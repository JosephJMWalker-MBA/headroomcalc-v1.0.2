//
//  HeadroomCalcApp.swift
//  HeadroomCalc
//
//  Created by Jeff Walker on 10/16/25.
//

import SwiftUI
import SwiftData

@main
struct HeadroomCalcApp: App {
    // Build a custom container so we can catch migration/validation failures
    // and (in DEBUG) wipe the store to keep dev moving.
    private static func makeContainer() -> ModelContainer {
        // Put the SQLite store in Application Support
        let storeURL = try! FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("default.store")

        let config = ModelConfiguration(url: storeURL)

        do {
            // If you later add a migration plan, pass `migrationPlan:` here.
            return try ModelContainer(
                for: YearLedger.self, IncomeEntry.self, FilingProfile.self,
                configurations: config
            )
        } catch {
            #if DEBUG
            // Migration/validation failed in development: wipe and retry.
            try? FileManager.default.removeItem(at: storeURL)
            return try! ModelContainer(
                for: YearLedger.self, IncomeEntry.self, FilingProfile.self,
                configurations: config
            )
            #else
            fatalError("Failed to open persistent store: \(error)")
            #endif
        }
    }

    // Hold the container once for the app's lifetime
    private let container: ModelContainer = HeadroomCalcApp.makeContainer()

    var body: some Scene {
        WindowGroup {
            BootstrapView()
        }
        .modelContainer(container)
    }
}

struct BootstrapView: View {
    @Environment(\.modelContext) private var context
    @StateObject private var tipStore = TipStateStore()
    @StateObject private var appState = AppState()
    @State private var didRunHealthCheck = false
    @State private var bootstrapDone = false

    var body: some View {
        ZStack {
            if bootstrapDone {
                ContentView()
                    .environmentObject(tipStore)
                    .environmentObject(appState)
            } else {
                ProgressView("Preparing data…")
                    .padding()
            }
        }
        .task {
            await runBootstrap()
        }
    }

    @MainActor
    private func runBootstrap() async {
        guard !didRunHealthCheck else { return }
        didRunHealthCheck = true

        // 1) Health check & enqueue banners FIRST (so they show before other notices)
        let healthMessages = StoreHealthChecker.runAndBannerMessages(in: context)
        for msg in healthMessages { appState.enqueueBanner(msg) }

        // 2) Seed (debug-only) and persist immediately
        #if DEBUG
        let seedOutcome = DataSeeder.seedIfNeeded(in: context)
        switch seedOutcome {
        case .didSeed(let message, _, _):
            appState.enqueueBanner(message)
        default:
            break
        }
        #endif
        try? context.save()

        // 3) Ensure a FilingProfile exists for the current year *before* showing the UI
        let currentYear = Calendar.current.component(.year, from: Date())
        _ = ensureFilingProfile(forYear: currentYear)

        // 4) Prime tax tables for the current year + all filing statuses
        TaxTableService.shared.prime(year: currentYear, statuses: Array(FilingStatus.allCases))

        // Give the service a brief moment to publish availability so views
        // don't flash "Tax tables unavailable" at first render.
        try? await Task.sleep(nanoseconds: 600_000_000) // 600ms

        // Persist any inserts from the ensure step
        try? context.save()

        // 5) Allow main content to render
        bootstrapDone = true
    }

    @MainActor
    private func ensureFilingProfile(forYear year: Int) -> FilingProfile {
        let fetch: FetchDescriptor<FilingProfile> = FetchDescriptor(
            predicate: #Predicate<FilingProfile> { $0.year == year }
        )
        if let results = try? context.fetch(fetch), let existing = results.first {
            return existing
        }

        let new = FilingProfile(year: year, status: .single, standardDeduction: 14600)
        context.insert(new)
        return new
    }
}

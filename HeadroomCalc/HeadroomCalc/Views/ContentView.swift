import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \YearLedger.year, order: .reverse) private var ledgers: [YearLedger]

    @State private var selection: YearLedger?
    @State private var exportedURL: URL?
    @State private var exportError: String?
    @AppStorage("hasSeenHowTo") private var hasSeenHowTo: Bool = false
    // App-wide banner/alert queue pushed from app bootstrap (e.g., DataSeeder)
    @EnvironmentObject var appState: AppState
    @State private var showingBanner: Bool = false
    @State private var currentBannerText: String?
    @State private var bannerIndex: Int = 0
    @State private var shouldShowHowToOnIdle: Bool = false
    // Banner behavior: set to a number (e.g., 3) to auto-dismiss after seconds; nil keeps it until user dismisses
    private let bannerAutoDismiss: TimeInterval? = nil
    // App brand accent (distinctive for screenshots & App Review)
    private let brandAccent: Color = Color(red: 0.16, green: 0.56, blue: 0.98)

    private enum ActiveSheet: Identifiable {
        case settings
        case share(URL)
        case howTo
        var id: String {
            switch self {
            case .settings: return "settings"
            case .share(let url): return "share:\(url.absoluteString)"
            case .howTo: return "howto"
            }
        }
    }
    @State private var activeSheet: ActiveSheet?

    @ViewBuilder
    private var sidebarList: some View {
        List(selection: $selection) {
            ForEach(ledgers) { ledger in
                NavigationLink(value: ledger) {
                    VStack(alignment: .leading) {
                        Text(ledger.year, format: .number.grouping(.never))
                            .font(.headline)
                        Text("\(ledger.entries.count) entries — " + currency(ledger.totalIncome))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete(perform: deleteYears)
        }
        .navigationTitle("HeadroomCalc")
    }

    @ViewBuilder
    private var detailPane: some View {
        if let selectedLedger = selection {
            VStack(spacing: 0) {
                HeadroomSummaryView(ledger: selectedLedger)
                Divider()
                IncomeListView(ledger: selectedLedger)
            }
            .navigationTitle(Text(selectedLedger.year, format: .number.grouping(.never)))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        do {
                            let url = try ReportExporter.exportPDF(for: selectedLedger)
                            exportedURL = url
                            DispatchQueue.main.async { activeSheet = .share(url) }
                        } catch {
                            exportError = (error as? ReportExporterError) == .tablesUnavailable
                                ? "Tax tables are unavailable for this year."
                                : "Could not render PDF."
                        }
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        ensureProfile(for: selectedLedger)
                        DispatchQueue.main.async { activeSheet = .settings }
                    } label: {
                        Label("Settings", systemImage: "gear")
                    }
                }
            }
            .sheet(item: $activeSheet) { item in
                switch item {
                case .settings:
                    SettingsView(ledger: selectedLedger)
                case .share(let url):
                    ReportShareView(url: url)
                case .howTo:
                    NavigationStack { HowToUseView() }
                }
            }
            .alert("Export Error", isPresented: Binding(
                get: { exportError != nil },
                set: { if !$0 { exportError = nil } }
            )) {
                Button("OK", role: .cancel) { exportError = nil }
            } message: {
                Text(exportError ?? "Unknown error")
            }
        } else {
            VStack(spacing: 16) {
                ContentUnavailableView("Select or add a year",
                                       systemImage: "calendar",
                                       description: Text("Your income entries and headroom will appear here."))
                Button {
                    addCurrentYearIfNeeded()
                } label: {
                    Label("Add Current Year", systemImage: "calendar.badge.plus")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
    }

    var body: some View {
        NavigationSplitView {
            sidebarList
        } detail: {
            detailPane
        }
        .tint(brandAccent)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(brandAccent.opacity(0.08), for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    addCurrentYearIfNeeded()
                } label: {
                    Label("Add Year", systemImage: "calendar.badge.plus")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    clonePreviousYear()
                } label: {
                    Label("Clone Last Year", systemImage: "rectangle.on.rectangle")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
        }
        .onAppear {
            if selection == nil { selection = ledgers.first }
            // Ensure the selected year has a FilingProfile so tax tables are available on first load
            if let ledger = selection, ledger.profile == nil {
                ensureProfile(for: ledger)
            }
            if !hasSeenHowTo {
                if appState.bannerQueue.isEmpty {
                    DispatchQueue.main.async {
                        activeSheet = .howTo
                        hasSeenHowTo = true
                    }
                } else {
                    // Defer until banners finish or are dismissed
                    shouldShowHowToOnIdle = true
                }
            }
        }
        .onChange(of: appState.bannerQueue, initial: true) { _, _ in
            // Whenever the queue is refreshed, start from the first item and present (once)
            bannerIndex = 0
            presentNextBannerIfAvailable()
        }
        .overlay(alignment: .top) {
            if showingBanner, let text = currentBannerText {
                TopBanner(text: text) {
                    withAnimation(.easeInOut) { showingBanner = false }
                    bannerIndex += 1
                    DispatchQueue.main.async { presentNextBannerIfAvailable() }
                }
                .padding(.top, 8)
            }
        }
    }

    // Present the next queued banner (if any), auto-advance after a delay, and chain until exhausted
    private func presentNextBannerIfAvailable() {
        let q = appState.bannerQueue
        // If already animating, do nothing
        guard !showingBanner else { return }
        // If no more banners, optionally show How-To if it was deferred
        guard bannerIndex < q.count else {
            if shouldShowHowToOnIdle, !hasSeenHowTo {
                DispatchQueue.main.async {
                    activeSheet = .howTo
                    hasSeenHowTo = true
                    shouldShowHowToOnIdle = false
                }
            }
            return
        }
        // Present the next banner
        currentBannerText = q[bannerIndex]
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) { showingBanner = true }
        // Auto-dismiss only if configured; otherwise wait for user dismissal
        if let seconds = bannerAutoDismiss {
            DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) { showingBanner = false }
                bannerIndex += 1
                DispatchQueue.main.async { presentNextBannerIfAvailable() }
            }
        }
    }

    // Clamp non-finite values to avoid CoreGraphics NaN warnings during formatting/rendering
    private func currency(_ x: Double) -> String { (x.isFinite ? x : 0).formatted(.currency(code: "USD")) }

    // MARK: - Actions

    private func addCurrentYearIfNeeded() {
        let y = Calendar.current.component(.year, from: Date())
        if !ledgers.contains(where: { $0.year == y }) {
            let ledger = YearLedger(year: y, profile: FilingProfile()) // default profile
            modelContext.insert(ledger)
            selection = ledger
        } else {
            selection = ledgers.first(where: { $0.year == y })
        }
    }

    private func clonePreviousYear() {
        guard let mostRecent = ledgers.first else { return }
        let newYear = (mostRecent.year + 1)
        guard !ledgers.contains(where: { $0.year == newYear }) else {
            selection = ledgers.first(where: { $0.year == newYear })
            return
        }

        let cloned = YearLedger(year: newYear,
                                profile: mostRecent.profile.map { FilingProfile(status: $0.status,
                                                                                standardDeduction: $0.standardDeduction) },
                                entries: mostRecent.entries.map {
                                    IncomeEntry(sourceType: $0.sourceType,
                                                displayName: $0.displayName,
                                                amount: $0.amount,
                                                shares: $0.shares,
                                                fairMarketPrice: $0.fairMarketPrice,
                                                costBasisPerShare: $0.costBasisPerShare)
                                })
        modelContext.insert(cloned)
        selection = cloned
    }

    private func deleteYears(at offsets: IndexSet) {
        for index in offsets { modelContext.delete(ledgers[index]) }
        selection = ledgers.first
    }

    private func ensureProfile(for ledger: YearLedger) {
        if ledger.profile == nil {
            ledger.profile = FilingProfile()
        }
    }
}

private struct TopBanner: View {
    let text: String
    var onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: "info.circle")
            Text(text)
                .lineLimit(3)
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .padding(6)
            }
            .accessibilityLabel("Dismiss")
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(radius: 4, y: 2)
        .padding(.horizontal)
        .contentShape(Rectangle())
        .onTapGesture(perform: onDismiss)
        .transition(.move(edge: .top).combined(with: .opacity))
        .accessibilityAddTraits(.isModal)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [YearLedger.self, IncomeEntry.self, FilingProfile.self])
        .environmentObject(AppState())
}

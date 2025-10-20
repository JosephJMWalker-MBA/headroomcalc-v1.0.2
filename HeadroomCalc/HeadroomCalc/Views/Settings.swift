//
//  Settings.swift
//  HeadroomCalc
import SwiftUI
import SwiftData
import Foundation

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var appState: AppState
    @Bindable var ledger: YearLedger

    @State private var showDeleteConfirm = false
    @State private var maintenanceMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Filing Profile") {
                    Picker("Filing Status", selection: Binding(
                        get: { (ledger.profile?.status) ?? .single },
                        set: { newValue in ensureProfile(); ledger.profile!.status = newValue }
                    )) {
                        ForEach(FilingStatus.allCases) { status in
                            Text(status.rawValue).tag(status)
                        }
                    }

                    TextField("Standard Deduction", value: Binding(
                        get: { (ledger.profile?.standardDeduction) ?? 0 },
                        set: { newValue in ensureProfile(); ledger.profile!.standardDeduction = newValue }
                    ), format: .currency(code: "USD"))
                    .keyboardType(.decimalPad)
                }

                Section("Tax Tables") {
                    HStack {
                        Text("Year \(String(ledger.year)) JSON")
                        Spacer()
                        Text(taxTableStatus)
                            .foregroundStyle(taxTableStatus == "Found" ? Color.secondary : Color.red)
                    }
                }

                Section("App") {
                    LabeledContent("Version", value: appVersion)
                    LabeledContent("Build", value: appBuild)
                }

                Section("Help & Info") {
                    NavigationLink {
                        HowToUseView()
                    } label: {
                        Label("How to Use", systemImage: "questionmark.circle")
                    }

                    NavigationLink {
                        AboutView()
                    } label: {
                        Label("About", systemImage: "info.circle")
                    }
                }

                Section("Data Management") {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete all entries for \(String(ledger.year))", systemImage: "trash")
                    }
                    .confirmationDialog("Delete \(ledger.entries.count) entries for \(String(ledger.year))?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                        Button("Delete Entries", role: .destructive) { deleteYearEntries() }
                        Button("Cancel", role: .cancel) { }
                    } message: {
                        Text("This cannot be undone.")
                    }
                }

                Section("Maintenance") {
                    Button {
                        runHealthCheck()
                    } label: {
                        Label("Run Health Check", systemImage: "wrench.and.screwdriver")
                    }
                    .labelStyle(.titleAndIcon)

                    #if DEBUG
                    Button {
                        seedSampleData()
                    } label: {
                        Label("Seed Sample Data", systemImage: "shippingbox")
                    }
                    .labelStyle(.titleAndIcon)
                    #endif
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            runHealthCheck()
                        } label: {
                            Label("Run Health Check", systemImage: "wrench.and.screwdriver")
                        }
                        .labelStyle(.titleAndIcon)
                        #if DEBUG
                        Button {
                            seedSampleData()
                        } label: {
                            Label("Seed Sample Data", systemImage: "shippingbox")
                        }
                        .labelStyle(.titleAndIcon)
                        #endif
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .onAppear { ensureProfile() }
            .alert(maintenanceMessage ?? "", isPresented: Binding(
                get: { maintenanceMessage != nil },
                set: { if !$0 { maintenanceMessage = nil } }
            )) {
                Button("OK", role: .cancel) { }
            }
        }
    }

    // MARK: - Helpers

    private func ensureProfile() {
        if ledger.profile == nil { ledger.profile = FilingProfile() }
    }

    private var taxTableStatus: String {
        let name = "TaxBrackets_\(ledger.year)"
        return Bundle.main.url(forResource: name, withExtension: "json") != nil ? "Found" : "Missing"
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    private var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }

    private func deleteYearEntries() {
        let items = ledger.entries
        for item in items { context.delete(item) }
    }

    private func runHealthCheck() {
        let messages = StoreHealthChecker.runAndBannerMessages(in: context)
        if messages.isEmpty {
            maintenanceMessage = "Health check: no issues found."
        } else {
            for m in messages { appState.enqueueBanner(m) }
            maintenanceMessage = nil
        }
    }

#if DEBUG
    private func seedSampleData() {
        DataSeeder.seedIfNeeded(in: context)
        appState.enqueueBanner("Sample data seeded.")
        maintenanceMessage = nil
    }
#endif
}


#Preview {
    let container = try! ModelContainer(for: YearLedger.self, IncomeEntry.self, FilingProfile.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let ledger = YearLedger(year: 2025, profile: FilingProfile())
    container.mainContext.insert(ledger)
    return SettingsView(ledger: ledger)
        .modelContainer(container)
        .environmentObject(AppState())
}

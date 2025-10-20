import SwiftUI
import SwiftData

struct IncomeListView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var ledger: YearLedger

    @State private var showingAdd = false
    @State private var showingTips = false
    @State private var editingEntry: IncomeEntry? = nil

    // Clamp non-finite values before formatting to avoid CoreGraphics NaN warnings
    private func currency(_ x: Double) -> String { (x.isFinite ? x : 0).formatted(.currency(code: "USD")) }

    // Display ordering: stable order by createdAt then id to avoid diffing surprises
    private var displayEntries: [IncomeEntry] {
        ledger.entries.sorted {
            if $0.createdAt == $1.createdAt { return $0.id.uuidString < $1.id.uuidString }
            return $0.createdAt < $1.createdAt
        }
    }

    private var totalAmount: Double {
        let x = ledger.totalIncome
        return x.isFinite ? x : 0
    }

    var body: some View {
        List {
            Section {
                DisclosureGroup(isExpanded: $showingTips) {
                    InlineHelpView(type: .other)
                        .padding(.top, 4)
                } label: {
                    Label("Planning Tips", systemImage: "lightbulb")
                        .foregroundStyle(.secondary)
                }
            }
            Section {
                ForEach(displayEntries, id: \.persistentModelID) { entry in
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.displayName)
                                .font(.body.weight(.semibold))
                            Text(entry.sourceType.rawValue)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(currency(entry.amount))
                            .monospacedDigit()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { editingEntry = entry }
                    .swipeActions(edge: .leading) {
                        Button("Edit") { editingEntry = entry }
                            .tint(.blue)
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            delete(entry)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            } header: {
                Text("Income Entries")
            } footer: {
                HStack {
                    Text("Total")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(currency(totalAmount))
                        .monospacedDigit()
                }
            }
        }
        .overlay {
            if ledger.entries.isEmpty {
                VStack(spacing: 12) {
                    ContentUnavailableView("No income entries",
                                           systemImage: "tray",
                                           description: Text("Tap “Add Income” to start."))
                    Button {
                        showingAdd = true
                    } label: {
                        Label("Add Income", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .labelStyle(.titleAndIcon)
                }
                .padding()
            }
        }
        .listStyle(.insetGrouped)
        .transaction { $0.disablesAnimations = true }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAdd = true
                } label: {
                    Label("Add Income", systemImage: "plus")
                }
                .labelStyle(.titleAndIcon)
            }
        }
        .sheet(isPresented: $showingAdd) {
            AddIncomeSheet(ledger: ledger)
        }
        .sheet(item: $editingEntry) { item in
            AddIncomeSheet(ledger: ledger, entryToEdit: item)
        }
    }

    private func delete(_ entry: IncomeEntry) {
        if editingEntry?.id == entry.id { editingEntry = nil }
        withTransaction(Transaction(animation: nil)) {
            modelContext.delete(entry)
            try? modelContext.save()
        }
    }
}

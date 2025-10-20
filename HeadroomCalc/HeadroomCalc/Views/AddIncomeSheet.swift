//
//  AddIncomeSheet.swift
//  HeadroomCalc
import SwiftUI
import SwiftData
import Foundation

struct AddIncomeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Bindable var ledger: YearLedger
    let entryToEdit: IncomeEntry?

    @State private var selectedType: IncomeSourceType = .w2
    @State private var name: String = ""
    @State private var amount: Double = 0
    @State private var isSubmitting = false

    // String mirrors to avoid transient NaNs while typing
    @State private var amountText: String = ""
    @State private var sharesText: String = ""
    @State private var sharesAvailableText: String = ""
    @State private var fmvText: String = ""
    @State private var strikePriceText: String = ""
    @State private var basisPerShareText: String = ""

    @State private var showHelp = false
    @FocusState private var inputActive: Bool

    // Prevent NaN/Inf from leaking into UI/formatters
    private var safeAmount: Double { amount.isFinite ? amount : 0 }
    
    private static let usdStyle = FloatingPointFormatStyle<Double>.Currency(code: "USD")
    private func currency(_ x: Double) -> String {
        let v = x.isFinite ? (x == -0.0 ? 0 : x) : 0
        return v.formatted(Self.usdStyle)
    }
    private func number(_ x: Double) -> String { (x.isFinite ? x : 0).formatted(.number) }

    // Equity fields
    @State private var shares: Double?
    @State private var fmv: Double?
    @State private var basisPerShare: Double? // used for Restricted Stock Units / Employee Stock Purchase Plan; for Incentive Stock Option use strikePrice

    // Stock option specifics (Incentive / Nonqualified)
    @State private var ticker: String = ""
    @State private var strikePrice: Double?
    @State private var sharesAvailable: Double?

    private var isEquityType: Bool { selectedType.isEquity }
    private var isISOorNSO: Bool { selectedType == .incentiveStockOption || selectedType == .nonqualifiedStockOption }
    private var isEditing: Bool { entryToEdit != nil }
    @State private var didPrefill = false

    init(ledger: YearLedger, entryToEdit: IncomeEntry? = nil) {
        self._ledger = Bindable(ledger)
        self.entryToEdit = entryToEdit
    }

    var body: some View {
        NavigationStack {
            Form {
                generalSection
                if isEquityType {
                    equityDetailsSection
                }
                miniHelpSection
            }
            .onChange(of: shares, initial: false) { _, _ in recomputeAmountForEquity() }
            .onChange(of: fmv, initial: false) { _, _ in recomputeAmountForEquity() }
            .onChange(of: strikePrice, initial: false) { _, _ in recomputeAmountForEquity() }
            .onChange(of: amount, initial: false) { _, new in
                if !new.isFinite { amount = 0 }
                else if new == -0.0 { amount = 0 }
            }
            .onChange(of: amountText, initial: false) { _, s in amount = parseDecimal(s) ?? 0 }
            .onChange(of: sharesText, initial: false) { _, s in shares = parseDecimal(s) }
            .onChange(of: sharesAvailableText, initial: false) { _, s in sharesAvailable = parseDecimal(s) }
            .onChange(of: fmvText, initial: false) { _, s in fmv = parseDecimal(s) }
            .onChange(of: strikePriceText, initial: false) { _, s in strikePrice = parseDecimal(s) }
            .onChange(of: basisPerShareText, initial: false) { _, s in basisPerShare = parseDecimal(s) }
            .onChange(of: selectedType, initial: false) { _, new in
                // Reset fields when switching types to avoid stale values and NaNs
                if new.isEquity {
                    amount = 0
                    amountText = ""
                }
                shares = nil; sharesText = ""
                sharesAvailable = nil; sharesAvailableText = ""
                fmv = nil; fmvText = ""
                strikePrice = nil; strikePriceText = ""
                basisPerShare = nil; basisPerShareText = ""
                showHelp = false
            }
            .onAppear {
                guard !didPrefill, let e = entryToEdit else { return }
                // Prefill from existing entry
                selectedType = e.sourceType
                name = e.displayName
                amount = e.amount
                ticker = e.symbol ?? ""
                shares = e.shares
                fmv = e.fairMarketPrice
                strikePrice = e.costBasisPerShare
                basisPerShare = e.costBasisPerShare
                // seed text mirrors
                amountText = safeAmount == 0 ? "" : number(safeAmount)
                sharesText = fmtOptional(shares)
                sharesAvailableText = fmtOptional(sharesAvailable)
                fmvText = fmtOptional(fmv)
                strikePriceText = fmtOptional(strikePrice)
                basisPerShareText = fmtOptional(basisPerShare)
                didPrefill = true
            }
            .navigationTitle(isEditing ? "Edit Income" : "Add Income")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add") {
                        guard !isSubmitting else { return }
                        isSubmitting = true
                        if isEditing { updateEntry() } else { addEntry() }
                    }
                    .disabled(isSubmitting || !canAdd)
                }
            }
            .transaction { $0.disablesAnimations = true }
            .modifier(HideKeyboardToolbarIfAvailable())
            .safeAreaInset(edge: .bottom) {
                if inputActive {
                    HStack {
                        Spacer()
                        Button("Done") { inputActive = false }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .shadow(radius: 2)
                }
            }
        }
    }

    @ViewBuilder private var generalSection: some View {
        Section("General") {
            Picker("Source Type", selection: $selectedType) {
                ForEach(IncomeSourceType.allCases) { t in
                    Text(t.rawValue).tag(t)
                }
            }
            TextField("Display name", text: $name)
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.never)
                .focused($inputActive)
            if isISOorNSO {
                LabeledContent("Amount (computed)", value: currency(safeAmount))
            } else {
                TextField("Amount", text: $amountText)
                    .keyboardType(.decimalPad)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .focused($inputActive)
            }
        }
    }
    @ViewBuilder private var miniHelpSection: some View {
        Section {
            DisclosureGroup(isExpanded: $showHelp) {
                InlineHelpView(type: selectedType)
            } label: {
                Label("Help for \(selectedType.rawValue)", systemImage: "questionmark.circle")
            }
        }
        .id(selectedType) // reset any internal state when the type changes
    }

    @ViewBuilder private var equityDetailsSection: some View {
        Section("Equity Details (optional)") {
            if isISOorNSO {
                isoFieldsView
            } else {
                rsuFieldsView
            }
        }
    }

    @ViewBuilder private var isoFieldsView: some View {
        isoInputFieldsView
        isoComputedReadoutsView
        isoWarningsView
    }

    @ViewBuilder private var isoInputFieldsView: some View {
        TextField("Ticker (e.g., AAPL)", text: $ticker)
            .textInputAutocapitalization(.characters)
            .autocorrectionDisabled(true)
            .onChange(of: ticker, initial: false) { _, s in
                // Keep only A–Z, uppercase, and cap to 5 characters
                let filtered = s.uppercased().filter { ("A"..."Z").contains($0) }
                let capped = String(filtered.prefix(5))
                if capped != s { ticker = capped }
            }
            .focused($inputActive)
        TextField("Shares to Exercise", text: $sharesText)
            .keyboardType(.decimalPad)
            .autocorrectionDisabled(true)
            .textInputAutocapitalization(.never)
            .focused($inputActive)
        TextField("Shares Available", text: $sharesAvailableText)
            .keyboardType(.decimalPad)
            .autocorrectionDisabled(true)
            .textInputAutocapitalization(.never)
            .focused($inputActive)
        TextField("FMV / Share", text: $fmvText)
            .keyboardType(.decimalPad)
            .autocorrectionDisabled(true)
            .textInputAutocapitalization(.never)
            .focused($inputActive)
        TextField("Strike (Award) / Share", text: $strikePriceText)
            .keyboardType(.decimalPad)
            .autocorrectionDisabled(true)
            .textInputAutocapitalization(.never)
            .focused($inputActive)
    }

    @ViewBuilder private var isoComputedReadoutsView: some View {
        LabeledContent("Bargain Element / Share", value: currency(perShareTaxable))
        LabeledContent("Estimated Taxable Add", value: currency(estimatedTaxableAdd))
        if let rem = remainingHeadroomAfter {
            LabeledContent("Remaining Headroom After", value: currency(rem))
        }

        if let est = headroomSharesEstimate {
            LabeledContent("Max Shares Within Headroom", value: number(est))
            Button("Set Shares to Max Within Headroom") { shares = est }
        } else {
            LabeledContent("Max Shares Within Headroom", value: "—")
        }
    }

    @ViewBuilder private var isoWarningsView: some View {
        if let avail = sharesAvailable, let sh = shares, sh > avail {
            Text("Warning: Shares exceed available (\(number(sh)) > \(number(avail))).")
                .font(.footnote)
                .foregroundStyle(.red)
        }

        Text("Estimate uses FMV − Strike; AMT not modeled.")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }

    @ViewBuilder private var rsuFieldsView: some View {
        TextField("Shares", text: $sharesText)
            .keyboardType(.decimalPad)
            .autocorrectionDisabled(true)
            .textInputAutocapitalization(.never)
            .focused($inputActive)
        TextField("FMV / Share", text: $fmvText)
            .keyboardType(.decimalPad)
            .autocorrectionDisabled(true)
            .textInputAutocapitalization(.never)
            .focused($inputActive)
        TextField("Cost Basis / Share", text: $basisPerShareText)
            .keyboardType(.decimalPad)
            .autocorrectionDisabled(true)
            .textInputAutocapitalization(.never)
            .focused($inputActive)
    }

    // MARK: - Actions
    private func addEntry() {
        if (selectedType == .incentiveStockOption || selectedType == .nonqualifiedStockOption),
           let sh = shares, let f = fmv, let k = (strikePrice ?? basisPerShare) {
            let perShare = max(0, f - k)
            if perShare > 0 { amount = sh * perShare }
        } else {
            // non-equity: use parsed amount text
            amount = parseDecimal(amountText) ?? 0
        }
        // Sanity: prevent NaN/Inf amounts from leaking into the model/UI
        if amount.isNaN || amount.isInfinite { amount = 0 }

        let entry = IncomeEntry(
            sourceType: selectedType,
            displayName: name.isEmpty ? selectedType.rawValue : name,
            amount: amount,
            shares: shares,
            fairMarketPrice: fmv,
            costBasisPerShare: (strikePrice ?? basisPerShare)
        )
        if !ticker.isEmpty {
            entry.symbol = ticker
        }
        // Ensure a concrete timestamp
        entry.createdAt = .now
        // Ensure id uniqueness in case of preexisting duplicates after migration
        while ledger.entries.contains(where: { $0.id == entry.id }) {
            entry.id = UUID()
        }
        // Recent-duplicate guard: avoid creating a twin during UI coalescing
        let recentCutoff = Date().addingTimeInterval(-1)
        let intendedName = name.isEmpty ? selectedType.rawValue : name
        if let _ = ledger.entries.first(where: { $0.createdAt > recentCutoff &&
                                                $0.sourceType == selectedType &&
                                                $0.displayName == intendedName &&
                                                abs($0.amount - amount) < 0.0001 }) {
            dismiss()
            DispatchQueue.main.async { isSubmitting = false }
            return
        }
        // Sequence on next run loop; dismiss first, then mutate without animation to avoid UICollectionView invalid updates
        DispatchQueue.main.async {
            dismiss()
            // Mutate after dismissal and without animation to avoid UICollectionView invalid updates
            withAnimation(nil) { ledger.addEntry(entry) }
            DispatchQueue.main.async { isSubmitting = false }
        }
    }

    // MARK: - Edit support
    private func updateEntry() {
        guard let e = entryToEdit else { return }
        if (selectedType == .incentiveStockOption || selectedType == .nonqualifiedStockOption) {
            recomputeAmountForEquity()
        } else {
            amount = parseDecimal(amountText) ?? 0
        }
        // Sanitize to prevent NaN/Inf leaking into UI/layout
        if amount.isNaN || amount.isInfinite { amount = 0 }

        // Dismiss first, then mutate on next runloop without animations to avoid list diff crashes
        dismiss()
        DispatchQueue.main.async {
            withAnimation(nil) {
                e.sourceType = selectedType
                e.displayName = name.isEmpty ? selectedType.rawValue : name
                e.amount = amount
                e.symbol = ticker.isEmpty ? nil : ticker
                e.shares = shares
                e.fairMarketPrice = fmv
                e.costBasisPerShare = (strikePrice ?? basisPerShare)
            }
            isSubmitting = false
        }
    }

    // MARK: - Helpers
    private var perShareTaxable: Double {
        guard selectedType == .incentiveStockOption || selectedType == .nonqualifiedStockOption, let f = fmv, let k = (strikePrice ?? basisPerShare) else { return 0 }
        return max(0, f - k)
    }

    private var headroomSharesEstimate: Double? {
        guard selectedType == .incentiveStockOption || selectedType == .nonqualifiedStockOption else { return nil }
        guard perShareTaxable > 0, let result = try? HeadroomEngine.compute(for: ledger), let dollars = result.dollarsToNextBracket else { return nil }
        let maxByHeadroom = floor(dollars / perShareTaxable)
        if let avail = sharesAvailable { return max(0, min(maxByHeadroom, floor(avail))) }
        return max(0, maxByHeadroom)
    }

    private var estimatedTaxableAdd: Double {
        guard selectedType == .incentiveStockOption || selectedType == .nonqualifiedStockOption, let sh = shares, sh > 0 else { return 0 }
        return sh * perShareTaxable
    }

    private var remainingHeadroomAfter: Double? {
        guard selectedType == .incentiveStockOption || selectedType == .nonqualifiedStockOption else { return nil }
        guard let base = try? HeadroomEngine.compute(for: ledger), let dollars = base.dollarsToNextBracket else { return nil }
        return max(0, dollars - estimatedTaxableAdd)
    }

    private var canAdd: Bool {
        if selectedType == .incentiveStockOption || selectedType == .nonqualifiedStockOption {
            return (shares ?? 0) > 0 && perShareTaxable > 0
        } else {
            return amount > 0
        }
    }

    private func recomputeAmountForEquity() {
        guard selectedType == .incentiveStockOption || selectedType == .nonqualifiedStockOption else { return }
        let val = max(0, estimatedTaxableAdd)
        amount = val.isFinite ? (val == -0.0 ? 0 : val) : 0
    }
}

fileprivate struct HideKeyboardToolbarIfAvailable: ViewModifier {
    func body(content: Content) -> some View {
        // Fallback no-op: SDK does not expose ToolbarPlacement.keyboard
        content
    }
}

    // MARK: - Parsing helpers
    private func parseDecimal(_ s: String) -> Double? {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        let fmt = NumberFormatter()
        fmt.locale = .current
        fmt.numberStyle = .decimal
        if let n = fmt.number(from: trimmed)?.doubleValue { return n.isFinite ? n : nil }
        if let d = Double(trimmed), d.isFinite { return d }
        return nil
    }

    private func fmtOptional(_ x: Double?) -> String {
        guard let v = x, v.isFinite, v != -0.0 else { return "" }
        return (v.isFinite ? v : 0).formatted(.number)
    }

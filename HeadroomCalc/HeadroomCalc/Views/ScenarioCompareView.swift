import SwiftUI

struct ScenarioCompareView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var ledger: YearLedger

    @State private var adjustments = ScenarioInputs()
    @State private var baselineResult: HeadroomResult?
    @State private var scenarioResult: HeadroomResult?
    @State private var errorText: String?
    @State private var baselineThresholds: [ThresholdInsight] = []
    @State private var scenarioThresholds: [ThresholdInsight] = []

    var body: some View {
        NavigationStack {
            Form {
                adjustmentsSection
                if let errorText {
                    Section { Text(errorText).foregroundStyle(.secondary) }
                } else {
                    baselineSection
                    scenarioSection
                }
            }
            .navigationTitle("Simulate Scenario")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .onAppear(perform: recalc)
            .onChange(of: adjustments) { _, _ in recalc() }
        }
    }

    private var adjustmentsSection: some View {
        Section("Additional income inputs") {
            AdjustmentRow(title: "Ordinary Income",
                          subtitle: "W-2, 1099, Roth conversions",
                          value: $adjustments.additionalOrdinaryIncome)
            AdjustmentRow(title: "Long-term Capital Gains",
                          subtitle: "Harvested gains or RSU basis recovery",
                          value: $adjustments.additionalLongTermCapitalGains)
            Text("Tap the steppers or edit the amount to explore Roth conversions, contract work, or equity sales without surprising the next bracket or IRMAA.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var baselineSection: some View {
        Section("Baseline") {
            if let result = baselineResult {
                ThresholdChipsView(bracketRate: result.bracketRate,
                                    insights: baselineThresholds)
                HeadroomBar(result: result,
                            standardDeduction: ledger.profile?.standardDeduction,
                            thresholds: baselineThresholds)
                ScenarioMetricsView(result: result)
            } else {
                Text("Baseline results unavailable. Add a filing profile and ensure tax tables for this year are bundled.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var scenarioSection: some View {
        Section("Scenario with adjustments") {
            if let base = baselineResult, let scenario = scenarioResult {
                ThresholdChipsView(bracketRate: scenario.bracketRate,
                                    insights: scenarioThresholds)
                HeadroomBar(result: scenario,
                            standardDeduction: ledger.profile?.standardDeduction,
                            thresholds: scenarioThresholds)
                ScenarioMetricsView(result: scenario,
                                     deltaTaxable: scenario.taxableIncome - base.taxableIncome,
                                     deltaHeadroom: (scenario.dollarsToNextBracket ?? 0) - (base.dollarsToNextBracket ?? 0))
                if scenario.bracketRate != base.bracketRate {
                    Text("Marginal rate changes to \(Int((scenario.bracketRate * 100).rounded()))%.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Enter adjustments to compare against your baseline.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button("Done") { dismiss() }
        }
    }

    private func recalc() {
        do {
            baselineResult = try HeadroomEngine.compute(for: ledger)
            scenarioResult = try HeadroomEngine.compute(for: ledger, applying: adjustments)
            baselineThresholds = ThresholdInsightService.shared.insights(for: ledger)
            scenarioThresholds = ThresholdInsightService.shared.insights(for: ledger, applying: adjustments)
            errorText = nil
        } catch HeadroomError.tablesUnavailable {
            errorText = "Tax tables for \(ledger.year) are missing. Add TaxBrackets_\(ledger.year).json to your bundle."
            baselineResult = nil
            scenarioResult = nil
        } catch HeadroomError.missingProfile {
            errorText = "Create a filing profile for this year to simulate scenarios."
            baselineResult = nil
            scenarioResult = nil
        } catch {
            errorText = "Unexpected error: \(error.localizedDescription)"
            baselineResult = nil
            scenarioResult = nil
        }
    }
}

private struct AdjustmentRow: View {
    let title: String
    let subtitle: String
    @Binding var value: Double

    private let formatter = FloatingPointFormatStyle<Double>.Currency(code: "USD")

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Stepper(value: $value, in: -1_000_000...1_000_000, step: 1_000) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).font(.subheadline.weight(.semibold))
                        Text(subtitle).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(value.formatted(formatter))
                        .monospacedDigit()
                        .foregroundStyle(value >= 0 ? .primary : .secondary)
                }
            }
            TextField("Custom amount", value: $value, format: formatter)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.numbersAndPunctuation)
        }
    }
}

private struct ScenarioMetricsView: View {
    let result: HeadroomResult
    var deltaTaxable: Double = 0
    var deltaHeadroom: Double = 0

    private let formatter = FloatingPointFormatStyle<Double>.Currency(code: "USD")

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            LabeledContent("Taxable Income", value: result.taxableIncome.formatted(formatter))
            if let headroom = result.dollarsToNextBracket {
                LabeledContent("Headroom to Next Bracket", value: headroom.formatted(formatter))
            } else {
                Text("Top bracket reached")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            LabeledContent("Marginal Rate", value: "\(Int((result.bracketRate * 100).rounded()))%")
            if deltaTaxable != 0 {
                Text("Δ Taxable: \(deltaTaxable.formatted(formatter))")
                    .font(.caption)
                    .foregroundStyle(deltaTaxable >= 0 ? .secondary : .green)
            }
            if deltaHeadroom != 0 {
                Text("Δ Headroom: \(deltaHeadroom.formatted(formatter))")
                    .font(.caption)
                    .foregroundStyle(deltaHeadroom >= 0 ? .green : .red)
            }
        }
    }
}

//
//  HeadroomSummaryView.swift
//  HeadroomCalc
//
import SwiftUI
import SwiftData
import Foundation

struct HeadroomSummaryView: View {
    @Bindable var ledger: YearLedger
    @State private var errorText: String?

    var body: some View {
        Group {
            if let errorText {
                ContentUnavailableView("Tax tables unavailable",
                                       systemImage: "exclamationmark.triangle",
                                       description: Text(errorText))
            } else {
                summaryBody
            }
        }
        .onAppear { recalc() }
        .onChange(of: ledger.entries.count) { _, _ in recalc() }
        .onChange(of: ledger.profile?.status) { _, _ in recalc() }
        .onChange(of: ledger.profile?.standardDeduction) { _, _ in recalc() }
    }

    @State private var result: HeadroomResult?

    private var summaryBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Year \(ledger.year, format: .number.grouping(.never))")
                .font(.title3.weight(.semibold))
                .lineLimit(1)

            if let profile = ledger.profile {
                LabeledContent("Filing Status", value: profile.status.rawValue)
                LabeledContent("Standard Deduction", value: currency(profile.standardDeduction))
            } else {
                Text("No filing profile. Using defaults may produce incorrect results.")
                    .foregroundStyle(.secondary)
            }

            Divider().padding(.vertical, 4)

            LabeledContent("Total Income", value: currency(ledger.totalIncome))

            if let result {
                LabeledContent("Taxable Income", value: currency(result.taxableIncome))
                LabeledContent("Current Bracket", value: percent(result.bracketRate))
                LabeledContent("Bracket Range", value: rangeText(result))
                if let toNext = result.dollarsToNextBracket {
                    LabeledContent("Headroom to Next Bracket", value: currency(toNext))
                } else {
                    Text("You’re in the top bracket for \(ledger.year, format: .number.grouping(.never)).")
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Headroom will appear after tax tables are loaded.")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }

    // Clamp non-finite values before formatting to avoid CoreGraphics NaN warnings
    private static let usdStyle = FloatingPointFormatStyle<Double>.Currency(code: "USD")
    private func currency(_ x: Double) -> String {
        let v = x.isFinite ? (x == -0.0 ? 0 : x) : 0
        return v.formatted(Self.usdStyle)
    }
    private func percent(_ x: Double) -> String {
        let v = x.isFinite ? x : 0
        return "\(Int((v * 100).rounded()))%"
    }

    private func rangeText(_ r: HeadroomResult) -> String {
        let lower = currency(r.bracketLower)
        if let upper = r.bracketUpper {
            return "\(lower) – \(currency(upper))"
        }
        return "\(lower)+"
    }

    private func recalc() {
        do {
            result = try HeadroomEngine.compute(for: ledger)
            errorText = nil
        } catch HeadroomError.tablesUnavailable {
            result = nil
            errorText = "Add TaxBrackets_\(ledger.year.formatted(IntegerFormatStyle<Int>.number.grouping(.never))).json to the app bundle."
        } catch HeadroomError.missingProfile {
            result = nil
            errorText = "Create a Filing Profile for this year (status + deduction)."
        } catch {
            result = nil
            errorText = "Unexpected error: \(error.localizedDescription)"
        }
    }
}

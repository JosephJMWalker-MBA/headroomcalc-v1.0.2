import SwiftUI
import SwiftData
import Foundation
import UIKit

// MARK: - Public API

enum ReportExporterError: Error {
    case failedToRender
    case tablesUnavailable
}

struct ReportExporter {
    /// US Letter @ 72 dpi
    static let pageSize = CGSize(width: 612, height: 792)
    static let pageMargin: CGFloat = 36

    /// Exports a single-page PDF summary for the given year ledger.
    /// Returns the file URL in the temporary directory.
    @MainActor
    static func exportPDF(for ledger: YearLedger) throws -> URL {
        // Prepare report view (pure SwiftUI, no side effects)
        let report = ReportView(ledger: ledger)
        let imageRenderer = ImageRenderer(content: report)
        imageRenderer.scale = UIScreen.main.scale

        guard let image = imageRenderer.uiImage else {
            throw ReportExporterError.failedToRender
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("HeadroomCalc_Report_\(ledger.year).pdf")

        let bounds = CGRect(origin: .zero, size: pageSize)
        let renderer = UIGraphicsPDFRenderer(bounds: bounds)
        try renderer.writePDF(to: url) { ctx in
            ctx.beginPage()

            // Fit the rendered image into the page with margins, preserving aspect
            let maxRect = bounds.insetBy(dx: pageMargin, dy: pageMargin)
            let scale = min(maxRect.width / image.size.width, maxRect.height / image.size.height)
            let drawSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let drawOrigin = CGPoint(x: maxRect.midX - drawSize.width/2, y: maxRect.minY)
            let drawRect = CGRect(origin: drawOrigin, size: drawSize)
            image.draw(in: drawRect)
        }

        return url
    }
}

// MARK: - SwiftUI Report content (rendered into PDF)

private struct ReportView: View {
    let ledger: YearLedger
    private let brandAccent = Color(red: 0.16, green: 0.56, blue: 0.98)

    private var result: HeadroomResult? {
        do { return try HeadroomEngine.compute(for: ledger) } catch { return nil }
    }

    private var thresholdDataset: TaxThresholds? {
        guard let profile = ledger.profile else { return nil }
        return ThresholdInsightService.shared.thresholds(for: ledger.year, status: profile.status)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Divider()
            summarySection
            Divider()
            thresholdsSection
            Divider()
            entriesSection
            disclaimerFooter
            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(width: ReportExporter.pageSize.width - ReportExporter.pageMargin*2)
        .background(Color.white)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Headroom — Bracket Headroom Report")
                    .font(.system(size: 28, weight: .bold))
                Text("Tax Year \(ledger.year, format: .number.grouping(.never))")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text("Generated \(Date.now.formatted(date: .abbreviated, time: .shortened))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Rectangle()
                    .fill(brandAccent.opacity(0.15))
                    .frame(height: 6)
                    .padding(.top, 6)
            }
            Spacer(minLength: 12)
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(brandAccent.opacity(0.85))
                .padding(.top, 2)
        }
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let profile = ledger.profile {
                LabeledRow(label: "Filing Status", value: profile.status.rawValue)
                LabeledRow(label: "Standard Deduction", value: currency(profile.standardDeduction))
            } else {
                Text("No filing profile set.")
                    .foregroundStyle(.secondary)
            }

            LabeledRow(label: "Total Income", value: currency(ledger.totalIncome))

            if let r = result {
                LabeledRow(label: "Taxable Income", value: currency(r.taxableIncome))
                LabeledRow(label: "Current Bracket", value: "\(Int(r.bracketRate * 100))% (\(currency(r.bracketLower)) – \(r.bracketUpper.map(currency) ?? "+"))")
                // Emphasized Headroom row
                if let toNext = r.dollarsToNextBracket {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Headroom to Next Bracket")
                            .font(.headline).bold()
                            .frame(width: 220, alignment: .leading)
                        Text(currency(toNext))
                            .font(.headline).bold()
                            .monospacedDigit()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Headroom to Next Bracket")
                            .font(.headline).bold()
                            .frame(width: 220, alignment: .leading)
                        Text("Top bracket")
                            .font(.headline).bold()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            } else {
                Text("Tax table not available for this year.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var thresholdsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Thresholds Used")
                .font(.headline)

            if let data = thresholdDataset {
                VStack(alignment: .leading, spacing: 4) {
                    Text("IRMAA Tiers")
                        .font(.subheadline.weight(.semibold))
                    ForEach(Array(zip(data.irmaaTiers.indices, data.irmaaTiers)), id: \.0) { index, tier in
                        HStack {
                            Text("Tier \(index + 1)")
                                .frame(width: 80, alignment: .leading)
                            Text(currency(tier.limit))
                                .monospacedDigit()
                                .frame(alignment: .leading)
                        }
                    }
                }

                HStack(alignment: .firstTextBaseline, spacing: 24) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("NIIT Threshold")
                            .font(.subheadline.weight(.semibold))
                        Text(currency(data.niit.limit))
                            .monospacedDigit()
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("QBI Phase-in")
                            .font(.subheadline.weight(.semibold))
                        Text(currency(data.qbi.limit))
                            .monospacedDigit()
                    }
                }
            } else {
                Text("Set a filing profile to include IRMAA, NIIT, and QBI thresholds.")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            }
        }
    }

    private var entriesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Income Entries (\(ledger.entries.count))")
                .font(.headline)
            VStack(spacing: 4) {
                ForEach(ledger.entries) { e in
                    HStack(alignment: .firstTextBaseline) {
                        Text(e.displayName)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(e.sourceType.rawValue)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 220, alignment: .leading)
                        Text(currency(e.amount))
                            .font(.body)
                            .monospacedDigit()
                            .frame(width: 140, alignment: .trailing)
                    }
                    .padding(.vertical, 2)
                    .overlay(Divider(), alignment: .bottom)
                }
            }
        }
    }

    private func currency(_ value: Double) -> String {
        value.formatted(.currency(code: "USD"))
    }
}

private struct LabeledRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 220, alignment: .leading)
            Text(value)
                .font(.body)
                .monospacedDigit()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private var disclaimerFooter: some View {
    VStack(alignment: .leading, spacing: 6) {
        Divider().padding(.top, 4)
        Text("Planning estimates only — not tax or legal advice. Intended for personal use only.")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }
}
// MARK: - Convenience Share Sheet (UIActivityViewController)

struct ReportShareView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) { }
}

import SwiftUI

struct HeadroomBar: View {
    let result: HeadroomResult
    let standardDeduction: Double?
    let thresholds: [ThresholdInsight]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { proxy in
                let markers = markerValues
                let scaleMax = barMaximum(for: markers)
                let width = proxy.size.width
                let progress = scaleMax > 0 ? min(1, result.taxableIncome / scaleMax) : 0

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 16)

                    Capsule()
                        .fill(Color.accentColor)
                        .frame(width: max(4, width * progress), height: 16)

                    ForEach(markers) { marker in
                        let ratio = scaleMax > 0 ? min(1, marker.value / scaleMax) : 0
                        let x = max(0, min(width - 1, width * ratio))
                        ThresholdMarker(label: marker.label, status: marker.status)
                            .position(x: x, y: 8)
                    }
                }
            }
            .frame(height: 24)

            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("Taxable: \(currency(result.taxableIncome))")
                    .font(.subheadline)
                    .monospacedDigit()
                if let headroom = result.dollarsToNextBracket {
                    Text("Headroom: \(currency(headroom))")
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                } else {
                    Text("Top bracket")
                        .font(.subheadline.weight(.semibold))
                }
            }
            .foregroundStyle(.secondary)
        }
    }

    private func barMaximum(for markers: [Marker]) -> Double {
        var candidates: [Double] = [result.taxableIncome]
        if let upper = result.bracketUpper { candidates.append(upper) }
        candidates.append(contentsOf: markers.map(\.value))
        let maxValue = candidates.max() ?? 0
        if let upper = result.bracketUpper { return upper }
        return max(maxValue, result.taxableIncome * 1.2 + 10_000)
    }

    private var markerValues: [Marker] {
        let deduction = standardDeduction ?? 0
        return thresholds.map { insight in
            Marker(id: "\(insight.detail.label)-\(Int(insight.detail.limit))",
                   label: insight.detail.label,
                   value: insight.detail.taxableEquivalent(standardDeduction: deduction),
                   status: insight.status)
        }
    }

    private func currency(_ value: Double) -> String {
        let formatter = FloatingPointFormatStyle<Double>.Currency(code: "USD")
        return value.formatted(formatter)
    }

    private struct Marker: Identifiable {
        let id: String
        let label: String
        let value: Double
        let status: ThresholdInsight.Status
    }

    private struct ThresholdMarker: View {
        let label: String
        let status: ThresholdInsight.Status

        var body: some View {
            VStack(spacing: 2) {
                Rectangle()
                    .fill(color)
                    .frame(width: 2, height: 18)
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
            }
            .accessibilityLabel("\(label) marker")
        }

        private var color: Color {
            switch status {
            case .clear: return Color.green.opacity(0.8)
            case .approaching: return Color.orange
            case .exceeded: return Color.red
            }
        }
    }
}

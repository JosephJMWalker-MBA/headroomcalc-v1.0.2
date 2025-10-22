import SwiftUI

struct ThresholdChipsView: View {
    let bracketRate: Double?
    let insights: [ThresholdInsight]

    private let currencyFormatter = FloatingPointFormatStyle<Double>.Currency(code: "USD")

    var body: some View {
        ViewThatFits {
            HStack(spacing: 8) {
                ForEach(chipData) { chip in
                    ChipCapsule(text: chip.text, tint: chip.tint)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                ForEach(chipData) { chip in
                    ChipCapsule(text: chip.text, tint: chip.tint)
                }
            }
        }
    }

    private var chipData: [ChipData] {
        var items: [ChipData] = []
        if let rate = bracketRate {
            let percent = Int((rate * 100).rounded())
            items.append(ChipData(id: "bracket",
                                  text: "\(percent)% bracket",
                                  tint: .accentColor))
        }

        for insight in insights {
            let text: String
            switch insight.status {
            case .clear:
                text = "\(insight.detail.label) • OK"
            case .approaching:
                let dollars = abs(insight.proximity)
                let formatted = dollars.formatted(currencyFormatter)
                text = "\(insight.detail.label) • within \(formatted)"
            case .exceeded:
                text = "\(insight.detail.label) • exceeded"
            }

            let tint: Color
            switch insight.status {
            case .clear:
                tint = Color.green.opacity(0.6)
            case .approaching:
                tint = Color.orange.opacity(0.7)
            case .exceeded:
                tint = Color.red.opacity(0.75)
            }

            items.append(ChipData(id: insight.detail.key, text: text, tint: tint))
        }
        return items
    }

    private struct ChipData: Identifiable {
        let id: String
        let text: String
        let tint: Color
    }

    private struct ChipCapsule: View {
        let text: String
        let tint: Color

        var body: some View {
            Text(text)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .foregroundStyle(tint.opacity(0.9))
                .background(tint.opacity(0.2), in: Capsule())
        }
    }
}

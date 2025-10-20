import SwiftUI

struct HowToUseView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                intro
                steps
                examples
                glossary
                tips
                footer
            }
            .padding(24)
        }
        .navigationTitle("How to Use")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("HeadroomCalc")
                .font(.largeTitle.bold())
            Text("Plan income without breaking into the next tax bracket")
                .foregroundStyle(.secondary)
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What this does")
                .font(.headline)
            Text("Track your household income for a tax year and see how much headroom you have before the next bracket. Then try adding potential items—contract work, option exercises, RSUs—to see the impact before you commit.")
        }
    }

    private var steps: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick start")
                .font(.headline)
            VStack(alignment: .leading, spacing: 10) {
                HowToRow(number: 1, title: "Add the current year", detail: "Use **Add Year**. You can also **Clone Last Year** to copy entries and your filing profile forward.")
                HowToRow(number: 2, title: "Set your filing profile", detail: "Tap **Settings** (gear) to choose Filing Status and Standard Deduction.")
                HowToRow(number: 3, title: "Add base income", detail: "Add your main job (**W‑2 Wages**) and your spouse’s job if filing jointly. Include other steady items like **Social Security**, **Pension**, **Dividends**, and **Interest**.")
                HowToRow(number: 4, title: "Explore what‑ifs", detail: "Try **Incentive/Nonqualified Stock Options**, **Restricted Stock Units**, **1099/Contractor** income, or bonuses. Option entries show **Bargain Element / Share** and **Max Shares Within Headroom** to help you size an exercise.")
                HowToRow(number: 5, title: "Watch the summary", detail: "The header shows your **Taxable Income**, **Current Bracket**, and **Headroom to Next Bracket** in dollars.")
                HowToRow(number: 6, title: "Export a PDF", detail: "Use **Export** to generate a one‑page report of the year for sharing or records.")
            }
        }
    }

    private var examples: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Examples")
                .font(.headline)

            GroupBox("Exercise stock options without crossing brackets") {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Add **Incentive Stock Option**.", systemImage: "square.and.pencil")
                    Label("Enter **Ticker**, **FMV / Share**, and **Strike**.", systemImage: "number")
                    Label("Check **Max Shares Within Headroom**.", systemImage: "chart.bar")
                    Label("Tap **Set Shares to Max Within Headroom** and **Add**.", systemImage: "hand.tap")
                    Text("This uses the bargain element (FMV − Strike) as the per‑share taxable increase. AMT is not modeled in the first release.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            GroupBox("Take a short 1099 contract and stay in range") {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Add **1099 / Contractor** (or **Bonus (1099)**).", systemImage: "briefcase")
                    Label("Enter the expected amount.", systemImage: "number")
                    Label("Verify **Headroom to Next Bracket** remains positive.", systemImage: "gauge")
                }
            }

            GroupBox("Plan a spouse’s W‑2 bonus") {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Add **Bonus (W‑2)**.", systemImage: "gift")
                    Label("Enter the target bonus amount.", systemImage: "number")
                    Label("Adjust as needed to keep headroom.", systemImage: "slider.horizontal.3")
                }
            }
        }
    }

    private var glossary: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Glossary")
                .font(.headline)

            GlossaryRow(term: "Headroom", def: "The dollars remaining before your taxable income reaches the next bracket threshold.")
            GlossaryRow(term: "Taxable Income", def: "Your income after deductions (standard or itemized) that is subject to tax.")
            GlossaryRow(term: "Standard Deduction", def: "A fixed amount that reduces taxable income based on filing status.")
            GlossaryRow(term: "Filing Status", def: "Your federal category (e.g., Single, Married Filing Jointly) which sets brackets and deduction amounts.")
            GlossaryRow(term: "Fair Market Value per Share", def: "The current market price used for equity calculations.")
            GlossaryRow(term: "Exercise (Strike) Price", def: "The per‑share price you pay to exercise a stock option.")
            GlossaryRow(term: "Bargain Element", def: "Fair Market Value per share minus Exercise Price; used to estimate income impact for option exercises.")
            GlossaryRow(term: "Unemployment Compensation", def: "Benefits paid when you’re out of work; generally taxable at the federal level.")
            GlossaryRow(term: "Incentive Stock Option", def: "An employee stock option type with special tax rules (commonly abbreviated ISO).")
            GlossaryRow(term: "Nonqualified Stock Option", def: "An employee stock option type typically taxed as ordinary income on exercise (commonly abbreviated NSO).")
            GlossaryRow(term: "Restricted Stock Unit", def: "A grant that converts to shares at vest; the vesting value is typically ordinary income (commonly abbreviated RSU).")
        }
    }

    private var tips: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tips")
                .font(.headline)
            Label("Use one ledger per tax year. Clone forward each January.", systemImage: "calendar")
            Label("If a year’s tax table JSON is missing, you’ll see a prompt in the header.", systemImage: "exclamationmark.triangle")
            Label("You can delete entries (swipe in the list) and re‑add to iterate.", systemImage: "trash")
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider().padding(.vertical, 4)
            Text("Notes")
                .font(.headline)
            Text("This tool provides planning estimates based on federal tax brackets and your filing profile. It does not provide tax or legal advice.")
                .foregroundStyle(.secondary)
                .font(.footnote)
        }
    }
}

private struct HowToRow: View {
    let number: Int
    let title: String
    let detail: LocalizedStringKey

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            ZStack {
                Circle().fill(Color.secondary.opacity(0.12)).frame(width: 28, height: 28)
                Text(String(number)).font(.subheadline.weight(.semibold))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).foregroundStyle(.secondary)
            }
        }
    }
}

private struct GlossaryRow: View {
    let term: String
    let def: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(term)
                .font(.subheadline.weight(.semibold))
            Text(def)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack { HowToUseView() }
}

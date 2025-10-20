import SwiftUI

struct AboutView: View {
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }
    private var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                differentiators
                headroomExplain
                Divider()
                dataHandling
                privacy
                credits
                footer
            }
            .padding(24)
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("About HeadroomCalc").font(.title.bold())
            Text("Plan income without breaking into the next tax bracket.")
                .foregroundStyle(.secondary)
            HStack(spacing: 16) {
                LabeledContent("Version", value: appVersion)
                LabeledContent("Build", value: appBuild)
            }
        }
    }

    private var dataHandling: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Data Handling").font(.headline)
            VStack(alignment: .leading, spacing: 8) {
                Label("On‑device storage: entries, ledgers, and filing profile are saved locally using SwiftData.", systemImage: "internaldrive")
                Label("No automatic network calls: nothing is uploaded anywhere by the app.", systemImage: "antenna.radiowaves.left.and.right")
                Label("Export is explicit: PDF exports are created in a temporary file and only leave the device if you share them.", systemImage: "square.and.arrow.up")
                Label("Delete anytime: you can remove entries and/or a year from Settings → Data Management.", systemImage: "trash")
                Label("Copy forward: start a new year by cloning last year to keep structure and tweak amounts.", systemImage: "arrow.right.doc.on.clipboard")
            }
            .foregroundStyle(.secondary)
        }
    }

    private var privacy: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Privacy").font(.headline)
            VStack(alignment: .leading, spacing: 8) {
                Label("No account or sign‑in required.", systemImage: "person.crop.circle.badge.xmark")
                Label("No analytics or tracking SDKs.", systemImage: "eye.slash")
                Label("No device permissions needed (camera, contacts, etc.).", systemImage: "hand.raised")
                Label("Your data remains on this device unless you explicitly export/share.", systemImage: "lock.shield")
            }
            .foregroundStyle(.secondary)
        }
    }

    private var differentiators: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What makes Headroom different").font(.headline)
            VStack(alignment: .leading, spacing: 8) {
                Label("Headroom to Next Bracket — see remaining room before the next federal bracket, with the current range.", systemImage: "chart.line.uptrend.xyaxis")
                Label("Multi‑year planning — clone last year with your filing profile to plan raises and bonuses.", systemImage: "arrow.branch")
                Label("Shareable reports — export a PDF summary of your year and entries.", systemImage: "doc.richtext")
                Label("Fully on‑device — SwiftData, offline, no login; includes a startup health‑check and repair.", systemImage: "lock.shield")
            }
            .foregroundStyle(.secondary)
        }
    }

    private var headroomExplain: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How headroom is calculated").font(.headline)
            VStack(alignment: .leading, spacing: 8) {
                Label("We total your current-year taxable income from your entries and filing profile.", systemImage: "sum")
                Label("We look up the next federal bracket threshold for your filing status and year.", systemImage: "chart.bar")
                Label("Headroom = max(0, NextBracketLowerBound − CurrentTaxableIncome).", systemImage: "arrow.up.right.circle")
                Label("This figure focuses on ordinary income headroom; special rates (e.g., long-term capital gains) are not included.", systemImage: "info.circle")
            }
            .foregroundStyle(.secondary)
        }
    }

    private var credits: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Technology").font(.headline)
            VStack(alignment: .leading, spacing: 8) {
                Label("Built with SwiftUI and SwiftData.", systemImage: "swift")
                Label("PDF export via ImageRenderer and UIKit.", systemImage: "doc.richtext")
            }
            .foregroundStyle(.secondary)
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider().padding(.vertical, 4)
            Text("Disclaimer").font(.headline)
            Text("HeadroomCalc provides planning estimates based on your inputs and published federal tax brackets. It does not provide tax or legal advice.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text("Intended for personal use only.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack { AboutView() }
}

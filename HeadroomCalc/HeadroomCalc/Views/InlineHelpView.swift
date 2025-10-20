//  InlineHelpView.swift
//  HeadroomCalc
//
//  Reusable, collapsible help block for AddIncomeSheet and others.
//  Pure SwiftUI view rendering a `TypeHelp` model.
//
//  Created by Jeff Walker on 10/18/25.
//

import SwiftUI

struct InlineHelpView: View {
    let model: TypeHelp
    var onLearnMore: (() -> Void)?
    @State private var expanded: Bool

    init(
        model: TypeHelp,
        initiallyExpanded: Bool = true,
        onLearnMore: (() -> Void)? = nil
    ) {
        self.model = model
        self.onLearnMore = onLearnMore
        _expanded = State(initialValue: initiallyExpanded)
    }

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 8) {
                if !model.bullets.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(model.bullets, id: \.self) { item in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text("•")
                                    .font(.headline)
                                    .accessibilityHidden(true)
                                Text(item)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(.top, 4)
                }

                if !model.examples.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Examples")
                            .font(.subheadline).bold()
                        ForEach(model.examples, id: \.self) { ex in
                            Text(ex)
                                .font(.footnote).italic()
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                    .padding(.top, 6)
                }

                if let foot = model.footnote {
                    Text(foot)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 6)
                }

                if let onLearnMore {
                    Button("Learn more…", action: onLearnMore)
                        .font(.footnote)
                        .padding(.top, 6)
                }
            }
            .padding(.top, 8)
        } label: {
            Label(model.title, systemImage: "questionmark.circle.fill")
                .font(.subheadline.weight(.semibold))
        }
        .padding(12)
        .background(helpBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.2))
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    private var helpBackground: some View {
        #if canImport(UIKit)
        return RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color(UIColor.secondarySystemBackground))
        #else
        return RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color(nsColor: .windowBackgroundColor))
        #endif
    }
}

// Convenience initializer to bridge from IncomeSourceType to TypeHelp
extension InlineHelpView {
    /// Convenience initializer so call sites can pass an IncomeSourceType
    /// without constructing a TypeHelp manually.
    init(type: IncomeSourceType, initiallyExpanded: Bool = true, onLearnMore: (() -> Void)? = nil) {
        self.init(
            model: IncomeTypeHelp.help(for: type),
            initiallyExpanded: initiallyExpanded,
            onLearnMore: onLearnMore
        )
    }
}

#Preview("InlineHelpView") {
    InlineHelpView(
        model: TypeHelp(
            title: "Bonus",
            bullets: [
                "Enter gross amount before withholdings.",
                "Use paystub date.",
            ],
            examples: [
                "Acme — Bonus Q4 2025",
                "Initech — Year‑End Bonus 2025",
            ]
        ),
        initiallyExpanded: true
    )
    .padding()
}

//  IncomeTypeHelp.swift
//  HeadroomCalc
//
//  Mini-help content for each income type. Pure data + tiny helpers.
//  Lives in Helpers. No UIKit/SwiftUI dependencies.
//
//  Created by Jeff Walker on 10/18/25.
//

import Foundation

/// Lightweight model used by InlineHelpView (and anywhere else) to render guidance.
public struct TypeHelp: Sendable, Equatable {
    public let title: String
    public let bullets: [String]
    public let examples: [String]
    public let footnote: String?

    public init(title: String, bullets: [String], examples: [String], footnote: String? = nil) {
        self.title = title
        self.bullets = bullets
        self.examples = examples
        self.footnote = footnote
    }
}

enum IncomeTypeHelp {

    /// Returns guidance content for a given income type.
    static func help(for type: IncomeSourceType, now: Date = Date()) -> TypeHelp {
        switch type {
        case .w2:
            return TypeHelp(
                title: "Salary (W‑2)",
                bullets: [
                    "Enter *gross* salary amounts reflected on paystubs/W‑2.",
                    "Use the pay period or year you want summarized (e.g., 2025).",
                    "Exclude bonuses here — use the Bonus type for those.",
                ],
                examples: [
                    "Acme Corp — Salary 2025",
                    "Globex — Salary 2025",
                ],
                footnote: nil
            )

        case .bonusW2, .bonus1099:
            return TypeHelp(
                title: "Bonus",
                bullets: [
                    "Record the *gross* bonus before withholdings.",
                    "Quarterly or annual naming helps readability (Q1..Q4, Year‑End).",
                    "Date should match the payment/posted date on your paystub.",
                ],
                examples: [
                    "Acme — Bonus Q4 2025",
                    "Initech — Year‑End Bonus 2025",
                ]
            )

        case .restrictedStockUnit:
            return TypeHelp(
                title: "RSU Vest",
                bullets: [
                    "Amount ≈ vested shares × FMV at vest time (ordinary income).",
                    "Taxes are often withheld via share sell‑to‑cover — that’s separate from this amount.",
                    "Name with ticker and vest date for clarity.",
                ],
                examples: [
                    "AAPL — RSU Vest 2025‑11‑15",
                    "MSFT — RSU Vest 2025‑05‑15",
                ],
                footnote: "Capital gains on later sales are not included here."
            )

        case .employeeStockPurchasePlan:
            return TypeHelp(
                title: "ESPP Purchase",
                bullets: [
                    "Record the *discount benefit* portion as ordinary income.",
                    "Purchases are commonly quarterly — include the quarter in the name.",
                    "Keep the actual share sale gains/losses separate.",
                ],
                examples: [
                    "AAPL — ESPP Purchase Q4 2025",
                    "AMZN — ESPP Purchase Q2 2025",
                ]
            )

        case .incentiveStockOption:
            return TypeHelp(
                title: "ISO Exercise",
                bullets: [
                    "App does not compute AMT; this entry is informational for headroom.",
                    "Common naming: include grant year and exercise date.",
                    "If you prefer, track the *bargain element* separately for your records.",
                ],
                examples: [
                    "AAPL — ISO Exercise — Grant 2024 — 2025‑11‑15",
                    "TSLA — ISO Exercise 2025‑06‑03",
                ],
                footnote: "Consult a tax pro for AMT — not modeled here."
            )

        case .nonqualifiedStockOption:
            return TypeHelp(
                title: "NSO Exercise",
                bullets: [
                    "Taxable income ≈ max(FMV − Strike, 0) × shares at exercise.",
                    "Include grant year in the name if useful.",
                    "Sale P/L is separate from the ordinary income at exercise.",
                ],
                examples: [
                    "AAPL — NSO Exercise — Grant 2024 — 2025‑11‑15",
                    "NFLX — NSO Exercise 2025‑02‑10",
                ]
            )

        case .other:
            return TypeHelp(
                title: "Other Income",
                bullets: [
                    "Use for taxable items that don’t fit other categories.",
                    "Include a short description and the year.",
                ],
                examples: [
                    "Signing Bonus — 2025",
                    "Referral Award — 2025",
                ]
            )
        default:
            return TypeHelp(
                title: "Income",
                bullets: [
                    "Provide the gross amount for this entry.",
                    "Use a clear name that includes source and period (month/quarter/year).",
                    "You can edit later; this is for headroom guidance not final tax prep.",
                ],
                examples: [
                    "Generic Source — 2025",
                    "Some Payout — Q4 2025",
                ],
                footnote: nil
            )
        }
    }
}

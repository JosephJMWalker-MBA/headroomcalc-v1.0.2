//
//  NamingSuggestions.swift
//  HeadroomCalc
//
//  Lightweight, pure helpers to propose user-friendly display names
//  for income entries based on type + context (ticker/employer/date).
//
//  Created by Jeff Walker on 10/18/25.
//

import Foundation

/// A namespace for display-name suggestions used by AddIncomeSheet and others.
enum NamingSuggestions {

    /// Primary, single suggestion suitable for an inline "Use suggestion" action.
    static func suggestDisplayName(
        type: IncomeSourceType,
        ticker: String?,
        employer: String?,
        now: Date = Date()
    ) -> String {
        return suggestions(type: type, ticker: ticker, employer: employer, now: now).first ?? fallback(now)
    }

    /// Returns a small ranked set of suggestions (primary first).
    static func suggestions(
        type: IncomeSourceType,
        ticker: String?,
        employer: String?,
        now: Date = Date()
    ) -> [String] {
        let year = Calendar.current.component(.year, from: now)
        let quarter = currentQuarter(from: now)
        let dateStr = Self.ymdString(from: now)
        let co = sanitize(employer)
        let tk = sanitize(ticker)

        switch type {
        case .w2:
            let base = "\(co ?? "Employer") — Salary \(year)"
            return [base]

        case .bonusW2, .bonus1099:
            let q = "\(co ?? "Employer") — Bonus Q\(quarter) \(year)"
            let ye = "\(co ?? "Employer") — Year-End Bonus \(year)"
            return [q, ye]

        case .restrictedStockUnit:
            let t = tk ?? (co ?? "Ticker")
            return ["\(t) — RSU Vest \(dateStr)"]

        case .employeeStockPurchasePlan:
            let t = tk ?? (co ?? "Ticker")
            let q = "\(t) — ESPP Purchase Q\(quarter) \(year)"
            return [q]

        case .incentiveStockOption:
            let t = tk ?? (co ?? "Ticker")
            let grantYear = year - 1
            return [
                "\(t) — ISO Exercise — Grant \(grantYear) — \(dateStr)",
                "\(t) — ISO Exercise \(dateStr)"
            ]

        case .nonqualifiedStockOption:
            let t = tk ?? (co ?? "Ticker")
            let grantYear = year - 1
            return [
                "\(t) — NSO Exercise — Grant \(grantYear) — \(dateStr)",
                "\(t) — NSO Exercise \(dateStr)"
            ]

        case .other:
            return ["Income — \(year)"]

        default:
            let base = (co ?? tk) ?? "Income"
            return ["\(base) — \(year)"]
        }
    }

    // MARK: - Helpers

    private static func sanitize(_ s: String?) -> String? {
        guard let s = s?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return nil }
        return s
    }

    private static func currentQuarter(from date: Date) -> Int {
        let month = Calendar.current.component(.month, from: date)
        return ((month - 1) / 3) + 1
    }

    private static func ymdString(from date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    private static func fallback(_ now: Date) -> String {
        let y = Calendar.current.component(.year, from: now)
        return "Income — \(y)"
    }
}

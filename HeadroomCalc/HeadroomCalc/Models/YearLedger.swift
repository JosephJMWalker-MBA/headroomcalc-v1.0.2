//
//  YearLedger.swift
//  HeadroomCalc
import Foundation
import SwiftData

@Model
final class YearLedger {
    @Attribute(.unique) var year: Int
    var profile: FilingProfile?
    var entries: [IncomeEntry]

    init(year: Int, profile: FilingProfile? = nil, entries: [IncomeEntry] = []) {
        self.year = year
        self.profile = profile
        self.entries = entries
        // Ensure inverse is set for any pre-seeded entries
        for e in self.entries { e.ledger = self }
    }

    // MARK: - Mutation helpers (add only; use modelContext.delete(_) for removals)
    func addEntry(_ entry: IncomeEntry) {
        entry.ledger = self
        entries.append(entry)
    }

    var totalIncome: Double {
        let sum = entries.reduce(0) { acc, e in
            let v = e.amount
            return acc + (v.isFinite ? v : 0)
        }
        return sum.isFinite ? sum : 0
    }
}

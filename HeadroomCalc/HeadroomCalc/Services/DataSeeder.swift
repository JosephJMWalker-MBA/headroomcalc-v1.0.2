//
//  DataSeeder.swift
//  HeadroomCalc
//
//  Created by Jeff Walker on 10/19/25.
//

import Foundation
import SwiftData

/// Seeds safe demo data for first run in DEBUG.
/// Runs only if the persistent store is empty (no entries, ledgers, or filing profiles).
enum DataSeeder {

    enum SeedOutcome: Equatable {
        case didSeed(message: String, year: Int, entries: Int)
        case skipped
    }

    /// Call once at app start (DEBUG only). Safe to call multiple times.
    @discardableResult
    static func seedIfNeeded(in context: ModelContext, now: Date = Date()) -> SeedOutcome {
        #if DEBUG
        // Seed only when the persistent store is truly empty
        guard storeIsEmpty(in: context) else { return .skipped }

        do {
            let year = Calendar.current.component(.year, from: now)
            let ledger = try ensureYearLedger(in: context, for: year)
            _ = try ensureDefaultFilingProfile(in: context, for: year)
            let inserted = try insertSamples(in: context, ledger: ledger, now: now)
            try context.save()
            let message = "Sample data added for \(year). You can modify it or delete it and add your own."
            // Return outcome; caller (e.g., App bootstrap / ContentView) decides how to present UI
            return .didSeed(message: message, year: year, entries: inserted)
        } catch {
            print("DataSeeder: failed with error: \(error)")
            return .skipped
        }
        #else
        return .skipped
        #endif
    }

    // MARK: - Helpers

    private static func storeIsEmpty(in context: ModelContext) -> Bool {
        return count(IncomeEntry.self, in: context) == 0
            && count(YearLedger.self, in: context) == 0
            && count(FilingProfile.self, in: context) == 0
    }

    private static func count<T: PersistentModel>(_ type: T.Type, in context: ModelContext) -> Int {
        do {
            let d = FetchDescriptor<T>()
            return try context.fetchCount(d)
        } catch {
            return 0
        }
    }

    private static func ensureYearLedger(in context: ModelContext, for year: Int) throws -> YearLedger {
        var d = FetchDescriptor<YearLedger>()
        d.predicate = #Predicate { $0.year == year }
        d.fetchLimit = 1
        if let existing = try context.fetch(d).first { return existing }
        let ledger = YearLedger(year: year)
        context.insert(ledger)
        return ledger
    }

    /// Ensure a default `FilingProfile` exists **for the given tax year** so the UI has status + deduction defaults.
    /// Uses safe defaults: `.single` filing status and current standard deduction.
    private static func ensureDefaultFilingProfile(in context: ModelContext, for year: Int) throws -> FilingProfile {
        var d = FetchDescriptor<FilingProfile>()
        d.predicate = #Predicate { $0.year == year }
        d.fetchLimit = 1
        if let existing = try context.fetch(d).first {
            return existing
        }
        // NOTE: adjust numbers to your latest tax-year defaults as needed
        let profile = FilingProfile(year: year, status: .single, standardDeduction: 14600)
        context.insert(profile)
        return profile
    }

    private static func insertSamples(in context: ModelContext, ledger: YearLedger, now: Date) throws -> Int {
        var count = 0
        func add(_ e: IncomeEntry) {
            e.createdAt = now
            ledger.entries.append(e)
            context.insert(e)
            count += 1
        }

        // Base Salary (W-2)
        add(IncomeEntry(
            sourceType: .w2,
            displayName: "Base Salary",
            amount: 120_000
        ))

        // Annual Bonus
        add(IncomeEntry(
            sourceType: .other,
            displayName: "Annual Bonus",
            amount: 15_000
        ))

        // Equity Award (Stock)
        add(IncomeEntry(
            sourceType: .other,
            displayName: "Restricted Stock Vested — 2024",
            amount: 10_000
        ))

        // Interest (1099-INT)
        add(IncomeEntry(
            sourceType: .interest,
            displayName: "High-Yield Savings Interest",
            amount: 420
        ))

        return count
    }
}

import Foundation
import SwiftData
import SwiftUI

/// Summary of fixes applied during a health check.
struct DataRepairReport {
    var fixedNonFinite: Int = 0
    var filledRequired: Int = 0
    var duplicateIDsFixed: Int = 0
    var orphansAttached: Int = 0
    var recentDuplicatesRemoved: Int = 0
}

extension DataRepairReport {
    /// True when no fixes or repairs were needed.
    var isClean: Bool {
        fixedNonFinite == 0 && filledRequired == 0 && duplicateIDsFixed == 0 && orphansAttached == 0 && recentDuplicatesRemoved == 0
    }

    /// Human‑readable, short banner messages summarizing repairs. Empty if `isClean`.
    var bannerMessages: [String] {
        var msgs: [String] = []
        if duplicateIDsFixed > 0 {
            msgs.append("Repaired \(duplicateIDsFixed) duplicate ID\(duplicateIDsFixed == 1 ? "" : "s").")
        }
        if fixedNonFinite > 0 {
            msgs.append("Normalized \(fixedNonFinite) non‑finite value\(fixedNonFinite == 1 ? "" : "s").")
        }
        if filledRequired > 0 {
            msgs.append("Filled \(filledRequired) required field\(filledRequired == 1 ? "" : "s").")
        }
        if orphansAttached > 0 {
            msgs.append("Attached \(orphansAttached) orphan entr\(orphansAttached == 1 ? "y" : "ies") to year ledgers.")
        }
        if recentDuplicatesRemoved > 0 {
            msgs.append("Removed \(recentDuplicatesRemoved) recent duplicate\(recentDuplicatesRemoved == 1 ? "" : "s").")
        }
        return msgs
    }
}

/// One-shot runtime repair pass to stabilize persisted data before views render.
/// Call once on app startup (after ModelContainer is available).
@MainActor
enum StoreHealthChecker {
    /// Convenience: run the health check and return banner messages to present (if any).
    /// Callers should enqueue these **before** other banners (e.g., sample‑data notices) so they appear first.
    static func runAndBannerMessages(in context: ModelContext, removeRecentDuplicates: Bool = true) -> [String] {
        let report = run(in: context, removeRecentDuplicates: removeRecentDuplicates)
        return report.bannerMessages
    }

    /// Run a quick repair pass; safe to call on app launch.
    static func run(in context: ModelContext, removeRecentDuplicates: Bool = true) -> DataRepairReport {
        var report = DataRepairReport()

        // 1) Fetch everything we need.
        let entries: [IncomeEntry] = (try? context.fetch(FetchDescriptor<IncomeEntry>())) ?? []
        var ledgers: [YearLedger] = (try? context.fetch(FetchDescriptor<YearLedger>())) ?? []

        // Helper: locate or create a ledger for a given year.
        func ledger(for year: Int) -> YearLedger {
            if let found = ledgers.first(where: { $0.year == year }) { return found }
            let newLedger = YearLedger(year: year)
            context.insert(newLedger)
            ledgers.append(newLedger)
            return newLedger
        }

        // 2) Ensure unique IDs across entries (guard against merged/migrated duplicates).
        var seenIDs = Set<UUID>()
        for e in entries {
            if seenIDs.contains(e.id) {
                e.id = UUID()
                report.duplicateIDsFixed += 1
            } else {
                seenIDs.insert(e.id)
            }
        }

        // 3) Normalize numbers and required-ish fields to avoid NaN/∞ UI crashes & save failures.
        for e in entries {
            // Non-finite guards
            if !e.amount.isFinite { e.amount = 0; report.fixedNonFinite += 1 }
            if let s = e.shares, !s.isFinite { e.shares = nil; report.fixedNonFinite += 1 }
            if let f = e.fairMarketPrice, !f.isFinite { e.fairMarketPrice = nil; report.fixedNonFinite += 1 }
            if let c = e.costBasisPerShare, !c.isFinite { e.costBasisPerShare = nil; report.fixedNonFinite += 1 }

            // Fill minimal display name if missing
            if e.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                e.displayName = "Income"
                report.filledRequired += 1
            }

            // createdAt sanity (belt & suspenders)
            if e.createdAt.timeIntervalSince1970 <= 0 {
                e.createdAt = Date()
                report.filledRequired += 1
            }
        }

        // 4) Attach orphans to a ledger for their year.
        let cal = Calendar.current
        for e in entries where e.ledger == nil {
            let year = cal.component(.year, from: e.createdAt)
            let y = ledger(for: year)
            // Setting the child side is enough for SwiftData to maintain the inverse.
            e.ledger = y
            report.orphansAttached += 1
        }

        // 5) Remove very-recent duplicates (double-tap protection) — optional.
        if removeRecentDuplicates {
            let grouped = Dictionary(grouping: entries) { (e: IncomeEntry) -> String in
                // Group by type + normalized name + amount (to cents), all folded into a single String key for Hashability.
                let typeKey = String(describing: e.sourceType)
                let nameKey = e.displayName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let amtKey = Int((e.amount * 100).rounded())
                return "\(typeKey)|\(nameKey)|\(amtKey)"
            }
            for (_, group) in grouped {
                // Newest first
                let sorted = group.sorted { $0.createdAt > $1.createdAt }
                var keep: [IncomeEntry] = []
                for e in sorted {
                    if let k = keep.first, abs(e.createdAt.timeIntervalSince(k.createdAt)) <= 1.0 {
                        context.delete(e)
                        report.recentDuplicatesRemoved += 1
                    } else {
                        keep.append(e)
                    }
                }
            }
        }

        // 6) Save once; disable animations to calm list diffs.
        withAnimation(nil) {
            try? context.save()
        }

        #if DEBUG
        print("StoreHealthChecker: fixedNonFinite=\(report.fixedNonFinite), filledRequired=\(report.filledRequired), duplicateIDsFixed=\(report.duplicateIDsFixed), orphansAttached=\(report.orphansAttached), recentDuplicatesRemoved=\(report.recentDuplicatesRemoved)")
        #endif

        return report
    }
}

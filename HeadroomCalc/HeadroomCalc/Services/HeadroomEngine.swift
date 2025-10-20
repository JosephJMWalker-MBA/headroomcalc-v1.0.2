//
//  HeadroomEngine.swift
//  HeadroomCalc
//
import Foundation

struct HeadroomResult {
    let taxableIncome: Double
    let bracketRate: Double
    let bracketLower: Double
    let bracketUpper: Double?     // nil = top bracket
    let dollarsToNextBracket: Double? // nil if top bracket
}

enum HeadroomError: Error {
    case missingProfile
    case tablesUnavailable
}

enum HeadroomEngine {
    static func compute(for ledger: YearLedger) throws -> HeadroomResult {
        guard let profile = ledger.profile else { throw HeadroomError.missingProfile }

        // v1 taxable income: totalIncome - standard deduction (not below zero)
        let taxable = max(0, ledger.totalIncome - profile.standardDeduction)

        let table: TaxTable
        do {
            table = try TaxTableService.shared.taxTable(for: ledger.year, status: profile.status)
        } catch {
            throw HeadroomError.tablesUnavailable
        }

        // find current bracket
        // brackets must be sorted by lower asc.
        let brackets = table.brackets.sorted(by: { $0.lower < $1.lower })
        guard let current = brackets.last(where: { taxable >= $0.lower }) ?? brackets.first else {
            // if no bracket found (e.g., taxable=0), use first
            let b = brackets[0]
            return HeadroomResult(
                taxableIncome: taxable,
                bracketRate: b.rate,
                bracketLower: b.lower,
                bracketUpper: b.upper,
                dollarsToNextBracket: b.upper.map { max(0, $0 - taxable) }
            )
        }

        let toNext = current.upper.map { max(0, $0 - taxable) } // nil at top
        return HeadroomResult(
            taxableIncome: taxable,
            bracketRate: current.rate,
            bracketLower: current.lower,
            bracketUpper: current.upper,
            dollarsToNextBracket: toNext
        )
    }
}

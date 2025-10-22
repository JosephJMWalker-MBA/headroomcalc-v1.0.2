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

struct ScenarioInputs: Equatable {
    var additionalOrdinaryIncome: Double = 0
    var additionalLongTermCapitalGains: Double = 0

    var totalAdjustment: Double {
        additionalOrdinaryIncome + additionalLongTermCapitalGains
    }

    static let zero = ScenarioInputs()
}

enum HeadroomError: Error {
    case missingProfile
    case tablesUnavailable
}

enum HeadroomEngine {
    static func compute(for ledger: YearLedger) throws -> HeadroomResult {
        try compute(for: ledger, applying: .zero)
    }

    static func compute(for ledger: YearLedger, applying adjustments: ScenarioInputs) throws -> HeadroomResult {
        guard let profile = ledger.profile else { throw HeadroomError.missingProfile }

        // v1 taxable income: totalIncome - standard deduction (not below zero)
        let adjustedTotal = ledger.totalIncome + adjustments.totalAdjustment
        let taxable = max(0, adjustedTotal - profile.standardDeduction)

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

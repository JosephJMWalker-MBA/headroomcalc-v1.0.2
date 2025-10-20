//
//  TaxTableService.swift
//  HeadroomCalc
//
import Foundation

struct TaxBracket: Codable {
    let lower: Double          // inclusive
    let upper: Double?         // nil = no upper cap (top bracket)
    let rate: Double           // e.g. 0.12 for 12%
}

struct TaxTable: Codable {
    let year: Int
    let status: FilingStatus
    let brackets: [TaxBracket]
}

enum TaxTableError: Error {
    case fileMissing
    case decodeFailed
    case noTableForStatus
}

final class TaxTableService {
    static let shared = TaxTableService()

    private var cache: [String: TaxTable] = [:] // key: "\(year)-\(status.rawValue)"

    func taxTable(for year: Int, status: FilingStatus) throws -> TaxTable {
        let key = "\(year)-\(status.rawValue)"
        if let cached = cache[key] { return cached }

        let filename = "TaxBrackets_\(year)"
        guard let url = Bundle.main.url(forResource: filename, withExtension: "json") else {
            throw TaxTableError.fileMissing
        }
        let data = try Data(contentsOf: url)
        let allTables = try JSONDecoder().decode([TaxTable].self, from: data)
        guard let match = allTables.first(where: { $0.status == status }) else {
            throw TaxTableError.noTableForStatus
        }
        cache[key] = match
        return match
    }
}
// MARK: - Priming convenience
extension TaxTableService {
    /// Warm the in-memory cache for a given year/status list.
    func prime(year: Int, statuses: [FilingStatus]) {
        for s in statuses {
            _ = try? taxTable(for: year, status: s)
        }
    }

    /// Warm cache for the current calendar year.
    func primeCurrentYear(statuses: [FilingStatus]) {
        let y = Calendar.current.component(.year, from: Date())
        prime(year: y, statuses: statuses)
    }
}

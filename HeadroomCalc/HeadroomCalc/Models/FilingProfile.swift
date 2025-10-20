//
//  FilingProfile.swift
//  HeadroomCalc
import Foundation
import SwiftData

enum FilingStatus: String, Codable, CaseIterable, Identifiable {
    case single = "Single"
    case marriedJoint = "Married Filing Jointly"
    case marriedSeparate = "Married Filing Separately"
    case headOfHousehold = "Head of Household"

    var id: String { rawValue }
}

extension FilingProfile {
    /// Return the first profile for a given year & status, or nil if not found.
    static func fetch(year: Int, status: FilingStatus, in context: ModelContext) throws -> FilingProfile? {
        let descriptor = FetchDescriptor<FilingProfile>(
            predicate: #Predicate { $0.year == year && $0.status == status },
            sortBy: []
        )
        return try context.fetch(descriptor).first
    }

    /// Fetch an existing profile for the given year & status, or create/insert one with the provided defaults.
    @discardableResult
    static func fetchOrInsert(
        year: Int,
        status: FilingStatus,
        in context: ModelContext,
        defaultStandardDeduction: Double = 14600
    ) throws -> FilingProfile {
        if let existing = try fetch(year: year, status: status, in: context) {
            return existing
        }
        let profile = FilingProfile(year: year, status: status, standardDeduction: defaultStandardDeduction)
        context.insert(profile)
        return profile
    }

    /// Ensure a profile exists for every FilingStatus for a given year. Returns the full set.
    @discardableResult
    static func ensureAllStatuses(
        for year: Int,
        in context: ModelContext,
        defaultStandardDeduction: Double = 14600
    ) throws -> [FilingProfile] {
        var results: [FilingProfile] = []
        for status in FilingStatus.allCases {
            let item = try fetchOrInsert(
                year: year,
                status: status,
                in: context,
                defaultStandardDeduction: defaultStandardDeduction
            )
            results.append(item)
        }
        return results
    }
}

@Model
final class FilingProfile {
    var year: Int
    var status: FilingStatus
    var standardDeduction: Double   // v1: simple; can evolve by year/age later

    init(year: Int,
         status: FilingStatus = .single,
         standardDeduction: Double = 14600) {
        self.year = year
        self.status = status
        self.standardDeduction = standardDeduction
    }

    /// Convenience initializer that defaults to the current calendar year.
    convenience init(status: FilingStatus = .single,
                     standardDeduction: Double = 14600) {
        let currentYear = Calendar.current.component(.year, from: Date())
        self.init(year: currentYear, status: status, standardDeduction: standardDeduction)
    }
}

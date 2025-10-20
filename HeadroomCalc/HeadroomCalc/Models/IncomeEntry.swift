//
//  IncomeEntry.swift
//  HeadroomCalc
//
import Foundation
import SwiftData

@Model
final class IncomeEntry {
    @Attribute(.unique) var id: UUID = UUID()
    var createdAt: Date
    var sourceType: IncomeSourceType
    var displayName: String
    var amount: Double
    var symbol: String?
    var ledger: YearLedger?

    // Optional equity metadata
    var shares: Double?
    var fairMarketPrice: Double?
    var costBasisPerShare: Double?

    init(sourceType: IncomeSourceType,
         displayName: String,
         amount: Double,
         shares: Double? = nil,
         fairMarketPrice: Double? = nil,
         costBasisPerShare: Double? = nil,
         id: UUID = UUID()) {
        self.createdAt = .now
        self.sourceType = sourceType
        self.displayName = displayName
        self.amount = amount
        self.shares = shares
        self.fairMarketPrice = fairMarketPrice
        self.costBasisPerShare = costBasisPerShare
        self.id = id
    }

    // Fallback initializer to ensure valid defaults when a zero-arg init is used (e.g., previews)
    convenience init() {
        self.init(sourceType: .w2, displayName: "", amount: 0)
    }
}

//
//  IncomeSourceType.swift
//  HeadroomCalc
//
import Foundation

/// Canonical list of income sources the app supports.
/// Raw value is the user-facing label. Provides helpers for grouping,
/// stable keys, and compatibility decoding.
enum IncomeSourceType: String, CaseIterable, Codable, Identifiable, Hashable, Sendable {
    case w2 = "W-2 Wages"
    case bonusW2 = "Bonus (W-2)"
    case form1099 = "1099 / Contractor"
    case bonus1099 = "Bonus (1099)"
    case socialSecurity = "Social Security"
    case unemploymentCompensation = "Unemployment Compensation"
    case pension = "Pension / Annuity"
    case iraWithdrawal = "IRA / 401k Withdrawal"
    case capitalGains = "Capital Gains"
    case dividends = "Dividends"
    case interest = "Interest"
    case restrictedStockUnit = "Restricted Stock Unit"
    case incentiveStockOption = "Incentive Stock Option"
    case nonqualifiedStockOption = "Nonqualified Stock Option"
    case employeeStockPurchasePlan = "Employee Stock Purchase Plan"
    case rental = "Rental Income"
    case business = "Business Income"
    case other = "Other"

    // Stable identity equals the display label.
    var id: String { rawValue }

    // MARK: - Classification

    /// High-level grouping for UI sections and reporting.
    enum Category: String, Codable {
        case wages, bonus, contractor1099, equity, investment, retirement, benefits, rental, business, other
    }

    var category: Category {
        switch self {
        case .w2: return .wages
        case .bonusW2, .bonus1099: return .bonus
        case .form1099: return .contractor1099
        case .restrictedStockUnit, .incentiveStockOption, .nonqualifiedStockOption, .employeeStockPurchasePlan:
            return .equity
        case .capitalGains, .dividends, .interest:
            return .investment
        case .pension, .iraWithdrawal:
            return .retirement
        case .socialSecurity, .unemploymentCompensation:
            return .benefits
        case .rental:
            return .rental
        case .business:
            return .business
        case .other:
            return .other
        }
    }

    var isEquity: Bool {
        switch self {
        case .restrictedStockUnit, .incentiveStockOption, .nonqualifiedStockOption, .employeeStockPurchasePlan:
            return true
        default:
            return false
        }
    }

    var isStockOption: Bool {
        switch self {
        case .incentiveStockOption, .nonqualifiedStockOption:
            return true
        default:
            return false
        }
    }

    var isBonus: Bool {
        switch self {
        case .bonusW2, .bonus1099:
            return true
        default:
            return false
        }
    }

    /// Stable, lowercase token for keys/URLs/analytics.
    var shortCode: String {
        switch self {
        case .w2: return "w2"
        case .bonusW2: return "bonus_w2"
        case .form1099: return "1099"
        case .bonus1099: return "bonus_1099"
        case .socialSecurity: return "social_security"
        case .unemploymentCompensation: return "unemployment"
        case .pension: return "pension"
        case .iraWithdrawal: return "ira_withdrawal"
        case .capitalGains: return "capital_gains"
        case .dividends: return "dividends"
        case .interest: return "interest"
        case .restrictedStockUnit: return "rsu"
        case .incentiveStockOption: return "iso"
        case .nonqualifiedStockOption: return "nso"
        case .employeeStockPurchasePlan: return "espp"
        case .rental: return "rental"
        case .business: return "business"
        case .other: return "other"
        }
    }

    /// Component used for feature-flag / tip keys; stable and aligned with `shortCode`.
    var tipKeyComponent: String { shortCode }

    /// Human-friendly section header for lists, derived from `category`.
    var sectionTitle: String {
        switch category {
        case .wages: return "Wages"
        case .bonus: return "Bonuses"
        case .contractor1099: return "Contractor (1099)"
        case .equity: return "Equity"
        case .investment: return "Investments"
        case .retirement: return "Retirement"
        case .benefits: return "Benefits"
        case .rental: return "Rental"
        case .business: return "Business"
        case .other: return "Other"
        }
    }

    /// Deterministic ordering for menus and pickers.
    static var allCasesSorted: [IncomeSourceType] {
        allCases.sorted { $0.uiSortIndex < $1.uiSortIndex }
    }

    /// Sort index for deterministic UI ordering.
    var uiSortIndex: Int {
        switch self {
        case .w2: return 10
        case .bonusW2: return 11
        case .form1099: return 20
        case .bonus1099: return 21
        case .business: return 30
        case .rental: return 40
        case .restrictedStockUnit: return 50
        case .incentiveStockOption: return 51
        case .nonqualifiedStockOption: return 52
        case .employeeStockPurchasePlan: return 53
        case .capitalGains: return 60
        case .dividends: return 61
        case .interest: return 62
        case .socialSecurity: return 70
        case .pension: return 71
        case .iraWithdrawal: return 72
        case .unemploymentCompensation: return 80
        case .other: return 99
        }
    }

    // MARK: - Codable compatibility

    /// Backward-compatible decoding: accept legacy abbreviations (RSU/ISO/NSO/ESPP),
    /// and looser text forms.
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        switch value {
        case "RSU": self = .restrictedStockUnit
        case "ISO": self = .incentiveStockOption
        case "NSO": self = .nonqualifiedStockOption
        case "ESPP": self = .employeeStockPurchasePlan
        case "1099 / Contractor": self = .form1099
        case "Unemployment": self = .unemploymentCompensation
        case "UI": self = .unemploymentCompensation
        default:
            if let s = IncomeSourceType(rawValue: value) {
                self = s
            } else {
                // Additional lenient mappings
                switch value.lowercased() {
                case "1099", "form 1099", "contractor": self = .form1099
                case "w2", "w-2": self = .w2
                case "unemployment", "unemployment compensation", "ui": self = .unemploymentCompensation
                case "bonus w2", "bonus (w2)": self = .bonusW2
                case "bonus 1099", "bonus (1099)": self = .bonus1099
                default:
                    throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown income source: \(value)")
                }
            }
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}

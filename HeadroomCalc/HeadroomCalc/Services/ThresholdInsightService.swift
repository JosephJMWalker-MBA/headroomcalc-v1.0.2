import Foundation

struct ThresholdDetail: Identifiable {
    enum Kind: String {
        case irmaa
        case niit
        case qbi
    }

    let key: String
    let label: String
    let limit: Double
    let kind: Kind

    var id: String { key }

    func taxableEquivalent(standardDeduction: Double) -> Double {
        switch kind {
        case .irmaa, .niit, .qbi:
            return max(0, limit - standardDeduction)
        }
    }
}

struct ThresholdInsight: Identifiable {
    enum Status {
        case clear
        case approaching
        case exceeded
    }

    let detail: ThresholdDetail
    let status: Status
    let proximity: Double

    var id: String { detail.id }
}

struct TaxThresholds {
    let irmaaTiers: [ThresholdDetail]
    let niit: ThresholdDetail
    let qbi: ThresholdDetail
}

final class ThresholdInsightService {
    static let shared = ThresholdInsightService()

    private init() {}

    func insights(for ledger: YearLedger,
                  applying adjustments: ScenarioInputs = .zero) -> [ThresholdInsight] {
        guard let profile = ledger.profile,
              let thresholds = thresholds(for: ledger.year, status: profile.status) else {
            return []
        }

        let totalIncome = ledger.totalIncome + adjustments.totalAdjustment
        var results: [ThresholdInsight] = []

        if let nextIRMAA = nextTier(for: totalIncome, tiers: thresholds.irmaaTiers) {
            let proximity = nextIRMAA.limit - totalIncome
            results.append(ThresholdInsight(detail: nextIRMAA,
                                            status: status(for: proximity, limit: nextIRMAA.limit),
                                            proximity: proximity))
        }

        let niitDelta = thresholds.niit.limit - totalIncome
        results.append(ThresholdInsight(detail: thresholds.niit,
                                        status: status(for: niitDelta, limit: thresholds.niit.limit),
                                        proximity: niitDelta))

        let qbiDelta = thresholds.qbi.limit - totalIncome
        results.append(ThresholdInsight(detail: thresholds.qbi,
                                        status: status(for: qbiDelta, limit: thresholds.qbi.limit),
                                        proximity: qbiDelta))

        return results.sorted { lhs, rhs in
            switch (lhs.status, rhs.status) {
            case (.exceeded, .approaching), (.exceeded, .clear), (.approaching, .clear):
                return true
            case (.approaching, .exceeded), (.clear, .exceeded), (.clear, .approaching):
                return false
            default:
                return lhs.proximity < rhs.proximity
            }
        }
    }

    func thresholds(for year: Int, status: FilingStatus) -> TaxThresholds? {
        if let match = dataset[year]?[status] {
            return match
        }

        // Fallback to nearest lower year, then higher.
        if let nearestYear = dataset.keys.sorted(by: <).last(where: { $0 < year }),
           let match = dataset[nearestYear]?[status] {
            return match
        }
        if let nearestYear = dataset.keys.sorted(by: <).first(where: { $0 > year }),
           let match = dataset[nearestYear]?[status] {
            return match
        }
        return nil
    }

    // MARK: - Helpers

    private func status(for delta: Double, limit: Double) -> ThresholdInsight.Status {
        if delta <= 0 { return .exceeded }
        let warningBand = max(5000, limit * 0.1)
        if delta <= warningBand { return .approaching }
        return .clear
    }

    private func nextTier(for income: Double, tiers: [ThresholdDetail]) -> ThresholdDetail? {
        if let next = tiers.first(where: { income < $0.limit }) {
            return next
        }
        return tiers.last
    }

    private let dataset: [Int: [FilingStatus: TaxThresholds]] = {
        func makeThresholds(single irmaaSingle: [Double],
                            marriedJoint irmaaJoint: [Double],
                            marriedSeparate irmaaSeparate: [Double],
                            hoh irmaaHOH: [Double],
                            niitSingle: Double,
                            niitJoint: Double,
                            niitSeparate: Double,
                            qbiSingle: Double,
                            qbiJoint: Double) -> [FilingStatus: TaxThresholds] {
            func irmaaTiers(prefix: String, values: [Double]) -> [ThresholdDetail] {
                values.enumerated().map { index, value in
                    ThresholdDetail(key: "irmaa_\(prefix)_tier_\(index)",
                                     label: "IRMAA Tier \(index + 1)",
                                     limit: value,
                                     kind: .irmaa)
                }
            }

            let singleTiers = irmaaTiers(prefix: "single", values: irmaaSingle)
            let jointTiers = irmaaTiers(prefix: "mfj", values: irmaaJoint)
            let separateTiers = irmaaTiers(prefix: "mfs", values: irmaaSeparate)
            let hohTiers = irmaaTiers(prefix: "hoh", values: irmaaHOH)

            let niitSingleDetail = ThresholdDetail(key: "niit_single",
                                                   label: "NIIT Threshold",
                                                   limit: niitSingle,
                                                   kind: .niit)
            let niitJointDetail = ThresholdDetail(key: "niit_joint",
                                                  label: "NIIT Threshold",
                                                  limit: niitJoint,
                                                  kind: .niit)
            let niitSeparateDetail = ThresholdDetail(key: "niit_separate",
                                                     label: "NIIT Threshold",
                                                     limit: niitSeparate,
                                                     kind: .niit)

            let qbiSingleDetail = ThresholdDetail(key: "qbi_single",
                                                  label: "QBI Phase-in",
                                                  limit: qbiSingle,
                                                  kind: .qbi)
            let qbiJointDetail = ThresholdDetail(key: "qbi_joint",
                                                 label: "QBI Phase-in",
                                                 limit: qbiJoint,
                                                 kind: .qbi)

            return [
                .single: TaxThresholds(irmaaTiers: singleTiers,
                                       niit: niitSingleDetail,
                                       qbi: qbiSingleDetail),
                .marriedJoint: TaxThresholds(irmaaTiers: jointTiers,
                                             niit: niitJointDetail,
                                             qbi: qbiJointDetail),
                .marriedSeparate: TaxThresholds(irmaaTiers: separateTiers,
                                                niit: niitSeparateDetail,
                                                qbi: qbiSingleDetail),
                .headOfHousehold: TaxThresholds(irmaaTiers: hohTiers,
                                                niit: niitSingleDetail,
                                                qbi: qbiSingleDetail)
            ]
        }

        return [
            2024: makeThresholds(single: [103_000, 129_000, 161_000, 193_000, 500_000],
                                 marriedJoint: [206_000, 258_000, 322_000, 386_000, 750_000],
                                 marriedSeparate: [103_000, 129_000, 161_000, 193_000, 500_000],
                                 hoh: [103_000, 129_000, 161_000, 193_000, 500_000],
                                 niitSingle: 200_000,
                                 niitJoint: 250_000,
                                 niitSeparate: 125_000,
                                 qbiSingle: 191_100,
                                 qbiJoint: 382_200),
            2025: makeThresholds(single: [106_000, 133_000, 166_000, 199_000, 510_000],
                                 marriedJoint: [212_000, 266_000, 332_000, 398_000, 770_000],
                                 marriedSeparate: [106_000, 133_000, 166_000, 199_000, 510_000],
                                 hoh: [106_000, 133_000, 166_000, 199_000, 510_000],
                                 niitSingle: 200_000,
                                 niitJoint: 250_000,
                                 niitSeparate: 125_000,
                                 qbiSingle: 196_000,
                                 qbiJoint: 392_000)
        ]
    }()
}

//  TipStateStore.swift
//  HeadroomCalc
//
//  Persist lightweight UI tip/help state (e.g., whether inline help
//  was collapsed, or a naming suggestion banner was dismissed).
//  No SwiftUI dependency; safe for Services/Helpers layer.
//
//  Created by Jeff Walker on 10/18/25.
//

import Foundation

/// Keys for persisted tip/help state. Narrow and explicit on purpose.
enum TipKey: Hashable, Sendable {
    case inlineHelp(IncomeSourceType)          // expanded/collapsed state
    case namingSuggestion(IncomeSourceType)    // dismissed banner state
    case custom(String)                        // escape hatch for future tips
}

@MainActor
public final class TipStateStore: ObservableObject {
    /// Singleton convenience for simple wiring. You can also init per scene if preferred.
    public static let shared = TipStateStore()

    private let defaults: UserDefaults
    private let prefix = "tips."

    /// Bump this to notify SwiftUI when values change.
    @Published private(set) var changeTick: UInt = 0

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - High‑level conveniences

    /// Whether inline help for a given type should render expanded.
    /// Default is `true` (show help on first encounter).
    func isHelpExpanded(for type: IncomeSourceType) -> Bool {
        value(for: .inlineHelp(type), default: true)
    }

    /// Persist inline help expansion state.
    func setHelpExpanded(for type: IncomeSourceType, expanded: Bool) {
        set(.inlineHelp(type), to: expanded)
    }

    /// Whether the naming suggestion banner has been dismissed for a type.
    /// Default is `false` (show suggestion until dismissed).
    func isNamingSuggestionDismissed(for type: IncomeSourceType) -> Bool {
        value(for: .namingSuggestion(type), default: false)
    }

    /// Persist naming suggestion dismissal.
    func setNamingSuggestionDismissed(for type: IncomeSourceType, dismissed: Bool = true) {
        set(.namingSuggestion(type), to: dismissed)
    }

    // MARK: - Generic Bool accessors

    /// Read a boolean setting for a key (with explicit default).
    func value(for key: TipKey, default defaultValue: Bool) -> Bool {
        let k = namespaced(key)
        if let obj = defaults.object(forKey: k) as? NSNumber { return obj.boolValue }
        return defaultValue
    }

    /// Write a boolean setting and publish a change tick.
    func set(_ key: TipKey, to newValue: Bool) {
        defaults.set(newValue, forKey: namespaced(key))
        changeTick &+= 1
    }

    /// Remove a stored value (will revert to defaults on next read).
    func reset(_ key: TipKey) {
        defaults.removeObject(forKey: namespaced(key))
        changeTick &+= 1
    }

    // MARK: - Key building

    private func namespaced(_ key: TipKey) -> String {
        return prefix + rawKey(key)
    }

    private func rawKey(_ key: TipKey) -> String {
        switch key {
        case .inlineHelp(let t):        return "help.inline." + typeKey(t)
        case .namingSuggestion(let t):  return "name.suggestion." + typeKey(t)
        case .custom(let s):            return "custom." + s
        }
    }

    private func typeKey(_ t: IncomeSourceType) -> String {
        // Delegate to IncomeSourceType so key mapping stays in one place
        return t.tipKeyComponent
    }
}

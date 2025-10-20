//
//  AppState.swift
//  HeadroomCalc
//
import SwiftUI

@MainActor final class AppState: ObservableObject {
    init() {}
    @Published private(set) var bannerQueue: [String] = []

    func enqueueBanner(_ message: String) {
        bannerQueue.append(message)
    }
    func popBanner() -> String? {
        guard !bannerQueue.isEmpty else { return nil }
        return bannerQueue.removeFirst()
    }
}

// Back-compat alias for older references in views
typealias HeadroomAppState = AppState

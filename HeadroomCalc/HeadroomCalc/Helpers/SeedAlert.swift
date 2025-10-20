//
//  SeedAlert.swift
//  HeadroomCalc
import SwiftUI
import Combine

// Bridge a typed notification name used by DataSeeder
extension Notification.Name {
    static let didSeedSampleData = Notification.Name("DataSeeder.didSeedSampleData")
}

private struct SeededDataAlert: ViewModifier {
    @State private var show = UserDefaults.standard.bool(forKey: "DataSeeder.didSeedOnLaunch")
    @State private var message = ""

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .didSeedSampleData)) { note in
                message = (note.userInfo?["message"] as? String)
                    ?? "Sample data was added. You can modify or delete it."
                show = true
                // one-shot: clear so it won’t reappear next launch
                UserDefaults.standard.set(false, forKey: "DataSeeder.didSeedOnLaunch")
            }
            .alert("Sample data added", isPresented: $show) {
                Button("OK") {}
            } message: {
                Text(message)
            }
    }
}

extension View {
    func seedAlertIfNeeded() -> some View { modifier(SeededDataAlert()) }
}

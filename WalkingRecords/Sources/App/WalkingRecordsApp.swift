//
//  WalkingRecordsApp.swift
//  WalkingRecords
//
//  Created by Arkadiy KAZAZYAN on 24/09/2025.
//

// MARK: - WalkingRecordsApp.swift
import SwiftUI
#if !SQLITEDATA
import SwiftData
#endif
import ComposableArchitecture

@main
struct MainApp: App {
    var body: some Scene {
        WindowGroup {
            WalkTrackerView(store: Store(initialState: WalkTrackerReducer.State()) { WalkTrackerReducer() })
        }
    }
#if SQLITEDATA
    init() {
        do {
            try prepareDependencies {
                try $0.bootstrapDatabase()
            }
        } catch {
            // You could log this to a logging framework, crashlytics, etc.
            print("Failed to prepare dependencies: \(error)")
            // Optionally handle the error more gracefully, e.g., by showing a UI alert
        }
    }
#endif
}

//
//  DatabaseServiceKey.swift
//  WalkingRecords
//
//  Created by Arkadiy KAZAZYAN on 24/09/2025.
//
#if !SQLITEDATA
import Foundation
import ComposableArchitecture
import SwiftData

// MARK: - Dependency Keys

enum DatabaseServiceKey: DependencyKey {
    static let liveValue: any DatabaseServiceProtocol = {
        do {
            let schema = Schema([ WalkSession.self, LocationPoint.self ])
            let modelConfiguration = ModelConfiguration(schema: schema)
            let container = try ModelContainer(for: schema, configurations: modelConfiguration)
            return SwiftDataService(modelContainer: container)
        } catch {
            fatalError("Failed to create test DatabaseService: \(error.localizedDescription)")
        }
    }()
    static let testValue: any DatabaseServiceProtocol = liveValue
    static let previewValue: any DatabaseServiceProtocol = liveValue
}

// MARK: - Dependency Registration
extension DependencyValues {
    var databaseService: any DatabaseServiceProtocol {
        get { self[DatabaseServiceKey.self] }
        set { self[DatabaseServiceKey.self] = newValue }
    }
}
#endif

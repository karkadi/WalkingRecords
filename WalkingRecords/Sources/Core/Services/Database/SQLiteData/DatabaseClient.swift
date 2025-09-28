//
//  DatabaseClient.swift
//  WalkingRecords
//
//  Created by Arkadiy KAZAZYAN on 26/09/2025.
//
#if SQLITEDATA
import ComposableArchitecture
import SQLiteData
import Foundation

// MARK: - Live Implementation
final class DefaultDatabaseClient: DatabaseServiceProtocol {
    // MARK: - Dependencies
    @Dependency(\.defaultDatabase) private var database
    
    func createWalk(startDate: Date) async throws -> WalkSessionDTO {
        let walk = WalkSessionSql(startTime: startDate)
        do {
            try await database.write { sqlDb in
                try WalkSessionSql
                    .insert { walk }
                    .execute(sqlDb)
            }
        } catch {
            print(error)
            throw error
        }
        // Return the DTO with the actual ID that was inserted
        return WalkSessionDTO(from: walk, points: [])
    }
    
    func endWalk(walkId: UUID, totalDistance: Double, endDate: Date) async throws {
        guard var walk = try await fetchWalkModel(for: walkId) else {
            throw WalkError.walkNotFound
        }
        walk.endTime = endDate
        walk.totalDistance = totalDistance
        
        // Capture the walk by value to avoid concurrency issues
        let walkToUpdate = walk
        do {
            try await database.write { sqlDb in
                try WalkSessionSql
                    .upsert { walkToUpdate }
                    .execute(sqlDb)
            }
        } catch {
            print(error)
            throw error
        }
    }
    
    func addLocations(walkId: UUID, points: [LocationPointDTO]) async throws {
        for locationPoint in points {
            let walkPoint = LocationPointSql(from: locationPoint, walkId: walkId)
            do {
                try await database.write { sqlDb in
                    try LocationPointSql
                        .insert { walkPoint }
                        .execute(sqlDb)
                }
            } catch {
                print(error)
                throw error
            }
        }
    }
    
    func fetchWalk(for walkId: UUID) async throws -> WalkSessionDTO? {
        guard let walk = try await fetchWalkModel(for: walkId) else {
            throw WalkError.walkNotFound
        }
        let locations = try await fetchAllLocations(for: walkId)
        return WalkSessionDTO(from: walk, points: locations)
    }
    
    func fetchAllWalks() async throws -> [WalkSessionDTO] {
        let walks: [WalkSessionSql] = try await database.read { sqlDb in
            try WalkSessionSql
                .order(by: \.startTime)
                .fetchAll(sqlDb)
        }
        
        var result: [WalkSessionDTO] = []
        for walk in walks {
            let locations = try await fetchAllLocations(for: walk.id)
            result.append(WalkSessionDTO(from: walk, points: locations))
        }
        return result
    }
    
    func deleteWalk(walkId: UUID) async throws {
        do {
            try await database.write { sqlDb in
                try WalkSessionSql
                    .where { $0.id.eq(walkId) }
                    .delete()
                    .execute(sqlDb)
            }
        } catch {
            print(error)
            throw error
        }
    }
    
    func importWalk(from url: URL) async throws {
        do {
            let text = try readFile(from: url)
            guard let walk = WalkSessionDTO.importGPX(text) else {
                return
            }
            
            let walkSql = WalkSessionSql(from: walk)
            do {
                try await database.write { sqlDb in
                    try WalkSessionSql
                        .insert { walkSql }
                        .execute(sqlDb)
                }
                
                try await addLocations(walkId: walkSql.id, points: walk.points)
            } catch {
                print(error)
                throw error
            }
        } catch {
            print("Permission check failed: \(error)")
            throw error
        }
    }
    
    private func fetchWalkModel(for walkId: UUID) async throws -> WalkSessionSql? {
        do {
            return try await database.read { sqlDb in
                try WalkSessionSql
                    .where { $0.id.eq(walkId) }
                    .fetchOne(sqlDb)
            }
        } catch {
            print("Failed to fetch walk model: \(error)")
            throw error
        }
    }
    
    private func fetchAllLocations(for walkId: UUID) async throws -> [LocationPointDTO] {
        var locations: [LocationPointSql] = []
        do {
            locations = try await database.read { sqlDb in
                try LocationPointSql
                    .where { $0.walkSessionID.eq(walkId) }
                    .order(by: \.timestamp)
                    .fetchAll(sqlDb)
            }
        } catch {
            print(error)
            throw error
        }
        return locations.map { LocationPointDTO(from: $0) }
    }
    
    private func readFile(from url: URL) throws -> String {
        // Gain temporary access
        let needsAccess = url.startAccessingSecurityScopedResource()
        defer {
            if needsAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        // Now you can safely read
        return try String(contentsOf: url, encoding: .utf8)
    }
    
}

// MARK: - Dependency Keys
enum DatabaseClientKey: DependencyKey {
    static let liveValue: any DatabaseServiceProtocol = DefaultDatabaseClient()
}

// MARK: - Dependency Registration
extension DependencyValues {
    var databaseClient: DatabaseServiceProtocol {
        get { self[DatabaseClientKey.self] }
        set { self[DatabaseClientKey.self] = newValue }
    }
}
#endif

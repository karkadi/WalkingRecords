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

// MARK: - Database Client (Closure-based)
struct DatabaseClient: Sendable {
    var createWalk: @Sendable (_ startDate: Date) async throws -> WalkSessionDTO
    var endWalk: @Sendable (_ walkId: UUID, _ totalDistance: Double, _ endDate: Date) async throws -> Void
    var addLocations: @Sendable (_ walkId: UUID, _ points: [LocationPointDTO]) async throws -> Void
    var fetchWalk: @Sendable (_ walkId: UUID) async throws -> WalkSessionDTO?
    var fetchAllWalks: @Sendable () async throws -> [WalkSessionDTO]
    var deleteWalk: @Sendable (_ walkId: UUID) async throws -> Void
    var importWalk: @Sendable (_ url: URL) async throws -> Void
}

// MARK: - Live Implementation
extension DatabaseClient: DependencyKey {
    static let liveValue: DatabaseClient = {
        @Dependency(\.defaultDatabase) var database
        
        return DatabaseClient(
            createWalk: { startDate in
                let walk = WalkSessionSql(startTime: startDate)
                try await database.write { sqlDb in
                    try WalkSessionSql.insert { walk }.execute(sqlDb)
                }
                return WalkSessionDTO(from: walk, points: [])
            },
            
            endWalk: { walkId, totalDistance, endDate in
                guard var walk = try await fetchWalkModel(database, walkId) else {
                    throw WalkError.walkNotFound
                }
                walk.endTime = endDate
                walk.totalDistance = totalDistance
                let walkToUpdate = walk
                try await database.write { sqlDb in
                    try WalkSessionSql.upsert { walkToUpdate }.execute(sqlDb)
                }
            },
            
            addLocations: { walkId, points in
                for locationPoint in points {
                    let walkPoint = LocationPointSql(from: locationPoint, walkId: walkId)
                    try await database.write { sqlDb in
                        try LocationPointSql.insert { walkPoint }.execute(sqlDb)
                    }
                }
            },
            
            fetchWalk: { walkId in
                guard let walk = try await fetchWalkModel(database, walkId) else {
                    throw WalkError.walkNotFound
                }
                let locations = try await fetchAllLocations(database, walkId)
                return WalkSessionDTO(from: walk, points: locations)
            },
            
            fetchAllWalks: {
                let walks: [WalkSessionSql] = try await database.read { sqlDb in
                    try WalkSessionSql.order(by: \.startTime).fetchAll(sqlDb)
                }
                return try await walks.asyncMap { walk in
                    let locations = try await fetchAllLocations(database, walk.id)
                    return WalkSessionDTO(from: walk, points: locations)
                }
            },
            
            deleteWalk: { walkId in
                try await database.write { sqlDb in
                    try WalkSessionSql
                        .where { $0.id.eq(walkId) }
                        .delete()
                        .execute(sqlDb)
                }
            },
            
            importWalk: { url in
                let text = try readFile(from: url)
                guard let walk = WalkSessionDTO.importGPX(text) else { return }
                let walkSql = WalkSessionSql(from: walk)
                
                try await database.write { sqlDb in
                    try WalkSessionSql.insert { walkSql }.execute(sqlDb)
                }
                try await DatabaseClient.liveValue.addLocations(walkSql.id, walk.points)
            }
        )
    }()
}

// MARK: - Dependency Registration
extension DependencyValues {
    var databaseClient: DatabaseClient {
        get { self[DatabaseClient.self] }
        set { self[DatabaseClient.self] = newValue }
    }
}

// MARK: - Helpers (private free functions)
private func fetchWalkModel(_ database: DatabaseWriter, _ walkId: UUID) async throws -> WalkSessionSql? {
    try await database.read { sqlDb in
        try WalkSessionSql.where { $0.id.eq(walkId) }.fetchOne(sqlDb)
    }
}

private func fetchAllLocations(_ database: DatabaseWriter, _ walkId: UUID) async throws -> [LocationPointDTO] {
    let locations: [LocationPointSql] = try await database.read { sqlDb in
        try LocationPointSql
            .where { $0.walkSessionID.eq(walkId) }
            .order(by: \.timestamp)
            .fetchAll(sqlDb)
    }
    return locations.map { LocationPointDTO(from: $0) }
}

private func readFile(from url: URL) throws -> String {
    let needsAccess = url.startAccessingSecurityScopedResource()
    defer { if needsAccess { url.stopAccessingSecurityScopedResource() } }
    return try String(contentsOf: url, encoding: .utf8)
}

// MARK: - Async map helper
extension Array {
    func asyncMap<T>(_ transform: @Sendable (Element) async throws -> T) async rethrows -> [T] {
        var results: [T] = []
        results.reserveCapacity(count)
        for element in self {
            try await results.append(transform(element))
        }
        return results
    }
}

#endif

//
//  SwiftDataService.swift
//  WalkingRecords
//
//  Created by Arkadiy KAZAZYAN on 24/09/2025.
//
#if !SQLITEDATA
import Foundation
import SwiftData
import ComposableArchitecture

// MARK: - Safe Actor for SwiftData
actor SwiftDataActor {
    private let modelContext: ModelContext
    
    init(container: ModelContainer) {
        self.modelContext = ModelContext(container)
    }
    
    func createWalk(startDate: Date) throws -> WalkSessionDTO {
        let walk = WalkSession(startTime: startDate)
        modelContext.insert(walk)
        try modelContext.save()
        return WalkSessionDTO(from: walk)
    }
    
    func endWalk(walkId: UUID, totalDistance: Double, endDate: Date) throws {
        guard let walk = try fetchWalkDataModel(for: walkId) else {
            throw WalkError.walkNotFound
        }
        walk.endTime = endDate
        walk.totalDistance = totalDistance
        try modelContext.save()
    }
    
    func addLocations(walkId: UUID, points: [LocationPointDTO]) throws {
        guard let walk = try fetchWalkDataModel(for: walkId) else {
            throw WalkError.walkNotFound
        }
        let locations = points.map { LocationPoint(from: $0) }
        walk.points = locations
        try modelContext.save()
    }
    
    func fetchAllWalks() throws -> [WalkSessionDTO] {
        let descriptor = FetchDescriptor<WalkSession>(
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        let walks = try modelContext.fetch(descriptor)
        return walks.map { WalkSessionDTO(from: $0) }
    }
    
    func deleteWalk(walkId: UUID) throws {
        guard let walk = try fetchWalkDataModel(for: walkId) else {
            throw WalkError.walkNotFound
        }
        modelContext.delete(walk)
        try modelContext.save()
    }
    
    func fetchWalk(for walkId: UUID) throws -> WalkSessionDTO? {
        guard let walk = try fetchWalkDataModel(for: walkId) else { return nil }
        return WalkSessionDTO(from: walk)
    }
    
    func importWalk(from url: URL) throws {
        let text = try readFile(from: url)
        guard let walk = WalkSessionDTO.importGPX(text) else { return }
        modelContext.insert(WalkSession(from: walk))
        try modelContext.save()
    }
    
    // MARK: - Private
    private func fetchWalkDataModel(for walkId: UUID) throws -> WalkSession? {
        let predicate = #Predicate<WalkSession> { $0.id == walkId }
        let descriptor = FetchDescriptor<WalkSession>(predicate: predicate)
        return try modelContext.fetch(descriptor).first
    }
    
    private func readFile(from url: URL) throws -> String {
        let needsAccess = url.startAccessingSecurityScopedResource()
        defer { if needsAccess { url.stopAccessingSecurityScopedResource() } }
        return try String(contentsOf: url, encoding: .utf8)
    }
}

// MARK: - Sendable Service
struct DatabaseClient: Sendable {
    var createWalk: @Sendable (_ startDate: Date) async throws -> WalkSessionDTO
    var endWalk: @Sendable (_ walkId: UUID, _ totalDistance: Double, _ endDate: Date) async throws -> Void
    var addLocations: @Sendable (_ walkId: UUID, _ points: [LocationPointDTO]) async throws -> Void
    var fetchAllWalks: @Sendable () async throws -> [WalkSessionDTO]
    var deleteWalk: @Sendable (_ walkId: UUID) async throws -> Void
    var fetchWalk: @Sendable (_ walkId: UUID) async throws -> WalkSessionDTO?
    var importWalk: @Sendable (_ url: URL) async throws -> Void
}

// MARK: - Live Value
extension DatabaseClient: DependencyKey {
    static let liveValue: DatabaseClient = {
        do {
            let schema = Schema([ WalkSession.self, LocationPoint.self ])
            let config = ModelConfiguration(schema: schema)
            let container = try ModelContainer(for: schema, configurations: config)
            let actor = SwiftDataActor(container: container)
            
            return DatabaseClient(
                createWalk: { startDate in try await actor.createWalk(startDate: startDate) },
                endWalk: { id, dist, end in try await actor.endWalk(walkId: id, totalDistance: dist, endDate: end) },
                addLocations: { id, points in try await actor.addLocations(walkId: id, points: points) },
                fetchAllWalks: { try await actor.fetchAllWalks() },
                deleteWalk: { id in try await actor.deleteWalk(walkId: id) },
                fetchWalk: { id in try await actor.fetchWalk(for: id) },
                importWalk: { url in try await actor.importWalk(from: url) }
            )
        } catch {
            fatalError("Failed to create DatabaseClient: \(error.localizedDescription)")
        }
    }()
}

extension DependencyValues {
    var databaseClient: DatabaseClient {
        get { self[DatabaseClient.self] }
        set { self[DatabaseClient.self] = newValue }
    }
}
#endif

//
//  SwiftDataService.swift
//  WalkingRecords
//
//  Created by Arkadiy KAZAZYAN on 24/09/2025.
//
#if !SQLITEDATA
import Foundation
import SwiftData

actor SwiftDataService: DatabaseServiceProtocol {
    private let modelContainer: ModelContainer
    private var modelContext: ModelContext
    
    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        self.modelContext = ModelContext(modelContainer)
    }
    
    func createWalk(startDate: Date) async throws -> WalkSessionDTO {
        let walk = WalkSession(startTime: startDate)
        modelContext.insert(walk)
        try modelContext.save()
        return WalkSessionDTO(from: walk)
    }
    
    func endWalk(walkId: UUID, totalDistance: Double, endDate: Date) async throws {
        guard let walk = try await fetchWalkDataModel(for: walkId) else {
            throw WalkError.walkNotFound
        }
        walk.endTime = endDate
        walk.totalDistance = totalDistance
        try modelContext.save()
    }
    
    func addLocations(walkId: UUID, points: [LocationPointDTO]) async throws {
        guard let walk = try await fetchWalkDataModel(for: walkId) else {
            throw WalkError.walkNotFound
        }
        let locations = points.map { LocationPoint(from: $0) }
        walk.points = locations
        try modelContext.save()
    }
    
    func fetchAllWalks() async throws -> [WalkSessionDTO] {
        let descriptor = FetchDescriptor<WalkSession>(sortBy: [SortDescriptor(\.startTime, order: .reverse)])
        let walks = try modelContext.fetch(descriptor)
        return walks.map { WalkSessionDTO(from: $0) }
    }
    
    func deleteWalk(walkId: UUID) async throws {
        guard let walk = try await fetchWalkDataModel(for: walkId) else {
            throw WalkError.walkNotFound
        }
        modelContext.delete(walk)
        try modelContext.save()
    }
    
    func fetchWalk(for walkId: UUID) async throws -> WalkSessionDTO? {
        guard let walk = try await fetchWalkDataModel(for: walkId) else {
            return nil
        }
        return WalkSessionDTO(from: walk)
    }
    
    func importWalk(from url: URL) async throws {
        do {
            let text = try readFile(from: url)
            guard let walk = WalkSessionDTO.importGPX(text) else {
                return
            }
            modelContext.insert(WalkSession(from: walk))
            try modelContext.save()
        } catch {
            print("Permission check failed: \(error)")
            throw error
        }
    }
    
    private func fetchWalkDataModel(for walkId: UUID) async throws -> WalkSession? {
         let predicate = #Predicate<WalkSession> { $0.id == walkId }
         let descriptor = FetchDescriptor<WalkSession>(predicate: predicate)
         let walk = try modelContext.fetch(descriptor).first
         return walk
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
#endif

//
//  DatabaseServiceProtocol.swift
//  WalkingRecords
//
//  Created by Arkadiy KAZAZYAN on 28/09/2025.
//
import Foundation

// MARK: - Errors
enum WalkError: Error, Equatable {
    case walkNotFound
}

enum DatabaseError: Error {
    case saveFailed
}

// sourcery: AutoMockable
protocol DatabaseServiceProtocol {
    func createWalk(startDate: Date) async throws -> WalkSessionDTO
    func endWalk(walkId: UUID, totalDistance: Double, endDate: Date) async throws
    func addLocations(walkId: UUID, points: [LocationPointDTO]) async throws
    func fetchWalk(for walkId: UUID) async throws -> WalkSessionDTO?
    func fetchAllWalks() async throws -> [WalkSessionDTO]
    func deleteWalk(walkId: UUID) async throws
    func importWalk(from url: URL) async throws
}

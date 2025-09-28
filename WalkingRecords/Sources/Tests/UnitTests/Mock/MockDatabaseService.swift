//
//  MockDatabaseService.swift
//  InstagramLikeApp
//
//  Created by Arkadiy KAZAZYAN on 10/04/2025.
//

@testable import WalkingRecords
import Foundation

// Mock implementation of DatabaseClient
struct MockDatabaseClient: DatabaseServiceProtocol {
    var mockedError: Error?
    var mockFetchAllWalksResult: [WalkSessionDTO] = []
    
    // Add more mutable properties for different functions
    var mockCreateWalkResult: WalkSessionDTO?
    var mockFetchWalkResult: WalkSessionDTO?
    var shouldThrowError = false
    
    func createWalk(startDate: Date) async throws -> WalkSessionDTO {
        if let error = mockedError { throw error }
        return mockCreateWalkResult ?? WalkSessionDTO(id: UUID(), startTime: startDate, totalDistance: 0.0, points: [])
    }
    
    func endWalk(walkId: UUID, totalDistance: Double, endDate: Date) async throws {
        if let error = mockedError { throw error }
        // You could add more control here if needed
    }
    
    func addLocations(walkId: UUID, points: [LocationPointDTO]) async throws {
        if let error = mockedError { throw error }
    }
    
    func fetchWalk(for walkId: UUID) async throws -> WalkSessionDTO? {
        if let error = mockedError { throw error }
        return mockFetchWalkResult
    }
    
    func fetchAllWalks() async throws -> [WalkSessionDTO] {
        if let error = mockedError { throw error }
        return mockFetchAllWalksResult
    }
    
    func deleteWalk(walkId: UUID) async throws {
        if let error = mockedError { throw error }
    }
    
    func importWalk(from url: URL) async throws {
        if let error = mockedError { throw error }
    }
}

// Simple error type for testing
enum TestError: Error, Equatable {
    case generic
}

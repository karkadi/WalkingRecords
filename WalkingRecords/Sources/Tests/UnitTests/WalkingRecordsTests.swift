//
//  WalkingRecordsTests.swift
//  WalkingRecordsTests
//
//  Created by Arkadiy KAZAZYAN on 24/09/2025.
//

import Testing
@testable import WalkingRecords
import ComposableArchitecture
import CoreLocationClient

extension TestStore {
    nonisolated func setExhaustivity(_ exhaustivity: Exhaustivity) async {
        await MainActor.run {
            self.exhaustivity = exhaustivity
        }
    }
}

@MainActor
@Suite("WalkingRecords Tests")
struct WalkingRecordsTests {
    
    @Test("Initial State")
    func testInitialState() async {
        let store = TestStore(initialState: WalkTrackerReducer.State()) {
            WalkTrackerReducer()
        }
        
        #expect(store.state.trackingState == .stopped)
        #expect(store.state.points.isEmpty)
        #expect(store.state.totalDistance == 0.0)
        #expect(store.state.pastSessions.isEmpty)
        #expect(store.state.showSession == nil)
    }
    
    @Test func testToggleTrackingStartsTracking() async {
        let store = TestStore(initialState: WalkTrackerReducer.State()) {
            WalkTrackerReducer()
        } withDependencies: {
            $0.locationManager.startUpdatingLocation = { }
            $0.locationManager.delegate = { .never }
            $0.locationManager.stopUpdatingLocation = { }
        }
        await store.setExhaustivity(.off)
        
        await store.send(.view(.startTracking)) {
            $0.trackingState = .active
            // $0.currentSessionStartTime = Date()
            $0.points = []
            $0.showSession = nil
            $0.totalDistance = 0.0
        }
        
    }
    
    @Test func testToggleTrackingStopsTracking() async {
        let store = TestStore(initialState: WalkTrackerReducer.State(trackingState: .active)) {
            WalkTrackerReducer()
        } withDependencies: {
            $0.locationManager.startUpdatingLocation = { }
            $0.locationManager.delegate = { .never }
            $0.locationManager.stopUpdatingLocation = { }
            //  $0.databaseClient = MockDatabaseClient()
            $0.databaseClient = DatabaseClient(createWalk: { _ in
                WalkSessionDTO(id: UUID(), startTime: Date(), endTime: Date(), totalDistance: 0, points: [])
            },
                                               endWalk: { _, _, _ in },
                                               addLocations: { _, _ in },
                                               fetchAllWalks: { [] },
                                               deleteWalk: { _ in },
                                               fetchWalk: { _ in nil},
                                               importWalk: { _ in })
        }
        await store.setExhaustivity(.off)
        
        await store.send(.view(.stopTracking)) {
            $0.trackingState = .stopped
        }
        
        await store.receive(\.endWalk)
    }
    
    @Test func testLocationUpdateAddsPointAndCalculatesDistance() async {
        let initialLocation = CLLocation(
            latitude: 37.33018,
            longitude: -122.023907
        )
        
        let secondLocation = CLLocation(
            latitude: 37.33028,
            longitude: -122.023907
        )
        
        let store = TestStore(initialState: WalkTrackerReducer.State(trackingState: .active)) {
            WalkTrackerReducer()
        }
        
        await store.withExhaustivity(.off) {
            await store.send(.locationManager(.didUpdateLocations([Location(rawValue: initialLocation)]))) {
                let point = LocationPointDTO(timestamp: Date(), coordinate: initialLocation.coordinate)
                $0.points = [point]
                $0.mapCamera.centerCoordinate = initialLocation.coordinate
                $0.cameraPosition = .camera($0.mapCamera)
            }
            
            await store.send(.locationManager(.didUpdateLocations([Location(rawValue: secondLocation)]))) {
                let secondPoint = LocationPointDTO(timestamp: Date(), coordinate: secondLocation.coordinate)
                $0.points.append(secondPoint)
                let expectedDistance = initialLocation.distance(from: secondLocation)
                $0.totalDistance = expectedDistance
                $0.mapCamera.centerCoordinate = secondLocation.coordinate
                $0.cameraPosition = .camera($0.mapCamera)
            }
        }
    }
    
    @Test func testFetchWalksSuccess() async {
        let mockWalks = [
            WalkSessionDTO(
                id: UUID(),
                startTime: Date(),
                endTime: Date().addingTimeInterval(3600),
                totalDistance: 5000.0,
                points: []
            )
        ]
        
        let store = TestStore(initialState: WalkTrackerReducer.State()) {
            WalkTrackerReducer()
        } withDependencies: {
            $0.databaseClient = DatabaseClient(createWalk: { _ in
                WalkSessionDTO(id: UUID(), startTime: Date(), endTime: Date(), totalDistance: 0, points: [])
            },
                                               endWalk: { _, _, _ in },
                                               addLocations: { _, _ in },
                                               fetchAllWalks: { mockWalks },
                                               deleteWalk: { _ in },
                                               fetchWalk: { _ in nil},
                                               importWalk: { _ in })
            
        }
        
        await store.send(.fetchWalks)
        await store.receive(\.walksResponse) {
            $0.pastSessions = mockWalks
        }
    }
    
    @Test func testFetchWalksFailure() async throws {
        struct TestError: Error, Equatable {
            let message = "Test error"
        }
        let testError = TestError()
        
        let store = TestStore(initialState: WalkTrackerReducer.State()) {
            WalkTrackerReducer()
        } withDependencies: {
            $0.databaseClient = DatabaseClient(createWalk: { _ in
                WalkSessionDTO(id: UUID(), startTime: Date(), endTime: Date(), totalDistance: 0, points: [])
            },
                                               endWalk: { _, _, _ in },
                                               addLocations: { _, _ in },
                                               fetchAllWalks: { throw testError},
                                               deleteWalk: { _ in },
                                               fetchWalk: { _ in nil},
                                               importWalk: { _ in })
        }
        await store.setExhaustivity(.off)
        
        await store.send(.fetchWalks)
        await store.receive(\.walksResponse) {
            $0.error = testError
        }
    }
    
    @Test func testDisplayWalkTogglesSessionDisplay() async {
        let walk = WalkSessionDTO(
            id: UUID(),
            startTime: Date(),
            endTime: Date().addingTimeInterval(3600),
            totalDistance: 5000.0,
            points: []
        )
        
        let store = TestStore(initialState: WalkTrackerReducer.State()) {
            WalkTrackerReducer()
        }
        
        await store.send(.view(.displayWalk(walk))) {
            $0.showSession = walk
        }
        
        await store.send(.view(.displayWalk(walk))) {
            $0.showSession = nil
        }
    }
    
    @Test func testDeleteWalk() async throws {
        let walkId = UUID()
        let mockWalks = [
            WalkSessionDTO(
                id: walkId,
                startTime: Date(),
                endTime: Date().addingTimeInterval(3600),
                totalDistance: 5000.0,
                points: []
            )
        ]
        
        let store = TestStore(initialState: WalkTrackerReducer.State(pastSessions: mockWalks)) {
            WalkTrackerReducer()
        } withDependencies: {
            $0.databaseClient = DatabaseClient(createWalk: { _ in
                WalkSessionDTO(id: UUID(), startTime: Date(), endTime: Date(), totalDistance: 0, points: [])
            },
                                               endWalk: { _, _, _ in },
                                               addLocations: { _, _ in },
                                               fetchAllWalks: { [] },
                                               deleteWalk: { _ in },
                                               fetchWalk: { _ in nil},
                                               importWalk: { _ in })
        }
        await store.setExhaustivity(.off)
        
        await store.send(.view(.deleteWalk(IndexSet(integer: 0))))
        await store.receive(\.fetchWalks)
        await store.receive(\.walksResponse) {
            $0.pastSessions = []
        }
    }
    
    @Test func testShowSettings() async {
        let store = TestStore(initialState: WalkTrackerReducer.State()) {
            WalkTrackerReducer()
        }
        await store.setExhaustivity(.off)
        
        await store.send(.view(.showSettings)) {
            $0.settings = SettingsReducer.State()
        }
    }
    
    @Test func testDurationCalculationWhileTracking() async {
        let startTime = Date()
        let store = TestStore(initialState: WalkTrackerReducer.State(
            trackingState: .active,
            currentSessionStartTime: startTime
        )) {
            WalkTrackerReducer()
        }
        
        let duration = store.state.duration
        #expect(duration != nil)
    }
    
    @Test func testDurationCalculationForCompletedWalk() async {
        let startTime = Date()
        let endTime = startTime.addingTimeInterval(3600)
        let walk = WalkSessionDTO(
            id: UUID(),
            startTime: startTime,
            endTime: endTime,
            totalDistance: 5000.0,
            points: []
        )
        
        let store = TestStore(initialState: WalkTrackerReducer.State(showSession: walk)) {
            WalkTrackerReducer()
        }
        
        let duration = store.state.duration
        #expect(duration == "1 h 0 m 0 s")
    }
    
    @Test func testOnAppearFetchesWalksAndRequestsLocation() async throws {
        let store = TestStore(initialState: WalkTrackerReducer.State()) {
            WalkTrackerReducer()
        } withDependencies: {
            $0.locationManager.requestAlwaysAuthorization = { }
            $0.databaseClient = DatabaseClient(createWalk: { _ in
                WalkSessionDTO(id: UUID(), startTime: Date(), endTime: Date(), totalDistance: 0, points: [])
            },
                                               endWalk: { _, _, _ in },
                                               addLocations: { _, _ in },
                                               fetchAllWalks: { [] },
                                               deleteWalk: { _ in },
                                               fetchWalk: { _ in nil},
                                               importWalk: { _ in })
        }
        await store.withExhaustivity(.off) {
            await store.send(.view(.onAppear))
            await store.receive(\.fetchWalks)
            await store.receive(\.walksResponse) {
                $0.pastSessions = []
            }
        }
    }
}

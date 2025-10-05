//
//  WalkTrackerReducer.swift
//  WalkingRecords
//
//  Created by Arkadiy KAZAZYAN on 24/09/2025.
//
import MapKit
import SwiftUI
import ComposableArchitecture
import CoreLocationClient

// MARK: - TCA Reducer
@Reducer
struct WalkTrackerReducer {
    enum TrackingState {
        case paused
        case stopped
        case active
    }
    
    // MARK: - State
    @ObservableState
    struct State: Equatable {
        @Presents var settings: SettingsReducer.State?
        @Shared(.appStorage("exportPrecision")) var exportPrecision: Double = 1.0
        
        var mapCamera: MapCamera = .init(centerCoordinate: .init(latitude: 37.33018, longitude: -122.023907),
                                         distance: 0,
                                         heading: 0,
                                         pitch: 0)
        var cameraPosition: MapCameraPosition = .automatic
        var span: MKCoordinateSpan = .init(latitudeDelta: 0.001, longitudeDelta: 0.001)
        
        var trackingState: TrackingState = .stopped
        var showSession: WalkSessionDTO?
        var pastSessions: [WalkSessionDTO] = []
        
        var exportURL: URL?
        
        var points: [LocationPointDTO] = []
        var totalDistance: Double = 0.0
        var currentSessionStartTime: Date?
        var isExportingFile: Bool = false
        var isImportingFile: Bool = false
        var showStopMenu: Bool = false
        var error: Error?
        
        static func == (lhs: WalkTrackerReducer.State, rhs: WalkTrackerReducer.State) -> Bool {
            lhs.trackingState == rhs.trackingState &&
            lhs.showSession == rhs.showSession &&
            lhs.pastSessions == rhs.pastSessions &&
            lhs.currentSessionStartTime == rhs.currentSessionStartTime &&
            lhs.exportURL == rhs.exportURL
        }
        
        var duration: String? {
            if trackingState == .active, let startTime = currentSessionStartTime {
                return Date().timeIntervalSince(startTime).detailedDuration
            } else if let session = showSession, let endTime = session.endTime {
                return endTime.timeIntervalSince(session.startTime).detailedDuration
            } else {
                return nil
            }
        }
        
        var averageSpeed: String? {
            if let session = showSession {
                // Calculate average speed for displayed session
                guard let endTime = session.endTime else { return nil }
                let durationInHours = endTime.timeIntervalSince(session.startTime) / 3600.0
                guard durationInHours > 0 else { return nil }
                
                let speedKmH = session.totalDistance / 1000.0 / durationInHours
                return String(format: "%.1f km/h", speedKmH)
            } else if trackingState == .active, let startTime = currentSessionStartTime {
                // Calculate current average speed for active session
                let durationInHours = Date().timeIntervalSince(startTime) / 3600.0
                guard durationInHours > 0 else { return nil }
                
                let speedKmH = totalDistance / 1000.0 / durationInHours
                return String(format: "%.1f km/h", speedKmH)
            }
            return nil
        }
    }
    
    enum Action: ViewAction, BindableAction {
        case binding(BindingAction<State>)
        case fetchWalks
        case walksResponse(Result<[WalkSessionDTO], Error>)
        case locationManager(LocationManager.Action)
        case endWalk
        case settings(PresentationAction<SettingsReducer.Action>)
        
        case view(View)
        // swiftlint:disable nesting
        enum View {
            case onAppear
            case startTracking
            case stopTracking
            case pauseTracking
            case resumeTracking
            case showSettings
            case deleteWalk(IndexSet)
            case displayWalk(WalkSessionDTO)
            case exportSession(WalkSessionDTO)
            case importDocument(URL)
            case mapSpanChanged(MapCameraUpdateContext)
        }
        // swiftlint:enable nesting
    }
    
    @Dependency(\.locationManager) private var locationManager: LocationManager
#if SQLITEDATA
    @Dependency(\.databaseClient) private var databaseClient
#else
    @Dependency(\.databaseClient) private var databaseClient
#endif
    
    public var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce(core)
            .ifLet(\.$settings, action: \.settings) {
                SettingsReducer()
            }
    }
    
    // MARK: - Reducer
    private func core(
        _ state: inout State,
        _ action: Action
    ) -> Effect<Action> {
        switch action {
        case let .view(viewAction):
            return handleViewAction(&state, viewAction)
            
        case .fetchWalks:
            return handleFetchWalks()
            
        case .walksResponse(.success(let walks)):
            state.pastSessions = walks
            return .none
            
        case .walksResponse(.failure(let error)):
            print("Error fetching walks: \(error)")
            state.error = error
            return .none
            
        case .locationManager(.didUpdateLocations(let location)):
            return handleLocationUpdate(&state, location)
            
        case .locationManager:
            return .none
            
        case .endWalk:
            return handleEndWalk(&state)
            
        case .binding:
            return .none
            
        case .settings(.presented(.view(.cancelButtonTapped))):
            state.settings = nil
            return .none
            
        case .settings:
            return .none
        }
    }
    
    // MARK: - View Action Handlers
    private func handleViewAction(_ state: inout State, _ action: Action.View) -> Effect<Action> {
        switch action {
        case .onAppear:
            return .run { send in
                await send(.fetchWalks)
                await locationManager.requestAlwaysAuthorization()
            }
            
        case .showSettings:
            state.settings = SettingsReducer.State()
            return .none
            
        case .mapSpanChanged(let context):
            state.mapCamera = context.camera
            state.span = context.region.span
            return .none
            
        case .startTracking:
            return handleStartTracking(&state)
            
        case .stopTracking:
            return handleStopTracking(&state)
            
        case .pauseTracking:
            return handlePauseTracking(&state)
            
        case .resumeTracking:
            return handleResumeTracking(&state)
            
        case .deleteWalk(let offsets):
            return handleDeleteWalk(&state, offsets)
            
        case .exportSession(let session):
            return handleExportSession(&state, session)
            
        case .importDocument(let url):
            return handleImportDocument(url)
            
        case .displayWalk(let walk):
            return handleDisplayWalk(&state, walk)
        }
    }
    
    private func handleStartTracking(_ state: inout State) -> Effect<Action> {
        state.currentSessionStartTime = Date()
        state.points = []
        state.showSession = nil
        state.totalDistance = 0.0
        return handleResumeTracking(&state)
    }
    
    private func handleStopTracking(_ state: inout State) -> Effect<Action> {
        state.trackingState = .stopped
        return .run { send in
            await locationManager.stopUpdatingLocation()
            await send(.endWalk)
        }
    }
    
    private func handlePauseTracking(_ state: inout State) -> Effect<Action> {
        state.trackingState = .paused
        return .run { _ in
            await locationManager.stopUpdatingLocation()
        }
    }

    private func handleResumeTracking(_ state: inout State) -> Effect<Action> {
        state.trackingState = .active
        return .run { send in
            await locationManager.startUpdatingLocation()
            for await action in await locationManager.delegate() {
                await send(.locationManager(action), animation: .default)
            }
        }
    }
    
    private func handleDeleteWalk(_ state: inout State, _ offsets: IndexSet) -> Effect<Action> {
        let walkIds = offsets.map { state.pastSessions[$0].id }
        return .run { send in
            for walkId in walkIds {
                try await databaseClient.deleteWalk(walkId)
            }
            await send(.fetchWalks)
        } catch: { error, _ in
            print("Error deleting walk: \(error)")
        }
    }
    
    private func handleExportSession(_ state: inout State, _ session: WalkSessionDTO) -> Effect<Action> {
        if let url = session.exportGPX(precision: state.exportPrecision).writeToTemporaryFile(named: "WalkSession.txt") {
            state.exportURL = url
            state.isExportingFile = true
        }
        return .none
    }
    
    private func handleImportDocument(_ url: URL) -> Effect<Action> {
        return .run { send in
            try await databaseClient.importWalk(url)
            await send(.fetchWalks)
        }
    }
    
    private func handleDisplayWalk(_ state: inout State, _ walk: WalkSessionDTO) -> Effect<Action> {
        if state.showSession == walk {
            state.showSession = nil
        } else {
            state.showSession = walk
            
            // Calculate region that fits all points
            if let region = walk.regionForPoints {
                state.cameraPosition = .region(region)
            } else if let lastLocation = walk.points.last {
                // Fallback to last location if region calculation fails
                state.cameraPosition = .region(
                    MKCoordinateRegion(
                        center: lastLocation.coordinate,
                        span: state.span
                    )
                )
            }
        }
        return .none
    }
    
    // MARK: - Database Handlers
    private func handleFetchWalks() -> Effect<Action> {
        return .run { send in
            do {
                let walks = try await databaseClient.fetchAllWalks()
                await send(.walksResponse(.success(walks)))
            } catch {
                await send(.walksResponse(.failure(error)))
            }
        }
    }
    
    private func handleEndWalk(_ state: inout State) -> Effect<Action> {
        return .run { [points = state.points, totalDistance = state.totalDistance] send in
            let startDate = points.first?.timestamp ?? Date()
            let walk = try await databaseClient.createWalk(startDate)
            try await databaseClient.addLocations(walk.id, points)
            try await databaseClient.endWalk(walk.id,
                                              totalDistance,
                                              Date())
            
            await send(.fetchWalks)
        }
    }
    
    // MARK: - Location Handlers
    private func handleLocationUpdate(_ state: inout State, _ location: [Location]) -> Effect<Action> {
        guard let firstLocation = location.first else { return .none }
        
        print("Processing location update in reducer: \(firstLocation.coordinate.latitude), \(firstLocation.coordinate.longitude)")
        if let previousPoint = state.points.last {
            state.totalDistance += previousPoint.location.distance(from: firstLocation.rawValue)
        }
        
        let point = LocationPointDTO(timestamp: Date(),
                                     coordinate: firstLocation.coordinate)
        state.points.append(point)
        
        state.mapCamera.centerCoordinate = firstLocation.rawValue.coordinate
        state.cameraPosition = .camera(state.mapCamera)
        
        return .none
    }
}

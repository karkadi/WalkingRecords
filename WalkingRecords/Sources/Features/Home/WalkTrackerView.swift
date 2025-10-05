//
//  WalkTrackerView.swift
//  WalkingRecords
//
//  Created by Arkadiy KAZAZYAN on 24/09/2025.
//

import SwiftUI
import MapKit
import ComposableArchitecture
import Metal

@ViewAction(for: WalkTrackerReducer.self)
struct WalkTrackerView: View {
    @Bindable var store: StoreOf<WalkTrackerReducer>
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            Map(position: $store.cameraPosition) {
                UserAnnotation()
                
                let points = store.showSession?.points ?? store.points
                if points.count > 1 {
                    MapPolyline(coordinates: points
                        .sorted { $0.timestamp < $1.timestamp }
                        .map { $0.coordinate })
                    .stroke(.blue, lineWidth: 4)
                }
            }
            .mapControls {
                MapCompass()
                MapUserLocationButton()
                MapPitchToggle()
                MapScaleView()
            }
            .controlSize(.large)
            .onMapCameraChange { context in
                send(.mapSpanChanged(context))
            }
            
            headerView
                .padding()
        }
        .accessibilityLabel("Walk path map")
        .customPopover(showPopover: .constant(true)) {
            popoverContent
        }
        .sheet(
            item: $store.scope(state: \.settings, action: \.settings)
        ) { settingsStore in
            SettingsView(store: settingsStore)
                .padding()
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            send(.onAppear)
        }
        .fileExporter(
            isPresented: $store.isExportingFile,
            document: TextFileDocument(url: store.exportURL),
            contentType: .plainText,
            defaultFilename: "WalkSession"
        ) { _ in
        }
        .fileImporter(
            isPresented: $store.isImportingFile,
            allowedContentTypes: [.plainText]
        ) { result in
            if case let .success(url) = result {
                send(.importDocument(url))
            }
        }
    }
    
    private var headerView: some View {
        HStack {
            VStack {
                Text("Distance:")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .accessibilityLabel("Distance")
                
                Text("\((store.showSession?.totalDistance ?? store.totalDistance), specifier: "%.0f") m")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .accessibilityLabel("Distance Value")
            }
            
            if let duration = store.duration {
                VStack {
                    Text("Duration:")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .accessibilityLabel("Duration")
                    
                    Text(duration)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .accessibilityLabel("Current Duration")
                }
                .padding(.leading)
            }
            
            if let averageSpeed = store.averageSpeed {
                VStack {
                    Text("Avg Speed:")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .accessibilityLabel("Average Speed")
                    
                    Text(averageSpeed)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .accessibilityLabel("Average Speed Value")
                }
                .padding(.leading)
            }
            
            Spacer()
        }
    }
    
    private var popoverContent: some View {
        VStack(alignment: .center) {
            HStack {
                Button(
                    action: {
                        store.isImportingFile = true
                    },
                    label: {
                        Image(systemName: "square.and.arrow.down")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 24.0, height: 24.0)
                    }
                )
                .padding(.horizontal)
                
                WalkingManView(isWaling: store.trackingState == .active, width: 50.0)
                    .offset(y: -4.0)
                    .padding(.horizontal)
                
                Spacer()
                
                switch store.trackingState {
                case .active:
                    Button(
                        action: {
                            store.showStopMenu = true
                        },
                        label: {
                            Image(systemName: "stop.circle")
                                .resizable()
                                .scaledToFill()
                                .frame(width: 50.0, height: 50.0)
                                .tint(.red)
                        }
                    )
                case .stopped:
                    Button(
                        action: {
                            send(.startTracking)
                        },
                        label: {
                            Image(systemName: "record.circle")
                                .resizable()
                                .scaledToFill()
                                .frame(width: 50.0, height: 50.0)
                                .tint(.red)
                        }
                    )
                case .paused:
                    Button(
                        action: {
                            send(.resumeTracking)
                        },
                        label: {
                            Image(systemName: "playpause.circle")
                                .resizable()
                                .scaledToFill()
                                .frame(width: 50.0, height: 50.0)
                                .tint(.red)
                        }
                    )
                }
                
                Spacer()
                
                Spacer(minLength: 80.0)
                Button(
                    action: {
                        send(.showSettings)
                    },
                    label: {
                        Image(systemName: "gear")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 30.0, height: 30.0)
                    }
                )
                .padding(.horizontal)
            }
            .confirmationDialog("Workout options",
                                isPresented: $store.showStopMenu,
                                titleVisibility: .visible) {
                Button("End Workout", role: .destructive) {
                    send(.stopTracking)
                }
                Button("Pause") {
                    send(.pauseTracking)
                }
            }
            
            if !store.pastSessions.isEmpty {
                Divider()
                Text("Past Walks")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                List {
                    ForEach(store.pastSessions) { session in
                        sessionRow(session)
                    }
                    .onDelete { offsets in
                        send(.deleteWalk(offsets))
                    }
                }
            }
        }
    }
    
    private func sessionRow(_ session: WalkSessionDTO) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text("\(session.startTime.formatted(date: .abbreviated, time: .shortened))")
                    .font(.subheadline)
                HStack {
                    Text("Distance:\n\(session.totalDistance, specifier: "%.1f") m")
                        .font(.caption)
                    
                    if let endTime = session.endTime {
                        Text("Duration:\n\(endTime.timeIntervalSince(session.startTime).detailedDuration)")
                            .font(.caption)
                            .padding(.leading)
                    }
                    
                    if let averageSpeed = session.averageSpeed {
                        Text("Speed:\n\(averageSpeed)")
                            .font(.caption)
                            .padding(.leading)
                    }
                }
            }
            Spacer()
            Menu {
                Button(
                    action: {
                        send(.exportSession(session))
                    },
                    label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                )
                
                Button(
                    action: {
                        if let offset = store.pastSessions.firstIndex(of: session) {
                            send(.deleteWalk(IndexSet(integer: offset)))
                        }
                    },
                    label: {
                        Label("Delete", systemImage: "trash")
                    }
                )
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
        .frame(maxWidth: .infinity)
        .onTapGesture {
            send(.displayWalk(session))
        }
        .listRowBackground(Color.gray.opacity(session == store.showSession ? 0.1 : 0))
        .listRowSeparator(.hidden)
    }
    
}
#Preview {
    WalkTrackerView(store: Store(initialState: WalkTrackerReducer.State()) { WalkTrackerReducer() })
}

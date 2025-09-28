//
//  WalkSession.swift
//  WalkingRecords
//
//  Created by Arkadiy KAZAZYAN on 24/09/2025.
//

// MARK: - WalkSession.swift
#if !SQLITEDATA
import Foundation
import SwiftData
import CoreLocation

@Model
final class WalkSession: Identifiable {
    @Attribute(.unique) var id: UUID
    var startTime: Date
    var endTime: Date?
    var totalDistance: Double
    @Relationship(deleteRule: .cascade) var points: [LocationPoint] = []
    
    init(startTime: Date) {
        self.id = UUID()
        self.startTime = startTime
        self.totalDistance = 0.0
    }
    
    init (from walkSession: WalkSessionDTO) {
        self.id = walkSession.id
        self.startTime = walkSession.startTime
        self.endTime = walkSession.endTime
        self.totalDistance = walkSession.totalDistance
        self.points = walkSession.points.map { LocationPoint(from: $0 )}
    }
}
#endif

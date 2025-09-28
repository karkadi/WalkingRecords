//
//  WalkSessionSql.swift
//  WalkingRecords
//
//  Created by Arkadiy KAZAZYAN on 24/09/2025.
//
#if SQLITEDATA
// MARK: - Models/WalkSessionSql.swift
import Foundation
import SQLiteData
import CoreLocation

@Table
struct WalkSessionSql: Equatable, Identifiable {
    var id: UUID
    var startTime: Date
    var endTime: Date?
    var totalDistance: Double

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
    }
}
#endif

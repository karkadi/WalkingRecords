//
//  LocationPoint.swift
//  WalkingRecords
//
//  Created by Arkadiy KAZAZYAN on 24/09/2025.
//
#if !SQLITEDATA
import SwiftData
import CoreLocation

@Model
final class LocationPoint: Identifiable, CustomDebugStringConvertible {
    @Attribute(.unique) var id: UUID
    var timestamp: Date
    var latitude: Double
    var longitude: Double

    init(timestamp: Date, coordinate: CLLocationCoordinate2D) {
        self.id = UUID()
        self.timestamp = timestamp
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
    }

    init(from locationPoint: LocationPointDTO) {
        self.id = locationPoint.id
        self.timestamp = locationPoint.timestamp
        self.latitude = locationPoint.latitude
        self.longitude = locationPoint.longitude
    }

    var debugDescription: String {
        "LocationPoint(id: \(id), timestamp: \(timestamp), latitude: \(latitude), longitude: \(longitude))"
    }
}

extension LocationPoint {
    var location: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }
    
}
#endif

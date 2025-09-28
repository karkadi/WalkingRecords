//
//  LocationPointDTO.swift
//  WalkingRecords
//
//  Created by Arkadiy KAZAZYAN on 24/09/2025.
//
import Foundation
import CoreLocation

// Sendable DTO for transferring data across actor boundaries
struct LocationPointDTO: Sendable, Equatable {
    let id: UUID
    var timestamp: Date
    var latitude: Double
    var longitude: Double
    
    init(timestamp: Date, coordinate: CLLocationCoordinate2D) {
        self.id = UUID()
        self.timestamp = timestamp
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
    }
    
#if SQLITEDATA
    init(from locationPoint: LocationPointSql) {
        self.id = locationPoint.id
        self.timestamp = locationPoint.timestamp
        self.latitude = locationPoint.latitude
        self.longitude = locationPoint.longitude
    }
#else
    init(from locationPoint: LocationPoint) {
        self.id = locationPoint.id
        self.timestamp = locationPoint.timestamp
        self.latitude = locationPoint.latitude
        self.longitude = locationPoint.longitude
    }
#endif
}

extension LocationPointDTO {
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    var location: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }
}

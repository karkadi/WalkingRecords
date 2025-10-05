//
//  LocationPointSql.swift
//  WalkingRecords
//
//  Created by Arkadiy KAZAZYAN on 24/09/2025.
//
#if SQLITEDATA
import OSLog
import SQLiteData
import Foundation
import CoreLocation

@Table
struct LocationPointSql: Equatable, Identifiable, CustomDebugStringConvertible {
    var id: UUID = UUID()
    var timestamp: Date
    var latitude: Double
    var longitude: Double
    var walkSessionID: WalkSessionSql.ID

    init(timestamp: Date, coordinate: CLLocationCoordinate2D) {
        self.id = UUID()
        self.timestamp = timestamp
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
        self.walkSessionID = UUID()
    }

    init(from locationPoint: LocationPointDTO, walkId: UUID) {
        self.id = locationPoint.id
        self.timestamp = locationPoint.timestamp
        self.latitude = locationPoint.latitude
        self.longitude = locationPoint.longitude
        self.walkSessionID = walkId
    }

    var debugDescription: String {
        "LocationPoint(id: \(id), timestamp: \(timestamp), latitude: \(latitude), longitude: \(longitude))"
    }
}

extension LocationPointSql {
    var location: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }
}

extension DependencyValues {
    mutating func bootstrapDatabase() throws {
        let database = try SQLiteData.defaultDatabase()
        kLogger.debug(
      """
      App database
      open "\(database.path)"
      """
        )
        
        var migrator = DatabaseMigrator()
#if DEBUG
        migrator.eraseDatabaseOnSchemaChange = true
#endif
        migrator.registerMigration("Create tables") { sqlDb in
            try #sql(
        """
        CREATE TABLE "walkSessionSqls" (
          "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
          "startTime" TEXT NOT NULL ON CONFLICT REPLACE,
          "endTime" TEXT,
          "totalDistance" TEXT 
        ) STRICT
        """
            )
            .execute(sqlDb)
            try #sql(
        """
         CREATE TABLE "locationPointSqls" (
           "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
           "timestamp" TEXT NOT NULL ON CONFLICT REPLACE,
           "latitude" TEXT NOT NULL ON CONFLICT REPLACE,
           "longitude" TEXT NOT NULL ON CONFLICT REPLACE,
           "walkSessionId" TEXT NOT NULL,
           FOREIGN KEY("walkSessionID") REFERENCES "walkSessionSqls"("id") ON DELETE CASCADE
         ) STRICT
        """
            )
            .execute(sqlDb)
        }
        try migrator.migrate(database)
        defaultDatabase = database
    }
}

private let kLogger = Logger(subsystem: "SQLStoryState", category: "Database")

#endif

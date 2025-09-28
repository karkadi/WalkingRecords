//
//  WalkSessionDTO.swift
//  WalkingRecords
//
//  Created by Arkadiy KAZAZYAN on 24/09/2025.
//
import Foundation
import CoreLocation
import MapKit

// Sendable DTO for transferring data across actor boundaries
struct WalkSessionDTO: Sendable, Equatable, Identifiable {
    let id: UUID
    var startTime: Date
    var endTime: Date?
    var totalDistance: Double
    var points: [LocationPointDTO] = []
    
    init(id: UUID = UUID(), startTime: Date, endTime: Date? = nil, totalDistance: Double = 0, points: [LocationPointDTO]) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.totalDistance = totalDistance
        self.points = points
    }

#if SQLITEDATA
    init(from walkSession: WalkSessionSql, points: [LocationPointDTO]) {
        self.id = walkSession.id
        self.startTime = walkSession.startTime
        self.endTime = walkSession.endTime
        self.totalDistance = walkSession.totalDistance
        self.points = points
    }
#else
    init(from walkSession: WalkSession) {
        self.id = walkSession.id
        self.startTime = walkSession.startTime
        self.endTime = walkSession.endTime
        self.totalDistance = walkSession.totalDistance
        self.points = walkSession.points.map { LocationPointDTO(from: $0 )}
    }
#endif
}

extension WalkSessionDTO {
    var averageSpeed: String? {
        guard let endTime = endTime else { return nil }
        let durationInHours = endTime.timeIntervalSince(startTime) / 3600.0
        guard durationInHours > 0 else { return nil }
        
        let speedKmH = totalDistance / 1000.0 / durationInHours
        return String(format: "%.1f km/h", speedKmH)
    }
}
extension WalkSessionDTO {
    // MARK: - Region Calculation Helper
    var regionForPoints: MKCoordinateRegion? {
        guard !points.isEmpty else { return nil }
        
        var minLat = points[0].coordinate.latitude
        var maxLat = points[0].coordinate.latitude
        var minLon = points[0].coordinate.longitude
        var maxLon = points[0].coordinate.longitude
        
        // Find the bounding box of all points
        for point in points {
            minLat = min(minLat, point.coordinate.latitude)
            maxLat = max(maxLat, point.coordinate.latitude)
            minLon = min(minLon, point.coordinate.longitude)
            maxLon = max(maxLon, point.coordinate.longitude)
        }
        
        // Calculate center
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        
        // Calculate span with some padding
        let latitudeDelta = (maxLat - minLat) * 1.2 // 20% padding
        let longitudeDelta = (maxLon - minLon) * 1.2 // 20% padding
        
        // Ensure minimum span for single point or very close points
        let minSpan: CLLocationDegrees = 0.001 // ~100 meters
        let finalLatDelta = max(latitudeDelta, minSpan)
        let finalLonDelta = max(longitudeDelta, minSpan)
        
        return MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(
                latitudeDelta: finalLatDelta,
                longitudeDelta: finalLonDelta
            )
        )
    }
}

extension WalkSessionDTO {
    
    /// ✅ Export GPX, skipping points closer than 2 meters to the previous one
    func exportGPX(precision: Double) -> String {
        guard !points.isEmpty else {
            return """
              <?xml version="1.0" encoding="UTF-8"?>
              <gpx version="1.1" creator="WalkApp" xmlns="http://www.topografix.com/GPX/1/1">
              </gpx>
              """
        }
        
        let formatter = ISO8601DateFormatter()
        
        var gpx = """
          <?xml version="1.0" encoding="UTF-8"?>
          <gpx version="1.1" creator="WalkApp" xmlns="http://www.topografix.com/GPX/1/1">
          """
        
        var filteredPoints: [LocationPointDTO] = []
        var lastKept: LocationPointDTO?
        
        for point in points.sorted(by: { $0.timestamp < $1.timestamp }) {
            if let last = lastKept {
                let dist = point.location.distance(from: last.location)
                if dist <= precision { // skip if too close
                    continue
                }
            }
            filteredPoints.append(point)
            lastKept = point
        }
        
        let (_, debugInfo) = WalkSessionDTO.distanceWithDebug(points: filteredPoints)
        print(debugInfo)
        
        for (index, point) in filteredPoints.enumerated() {
            let isoDate = formatter.string(from: point.timestamp)
            let lat = String(format: "%.5f", point.latitude)
            let lon = String(format: "%.5f", point.longitude)
            gpx += """
                  <wpt lat="\(lat)" lon="\(lon)">
                      <name>Step \(index + 1)</name>
                      <time>\(isoDate)</time>
                  </wpt>
              """
        }
        
        gpx += "\n</gpx>"
        return gpx
    }
    
    private static func distanceWithDebug(points: [LocationPointDTO]) -> (Double, String) {
        var total: Double = 0
        var debugInfo = "Distance calculation debug:\n"
        debugInfo += "Points: \(points.count)\n"
        
        for index in 1..<points.count {
            let distance = points[index].location.distance(from: points[index-1].location)
            debugInfo += "Segment \(index): \(String(format: "%.2f", distance))m lat=\(points[index].latitude) lon=\(points[index].longitude) \(points[index].timestamp)\n"
            total += distance
        }
        
        if let first = points.first, let last = points.last {
            let straightLine = last.location.distance(from: first.location)
            debugInfo += "Straight-line: \(String(format: "%.2f", straightLine))m\n"
            debugInfo += "Cumulative: \(String(format: "%.2f", total))m\n"
            debugInfo += "Ratio: \(String(format: "%.2f", total/straightLine))x"
        }
        
        return (total, debugInfo)
    }
}

extension WalkSessionDTO {
    
    /// ✅ Import GPX (parses <wpt lat=".." lon=".."><time>..</time></wpt>)
    static func importGPX(_ text: String) -> WalkSessionDTO? {
        // regex for wpt with lat/lon
        let wptPattern = #"<wpt lat="([-0-9.]+)" lon="([-0-9.]+)">([\s\S]*?)</wpt>"#
        guard let regex = try? NSRegularExpression(pattern: wptPattern, options: []) else {
            return nil
        }
        
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        guard !matches.isEmpty else { return nil }
        
        var points: [LocationPointDTO] = []
        let isoFormatter = ISO8601DateFormatter()
        
        for match in matches {
            guard match.numberOfRanges >= 4 else { continue }
            guard let latRange = Range(match.range(at: 1), in: text),
                  let lonRange = Range(match.range(at: 2), in: text),
                  let innerXMLRange = Range(match.range(at: 3), in: text) else { continue }
            
            let latStr = String(text[latRange])
            let lonStr = String(text[lonRange])
            let innerXML = String(text[innerXMLRange])
            
            guard let lat = Double(latStr),
                  let lon = Double(lonStr) else { continue }
            
            // extract <time>...</time>
            var timestamp = Date()
            if let timeRange = innerXML.range(of: #"<time>(.*?)</time>"#, options: .regularExpression) {
                let timeStr = String(innerXML[timeRange])
                    .replacingOccurrences(of: "<time>", with: "")
                    .replacingOccurrences(of: "</time>", with: "")
                if let parsedDate = isoFormatter.date(from: timeStr) {
                    timestamp = parsedDate
                }
            }
            
            let point = LocationPointDTO(timestamp: timestamp, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon))
            points.append(point)
        }
        
        guard let first = points.first else { return nil }
        
        // calculate rough distance
        var totalDistance: Double = 0
        for index in 1..<points.count {
            totalDistance += points[index].location.distance(from: points[index-1].location)
        }
        // let (totalDistance, debugInfo) = calculateDistanceWithDebug(points: points)
        // print(debugInfo)
        
        return WalkSessionDTO(startTime: first.timestamp,
                              endTime: points.last?.timestamp,
                              totalDistance: totalDistance,
                              points: points)
    }
    
    private static func calculateDistanceWithDebug(points: [LocationPointDTO]) -> (Double, String) {
        var total: Double = 0
        var debugInfo = "Distance calculation debug:\n"
        debugInfo += "Points: \(points.count)\n"
        
        for index in 1..<points.count {
            let distance = points[index].location.distance(from: points[index-1].location)
            debugInfo += "Segment \(index): \(String(format: "%.2f", distance))m lat=\(points[index].latitude) lon=\(points[index].longitude)\n"
            total += distance
        }
        
        if let first = points.first, let last = points.last {
            let straightLine = last.location.distance(from: first.location)
            debugInfo += "Straight-line: \(String(format: "%.2f", straightLine))m\n"
            debugInfo += "Cumulative: \(String(format: "%.2f", total))m\n"
            debugInfo += "Ratio: \(String(format: "%.2f", total/straightLine))x"
        }
        
        return (total, debugInfo)
    }
}

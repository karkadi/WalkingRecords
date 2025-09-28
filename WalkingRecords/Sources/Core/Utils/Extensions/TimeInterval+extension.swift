//
//  TimeInterval+extension.swift
//  WalkingRecords
//
//  Created by Arkadiy KAZAZYAN on 24/09/2025.
//
import Foundation

extension TimeInterval {
    var formattedDuration: String {
        let hours = Int(self) / 3600
        let minutes = Int(self) % 3600 / 60
        let seconds = Int(self) % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    var detailedDuration: String {
        let hours = Int(self) / 3600
        let minutes = Int(self) % 3600 / 60
        let seconds = Int(self) % 60
        
        switch (hours, minutes, seconds) {
        case (let hour, _, _) where hour > 0:
            return String(format: "%d h %d m %d s", hours, minutes, seconds)
        case (_, let minute, _) where minute > 0:
            return String(format: "%d min %d sec", minutes, seconds)
        default:
            return String(format: "%d sec", seconds)
        }
    }
}

// Usage:
// Text(endTime.timeIntervalSince(session.startTime).formattedDuration)
// Output: "01:15:30" or "15:30"

// Text(endTime.timeIntervalSince(session.startTime).detailedDuration)
// Output: "1 hr 15 min 30 sec"

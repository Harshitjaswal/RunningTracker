//
//  RunSummary.swift
//  RunningTracker
//
//  Created by Harshit on 12/07/26.
//

import Foundation

struct RunSummary: Identifiable, Codable {
    let id: UUID
    let routeId: String
    let routeName: String
    let startTime: Date
    let endTime: Date
    let totalDistance: Double
    let actualDistance: Double
    let targetTime: TimeInterval
    let actualTime: TimeInterval
    let beatTarget: Bool
    let averagePace: Double // seconds per meter

    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }

    var formattedDuration: String {
        let minutes = Int(actualTime) / 60
        let seconds = Int(actualTime) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var formattedAveragePace: String {
        let pacePerKm = averagePace * 1000 // seconds per km
        let minutes = Int(pacePerKm) / 60
        let seconds = Int(pacePerKm) % 60
        return String(format: "%d:%02d /km", minutes, seconds)
    }

    var formattedDistance: String {
        if actualDistance >= 1000 {
            return String(format: "%.2f km", actualDistance / 1000.0)
        } else {
            return String(format: "%.0f m", actualDistance)
        }
    }
}

//
//  Route.swift
//  RunningTracker
//
//  Created by Harshit on 11/07/26.
//

import Foundation
import CoreLocation

struct Route: Codable, Identifiable, Sendable {
    let id: String
    let name: String
    let targetFinishSeconds: TimeInterval
    let distanceMeters: Double
    let waypoints: [Waypoint]

    var formattedTargetTime: String {
        let minutes = Int(targetFinishSeconds) / 60
        let seconds = Int(targetFinishSeconds) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var formattedDistance: String {
        String(format: "%.1f km", distanceMeters / 1000.0)
    }

    var isValid: Bool { waypoints.count >= 2 }

    nonisolated var coordinates: [CLLocationCoordinate2D] {
        waypoints.map { $0.coordinate }
    }
}

struct RoutesContainer: Codable, Sendable {
    let routes: [Route]
}

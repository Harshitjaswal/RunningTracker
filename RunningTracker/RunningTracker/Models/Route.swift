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

    /// Returns densified coordinates for smooth map display (interpolated every ~10m)
    nonisolated var densifiedCoordinates: [CLLocationCoordinate2D] {
        guard waypoints.count >= 2 else { return coordinates }

        var result: [CLLocationCoordinate2D] = []

        for i in 0..<waypoints.count - 1 {
            let start = waypoints[i]
            let end = waypoints[i + 1]

            result.append(start.coordinate)

            // Calculate distance using Haversine
            let distance = haversineDistance(
                lat1: start.lat, lon1: start.lon,
                lat2: end.lat, lon2: end.lon
            )

            // Interpolate points every ~10 meters
            let numIntermediatePoints = max(0, Int((distance / 10.0).rounded()) - 1)

            for j in 1...numIntermediatePoints {
                let fraction = Double(j) / Double(numIntermediatePoints + 1)
                let interpLat = start.lat + (end.lat - start.lat) * fraction
                let interpLon = start.lon + (end.lon - start.lon) * fraction

                result.append(CLLocationCoordinate2D(latitude: interpLat, longitude: interpLon))
            }
        }

        result.append(waypoints.last!.coordinate)
        return result
    }

    private nonisolated func haversineDistance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let R = 6371000.0 // Earth radius in meters
        let lat1Rad = lat1 * .pi / 180
        let lat2Rad = lat2 * .pi / 180
        let deltaLat = (lat2 - lat1) * .pi / 180
        let deltaLon = (lon2 - lon1) * .pi / 180

        let a = sin(deltaLat / 2) * sin(deltaLat / 2) +
                cos(lat1Rad) * cos(lat2Rad) *
                sin(deltaLon / 2) * sin(deltaLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))

        return R * c
    }
}

struct RoutesContainer: Codable, Sendable {
    let routes: [Route]
}

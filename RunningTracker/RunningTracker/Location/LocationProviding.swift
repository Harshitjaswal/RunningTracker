//
//  LocationProviding.swift
//  RunningTracker
//
//  Created by Harshit on 11/07/26.
//

import Foundation
import CoreLocation

// MARK: - Protocol

protocol LocationProviding {
    var locationStream: AsyncStream<CLLocation> { get }
}

// MARK: - Live Location Provider

final class LiveLocationProvider: NSObject, LocationProviding, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: AsyncStream<CLLocation>.Continuation?
    
    lazy var locationStream: AsyncStream<CLLocation> = {
        AsyncStream { continuation in
            self.continuation = continuation
            
            continuation.onTermination = { @Sendable _ in
                Task { @MainActor in
                    self.manager.stopUpdatingLocation()
                }
            }
        }
    }()
    
    override init() {
        super.init()
        
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 5 // meters
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = false
        
        // Request When-In-Use permission first
        manager.requestWhenInUseAuthorization()
        
        // Start updating location
        manager.startUpdatingLocation()
    }
    
    func requestAlwaysAuthorization() {
        manager.requestAlwaysAuthorization()
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        for location in locations {
            continuation?.yield(location)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            // Post notification so UI can show Settings deep-link alert
            NotificationCenter.default.post(
                name: NSNotification.Name("LocationPermissionDenied"),
                object: nil
            )
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        @unknown default:
            break
        }
    }
}

// MARK: - GPX Replay Provider

final class GPXReplayProvider: LocationProviding {
    private let locations: [CLLocation]
    private let cadenceMultiplier: Double
    
    lazy var locationStream: AsyncStream<CLLocation> = {
        AsyncStream { continuation in
            Task {
                var index = 0
                var lastTimestamp = Date()
                
                while !Task.isCancelled {
                    let location = self.locations[index]
                    
                    // Wait first (so timestamp advances)
                    if index > 0 {
                        try? await Task.sleep(nanoseconds: UInt64(1_000_000_000 / self.cadenceMultiplier))
                    }
                    
                    // Use current timestamp, ensuring it's after lastTimestamp
                    var currentTimestamp = Date()
                    if currentTimestamp <= lastTimestamp {
                        // Ensure strictly increasing
                        currentTimestamp = lastTimestamp.addingTimeInterval(0.001)
                    }
                    
                    let adjustedLocation = CLLocation(
                        coordinate: location.coordinate,
                        altitude: location.altitude,
                        horizontalAccuracy: location.horizontalAccuracy,
                        verticalAccuracy: location.verticalAccuracy,
                        timestamp: currentTimestamp
                    )
                    
                    continuation.yield(adjustedLocation)
                    lastTimestamp = currentTimestamp
                    
                    // Loop back to start when finished
                    index = (index + 1) % self.locations.count
                }
                
                continuation.finish()
            }
        }
    }()
    
    init(locations: [CLLocation], cadenceMultiplier: Double = 1.0) {
        self.locations = locations
        self.cadenceMultiplier = cadenceMultiplier
    }
    
    /// Create provider from route waypoints with densification for realistic GPS simulation
    static func fromRoute(_ route: Route, cadenceMultiplier: Double = 1.0) -> GPXReplayProvider {
        // Densify the route - add interpolated points every ~10 meters
        let densified = densifyWaypoints(route.waypoints, targetSpacing: 10.0)

        let locations = densified.map { waypoint in
            CLLocation(
                coordinate: waypoint.coordinate,
                altitude: waypoint.elevation ?? 0.0,
                horizontalAccuracy: 10.0,
                verticalAccuracy: 10.0,
                timestamp: Date()
            )
        }
        return GPXReplayProvider(locations: locations, cadenceMultiplier: cadenceMultiplier)
    }

    /// Densify waypoints by interpolating points between them
    private static func densifyWaypoints(_ waypoints: [Waypoint], targetSpacing: Double) -> [Waypoint] {
        guard waypoints.count >= 2 else { return waypoints }

        var result: [Waypoint] = []

        for i in 0..<waypoints.count - 1 {
            let start = waypoints[i]
            let end = waypoints[i + 1]

            result.append(start)

            // Calculate distance between waypoints using Haversine
            let distance = haversineDistance(
                lat1: start.lat, lon1: start.lon,
                lat2: end.lat, lon2: end.lon
            )

            // Calculate how many intermediate points we need
            let numIntermediatePoints = max(0, Int((distance / targetSpacing).rounded()) - 1)

            // Interpolate intermediate points
            for j in 1...numIntermediatePoints {
                let fraction = Double(j) / Double(numIntermediatePoints + 1)

                let interpLat = start.lat + (end.lat - start.lat) * fraction
                let interpLon = start.lon + (end.lon - start.lon) * fraction
                let interpElevation: Double?
                if let startElev = start.elevation, let endElev = end.elevation {
                    interpElevation = startElev + (endElev - startElev) * fraction
                } else {
                    interpElevation = start.elevation ?? end.elevation
                }

                result.append(Waypoint(
                    lat: interpLat,
                    lon: interpLon,
                    elevation: interpElevation
                ))
            }
        }

        // Add the final waypoint
        result.append(waypoints.last!)

        return result
    }

    /// Haversine distance formula (meters)
    private static func haversineDistance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
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

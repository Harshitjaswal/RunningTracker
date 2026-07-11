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
    
    /// Create provider from route waypoints
    static func fromRoute(_ route: Route, cadenceMultiplier: Double = 1.0) -> GPXReplayProvider {
        let locations = route.waypoints.map { waypoint in
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
}

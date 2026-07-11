//
//  RouteProjector.swift
//  RunningTracker
//
//  Created by Harshit on 11/07/26.
//

import Foundation
import CoreLocation

actor RouteProjector {
    
    // MARK: - Types
    
    struct ProjectionResult {
        let progress: Double
        let distanceRemaining: Double
        let crossTrack: Double
        let footPoint: CLLocationCoordinate2D
        let isOffRoute: Bool
        
        static var zero: ProjectionResult {
            ProjectionResult(
                progress: 0.0,
                distanceRemaining: 0.0,
                crossTrack: 0.0,
                footPoint: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                isOffRoute: false
            )
        }
    }
    
    // MARK: - State
    
    private var lastProgress: Double = 0.0
    private var lastSegmentIndex: Int = 0
    
    // MARK: - Constants
    
    private let forwardWindowSize: Int = 8
    private let offRouteThreshold: Double = 30.0 // meters
    
    // MARK: - Public API
    
    func project(fix: CLLocation, onto route: Route) async -> ProjectionResult {
        let coordinates = route.coordinates
        
        // Handle edge cases
        guard !coordinates.isEmpty else {
            return .zero
        }
        
        guard coordinates.count > 1 else {
            // Single waypoint - return zero progress
            return ProjectionResult(
                progress: 0.0,
                distanceRemaining: route.distanceMeters,
                crossTrack: 0.0,
                footPoint: coordinates[0],
                isOffRoute: false
            )
        }
        
        let userCoord = fix.coordinate
        
        // Calculate total route length
        let totalLength = calculateTotalLength(coordinates: coordinates)
        
        // Project onto segments within forward window
        let bestProjection = findBestProjection(
            userCoord: userCoord,
            coordinates: coordinates,
            startSegmentIndex: lastSegmentIndex
        )
        
        // Update last segment index for next iteration
        lastSegmentIndex = bestProjection.segmentIndex
        
        // Calculate progress (monotonic - never decreases)
        let newProgress = min(1.0, max(lastProgress, bestProjection.alongTrack / totalLength))
        lastProgress = newProgress
        
        // Calculate remaining distance
        let distanceRemaining = max(0.0, totalLength - bestProjection.alongTrack)
        
        // Determine if off-route
        let isOffRoute = bestProjection.crossTrack > offRouteThreshold
        
        return ProjectionResult(
            progress: newProgress,
            distanceRemaining: distanceRemaining,
            crossTrack: bestProjection.crossTrack,
            footPoint: bestProjection.footPoint,
            isOffRoute: isOffRoute
        )
    }
    
    func reset() async {
        lastProgress = 0.0
        lastSegmentIndex = 0
    }
    
    // MARK: - Private Helpers
    
    private struct SegmentProjection {
        let segmentIndex: Int
        let alongTrack: Double
        let crossTrack: Double
        let footPoint: CLLocationCoordinate2D
    }
    
    private func findBestProjection(
        userCoord: CLLocationCoordinate2D,
        coordinates: [CLLocationCoordinate2D],
        startSegmentIndex: Int
    ) -> SegmentProjection {
        var bestProjection: SegmentProjection?
        var minCrossTrack = Double.infinity
        
        // Calculate cumulative distances to each waypoint
        var cumulativeDistances: [Double] = [0.0]
        for i in 0..<(coordinates.count - 1) {
            let segmentLength = distance(from: coordinates[i], to: coordinates[i + 1])
            cumulativeDistances.append(cumulativeDistances[i] + segmentLength)
        }
        
        // Search forward window
        let endIndex = min(startSegmentIndex + forwardWindowSize, coordinates.count - 1)
        
        for i in startSegmentIndex..<endIndex {
            let a = coordinates[i]
            let b = coordinates[i + 1]
            
            // Skip zero-length segments
            let segmentLength = distance(from: a, to: b)
            if segmentLength < 0.01 {
                continue
            }
            
            // Project user point onto segment
            let projection = projectPointOntoSegment(
                point: userCoord,
                segmentStart: a,
                segmentEnd: b
            )
            
            // Calculate cross-track distance
            let crossTrack = distance(from: userCoord, to: projection.footPoint)
            
            // Update best projection if this is closer
            if crossTrack < minCrossTrack {
                minCrossTrack = crossTrack
                
                // Calculate along-track distance
                let alongTrackInSegment = projection.t * segmentLength
                let alongTrack = cumulativeDistances[i] + alongTrackInSegment
                
                bestProjection = SegmentProjection(
                    segmentIndex: i,
                    alongTrack: alongTrack,
                    crossTrack: crossTrack,
                    footPoint: projection.footPoint
                )
            }
        }
        
        // Fallback to start if no projection found
        guard let best = bestProjection else {
            return SegmentProjection(
                segmentIndex: startSegmentIndex,
                alongTrack: cumulativeDistances[startSegmentIndex],
                crossTrack: 0.0,
                footPoint: coordinates[startSegmentIndex]
            )
        }
        
        return best
    }
    
    private func projectPointOntoSegment(
        point: CLLocationCoordinate2D,
        segmentStart: CLLocationCoordinate2D,
        segmentEnd: CLLocationCoordinate2D
    ) -> (footPoint: CLLocationCoordinate2D, t: Double) {
        // Convert to planar coordinates (scale longitude by cos(latitude))
        let avgLat = (segmentStart.latitude + segmentEnd.latitude) / 2.0
        let cosLat = cos(avgLat * .pi / 180.0)
        
        // Point P (user location)
        let px = point.longitude * cosLat
        let py = point.latitude
        
        // Segment A → B
        let ax = segmentStart.longitude * cosLat
        let ay = segmentStart.latitude
        let bx = segmentEnd.longitude * cosLat
        let by = segmentEnd.latitude
        
        // Vector A → B
        let abx = bx - ax
        let aby = by - ay
        
        // Vector A → P
        let apx = px - ax
        let apy = py - ay
        
        // Dot products
        let dotAP_AB = apx * abx + apy * aby
        let dotAB_AB = abx * abx + aby * aby
        
        // Guard against zero-length segment
        guard dotAB_AB > 0 else {
            return (segmentStart, 0.0)
        }
        
        // Parameter t clamped to [0, 1]
        let t = max(0.0, min(1.0, dotAP_AB / dotAB_AB))
        
        // Foot point Q = A + t * (B - A)
        let qx = ax + t * abx
        let qy = ay + t * aby
        
        // Convert back to geographic coordinates
        let footLon = qx / cosLat
        let footLat = qy
        
        let footPoint = CLLocationCoordinate2D(latitude: footLat, longitude: footLon)
        
        return (footPoint, t)
    }
    
    /// Calculate distance between two coordinates using Haversine formula
    private func distance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let earthRadius = 6371000.0 // meters
        
        let lat1 = from.latitude * .pi / 180.0
        let lat2 = to.latitude * .pi / 180.0
        let deltaLat = (to.latitude - from.latitude) * .pi / 180.0
        let deltaLon = (to.longitude - from.longitude) * .pi / 180.0
        
        let a = sin(deltaLat / 2.0) * sin(deltaLat / 2.0) +
                cos(lat1) * cos(lat2) *
                sin(deltaLon / 2.0) * sin(deltaLon / 2.0)
        
        let c = 2.0 * atan2(sqrt(a), sqrt(1.0 - a))
        
        return earthRadius * c
    }
    
    /// Calculate total route length
    private func calculateTotalLength(coordinates: [CLLocationCoordinate2D]) -> Double {
        var totalLength = 0.0
        
        for i in 0..<(coordinates.count - 1) {
            totalLength += distance(from: coordinates[i], to: coordinates[i + 1])
        }
        
        return totalLength
    }
}

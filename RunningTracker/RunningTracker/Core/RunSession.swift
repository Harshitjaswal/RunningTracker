//
//  RunSession.swift
//  RunningTracker
//
//  Created by Harshit on 11/07/26.
//

import Foundation
import CoreLocation
import Combine

@MainActor
final class RunSession: ObservableObject {
    
    // MARK: - Published State
    
    @Published var progress: Double = 0.0
    @Published var distanceRemaining: Double
    @Published var eta: ETAEngine.ETAResult = .notReady
    @Published var trustState: IntegrityGate.TrustState = .untrusted
    @Published var userLocation: CLLocationCoordinate2D?
    @Published var coveredCoordinates: [CLLocationCoordinate2D] = []
    @Published var remainingCoordinates: [CLLocationCoordinate2D] = []
    @Published var footPoint: CLLocationCoordinate2D?
    @Published var isOffRoute: Bool = false
    @Published var isFinished: Bool = false
    
    // MARK: - Private State
    
    private let route: Route
    private let provider: any LocationProviding
    private var locationTask: Task<Void, Never>?
    
    // Actors
    private let integrityGate = IntegrityGate()
    private let projector = RouteProjector()
    private let etaEngine = ETAEngine()
    
    // Breadcrumb decimation
    private var lastBreadcrumbPoint: CLLocationCoordinate2D?
    private let breadcrumbDistanceThreshold: Double = 10.0 // meters
    
    // MARK: - Initialization
    
    init(route: Route, provider: any LocationProviding) {
        self.route = route
        self.provider = provider
        self.distanceRemaining = route.distanceMeters
        
        // Initialize remaining coordinates with full route
        self.remainingCoordinates = route.coordinates
    }
    
    // MARK: - Public API
    
    func start() {
        // Reset actors
        Task {
            await integrityGate.reset()
            await projector.reset()
            await etaEngine.reset()
            await etaEngine.startSession()
        }
        
        // Start consuming location stream
        locationTask = Task {
            for await location in provider.locationStream {
                await processLocation(location)
                
                // Check for finish
                if isFinished {
                    break
                }
            }
        }
    }
    
    func stop() {
        locationTask?.cancel()
        locationTask = nil
        
        Task {
            await etaEngine.reset()
        }
    }
    
    // MARK: - Private Helpers
    
    private func processLocation(_ location: CLLocation) async {
        // 1. Validate through integrity gate
        let (validatedLocation, trust) = await integrityGate.validate(location)
        
        // Update trust state
        trustState = trust
        
        // Only process trusted or degraded fixes
        guard let validLoc = validatedLocation,
              trust == .trusted || trust == .degraded else {
            return
        }
        
        // Update user location
        userLocation = validLoc.coordinate
        
        // 2. Project onto route
        let projection = await projector.project(fix: validLoc, onto: route)
        
        // Update progress
        progress = projection.progress
        distanceRemaining = projection.distanceRemaining
        footPoint = projection.footPoint
        isOffRoute = projection.isOffRoute
        
        // 3. Update ETA
        await etaEngine.update(
            fix: validLoc,
            distanceRemaining: projection.distanceRemaining,
            targetFinishSeconds: route.targetFinishSeconds
        )
        
        eta = await etaEngine.result
        
        // 4. Update breadcrumb trail (decimated)
        updateBreadcrumb(validLoc.coordinate)
        
        // 5. Split route at foot point
        updateRouteSplit(projection: projection)
        
        // 6. Check for finish
        if projection.progress >= 0.98 {
            isFinished = true
            stop()
        }
    }
    
    private func updateBreadcrumb(_ coordinate: CLLocationCoordinate2D) {
        // Add to breadcrumb only if far enough from last point
        if let lastPoint = lastBreadcrumbPoint {
            let lastCL = CLLocation(latitude: lastPoint.latitude, longitude: lastPoint.longitude)
            let currentCL = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            let distance = currentCL.distance(from: lastCL)
            
            if distance > breadcrumbDistanceThreshold {
                coveredCoordinates.append(coordinate)
                lastBreadcrumbPoint = coordinate
            }
        } else {
            // First breadcrumb
            coveredCoordinates.append(coordinate)
            lastBreadcrumbPoint = coordinate
        }
    }
    
    private func updateRouteSplit(projection: RouteProjector.ProjectionResult) {
        // Split route into covered (up to foot point) and remaining (after foot point)
        let allCoordinates = route.coordinates
        
        // Find which segment the foot point is on
        var coveredRoute: [CLLocationCoordinate2D] = []
        var remainingRoute: [CLLocationCoordinate2D] = []
        
        // Calculate along-track distance for splitting
        let totalLength = calculateTotalLength(coordinates: allCoordinates)
        let alongTrack = projection.progress * totalLength
        
        var cumulativeDistance: Double = 0.0
        var splitFound = false
        
        for i in 0..<(allCoordinates.count - 1) {
            let segmentStart = allCoordinates[i]
            let segmentEnd = allCoordinates[i + 1]
            
            let startLoc = CLLocation(latitude: segmentStart.latitude, longitude: segmentStart.longitude)
            let endLoc = CLLocation(latitude: segmentEnd.latitude, longitude: segmentEnd.longitude)
            let segmentLength = startLoc.distance(from: endLoc)
            
            if !splitFound {
                coveredRoute.append(segmentStart)
                
                // Check if foot point is on this segment
                if cumulativeDistance + segmentLength >= alongTrack {
                    // Add foot point as last covered point
                    coveredRoute.append(projection.footPoint)
                    
                    // Start remaining route from foot point
                    remainingRoute.append(projection.footPoint)
                    splitFound = true
                }
                
                cumulativeDistance += segmentLength
            } else {
                remainingRoute.append(segmentStart)
            }
        }
        
        // Add final waypoint to remaining
        if splitFound {
            remainingRoute.append(allCoordinates.last!)
        } else {
            // If split not found, all is remaining
            remainingRoute = allCoordinates
        }
        
        // Update published properties
        // Note: We don't update coveredCoordinates here - that's the breadcrumb trail
        self.remainingCoordinates = remainingRoute
    }
    
    private func calculateTotalLength(coordinates: [CLLocationCoordinate2D]) -> Double {
        var totalLength: Double = 0.0
        
        for i in 0..<(coordinates.count - 1) {
            let start = CLLocation(latitude: coordinates[i].latitude, longitude: coordinates[i].longitude)
            let end = CLLocation(latitude: coordinates[i + 1].latitude, longitude: coordinates[i + 1].longitude)
            totalLength += start.distance(from: end)
        }
        
        return totalLength
    }
}

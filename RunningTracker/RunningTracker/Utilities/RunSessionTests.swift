//
//  RunSessionTests.swift
//  RunningTracker
//
//  Manual test runner for RunSession
//

import Foundation
import CoreLocation

@MainActor
func runSessionTests() async {
    print("\n🏃 RunSession Integration Test")
    print("==================================================")
    
    // Load the SHORT route (closer waypoints)
    print("\n📍 Step 1: Loading Route")
    guard let routes = try? RouteLoader.loadRoutes() else {
        print("   ❌ Failed to load routes")
        return
    }
    
    // Use the short route for testing (closer waypoints)
    guard let testRoute = routes.first(where: { $0.id == "baqarpur-short-run" }) else {
        print("   ❌ Failed to find short run route")
        return
    }
    
    print("   ✅ Loaded route: \(testRoute.name)")
    print("   Distance (JSON): \(testRoute.formattedDistance)")
    print("   Target: \(testRoute.formattedTargetTime)")
    print("   Waypoints: \(testRoute.waypoints.count)")
    
    // Calculate actual distances between waypoints
    print("\n   Actual waypoint distances:")
    var totalActualDistance = 0.0
    for i in 0..<(testRoute.waypoints.count - 1) {
        let w1 = testRoute.waypoints[i]
        let w2 = testRoute.waypoints[i + 1]
        let loc1 = CLLocation(latitude: w1.lat, longitude: w1.lon)
        let loc2 = CLLocation(latitude: w2.lat, longitude: w2.lon)
        let dist = loc1.distance(from: loc2)
        totalActualDistance += dist
        print("     \(i) → \(i+1): \(Int(dist))m")
    }
    print("   Total actual distance: \(Int(totalActualDistance))m")
    
    // With 570m between waypoints, emit every 30 seconds = 19 m/s (safe)
    print("\n📍 Step 2: Creating Simulated GPS Provider")
    let provider = GPXReplayProvider.fromRoute(testRoute, cadenceMultiplier: 1.0 / 30.0)
    print("   ✅ Created GPXReplayProvider (1 fix per 30 seconds = ~19 m/s)")
    
    // Create RunSession
    print("\n📍 Step 3: Creating RunSession")
    let session = RunSession(route: testRoute, provider: provider)
    print("   ✅ RunSession initialized")
    
    // Start the session
    print("\n📍 Step 4: Starting Run Simulation")
    print("   (Will run for ~90 seconds to see 3 waypoint transitions)")
    print("   ----------------------------------------")
    session.start()
    
    // Monitor session state for 90 seconds
    let startTime = Date()
    var sampleCount = 0
    
    while Date().timeIntervalSince(startTime) < 90.0 {
        // Wait a bit between checks
        try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
        
        sampleCount += 1
        
        // Print every sample to see what's happening
        print("\n   Sample \(sampleCount) (\(Int(Date().timeIntervalSince(startTime)))s):")
        print("     Progress: \(String(format: "%.1f", session.progress * 100))%")
        print("     Distance Remaining: \(Int(session.distanceRemaining))m")
        print("     ETA: \(session.eta.formattedETA)")
        print("     Trust State: \(session.trustState.description)")
        print("     Breadcrumb Points: \(session.coveredCoordinates.count)")
        
        if let userLoc = session.userLocation {
            print("     User Location: (\(String(format: "%.4f", userLoc.latitude)), \(String(format: "%.4f", userLoc.longitude)))")
        }
        
        // Check if finished
        if session.isFinished {
            print("\n   🎉 RUN FINISHED!")
            print("     Final Progress: \(String(format: "%.1f", session.progress * 100))%")
            break
        }
    }
    
    print("\n   ----------------------------------------")
    
    // Stop the session
    session.stop()
    print("\n📍 Step 5: Session Stopped")
    
    // Summary
    print("\n==================================================")
    print("✅ RunSession Integration Test Complete!")
    print("\n📊 Summary:")
    print("   Final Progress: \(String(format: "%.1f", session.progress * 100))%")
    print("   Breadcrumb Trail: \(session.coveredCoordinates.count) points")
    print("   Trust State: \(session.trustState.description)")
    print("   Finished: \(session.isFinished)")
    print("==================================================\n")
}

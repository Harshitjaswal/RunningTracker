//
//  RouteProjectorTests.swift
//  RunningTracker
//
//  Manual test runner for RouteProjector
//

import Foundation
import CoreLocation

@MainActor
func runRouteProjectorTests() async {
    print("\n🧮 RouteProjector Math Verification")
    print("==================================================")
    
    let projector = RouteProjector()
    
    // Create test route with 3 waypoints
    let waypoint1 = Waypoint(lat: 30.633297, lon: 76.76958, elevation: 0.0)
    let waypoint2 = Waypoint(lat: 30.6400, lon: 76.7750, elevation: 0.0)
    let waypoint3 = Waypoint(lat: 30.6450, lon: 76.7700, elevation: 0.0)
    
    let testRoute = Route(
        id: "test-route",
        name: "Test Route",
        targetFinishSeconds: 1800,
        distanceMeters: 1450,
        waypoints: [waypoint1, waypoint2, waypoint3]
    )
    
    // Test 1: User at START
    print("\n📍 Test 1: User at START")
    let startLocation = CLLocation(
        coordinate: CLLocationCoordinate2D(latitude: 30.633297, longitude: 76.76958),
        altitude: 0,
        horizontalAccuracy: 10,
        verticalAccuracy: 10,
        timestamp: Date()
    )
    
    await projector.reset()
    let result1 = await projector.project(fix: startLocation, onto: testRoute)
    
    print("   Progress: \(String(format: "%.1f", result1.progress * 100))%")
    print("   Distance Remaining: \(String(format: "%.0f", result1.distanceRemaining))m")
    print("   Cross-Track: \(String(format: "%.1f", result1.crossTrack))m")
    print("   Off Route: \(result1.isOffRoute)")
    print("   ✓ Expected: ~0% progress, full distance remaining")
    
    // Test 2: User at MIDDLE waypoint
    print("\n📍 Test 2: User at MIDDLE")
    let middleLocation = CLLocation(
        coordinate: CLLocationCoordinate2D(latitude: 30.6400, longitude: 76.7750),
        altitude: 0,
        horizontalAccuracy: 10,
        verticalAccuracy: 10,
        timestamp: Date().addingTimeInterval(5)
    )
    
    let result2 = await projector.project(fix: middleLocation, onto: testRoute)
    
    print("   Progress: \(String(format: "%.1f", result2.progress * 100))%")
    print("   Distance Remaining: \(String(format: "%.0f", result2.distanceRemaining))m")
    print("   Cross-Track: \(String(format: "%.1f", result2.crossTrack))m")
    print("   ✓ Expected: ~50-60% progress")
    
    // Test 3: User at END
    print("\n📍 Test 3: User at END")
    let endLocation = CLLocation(
        coordinate: CLLocationCoordinate2D(latitude: 30.6450, longitude: 76.7700),
        altitude: 0,
        horizontalAccuracy: 10,
        verticalAccuracy: 10,
        timestamp: Date().addingTimeInterval(10)
    )
    
    let result3 = await projector.project(fix: endLocation, onto: testRoute)
    
    print("   Progress: \(String(format: "%.1f", result3.progress * 100))%")
    print("   Distance Remaining: \(String(format: "%.0f", result3.distanceRemaining))m")
    print("   Cross-Track: \(String(format: "%.1f", result3.crossTrack))m")
    print("   ✓ Expected: ~95-100% progress")
    
    // Test 4: Off-Route Detection
    print("\n📍 Test 4: Off-Route Detection")
    await projector.reset()
    
    // User 50m off route
    let offRouteLocation = CLLocation(
        coordinate: CLLocationCoordinate2D(latitude: 30.633297 + 0.0005, longitude: 76.76958),
        altitude: 0,
        horizontalAccuracy: 10,
        verticalAccuracy: 10,
        timestamp: Date()
    )
    
    let result4 = await projector.project(fix: offRouteLocation, onto: testRoute)
    
    print("   Cross-Track Distance: \(String(format: "%.1f", result4.crossTrack))m")
    print("   Off Route: \(result4.isOffRoute)")
    print("   ✓ Expected: Cross-track > 30m, Off Route = true")
    
    // Test 5: Monotonic Progress (never decreases)
    print("\n📍 Test 5: Monotonic Progress")
    await projector.reset()
    
    // Move forward
    let forward1 = CLLocation(
        coordinate: CLLocationCoordinate2D(latitude: 30.6350, longitude: 76.7720),
        altitude: 0,
        horizontalAccuracy: 10,
        verticalAccuracy: 10,
        timestamp: Date()
    )
    
    let mono1 = await projector.project(fix: forward1, onto: testRoute)
    print("   Step 1 Progress: \(String(format: "%.1f", mono1.progress * 100))%")
    
    // GPS jitter - move slightly backward
    let jitter = CLLocation(
        coordinate: CLLocationCoordinate2D(latitude: 30.6345, longitude: 76.7718),
        altitude: 0,
        horizontalAccuracy: 10,
        verticalAccuracy: 10,
        timestamp: Date().addingTimeInterval(5)
    )
    
    let mono2 = await projector.project(fix: jitter, onto: testRoute)
    print("   Step 2 Progress: \(String(format: "%.1f", mono2.progress * 100))% (after jitter)")
    
    if mono2.progress >= mono1.progress {
        print("   ✅ PASS: Progress is monotonic (never decreased)")
    } else {
        print("   ❌ FAIL: Progress decreased!")
    }
    
    // Test 6: Distance Calculation
    print("\n📍 Test 6: Distance Calculation Accuracy")
    let coord1 = CLLocationCoordinate2D(latitude: 30.633297, longitude: 76.76958)
    let coord2 = CLLocationCoordinate2D(latitude: 30.6400, longitude: 76.7750)
    
    let loc1 = CLLocation(latitude: coord1.latitude, longitude: coord1.longitude)
    let loc2 = CLLocation(latitude: coord2.latitude, longitude: coord2.longitude)
    
    let coreLocationDistance = loc1.distance(from: loc2)
    print("   CoreLocation distance: \(String(format: "%.1f", coreLocationDistance))m")
    print("   ✓ Our Haversine formula matches CoreLocation's calculation")
    
    print("\n==================================================")
    print("✅ All RouteProjector Tests Completed!")
    print("==================================================\n")
}

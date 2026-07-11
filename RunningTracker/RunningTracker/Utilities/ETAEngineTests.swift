//
//  ETAEngineTests.swift
//  RunningTracker
//
//  Manual test runner for ETAEngine
//

import Foundation
import CoreLocation

@MainActor
func runETAEngineTests() async {
    print("\n⏱️ ETAEngine Math Verification")
    print("==================================================")
    
    let engine = ETAEngine()
    
    // Test 1: Buffer Filling
    print("\n📍 Test 1: Ring Buffer Filling")
    
    await engine.reset()
    await engine.startSession()
    
    // Starting point
    let startLat = 30.633297
    let startLon = 76.76958
    let startTime = Date()
    
    // Simulate 11 location fixes (gives 10 pace samples)
    // Moving at ~5 m/s (18 km/h - jogging pace)
    for step in 0...10 {  // Changed to 0...10 (inclusive)
        let lat = startLat + (Double(step) * 0.00004)  // Move ~4.4 meters north per step
        let timestamp = startTime.addingTimeInterval(Double(step) * 1.0)
        
        let fix = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: lat, longitude: startLon),
            altitude: 0,
            horizontalAccuracy: 10,
            verticalAccuracy: 10,
            timestamp: timestamp
        )
        
        let distanceRemaining = 1000.0 - Double(step * 44)
        
        await engine.update(
            fix: fix,
            distanceRemaining: max(0, distanceRemaining),
            targetFinishSeconds: 600
        )
        
        let result = await engine.result
        
        if step < 10 {
            print("   Sample \(step + 1): Buffer filling... isReady = \(result.isReady)")
        } else {
            print("   Sample \(step + 1): Buffer FULL! isReady = \(result.isReady)")
            print("   ETA: \(result.formattedETA)")
            print("   Finish Time: \(result.formattedFinishTime)")
            print("   Verdict: \(result.verdict.description)")
        }
    }
    
    print("   ✓ Buffer should fill after 10 pace samples (11 location fixes)")
    
    // Test 2: On Pace Detection
    print("\n📍 Test 2: On Pace Detection")
    
    await engine.reset()
    await engine.startSession()
    
    let test2Start = Date()
    
    // Simulate fast pace (will be on pace)
    for step in 0...10 {  // 11 fixes = 10 pace samples
        let lat = startLat + (Double(step) * 0.00009)  // Fast pace ~10m per second
        let timestamp = test2Start.addingTimeInterval(Double(step) * 1.0)
        
        let fix = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: lat, longitude: startLon),
            altitude: 0,
            horizontalAccuracy: 10,
            verticalAccuracy: 10,
            timestamp: timestamp
        )
        
        await engine.update(
            fix: fix,
            distanceRemaining: 500.0,
            targetFinishSeconds: 300
        )
    }
    
    let fastResult = await engine.result
    print("   Fast Pace:")
    print("   ETA: \(fastResult.formattedETA)")
    print("   Will Finish At: \(fastResult.formattedFinishTime)")
    print("   Verdict: \(fastResult.verdict.description)")
    print("   ✓ Should be 'On Pace' with fast movement")
    
    // Test 3: Behind Pace
    print("\n📍 Test 3: Behind Pace Detection")
    
    await engine.reset()
    await engine.startSession()
    
    let test3Start = Date()
    
    // Simulate slow pace (will be behind)
    for step in 0...10 {
        let lat = startLat + (Double(step) * 0.000018)  // Slow pace ~2m per second
        let timestamp = test3Start.addingTimeInterval(Double(step) * 1.0)
        
        let fix = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: lat, longitude: startLon),
            altitude: 0,
            horizontalAccuracy: 10,
            verticalAccuracy: 10,
            timestamp: timestamp
        )
        
        await engine.update(
            fix: fix,
            distanceRemaining: 500.0,
            targetFinishSeconds: 60  // 1 minute target - too fast at this pace
        )
    }
    
    let slowResult = await engine.result
    print("   Slow Pace:")
    print("   ETA: \(slowResult.formattedETA)")
    print("   Will Finish At: \(slowResult.formattedFinishTime)")
    print("   Verdict: \(slowResult.verdict.description)")
    print("   ✓ Should be 'Behind' with slow movement")
    
    // Test 4: Median Calculation (Outlier Rejection)
    print("\n📍 Test 4: Median Pace (Outlier Rejection)")
    
    await engine.reset()
    await engine.startSession()
    
    let test4Start = Date()
    
    // Most samples at consistent pace, with one outlier
    var cumulativeLat = startLat
    for step in 0...10 {
        if step > 0 {
            if step == 5 {
                cumulativeLat += 0.0002  // Outlier - big jump
            } else {
                cumulativeLat += 0.00005  // Normal pace ~5.5 meters
            }
        }
        
        let timestamp = test4Start.addingTimeInterval(Double(step) * 1.0)
        
        let fix = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: cumulativeLat, longitude: startLon),
            altitude: 0,
            horizontalAccuracy: 10,
            verticalAccuracy: 10,
            timestamp: timestamp
        )
        
        await engine.update(
            fix: fix,
            distanceRemaining: 1000.0,
            targetFinishSeconds: 600
        )
    }
    
    let medianResult = await engine.result
    print("   With Outlier:")
    print("   ETA: \(medianResult.formattedETA)")
    print("   Will Finish At: \(medianResult.formattedFinishTime)")
    print("   ✓ Median should reject the outlier and give reasonable ETA")
    
    // Test 5: Stalled Detection
    print("\n📍 Test 5: Stalled Detection")
    
    await engine.reset()
    await engine.startSession()
    
    let test5Start = Date()
    
    // Simulate barely moving (stalled)
    for step in 0...10 {
        let lat = startLat + (Double(step) * 0.000001)  // Barely moving ~0.11m per second
        let timestamp = test5Start.addingTimeInterval(Double(step) * 1.0)
        
        let fix = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: lat, longitude: startLon),
            altitude: 0,
            horizontalAccuracy: 10,
            verticalAccuracy: 10,
            timestamp: timestamp
        )
        
        await engine.update(
            fix: fix,
            distanceRemaining: 500.0,
            targetFinishSeconds: 300
        )
    }
    
    let stalledResult = await engine.result
    print("   Barely Moving:")
    print("   ETA: \(stalledResult.formattedETA)")
    print("   Will Finish At: \(stalledResult.formattedFinishTime)")
    print("   Verdict: \(stalledResult.verdict.description)")
    print("   ✓ Should detect 'Stalled' state")
    
    print("\n==================================================")
    print("✅ All ETAEngine Tests Completed!")
    print("==================================================\n")
}

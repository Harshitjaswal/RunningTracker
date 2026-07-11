//
//  ETAEngine.swift
//  RunningTracker
//
//  Created by Harshit on 11/07/26.
//

import Foundation
import CoreLocation

actor ETAEngine {
    
    // MARK: - Types
    
    enum Verdict: Sendable {
        case onPace
        case behind
        
        var description: String {
            switch self {
            case .onPace: return "On Pace"
            case .behind: return "Behind"
            }
        }
    }
    
    struct ETAResult: Sendable {
        let etaSeconds: Double?
        let projectedFinishTime: Date?
        let verdict: Verdict
        let isReady: Bool
        
        var formattedETA: String {
            guard let s = etaSeconds else { return "—" }
            let m = Int(s) / 60
            let sec = Int(s) % 60
            return String(format: "%d:%02d", m, sec)
        }
        
        var formattedFinishTime: String {
            guard let finishTime = projectedFinishTime else { return "—" }
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: finishTime)
        }
        
        static var notReady: ETAResult {
            ETAResult(etaSeconds: nil, projectedFinishTime: nil, verdict: .onPace, isReady: false)
        }
    }
    
    // MARK: - State
    
    private var paceBuffer: [Double] = []  // Ring buffer of pace samples (seconds/meter)
    private let bufferSize: Int = 10
    private var lastLocation: CLLocation?
    private var currentResult: ETAResult = .notReady
    private var sessionStartTime: Date?
    private var lastDistanceRemaining: Double?
    private var lastTargetFinishSeconds: TimeInterval?
    private var timerTask: Task<Void, Never>?
    
    // MARK: - Constants
    
    private let stalledPaceThreshold: Double = 0.01  // meters/second (very slow)
    
    // MARK: - Public API
    
    func startSession() async {
        sessionStartTime = Date()
        
        // Start 1-second repeating timer
        timerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                await self.recomputeResult()
            }
        }
    }
    
    func update(
        fix: CLLocation,
        distanceRemaining: Double,
        targetFinishSeconds: TimeInterval
    ) async {
        // Store latest values for timer
        lastDistanceRemaining = distanceRemaining
        lastTargetFinishSeconds = targetFinishSeconds
        
        // Set session start if not set
        if sessionStartTime == nil {
            sessionStartTime = Date()
        }
        
        // Calculate pace if we have a previous location
        if let lastLoc = lastLocation {
            let deltaDistance = lastLoc.distance(from: fix)
            let deltaTime = fix.timestamp.timeIntervalSince(lastLoc.timestamp)
            
            // Only add pace sample if we moved enough and time elapsed
            if deltaDistance > 0.1 && deltaTime > 0 {
                let pace = deltaTime / deltaDistance  // seconds per meter
                
                // Add to ring buffer
                paceBuffer.append(pace)
                
                // Keep buffer size fixed at 10
                if paceBuffer.count > bufferSize {
                    paceBuffer.removeFirst()
                }
            }
        }
        
        // Update last location
        lastLocation = fix
        
        // Recompute result
        await recomputeResult()
    }
    
    var result: ETAResult {
        get async {
            return currentResult
        }
    }
    
    func reset() async {
        paceBuffer.removeAll()
        lastLocation = nil
        currentResult = .notReady
        sessionStartTime = nil
        lastDistanceRemaining = nil
        lastTargetFinishSeconds = nil
        
        // Cancel timer
        timerTask?.cancel()
        timerTask = nil
    }
    
    // MARK: - Private Helpers
    
    private func recomputeResult() async {
        guard let distanceRemaining = lastDistanceRemaining,
              let targetFinishSeconds = lastTargetFinishSeconds else {
            return
        }
        
        // Calculate ETA if buffer is full
        if paceBuffer.count == bufferSize {
            let medianPace = calculateMedianPace()
            
            // Check if stalled (pace implies very slow speed)
            let impliedSpeed = 1.0 / medianPace  // meters/second
            
            if impliedSpeed < stalledPaceThreshold {
                // Stalled - mark as not ready
                currentResult = ETAResult(
                    etaSeconds: nil,
                    projectedFinishTime: nil,
                    verdict: .onPace,
                    isReady: false
                )
            } else {
                // Calculate ETA
                let etaSeconds = distanceRemaining * medianPace
                
                // Calculate projected finish time
                let projectedFinishTime = Date().addingTimeInterval(etaSeconds)
                
                // Calculate elapsed time since session start
                let elapsedTime = Date().timeIntervalSince(sessionStartTime ?? Date())
                let projectedTotalTime = elapsedTime + etaSeconds
                
                // Determine verdict
                let verdict: Verdict
                if projectedTotalTime <= targetFinishSeconds {
                    verdict = .onPace
                } else {
                    verdict = .behind
                }
                
                currentResult = ETAResult(
                    etaSeconds: etaSeconds,
                    projectedFinishTime: projectedFinishTime,
                    verdict: verdict,
                    isReady: true
                )
            }
        } else {
            // Buffer not full yet
            currentResult = .notReady
        }
    }
    
    private func calculateMedianPace() -> Double {
        guard !paceBuffer.isEmpty else { return 0 }
        
        let sorted = paceBuffer.sorted()
        let count = sorted.count
        
        if count % 2 == 0 {
            // Even number of elements - average middle two
            let mid1 = sorted[count / 2 - 1]
            let mid2 = sorted[count / 2]
            return (mid1 + mid2) / 2.0
        } else {
            // Odd number of elements - return middle
            return sorted[count / 2]
        }
    }
}

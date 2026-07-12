//
//  IntegrityGate.swift
//  RunningTracker
//
//  Created by Harshit on 11/07/26.
//

import Foundation
import CoreLocation

actor IntegrityGate {
    
    // MARK: - Trust State
    
    enum TrustState: Equatable {
        case trusted    // accuracy < 30m, all checks passed
        case degraded   // accuracy 30–50m, accepted but flagged
        case untrusted  // rejected
        case offRoute   // set by RouteProjector, not here
        
        var description: String {
            switch self {
            case .trusted: return "Trusted"
            case .degraded: return "Degraded"
            case .untrusted: return "Untrusted"
            case .offRoute: return "Off Route"
            }
        }
    }
    
    // MARK: - State
    
    private var lastAcceptedLocation: CLLocation?
    private var lastAcceptedTimestamp: Date?
    
    // MARK: - Validation
    
    func validate(_ location: CLLocation) async -> (location: CLLocation?, trust: TrustState) {
        // Reject invalid coordinates (0, 0)
        if location.coordinate.latitude == 0 && location.coordinate.longitude == 0 {
            return (nil, .untrusted)
        }
        
        // Reject invalid horizontal accuracy
        if location.horizontalAccuracy < 0 || location.horizontalAccuracy > 50 {
            return (nil, .untrusted)
        }
        
        // Reject timestamps more than 5s in the past
        let now = Date()
        let timeDifference = now.timeIntervalSince(location.timestamp)
        if timeDifference > 5.0 {
            return (nil, .untrusted)
        }
        
        // Reject out-of-order timestamps
        if let lastTimestamp = lastAcceptedTimestamp, location.timestamp <= lastTimestamp {
            return (nil, .untrusted)
        }
        
        // Check for teleport (implied speed > 25 m/s)
        if let lastLocation = lastAcceptedLocation {
            let distance = location.distance(from: lastLocation)
            let timeDelta = location.timestamp.timeIntervalSince(lastLocation.timestamp)
            
            // Guard against zero time delta
            if timeDelta > 0 {
                let impliedSpeed = distance / timeDelta
                
                // Reject if speed > 25 m/s (~90 km/h)
                if impliedSpeed > 25.0 {
                    return (nil, .untrusted)
                }
            }
        }
        
        #if DEBUG
        // In DEBUG builds, skip the simulated software check for Simulator compatibility
        #else
        // In RELEASE builds, reject software-simulated fixes
        if let sourceInfo = location.sourceInformation,
           sourceInfo.isSimulatedBySoftware {
            return (nil, .untrusted)
        }
        #endif
        
        // Determine trust level based on accuracy
        let trustState: TrustState
        if location.horizontalAccuracy < 30 {
            trustState = .trusted
        } else {
            trustState = .degraded
        }
        
        // Update state
        lastAcceptedLocation = location
        lastAcceptedTimestamp = location.timestamp
        
        return (location, trustState)
    }
    
    func reset() async {
        lastAcceptedLocation = nil
        lastAcceptedTimestamp = nil
    }
}

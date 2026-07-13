# RunTracker

**iOS Run Tracker** - A SwiftUI-based GPS tracking app that monitors your progress along planned routes with real-time ETA, pace analysis, and route projection.

Built with **Swift 5.9+**, **iOS 17+**, **SwiftUI**, and **Swift Concurrency** (async/await, actors, AsyncStream). Zero third-party dependencies.

---

## Features

### Core Functionality
- **Route Projection** - Custom point-to-segment algorithm projects GPS fixes onto planned routes
- **Live Tracking** - Real-time location updates with CoreLocation integration
- **ETA Computation** - Self-computed ETA using median pace filtering (no MapKit ETA)
- **Location Integrity** - Actor-based validation layer filtering invalid/spoofed GPS fixes
- **Live Path Visualization** - Breadcrumb trail showing actual path traveled
- **Route Greying** - Covered portions fade while remaining route stays highlighted
- **Target Time Verdict** - "On Pace" vs "Behind" indicator updating every second
- **Off-Route Detection** - Alerts when user strays >30m from planned route
- **Run Summary** - Post-run statistics with time, distance, and pace

### UI/UX
- **Adaptive Layout** - Responsive design for iPhone and iPad
- **Dark Mode Support** - Adaptive app logo and theme switching
- **Waypoint Markers** - Color-coded progress indicators on map
- **Trust State Indicator** - Visual feedback for GPS quality (Trusted/Degraded/Untrusted)
- **Permission Handling** - Settings deep-link when location denied

---

## Architecture

### Design Pattern: Actor-Based MVVM

**UI Layer (SwiftUI)**
- `RouteListView` - Route selection with adaptive cards
- `ActiveRunView` - Live tracking map with MapKit
- `HUDOverlayView` - Stats display (progress, ETA, waypoints)
- `RunSummaryView` - Post-run statistics

**State Management (@MainActor)**
- `RunSession` - Central orchestrator, publishes 15+ reactive properties
- Consumes location stream, coordinates 3 isolated actors
- Handles breadcrumb decimation (10m threshold)

**Computation Actors (Isolated)**
1. **IntegrityGate** - GPS validation layer
   - Rejects: accuracy >50m, speed >25 m/s, timestamp jitter
   - Anti-spoof: blocks `isSimulatedBySoftware` in Release builds
   - `#if DEBUG` bypass for Simulator compatibility

2. **RouteProjector** - Point-to-segment projection
   - Planar geometry with cos-latitude scaling
   - Forward-window search (8 segments) for efficiency
   - Monotonic progress guarantee (never decreases)
   - Cross-track distance for off-route detection (>30m)

3. **ETAEngine** - Pace estimation and ETA
   - 5-sample ring buffer with median filtering
   - Recomputes every 1 second (even when stationary)
   - Stall detection (<0.01 m/s)
   - Verdict: compares projected finish vs target time

**Location Providers**
- `LocationProviding` protocol - Abstraction via AsyncStream
- `LiveLocationProvider` - CoreLocation wrapper (production)
- `GPXReplayProvider` - Simulation with densification (debug)

### Data Flow

```
GPS/Simulation → IntegrityGate (validate) 
              → RouteProjector (project) 
              → ETAEngine (compute) 
              → RunSession (publish) 
              → SwiftUI Views
```

### Concurrency Model

- **Strict actor isolation** - No data races, no locks needed
- **AsyncStream** - Backpressure-safe location consumption
- **Task-based lifecycle** - Clean cancellation on stop
- **@MainActor** - UI updates always on main thread

### Project Structure

```
RunningTracker/
├── Core/
│   ├── RunSession.swift          # Main session orchestrator
│   ├── RouteProjector.swift      # Point-to-segment projection
│   └── ETAEngine.swift            # Pace estimation & ETA
├── Location/
│   ├── LocationProviding.swift   # Protocol + providers
│   └── IntegrityGate.swift       # GPS validation actor
├── Models/
│   ├── Route.swift                # Route data model
│   ├── Waypoint.swift             # Waypoint coordinates
│   └── RunSummary.swift           # Post-run statistics
├── Views/
│   ├── RouteListView.swift        # Route selection screen
│   ├── ActiveRunView.swift        # Live tracking map
│   ├── HUDOverlayView.swift       # Stats overlay
│   └── RunSummaryView.swift       # Finish summary
├── Utilities/
│   ├── RouteLoader.swift          # JSON route parsing
│   └── *Tests.swift               # Manual test runners
├── Resources/
│   └── routes.json                # Route definitions
└── Assets.xcassets/
    └── AppLogo.imageset/          # Adaptive app icon
```

---

## Quick Start

### Prerequisites
- **Xcode 15+**
- **iOS 17+ device or Simulator**
- **macOS** for development

### Build & Run

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd RunningTracker
   ```

2. **Open in Xcode**
   ```bash
   open RunningTracker.xcodeproj
   ```

3. **Select target device**
   - **Simulator**: Select any iOS 17+ simulator (iPhone/iPad)
   - **Physical Device**: Connect device, select it as target, trust developer certificate

4. **Build and Run**
   - Press `Cmd+R` or click Run button
   - Grant location permissions when prompted

### First Run Experience

1. **Route Selection** - Choose from 3 pre-configured routes (Mohali, Punjab area)
2. **Start Tracking** - Tap a route card to begin tracking
3. **Watch Progress** - View live stats: progress %, distance remaining, ETA, pace verdict
4. **Finish** - Complete route to see run summary with stats

---

## GPS Simulation (Simulator Testing)

### How It Works

Instead of bundled `.gpx` files, we use **runtime waypoint densification**:

1. **Routes defined in JSON** (`Resources/routes.json`) with waypoints
2. **GPXReplayProvider** densifies waypoints to ~10m spacing
3. **Adjustable playback speed** (0.1x to 3.0x) via debug menu
4. **Realistic timestamps** - strictly increasing, ~1 fix per second

### Testing in Simulator

1. **Launch app in Simulator** (automatically uses GPXReplayProvider in DEBUG)
2. **Select route** - App starts emitting simulated GPS fixes
3. **Adjust speed** - Tap ellipsis menu → Theme section → set pace multiplier
4. **Watch real-time** - ETA, verdict, and projection update live

**Debug Speed Options:**
- 0.1x - Very slow (test "Behind" verdict)
- 0.5x - Normal running pace (~5 m/s)
- 1.0x - Default
- 2.0x / 3.0x - Fast (test "On Pace" verdict)

### Testing on Physical Device

- **Real GPS** - Uses LiveLocationProvider with actual CoreLocation fixes
- **No simulation** - All location data comes from device GPS
- **Outdoor testing recommended** - Best accuracy in open areas

---

## Key Algorithms

### Route Projection
**Inputs**: GPS fix, route polyline  
**Outputs**: Progress %, distance remaining, footpoint, off-route status

1. Search forward window (8 segments from last position)
2. For each segment: project point onto line using dot product
3. Clamp parameter `t` to [0,1] to stay within segment
4. Calculate cross-track distance (perpendicular offset)
5. Accumulate along-track distance for progress %
6. Flag off-route if cross-track >30m

**Formula**: `t = clamp(dot(P−A, B−A) / dot(B−A, B−A), 0, 1)`  
**Distance**: Haversine for segments, planar for projection

### ETA Calculation
**Inputs**: Consecutive GPS fixes  
**Outputs**: ETA, projected finish time, verdict

1. Calculate pace = Δtime / Δdistance (seconds per meter)
2. Add to 5-sample ring buffer
3. Sort and take median (robust to GPS noise)
4. ETA = remaining distance × median pace
5. Compare elapsed + ETA vs target time for verdict

**Timer**: 1-second repeating task updates ETA even when stationary

### Breadcrumb Decimation
Only add GPS fix to trail if >10m from last point. Prevents coordinate array explosion on long runs.

---

## Testing

### Manual Test Harness

Located in `Utilities/` folder, accessible via debug menu:

1. **Route Projector Tests** - Validates projection math
   - Start position → 0% progress
   - Middle waypoint → ~50% progress  
   - End position → ~98% progress
   - Off-route detection → cross-track >30m

2. **ETA Engine Tests** - Pace calculation accuracy
   - Buffer filling (requires 3+ samples)
   - Median filtering (rejects outliers)
   - Verdict switching (on-pace ↔ behind)

3. **Run Session Tests** - Full integration
   - Complete location stream processing
   - State transitions (untrusted → trusted → finished)

**Access**: Tap ellipsis menu → Tests section

### Test Routes

4 pre-configured routes in `Resources/routes.json`:
- Zscaler-cp67-Zscaler Round Trip (1.7 km , 20 min target)
- Home to Jaypee Enterprise (2.0 km, 10 min target)
- Jaypee to Rudra School (4.0 km, 20 min target)
- McDonald's to Manav Rachna (6.0 km, 30 min target)

---

## Configuration

### Debug Flags

**Location Simulation Bypass** (`IntegrityGate.swift`, line 77-84)
```swift
#if DEBUG
    // Bypass simulated software check in debug builds
#else
    // Reject isSimulatedBySoftware in release builds
#endif
```
**Status**: Active in DEBUG, disabled in RELEASE (as required)

### Adjustable Parameters

**Route Projection** (`RouteProjector.swift`)
- Forward window: 8 segments
- Off-route threshold: 30 meters
- Cross-track calculation: planar with cos-latitude

**ETA Engine** (`ETAEngine.swift`)
- Ring buffer size: 5 samples
- Minimum samples: 3 (for display)
- Stall threshold: 0.01 m/s
- Timer interval: 1 second

**Integrity Gate** (`IntegrityGate.swift`)
- Accuracy threshold: 50 meters
- Teleport threshold: 25 m/s
- Timestamp tolerance: 5 seconds

**Breadcrumb Trail** (`RunSession.swift`)
- Decimation threshold: 10 meters

---

## What's Implemented

### Functional Requirements (FR1-FR5)
- **FR1** - Route projection & progress (custom algorithm, no framework)
- **FR2** - Live tracking + integrity gate (actor-based, AsyncStream)
- **FR3** - Self-computed ETA + verdict (median pace, 1s timer)
- **FR4** - Live path + greying (breadcrumb trail, split polylines)
- **FR5** - Concurrency & smooth UI (actors, 60fps target)

### Additional Features
- Run summary with stats (time, distance, pace, verdict)
- Theme toggle (System/Light/Dark)
- Settings deep-link (location permission denial)
- Adaptive layout (iPhone/iPad responsive)
- Waypoint markers with color-coded progress
- Next waypoint tracking with distance/progress

---

## What's Not Implemented

### Known Gaps
- **Bundled GPX files** - Using runtime densification instead (more flexible)
- **Run history persistence** - Summary shown but not saved to disk
- **XCTest unit tests** - Manual test harness instead

### Why Runtime Densification > GPX Files
1. **No file maintenance** - Edit `routes.json` and it auto-generates
2. **Adjustable speed** - Change pace multiplier on the fly
3. **Always valid** - Timestamps guaranteed strictly increasing
4. **Compact** - 3 routes in 51 lines vs 3 large GPX files

---

## Technical Highlights

### GPS Accuracy & Anti-Spoofing
- **Teleport detection** - Speed >25 m/s rejected
- **Accuracy filter** - Only accepts fixes with accuracy <50m
- **Timestamp validation** - Rejects old (>5s) or out-of-order fixes
- **Software simulation block** - `isSimulatedBySoftware` rejected in Release
- **Off-route awareness** - Trust downgrades to "Degraded" when off-route

### Performance Optimizations
- **Forward-window search** - Only checks 8 segments ahead (not entire route)
- **Monotonic progress** - Never decreases despite GPS jitter
- **Breadcrumb decimation** - 10m threshold prevents memory bloat
- **Median pace filtering** - Rejects GPS outliers better than mean
- **Actor isolation** - Compute off main thread, publish coalesced updates

### Edge Cases Handled
- **Single-point routes** - Graceful handling
- **Zero-length segments** - Skipped in projection
- **Out-and-back loops** - Forward-window prevents backward snapping
- **GPS gaps** - Post-gap re-baseline for teleport detection
- **First fix** - Special handling (no teleport check)
- **Stalled motion** - ETA freezes when pace <0.01 m/s
- **Near-finish** - ETA hides when <1m remaining (prevents "0:00" display)

---

## Development Notes

### Git Workflow
- **main** - Stable releases
- **develop** - Integration branch
- **feat/*** - Feature branches
- **fix/*** - Bug fixes

### Commit Style
```
<type>: <description>

- Bullet points for changes
- Keep under 72 chars per line
```

**Types**: feat, fix, chore, docs, refactor

### Code Style
- **PascalCase** - Types
- **camelCase** - Properties, methods
- **4-space indentation**
- **No force-unwrapping** in core paths
- **Comments** - Only for non-obvious "why", not "what"
- **SwiftUI** - All views, no UIKit
- **async/await** - No Combine in new code (legacy in RunSession)

---

## License

iOS Run Tracker app for educational/portfolio purposes.

---

## Acknowledgments

Built by Harshit Jaswal as a demonstration of:
- iOS development with Swift & SwiftUI
- Concurrent programming with actors
- MapKit & CoreLocation integration
- Real-time algorithm implementation
- Clean architecture & separation of concerns

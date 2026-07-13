//
//  ActiveRunView.swift
//  RunningTracker
//
//  Created by Harshit on 11/07/26.
//

import SwiftUI
import MapKit

struct ActiveRunView: View {
    let route: Route
    @StateObject private var session: RunSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    @State private var mapCameraPosition: MapCameraPosition
    
    init(route: Route) {
        self.route = route
        
        // Set initial camera to show the full route
        let coordinates = route.coordinates
        if !coordinates.isEmpty {
            // Calculate center point
            let avgLat = coordinates.map { $0.latitude }.reduce(0, +) / Double(coordinates.count)
            let avgLon = coordinates.map { $0.longitude }.reduce(0, +) / Double(coordinates.count)
            let center = CLLocationCoordinate2D(latitude: avgLat, longitude: avgLon)
            
            _mapCameraPosition = State(initialValue: .camera(
                MapCamera(centerCoordinate: center, distance: 2000, heading: 0, pitch: 0)
            ))
        } else {
            _mapCameraPosition = State(initialValue: .automatic)
        }
        
        // Use GPXReplayProvider for testing, LiveLocationProvider for production
        #if DEBUG
        // Waypoints are densified to ~10m spacing, emit 1 fix per 2 seconds
        // This simulates ~5 m/s (18 km/h) pace - realistic running/cycling speed
        // 0.5 = 1 fix per 2 seconds, stays well under 25 m/s teleport threshold
        _session = StateObject(wrappedValue: RunSession(
            route: route,
            provider: GPXReplayProvider.fromRoute(route, cadenceMultiplier: 0.5)
        ))
        #else
        _session = StateObject(wrappedValue: RunSession(
            route: route,
            provider: LiveLocationProvider()
        ))
        #endif
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Map
                Map(position: $mapCameraPosition) {
                    // Remaining route (blue)
                    if !session.remainingCoordinates.isEmpty {
                        MapPolyline(coordinates: session.remainingCoordinates)
                            .stroke(.blue, lineWidth: isIPad ? 6 : 4)
                    }
                    
                    // Breadcrumb trail (orange)
                    if session.coveredCoordinates.count > 1 {
                        MapPolyline(coordinates: session.coveredCoordinates)
                            .stroke(.orange, lineWidth: isIPad ? 5 : 3)
                    }
                    
                    // User location
                    if let userLoc = session.userLocation {
                        Annotation("", coordinate: userLoc) {
                            ZStack {
                                Circle()
                                    .fill(.blue)
                                    .frame(width: isIPad ? 28 : 20, height: isIPad ? 28 : 20)
                                Circle()
                                    .stroke(.white, lineWidth: isIPad ? 4 : 3)
                                    .frame(width: isIPad ? 28 : 20, height: isIPad ? 28 : 20)
                            }
                        }
                    }
                    
                    // Foot point (projected position on route)
                    if let footPoint = session.footPoint {
                        Annotation("", coordinate: footPoint) {
                            Circle()
                                .fill(.green.opacity(0.3))
                                .frame(width: isIPad ? 16 : 12, height: isIPad ? 16 : 12)
                        }
                    }

                    // Waypoint markers
                    ForEach(Array(route.waypoints.enumerated()), id: \.element.id) { index, waypoint in
                        Annotation("", coordinate: waypoint.coordinate) {
                            ZStack {
                                Circle()
                                    .fill(waypointColor(for: index))
                                    .frame(width: isIPad ? 24 : 18, height: isIPad ? 24 : 18)
                                Circle()
                                    .stroke(.white, lineWidth: isIPad ? 3 : 2)
                                    .frame(width: isIPad ? 24 : 18, height: isIPad ? 24 : 18)

                                if let name = waypoint.name {
                                    Text(name)
                                        .font(.caption2.bold())
                                        .foregroundStyle(.primary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(.ultraThinMaterial)
                                        .cornerRadius(6)
                                        .offset(y: isIPad ? -20 : -15)
                                }
                            }
                        }
                    }
                }
                .mapStyle(.standard(elevation: .flat))
                .mapControls {
                    MapUserLocationButton()
                    MapCompass()
                }
                .ignoresSafeArea()

                // HUD Overlay
                HUDOverlayView(session: session)

                // Stop button - positioned on top-left to avoid map controls on top-right
                VStack {
                    HStack {
                        Button(action: stopRun) {
                            Image(systemName: "xmark.circle.fill")
                                .font(isIPad ? .largeTitle : .title)
                                .foregroundStyle(.white)
                                .background(
                                    Circle()
                                        .fill(.black.opacity(0.6))
                                        .padding(isIPad ? -12 : -8)
                                )
                        }
                        .padding(isIPad ? 24 : 16)

                        Spacer()
                    }
                    Spacer()
                }
                
                // Finish overlay
                if session.isFinished, let summary = session.runSummary {
                    RunSummaryView(summary: summary, isIPad: isIPad) {
                        dismiss()
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            session.start()
        }
        .onDisappear {
            session.stop()
        }
    }
    
    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }
    
    private func stopRun() {
        session.stop()
        dismiss()
    }

    /// Determine waypoint marker color based on progress
    private func waypointColor(for index: Int) -> Color {
        // Determine which segment user is currently on
        let currentSegmentStart = session.progress * Double(route.waypoints.count - 1)
        let currentWaypointIndex = Int(currentSegmentStart)

        if index == 0 {
            // Start waypoint - green
            return .green
        } else if index == route.waypoints.count - 1 {
            // End waypoint - red
            return .red
        } else if index < currentWaypointIndex {
            // Passed waypoints - gray
            return .gray
        } else if index == currentWaypointIndex + 1 {
            // Next waypoint - orange (highlighted)
            return .orange
        } else {
            // Future waypoints - blue
            return .blue
        }
    }
}

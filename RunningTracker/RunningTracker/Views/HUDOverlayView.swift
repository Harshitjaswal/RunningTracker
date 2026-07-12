//
//  HUDOverlayView.swift
//  RunningTracker
//
//  Created by Harshit on 11/07/26.
//

import SwiftUI

struct HUDOverlayView: View {
    @ObservedObject var session: RunSession
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Adapt layout for iPad/landscape
            if horizontalSizeClass == .regular {
                // iPad or landscape - horizontal layout
                regularSizeLayout
            } else {
                // iPhone portrait - vertical layout
                compactSizeLayout
            }
        }
    }
    
    // MARK: - Compact Layout (iPhone Portrait)
    
    private var compactSizeLayout: some View {
        VStack(spacing: 16) {
            // Progress and Distance
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Progress")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(Int(session.progress * 100))%")
                        .font(.title2.bold())
                }
                
                Divider()
                .opacity(0.3)
                    .frame(height: 40)
                    .opacity(0.3)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Distance Remaining")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(formatDistance(session.distanceRemaining))
                        .font(.title2.bold())
                }
            }
            .padding(.top)

            // Next Waypoint
            if let nextWaypoint = session.nextWaypoint {
                Divider()
                .opacity(0.3)

                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Next Waypoint")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(nextWaypoint.name ?? "Waypoint")
                            .font(.title3.bold())
                            .lineLimit(1)
                    }

                    Divider()
                .opacity(0.3)
                        .frame(height: 40)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Progress to Next")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(Int(session.waypointProgress * 100))%")
                            .font(.title3.bold())
                    }

                    Divider()
                .opacity(0.3)
                        .frame(height: 40)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Distance")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(formatDistance(session.distanceToNextWaypoint))
                            .font(.title3.bold())
                    }
                }
            }

            Divider()
                .opacity(0.3)

            // ETA and Verdict
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ETA")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(session.eta.formattedETA)
                        .font(.title3.bold())
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Finish At")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(session.eta.formattedFinishTime)
                        .font(.title3.bold())
                }
                
                Spacer()
                
                // Verdict chip
                if session.eta.isReady {
                    verdictChip
                }
            }
            
            Divider()
                .opacity(0.3)
            
            // Trust State and Off-Route Status
            statusChips
                .padding(.bottom)
        }
        .padding(.horizontal)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(radius: 10)
        .padding()
    }
    
    // MARK: - Regular Layout (iPad / Landscape)
    
    private var regularSizeLayout: some View {
        HStack(spacing: 24) {
            // Left: Progress & Distance
            VStack(alignment: .leading, spacing: 12) {
                statItem(title: "Progress", value: "\(Int(session.progress * 100))%")
                statItem(title: "Distance", value: formatDistance(session.distanceRemaining))
            }
            
            Divider()
                .opacity(0.3)
                .frame(height: 80)

            // Center: Next Waypoint
            if let nextWaypoint = session.nextWaypoint {
                VStack(alignment: .leading, spacing: 12) {
                    statItem(title: "Next", value: nextWaypoint.name ?? "Waypoint")
                    statItem(title: "Waypoint %", value: "\(Int(session.waypointProgress * 100))%")
                    statItem(title: "Distance", value: formatDistance(session.distanceToNextWaypoint))
                }

                Divider()
                .opacity(0.3)
                    .frame(height: 80)
            }

            // Center-Right: ETA & Finish Time
            VStack(alignment: .leading, spacing: 12) {
                statItem(title: "ETA", value: session.eta.formattedETA)
                statItem(title: "Finish At", value: session.eta.formattedFinishTime)
            }

            Divider()
                .opacity(0.3)
                .frame(height: 80)
            
            // Right: Verdict & Status
            VStack(alignment: .leading, spacing: 12) {
                if session.eta.isReady {
                    verdictChip
                }
                statusChips
            }
        }
        .padding(24)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(radius: 10)
        .padding()
    }
    
    // MARK: - Reusable Components
    
    private func statItem(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.bold())
        }
    }
    
    private var verdictChip: some View {
        HStack(spacing: 4) {
            Image(systemName: verdictIcon)
                .font(.caption)
            Text(session.eta.verdict.description)
                .font(.caption.bold())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(verdictColor.opacity(0.2))
        .foregroundStyle(verdictColor)
        .clipShape(Capsule())
    }
    
    private var statusChips: some View {
        HStack(spacing: 12) {
            // Trust chip
            HStack(spacing: 4) {
                Circle()
                    .fill(trustColor)
                    .frame(width: 8, height: 8)
                Text(session.trustState.description)
                    .font(.caption)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            
            // Off-route indicator
            if session.isOffRoute {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                    Text("Off Route")
                        .font(.caption.bold())
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.orange.opacity(0.2))
                .foregroundStyle(.orange)
                .clipShape(Capsule())
            }
        }
    }
    
    // MARK: - Helpers
    
    private func formatDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.1f km", meters / 1000.0)
        } else {
            return String(format: "%.0f m", meters)
        }
    }
    
    private var verdictIcon: String {
        switch session.eta.verdict {
        case .onPace: return "checkmark.circle.fill"
        case .behind: return "exclamationmark.circle.fill"
        }
    }
    
    private var verdictColor: Color {
        switch session.eta.verdict {
        case .onPace: return .green
        case .behind: return .orange
        }
    }
    
    private var trustColor: Color {
        switch session.trustState {
        case .trusted: return .green
        case .degraded: return .yellow
        case .untrusted: return .red
        case .offRoute: return .orange
        }
    }
}

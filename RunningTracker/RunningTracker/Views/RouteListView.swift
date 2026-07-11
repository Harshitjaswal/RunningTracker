//
//  RouteListView.swift
//  RunningTracker
//
//  Created by Harshit on 11/07/26.
//

import SwiftUI

struct RouteListView: View {
    @State private var routes: [Route] = []
    @State private var loadError: String?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    // Grid columns for iPad
    private var gridColumns: [GridItem] {
        if horizontalSizeClass == .regular {
            // iPad: 2-3 columns depending on size
            return [
                GridItem(.adaptive(minimum: 300, maximum: 400), spacing: 16)
            ]
        } else {
            // iPhone: single column
            return [GridItem(.flexible())]
        }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if let error = loadError {
                    // Error state
                    ContentUnavailableView {
                        Label("Failed to Load Routes", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("Retry") {
                            loadRoutes()
                        }
                    }
                } else if routes.isEmpty {
                    // Loading state
                    ProgressView("Loading routes...")
                } else {
                    // Routes grid/list
                    ScrollView {
                        LazyVGrid(columns: gridColumns, spacing: 16) {
                            ForEach(routes) { route in
                                NavigationLink(destination: ActiveRunView(route: route)) {
                                    RouteCard(route: route)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Routes")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("🧮 Route Projector Tests") {
                            Task { await runRouteProjectorTests() }
                        }
                        Button("⏱️ ETA Engine Tests") {
                            Task { await runETAEngineTests() }
                        }
                        Button("🏃 Run Session Tests") {
                            Task { await runSessionTests() }
                        }
                    } label: {
                        Image(systemName: "testtube.2")
                    }
                }
            }
        }
        .onAppear {
            if routes.isEmpty && loadError == nil {
                loadRoutes()
            }
        }
    }
    
    private func loadRoutes() {
        do {
            routes = try RouteLoader.loadRoutes()
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
    }
}

struct RouteCard: View {
    let route: Route
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Route name
            Text(route.name)
                .font(.title3.bold())
                .foregroundStyle(.primary)
            
            // Stats grid
            if horizontalSizeClass == .regular {
                // iPad: horizontal layout
                HStack(spacing: 24) {
                    statItem(icon: "map", label: "Distance", value: route.formattedDistance)
                    statItem(icon: "clock", label: "Target", value: route.formattedTargetTime)
                    statItem(icon: "location", label: "Points", value: "\(route.waypoints.count)")
                }
            } else {
                // iPhone: vertical layout
                VStack(alignment: .leading, spacing: 8) {
                    statRow(icon: "map", value: route.formattedDistance)
                    statRow(icon: "clock", value: route.formattedTargetTime)
                    statRow(icon: "location", value: "\(route.waypoints.count) waypoints")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.quaternary, lineWidth: 1)
        )
    }
    
    private func statItem(icon: String, label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(label, systemImage: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(.primary)
        }
    }
    
    private func statRow(icon: String, value: String) -> some View {
        Label(value, systemImage: icon)
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }
}

#Preview {
    RouteListView()
}

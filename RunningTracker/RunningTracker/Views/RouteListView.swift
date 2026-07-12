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
    @AppStorage("selectedColorScheme") private var selectedColorScheme: String = "system"

    private var colorScheme: ColorScheme? {
        switch selectedColorScheme {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }
    
    // Grid columns for iPad
    private var gridColumns: [GridItem] {
        if horizontalSizeClass == .regular {
            // iPad: larger cards with better spacing
            return [
                GridItem(.adaptive(minimum: 400, maximum: 600), spacing: 24)
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
                        VStack(spacing: 0) {
                            // Hero header
                            VStack(spacing: 12) {
                                Image("AppLogo")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: horizontalSizeClass == .regular ? 100 : 80, height: horizontalSizeClass == .regular ? 100 : 80)
                                    .clipShape(RoundedRectangle(cornerRadius: horizontalSizeClass == .regular ? 22 : 18))
                                    .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 4)

                                Text("Choose Your Route")
                                    .font(horizontalSizeClass == .regular ? .largeTitle : .title)
                                    .fontWeight(.bold)
                                Text("\(routes.count) routes available")
                                    .font(horizontalSizeClass == .regular ? .title3 : .subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.top, horizontalSizeClass == .regular ? 40 : 24)
                            .padding(.bottom, horizontalSizeClass == .regular ? 32 : 20)

                            LazyVGrid(columns: gridColumns, spacing: horizontalSizeClass == .regular ? 24 : 16) {
                                ForEach(routes) { route in
                                    NavigationLink(destination: ActiveRunView(route: route)) {
                                        RouteCard(route: route)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, horizontalSizeClass == .regular ? 40 : 20)
                            .padding(.bottom, 32)
                        }
                        .frame(maxWidth: horizontalSizeClass == .regular ? 1200 : .infinity)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        // Theme Section
                        Section("Theme") {
                            Button {
                                selectedColorScheme = "system"
                            } label: {
                                if selectedColorScheme == "system" {
                                    Label("System", systemImage: "checkmark")
                                } else {
                                    Label("System", systemImage: "circle.lefthalf.filled")
                                }
                            }

                            Button {
                                selectedColorScheme = "light"
                            } label: {
                                if selectedColorScheme == "light" {
                                    Label("Light", systemImage: "checkmark")
                                } else {
                                    Label("Light", systemImage: "sun.max")
                                }
                            }

                            Button {
                                selectedColorScheme = "dark"
                            } label: {
                                if selectedColorScheme == "dark" {
                                    Label("Dark", systemImage: "checkmark")
                                } else {
                                    Label("Dark", systemImage: "moon.fill")
                                }
                            }
                        }

                        // Tests Section
                        Section("Tests") {
                            Button("🧮 Route Projector Tests") {
                                Task { await runRouteProjectorTests() }
                            }
                            Button("⏱️ ETA Engine Tests") {
                                Task { await runETAEngineTests() }
                            }
                            Button("🏃 Run Session Tests") {
                                Task { await runSessionTests() }
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .preferredColorScheme(colorScheme)
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

    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isIPad ? 20 : 16) {
            // Route name with icon
            HStack(spacing: 12) {
                Image(systemName: "figure.run")
                    .font(.system(size: isIPad ? 32 : 24))
                    .foregroundStyle(.blue.gradient)
                    .frame(width: isIPad ? 50 : 40, height: isIPad ? 50 : 40)
                    .background(.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 4) {
                    Text(route.name)
                        .font(isIPad ? .title2.bold() : .title3.bold())
                        .foregroundStyle(.primary)
                    Text("Tap to start tracking")
                        .font(isIPad ? .subheadline : .caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            // Stats grid
            if isIPad {
                // iPad: horizontal layout with more spacing
                HStack(spacing: 32) {
                    statItem(icon: "map", label: "Distance", value: route.formattedDistance)
                    statItem(icon: "clock", label: "Target", value: route.formattedTargetTime)
                    statItem(icon: "mappin.and.ellipse", label: "Waypoints", value: "\(route.waypoints.count)")
                }
            } else {
                // iPhone: vertical layout
                VStack(alignment: .leading, spacing: 10) {
                    statRow(icon: "map", value: route.formattedDistance)
                    statRow(icon: "clock", value: route.formattedTargetTime)
                    statRow(icon: "mappin.and.ellipse", value: "\(route.waypoints.count) waypoints")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(isIPad ? 28 : 20)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: isIPad ? 20 : 16))
        .shadow(color: .black.opacity(0.08), radius: isIPad ? 12 : 8, x: 0, y: isIPad ? 4 : 2)
        .overlay(
            RoundedRectangle(cornerRadius: isIPad ? 20 : 16)
                .stroke(.quaternary, lineWidth: 1)
        )
    }
    
    private func statItem(icon: String, label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(label, systemImage: icon)
                .font(isIPad ? .body : .caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(isIPad ? .title3.bold() : .subheadline.bold())
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func statRow(icon: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.blue)
                .frame(width: 24)
            Text(value)
                .font(.body)
                .foregroundStyle(.primary)
        }
    }
}

#Preview {
    RouteListView()
}

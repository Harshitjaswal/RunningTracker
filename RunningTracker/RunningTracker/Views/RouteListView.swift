//
//  RouteListView.swift
//  RunningTracker
//
//  Created by Harshit on 11/07/26.
//

import SwiftUI

struct RouteListView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Route List - Coming in Step 6")
                    .font(.headline)
                
                Button("🧮 Run RouteProjector Math Tests") {
                    Task {
                        await runRouteProjectorTests()
                    }
                }
                .buttonStyle(.borderedProminent)
                
                Button("⏱️ Run ETA Engine Tests") {
                    Task {
                        await runETAEngineTests()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .navigationTitle("Routes")
        }
    }
}

#Preview {
    RouteListView()
}

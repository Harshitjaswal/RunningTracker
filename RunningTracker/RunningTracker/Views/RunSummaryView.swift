//
//  RunSummaryView.swift
//  RunningTracker
//
//  Created by Harshit on 12/07/26.
//

import SwiftUI

struct RunSummaryView: View {
    let summary: RunSummary
    let isIPad: Bool
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: isIPad ? 32 : 24) {
                    // Success icon
                    Image(systemName: summary.beatTarget ? "checkmark.circle.fill" : "flag.checkered.circle.fill")
                        .font(.system(size: isIPad ? 100 : 70))
                        .foregroundStyle(summary.beatTarget ? .green : .blue)
                        .padding(.top, isIPad ? 40 : 20)

                    // Title
                    VStack(spacing: 8) {
                        Text("Run Complete!")
                            .font(isIPad ? .system(size: 44, weight: .bold) : .largeTitle.bold())

                        Text(summary.routeName)
                            .font(isIPad ? .title2 : .title3)
                            .foregroundStyle(.secondary)
                    }

                    // Verdict chip
                    HStack(spacing: 8) {
                        Image(systemName: summary.beatTarget ? "checkmark.circle.fill" : "clock.fill")
                            .font(isIPad ? .title3 : .body)
                        Text(summary.beatTarget ? "Beat Target Time!" : "Completed")
                            .font(isIPad ? .title3.bold() : .headline.bold())
                    }
                    .padding(.horizontal, isIPad ? 24 : 16)
                    .padding(.vertical, isIPad ? 12 : 8)
                    .background(summary.beatTarget ? Color.green.opacity(0.2) : Color.blue.opacity(0.2))
                    .foregroundStyle(summary.beatTarget ? .green : .blue)
                    .clipShape(Capsule())

                    // Stats grid
                    VStack(spacing: isIPad ? 20 : 16) {
                        statRow(
                            icon: "clock.fill",
                            label: "Time",
                            value: summary.formattedDuration,
                            target: formatTime(summary.targetTime)
                        )

                        Divider()
                            .opacity(0.3)

                        statRow(
                            icon: "road.lanes",
                            label: "Distance",
                            value: summary.formattedDistance,
                            target: nil
                        )

                        Divider()
                            .opacity(0.3)

                        statRow(
                            icon: "speedometer",
                            label: "Avg Pace",
                            value: summary.formattedAveragePace,
                            target: nil
                        )
                    }
                    .padding(isIPad ? 32 : 24)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: isIPad ? 24 : 20))
                    .padding(.horizontal, isIPad ? 40 : 20)

                    // Done button
                    Button(action: onDismiss) {
                        Text("Done")
                            .font(isIPad ? .title2.bold() : .headline.bold())
                            .frame(maxWidth: .infinity)
                            .padding(isIPad ? 20 : 16)
                            .background(.blue)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: isIPad ? 16 : 12))
                    }
                    .padding(.horizontal, isIPad ? 40 : 20)
                    .padding(.bottom, 32)
                }
            }
        }
        .foregroundStyle(.white)
    }

    private func statRow(icon: String, label: String, value: String, target: String?) -> some View {
        HStack(spacing: isIPad ? 20 : 16) {
            // Icon
            Image(systemName: icon)
                .font(isIPad ? .title : .title3)
                .foregroundStyle(.blue)
                .frame(width: isIPad ? 50 : 40)

            // Label & Value
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(isIPad ? .body : .subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Text(value)
                        .font(isIPad ? .title.bold() : .title3.bold())
                        .foregroundStyle(.primary)

                    if let target = target {
                        Text("/ \(target)")
                            .font(isIPad ? .title3 : .body)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()
        }
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

#Preview {
    RunSummaryView(
        summary: RunSummary(
            id: UUID(),
            routeId: "test",
            routeName: "Home to Jay Pee",
            startTime: Date().addingTimeInterval(-600),
            endTime: Date(),
            totalDistance: 2000,
            actualDistance: 1987,
            targetTime: 600,
            actualTime: 580,
            beatTarget: true,
            averagePace: 0.292
        ),
        isIPad: false,
        onDismiss: {}
    )
}

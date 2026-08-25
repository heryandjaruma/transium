//
//  TransiumLiveActivityWidget.swift
//  transium
//

import ActivityKit
import SwiftUI
import WidgetKit

public struct TransiumLiveActivityWidget: Widget {
    public init() {}

    public var body: some WidgetConfiguration {
        ActivityConfiguration(for: TransiumNavigationActivityAttributes.self) { context in
            // Lock Screen / Notification Center Banner
            TransiumLiveActivityLockScreenView(state: context.state, attributes: context.attributes)
                .activityBackgroundTint(Color.black.opacity(0.85))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded Leading
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        ZStack {
                            Capsule()
                                .fill(Color(red: 0.21, green: 0.49, blue: 0.93))
                                .frame(width: 38, height: 28)

                            Image(systemName: iconName(for: context.state.transportType))
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(context.state.routeName)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                            if let stops = context.state.stopsRemainingText {
                                Text(stops)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                        }
                    }
                    .padding(.leading, 4)
                }

                // Expanded Trailing
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(context.state.etaText)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text("remaining")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .padding(.trailing, 4)
                }

                // Expanded Bottom
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Next Stop:")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.65))

                            Text(context.state.nextStopName)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                        }

                        // Minimalist route progress track
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.2))
                                    .frame(height: 5)

                                Capsule()
                                    .fill(Color(red: 0.21, green: 0.49, blue: 0.93))
                                    .frame(width: max(10, proxy.size.width * CGFloat(context.state.progressFraction)), height: 5)
                            }
                        }
                        .frame(height: 5)
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 4)
                }
            } compactLeading: {
                // Exact reference match: Smooth bright blue pill with white vehicle icon
                ZStack {
                    Capsule()
                        .fill(Color(red: 0.21, green: 0.49, blue: 0.93))
                        .frame(width: 32, height: 22)

                    Image(systemName: iconName(for: context.state.transportType))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                }
                .padding(.leading, 2)
            } compactTrailing: {
                // Dynamic remaining ETA text
                Text(context.state.etaText)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.trailing, 3)
            } minimal: {
                ZStack {
                    Capsule()
                        .fill(Color(red: 0.21, green: 0.49, blue: 0.93))
                        .frame(width: 26, height: 22)

                    Image(systemName: iconName(for: context.state.transportType))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
        }
    }

    private func iconName(for transportType: String) -> String {
        switch transportType {
        case "walk", "transfer":
            return "figure.walk"
        case "mission":
            return "camera.fill"
        default:
            return "bus.fill"
        }
    }
}

// MARK: - Lock Screen Banner View

private struct TransiumLiveActivityLockScreenView: View {
    let state: TransiumNavigationActivityAttributes.ContentState
    let attributes: TransiumNavigationActivityAttributes

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.21, green: 0.49, blue: 0.93))
                    .frame(width: 44, height: 44)

                Image(systemName: state.transportType == "walk" ? "figure.walk" : "bus.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(state.routeName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)

                    if let stops = state.stopsRemainingText {
                        Text("• \(stops)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }

                Text("Approaching \(state.nextStopName)")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(state.etaText)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("ETA")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

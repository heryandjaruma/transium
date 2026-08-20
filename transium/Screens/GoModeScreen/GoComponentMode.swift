//
//  GoComponentMode.swift
//  transium
//
//  Created by Abigail Metanoia Melody on 20/08/26.
//
//  Screen that assembles the reusable pieces from GoComponentOnly.swift, driven by the
//  real JourneyResult a quest was started with. Has no background of its own — it's meant
//  to be overlaid directly on top of HomeScreen's existing LocalBaliMapView, the same way
//  the pre-Go "Navigation Mode" overlay works.
//
//  The bottom panel is a collapsed/expanded toggle, not a modal sheet: collapsed shows the
//  current step as a floating card (no background, matching the map behind it); expanded
//  shows GoTripDetailsPanel, a docked white sheet like NavigationBottomSheet's — so it never
//  fully covers the map/top bar the way a system .sheet() would.

import SwiftUI

struct GoComponentMode: View {
    enum Variant {
        case walking
        case commute
        case commuteOnGoing
    }

    let journey: JourneyResult
    let currentSegmentIndex: Int
    var steps: [JourneyAttemptStep] = []
    var isMuted: Bool = false

    var onBack: () -> Void = {}
    var onEnd: () -> Void = {}
    var onLocate: () -> Void = {}
    var onToggleMute: () -> Void = {}
    /// Tapped the current step's card — advances to the next leg of the trip.
    /// Only offered on walking legs; bus legs are display-only (their card already hosts
    /// the "Download App" action).
    var onAdvanceSegment: () -> Void = {}

    @State private var isTripDetailsExpanded = false

    private var currentSegment: JourneySegment? {
        journey.segments.indices.contains(currentSegmentIndex) ? journey.segments[currentSegmentIndex] : nil
    }

    private var variant: Variant {
        currentSegment?.type == "bus" ? .commute : .walking
    }

    var body: some View {
        VStack {
            GoTopBar(
                onBack: onBack,
                onEnd: onEnd,
                onLocate: onLocate,
                isMuted: isMuted,
                onToggleMute: onToggleMute
            )
            .padding(.top, 6)

            Spacer()

            bottomPanel
        }
    }

    @ViewBuilder
    private var bottomPanel: some View {
        if isTripDetailsExpanded {
            GoTripDetailsPanel(
                journey: journey,
                currentSegmentIndex: currentSegmentIndex,
                steps: steps,
                onCollapse: collapseTripDetails
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
        } else if let segment = currentSegment {
            switch variant {
            case .walking:
                GoBottomPanel(
                    livePill: nil,
                    card: AnyView(walkCard(segment)),
                    onTripDetails: expandTripDetails
                )

            case .commute, .commuteOnGoing:
                GoBottomPanel(
                    livePill: (
                        title: "Check Bus Live Location",
                        subtitle: "Open \(segment.routeName ?? "Transit App")",
                        action: {}
                    ),
                    card: AnyView(
                        GoBusAppCard(
                            providerCode: segment.routeRef ?? "BUS",
                            promptText: "Check bus live location on",
                            appName: segment.routeName ?? "Transit App",
                            downloadLabel: "Download App",
                            onDownload: {}
                        )
                    ),
                    onTripDetails: expandTripDetails
                )
            }
        } else {
            GoBottomPanel(
                livePill: nil,
                card: AnyView(arrivedCard),
                onTripDetails: expandTripDetails
            )
        }
    }

    private func expandTripDetails() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            isTripDetailsExpanded = true
        }
    }

    private func collapseTripDetails() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            isTripDetailsExpanded = false
        }
    }

    private func walkCard(_ segment: JourneySegment) -> some View {
        Button(action: onAdvanceSegment) {
            GoStepCard(
                mode: .walking,
                verb: "Walk to",
                destination: segment.to.name,
                metrics: metrics(for: segment)
            )
        }
        .buttonStyle(.transiumNoOpacity)
    }

    private var arrivedCard: some View {
        GoStepCard(
            mode: .walking,
            verb: "You've arrived at",
            destination: journey.segments.last?.to.name ?? "your destination",
            metricValue: "0",
            metricUnit: "min"
        )
    }

    private func metrics(for segment: JourneySegment) -> [GoStepCard.Metric] {
        var result: [GoStepCard.Metric] = []
        if let duration = segment.durationSeconds {
            result.append(.init("\(Int(round(duration / 60)))", "min"))
        }
        if let distance = segment.distanceMeters {
            result.append(.init(String(format: "%.1f", distance / 1000), "kilometer"))
        }
        return result.isEmpty ? [.init("--", "min")] : result
    }
}

#Preview("Walking") {
    ZStack {
        Color(.systemGray5).ignoresSafeArea()
        GoComponentMode(journey: .previewMock, currentSegmentIndex: 0)
    }
}

#Preview("Commute") {
    ZStack {
        Color(.systemGray5).ignoresSafeArea()
        GoComponentMode(journey: .previewMock, currentSegmentIndex: 1)
    }
}

#Preview("Arrived") {
    ZStack {
        Color(.systemGray5).ignoresSafeArea()
        GoComponentMode(journey: .previewMock, currentSegmentIndex: 2)
    }
}

private extension JourneyResult {
    static var previewMock: JourneyResult {
        let origin = JourneyLocationRef(lat: -8.702105, lng: 115.176189, name: "Current Location", stopId: nil)
        let stop = JourneyLocationRef(lat: -8.6975, lng: 115.1800, name: "Sanur Beach Stop", stopId: "stop-1")
        let destination = JourneyLocationRef(lat: -8.67368, lng: 115.26337, name: "Jimbaran Side Walk", stopId: nil)

        return JourneyResult(
            origin: LatLng(lat: origin.lat, lng: origin.lng),
            destination: LatLng(lat: destination.lat, lng: destination.lng),
            summary: JourneyOverviewSummary(
                distanceMeters: 5200,
                walkingDistanceMeters: 1200,
                walkingDurationSeconds: 900,
                transitDistanceMeters: 4000,
                busLegCount: 1,
                transferCount: 0
            ),
            segments: [
                JourneySegment(type: "walk", from: origin, to: stop, distanceMeters: 1200, durationSeconds: 900),
                JourneySegment(type: "bus", from: stop, to: destination, distanceMeters: 4000, durationSeconds: 900, routeId: "kib-1", routeRef: "KIB", routeName: "Trans Metro Dewata")
            ],
            steps: []
        )
    }
}

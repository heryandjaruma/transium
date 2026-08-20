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
//  The bottom panel is: a floating current-step card (no background, matching the map
//  behind it) sitting above GoTripDetailsPanel, an always-present docked white sheet
//  (like NavigationBottomSheet's) that toggles between a collapsed "Trip Details" peek and
//  the full itinerary — dragging or tapping its handle never covers the map/top bar the way
//  a modal .sheet() would. The floating card hides while the sheet is expanded, since the
//  expanded itinerary already shows the current leg as its own highlighted card.

import CoreLocation
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
    /// The device's live position — when set, the current walking leg's "Walk to X" card
    /// recomputes its distance/time to go from this instead of the route's static estimate.
    var currentLocation: CLLocationCoordinate2D? = nil
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

    private static let busStopProximityMeters: Double = 69

    private var currentSegment: JourneySegment? {
        journey.segments.indices.contains(currentSegmentIndex) ? journey.segments[currentSegmentIndex] : nil
    }

    /// The upcoming bus leg, when the current segment is the walk leading straight to its stop.
    private var upcomingBusSegment: JourneySegment? {
        guard let segment = currentSegment, segment.type != "bus",
              journey.segments.indices.contains(currentSegmentIndex + 1) else { return nil }
        let next = journey.segments[currentSegmentIndex + 1]
        return next.type == "bus" ? next : nil
    }

    /// True once the live distance to the current walking leg's destination (the bus stop)
    /// drops within `busStopProximityMeters` — switches the card over to "check bus live
    /// location" early, before the segment index itself advances.
    private var isNearUpcomingBusStop: Bool {
        guard upcomingBusSegment != nil, let segment = currentSegment,
              let distance = segment.liveRemaining(from: currentLocation).distanceMeters else { return false }
        return distance <= Self.busStopProximityMeters
    }

    private var variant: Variant {
        if currentSegment?.type == "bus" { return .commute }
        if isNearUpcomingBusStop { return .commute }
        return .walking
    }

    /// The segment whose route info (name, ref, color) the commute card should show —
    /// either the current bus leg itself, or the upcoming one when near its stop on the walk in.
    private var busInfoSegment: JourneySegment? {
        currentSegment?.type == "bus" ? currentSegment : upcomingBusSegment
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

    private var bottomPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !isTripDetailsExpanded {
                currentStepCard
            }

            GoTripDetailsPanel(
                journey: journey,
                currentSegmentIndex: currentSegmentIndex,
                steps: steps,
                currentLocation: currentLocation,
                isExpanded: $isTripDetailsExpanded
            )
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var currentStepCard: some View {
        if let segment = currentSegment {
            switch variant {
            case .walking:
                walkCard(segment)

            case .commute, .commuteOnGoing:
                if let busSegment = busInfoSegment {
                    VStack(alignment: .leading, spacing: 10) {
                        GoBusLivePill(
                            title: "Check Bus Live Location",
                            subtitle: "Open \(busSegment.routeName ?? "Transit App")",
                            action: openTMDApp
                        )

                        GoBusAppCard(
                            providerCode: busSegment.routeRef ?? "BUS",
                            promptText: "Check bus live location on",
                            appName: busSegment.routeName ?? "Transit App",
                            downloadLabel: "Download App",
                            onDownload: openTMDAppStorePage
                        )
                    }
                }
            }
        } else {
            arrivedCard
        }
    }

    /// The TMD app has no known custom URL scheme registered in this project yet, so both
    /// "Open" and "Download" currently just send the user to its App Store page.
    private static let tmdAppStoreURL = URL(string: "https://apps.apple.com/id/app/trans-metro-dewata/id6744358191")!

    private func openTMDApp() {
        UIApplication.shared.open(Self.tmdAppStoreURL)
    }

    private func openTMDAppStorePage() {
        UIApplication.shared.open(Self.tmdAppStoreURL)
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
        let live = segment.type != "bus"
            ? segment.liveRemaining(from: currentLocation)
            : (distanceMeters: segment.distanceMeters, durationSeconds: segment.durationSeconds)

        var result: [GoStepCard.Metric] = []
        if let duration = live.durationSeconds {
            result.append(.init("\(max(0, Int(round(duration / 60))))", "min"))
        }
        if let distance = live.distanceMeters {
            result.append(.init(String(format: "%.1f", max(0, distance) / 1000), "kilometer"))
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

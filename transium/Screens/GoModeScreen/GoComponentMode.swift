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
    /// Only read from for the debug "active geofences" share button on GoTripDetailsPanel;
    /// defaults so preview/test call sites don't need one of their own.
    var geofenceMonitor: JourneyGeofenceMonitor = JourneyGeofenceMonitor()
    /// The raw POST /private/journey/go response, when this session actually started that way
    /// (nil if resumed instead). Only read from GoTripDetailsPanel's debug share button.
    var goStartResult: JourneyGoResult? = nil

    var onBack: () -> Void = {}
    var onEnd: () -> Void = {}
    var onLocate: () -> Void = {}
    var onToggleMute: () -> Void = {}
    /// Manual "I'm here" fallback for a specific quest step (mission/photo-checkpoint), passed
    /// straight through to GoTripDetailsPanel — see its own doc comment for why this exists.
    var onManualAdvance: (String) -> Void = { _ in }

    @State private var isTripDetailsExpanded = false

    /// Matches `HomeScreen.segmentArrivalProximityMeters`, which owns the actual leg-to-leg
    /// advance (this view only reads `currentSegmentIndex`, it doesn't change it) — used here
    /// just for the sub-state within an already-current bus leg: still at the boarding stop, or
    /// already riding.
    private static let busStopProximityMeters: Double = 69

    private var currentSegment: JourneySegment? {
        journey.segments.indices.contains(currentSegmentIndex) ? journey.segments[currentSegmentIndex] : nil
    }

    /// True while still near a bus leg's *boarding* stop — i.e., still waiting to board rather
    /// than already riding. Defaults to true (still waiting) with no live position yet, so we
    /// don't jump to "riding" without real GPS evidence. `currentSegmentIndex` only lands on
    /// this bus leg once the walk leg before it already registered arrival at this same stop
    /// (see `HomeScreen.advanceGoSegmentIfNeeded`), so "far from the boarding stop" here can
    /// only mean "moved on since boarding" — no separate road-alignment signal needed.
    private func isNearBoardingStop(_ segment: JourneySegment) -> Bool {
        guard let currentLocation, let from = segment.from else { return true }
        let distance = CLLocation(latitude: currentLocation.latitude, longitude: currentLocation.longitude)
            .distance(from: CLLocation(latitude: from.lat, longitude: from.lng))
        return distance <= Self.busStopProximityMeters
    }

    private var variant: Variant {
        guard let segment = currentSegment, segment.type == "bus" else { return .walking }
        return isNearBoardingStop(segment) ? .commute : .commuteOnGoing
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
                    .padding(.horizontal, 16)
            }

            // No horizontal padding here — the sheet's white surface should span the full
            // screen width edge-to-edge, matching NavigationBottomSheet in the overview;
            // its own content is padded internally instead.
            GoTripDetailsPanel(
                journey: journey,
                currentSegmentIndex: currentSegmentIndex,
                steps: steps,
                currentLocation: currentLocation,
                isExpanded: $isTripDetailsExpanded,
                geofenceMonitor: geofenceMonitor,
                goStartResult: goStartResult,
                onManualAdvance: onManualAdvance
            )
        }
        .padding(.bottom, 8)
    }

    // Blue Card showing current step going on in a trip
    @ViewBuilder
    private var currentStepCard: some View {
        if let segment = currentSegment {
            switch variant {
            case .walking:
                walkCard(segment)

            case .commuteOnGoing:
                rideCard(segment)

            case .commute:
                VStack(alignment: .leading, spacing: 10) {
                    GoBusLivePill(
                        title: "Check Bus Live Location",
                        subtitle: "Open \(segment.routeName ?? "Transit App")",
                        action: openTMDApp
                    )

                    GoBusAppCard(
                        providerCode: segment.routeRef ?? "BUS",
                        promptText: "Check bus live location on",
                        appName: segment.routeName ?? "Transit App",
                        downloadLabel: "Download App",
                        onDownload: openTMDAppStorePage
                    )
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
        GoStepCard(
            mode: .walking,
            verb: "Walk to",
            destination: segment.to?.name ?? "your destination",
            metrics: metrics(for: segment)
        )
    }

    /// Shown once the user is assumed to have boarded (see `isNearBoardingStop`) — the
    /// device's own GPS doubles as a rough proxy for the bus's position while riding, so this
    /// still recomputes distance/time to the alighting stop live, using the segment's own pace.
    private func rideCard(_ segment: JourneySegment) -> some View {
        GoStepCard(
            mode: .bus(providerCode: segment.routeRef ?? "BUS"),
            verb: "Ride to",
            destination: segment.to?.name ?? "your destination",
            metrics: metrics(for: segment)
        )
    }

    private var arrivedCard: some View {
        GoStepCard(
            mode: .walking,
            verb: "You've arrived at",
            destination: journey.destinationName,
            metricValue: "0",
            metricUnit: "min"
        )
    }

    private func metrics(for segment: JourneySegment) -> [GoStepCard.Metric] {
        // Called for the walking leg and, once `isNearBoardingStop` is false, the bus leg
        // being ridden — in both cases the device's live position is a meaningful proxy for
        // progress, so `liveRemaining` (segment's own pace, gracefully falling back to the
        // static estimate with no live fix) applies uniformly.
        let live = segment.liveRemaining(from: currentLocation)

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

#Preview("Riding") {
    // Current location far from the bus segment's boarding stop, simulating "already boarded".
    ZStack {
        Color(.systemGray5).ignoresSafeArea()
        GoComponentMode(
            journey: .previewMock,
            currentSegmentIndex: 1,
            currentLocation: CLLocationCoordinate2D(latitude: -8.685, longitude: 115.20)
        )
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
                JourneySegment(type: "bus", from: stop, to: destination, distanceMeters: 4000, durationSeconds: 900, routeId: "kib-1", routeRef: "KIB", routeName: "Trans Metro Dewata"),
                JourneySegment(type: "mission", instructions: "Find two beach lights", lat: destination.lat, lng: destination.lng)
            ],
            steps: []
        )
    }
}

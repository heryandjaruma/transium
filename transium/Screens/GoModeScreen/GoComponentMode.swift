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

    /// Segment ids the live position has ever come within `busStopProximityMeters` of.
    /// `currentSegmentIndex` only advances on a manual tap (see `onAdvanceSegment`), so while
    /// still nominally on the walk-to-stop leg, this is what lets us tell "far from the stop
    /// because we haven't arrived yet" apart from "far because we boarded and it pulled away" —
    /// a bare distance check alone can't distinguish those without remembering having been close.
    @State private var everNearStopSegmentIds: Set<String> = []

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

    /// Live distance from the current position to `segment`'s destination, when both are known.
    private func liveDistance(to segment: JourneySegment) -> Double? {
        segment.liveRemaining(from: currentLocation).distanceMeters
    }

    /// True while still near the current bus leg's *boarding* stop — i.e., still waiting.
    /// Defaults to true (still waiting) with no live position yet, so we don't jump to
    /// "riding" without real GPS evidence.
    private var isNearBoardingStop: Bool {
        guard let segment = currentSegment, segment.type == "bus", let currentLocation else { return true }
        let distance = CLLocation(latitude: currentLocation.latitude, longitude: currentLocation.longitude)
            .distance(from: CLLocation(latitude: segment.from.lat, longitude: segment.from.lng))
        return distance <= Self.busStopProximityMeters
    }

    private var variant: Variant {
        if let segment = currentSegment, segment.type == "bus" {
            return isNearBoardingStop ? .commute : .commuteOnGoing
        }

        guard let segment = currentSegment, let busSegment = upcomingBusSegment else {
            return .walking
        }

        // Primary signal: the live position is on/near the bus's own road — this alone is
        // enough to call it "riding", regardless of whether the walk to the stop ever
        // registered as close (GPS noise, boarding slightly off the marked stop coordinate,
        // or a missed update near the stop can all mean that moment is never observed).
        if busSegment.isAligned(with: currentLocation) {
            return .commuteOnGoing
        }

        guard let distance = liveDistance(to: segment) else {
            return everNearStopSegmentIds.contains(segment.id) ? .commuteOnGoing : .walking
        }

        if distance <= Self.busStopProximityMeters {
            return .commute
        }
        // Far from the stop, not aligned to the route road (e.g. geometry resolution fell back
        // to a straight line): fall back to "was ever close, now far" as a secondary signal.
        return everNearStopSegmentIds.contains(segment.id) ? .commuteOnGoing : .walking
    }

    /// The segment whose route info (name, ref, color) the commute/ride card should show —
    /// either the current bus leg itself, or the upcoming one when near its stop (or riding
    /// away from it) on the walk leading into it.
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
        .onAppear { recordProximityIfNeeded() }
        .onChange(of: currentLocation?.latitude) { _, _ in recordProximityIfNeeded() }
        .onChange(of: currentLocation?.longitude) { _, _ in recordProximityIfNeeded() }
    }

    private func recordProximityIfNeeded() {
        guard let segment = currentSegment, segment.type != "bus", upcomingBusSegment != nil,
              let distance = liveDistance(to: segment), distance <= Self.busStopProximityMeters else { return }
        everNearStopSegmentIds.insert(segment.id)
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

            case .commuteOnGoing:
                if let busSegment = busInfoSegment {
                    rideCard(busSegment)
                }

            case .commute:
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

    /// Shown once the user is assumed to have boarded (see `isNearBoardingStop`) — the
    /// device's own GPS doubles as a rough proxy for the bus's position while riding, so this
    /// still recomputes distance/time to the alighting stop live, using the segment's own pace.
    private func rideCard(_ segment: JourneySegment) -> some View {
        GoStepCard(
            mode: .bus(providerCode: segment.routeRef ?? "BUS"),
            verb: "Ride to",
            destination: segment.to.name,
            metrics: metrics(for: segment)
        )
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
                JourneySegment(type: "bus", from: stop, to: destination, distanceMeters: 4000, durationSeconds: 900, routeId: "kib-1", routeRef: "KIB", routeName: "Trans Metro Dewata")
            ],
            steps: []
        )
    }
}

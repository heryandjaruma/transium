//
//  GoTripDetailsPanel.swift
//  transium
//
//  Go Mode's bottom sheet — presented by GoComponentMode as a real, native .sheet with
//  presentationDetents (collapsed "Trip Details" peek vs. the full itinerary) and
//  presentationBackgroundInteraction(.enabled), so the map/top bar stay interactive
//  underneath it while dragging still gets genuine system sheet physics (live finger
//  tracking, rubber-banding, velocity-based settle) instead of a hand-rolled DragGesture.
//  This view is just the sheet's content — no background/corner/shadow chrome of its own,
//  and no expanded/collapsed branching: it always lays out the full itinerary and lets the
//  sheet's current detent height decide how much of it is visible.
//
//  The current leg is highlighted as a blue "active" card; the quest's own photo-checkpoint
//  steps (from POST /private/journey/go, unrelated in the API to the route's segments) are
//  matched onto the nearest segment by straight-line distance to its destination, best-effort
//  — there's no server-side link between the two.

import CoreLocation
import SwiftUI

struct GoTripDetailsPanel: View {
    let journey: JourneyResult
    let currentSegmentIndex: Int
    let steps: [JourneyAttemptStep]
    var currentLocation: CLLocationCoordinate2D? = nil
    var geofenceMonitor: JourneyGeofenceMonitor = JourneyGeofenceMonitor()
    var goStartResult: JourneyGoResult? = nil
    /// POST /private/journey/{id}/advance's own doc calls this "a geofence trigger, or a
    /// manual arrival check" — this is the latter: a fallback for when the geofence doesn't
    /// fire (GPS drift, being outside the server's own ~150m tolerance, etc.), wired by the
    /// caller to the exact same handler a real geofence trigger uses.
    var onManualAdvance: (String) -> Void = { _ in }
    @Binding var isExpanded: Bool

    @GestureState private var dragOffset: CGFloat = 0
    @State private var isStopsExpanded: [String: Bool] = [:]
    #if DEBUG
    @State private var debugShareItem: DebugShareItem?
    #endif

    private static let doneBackground = Color(red: 0.86, green: 0.97, blue: 0.89)
    private static let doneAccent = Color(red: 0.06, green: 0.72, blue: 0.51)

    private var matchedSteps: [String: JourneyAttemptStep] {
        // Anything already surfaced precisely by its own `missionCard` shouldn't also be
        // guessed at here. Exact via `stepId` when the mission resolved one (GET /journey/real
        // is now attempt-scoped for the whole Go Mode session — see HomeScreen.startGoMode/
        // resumeOngoingTrip); falls back to a coordinate proximity guard only if a mission
        // somehow has none (e.g. the attempt-scoped re-fetch failed and this session is still
        // on the earlier, un-scoped preview fetch).
        let missionStepIds: Set<String> = Set(journey.segments.compactMap { $0.isMission ? $0.stepId : nil })
        let missionLocations: [CLLocation] = journey.segments.compactMap { segment in
            guard segment.isMission, segment.stepId == nil, let coordinate = segment.coordinate else { return nil }
            return CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        }

        let candidates: [(step: JourneyAttemptStep, location: CLLocation)] = steps.compactMap { step in
            guard step.isPhotoCheckpoint, !missionStepIds.contains(step.id),
                  let lat = step.lat, let lng = step.lng else { return nil }
            let location = CLLocation(latitude: lat, longitude: lng)
            guard !missionLocations.contains(where: { $0.distance(from: location) <= 50 }) else { return nil }
            return (step, location)
        }

        var assignments: [String: JourneyAttemptStep] = [:]
        var usedStepIds = Set<String>()

        for segment in journey.segments {
            // Mission segments have no `to` to match a photo-checkpoint against — only travel
            // legs (walk/bus/transfer) do.
            guard let to = segment.to else { continue }
            let destination = CLLocation(latitude: to.lat, longitude: to.lng)
            let nearest = candidates
                .filter { !usedStepIds.contains($0.step.id) }
                .min { $0.location.distance(from: destination) < $1.location.distance(from: destination) }

            guard let nearest, nearest.location.distance(from: destination) <= 500 else { continue }
            assignments[segment.id] = nearest.step
            usedStepIds.insert(nearest.step.id)
        }

        return assignments
    }

    /// Steps with no coordinates at all — no `missionCard` in `journey.segments` accounts for
    /// these (a located step's own route entry), so they'd otherwise never appear anywhere in
    /// this timeline. Shown via `manualActionCard` instead, each with its own "I've done it".
    private var unlocatedActionSteps: [JourneyAttemptStep] {
        steps.filter { $0.status == .waiting && $0.lat == nil }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle area (tappable & draggable)
            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(Color(.systemGray3))
                    .frame(width: 38, height: 5)
                    .padding(.top, 10)
                    .padding(.bottom, 8)

                // Header summary row
                HStack(alignment: .center, spacing: 0) {
                    // Horizontal timeline chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(Array(timelineChips.enumerated()), id: \.offset) { index, chip in
                                if index > 0 {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(.gray.opacity(0.45))
                                }

                                switch chip {
                                case .walk(let minutes, let isMissionWalk):
                                    if isMissionWalk {
                                        HStack(spacing: 4) {
                                            Image(systemName: "figure.walk")
                                                .font(.system(size: 12, weight: .bold))
                                            Text("\(minutes) m")
                                                .font(TransiumFont.body(11, weight: .bold))
                                        }
                                        .foregroundColor(Color(red: 0.05, green: 0.62, blue: 0.42))
                                        .padding(.horizontal, 8)
                                        .frame(height: 28)
                                        .background(Color(red: 0.05, green: 0.62, blue: 0.42).opacity(0.12))
                                        .clipShape(Capsule())
                                    } else {
                                        HStack(spacing: 4) {
                                            Image(systemName: "figure.walk")
                                                .font(.system(size: 13, weight: .medium))
                                            Text("\(minutes) m")
                                                .font(TransiumFont.body(11, weight: .semibold))
                                        }
                                        .foregroundColor(.gray)
                                        .padding(.horizontal, 6)
                                        .frame(height: 28)
                                    }

                                case .bus(let routeRef):
                                    HStack(spacing: 5) {
                                        Image(systemName: "bus.fill")
                                            .font(.system(size: 11, weight: .semibold))
                                        Text(routeRef.truncatedAtDash)
                                            .font(TransiumFont.body(11, weight: .bold))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .frame(height: 28)
                                    .background(TransiumTransitColor.color(for: routeRef))
                                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

                                case .missionPoint(let name, let number):
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(Color(red: 0.98, green: 0.72, blue: 0.12))
                                            .frame(width: 6, height: 6)

                                        Image(systemName: "flag.fill")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(Color(red: 0.85, green: 0.55, blue: 0.05))

                                        Text(name.count > 16 ? "Mission \(number)" : name)
                                            .font(TransiumFont.body(11, weight: .bold))
                                            .foregroundColor(Color(red: 0.82, green: 0.52, blue: 0.04))
                                            .lineLimit(1)
                                    }
                                    .padding(.horizontal, 8)
                                    .frame(height: 28)
                                    .background(Color(red: 0.98, green: 0.72, blue: 0.12).opacity(0.15))
                                    .clipShape(Capsule())
                                }
                            }
                        }
                        .frame(height: 28)
                    }

                    Spacer(minLength: 12)

                    #if DEBUG
                    HStack(spacing: 4) {
                        Button(action: shareGoStartResultJSON) {
                            Image(systemName: "play.circle")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(goStartResult == nil ? Color(.systemGray4) : .secondary)
                        }
                        .disabled(goStartResult == nil)
                        Button(action: shareActiveGeofencesJSON) {
                            Image(systemName: "location.circle")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        Button(action: shareJourneyDebugJSON) {
                            Image(systemName: "ladybug")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.trailing, 6)
                    #endif

                    Text(formattedDuration)
                        .font(TransiumFont.body(20, weight: .black))
                        .foregroundColor(.black)
                        .fixedSize()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, isExpanded ? 14 : 10)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    isExpanded.toggle()
                }
            }
            .gesture(
                DragGesture()
                    .onEnded { value in
                        let verticalAmount = value.translation.height
                        if verticalAmount > 25 {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                isExpanded = false
                            }
                        } else if verticalAmount < -25 {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                isExpanded = true
                            }
                        }
                    }
            )

            // Scrollable detailed steps timeline (collapsible)
            if isExpanded {
                ScrollView(.vertical, showsIndicators: true) {
                    timeline
                        .padding(.horizontal, 20)
                        .padding(.bottom, 50)
                }
                .frame(maxHeight: 460)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .gesture(
            DragGesture()
                .updating($dragOffset) { value, state, _ in
                    state = value.translation.height
                }
                .onEnded { value in
                    let verticalAmount = value.translation.height
                    if verticalAmount > 35 {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            isExpanded = false
                        }
                    } else if verticalAmount < -35 {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            isExpanded = true
                        }
                    }
                }
        )
        .frame(maxWidth: .infinity)
        .padding(.bottom, isExpanded ? 20 : 28)
        .background(Color.white)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 24, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 12, y: -4)
        .overlay(alignment: .bottom) {
            Color.white
                .frame(height: 120)
                .offset(y: 120)
        }
        #if DEBUG
        .sheet(item: $debugShareItem) { item in
            ActivityShareSheet(activityItems: [item.url])
        }
        #endif
    }

//    private var leaveArriveBar: some View {
//        HStack {
//            Text("Leave within **1 min**")
//            Spacer()
//            Text("Arrive **\(arrivalTime)**")
//        }
//        .font(TransiumFont.body(14))
//        .foregroundColor(Color(red: 0.05, green: 0.45, blue: 0.22))
//        .padding(.horizontal, 16)
//        .frame(height: 46)
//        .background(Color(red: 0.86, green: 0.97, blue: 0.89))
//        .cornerRadius(12)
//    }

    // MARK: - Timeline

    private var timeline: some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(Color(red: 0.06, green: 0.72, blue: 0.51))
                .frame(width: 4)
                .padding(.leading, 30)
                .padding(.vertical, 24)

            VStack(spacing: 12) {
                ForEach(Array(journey.segments.enumerated()), id: \.offset) { index, segment in
                    if segment.isMission {
                        // Already in the right place — the API emits mission entries right
                        // after the travel leg (if any) that reaches them, in step-sequence order.
                        missionCard(segment, isDone: index < currentSegmentIndex)
                    } else if index == currentSegmentIndex {
                        activeCard(segment, index: index)
                    } else if segment.type == "bus" {
                        inactiveBusCard(segment, isDone: index < currentSegmentIndex)
                    } else {
                        inactiveWalkCard(segment, index: index, isDone: index < currentSegmentIndex)
                    }
                }

                ForEach(unlocatedActionSteps) { step in
                    manualActionCard(step)
                }
            }
        }
    }

    // MARK: - Active Card (current leg)

    private func activeCard(_ segment: JourneySegment, index: Int) -> some View {
        let boardingSegment: JourneySegment? = {
            guard segment.type != "bus", journey.segments.indices.contains(index + 1) else { return nil }
            let next = journey.segments[index + 1]
            return next.type == "bus" ? next : nil
        }()

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Color.white.opacity(0.2)).frame(width: 36, height: 36)
                    Image(systemName: segment.type == "bus" ? "bus.fill" : "figure.walk")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }

                Text(segment.type == "bus" ? "Ride to \(segment.to?.name ?? "destination")" : "Walk to \(segment.to?.name ?? "destination")")
                    .font(TransiumFont.body(15, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Spacer()

                let activeRemaining = segment.type != "bus"
                    ? segment.liveRemaining(from: currentLocation)
                    : (distanceMeters: segment.distanceMeters, durationSeconds: segment.durationSeconds)
                if let dur = activeRemaining.durationSeconds {
                    Text(formatDurationText(dur))
                        .font(TransiumFont.body(14, weight: .bold))
                        .foregroundColor(.white)
                }
            }

            if let boardingSegment {
                Divider().overlay(Color.white.opacity(0.3))
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.turn.down.right")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Wait for \(boardingSegment.routeRef?.truncatedAtDash ?? "the bus") towards \(boardingSegment.to?.name ?? "destination")")
                            .font(TransiumFont.body(13))
                    }
                    HStack(spacing: 8) {
                        Image(systemName: "figure.wave")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Inform the driver your destination")
                            .font(TransiumFont.body(13))
                    }
                }
                .foregroundColor(.white.opacity(0.9))
                .padding(.leading, 8)
            } else if segment.type == "bus" {
                Divider().overlay(Color.white.opacity(0.3))
                stopsMiniTimeline(segment, textColor: .white, mutedColor: .white.opacity(0.75), chipBackground: .white.opacity(0.18), liveLocation: currentLocation)

                if let matched = matchedSteps[segment.id] {
                    Divider().overlay(Color.white.opacity(0.3))
                    questActionRow(matched, tint: .white)
                }
            } else if let matched = matchedSteps[segment.id] {
                Divider().overlay(Color.white.opacity(0.3))
                questActionRow(matched, tint: .white)
            }
        }
        .padding(14)
        .background(TransiumColor.primaryBlue)
        .cornerRadius(16)
    }

    // MARK: - Stops Mini-Timeline (shared between the active and inactive bus cards)

    /// `liveLocation` is only meaningful for the currently-active leg — pass it from
    /// `activeCard` to grey out/checkmark stops already behind the device; `inactiveBusCard`
    /// (a leg not yet reached, or already fully completed) leaves it nil, so nothing here reads
    /// as "passed" independent of the segment's own already-done styling.
    private func stopsMiniTimeline(_ segment: JourneySegment, textColor: Color, mutedColor: Color, chipBackground: Color, liveLocation: CLLocationCoordinate2D? = nil) -> some View {
        let routeColor = TransiumTransitColor.color(for: segment.routeRef, hex: segment.routeColor)
        let stops = segment.stops ?? []
        let stopCount = stops.count
        let isExpanded = isStopsExpanded[segment.id] ?? false
        let passedIndex = liveLocation.flatMap { segment.liveStopIndex(from: $0) } ?? 0
        let lineHeight: CGFloat = isExpanded ? CGFloat(max(1, stopCount - 2) * 22) : 24
        let progress: CGFloat = stopCount > 1 ? CGFloat(min(max(passedIndex, 0), stopCount - 1)) / CGFloat(stopCount - 1) : 0

        return HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                ZStack {
                    Circle().fill(routeColor).frame(width: 12, height: 12)
                    if passedIndex > 0 {
                        Image(systemName: "checkmark")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundColor(.white)
                    }
                }

                ZStack(alignment: .top) {
                    Rectangle().fill(routeColor.opacity(0.25)).frame(width: 3, height: lineHeight)
                    Rectangle().fill(routeColor).frame(width: 3, height: lineHeight * progress)
                }

                Circle().fill(routeColor).opacity(passedIndex >= stopCount - 1 ? 1 : 0.3).frame(width: 12, height: 12)
            }
            .padding(.top, 3)

            VStack(alignment: .leading, spacing: 6) {
                Text(segment.from?.name ?? "")
                    .font(TransiumFont.body(13, weight: .semibold))
                    .foregroundColor(textColor)
                    .strikethrough(passedIndex > 0, color: mutedColor)
                    .opacity(passedIndex > 0 ? 0.55 : 1)

                if stopCount > 2 {
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isStopsExpanded[segment.id] = !isExpanded
                        }
                    }) {
                        HStack(spacing: 4) {
                            Text("\(stopCount - 2) Stops")
                                .font(TransiumFont.body(11, weight: .medium))
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundColor(mutedColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(chipBackground)
                        .cornerRadius(12)
                    }
                    .buttonStyle(.transiumNoOpacity)

                    if isExpanded {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(stops.dropFirst().dropLast().enumerated()), id: \.offset) { offset, stop in
                                let isPassed = (offset + 1) < passedIndex
                                HStack(spacing: 6) {
                                    Image(systemName: isPassed ? "checkmark.circle.fill" : "circle.fill")
                                        .font(.system(size: isPassed ? 10 : 4, weight: .bold))
                                        .foregroundColor(isPassed ? routeColor : mutedColor.opacity(0.5))
                                        .frame(width: 10)
                                    Text(stop.name)
                                        .font(TransiumFont.body(12))
                                        .foregroundColor(mutedColor)
                                        .strikethrough(isPassed, color: mutedColor)
                                        .opacity(isPassed ? 0.55 : 1)
                                }
                            }
                        }
                        .padding(.leading, 4)
                    }
                }

                Text(segment.to?.name ?? "")
                    .font(TransiumFont.body(13, weight: .semibold))
                    .foregroundColor(textColor)
            }

            Spacer()
        }
        .padding(.leading, 4)
    }

    // MARK: - Inactive Cards

    private func inactiveWalkCard(_ segment: JourneySegment, index: Int, isDone: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(isDone ? Self.doneAccent : Color(red: 0.06, green: 0.72, blue: 0.51)).frame(width: 36, height: 36)
                    Image(systemName: isDone ? "checkmark" : "figure.walk")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }

                Text(index == 0 ? "Walk to **\(segment.to?.name ?? "destination")**" : "Walk to **destination**")
                    .font(TransiumFont.body(15, weight: .bold))
                    .foregroundColor(.black)

                Spacer()

                if let dur = segment.durationSeconds {
                    Text(formatDurationText(dur))
                        .font(TransiumFont.body(14, weight: .bold))
                        .foregroundColor(.black)
                }
            }

            if let matched = matchedSteps[segment.id] {
                Divider()
                questActionRow(matched, tint: .black)
            }
        }
        .padding(14)
        .background(isDone ? Self.doneBackground : Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(isDone ? Self.doneAccent.opacity(0.4) : Color(.systemGray5), lineWidth: 1))
    }

    private func inactiveBusCard(_ segment: JourneySegment, isDone: Bool) -> some View {
        let routeRef = segment.routeRef ?? "Bus"
        let routeColor = TransiumTransitColor.color(for: segment.routeRef, hex: segment.routeColor)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                if isDone {
                    ZStack {
                        Circle().fill(Self.doneAccent).frame(width: 24, height: 24)
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                    }
                } else {
                    Text(routeRef.truncatedAtDash)
                        .font(TransiumFont.body(12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(routeColor)
                        .cornerRadius(8)
                }

                HStack(spacing: 5) {
                    Text("Get off at")
                        .font(TransiumFont.body(15, weight: .bold))
                        .foregroundColor(.black)
                        .layoutPriority(1)

                    Image("LineIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)

                    Text(segment.to?.name ?? "destination")
                        .font(TransiumFont.body(15, weight: .bold))
                        .foregroundColor(.black)
                        .lineLimit(1)
                }

                Spacer()

                if let dur = segment.durationSeconds {
                    Text("\(Int(round(dur / 60))) min")
                        .font(TransiumFont.body(14, weight: .bold))
                        .foregroundColor(.black)
                }
            }

            Divider()

            stopsMiniTimeline(segment, textColor: .black, mutedColor: .secondary, chipBackground: Color(.systemGray6))

            if let matched = matchedSteps[segment.id] {
                Divider()
                questActionRow(matched, tint: .black)
            }
        }
        .padding(14)
        .background(isDone ? Self.doneBackground : Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(isDone ? Self.doneAccent.opacity(0.4) : Color(.systemGray5), lineWidth: 1))
    }

    // MARK: - Mission Card

    /// A quest step the user must actually do there — GET /journey/real's `mission`-typed
    /// segments, shown as their own card (never merged into a travel-leg card) right after
    /// the leg that reaches it. Display-only here: the "I'm here" confirmation for whichever
    /// mission is actually current lives on `GoComponentMode`'s floating current-step card
    /// instead, so it can't be tapped ahead of time for a mission still further down the list.
    private func missionCard(_ mission: JourneySegment, isDone: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(isDone ? Self.doneAccent : TransiumColor.primaryYellow).frame(width: 36, height: 36)
                    Image(systemName: isDone ? "checkmark" : "questionmark.app.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Mission")
                        .font(TransiumFont.body(11, weight: .bold))
                        .foregroundColor(.secondary)
                    Text(mission.instructions ?? "Complete the mission")
                        .font(TransiumFont.body(15, weight: .bold))
                        .foregroundColor(.black)
                }

                Spacer()
            }
        }
        .padding(14)
        .background(isDone ? Self.doneBackground : Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(isDone ? Self.doneAccent.opacity(0.4) : TransiumColor.primaryYellow.opacity(0.5), lineWidth: 1))
    }

    private func questActionRow(_ step: JourneyAttemptStep, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(tint.opacity(0.85))

                VStack(alignment: .leading, spacing: 2) {
                    Text(step.description.isEmpty ? "Take a pic during your journey" : step.description)
                        .font(TransiumFont.body(13, weight: .semibold))
                        .foregroundColor(tint)
                    Text("Random camera pop-up for your digital keepsake")
                        .font(TransiumFont.body(11))
                        .foregroundColor(tint.opacity(0.7))
                }

                Spacer()
            }

            if step.status != .done, step.isWithinConfirmationRange(of: currentLocation) {
                HStack {
                    Spacer()
                    markDoneButton(for: step, tint: tint)
                }
            }
        }
        .padding(.leading, 8)
    }

    /// A manual fallback for POST /private/journey/{id}/advance's own documented "manual
    /// arrival check" case — wired by the caller to the exact same handler a real geofence
    /// trigger uses, for when the geofence itself doesn't fire. `label`/`icon` default to the
    /// located-step "I'm here" wording; `manualActionCard` overrides them for unlocated steps,
    /// where tapping is the *only* way that step ever gets marked done.
    private func markDoneButton(for step: JourneyAttemptStep, tint: Color, label: String = "I'm here", icon: String = "checkmark.circle") -> some View {
        Button(action: { onManualAdvance(step.id) }) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(label)
                    .font(TransiumFont.body(11, weight: .semibold))
            }
            .foregroundColor(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(tint.opacity(0.12))
            .clipShape(Capsule())
        }
        .buttonStyle(.transiumNoOpacity)
    }

    // MARK: - Manual Action Card

    /// A quest step with no coordinates at all — nothing to geofence, so it has no `missionCard`
    /// counterpart in `journey.segments` (a located step's own account of itself) and would
    /// otherwise be entirely invisible in this timeline. POST /private/journey/{id}/advance
    /// treats just submitting its `stepId` as the "I did this" attestation, trusted client-side
    /// — this card is that attestation's UI. Capture-type steps still get the same camera sheet
    /// on tap, via `onManualAdvance` → HomeScreen.handleGeofenceEntered, which already pops it
    /// for any `isPhotoCheckpoint` step regardless of whether it's located.
    private func manualActionCard(_ step: JourneyAttemptStep) -> some View {
        let isCapture = step.isPhotoCheckpoint
        let icon: String = {
            if isCapture { return "camera.fill" }
            if step.actionType?.localizedCaseInsensitiveContains("step") == true { return "shoeprints.fill" }
            if step.actionType?.localizedCaseInsensitiveContains("walk") == true { return "figure.walk" }
            return "questionmark.app.fill"
        }()

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(TransiumColor.primaryYellow).frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Mission")
                        .font(TransiumFont.body(11, weight: .bold))
                        .foregroundColor(.secondary)
                    Text(step.description.isEmpty ? step.name : step.description)
                        .font(TransiumFont.body(15, weight: .bold))
                        .foregroundColor(.black)
                }

                Spacer()
            }

            Divider()
            HStack {
                Spacer()
                markDoneButton(
                    for: step,
                    tint: TransiumColor.primaryYellow,
                    label: isCapture ? "Take a Photo" : "I've Done It",
                    icon: isCapture ? "camera.fill" : "checkmark.circle"
                )
            }
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(TransiumColor.primaryYellow.opacity(0.5), lineWidth: 1))
    }

    #if DEBUG
    // MARK: - Debug

    /// Writes the `JourneyResult` this panel was handed — i.e. the `best`/`lessWalking`/
    /// `lessTransit` payload from GET /journey/real — to a temp .json file and hands it to the
    /// system share sheet (AirDrop, Save to Files, Mail, etc.) so it can be pulled onto desktop.
    /// A pasteboard copy was tried first but real journeys are big enough that pasting them
    /// anywhere reliably choked, hence a file instead.
    private func shareJourneyDebugJSON() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(journey) else {
            AppToastCenter.shared.showSuccess(title: "Debug", message: "Failed to encode journey JSON.")
            return
        }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("journey-real-\(Int(Date().timeIntervalSince1970)).json")
        do {
            try data.write(to: url)
            debugShareItem = DebugShareItem(url: url)
        } catch {
            AppToastCenter.shared.showSuccess(title: "Debug", message: "Failed to write journey JSON.")
        }
    }

    /// Writes the raw POST /private/journey/go response this Go Mode session started with to a
    /// temp .json file and shares it the same way. Only ever set when this session actually hit
    /// /go (`HomeScreen.startGoMode`) — resuming an ongoing trip doesn't call it, so the button
    /// stays disabled/greyed out for the lifetime of that session instead of showing stale data.
    private func shareGoStartResultJSON() {
        guard let goStartResult else { return }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(goStartResult) else {
            AppToastCenter.shared.showSuccess(title: "Debug", message: "Failed to encode /go response JSON.")
            return
        }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("journey-go-\(Int(Date().timeIntervalSince1970)).json")
        do {
            try data.write(to: url)
            debugShareItem = DebugShareItem(url: url)
        } catch {
            AppToastCenter.shared.showSuccess(title: "Debug", message: "Failed to write /go response JSON.")
        }
    }

    /// Writes every region currently registered with Core Location (identifier = step id, per
    /// `JourneyGeofenceMonitor.startMonitoring`) to a temp .json file and shares it the same
    /// way — empty array if nothing's actively being monitored right now.
    private func shareActiveGeofencesJSON() {
        let regions = geofenceMonitor.activeRegions.map {
            DebugGeofenceInfo(identifier: $0.identifier, latitude: $0.center.latitude, longitude: $0.center.longitude, radiusMeters: $0.radius)
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(regions) else {
            AppToastCenter.shared.showSuccess(title: "Debug", message: "Failed to encode geofences JSON.")
            return
        }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("active-geofences-\(Int(Date().timeIntervalSince1970)).json")
        do {
            try data.write(to: url)
            debugShareItem = DebugShareItem(url: url)
        } catch {
            AppToastCenter.shared.showSuccess(title: "Debug", message: "Failed to write geofences JSON.")
        }
    }
    #endif

    // MARK: - Timing & Timeline Chips

    private var totalSeconds: Double {
        let sum = journey.segments.compactMap { $0.durationSeconds }.reduce(0, +)
        return sum > 0 ? sum : Double(journey.summary.walkingDurationSeconds) + (journey.summary.transitDistanceMeters / 5.5)
    }

    private var formattedDuration: String {
        let totalMinutes = Int(round(totalSeconds / 60))
        if totalMinutes < 60 {
            return "\(totalMinutes) min"
        }
        let hours = totalMinutes / 60
        let mins = totalMinutes % 60
        if mins == 0 {
            return "\(hours)h"
        }
        return "\(hours)h \(mins)m"
    }

    private func formatDurationText(_ seconds: Double) -> String {
        let totalMinutes = max(0, Int(round(seconds / 60)))
        if totalMinutes < 60 {
            return "\(totalMinutes) min"
        }
        let hours = totalMinutes / 60
        let mins = totalMinutes % 60
        if mins == 0 {
            return "\(hours)h"
        }
        return "\(hours)h \(mins)m"
    }

    private var timelineChips: [JourneyTimelineChip] {
        var chips: [JourneyTimelineChip] = []
        var missionCount = 0
        var hasSeenBus = false

        let hasMissions = journey.steps.contains { $0.isMission } || journey.segments.contains { $0.isMission }

        for (index, segment) in journey.segments.enumerated() {
            if segment.isMission {
                missionCount += 1
                chips.append(.missionPoint(name: segment.instructions ?? "Mission", number: missionCount))
            } else if segment.type == "bus" {
                chips.append(.bus(routeRef: segment.routeRef ?? "Bus"))
                hasSeenBus = true
            } else {
                let mins = max(1, Int(round((segment.durationSeconds ?? 0) / 60)))
                let isMissionWalk = hasMissions && hasSeenBus && (index == journey.segments.count - 1 || index == journey.segments.count - 2)
                chips.append(.walk(minutes: mins, isMissionWalk: isMissionWalk))
            }
        }
        return chips
    }
}

#if DEBUG
private struct DebugShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

private struct DebugGeofenceInfo: Codable {
    let identifier: String
    let latitude: Double
    let longitude: Double
    let radiusMeters: Double
}

private struct ActivityShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif

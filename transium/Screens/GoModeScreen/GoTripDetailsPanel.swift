//
//  GoTripDetailsPanel.swift
//  transium
//
//  Go Mode's bottom sheet — one persistent white docked surface (styled after
//  NavigationBottomSheet, the pre-Go overview's own bottom sheet), not a modal .sheet().
//  Collapsed, it's just the drag handle + "Trip Details" label peeking up; dragging it up
//  (or tapping the handle) expands the SAME sheet into the full itinerary, exactly like
//  NavigationBottomSheet's isCollapsed toggle — so it never covers the map/top bar the way
//  a system sheet would, and the handle/label are always part of a real sheet surface
//  rather than floating bare on the map.
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
    @Binding var isExpanded: Bool
    var geofenceMonitor: JourneyGeofenceMonitor = JourneyGeofenceMonitor()
    var goStartResult: JourneyGoResult? = nil

    @State private var isStopsExpanded: [String: Bool] = [:]
    #if DEBUG
    @State private var debugShareItem: DebugShareItem?
    #endif

    private static let doneBackground = Color(red: 0.86, green: 0.97, blue: 0.89)
    private static let doneAccent = Color(red: 0.06, green: 0.72, blue: 0.51)

    private var matchedSteps: [String: JourneyAttemptStep] {
        let candidates: [(step: JourneyAttemptStep, location: CLLocation)] = steps.compactMap { step in
            guard step.name.localizedCaseInsensitiveContains("picture"),
                  let lat = step.lat, let lng = step.lng else { return nil }
            return (step, CLLocation(latitude: lat, longitude: lng))
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

    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color(.systemGray3))
                .frame(width: 38, height: 5)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
                .onTapGesture { toggle() }

            HStack {
                Text("Trip Details")
                    .font(TransiumFont.body(20, weight: .bold))
                    .foregroundStyle(TransiumColor.primaryBlue)
                Spacer()
                #if DEBUG
                Button(action: shareGoStartResultJSON) {
                    Image(systemName: "play.circle")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(goStartResult == nil ? Color(.systemGray4) : .secondary)
                }
                .disabled(goStartResult == nil)
                Button(action: shareActiveGeofencesJSON) {
                    Image(systemName: "location.circle")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                }
                Button(action: shareJourneyDebugJSON) {
                    Image(systemName: "ladybug")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                }
                #endif
            }
            .padding(.horizontal, 20)
            .padding(.bottom, isExpanded ? 10 : 16)

            if isExpanded {
                modeChipsRow
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)

//                leaveArriveBar
//                    .padding(.horizontal, 20)
//                    .padding(.bottom, 16)

                ScrollView(.vertical, showsIndicators: false) {
                    timeline
                        .padding(.horizontal, 20)
                        .padding(.bottom, 28)
                }
                .frame(maxHeight: 380)
                .mask(
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: .black, location: 0.0),
                            .init(color: .black, location: 0.9),
                            .init(color: .clear, location: 1.0)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .gesture(
            DragGesture()
                .onEnded { value in
                    let dy = value.translation.height
                    if dy > 35 {
                        setExpanded(false)
                    } else if dy < -35 {
                        setExpanded(true)
                    }
                }
        )
        .frame(maxWidth: .infinity)
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

    private func toggle() {
        setExpanded(!isExpanded)
    }

    private func setExpanded(_ expanded: Bool) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            isExpanded = expanded
        }
    }

    // MARK: - Header

    private var modeChipsRow: some View {
        HStack(alignment: .center, spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    // Mission steps aren't a travel mode — they don't get a chip here, only
                    // their own card further down in the timeline.
                    ForEach(Array(journey.steps.filter { !$0.isMission }.enumerated()), id: \.offset) { index, step in
                        if index > 0 {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.gray.opacity(0.5))
                        }

                        if step.type == "walk" {
                            HStack(spacing: 3) {
                                Image(systemName: "figure.walk")
                                    .font(.system(size: 13))
                                Text("\(Int(step.durationMinutes ?? 0)) m")
                                    .font(TransiumFont.body(11, weight: .medium))
                            }
                            .foregroundColor(.gray)
                        } else {
                            HStack(spacing: 4) {
                                Image(systemName: "bus.fill")
                                    .font(.system(size: 11))
                                Text((step.routeRef ?? "Bus").truncatedAtDash)
                                    .font(TransiumFont.body(11, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(TransiumTransitColor.color(for: step.routeRef))
                            .cornerRadius(6)
                        }
                    }
                }
            }

            Spacer(minLength: 12)

            Text("\(Int(round(totalSeconds / 60))) min")
                .font(TransiumFont.body(20, weight: .black))
                .foregroundColor(.black)
                .fixedSize()
        }
    }

    private var leaveArriveBar: some View {
        HStack {
            Text("Leave within **1 min**")
            Spacer()
            Text("Arrive **\(arrivalTime)**")
        }
        .font(TransiumFont.body(14))
        .foregroundColor(Color(red: 0.05, green: 0.45, blue: 0.22))
        .padding(.horizontal, 16)
        .frame(height: 46)
        .background(Color(red: 0.86, green: 0.97, blue: 0.89))
        .cornerRadius(12)
    }

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

                finishCard
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
                    Text("\(max(0, Int(round(dur / 60)))) min")
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
                        Text("Wait for \(boardingSegment.routeRef ?? "the bus") towards \(boardingSegment.to?.name ?? "destination")")
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
                stopsMiniTimeline(segment, textColor: .white, mutedColor: .white.opacity(0.75), chipBackground: .white.opacity(0.18))

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

    private func stopsMiniTimeline(_ segment: JourneySegment, textColor: Color, mutedColor: Color, chipBackground: Color) -> some View {
        let routeColor = TransiumTransitColor.color(for: segment.routeRef, hex: segment.routeColor)
        let stopCount = segment.stops?.count ?? 0
        let isExpanded = isStopsExpanded[segment.id] ?? false

        return HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Circle().fill(routeColor).frame(width: 12, height: 12)
                Rectangle().fill(routeColor.opacity(0.7)).frame(width: 3, height: isExpanded ? CGFloat(max(1, stopCount - 2) * 22) : 24)
                Circle().fill(routeColor).frame(width: 12, height: 12)
            }
            .padding(.top, 3)

            VStack(alignment: .leading, spacing: 6) {
                Text(segment.from?.name ?? "")
                    .font(TransiumFont.body(13, weight: .semibold))
                    .foregroundColor(textColor)

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

                    if isExpanded, let stops = segment.stops {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(stops.dropFirst().dropLast().enumerated()), id: \.offset) { _, stop in
                                Text("• \(stop.name)")
                                    .font(TransiumFont.body(12))
                                    .foregroundColor(mutedColor)
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
                    Text("\(Int(round(dur / 60))) min")
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

                Text("Get off at **\(segment.to?.name ?? "destination")**")
                    .font(TransiumFont.body(15, weight: .bold))
                    .foregroundColor(.black)
                    .lineLimit(1)

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
    /// the leg that reaches it.
    private func missionCard(_ mission: JourneySegment, isDone: Bool) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(isDone ? Self.doneAccent : TransiumColor.primaryYellow).frame(width: 36, height: 36)
                Image(systemName: isDone ? "checkmark" : "flag.checkered")
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
        .padding(14)
        .background(isDone ? Self.doneBackground : Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(isDone ? Self.doneAccent.opacity(0.4) : TransiumColor.primaryYellow.opacity(0.5), lineWidth: 1))
    }

    private func questActionRow(_ step: JourneyAttemptStep, tint: Color) -> some View {
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
        }
        .padding(.leading, 8)
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

    // MARK: - Finish Card

    private var finishCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Color.white.opacity(0.2)).frame(width: 36, height: 36)
                    Image(systemName: "flag.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(journey.destinationName)
                        .font(TransiumFont.body(15, weight: .bold))
                        .foregroundColor(.white)
                    Text("Finish the quest to get your badge")
                        .font(TransiumFont.body(12))
                        .foregroundColor(.white.opacity(0.85))
                }

                Spacer()

                Text(arrivalTime)
                    .font(TransiumFont.body(14, weight: .bold))
                    .foregroundColor(.white)
            }

            Divider().overlay(Color.white.opacity(0.3))

            HStack(spacing: 24) {
                Button(action: {
                    AppToastCenter.shared.showSuccess(title: "Saved", message: "Destination saved.")
                }) {
                    Image(systemName: "star")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                }

                Button(action: {
                    AppToastCenter.shared.showSuccess(title: "Shared", message: "Destination link copied.")
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                }

                Button(action: {
                    UIPasteboard.general.string = journey.destinationName
                    AppToastCenter.shared.showSuccess(title: "Copied", message: "Name copied to clipboard.")
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                }

                Spacer()
            }
            .padding(.top, 2)
            .padding(.leading, 8)
        }
        .padding(14)
        .background(TransiumColor.primaryBlue)
        .cornerRadius(16)
    }

    // MARK: - Timing

    private var totalSeconds: Double {
        let sum = journey.segments.compactMap { $0.durationSeconds }.reduce(0, +)
        return sum > 0 ? sum : Double(journey.summary.walkingDurationSeconds) + (journey.summary.transitDistanceMeters / 5.5)
    }

    private var arrivalTime: String {
        let arrivalDate = Date().addingTimeInterval(totalSeconds)
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: arrivalDate)
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

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

    private var matchedSteps: [String: JourneyAttemptStep] {
        let candidates: [(step: JourneyAttemptStep, location: CLLocation)] = steps.compactMap { step in
            guard step.name.localizedCaseInsensitiveContains("picture"),
                  let lat = step.lat, let lng = step.lng else { return nil }
            return (step, CLLocation(latitude: lat, longitude: lng))
        }

        var assignments: [String: JourneyAttemptStep] = [:]
        var usedStepIds = Set<String>()

        for segment in journey.segments {
            let destination = CLLocation(latitude: segment.to.lat, longitude: segment.to.lng)
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
            }
            .padding(.horizontal, 20)
            .padding(.bottom, isExpanded ? 10 : 16)

            if isExpanded {
                modeChipsRow
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)

                leaveArriveBar
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)

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
                    ForEach(Array(journey.steps.enumerated()), id: \.offset) { index, step in
                        if index > 0 {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.gray.opacity(0.5))
                        }

                        if step.type == "walk" {
                            HStack(spacing: 3) {
                                Image(systemName: "figure.walk")
                                    .font(.system(size: 13))
                                Text("\(Int(step.durationMinutes)) m")
                                    .font(TransiumFont.body(11, weight: .medium))
                            }
                            .foregroundColor(.gray)
                        } else {
                            HStack(spacing: 4) {
                                Image(systemName: "bus.fill")
                                    .font(.system(size: 11))
                                Text(step.routeRef ?? "Bus")
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
                    if index == currentSegmentIndex {
                        activeCard(segment, index: index)
                    } else if segment.type == "bus" {
                        inactiveBusCard(segment)
                    } else {
                        inactiveWalkCard(segment, index: index)
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

                Text(segment.type == "bus" ? "Ride to \(segment.to.name)" : "Walk to \(segment.to.name)")
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
                        Text("Wait for \(boardingSegment.routeRef ?? "the bus") towards \(boardingSegment.to.name)")
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
            } else if let matched = matchedSteps[segment.id] {
                Divider().overlay(Color.white.opacity(0.3))
                questActionRow(matched, tint: .white)
            }
        }
        .padding(14)
        .background(TransiumColor.primaryBlue)
        .cornerRadius(16)
    }

    // MARK: - Inactive Cards

    private func inactiveWalkCard(_ segment: JourneySegment, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Color(red: 0.06, green: 0.72, blue: 0.51)).frame(width: 36, height: 36)
                    Image(systemName: "figure.walk")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }

                Text(index == 0 ? "Walk to **\(segment.to.name)**" : "Walk to **destination**")
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
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(.systemGray5), lineWidth: 1))
    }

    private func inactiveBusCard(_ segment: JourneySegment) -> some View {
        let routeRef = segment.routeRef ?? "Bus"
        let routeColor = TransiumTransitColor.color(for: segment.routeRef, hex: segment.routeColor)
        let stopCount = segment.stops?.count ?? 0

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Text(routeRef)
                    .font(TransiumFont.body(12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(routeColor)
                    .cornerRadius(8)

                Text("Get off at **\(segment.to.name)**")
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

            HStack(alignment: .top, spacing: 12) {
                VStack(spacing: 0) {
                    Circle().fill(routeColor).frame(width: 12, height: 12)
                    Rectangle().fill(routeColor.opacity(0.7)).frame(width: 3, height: 24)
                    Circle().fill(routeColor).frame(width: 12, height: 12)
                }
                .padding(.top, 3)

                VStack(alignment: .leading, spacing: 6) {
                    Text(segment.from.name)
                        .font(TransiumFont.body(13, weight: .semibold))
                        .foregroundColor(.black)

                    if stopCount > 2 {
                        Text("\(stopCount - 2) Stops")
                            .font(TransiumFont.body(11, weight: .medium))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                    }

                    Text(segment.to.name)
                        .font(TransiumFont.body(13, weight: .semibold))
                        .foregroundColor(.black)
                }

                Spacer()
            }
            .padding(.leading, 4)

            if let matched = matchedSteps[segment.id] {
                Divider()
                questActionRow(matched, tint: .black)
            }
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(.systemGray5), lineWidth: 1))
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
                    Text(journey.segments.last?.to.name ?? "Destination")
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
                    UIPasteboard.general.string = journey.segments.last?.to.name ?? "Destination"
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

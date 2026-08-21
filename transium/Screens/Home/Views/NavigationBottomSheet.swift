import SwiftUI

struct NavigationBottomSheet: View {
    let journey: JourneyResult
    let onBack: () -> Void
    
    @State private var isCollapsed: Bool = false
    @GestureState private var dragOffset: CGFloat = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Drag handle area (tappable & draggable)
            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(Color(.systemGray3))
                    .frame(width: 38, height: 5)
                    .padding(.vertical, 10)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    isCollapsed.toggle()
                }
            }
            
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
                
                // Formatted Duration (e.g. "1h 3m" or "25 min")
                Text(formattedDuration)
                    .font(TransiumFont.body(20, weight: .black))
                    .foregroundColor(.black)
                    .fixedSize()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
            
//             Leave sub-header card
//            HStack {
//                Text("Leave within **1 min**")
//                    .font(TransiumFont.body(14))
//                    .foregroundColor(.black)
//                
//                Spacer()
//                
//                Text("Arrive **\(arrivalTime)**")
//                    .font(TransiumFont.body(14))
//                    .foregroundColor(.black)
//            }
//            .padding(.horizontal, 16)
//            .frame(height: 46)
//            .background(Color(.systemGray6))
//            .cornerRadius(12)
//            .padding(.horizontal, 20)
//            .padding(.bottom, isCollapsed ? 12 : 16)
            
            // Scrollable detailed steps timeline (collapsible)
            if !isCollapsed {
                ScrollView(.vertical, showsIndicators: false) {
                    StepTimelineView(journey: journey)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 28)
                }
                .frame(maxHeight: 330)
                .mask(
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: .black, location: 0.0),
                            .init(color: .black, location: 0.86),
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
                .updating($dragOffset) { value, state, _ in
                    state = value.translation.height
                }
                .onEnded { value in
                    let verticalAmount = value.translation.height
                    if verticalAmount > 35 {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            isCollapsed = true
                        }
                    } else if verticalAmount < -35 {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            isCollapsed = false
                        }
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

    private var timelineChips: [JourneyTimelineChip] {
        var chips: [JourneyTimelineChip] = []
        var missionCount = 0
        var hasSeenBus = false

        let hasMissions = journey.steps.contains { $0.isMission } || journey.segments.contains { $0.isMission }

        for step in journey.steps {
            if step.isMission {
                missionCount += 1
                chips.append(.missionPoint(name: step.instructions ?? "Mission \(missionCount)", number: missionCount))
            } else if step.type == "ride" || step.type == "bus" {
                hasSeenBus = true
                chips.append(.bus(routeRef: step.routeRef ?? "Bus"))
            } else if step.type == "walk" {
                let mins = Int(step.durationMinutes ?? 0)
                // Filter out 0m transfer/transition walks completely
                if mins <= 0 && !chips.isEmpty {
                    continue
                }
                let isMissionWalk = hasMissions && (hasSeenBus || missionCount > 0)
                chips.append(.walk(minutes: max(1, mins), isMissionWalk: isMissionWalk))
            }
        }

        // Fallback to segments if journey.steps was empty
        if chips.isEmpty {
            for segment in journey.segments {
                if segment.isMission {
                    missionCount += 1
                    chips.append(.missionPoint(name: segment.instructions ?? "Mission \(missionCount)", number: missionCount))
                } else if segment.type == "bus" {
                    chips.append(.bus(routeRef: segment.routeRef ?? "Bus"))
                } else {
                    let mins = Int(round((segment.durationSeconds ?? 0) / 60))
                    if mins <= 0 && !chips.isEmpty {
                        continue
                    }
                    chips.append(.walk(minutes: max(1, mins), isMissionWalk: false))
                }
            }
        }

        return chips
    }
}

// MARK: - Timeline Chip Model

enum JourneyTimelineChip: Identifiable, Equatable {
    case walk(minutes: Int, isMissionWalk: Bool)
    case bus(routeRef: String)
    case missionPoint(name: String, number: Int)

    var id: String {
        switch self {
        case .walk(let minutes, let isMission):
            return "walk-\(minutes)-\(isMission)"
        case .bus(let ref):
            return "bus-\(ref)"
        case .missionPoint(let name, let num):
            return "mission-\(num)-\(name)"
        }
    }

    var isMission: Bool {
        if case .missionPoint = self { return true }
        return false
    }
}

// Custom step timeline view matching uploaded reference layout
struct StepTimelineView: View {
    let journey: JourneyResult
    @State private var isStopsExpanded: [Int: Bool] = [:]
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Continuous green vertical connector line running down behind icon nodes
            Rectangle()
                .fill(Color(red: 0.06, green: 0.72, blue: 0.51)) // Emerald line
                .frame(width: 4)
                .padding(.leading, 30) // Positioned behind icon circles
                .padding(.vertical, 24)
            
            VStack(spacing: 12) {
                ForEach(Array(journey.segments.enumerated()), id: \.offset) { index, segment in
                    if segment.isMission {
                        missionCard(segment)
                    } else if segment.type == "bus" {
                        busRideCard(segment, index: index)
                    } else {
                        walkCard(segment, index: index)
                    }
                }
            }
        }
    }
    
    // MARK: - Walk Card
    @ViewBuilder
    private func walkCard(_ segment: JourneySegment, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                // Emerald circular walk icon
                ZStack {
                    Circle()
                        .fill(Color(red: 0.06, green: 0.72, blue: 0.51))
                        .frame(width: 36, height: 36)
                    Image(systemName: "figure.walk")
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
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
    }
    
    // MARK: - Bus Ride Card
    @ViewBuilder
    private func busRideCard(_ segment: JourneySegment, index: Int) -> some View {
        let stopCount = segment.stops?.count ?? 0
        let isExpanded = isStopsExpanded[index] ?? false
        let routeRef = segment.routeRef ?? "Bus"
        let routeColor = TransiumTransitColor.color(for: segment.routeRef, hex: segment.routeColor)
        
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                // Route Ref Badge with route-specific color
                HStack(spacing: 4) {
                    Image(systemName: "bus.fill")
                        .font(.system(size: 11))
                    Text(routeRef)
                        .font(TransiumFont.body(12, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(routeColor)
                .cornerRadius(8)

                // Transit Fare Badge
                Text("IDR 4.400")
                    .font(TransiumFont.body(11, weight: .bold))
                    .foregroundColor(TransiumColor.primaryBlue)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(TransiumColor.primaryBlue.opacity(0.1))
                    .clipShape(Capsule())
                
                Text("to **\(segment.to?.name ?? "destination")**")
                    .font(TransiumFont.body(14, weight: .bold))
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
            
            // Mini timeline showing Boarding Stop -> Intermediate Stops -> Alighting Stop
            HStack(alignment: .top, spacing: 12) {
                VStack(spacing: 0) {
                    Circle()
                        .fill(routeColor)
                        .frame(width: 12, height: 12)
                    
                    Rectangle()
                        .fill(routeColor.opacity(0.7))
                        .frame(width: 3, height: isExpanded ? CGFloat(max(1, stopCount - 2) * 28) : 24)
                    
                    Circle()
                        .fill(routeColor)
                        .frame(width: 12, height: 12)
                }
                .padding(.top, 3)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(segment.from?.name ?? "")
                        .font(TransiumFont.body(13, weight: .semibold))
                        .foregroundColor(.black)
                    
                    if stopCount > 2 {
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                isStopsExpanded[index] = !isExpanded
                            }
                        }) {
                            HStack(spacing: 4) {
                                Text("\(stopCount - 2) Stops")
                                    .font(TransiumFont.body(11, weight: .medium))
                                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 9, weight: .bold))
                            }
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                        
                        if isExpanded, let stops = segment.stops {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(Array(stops.dropFirst().dropLast().enumerated()), id: \.offset) { _, stop in
                                    Text("• \(stop.name)")
                                        .font(TransiumFont.body(12))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.leading, 4)
                        }
                    }
                    
                    Text(segment.to?.name ?? "")
                        .font(TransiumFont.body(13, weight: .semibold))
                        .foregroundColor(.black)
                }
                
                Spacer()
            }
            .padding(.leading, 4)
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
    }
    
    // MARK: - Mission Card

    /// A quest step the user must actually do there — GET /journey/real's `mission`-typed
    /// segments, shown as their own card (never as an empty-looking "Walk to destination")
    /// right after the leg that reaches it. Mirrors GoTripDetailsPanel's missionCard, styled
    /// to match this screen's cards.
    private func missionCard(_ mission: JourneySegment) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(TransiumColor.primaryYellow)
                    .frame(width: 36, height: 36)
                Image(systemName: "questionmark.app.fill")
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
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(TransiumColor.primaryYellow.opacity(0.5), lineWidth: 1)
        )
    }

}

//
//  SummaryScreen.swift
//  transium
//

import SwiftUI

/// Main screen presented when a journey is completed (`POST /private/journey/{id}/complete`).
/// Shows `SummaryIntroView` for 3 seconds, then transitions into `SummaryCelebrationView`.
struct SummaryScreen: View {
    let result: JourneyCompleteResult
    var journey: JourneyResult? = nil
    var onDismiss: () -> Void = {}

    @State private var showCelebration = false

    private var summary: JourneySummary? { result.summary }
    private var badge: EarnedBadge? { result.badgesAwarded.first }

    private var cards: [StatCardData] {
        guard let summary else {
            if let journey {
                let distKm = max(1, Int((Double(journey.summary.distanceMeters) / 1000).rounded()))
                let walkDist = journey.summary.walkingDistanceMeters
                let estSteps = max(200, Int(Double(walkDist) / 0.75))
                let estCal = max(50, Int(Double(walkDist) * 0.05))
                return [
                    StatCardData(title: "Distance", value: String(distKm), unit: "km", icon: "distance-icon"),
                    StatCardData(title: "Cost Saved", value: "24k", unit: "Rp", icon: "cost-icon"),
                    StatCardData(title: "Calories", value: String(estCal), unit: nil, icon: "calorie-icon"),
                    StatCardData(title: "Total Steps", value: String(estSteps), unit: nil, icon: "steps-icon")
                ]
            }
            return []
        }

        let distanceKm = max(1, Int((summary.distanceMeters / 1000).rounded()))
        let costSaved = summary.rideHailingMotorcycleSavedIdr ?? summary.fuelCostSavedIdr ?? 0
        let calories = max(1, Int(summary.calorie.rounded()))
        let steps = max(1, summary.stepsTaken)

        return [
            StatCardData(
                title: "Distance",
                value: String(distanceKm),
                unit: "km",
                icon: "distance-icon"
            ),
            StatCardData(
                title: "Cost Saved",
                value: Self.formatIdrAbbreviated(costSaved),
                unit: "Rp",
                icon: "cost-icon"
            ),
            StatCardData(
                title: "Calories",
                value: String(calories),
                unit: nil,
                icon: "calorie-icon"
            ),
            StatCardData(
                title: "Total Steps",
                value: String(steps),
                unit: nil,
                icon: "steps-icon"
            )
        ]
    }

    private var originName: String {
        summary?.startPoint ?? journey?.segments.first?.from?.name ?? "Current Location"
    }

    private var destinationName: String {
        summary?.finishPoint ?? journey?.segments.last?.to?.name ?? "Destination"
    }

    private var calorieMessage: String {
        let calories: Int = {
            if let summary { return max(1, Int(summary.calorie.rounded())) }
            if let journey { return max(50, Int(Double(journey.summary.walkingDistanceMeters) * 0.05)) }
            return 250
        }()
        
        return "If more people take public transportation, there’s higher chance we can get even better infrastructures and more frequent services!"
    }

    private var tripTitle: String {
        badge?.badgeName ?? result.journeyAttempt.questName ?? journey?.segments.last?.to?.name ?? "Quest Complete"
    }

    var body: some View {
        ZStack {
            // Solid base color prevents any white background flash/flicker during transitions
            Color.primaryBlue
                .ignoresSafeArea()

            if showCelebration {
                SummaryCelebrationView(
                    cards: cards,
                    origin: originName,
                    destination: destinationName,
                    tripTitle: tripTitle,
                    badgeImageUrl: badge?.badgeImageUrl,
                    journey: journey,
                    path: result.path,
                    onShare: {
                        SummaryStoryShareManager.shared.share(
                            cards: cards,
                            origin: originName,
                            destination: destinationName,
                            tripTitle: tripTitle,
                            calorieMessage: calorieMessage,
                            badgeImageUrl: badge?.badgeImageUrl,
                            journey: journey,
                            path: result.path
                        )
                    },
                    onNext: onDismiss
                )
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.96).combined(with: .opacity),
                    removal: .scale(scale: 1.04).combined(with: .opacity)
                ))
            } else {
                SummaryIntroView(
                    cards: cards,
                    locationLabel: destinationName,
                    calorieMessage: calorieMessage,
                    badgeImageUrl: badge?.badgeImageUrl
                )
                .transition(.asymmetric(
                    insertion: .opacity,
                    removal: .scale(scale: 0.96).combined(with: .opacity)
                ))
            }
        }
        .onAppear {
            Task {
                try? await Task.sleep(for: .seconds(2.8))
                withAnimation(.spring(response: 0.55, dampingFraction: 0.85)) {
                    showCelebration = true
                }
            }
        }
    }

    private static func formatIdrAbbreviated(_ amount: Int) -> String {
        guard amount >= 1000 else { return "\(amount)" }
        let thousands = (Double(amount) / 100).rounded() / 10
        let formatted = thousands.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", thousands)
            : String(format: "%.1f", thousands)
        return "\(formatted)k"
    }
}

// Backward-compatibility alias
typealias JourneyCompletionSummaryScreen = SummaryScreen

/// Renders the quest badge artwork cleanly inside a single postage stamp frame with playful tilt.
struct BadgeArtworkStamp: View {
    let badgeImageUrl: String?
    var size: CGFloat = 195
    var tilt: Angle = .degrees(-7.5)

    var body: some View {
        Group {
            if let badgeImageUrl, !badgeImageUrl.isEmpty, let url = Self.resolvedURL(badgeImageUrl) {
                TransiumStampCard(size: size, tilt: .degrees(0), variant: .classic) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        case .empty:
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(Color.white.opacity(0.12))
                                .transiumShimmer(
                                    baseColor: Color.white.opacity(0.1),
                                    highlightColor: Color.white.opacity(0.3)
                                )
                        default:
                            Image(systemName: "rosette")
                                .resizable()
                                .scaledToFit()
                                .padding(18)
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                }
            } else {
                // Standalone badge artwork (SampleBadge is already a complete single postage stamp)
                Image("SampleBadge")
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size * 0.96)
            }
        }
        .rotationEffect(tilt)
        .shadow(color: Color.black.opacity(0.22), radius: 12, x: 0, y: 8)
    }

    private static func resolvedURL(_ raw: String) -> URL? {
        let fullString = raw.hasPrefix("http") ? raw : "\(APIConfiguration.origin.absoluteString)\(raw)"
        return URL(string: fullString)
    }
}

// Backward-compatibility alias
typealias BadgeArtworkImage = BadgeArtworkStamp

#Preview("Summary Screen - Full Flow") {
    let origin = JourneyLocationRef(lat: -8.702105, lng: 115.176189, name: "Jimbaran", stopId: nil)
    let stop = JourneyLocationRef(lat: -8.6975, lng: 115.1800, name: "Sanur Beach Stop", stopId: "stop-1")
    let dest = JourneyLocationRef(lat: -8.67368, lng: 115.26337, name: "Sanur Beach", stopId: nil)

    let mockJourney = JourneyResult(
        origin: LatLng(lat: origin.lat, lng: origin.lng),
        destination: LatLng(lat: dest.lat, lng: dest.lng),
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
            JourneySegment(type: "bus", from: stop, to: dest, distanceMeters: 4000, durationSeconds: 900, routeId: "kib-1", routeRef: "KIB", routeName: "Trans Metro Dewata")
        ],
        steps: []
    )

    let mockResult = JourneyCompleteResult(
        journeyAttempt: JourneyAttempt(
            id: "attempt-1",
            userQuestId: "uq-1",
            questId: "quest-1",
            questName: "Sanur Beach Sunrise Quest",
            questCategory: "Explorer",
            currentStepSequence: 3,
            status: "completed",
            createdAt: Date().addingTimeInterval(-3600),
            startedAt: Date().addingTimeInterval(-3500),
            endedAt: Date()
        ),
        steps: [],
        summary: JourneySummary(
            id: "sum-1",
            journeyAttemptId: "attempt-1",
            stepsTaken: 3600,
            distanceMeters: 5200,
            calorie: 250,
            startPoint: "Jimbaran",
            finishPoint: "Sanur Beach",
            fuelCostSavedIdr: 15000,
            rideHailingMotorcycleSavedIdr: 24000,
            rideHailingCarSavedIdr: 48000
        ),
        path: [
            JourneyPathPoint(id: "p1", journeyAttemptId: "attempt-1", sequence: 0, lat: -8.702105, lng: 115.176189),
            JourneyPathPoint(id: "p2", journeyAttemptId: "attempt-1", sequence: 1, lat: -8.6975, lng: 115.1800),
            JourneyPathPoint(id: "p3", journeyAttemptId: "attempt-1", sequence: 2, lat: -8.67368, lng: 115.26337)
        ],
        xpAwarded: 150,
        badgesAwarded: [
            EarnedBadge(
                id: "eb-1",
                badgeId: "b-1",
                badgeName: "Sanoored",
                badgeCategory: "Explorer",
                badgeType: "Stamp",
                badgeImageUrl: nil,
                earnedAt: Date(),
                questId: "quest-1",
                questName: "Sanur Beach Sunrise Quest"
            )
        ],
        profile: Profile(id: "p-1", userId: "u-1", firstName: "Bali", lastName: "Traveler", level: 2, image: nil, email: "explorer@transium.app")
    )

    SummaryScreen(result: mockResult, journey: mockJourney)
}

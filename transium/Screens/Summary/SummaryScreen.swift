//
//  SummaryScreen.swift
//  transium
//

import SwiftUI

/// Main screen presented when a journey is completed (`POST /private/journey/{id}/complete`).
/// Shows `SummaryIntroView` for 3 seconds, then transitions into `SummaryCelebrationView`.
struct SummaryScreen: View {
    let result: JourneyCompleteResult
    var onDismiss: () -> Void = {}

    @State private var showCelebration = false

    private var summary: JourneySummary? { result.summary }
    private var badge: EarnedBadge? { result.badgesAwarded.first }

    private var cards: [StatCardData] {
        guard let summary else { return [] }
        return [
            StatCardData(
                title: "Distance",
                value: String(Int((summary.distanceMeters / 1000).rounded())),
                unit: "km",
                icon: "distance-icon"
            ),
            StatCardData(
                title: "Travel Cost",
                value: Self.formatIdrAbbreviated(summary.rideHailingMotorcycleSavedIdr ?? 0),
                unit: "Rp",
                icon: "cost-icon"
            ),
            StatCardData(
                title: "Calories",
                value: String(Int(summary.calorie.rounded())),
                unit: nil,
                icon: "calorie-icon"
            ),
            StatCardData(
                title: "Total Steps",
                value: String(summary.stepsTaken),
                unit: nil,
                icon: "steps-icon"
            )
        ]
    }

    private var calorieMessage: String {
        guard let summary else { return "This trip burned some calories. Nice work! 🥵" }
        let calories = Int(summary.calorie.rounded())
        let jumpingJacks = max(1, Int((summary.calorie * 4).rounded()))
        return "This trip burned \(calories) calories. That's like doing \(jumpingJacks) jumping jacks 🥵"
    }

    private var tripTitle: String {
        badge?.badgeName ?? result.journeyAttempt.questName ?? "Quest Complete"
    }

    var body: some View {
        ZStack {
            if showCelebration {
                SummaryCelebrationView(
                    cards: cards,
                    origin: summary?.startPoint ?? "Origin",
                    destination: summary?.finishPoint ?? "Destination",
                    tripTitle: tripTitle,
                    badgeImageUrl: badge?.badgeImageUrl,
                    onShare: {
                        AppToastCenter.shared.showSuccess(title: "Shared", message: "Your trip summary was shared.")
                    },
                    onNext: onDismiss
                )
                .transition(.opacity)
            } else {
                SummaryIntroView(
                    cards: cards,
                    locationLabel: summary?.finishPoint ?? "Destination",
                    calorieMessage: calorieMessage,
                    badgeImageUrl: badge?.badgeImageUrl
                )
                .transition(.opacity)
            }
        }
        .onAppear {
            Task {
                try? await Task.sleep(for: .seconds(3))
                withAnimation(.easeInOut(duration: 0.4)) {
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

/// A quest badge's artwork, loaded from its URL with a graceful fallback to a bundled placeholder.
struct BadgeArtworkImage: View {
    let urlString: String?
    var fallback: String = "SampleBadge"

    var body: some View {
        if let urlString, let url = Self.resolvedURL(urlString) {
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
                    Image(fallback).resizable().scaledToFill()
                }
            }
        } else {
            Image(fallback).resizable().scaledToFill()
        }
    }

    private static func resolvedURL(_ raw: String) -> URL? {
        let fullString = raw.hasPrefix("http") ? raw : "\(APIConfiguration.origin.absoluteString)\(raw)"
        return URL(string: fullString)
    }
}

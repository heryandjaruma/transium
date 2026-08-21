//
//  JourneyCompletionSummaryScreen.swift
//  transium
//

import SwiftUI

/// Presented the instant POST /private/journey/{id}/complete succeeds — `Summary` for 3
/// seconds, then an internal cross-fade into `SummaryCelebrationScreen`. Both were built as
/// static mockups (StatCardData cards, hardcoded badge/location copy); this is what actually
/// feeds them real data from the finished `JourneyCompleteResult`.
struct JourneyCompletionSummaryScreen: View {
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
                SummaryCelebrationScreen(
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
                Summary(
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

/// A quest badge's artwork, loaded from its (possibly relative) URL with a graceful fallback
/// to a bundled placeholder while loading or on failure — same idiom already used for quest
/// ticket stamps in TransiumTicketComponents.swift.
struct BadgeArtworkImage: View {
    let urlString: String?
    var fallback: String = "SampleBadge"

    var body: some View {
        if let urlString, let url = Self.resolvedURL(urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFit()
                default:
                    Image(fallback).resizable().scaledToFit()
                }
            }
        } else {
            Image(fallback).resizable().scaledToFit()
        }
    }

    private static func resolvedURL(_ raw: String) -> URL? {
        let fullString = raw.hasPrefix("http") ? raw : "\(APIConfiguration.origin.absoluteString)\(raw)"
        return URL(string: fullString)
    }
}

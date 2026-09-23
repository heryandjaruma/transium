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
    var areaName: String? = nil
    var badgeImageUrl: String? = nil
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

    private func isStepActionText(_ text: String?) -> Bool {
        guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return true }
        let lower = text.lowercased()
        if lower.contains("selfie") || lower.contains("picture") || lower.contains("photo") || lower.contains("take a") || lower.contains("capture") || lower.contains("checkin") || lower.contains("check in") || lower.contains("snap") || lower.contains("mission") || lower.contains("!") {
            return true
        }
        if result.steps.contains(where: { $0.name.caseInsensitiveCompare(text) == .orderedSame || $0.description.caseInsensitiveCompare(text) == .orderedSame }) {
            return true
        }
        return false
    }

    private func isGenericLocationName(_ text: String?) -> Bool {
        guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return true }
        let lower = text.lowercased()
        if lower == "destination" ||
           lower == "walk to destination" ||
           lower == "current location" ||
           lower == "start" ||
           lower == "origin" ||
           lower == "finish" ||
           lower == "culture" ||
           lower == "explore" ||
           lower == "nature" ||
           lower == "food" ||
           lower == "null" ||
           lower == "undefined" {
            return true
        }
        return isStepActionText(text)
    }

    private var originName: String {
        // 1. First bus departure stop in the transit route (e.g. "Titi Banda")
        if let firstBusStop = journey?.segments.first(where: { $0.type == "bus" })?.from?.name,
           !isGenericLocationName(firstBusStop) {
            return firstBusStop
        }
        // 2. First non-generic departure point from journey segments
        if let firstFrom = journey?.segments.first?.from?.name, !isGenericLocationName(firstFrom) {
            return firstFrom
        }
        // 3. Start point from backend summary
        if let start = summary?.startPoint, !isGenericLocationName(start) {
            return start
        }
        return "Origin"
    }

    private var destinationName: String {
        // 1. Last bus arrival stop in the transit route (e.g. "Sentral Parkir Monkey Forest")
        if let lastBusStop = journey?.segments.reversed().first(where: { $0.type == "bus" })?.to?.name,
           !isGenericLocationName(lastBusStop) {
            return lastBusStop
        }
        // 2. Journey destination / arrival stop if not generic
        if let journeyDest = journey?.destinationName, !isGenericLocationName(journeyDest) {
            return journeyDest
        }
        // 3. Last location in journey segments
        if let lastLocation = journey?.segments.reversed().compactMap(\.to?.name).first(where: { !isGenericLocationName($0) }) {
            return lastLocation
        }
        // 4. Finish point from backend summary
        if let finish = summary?.finishPoint, !isGenericLocationName(finish) {
            return finish
        }
        // 5. Quest Name if meaningful
        if let questName = result.journeyAttempt.questName, !isGenericLocationName(questName) {
            return questName
        }
        // 6. Area Name as fallback
        if let areaName, !isGenericLocationName(areaName) {
            return areaName
        }
        return "Sanur Beach"
    }

    private var calorieMessage: String {
        "If more people take public transportation, there’s higher chance we can get even better infrastructures and more frequent services!"
    }

    private var tripTitle: String {
        if let questName = result.journeyAttempt.questName, !questName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !isStepActionText(questName) {
            return questName
        }
        if let badgeQuestName = badge?.questName, !badgeQuestName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !isStepActionText(badgeQuestName) {
            return badgeQuestName
        }
        if let journeyDest = journey?.destinationName, !isStepActionText(journeyDest) {
            return journeyDest
        }
        return badge?.badgeName ?? "Quest Complete"
    }

    @State private var fetchedBadgeImageUrl: String? = nil

    private var resolvedBadgeImageUrl: String? {
        if let apiBadgeUrl = result.badgesAwarded.first?.badgeImageUrl, !apiBadgeUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return apiBadgeUrl
        }
        if let passedUrl = badgeImageUrl, !passedUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return passedUrl
        }
        if let badgeUrl = badge?.badgeImageUrl, !badgeUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return badgeUrl
        }
        if let fetchedUrl = fetchedBadgeImageUrl, !fetchedUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return fetchedUrl
        }
        return nil
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
                    badgeImageUrl: resolvedBadgeImageUrl,
                    journey: journey,
                    path: result.path,
                    onShare: {
                        SummaryStoryShareManager.shared.share(
                            cards: cards,
                            origin: originName,
                            destination: destinationName,
                            tripTitle: tripTitle,
                            calorieMessage: calorieMessage,
                            badgeImageUrl: resolvedBadgeImageUrl,
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
                    badgeImageUrl: resolvedBadgeImageUrl
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
        .task {
            if resolvedBadgeImageUrl == nil {
                if let questId = result.journeyAttempt.questId, !questId.isEmpty {
                    if let badges = try? await QuestService.shared.listQuestBadges(id: questId),
                       let firstUrl = badges.first?.badgeImageUrl, !firstUrl.isEmpty {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            fetchedBadgeImageUrl = firstUrl
                        }
                    }
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

/// In-memory cache to guarantee instant, zero-flicker loading across view transitions
@MainActor
final class TransiumImageCache {
    static let shared = TransiumImageCache()
    private let cache = NSCache<NSURL, UIImage>()

    private init() {
        cache.countLimit = 100
        cache.totalCostLimit = 50 * 1024 * 1024
    }

    func image(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    func setImage(_ image: UIImage, for url: URL) {
        cache.setObject(image, forKey: url as NSURL)
    }
}

/// Renders the quest badge artwork cleanly inside a single postage stamp frame with playful tilt and zero-flicker caching.
struct BadgeArtworkStamp: View {
    let badgeImageUrl: String?
    var size: CGFloat = 195
    var tilt: Angle = .degrees(-7.5)

    @State private var loadedImage: UIImage? = nil
    @State private var isLoading: Bool = false

    var body: some View {
        TransiumStampCard(size: size, tilt: .degrees(0), variant: .classic) {
            Group {
                if let loadedImage {
                    Image(uiImage: loadedImage)
                        .resizable()
                        .scaledToFill()
                } else if let localAsset = badgeImageUrl, !localAsset.isEmpty, let assetImg = UIImage(named: localAsset) {
                    Image(uiImage: assetImg)
                        .resizable()
                        .scaledToFill()
                } else if isLoading {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.white.opacity(0.18))
                        .transiumShimmer(
                            baseColor: Color.white.opacity(0.12),
                            highlightColor: Color.white.opacity(0.38)
                        )
                } else {
                    ZStack {
                        Color(red: 0.95, green: 0.60, blue: 0.20).opacity(0.15)
                        Image(systemName: "rosette")
                            .resizable()
                            .scaledToFit()
                            .padding(28)
                            .foregroundColor(TransiumColor.primaryBlue.opacity(0.85))
                    }
                }
            }
        }
        .rotationEffect(tilt)
        .shadow(color: Color.black.opacity(0.22), radius: 12, x: 0, y: 8)
        .task(id: badgeImageUrl) {
            await loadImage()
        }
    }

    private func loadImage() async {
        guard let raw = badgeImageUrl?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            loadedImage = nil
            return
        }

        if let local = UIImage(named: raw) {
            loadedImage = local
            return
        }

        guard let url = APIConfiguration.resolveURL(raw) else {
            loadedImage = nil
            return
        }

        if let cached = TransiumImageCache.shared.image(for: url) {
            loadedImage = cached
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            var request = URLRequest(url: url)
            request.cachePolicy = .returnCacheDataElseLoad
            request.timeoutInterval = 10
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode == 200, let downloaded = UIImage(data: data) {
                TransiumImageCache.shared.setImage(downloaded, for: url)
                withAnimation(.easeInOut(duration: 0.2)) {
                    loadedImage = downloaded
                }
            }
        } catch {
            // Keep fallback
        }
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
                badgeImageUrl: "https://transium-api.heryandjaruma.workers.dev/media/system/badge/ae2cf1b2-e536-416b-9db7-d7e76c6f3443/0e1721d8-0858-462e-af84-f78d99a43d5a.png",
                earnedAt: Date(),
                questId: "quest-1",
                questName: "Sanur Beach Sunrise Quest"
            )
        ],
        profile: Profile(id: "p-1", userId: "u-1", firstName: "Bali", lastName: "Traveler", level: 2, image: nil, email: "explorer@transium.app")
    )

    SummaryScreen(result: mockResult, journey: mockJourney)
}

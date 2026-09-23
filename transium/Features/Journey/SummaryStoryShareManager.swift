//
//  SummaryStoryShareManager.swift
//  transium
//

import CoreLocation
import MapKit
import SwiftUI
import UIKit

@MainActor
final class SummaryStoryShareManager {
    static let shared = SummaryStoryShareManager()

    private init() {}

    /// Shares the trip summary story card to Instagram Stories or the native iOS share sheet.
    func share(
        cards: [StatCardData],
        origin: String,
        destination: String,
        tripTitle: String,
        calorieMessage: String,
        badgeImageUrl: String?,
        journey: JourneyResult?,
        path: [JourneyPathPoint]
    ) {
        Task {
            // 1. Preload badge image synchronously from memory cache or network
            let preloadedBadge = await loadBadgeImage(rawUrl: badgeImageUrl)

            // 2. Fetch the high-fidelity offline MapLibre PMTiles map snapshot
            let preloadedMap = SummaryMapSnapshotCache.shared.latestSnapshot

            // 3. Build story card view with pre-rendered synchronous image assets
            let storyView = SummaryStoryCardView(
                cards: cards,
                origin: origin,
                destination: destination,
                tripTitle: tripTitle,
                calorieMessage: calorieMessage,
                badgeImage: preloadedBadge,
                mapImage: preloadedMap,
                badgeImageUrl: badgeImageUrl,
                journey: journey,
                path: path
            )

            guard let image = renderStoryImage(view: storyView) else {
                AppToastCenter.shared.showError(title: "Share Failed", message: "Could not generate story image.")
                return
            }

            let instagramURL = URL(string: "instagram-stories://share?source_application=si.transporta.transium-app")!

            if UIApplication.shared.canOpenURL(instagramURL) {
                shareToInstagramStories(image: image, fallbackURL: instagramURL)
            } else {
                presentShareSheet(with: image)
            }
        }
    }

    /// Preloads the badge image into a concrete UIImage so off-screen snapshotting captures it immediately.
    private func loadBadgeImage(rawUrl: String?) async -> UIImage? {
        guard let raw = rawUrl?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }

        if let local = UIImage(named: raw) {
            return local
        }

        guard let url = APIConfiguration.resolveURL(raw) else {
            return nil
        }

        if let cached = TransiumImageCache.shared.image(for: url) {
            return cached
        }

        do {
            var request = URLRequest(url: url)
            request.cachePolicy = .returnCacheDataElseLoad
            request.timeoutInterval = 8
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode == 200, let downloaded = UIImage(data: data) {
                TransiumImageCache.shared.setImage(downloaded, for: url)
                return downloaded
            }
        } catch {
            // Return nil to use graceful fallback
        }
        return nil
    }

    /// Renders a SwiftUI view hierarchy into a high-resolution 9:16 UIImage.
    private func renderStoryImage<V: View>(view: V) -> UIImage? {
        let targetSize = CGSize(width: 414, height: 896)
        let hostingController = UIHostingController(rootView: view)
        hostingController.view.bounds = CGRect(origin: .zero, size: targetSize)
        hostingController.view.backgroundColor = .clear
        hostingController.view.layoutIfNeeded()

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            hostingController.view.drawHierarchy(in: CGRect(origin: .zero, size: targetSize), afterScreenUpdates: true)
        }
    }

    /// Shares directly to Instagram Stories via Meta's Pasteboard API.
    private func shareToInstagramStories(image: UIImage, fallbackURL: URL) {
        guard let imageData = image.pngData() else {
            presentShareSheet(with: image)
            return
        }

        let pasteboardItems: [String: Any] = [
            "com.instagram.sharedSticker.backgroundImage": imageData,
            "com.instagram.sharedSticker.backgroundTopColor": "#246BFD",
            "com.instagram.sharedSticker.backgroundBottomColor": "#0F4BC2"
        ]

        let pasteboardOptions = [UIPasteboard.OptionsKey.expirationDate: Date().addingTimeInterval(300)]
        UIPasteboard.general.setItems([pasteboardItems], options: pasteboardOptions)

        UIApplication.shared.open(fallbackURL, options: [:]) { success in
            if !success {
                self.presentShareSheet(with: image)
            }
        }
    }

    /// Presents the native iOS system share sheet.
    func presentShareSheet(with image: UIImage) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            return
        }

        var topController = rootVC
        while let presented = topController.presentedViewController {
            topController = presented
        }

        let activityVC = UIActivityViewController(
            activityItems: [
                image,
                "Just finished my sustainable trip on Transium! 🚌✨"
            ],
            applicationActivities: nil
        )

        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = topController.view
            popover.sourceRect = CGRect(x: topController.view.bounds.midX, y: topController.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }

        topController.present(activityVC, animated: true)
    }
}


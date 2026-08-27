//
//  SummaryStoryShareManager.swift
//  transium
//

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
        let storyView = SummaryStoryCardView(
            cards: cards,
            origin: origin,
            destination: destination,
            tripTitle: tripTitle,
            calorieMessage: calorieMessage,
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

    /// Renders a SwiftUI view hierarchy into a high-resolution UIImage.
    private func renderStoryImage<V: View>(view: V) -> UIImage? {
        let hostingController = UIHostingController(rootView: view)
        let targetSize = CGSize(width: 390, height: 844)
        hostingController.view.bounds = CGRect(origin: .zero, size: targetSize)
        hostingController.view.backgroundColor = .clear

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
            "com.instagram.sharedSticker.backgroundTopColor": "#1E88E5",
            "com.instagram.sharedSticker.backgroundBottomColor": "#0D47A1"
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

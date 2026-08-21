//
//  AppDelegate.swift
//  transium
//

import UIKit

/// Bridges UIKit-only APNs callbacks into `PushNotificationManager`.
/// SwiftUI's App lifecycle has no equivalent for these two delegate methods.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in
            await PushNotificationManager.shared.handleDeviceToken(deviceToken)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Task { @MainActor in
            PushNotificationManager.shared.handleRegistrationFailure(error)
        }
    }
}

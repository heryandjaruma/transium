//
//  PushNotificationManager.swift
//  transium
//

import Foundation
import UIKit
import UserNotifications

/// Requests push permission, registers with APNs, and syncs the resulting
/// device token with the backend's `/private/device` endpoint.
@MainActor
public final class PushNotificationManager {
    public static let shared = PushNotificationManager()

    private let deviceService: DeviceServiceProtocol

    /// Holds a token received before the user is signed in, so it can be
    /// synced once `retryPendingRegistration()` is called after sign-in.
    private var pendingToken: String?

    private var currentEnvironment: DeviceEnvironment {
        #if DEBUG
        .sandbox
        #else
        .production
        #endif
    }

    init(deviceService: DeviceServiceProtocol = DeviceService.shared) {
        self.deviceService = deviceService
    }

    /// Prompts for notification permission (no-ops if already decided) and,
    /// if granted, asks iOS to register the device with APNs.
    public func requestAuthorizationAndRegister() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])

            guard granted else { return }

            UIApplication.shared.registerForRemoteNotifications()
        } catch {
            // Permission errors aren't actionable here; the user can retry
            // by revisiting notification settings.
        }
    }

    /// Called from `AppDelegate` once APNs hands back a device token.
    public func handleDeviceToken(_ deviceToken: Data) async {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        await registerWithBackend(token: token)
    }

    /// Called from `AppDelegate` when APNs registration fails.
    public func handleRegistrationFailure(_ error: Error) {
        #if DEBUG
        print("APNs registration failed: \(error.localizedDescription)")
        #endif
    }

    /// Syncs a token that arrived before the user was signed in.
    public func retryPendingRegistration() async {
        guard let token = pendingToken else { return }
        await registerWithBackend(token: token)
    }

    private func registerWithBackend(token: String) async {
        guard SessionTokenStore.read() != nil else {
            pendingToken = token
            return
        }

        do {
            _ = try await deviceService.registerDevice(token: token, environment: currentEnvironment)
            pendingToken = nil
        } catch {
            // Keep the token around so the next retry (e.g. after sign-in
            // or app relaunch) can attempt the sync again.
            pendingToken = token
        }
    }
}

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

    /// The token last confirmed as registered with the backend, kept so
    /// sign-out can unregister this specific device.
    private var registeredToken: String?

    private var currentEnvironment: DeviceEnvironment {
        #if DEBUG
        .sandbox
        #else
        .production
        #endif
    }

    init(deviceService: DeviceServiceProtocol? = nil) {
        self.deviceService = deviceService ?? DeviceService.shared
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

    /// Unregisters this device's token from the backend. Must be called
    /// while the session's access token is still available, i.e. before
    /// `SessionTokenStore.clear()` runs as part of sign-out.
    public func unregisterCurrentDevice() async {
        guard let token = registeredToken else { return }

        // Best-effort: sign-out should proceed locally even if this fails.
        try? await deviceService.unregisterDevice(token: token)
        registeredToken = nil
        pendingToken = nil
    }

    private func registerWithBackend(token: String) async {
        guard SessionTokenStore.read() != nil else {
            pendingToken = token
            return
        }

        do {
            _ = try await deviceService.registerDevice(token: token, environment: currentEnvironment)
            pendingToken = nil
            registeredToken = token
        } catch {
            // Keep the token around so the next retry (e.g. after sign-in
            // or app relaunch) can attempt the sync again.
            pendingToken = token
        }
    }
}

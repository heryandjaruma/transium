//
//  SessionController.swift
//  transium
//

import AuthenticationServices
import Foundation
import Observation

/// Manages the app's current authentication state.
@Observable
final class SessionController {
    enum Phase: Equatable {
        /// Launch state: a stored token may exist but has not been validated yet.
        case restoring
        case signedOut
        case signedIn(BackendProfile)
    }

    private(set) var phase: Phase = .restoring
    private(set) var isBusy = false
    var errorMessage: String?

    private let backend: any AuthBackend

    init(backend: any AuthBackend = BetterAuthBackend()) {
        self.backend = backend
    }

    var profile: BackendProfile? {
        if case let .signedIn(profile) = phase {
            return profile
        }

        return nil
    }

    // Restore and validate an existing session.
    func restore() async {
        guard case .restoring = phase else {
            return
        }

        guard let token = SessionTokenStore.read() else {
            phase = .signedOut
            return
        }

        // Fast optimistic path: If we have a cached profile, restore immediately (0ms launch)
        if let cachedProfile = SessionTokenStore.readProfile() {
            phase = .signedIn(cachedProfile)
            
            // Asynchronously validate / refresh in background
            Task {
                do {
                    let freshProfile = try await backend.fetchPrivateProfile(accessToken: token)
                    SessionTokenStore.saveProfile(freshProfile)
                    self.phase = .signedIn(freshProfile)
                } catch BackendError.unauthorized {
                    SessionTokenStore.clear()
                    self.phase = .signedOut
                } catch {
                    // Transient network failure - keep user signed in offline
                }
            }
            
            Task {
                await syncPushNotifications()
            }
            return
        }

        // Fallback path: Validate session with backend if no cached profile
        do {
            let profile = try await backend.fetchPrivateProfile(accessToken: token)
            SessionTokenStore.saveProfile(profile)
            phase = .signedIn(profile)
            Task { await syncPushNotifications() }
        } catch BackendError.unauthorized {
            SessionTokenStore.clear()
            phase = .signedOut
        } catch {
            // Keep the token if validation only failed because of temporary network error
            phase = .signedOut
        }
    }

    // Exchange Apple's credential for a Better Auth session.
    func signIn(with credential: AppleSignInCredential, localStore: AuthStore) async {
        guard !isBusy else {
            return
        }

        isBusy = true
        errorMessage = nil

        defer { isBusy = false }

        do {
            let session = try await backend.verifyAppleSignIn(credential)

            SessionTokenStore.save(session.accessToken, profile: session.profile)
            _ = try localStore.upsertLocalProfile(
                from: credential,
                remoteUserID: session.userID
            )

            phase = .signedIn(session.profile)
            
            Task {
                await syncPushNotifications()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // Request notification permission and sync any pending or fresh device token.
    private func syncPushNotifications() async {
        await PushNotificationManager.shared.retryPendingRegistration()
        await PushNotificationManager.shared.requestAuthorizationAndRegister()
    }

    // MARK: Important Flow - DEV_MODE Preview Sign In

    // TODO: Remove before production. This keeps previews/simulator UI work
    // unblocked when Apple Sign In cannot present or complete.
    func signInForDevelopmentPreview() {
        guard AppEnvironment.DEV_MODE else {
            return
        }

        let profile = BackendProfile(
            id: "dev-preview-user",
            firstName: "Transium",
            method: AuthMethod.apple.rawValue,
            level: ProfileLevel.standard.rawValue
        )

        errorMessage = nil
        phase = .signedIn(profile)
    }

    // End both the server and local session.
    func signOut() async {
        guard !isBusy else {
            return
        }

        isBusy = true
        errorMessage = nil

        defer { isBusy = false }

        if let token = SessionTokenStore.read() {
            // Local sign-out should still succeed if the server request fails.
            await PushNotificationManager.shared.unregisterCurrentDevice()
            try? await backend.signOut(accessToken: token)
        }

        SessionTokenStore.clear()
        phase = .signedOut
    }

    // Sign out if Apple revokes this app's credential.
    func handleAppleCredentialRevoked() async {
        guard case .signedIn = phase else {
            return
        }

        await signOut()
    }
}

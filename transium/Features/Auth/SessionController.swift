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

        do {
            phase = .signedIn(try await backend.fetchPrivateProfile(accessToken: token))
        } catch BackendError.unauthorized {
            // Remove tokens that the server no longer accepts.
            SessionTokenStore.clear()
            phase = .signedOut
        } catch {
            // Keep the token if validation only failed because of a temporary error.
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

            SessionTokenStore.save(session.accessToken)
            try localStore.upsertLocalProfile(
                from: credential,
                remoteUserID: session.userID
            )

            phase = .signedIn(session.profile)
        } catch {
            errorMessage = error.localizedDescription
        }
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

//
//  AuthScreen.swift
//  transium
//

import AuthenticationServices
import SwiftData
import SwiftUI
import UIKit

struct AuthScreen: View {
    @Environment(\.modelContext) private var modelContext
    @State private var appleSignInService = AppleSignInService()
    @State private var signInErrorMessage: String?
    @State private var backendIDToast: BackendIDToast?

    var body: some View {
        GeometryReader { proxy in
            let metrics = AuthScreenMetrics(size: proxy.size)

            ZStack(alignment: .bottom) {
                Color.authBlue
                    .ignoresSafeArea()

                heroArt(metrics)

                AuthBottomPanel(
                    metrics: metrics,
                    signInErrorMessage: signInErrorMessage,
                    backendIDToast: backendIDToast,
                    onRequest: configureAppleSignIn,
                    onCompletion: handleAppleSignIn,
                    onCopyBackendID: copyBackendID
                )
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .task {
            await refreshStoredCredentialState(showErrors: false)
        }
        .onReceive(NotificationCenter.default.publisher(for: ASAuthorizationAppleIDProvider.credentialRevokedNotification)) { _ in
            Task {
                await refreshStoredCredentialState(showErrors: false)
            }
        }
        .preferredColorScheme(.light)
    }

    // MARK: Important Flow - Hero Placement

    private func heroArt(_ metrics: AuthScreenMetrics) -> some View {
        Image(TransiumAsset.Illustration.authHero)
            .resizable()
            .scaledToFit()
            .frame(width: metrics.heroWidth)
            .offset(y: metrics.heroBottomOverlap)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, metrics.panelHeight)
            .accessibilityHidden(true)
    }

    // MARK: Important Flow - Configure Native Apple Sign-In

    private func configureAppleSignIn(_ request: ASAuthorizationAppleIDRequest) {
        do {
            signInErrorMessage = nil
            try appleSignInService.configure(request)
        } catch {
            signInErrorMessage = error.localizedDescription
        }
    }

    // MARK: Important Flow - Store Verified Local Profile Seed

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        defer { appleSignInService.reset() }

        do {
            let authorization = try result.get()
            let credential = try appleSignInService.credential(from: authorization)
            _ = try AuthStore(modelContext: modelContext).upsertLocalProfile(from: credential)
            showBackendIDToast(credential.appleUserIdentifier)
            signInErrorMessage = nil
        } catch {
            signInErrorMessage = error.localizedDescription
        }
    }

    // MARK: Important Flow - Surface Backend User Identifier

    private func showBackendIDToast(_ appleUserIdentifier: String) {
        withAnimation(.snappy(duration: 0.28)) {
            backendIDToast = BackendIDToast(appleUserIdentifier: appleUserIdentifier)
        }

        Task {
            try? await Task.sleep(for: .seconds(8))

            await MainActor.run {
                if backendIDToast?.appleUserIdentifier == appleUserIdentifier {
                    withAnimation(.snappy(duration: 0.28)) {
                        backendIDToast = nil
                    }
                }
            }
        }
    }

    private func copyBackendID() {
        guard let backendIDToast else {
            return
        }

        UIPasteboard.general.string = backendIDToast.appleUserIdentifier
    }

    // MARK: Important Flow - Guard Stored Apple Sessions

    private func refreshStoredCredentialState(showErrors: Bool) async {
        do {
            try await AuthStore(modelContext: modelContext)
                .refreshStoredAppleCredentialState(using: appleSignInService)

            if signInErrorMessage != nil {
                signInErrorMessage = nil
            }
        } catch AuthError.credentialRevoked, AuthError.credentialNotFound, AuthError.credentialTransferred {
            signInErrorMessage = nil
        } catch {
            if showErrors {
                signInErrorMessage = error.localizedDescription
            }
        }
    }
}

private struct AuthBottomPanel: View {
    let metrics: AuthScreenMetrics
    let signInErrorMessage: String?
    let backendIDToast: BackendIDToast?
    let onRequest: (ASAuthorizationAppleIDRequest) -> Void
    let onCompletion: (Result<ASAuthorization, Error>) -> Void
    let onCopyBackendID: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.bottom, metrics.headerBottomSpacing)

            SignInWithAppleButton(.continue, onRequest: onRequest, onCompletion: onCompletion)
                .signInWithAppleButtonStyle(.black)
                .frame(maxWidth: metrics.buttonMaxWidth)
                .frame(height: metrics.buttonHeight)
                .clipShape(.capsule)
                .accessibilityLabel("Continue with Apple")
                .accessibilityHint("Signs in to Transium using your Apple Account.")
                .padding(.bottom, metrics.buttonBottomSpacing)

            if let signInErrorMessage {
                Text(signInErrorMessage)
                    .font(TransiumFont.body(13))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .accessibilityLabel("Sign in error: \(signInErrorMessage)")
                    .padding(.bottom, metrics.errorBottomSpacing)
            }

            Text(termsText)
                .font(TransiumFont.body(metrics.termsFontSize))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: metrics.termsMaxWidth)
                .accessibilityLabel("Signing up to a Transium account means you agree to the Privacy Policy and Terms of Service.")
        }
        .frame(maxWidth: metrics.contentMaxWidth)
        .padding(.top, metrics.panelTopPadding)
        .padding(.horizontal, metrics.panelHorizontalPadding)
        .frame(width: metrics.panelWidth, height: metrics.panelHeight, alignment: .top)
        .background {
            VStack(spacing: 0) {
                UnevenRoundedRectangle(
                    topLeadingRadius: metrics.panelCornerRadius,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: metrics.panelCornerRadius,
                    style: .continuous
                )
                .fill(Color(.systemBackground))
                .frame(width: metrics.panelWidth, height: metrics.panelHeight)

                Color(.systemBackground)
                    .frame(width: metrics.panelWidth, height: metrics.bottomSafeAreaFillHeight)
                    .ignoresSafeArea(edges: .bottom)
            }
        }
        .overlay(alignment: .top) {
            if let backendIDToast {
                BackendIDToastView(toast: backendIDToast, onCopy: onCopyBackendID)
                    .padding(.horizontal, metrics.panelHorizontalPadding)
                    .padding(.top, metrics.toastTopPadding)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text("Welcome!")
                .font(TransiumFont.display(metrics.titleFontSize))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.82)
                .lineLimit(1)

            Text("Sign in to Start Your Adventure!")
                .font(TransiumFont.body(metrics.subtitleFontSize))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.82)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
    }

    private var termsText: AttributedString {
        var text = AttributedString("Signing up to a Transium account means you agree to the Privacy Policy and Terms of Service")

        if let range = text.range(of: "Privacy Policy") {
            text[range].foregroundColor = .authLinkBlue
            text[range].underlineStyle = .single
            text[range].link = URL(string: "https://transium.app/privacy")
        }

        if let range = text.range(of: "Terms of Service") {
            text[range].foregroundColor = .authLinkBlue
            text[range].underlineStyle = .single
            text[range].link = URL(string: "https://transium.app/terms")
        }

        return text
    }
}

private struct BackendIDToast: Identifiable, Equatable {
    let id = UUID()
    let appleUserIdentifier: String
}

private struct BackendIDToastView: View {
    let toast: BackendIDToast
    let onCopy: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Apple backend ID")
                    .font(TransiumFont.body(12, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text(toast.appleUserIdentifier)
                    .font(.caption.monospaced())
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Button("Copy", action: onCopy)
                .font(TransiumFont.body(12, weight: .semibold))
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: .rect(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Apple backend ID \(toast.appleUserIdentifier). Copy button.")
    }
}

private struct AuthScreenMetrics {
    let size: CGSize

    var panelHeight: CGFloat {
        max(282, min(308, size.height * 0.325))
    }

    var bottomSafeAreaFillHeight: CGFloat {
        80
    }

    var panelWidth: CGFloat {
        size.width
    }

    var panelCornerRadius: CGFloat {
        min(54, size.width * 0.126)
    }

    var panelHorizontalPadding: CGFloat {
        max(34, size.width * 0.085)
    }

    var panelTopPadding: CGFloat {
        max(14, panelHeight * 0.052)
    }

    var headerBottomSpacing: CGFloat {
        max(18, panelHeight * 0.062)
    }

    var buttonBottomSpacing: CGFloat {
        max(20, panelHeight * 0.07)
    }

    var errorBottomSpacing: CGFloat {
        max(10, panelHeight * 0.034)
    }

    var toastTopPadding: CGFloat {
        max(14, panelTopPadding * 0.3)
    }

    var buttonHeight: CGFloat {
        max(54, min(60, panelHeight * 0.18))
    }

    var contentMaxWidth: CGFloat {
        max(260, panelWidth - (panelHorizontalPadding * 2))
    }

    var termsMaxWidth: CGFloat {
        max(320, panelWidth - 44)
    }

    var buttonMaxWidth: CGFloat {
        min(contentMaxWidth, 350)
    }

    var heroWidth: CGFloat {
        max(size.width * 2.22, min(1_475, size.height * 1.2))
    }

    var heroBottomOverlap: CGFloat {
        panelHeight * 0.28
    }

    var titleFontSize: CGFloat {
        max(47, min(57, size.width * 0.136))
    }

    var subtitleFontSize: CGFloat {
        max(20, min(24, size.width * 0.054))
    }

    var termsFontSize: CGFloat {
        max(13, min(15, size.width * 0.035))
    }
}

private extension Color {
    static let authBlue = TransiumColor.authBlue
    static let authLinkBlue = TransiumColor.linkBlue
}

#Preview {
    AuthScreen()
        .modelContainer(for: transiumSchema.models, inMemory: true)
}

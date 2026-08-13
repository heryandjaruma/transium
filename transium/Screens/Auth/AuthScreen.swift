//
//  AuthScreen.swift
//  transium
//
//  Created by Salman Alfarisi on 12/08/26.
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

    let onBackToOnboarding: (() -> Void)?

    init(onBackToOnboarding: (() -> Void)? = nil) {
        self.onBackToOnboarding = onBackToOnboarding
    }

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

                if let onBackToOnboarding {
                    VStack {
                        HStack {
                            TransiumIconButton(
                                systemName: "arrow.left",
                                accessibilityLabel: "Back to onboarding",
                                action: onBackToOnboarding
                            )

                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)

                        Spacer()
                    }
                }
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
            .scaleEffect(metrics.heroScale, anchor: .bottom)
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

            AuthAssuranceLine()
                .padding(.bottom, metrics.trustPillBottomSpacing)

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
                .padding(.bottom, metrics.panelBottomPadding)
        }
        .frame(width: metrics.panelWidth)
        .padding(.top, metrics.panelTopPadding)
        .padding(.horizontal, metrics.panelHorizontalPadding)
        .frame(width: metrics.panelWidth, height: metrics.panelHeight, alignment: .top)
        .background(alignment: .top) {
            AuthPanelBackground(metrics: metrics)
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
        VStack(spacing: metrics.headerInnerSpacing) {
            Text("Welcome!")
                .font(TransiumFont.display(metrics.titleFontSize))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.72)
                .lineLimit(1)

            Text("Sign in to Start Your Adventure!")
                .font(TransiumFont.body(metrics.subtitleFontSize))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.72)
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

private struct AuthAssuranceLine: View {
    var body: some View {
        HStack(spacing: 8) {
            softRule

            HStack(spacing: 6) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.authInk.opacity(0.42))

                Text("Private, password-free sign in")
                    .font(TransiumFont.body(10, weight: .medium))
                    .foregroundStyle(Color.authInk.opacity(0.52))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Private, password-free sign in")

            softRule
        }
        .frame(maxWidth: .infinity)
    }

    private var softRule: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        .clear,
                        Color.authInk.opacity(0.11),
                        .clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: 54)
            .frame(height: 1)
    }
}

private struct AuthPanelBackground: View {
    let metrics: AuthScreenMetrics

    var body: some View {
        VStack(spacing: 0) {
            panelShape
                .fill(panelFill)
                .overlay(alignment: .top) {
                    panelTopGlow
                        .clipShape(panelShape)
                }
                .overlay(alignment: .top) {
                    Capsule()
                        .fill(Color.authInk.opacity(0.08))
                        .frame(width: 42, height: 4)
                        .padding(.top, 12)
                }
                .overlay {
                    panelShape
                        .stroke(.white.opacity(0.9), lineWidth: 1)
                }
                .frame(width: metrics.panelWidth, height: metrics.panelHeight)
                .shadow(color: .authInk.opacity(0.08), radius: 24, y: -8)

            Color.authPanelBase
                .frame(width: metrics.panelWidth, height: metrics.bottomSafeAreaFillHeight)
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private var panelShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: metrics.panelCornerRadius,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: 0,
            topTrailingRadius: metrics.panelCornerRadius,
            style: .continuous
        )
    }

    private var panelFill: LinearGradient {
        LinearGradient(
            colors: [
                .white,
                .authPanelBase,
                .white
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var panelTopGlow: some View {
        HStack(spacing: 0) {
            Circle()
                .fill(Color.authGold.opacity(0.18))
                .frame(width: 170, height: 170)
                .blur(radius: 36)
                .offset(x: -58, y: -94)

            Spacer()

            Circle()
                .fill(Color.authBlue.opacity(0.08))
                .frame(width: 150, height: 150)
                .blur(radius: 34)
                .offset(x: 48, y: -82)
        }
        .frame(width: metrics.panelWidth, height: 110)
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
        max(334, min(362, size.height * 0.388))
    }

    var bottomSafeAreaFillHeight: CGFloat {
        max(72, size.height * 0.08)
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
        max(26, panelHeight * 0.12)
    }

    var panelBottomPadding: CGFloat {
        max(8, panelHeight * 0.026)
    }

    var headerInnerSpacing: CGFloat {
        max(4, panelHeight * 0.012)
    }

    var headerBottomSpacing: CGFloat {
        max(18, panelHeight * 0.052)
    }

    var trustPillBottomSpacing: CGFloat {
        max(24, panelHeight * 0.07)
    }

    var buttonBottomSpacing: CGFloat {
        max(30, panelHeight * 0.088)
    }

    var errorBottomSpacing: CGFloat {
        max(10, panelHeight * 0.034)
    }

    var toastTopPadding: CGFloat {
        max(14, panelTopPadding * 0.3)
    }

    var buttonHeight: CGFloat {
        max(58, min(62, panelHeight * 0.18))
    }

    var contentMaxWidth: CGFloat {
        max(260, panelWidth - (panelHorizontalPadding * 2))
    }

    var termsMaxWidth: CGFloat {
        max(340, panelWidth - 64)
    }

    var buttonMaxWidth: CGFloat {
        min(contentMaxWidth, 350)
    }

    var heroWidth: CGFloat {
        max(size.width * 2.22, min(1_475, size.height * 1.2))
    }

    var heroScale: CGFloat {
        1.2
    }

    var heroBottomOverlap: CGFloat {
        panelHeight * 0.42
    }

    var titleFontSize: CGFloat {
        max(47, min(57, size.width * 0.136))
    }

    var subtitleFontSize: CGFloat {
        max(17, min(20, size.width * 0.048))
    }

    var termsFontSize: CGFloat {
        max(12, min(13, size.width * 0.031))
    }
}

private extension Color {
    static let authBlue = TransiumColor.authBlue
    static let authLinkBlue = TransiumColor.linkBlue
    static let authGold = Color(red: 1.0, green: 0.66, blue: 0.16)
    static let authInk = Color(red: 0.07, green: 0.07, blue: 0.1)
    static let authPanelBase = Color(red: 1.0, green: 0.995, blue: 0.975)
}

#Preview {
    AuthScreen()
        .modelContainer(for: transiumSchema.models, inMemory: true)
}

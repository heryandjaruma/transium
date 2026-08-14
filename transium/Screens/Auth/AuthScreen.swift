//
//  AuthScreen.swift
//  transium
//
//  Created by Salman Alfarisi on 12/08/26.
//

import AuthenticationServices
import SwiftData
import SwiftUI

struct AuthScreen: View {
    @Environment(SessionController.self) private var session
    @Environment(\.modelContext) private var modelContext
    @State private var appleSignInService = AppleSignInService()
    @State private var signInErrorMessage: String?

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
                    signInErrorMessage: signInErrorMessage ?? session.errorMessage,
                    isVerifying: session.isBusy,
                    onRequest: configureAppleSignIn,
                    onCompletion: handleAppleSignIn
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

    // Prepare the Apple sign-in request.
    private func configureAppleSignIn(_ request: ASAuthorizationAppleIDRequest) {
        do {
            signInErrorMessage = nil
            try appleSignInService.configure(request)
        } catch {
            signInErrorMessage = error.localizedDescription
        }
    }

    // Send Apple's credential to the backend to create a session.
    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        defer { appleSignInService.reset() }

        do {
            let authorization = try result.get()
            let credential = try appleSignInService.credential(from: authorization)

            signInErrorMessage = nil

            Task {
                await session.signIn(
                    with: credential,
                    localStore: AuthStore(modelContext: modelContext)
                )
            }
        } catch let error as ASAuthorizationError where error.code == .canceled {
            // Closing the Apple sign-in sheet is not an error.
            signInErrorMessage = nil
        } catch {
            signInErrorMessage = error.localizedDescription
        }
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
    let isVerifying: Bool
    let onRequest: (ASAuthorizationAppleIDRequest) -> Void
    let onCompletion: (Result<ASAuthorization, Error>) -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.bottom, metrics.headerBottomSpacing)
            
            Spacer()
                .frame(height: 30)

            SignInWithAppleButton(.continue, onRequest: onRequest, onCompletion: onCompletion)
                .signInWithAppleButtonStyle(.black)
                .frame(maxWidth: metrics.buttonMaxWidth)
                .frame(height: metrics.buttonHeight)
                .clipShape(.capsule)
                .accessibilityLabel("Continue with Apple")
                .accessibilityHint("Signs in to Transium using your Apple Account.")
                // The server round trip is short but not instant, and a second
                // tap would start a competing sign-in.
                .disabled(isVerifying)
                .opacity(isVerifying ? 0.55 : 1)
                .overlay {
                    if isVerifying {
                        ProgressView()
                            .tint(.white)
                    }
                }
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
        .environment(SessionController())
        .modelContainer(for: transiumSchema.models, inMemory: true)
}

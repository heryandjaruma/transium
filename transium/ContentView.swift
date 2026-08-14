//
//  ContentView.swift
//  transium
//
//  Created by Heryan Djaruma on 10/08/26.
//

import AuthenticationServices
import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(SessionController.self) private var session
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var onboardingInitialPage = 0
    @StateObject private var toastCenter = AppToastCenter.shared

    var body: some View {
        content
            .task {
                await session.restore()
            }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: ASAuthorizationAppleIDProvider.credentialRevokedNotification
                )
            ) { _ in
                Task { await session.handleAppleCredentialRevoked() }
            }
            .animation(.snappy(duration: 0.28), value: session.phase)
            .appToastOverlay(toastCenter)
    }

    // Decide which screen to show based on onboarding and sign-in state.
    @ViewBuilder
    private var content: some View {
        switch session.phase {
        case .restoring:
            LaunchPlaceholder()

        case .signedIn:
            HomeScreen()

        case .signedOut:
            if hasCompletedOnboarding {
                AuthScreen(onBackToOnboarding: showFinalOnboardingPage)
            } else {
                OnboardingScreen(initialPage: onboardingInitialPage, onComplete: completeOnboarding)
            }
        }
    }

    private func completeOnboarding() {
        onboardingInitialPage = 0

        withAnimation(.smooth(duration: 0.28, extraBounce: 0)) {
            hasCompletedOnboarding = true
        }
    }

    private func showFinalOnboardingPage() {
        onboardingInitialPage = 2
        hasCompletedOnboarding = false
    }
}

// Shown while restoring an existing session.
private struct LaunchPlaceholder: View {
    var body: some View {
        ZStack {
            TransiumColor.primaryBlue
                .ignoresSafeArea()

            ProgressView()
                .tint(.white)
        }
        .accessibilityLabel("Restoring your session")
    }
}

#Preview {
    ContentView()
        .environment(SessionController())
        .modelContainer(for: transiumSchema.models, inMemory: true)
}

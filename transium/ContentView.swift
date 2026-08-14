//
//  ContentView.swift
//  transium
//
//  Created by Heryan Djaruma on 10/08/26.
//

import AuthenticationServices
import SwiftUI
import SwiftData

private enum RootScreen {
    case onboarding(initialPage: Int)
    case auth
    case home
}

struct ContentView: View {
    @Environment(SessionController.self) private var session
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var rootScreen: RootScreen
    @State private var onboardingInitialPage = 0
    @StateObject private var toastCenter = AppToastCenter.shared

    init() {
        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: Self.onboardingCompletionKey)

        _rootScreen = State(initialValue: hasCompletedOnboarding ? .auth : .onboarding(initialPage: 0))
    }

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
        hasCompletedOnboarding = true

        withAnimation(.smooth(duration: 0.28, extraBounce: 0)) {
            rootScreen = .auth
        }
    }

    private func showFinalOnboardingPage() {
        onboardingInitialPage = 2
        hasCompletedOnboarding = false
    }
}

#Preview {
    ContentView()
        .environment(SessionController())
        .modelContainer(for: transiumSchema.models, inMemory: true)
}

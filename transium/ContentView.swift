//
//  ContentView.swift
//  transium
//
//  Created by Heryan Djaruma on 10/08/26.
//

import SwiftUI
import SwiftData

private enum RootScreen {
    case onboarding
    case auth
}

struct ContentView: View {
    private static let onboardingCompletionKey = "hasCompletedOnboarding"

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var rootScreen: RootScreen
    @State private var onboardingInitialPage = 0

    init() {
        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: Self.onboardingCompletionKey)

        _rootScreen = State(initialValue: hasCompletedOnboarding ? .auth : .onboarding)
    }

    var body: some View {
        switch rootScreen {
        case .auth:
            AuthScreen(onBackToOnboarding: showFinalOnboardingPage)
        case .onboarding:
            OnboardingScreen(initialPage: onboardingInitialPage, onComplete: completeOnboarding)
        }
    }

    // MARK: Important Flow - Onboarding Before Auth

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

        withAnimation(.smooth(duration: 0.28, extraBounce: 0)) {
            rootScreen = .onboarding
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: transiumSchema.models, inMemory: true)
}

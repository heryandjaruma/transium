//
//  ContentView.swift
//  transium
//
//  Created by Heryan Djaruma on 10/08/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var onboardingInitialPage = 0

    var body: some View {
        if hasCompletedOnboarding {
            AuthScreen(onBackToOnboarding: showFinalOnboardingPage)
        } else {
            OnboardingScreen(initialPage: onboardingInitialPage, onComplete: completeOnboarding)
        }
    }

    // MARK: Important Flow - Onboarding Before Auth

    private func completeOnboarding() {
        onboardingInitialPage = 0
        hasCompletedOnboarding = true
    }

    private func showFinalOnboardingPage() {
        onboardingInitialPage = 2
        hasCompletedOnboarding = false
    }
}

#Preview {
    ContentView()
        .modelContainer(for: transiumSchema.models, inMemory: true)
}

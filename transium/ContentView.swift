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

    var body: some View {
        if shouldShowOnboarding {
            OnboardingScreen {
                hasCompletedOnboarding = true
            }
        } else {
            AuthScreen()
        }
    }

    // MARK: Important Flow - Onboarding Before Auth

    private var shouldShowOnboarding: Bool {
        AppEnvironment.DEV_MODE || !hasCompletedOnboarding
    }
}

#Preview {
    ContentView()
        .modelContainer(for: transiumSchema.models, inMemory: true)
}

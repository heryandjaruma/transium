//
//  TransiumDesignSystem.swift
//  transium
//

import SwiftUI

enum TransiumAsset {
    enum Illustration {
        static let authHero = "hero"
        static let onboardingExplore = "Onboarding1"
        static let onboardingAdventure = "Onboarding2"
        static let onboardingShare = "Onboarding3"
    }
}

enum TransiumColor {
    static let primaryBlue = Color("PrimaryBlue")
    static let primaryYellow = Color("PrimaryYellow")
    static let authBlue = Color(red: 0.19, green: 0.43, blue: 0.91)
    static let linkBlue = Color(red: 0.0, green: 0.18, blue: 0.62)
}

enum TransiumFont {
    static func display(_ size: CGFloat) -> Font {
        .custom("Londrina Solid", size: size)
    }

    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom("Poppins", size: size).weight(weight)
    }
}

enum AppEnvironment {
    // MARK: Important Flow - Dev Onboarding Replay

    /// Keep `false` for normal app behavior. Set `true` locally when the
    /// onboarding flow should replay on every launch while polishing it.
    static let DEV_MODE = false
}

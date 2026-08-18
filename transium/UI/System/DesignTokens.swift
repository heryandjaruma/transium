//
//  DesignTokens.swift
//  transium
//

import SwiftUI

enum TransiumAsset {
    enum Illustration {
        static let authHero = "hero"
        static let onboardingExplore = "onboard-1"
        static let onboardingAdventure = "onboard-2"
        static let onboardingShare = "onboard-3"
        static let permissionOnboarding = "Permission_onboarding"
        static let payment = "Payment"
    
    }
    
    enum Logo {
        static let tmd = "logo_tmd"
    }
}

enum TransiumColor {
    static let primaryBlue = Color("PrimaryBlue")
    static let primaryYellow = Color("PrimaryYellow")
    static let darkBlue = Color("DarkBlue")
    static let authBlue = Color(red: 0.19, green: 0.43, blue: 0.91)
    static let linkBlue = Color(red: 0.0, green: 0.18, blue: 0.62)
}

enum TransiumFont {
    static func display(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom(londrinaName(for: weight), size: size)
    }

    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom(poppinsName(for: weight), size: size)
    }

    private static func londrinaName(for weight: Font.Weight) -> String {
        if weight == .black || weight == .heavy || weight == .bold {
            return "LondrinaSolid-Black"
        }

        if weight == .light {
            return "LondrinaSolid-Light"
        }

        if weight == .thin || weight == .ultraLight {
            return "LondrinaSolid-Thin"
        }

        return "LondrinaSolid-Regular"
    }

    private static func poppinsName(for weight: Font.Weight) -> String {
        if weight == .bold || weight == .heavy || weight == .black {
            return "Poppins-Bold"
        }

        if weight == .semibold {
            return "Poppins-SemiBold"
        }

        if weight == .medium {
            return "Poppins-Medium"
        }

        return "Poppins-Regular"
    }
}

nonisolated enum AppEnvironment {
    // MARK: Important Flow - Dev Onboarding Replay

    // Replay onboarding on every launch.
    static let DEV_MODE = true
}

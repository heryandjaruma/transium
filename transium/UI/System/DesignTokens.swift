//
//  DesignTokens.swift
//  transium
//

import SwiftUI

enum TransiumAsset {
    enum Illustration {
        static let authHero = "hero"
        static let onboardingExplore = "onboarding-explore"
        static let onboardingAdventure = "onboarding-adventure"
        static let onboardingShare = "onboarding-explore"
        
        static let onboardingTrophy = "onboarding-trophy"
        static let onboardingStampMonkey = "onboarding-stamp-monkey"
        static let onboardingStampTemple = "onboarding-stamp-temple"
        static let onboardingStampStatue = "onboarding-stamp-statue"
        
        // Aliases for compatibility
        static let onboard3trophy = onboardingTrophy
        static let onboard3photo1 = onboardingStampMonkey
        static let onboard3photo2 = onboardingStampTemple
        static let onboard3photo3 = onboardingStampStatue
        
        static let permissionOnboarding = "permission-onboarding"
        static let payment = "Payment"
    }
    
    enum Logo {
        static let tmd = "logo_tmd"
    }

    enum Ticket {
        static let postageFrame = "postage-frame"
        static let paperBadge = "paper-badge"
    }
}

enum TransiumColor {
    static let primaryBlue = Color("PrimaryBlue")
    static let primaryYellow = Color("PrimaryYellow")
    static let darkBlue = Color("DarkBlue")
    static let primary9Blue = Color("Primary9Blue")
    static let mainGreen = Color("MainGreen")
    static let lightRed = Color("lightRed")
    static let authBlue = Color(red: 0.19, green: 0.43, blue: 0.91)
    static let linkBlue = Color(red: 0.0, green: 0.18, blue: 0.62)
    static let ticketBlue = Color(red: 0.20, green: 0.45, blue: 0.95)
    static let ticketMint = Color(red: 0.31, green: 0.78, blue: 0.58)
    static let ticketCoral = Color(red: 1.0, green: 0.39, blue: 0.32)
    static let ticketInk = Color(red: 0.07, green: 0.08, blue: 0.13)
}

enum TransiumTransitColor {
    static func color(for routeRef: String?, hex: String? = nil) -> Color {
        Color(uiColor: uiColor(for: routeRef, hex: hex))
    }
    
    static func uiColor(for routeRef: String?, hex: String? = nil) -> UIColor {
        if let hex = hex?.trimmingCharacters(in: .whitespacesAndNewlines), !hex.isEmpty {
            return parseHex(hex)
        }
        guard let ref = routeRef?.trimmingCharacters(in: .whitespacesAndNewlines), !ref.isEmpty else {
            return UIColor(red: 0.19, green: 0.43, blue: 0.91, alpha: 1.0)
        }
        let baseRef = ref.components(separatedBy: "-").first?.uppercased() ?? ref.uppercased()
        switch baseRef {
        case "K1B": return parseHex("#2563EB") // Royal Blue (Koridor 1)
        case "K2B": return parseHex("#DC2626") // Coral Crimson Red (Koridor 2)
        case "K3B": return parseHex("#0D9488") // Deep Teal (Koridor 3)
        case "K4B": return parseHex("#7C3AED") // Purple Amethyst (Koridor 4)
        case "K5B": return parseHex("#D97706") // Amber Gold (Koridor 5)
        case "K6B": return parseHex("#0284C7") // Sky Blue (Koridor 6)
        case "I1":  return parseHex("#05ACC1") // Turquoise Aqua
        case "TS1": return parseHex("#019E73") // Emerald Jade
        default:    return parseHex("#2563EB")
        }
    }
    
    static func parseHex(_ hex: String) -> UIColor {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if hexSanitized.hasPrefix("#") {
            hexSanitized.removeFirst()
        }
        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)
        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0
        return UIColor(red: r, green: g, blue: b, alpha: 1.0)
    }
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
    // MARK: Important Flow - Preview Dev Mode

    /// Only true when running inside Xcode SwiftUI Canvas Previews (#Preview).
    /// When running on a real iPhone or Simulator build, this is false.
    static var DEV_MODE: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
}

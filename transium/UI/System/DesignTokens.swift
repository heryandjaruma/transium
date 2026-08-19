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

    enum Ticket {
        static let postageFrame = "postage-frame"
        static let paperBadge = "paper-badge"
    }
}

enum TransiumColor {
    static let primaryBlue = Color("PrimaryBlue")
    static let primaryYellow = Color("PrimaryYellow")
    static let darkBlue = Color("DarkBlue")
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
        case "K1B": return parseHex("#0072B2")
        case "K2B": return parseHex("#0073B2")
        case "K3B": return parseHex("#164C64")
        case "K4B": return parseHex("#40B0A6")
        case "K5B": return parseHex("#E69F00")
        case "K6B": return parseHex("#57B4E9")
        case "I1":  return parseHex("#05ACC1")
        case "TS1": return parseHex("#019E73")
        default:    return parseHex("#0073B2")
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

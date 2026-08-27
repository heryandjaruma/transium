//
//  AppLanguageManager.swift
//  transium
//

import Foundation
import SwiftUI

/// Supported languages in Transium.
enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case indonesia = "id"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english: return "English"
        case .indonesia: return "Bahasa Indonesia"
        }
    }

    var flag: String {
        switch self {
        case .english: return "🇺🇸"
        case .indonesia: return "🇮🇩"
        }
    }

    var locale: Locale {
        Locale(identifier: rawValue)
    }
}

/// Manages app-wide in-app localization and dynamic locale switching.
@Observable
final class AppLanguageManager {
    static let shared = AppLanguageManager()

    private static let storageKey = "app_language_code"

    var currentLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: Self.storageKey)
            UserDefaults.standard.set([currentLanguage.rawValue], forKey: "AppleLanguages")
            UserDefaults.standard.synchronize()
        }
    }

    init() {
        let saved = UserDefaults.standard.string(forKey: Self.storageKey) ?? "en"
        self.currentLanguage = AppLanguage(rawValue: saved) ?? .english
    }

    func setLanguage(_ language: AppLanguage) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            self.currentLanguage = language
        }
    }
}

//
//  APIConfiguration.swift
//  transium
//

import Foundation

public nonisolated enum APIConfiguration {
    // MARK: Important Flow - Point The App At transium-api

    /// Used by BetterAuth & API endpoints
    public static let origin = URL(string: "https://transium-api.heryandjaruma.workers.dev")!

    public static var apiBaseURL: URL {
        origin.appending(path: "api")
    }

    public static var authBaseURL: URL {
        origin.appending(path: "api/auth")
    }

    /// Resolves an absolute or relative image/media URL path against the API origin
    public static func resolveURL(_ raw: String?) -> URL? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
        if raw.hasPrefix("http://") || raw.hasPrefix("https://") {
            return URL(string: raw)
        }
        let sanitized = raw.hasPrefix("/") ? String(raw.dropFirst()) : raw
        return origin.appending(path: sanitized)
    }
}

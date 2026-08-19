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
}

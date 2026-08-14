//
//  APIConfiguration.swift
//  transium
//

import Foundation

nonisolated enum APIConfiguration {
    // MARK: Important Flow - Point The App At transium-api

    /// Used by BetterAuth
    static let origin = URL(string: "https://transium-api.heryandjaruma.workers.dev")!

    static var authBaseURL: URL {
        origin.appending(path: "api/auth")
    }
}

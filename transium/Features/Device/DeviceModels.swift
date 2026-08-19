//
//  DeviceModels.swift
//  transium
//

import Foundation

// MARK: - DeviceEnvironment
public nonisolated enum DeviceEnvironment: String, Codable, Sendable {
    case sandbox
    case production
}

// MARK: - DeviceToken
public nonisolated struct DeviceToken: Codable, Identifiable, Sendable, Equatable {
    public let id: String
    public let environment: DeviceEnvironment
    public let createdAt: Date
    public let updatedAt: Date

    public init(
        id: String,
        environment: DeviceEnvironment = .production,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.environment = environment
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Device Request Payloads
public nonisolated struct RegisterDeviceRequest: Codable, Sendable {
    public let token: String
    public let environment: DeviceEnvironment?

    public init(token: String, environment: DeviceEnvironment? = .production) {
        self.token = token
        self.environment = environment
    }
}

public nonisolated struct UnregisterDeviceRequest: Codable, Sendable {
    public let token: String

    public init(token: String) {
        self.token = token
    }
}

// MARK: - DevicePushTestResult
public nonisolated struct DevicePushTestResult: Codable, Sendable, Equatable {
    public let token: String
    public let ok: Bool
    public let status: Int
    public let reason: String?

    public init(
        token: String,
        ok: Bool,
        status: Int,
        reason: String? = nil
    ) {
        self.token = token
        self.ok = ok
        self.status = status
        self.reason = reason
    }
}

// MARK: - Response Wrappers
nonisolated struct DeviceListResponse: Codable {
    let deviceTokens: [DeviceToken]
}

nonisolated struct DeviceRegisterResponse: Codable {
    let deviceToken: DeviceToken
}

nonisolated struct DevicePushTestResponse: Codable {
    let results: [DevicePushTestResult]
}

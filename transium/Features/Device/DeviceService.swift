//
//  DeviceService.swift
//  transium
//

import Foundation

public protocol DeviceServiceProtocol: Sendable {
    /// List the caller's registered APNs devices.
    func listDevices() async throws -> [DeviceToken]
    
    /// Register (or re-register) the caller's APNs device token.
    func registerDevice(token: String, environment: DeviceEnvironment) async throws -> DeviceToken
    
    /// Unregister a device token.
    func unregisterDevice(token: String) async throws
    
    /// Send a test push notification to the caller's devices.
    func testPush() async throws -> [DevicePushTestResult]
}

public final class DeviceService: DeviceServiceProtocol, Sendable {
    public static let shared = DeviceService()

    private let apiClient: APIClientProtocol

    public init(apiClient: APIClientProtocol = APIClient.shared) {
        self.apiClient = apiClient
    }

    public func listDevices() async throws -> [DeviceToken] {
        let response: DeviceListResponse = try await apiClient.request(
            path: "/private/device",
            method: .get,
            queryItems: nil,
            body: nil,
            requiresAuth: true
        )
        return response.deviceTokens
    }

    public func registerDevice(token: String, environment: DeviceEnvironment = .production) async throws -> DeviceToken {
        let body = RegisterDeviceRequest(token: token, environment: environment)
        let response: DeviceRegisterResponse = try await apiClient.request(
            path: "/private/device",
            method: .post,
            queryItems: nil,
            body: body,
            requiresAuth: true
        )
        return response.deviceToken
    }

    public func unregisterDevice(token: String) async throws {
        let body = UnregisterDeviceRequest(token: token)
        try await apiClient.requestVoid(
            path: "/private/device",
            method: .delete,
            queryItems: nil,
            body: body,
            requiresAuth: true
        )
    }

    public func testPush() async throws -> [DevicePushTestResult] {
        let response: DevicePushTestResponse = try await apiClient.request(
            path: "/private/device/test",
            method: .post,
            queryItems: nil,
            body: nil,
            requiresAuth: true
        )
        return response.results
    }
}

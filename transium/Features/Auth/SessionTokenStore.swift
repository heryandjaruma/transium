//
//  SessionTokenStore.swift
//  transium
//

import Foundation
import Security

/// Stores the Better Auth session token securely in Keychain.
nonisolated enum SessionTokenStore {
    private static let service = "si.transporta.transium-app.auth"
    private static let account = "better-auth.session-token"
    private static let profileAccount = "better-auth.cached-profile"

    // MARK: Important Flow - Persist The Bearer Session Token & Cached Profile

    static func save(_ token: String, profile: BackendProfile? = nil) {
        saveKeychainData(Data(token.utf8), account: account)
        if let profile, let profileData = try? JSONEncoder().encode(profile) {
            saveKeychainData(profileData, account: profileAccount)
        }
    }

    static func saveProfile(_ profile: BackendProfile) {
        if let profileData = try? JSONEncoder().encode(profile) {
            saveKeychainData(profileData, account: profileAccount)
        }
    }

    static func read() -> String? {
        guard let data = readKeychainData(account: account),
              let token = String(data: data, encoding: .utf8),
              !token.isEmpty else {
            return nil
        }
        return token
    }

    static func readProfile() -> BackendProfile? {
        guard let data = readKeychainData(account: profileAccount) else {
            return nil
        }
        return try? JSONDecoder().decode(BackendProfile.self, from: data)
    }

    static func clear() {
        deleteKeychainData(account: account)
        deleteKeychainData(account: profileAccount)
    }

    // MARK: - Private Keychain Helpers

    private static func saveKeychainData(_ data: Data, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            SecItemAdd(query.merging(attributes) { _, new in new } as CFDictionary, nil)
        }
    }

    private static func readKeychainData(account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else {
            return nil
        }
        return data
    }

    private static func deleteKeychainData(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

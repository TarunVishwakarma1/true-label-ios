//
//  DeviceAuth.swift
//  truelable
//
//  This app has no accounts, so the device is the subject — but a device
//  identifier is not a secret. It is handed to other apps from the same
//  vendor, and anything carrying it in a URL ends up in proxy and access
//  logs. So the server issues a bearer token once, and that token, not the
//  identifier, is what proves who is calling.
//

import Foundation
import Security

actor DeviceAuth {
    static let shared = DeviceAuth()

    private var cached: String?
    private var registration: Task<String, Error>?

    private init() {}

    /// The token for this install, registering on first use. Concurrent
    /// callers share one registration — two in flight would mint two rows
    /// and orphan one of them.
    func token() async throws -> String {
        if let cached { return cached }
        if let stored = Keychain.read() {
            cached = stored
            return stored
        }
        if let registration { return try await registration.value }

        let task = Task<String, Error> {
            let issued = try await API.registerDevice()
            Keychain.write(issued.token)
            return issued.token
        }
        registration = task
        defer { self.registration = nil }

        let token = try await task.value
        cached = token
        return token
    }

    /// Called when the server rejects our token, which means the row behind
    /// it is gone — the account was deleted, or the database was reset. The
    /// next call registers afresh.
    func forget() {
        cached = nil
        Keychain.delete()
    }
}

/// The token is a credential, so it belongs in the Keychain rather than
/// UserDefaults. It also survives deleting the app, which is what lets a
/// reinstall keep its profile instead of orphaning it.
private enum Keychain {
    private static let service = "fun.truelabel.device"
    private static let account = "device-token"

    private static var query: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    static func read() -> String? {
        var request = query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        guard SecItemCopyMatching(request as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8),
              !token.isEmpty else { return nil }
        return token
    }

    static func write(_ token: String) {
        delete()
        var request = query
        request[kSecValueData as String] = Data(token.utf8)
        // Readable after the first unlock so a background refresh still works,
        // but never synced to iCloud or another device: this token stands for
        // one install.
        request[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(request as CFDictionary, nil)
    }

    static func delete() {
        SecItemDelete(query as CFDictionary)
    }
}

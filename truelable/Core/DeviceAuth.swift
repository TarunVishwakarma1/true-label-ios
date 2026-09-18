import Foundation
import Security

actor DeviceAuth {
    static let shared = DeviceAuth()

    private var cached: String?
    private var registration: Task<String, Error>?

    private init() {}

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

    func forget() {
        cached = nil
        Keychain.delete()
    }
}

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

        request[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(request as CFDictionary, nil)
    }

    static func delete() {
        SecItemDelete(query as CFDictionary)
    }
}

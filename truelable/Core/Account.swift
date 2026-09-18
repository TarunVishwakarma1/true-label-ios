import AuthenticationServices
import Foundation

@Observable
@MainActor
final class Account {
    static let shared = Account()

    private(set) var signedIn = false
    private(set) var displayName: String?
    private(set) var email: String?
    private(set) var busy = false
    private(set) var lastError: String?

    private init() {

        signedIn = UserDefaults.standard.bool(forKey: Keys.signedIn)
        displayName = UserDefaults.standard.string(forKey: Keys.displayName)
        email = UserDefaults.standard.string(forKey: Keys.email)
    }

    var label: String {
        displayName?.nilIfBlank ?? email?.nilIfBlank ?? "Signed in with Apple"
    }

    func refresh() async {
        guard let profile = try? await API.profile() else { return }
        apply(profile.identity)
    }

    @discardableResult
    func signIn(with credential: ASAuthorizationAppleIDCredential) async -> Bool {
        guard let tokenData = credential.identityToken,
              let token = String(data: tokenData, encoding: .utf8) else {
            lastError = "Apple didn't return a usable sign-in token."
            return false
        }

        busy = true
        defer { busy = false }
        lastError = nil

        let name = [credential.fullName?.givenName, credential.fullName?.familyName]
            .compactMap { $0 }
            .joined(separator: " ")
            .nilIfBlank

        do {
            let profile = try await API.linkApple(identityToken: token, displayName: name)
            apply(profile.identity)
            await Plus.shared.refresh()
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func setName(_ name: String) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        busy = true
        defer { busy = false }
        guard let profile = try? await API.updateProfile(displayName: trimmed) else {
            lastError = "Couldn't save that. Check your connection."
            return
        }
        lastError = nil
        displayName = profile.identity.displayName
        UserDefaults.standard.set(displayName, forKey: Keys.displayName)
    }

    func signOut() async {
        busy = true
        defer { busy = false }
        _ = try? await API.unlinkApple()
        apply(nil)
        await Plus.shared.refresh()
    }

    @discardableResult
    func deleteAccount() async -> Bool {
        busy = true
        defer { busy = false }
        do {
            try await API.deleteAccount()

            await DeviceAuth.shared.forget()
            apply(nil)
            await Plus.shared.refresh()
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    private func apply(_ identity: Identity?) {
        signedIn = identity?.signedIn ?? false
        displayName = identity?.displayName
        email = identity?.email
        UserDefaults.standard.set(signedIn, forKey: Keys.signedIn)
        UserDefaults.standard.set(displayName, forKey: Keys.displayName)
        UserDefaults.standard.set(email, forKey: Keys.email)
    }

    private enum Keys {
        static let signedIn = "v2.account.signedIn"
        static let displayName = "v2.account.displayName"
        static let email = "v2.account.email"
    }
}

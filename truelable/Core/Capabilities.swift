//
//  Capabilities.swift
//  truelable
//

enum Capabilities {
    /// Sign in with Apple requires a paid Apple Developer Program team — a
    /// personal team cannot sign an app that declares the entitlement at all.
    /// Flip this together with `CODE_SIGN_ENTITLEMENTS`; see
    /// `truelable.entitlements` for the two steps.
    ///
    /// Off, the account page falls back to a name you choose, which needs no
    /// capability and still gives the profile something to identify you by.
    static let signInWithApple = false
}

//
//  AccountView.swift
//  truelable
//
//  The one page about who you are. Signed out it explains what signing in
//  buys and offers the only provider; signed in it shows what we hold, and
//  lets you leave — sign out keeps everything, delete removes it.
//

import AuthenticationServices
import SwiftUI

struct AccountView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Keys.dietary) private var dietaryRaw = ""
    @State private var confirmDelete = false
    @State private var deleted = false
    @State private var nameDraft = ""

    private let account = Account.shared
    private let plus = Plus.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Group {
                        if account.signedIn {
                            signedIn
                        } else if Capabilities.signInWithApple {
                            signedOut
                        } else {
                            nameOnly
                        }
                    }
                    .appear(0)
                    // Signing in or out swaps the whole panel, so the swap
                    // is worth animating — it is the only thing that
                    // confirms the tap did anything.
                    .animation(.tlSettle, value: account.signedIn)
                    whatWeStore.appear(1)
                }
                .padding(.horizontal, TL.gutter)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            .screenBackground()
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
            }
        }
        .presentationBackground(TL.bg)
        .presentationCornerRadius(32)
        .task { await account.refresh() }
        .confirmationDialog("Delete your account?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete account", role: .destructive) {
                Task { deleted = await account.deleteAccount() }
            }
        } message: {
            Text("Removes your profile, preferences and Plus from our servers. Products you helped verify stay verified. This can't be undone.")
        }
        .sensoryFeedback(.success, trigger: account.signedIn)
    }

    // MARK: Signed out

    private var signedOut: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "person.crop.circle.dashed")
                    .font(.system(size: 40))
                    .foregroundStyle(TL.fg3)
                Text("Keep your profile\nif you change phones.")
                    .font(.displayM)
                    .tracking(-0.5)
                Text("Everything works without an account. Signing in only means your preferences and Plus come back on a new phone instead of starting over.")
                    .font(.subheadline)
                    .foregroundStyle(TL.fg2)
            }

            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                guard case .success(let auth) = result,
                      let credential = auth.credential as? ASAuthorizationAppleIDCredential else { return }
                Task { await account.signIn(with: credential) }
            }
            .signInWithAppleButtonStyle(.white)
            .frame(height: 54)
            .clipShape(Capsule())
            .disabled(account.busy)

            if account.busy {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Setting things up…").font(.footnote).foregroundStyle(TL.fg2)
                }
            }
            if let error = account.lastError {
                Text(error).font(.footnote).foregroundStyle(TL.danger)
            }

            Text("Apple is the only way to sign in here, so there's no password to forget and no email for us to lose. You can hide your email address and it still works.")
                .font(.caption)
                .foregroundStyle(TL.fg3)
        }
        .card()
    }

    // MARK: Name only

    /// Sign in with Apple needs a paid developer team, so on a personal team
    /// the honest version of "who are you" is a name you choose. No account,
    /// nothing to verify, and the same row behind it.
    private var nameOnly: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 40))
                    .foregroundStyle(TL.fg3)
                Text("What should we\ncall you?")
                    .font(.displayM)
                    .tracking(-0.5)
                Text("Optional, and it's the only thing we'd know about you. Everything else in the app works without it.")
                    .font(.subheadline)
                    .foregroundStyle(TL.fg2)
            }

            TextField("Your name", text: $nameDraft)
                .textContentType(.name)
                .submitLabel(.done)
                .font(.body.weight(.medium))
                .padding(16)
                .glassEffect(.regular, in: .capsule)
                .onSubmit { save() }

            Button {
                save()
            } label: {
                HStack(spacing: 8) {
                    if account.busy { ProgressView().tint(TL.ink) }
                    Text(account.displayName == nil ? "Save" : "Update")
                }
            }
            .buttonStyle(.primary)
            .disabled(account.busy || nameDraft.trimmingCharacters(in: .whitespaces).isEmpty)

            if let error = account.lastError {
                Text(error).font(.footnote).foregroundStyle(TL.danger)
            }

            Text("Signing in with Apple would also carry your preferences to a new phone. It needs a paid developer account, so it isn't in this build yet.")
                .font(.caption)
                .foregroundStyle(TL.fg3)
        }
        .card()
        .onAppear { nameDraft = account.displayName ?? "" }
    }

    private func save() {
        Task { await account.setName(nameDraft) }
    }

    // MARK: Signed in

    private var signedIn: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 16) {
                Image(systemName: "person.crop.circle.fill.badge.checkmark")
                    .font(.system(size: 34))
                    .foregroundStyle(TL.accent)
                VStack(alignment: .leading, spacing: 4) {
                    Text(account.label)
                        .font(.headline)
                        .lineLimit(1)
                    Text(plus.isActive ? "TrueLabel Plus is on" : "Free plan")
                        .font(.footnote)
                        .foregroundStyle(plus.isActive ? TL.brass : TL.fg3)
                }
                Spacer()
            }

            if let email = account.email {
                row("Email", email)
            }
            row("Preferences", DietaryPreference.decode(dietaryRaw).isEmpty
                ? "None set" : "\(DietaryPreference.decode(dietaryRaw).count) saved")

            Hairline()

            Button("Sign out") { Task { await account.signOut() } }
                .buttonStyle(.secondary)
                .disabled(account.busy)

            Button(role: .destructive) {
                confirmDelete = true
            } label: {
                Text("Delete account")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(TL.danger)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
            }
            .disabled(account.busy)

            Text("Signing out leaves everything on this phone. Deleting removes it from our servers too.")
                .font(.caption)
                .foregroundStyle(TL.fg3)
        }
        .card()
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.footnote).foregroundStyle(TL.fg2)
            Spacer()
            Text(value).font(.footnote.weight(.medium)).lineLimit(1)
        }
    }

    // MARK: Disclosure

    /// Plain language, in the app, rather than only a policy URL nobody opens.
    private var whatWeStore: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "What we store")
            line("barcode.viewfinder", "The barcodes you look up, to count how popular a product is. Not tied to you.")
            line("slider.horizontal.3", "Your preferences and Plus status, against your device.")
            line("person.crop.circle", account.signedIn
                 ? "Your Apple account id, so a new phone can restore the above."
                 : "Nothing about who you are, beyond a name if you give one.")
            line("iphone", "Scan history never leaves this phone.")
        }
        .card()
    }

    private func line(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(TL.fg3)
                .frame(width: 22)
            Text(text).font(.footnote).foregroundStyle(TL.fg2)
        }
    }
}

/// The row that opens the page, used at the top of You.
struct AccountCard: View {
    @State private var showing = false
    private let account = Account.shared

    var body: some View {
        Button { showing = true } label: {
            HStack(spacing: 16) {
                Image(systemName: account.signedIn ? "person.crop.circle.fill" : "person.crop.circle.dashed")
                    .font(.title2)
                    .foregroundStyle(account.signedIn ? TL.accent : TL.fg3)
                    .frame(width: 44, height: 44)
                    .background((account.signedIn ? TL.accent : TL.fg3).opacity(0.14),
                                in: RoundedRectangle(cornerRadius: TL.R.sm, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(account.signedIn
                     ? account.label
                     : (Capabilities.signInWithApple ? "Sign in" : (Account.shared.displayName ?? "Add your name")))
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text(account.signedIn
                         ? "Your profile follows you to a new phone."
                         : (Capabilities.signInWithApple
                            ? "Optional. Keeps your profile if you change phones."
                            : "Optional. Tell us what to call you."))
                        .font(.footnote)
                        .foregroundStyle(TL.fg2)
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(TL.fg3)
            }
            .card(.flat)
        }
        .buttonStyle(.pressable)
        .sheet(isPresented: $showing) { AccountView() }
    }
}

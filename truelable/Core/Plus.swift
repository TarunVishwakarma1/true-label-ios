//
//  Plus.swift
//  truelable
//
//  One source of truth for "is Plus on". Two things can grant it: the
//  backend (which is how it works while Plus is complimentary — there is
//  nothing to buy yet) and a StoreKit entitlement (which is how it will work
//  once there is). Either one is enough, so the switch to paid needs no
//  change here.
//

import Foundation
import StoreKit

@Observable
@MainActor
final class Plus {
    static let shared = Plus()

    static let monthlyID = "fun.truelabel.plus.monthly"
    static let yearlyID = "fun.truelabel.plus.yearly"
    static let ids = [yearlyID, monthlyID]

    /// Free tier limits — the numbers Plus lifts.
    static let freeCompareLimit = 2
    static let freeAlternativesLimit = 3

    private(set) var isActive = false
    private(set) var isComplimentary = false
    private(set) var products: [StoreKit.Product] = []
    private(set) var busy = false

    /// Nothing to sell yet, so Plus is given away and the paywall becomes a
    /// switch. Once products exist in App Store Connect this flips on its own.
    var isGiveaway: Bool { products.isEmpty }

    private var updates: Task<Void, Never>?

    private init() {
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await self?.refresh()
                }
            }
        }
        Task {
            await loadProducts()
            await refresh()
        }
    }

    func refresh() async {
        var active = false
        var complimentary = false

        if let subscription = try? await API.subscription() {
            active = subscription.active
            complimentary = subscription.isComplimentary
        }
        for await result in Transaction.currentEntitlements {
            if case .verified(let t) = result, Self.ids.contains(t.productID), t.revocationDate == nil {
                active = true
                complimentary = false
            }
        }

        isActive = active
        isComplimentary = complimentary
    }

    func loadProducts() async {
        products = (try? await StoreKit.Product.products(for: Self.ids)) ?? []
    }

    /// Turn Plus on during the free period. Returns false if the server
    /// couldn't be reached — nothing is unlocked optimistically, or the next
    /// launch would silently take it away again.
    @discardableResult
    func activateGiveaway() async -> Bool {
        busy = true
        defer { busy = false }
        guard let subscription = try? await API.activatePlus() else { return false }
        isActive = subscription.active
        isComplimentary = subscription.isComplimentary
        return subscription.active
    }

    func cancel() async {
        busy = true
        defer { busy = false }
        if let subscription = try? await API.cancelPlus() {
            isActive = subscription.active
            isComplimentary = subscription.isComplimentary
        }
    }
}

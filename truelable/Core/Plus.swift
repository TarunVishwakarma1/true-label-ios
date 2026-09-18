import Foundation
import StoreKit

@Observable
@MainActor
final class Plus {
    static let shared = Plus()

    static let monthlyID = "fun.truelabel.plus.monthly"
    static let yearlyID = "fun.truelabel.plus.yearly"
    static let ids = [yearlyID, monthlyID]

    static let freeCompareLimit = 2
    static let freeAlternativesLimit = 3

    private(set) var isActive = false
    private(set) var isComplimentary = false
    private(set) var products: [StoreKit.Product] = []
    private(set) var busy = false

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

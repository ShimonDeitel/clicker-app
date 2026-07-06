import Foundation
import StoreKit
import Observation

/// StoreKit 2 manager: loads the two Clicker Pro subscriptions, handles
/// purchases, and keeps the entitlement flag fresh.
///
/// Free-tier gate: 1 saved TV free; adding TV #2 requires Pro. The saved-TV
/// count lives in SwiftData, so callers pass it in (see `canAddTV(currentCount:)`).
@Observable
final class StoreManager {

    static let monthlyProductID = "clicker_pro_monthly"
    static let yearlyProductID = "clicker_pro_yearly"
    static let productIDs: Set<String> = [monthlyProductID, yearlyProductID]

    /// Free tier: full remote for 1 saved TV.
    static let freeTVLimit = 1

    private(set) var products: [Product] = []
    /// "Pro" = either subscription currently entitled.
    private(set) var isPro = false
    private(set) var isLoadingProducts = false
    private(set) var lastErrorMessage: String?

    private var updatesTask: Task<Void, Never>?

    init() {
        // Listen for transactions that arrive outside a purchase flow
        // (renewals, Ask to Buy approvals, purchases on other devices).
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                if case .verified(let transaction) = update {
                    await transaction.finish()
                }
                await self?.refreshEntitlements()
            }
        }

        Task { [weak self] in
            await self?.loadProducts()
            await self?.refreshEntitlements()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    // MARK: Free-tier gate

    /// `currentCount` is the SavedTV count from SwiftData (fetch count in the view).
    func canAddTV(currentCount: Int) -> Bool {
        isPro || currentCount < Self.freeTVLimit
    }

    // MARK: Products

    @MainActor
    func loadProducts() async {
        guard !isLoadingProducts else { return }
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            let loaded = try await Product.products(for: Self.productIDs)
            // Monthly first, yearly second.
            products = loaded.sorted { $0.price < $1.price }
        } catch {
            lastErrorMessage = "Could not load products: \(error.localizedDescription)"
        }
    }

    // MARK: Purchase

    @MainActor
    @discardableResult
    func purchase(_ product: Product) async -> Bool {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                }
                await refreshEntitlements()
                return isPro
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            lastErrorMessage = error.localizedDescription
            return false
        }
    }

    @MainActor
    func restorePurchases() async {
        do {
            try await AppStore.sync()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
        await refreshEntitlements()
    }

    // MARK: Entitlements

    @MainActor
    func refreshEntitlements() async {
        var pro = false
        for await entitlement in Transaction.currentEntitlements {
            guard case .verified(let transaction) = entitlement else { continue }
            if Self.productIDs.contains(transaction.productID), transaction.revocationDate == nil {
                pro = true
            }
        }
        isPro = pro
    }
}

import SwiftUI
import StoreKit

/// Clicker Pro paywall. // PLACEHOLDER UI — functional list, no design pass yet.
struct PaywallView: View {
    @Environment(StoreManager.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Clicker Pro")
                        .font(.title2.bold())
                    Text("Unlimited saved TVs, keyboard input, and app shortcuts.")
                        .foregroundStyle(.secondary)
                }

                Section("Plans") {
                    if store.products.isEmpty {
                        Text(store.isLoadingProducts ? "Loading plans..." : "Plans unavailable.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(store.products, id: \.id) { product in
                        Button {
                            Task {
                                if await store.purchase(product) {
                                    dismiss()
                                }
                            }
                        } label: {
                            HStack {
                                Text(product.displayName)
                                Spacer()
                                Text(product.displayPrice)
                            }
                        }
                    }
                }

                Section {
                    Button("Restore Purchases") {
                        Task {
                            await store.restorePurchases()
                            if store.isPro { dismiss() }
                        }
                    }
                }

                if let error = store.lastErrorMessage {
                    Section {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Go Pro")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

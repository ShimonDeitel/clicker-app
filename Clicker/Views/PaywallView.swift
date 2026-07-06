import SwiftUI
import StoreKit

/// Clicker Pro paywall. Transparent pricing, no trial traps (Apple 5.6).
struct PaywallView: View {
    @Environment(StoreManager.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var selectedProductID: String?
    @State private var isPurchasing = false

    private static let privacyURL: URL? = nil
    private static let termsURL: URL? = nil

    var body: some View {
        ZStack {
            LivingRoomBackdrop(intensity: 0.8)

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(ClickerTheme.creamSoft)
                            .padding(10)
                            .background(Circle().fill(ClickerTheme.panel))
                    }
                    .accessibilityLabel("Close")
                }
                .padding(.top, 14)
                .padding(.horizontal, 20)

                ScrollView {
                    VStack(spacing: 20) {
                        remoteMark
                        titleBlock
                        if store.isPro {
                            proActive
                        } else {
                            offerBlock
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 30)
                }
            }
        }
        .task {
            if store.products.isEmpty { await store.loadProducts() }
            if selectedProductID == nil {
                selectedProductID = store.products.last?.id ?? StoreManager.yearlyProductID
            }
        }
    }

    private var remoteMark: some View {
        ZStack {
            Circle()
                .fill(ClickerTheme.neon.opacity(0.15))
                .frame(width: 110, height: 110)
                .blendMode(.plusLighter)
            Circle()
                .strokeBorder(ClickerTheme.neon, lineWidth: 2.5)
                .frame(width: 84, height: 84)
            Image(systemName: "sparkles.tv.fill")
                .font(.system(size: 34))
                .foregroundStyle(ClickerTheme.neon)
        }
        .padding(.top, 2)
    }

    private var titleBlock: some View {
        VStack(spacing: 7) {
            Text("Clicker Pro")
                .font(ClickerTheme.display(30))
                .foregroundStyle(ClickerTheme.cream)
            Text("Every TV in the house, one remote.")
                .font(ClickerTheme.text(15))
                .foregroundStyle(ClickerTheme.creamSoft)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: Offer

    private var offerBlock: some View {
        VStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 11) {
                bullet("Unlimited saved TVs (free keeps 1)")
                bullet("Keyboard input on supported TVs")
                bullet("Quick app-launch shortcuts")
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if store.products.isEmpty {
                if store.isLoadingProducts {
                    ProgressView().tint(ClickerTheme.neon).padding(.vertical, 24)
                } else {
                    VStack(spacing: 10) {
                        Text("Signal's weak. One second.")
                            .font(ClickerTheme.text(14))
                            .foregroundStyle(ClickerTheme.creamSoft)
                        Button("Try again") {
                            Task { await store.loadProducts() }
                        }
                        .font(ClickerTheme.text(15, weight: .bold))
                        .foregroundStyle(ClickerTheme.neon)
                    }
                    .padding(.vertical, 14)
                }
            } else {
                VStack(spacing: 12) {
                    ForEach(store.products) { product in
                        productCard(product)
                    }
                }
            }

            purchaseButton

            Button("Restore purchases") {
                Task {
                    await store.restorePurchases()
                    if store.isPro { dismiss() }
                }
            }
            .font(ClickerTheme.text(14))
            .foregroundStyle(ClickerTheme.creamSoft)

            if let message = store.lastErrorMessage {
                Text(message)
                    .font(ClickerTheme.text(12))
                    .foregroundStyle(ClickerTheme.danger)
                    .multilineTextAlignment(.center)
            }

            footnote
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(ClickerTheme.neon)
            Text(text)
                .font(ClickerTheme.text(15))
                .foregroundStyle(ClickerTheme.cream)
        }
    }

    private func productCard(_ product: Product) -> some View {
        let isSelected = selectedProductID == product.id
        let isYearly = product.subscription?.subscriptionPeriod.unit == .year

        return Button {
            ClickerHaptics.key()
            selectedProductID = product.id
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(isYearly ? "Yearly" : "Monthly")
                        .font(ClickerTheme.text(17, weight: .bold))
                        .foregroundStyle(ClickerTheme.cream)
                    if isYearly, let monthly = yearlyPerMonthText(product) {
                        Text("\(monthly) a month")
                            .font(ClickerTheme.mono(11))
                            .foregroundStyle(ClickerTheme.creamSoft)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(product.displayPrice)
                        .font(ClickerTheme.display(19))
                        .foregroundStyle(ClickerTheme.cream)
                    Text(isYearly ? "per year" : "per month")
                        .font(ClickerTheme.mono(10))
                        .foregroundStyle(ClickerTheme.creamSoft)
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16).fill(ClickerTheme.panel))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(isSelected ? ClickerTheme.neon : ClickerTheme.panelLight, lineWidth: isSelected ? 2.5 : 1.5)
            )
            .overlay(alignment: .topTrailing) {
                if isYearly, let savings = yearlySavingsText {
                    Text(savings)
                        .font(ClickerTheme.mono(9, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(ClickerTheme.charcoalDeep)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(ClickerTheme.neon))
                        .offset(x: -8, y: -9)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func yearlyPerMonthText(_ yearly: Product) -> String? {
        let perMonth = yearly.price / 12
        return perMonth.formatted(yearly.priceFormatStyle.precision(.fractionLength(2)))
    }

    private var yearlySavingsText: String? {
        guard
            let monthly = store.products.first(where: { $0.subscription?.subscriptionPeriod.unit == .month }),
            let yearly = store.products.first(where: { $0.subscription?.subscriptionPeriod.unit == .year }),
            monthly.price > 0
        else { return nil }
        let fullYear = monthly.price * 12
        guard fullYear > yearly.price else { return nil }
        let fraction = (fullYear - yearly.price) / fullYear
        let percent = Int((NSDecimalNumber(decimal: fraction).doubleValue * 100).rounded())
        return "SAVE \(percent)%"
    }

    private var purchaseButton: some View {
        Button {
            guard let product = store.products.first(where: { $0.id == selectedProductID }) else { return }
            ClickerHaptics.power()
            isPurchasing = true
            Task {
                defer { isPurchasing = false }
                if await store.purchase(product) {
                    ClickerHaptics.success()
                    dismiss()
                }
            }
        } label: {
            ZStack {
                Capsule()
                    .fill(ClickerTheme.neon)
                    .frame(height: 56)
                    .shadow(color: ClickerTheme.neon.opacity(0.4), radius: 14, y: 5)
                if isPurchasing {
                    ProgressView().tint(ClickerTheme.charcoalDeep)
                } else {
                    Text("Power on Pro")
                        .font(ClickerTheme.text(18, weight: .bold))
                        .foregroundStyle(ClickerTheme.charcoalDeep)
                }
            }
        }
        .disabled(isPurchasing || store.products.isEmpty || selectedProductID == nil)
        .opacity(store.products.isEmpty ? 0.35 : 1)
        .buttonStyle(KeyPressStyle())
    }

    private var footnote: some View {
        VStack(spacing: 8) {
            Text("Auto-renews until cancelled. Cancel anytime in Settings.")
                .font(ClickerTheme.mono(10))
                .foregroundStyle(ClickerTheme.creamSoft.opacity(0.7))
                .multilineTextAlignment(.center)
            HStack(spacing: 18) {
                if let url = Self.privacyURL { Link("Privacy", destination: url) }
                if let url = Self.termsURL { Link("Terms", destination: url) }
            }
            .font(ClickerTheme.mono(10))
            .foregroundStyle(ClickerTheme.creamSoft.opacity(0.7))
        }
    }

    private var proActive: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 40))
                .foregroundStyle(ClickerTheme.neon)
            Text("Every TV, unlocked.")
                .font(ClickerTheme.display(20))
                .foregroundStyle(ClickerTheme.cream)
            Text("Add as many as your house has.")
                .font(ClickerTheme.text(14))
                .foregroundStyle(ClickerTheme.creamSoft)
        }
        .padding(.vertical, 28)
    }
}

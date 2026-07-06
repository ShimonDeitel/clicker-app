import SwiftUI
import SwiftData

/// Devices: the couch-radar sweep finds TVs on the network; saved TVs sit
/// below as glowing panel rows; manual IP entry is the always-works fallback.
struct DevicesView: View {
    @Environment(DiscoveryService.self) private var discovery
    @Environment(StoreManager.self) private var store
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedTV.createdAt) private var savedTVs: [SavedTV]

    @State private var manualHost = ""
    @State private var isProbingManual = false
    @State private var manualProbeMessage: String?
    @State private var showPaywall = false
    @State private var showManualEntry = false

    var body: some View {
        ZStack {
            LivingRoomBackdrop(intensity: 0.6)

            ScrollView {
                VStack(spacing: 22) {
                    radarCard
                    if !savedTVs.isEmpty {
                        savedSection
                    }
                    manualSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("DEVICES")
                    .font(ClickerTheme.mono(13, weight: .bold))
                    .tracking(3)
                    .foregroundStyle(ClickerTheme.cream)
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .onDisappear { discovery.stopScan() }
    }

    // MARK: Radar

    private var radarCard: some View {
        VStack(spacing: 16) {
            SonarSweepView(
                dots: discovery.discovered.map {
                    SonarDot(id: $0.id, label: $0.name)
                },
                scanning: discovery.isScanning
            )
            .frame(maxWidth: 300)
            .onChange(of: discovery.discovered.count) { old, new in
                if new > old { ClickerHaptics.found() }
            }

            Button {
                discovery.isScanning ? discovery.stopScan() : discovery.startScan()
            } label: {
                Text(discovery.isScanning ? "Stop scanning" : "Scan for TVs")
                    .font(ClickerTheme.text(16, weight: .bold))
                    .foregroundStyle(discovery.isScanning ? ClickerTheme.cream : ClickerTheme.charcoalDeep)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        Capsule().fill(discovery.isScanning ? AnyShapeStyle(ClickerTheme.panelLight) : AnyShapeStyle(ClickerTheme.neon))
                    )
            }
            .buttonStyle(KeyPressStyle())

            if !discovery.discovered.isEmpty {
                VStack(spacing: 8) {
                    ForEach(discovery.discovered) { tv in
                        foundRow(tv)
                    }
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(ClickerTheme.panel.opacity(0.7))
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(ClickerTheme.neon.opacity(0.15), lineWidth: 1))
        )
    }

    private func foundRow(_ tv: DiscoveredTV) -> some View {
        Button {
            add(name: tv.name, host: tv.host, port: tv.port, brand: tv.brand)
        } label: {
            HStack {
                Circle()
                    .fill(ClickerTheme.neon)
                    .frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 1) {
                    Text(tv.name)
                        .font(ClickerTheme.text(14, weight: .semibold))
                        .foregroundStyle(ClickerTheme.cream)
                    Text("\(tv.brand.displayName)? · \(tv.host)")
                        .font(ClickerTheme.mono(11))
                        .foregroundStyle(ClickerTheme.creamSoft)
                }
                Spacer()
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(ClickerTheme.neon)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(RoundedRectangle(cornerRadius: 12).fill(ClickerTheme.panelLight.opacity(0.6)))
        }
        .buttonStyle(.plain)
    }

    // MARK: Saved TVs

    private var savedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PAIRED")
                .font(ClickerTheme.mono(11, weight: .bold))
                .tracking(2)
                .foregroundStyle(ClickerTheme.creamSoft)
            VStack(spacing: 10) {
                ForEach(savedTVs) { tv in
                    savedRow(tv)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func savedRow(_ tv: SavedTV) -> some View {
        HStack {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(ClickerTheme.panelLight)
                    .frame(width: 44, height: 44)
                Image(systemName: "tv.fill")
                    .foregroundStyle(ClickerTheme.neon)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(tv.name)
                    .font(ClickerTheme.text(15, weight: .semibold))
                    .foregroundStyle(ClickerTheme.cream)
                Text("\(tv.brandEnum.displayName) · \(tv.host)")
                    .font(ClickerTheme.mono(11))
                    .foregroundStyle(ClickerTheme.creamSoft)
            }
            Spacer()
            Button {
                modelContext.delete(tv)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundStyle(ClickerTheme.danger.opacity(0.8))
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(ClickerTheme.panel.opacity(0.6)))
    }

    // MARK: Manual IP

    private var manualSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ADD BY IP ADDRESS")
                .font(ClickerTheme.mono(11, weight: .bold))
                .tracking(2)
                .foregroundStyle(ClickerTheme.creamSoft)

            HStack(spacing: 10) {
                TextField("192.168.1.20", text: $manualHost)
                    .keyboardType(.decimalPad)
                    .autocorrectionDisabled()
                    .font(ClickerTheme.mono(15))
                    .foregroundStyle(ClickerTheme.cream)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(ClickerTheme.panel))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(ClickerTheme.neon.opacity(0.2), lineWidth: 1))

                Button {
                    Task { await probeManual() }
                } label: {
                    if isProbingManual {
                        ProgressView().tint(ClickerTheme.charcoalDeep)
                            .frame(width: 60, height: 46)
                    } else {
                        Text("Add")
                            .font(ClickerTheme.text(15, weight: .bold))
                            .foregroundStyle(ClickerTheme.charcoalDeep)
                            .frame(width: 60, height: 46)
                    }
                }
                .background(Capsule().fill(ClickerTheme.neon))
                .buttonStyle(KeyPressStyle())
                .disabled(manualHost.isEmpty || isProbingManual)
            }

            if let manualProbeMessage {
                Text(manualProbeMessage)
                    .font(ClickerTheme.text(12))
                    .foregroundStyle(ClickerTheme.creamSoft)
            }
        }
    }

    private func probeManual() async {
        isProbingManual = true
        manualProbeMessage = nil
        defer { isProbingManual = false }
        let host = manualHost.trimmingCharacters(in: .whitespaces)
        guard let brand = await discovery.validateManualIP(host: host) else {
            withAnimation { manualProbeMessage = "No Roku, Samsung, or LG TV answered at \(host)." }
            return
        }
        let port: Int
        switch brand {
        case .roku: port = 8060
        case .samsung: port = 8002
        case .lg: port = 3000
        }
        add(name: "\(brand.displayName) TV", host: host, port: port, brand: brand)
        manualHost = ""
    }

    // MARK: Save (free-tier gate: TV #2 requires Pro)

    private func add(name: String, host: String, port: Int, brand: TVBrand) {
        guard store.canAddTV(currentCount: savedTVs.count) else {
            ClickerHaptics.warning()
            showPaywall = true
            return
        }
        ClickerHaptics.success()
        let tv = SavedTV(name: name, host: host, port: port, brand: brand)
        modelContext.insert(tv)
    }
}

import SwiftUI
import SwiftData

/// Devices screen: Bonjour scan list, manual IP add, saved TVs.
/// // PLACEHOLDER UI — plain lists, no design pass yet.
struct DevicesView: View {
    @Environment(DiscoveryService.self) private var discovery
    @Environment(StoreManager.self) private var store
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedTV.createdAt) private var savedTVs: [SavedTV]

    @State private var manualHost = ""
    @State private var isProbingManual = false
    @State private var manualProbeMessage = ""
    @State private var showPaywall = false

    var body: some View {
        List {
            savedSection
            scanSection
            manualSection
        }
        .navigationTitle("Devices")
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .onDisappear { discovery.stopScan() }
    }

    // MARK: Saved TVs

    private var savedSection: some View {
        Section("Saved TVs") {
            if savedTVs.isEmpty {
                Text("No saved TVs yet.")
                    .foregroundStyle(.secondary)
            }
            ForEach(savedTVs) { tv in
                VStack(alignment: .leading) {
                    Text(tv.name)
                    Text("\(tv.brandEnum.displayName) · \(tv.host):\(String(tv.port))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .onDelete { offsets in
                for index in offsets {
                    modelContext.delete(savedTVs[index])
                }
            }
        }
    }

    // MARK: Bonjour scan

    private var scanSection: some View {
        Section("Nearby (Bonjour)") {
            Button(discovery.isScanning ? "Stop Scan" : "Scan for TVs") {
                discovery.isScanning ? discovery.stopScan() : discovery.startScan()
            }
            ForEach(discovery.discovered) { tv in
                Button {
                    add(name: tv.name, host: tv.host, port: tv.port, brand: tv.brand)
                } label: {
                    VStack(alignment: .leading) {
                        Text(tv.name)
                        Text("\(tv.brand.displayName)? · \(tv.host):\(String(tv.port))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: Manual IP

    private var manualSection: some View {
        Section("Add by IP") {
            TextField("192.168.1.20", text: $manualHost)
                .keyboardType(.decimalPad)
                .autocorrectionDisabled()
            Button(isProbingManual ? "Probing..." : "Detect & Add") {
                Task { await probeManual() }
            }
            .disabled(manualHost.isEmpty || isProbingManual)
            if !manualProbeMessage.isEmpty {
                Text(manualProbeMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func probeManual() async {
        isProbingManual = true
        defer { isProbingManual = false }
        let host = manualHost.trimmingCharacters(in: .whitespaces)
        guard let brand = await discovery.validateManualIP(host: host) else {
            manualProbeMessage = "No Roku, Samsung, or LG TV answered at \(host)."
            return
        }
        manualProbeMessage = ""
        let port: Int
        switch brand {
        case .roku: port = 8060
        case .samsung: port = 8002
        case .lg: port = 3000
        }
        add(name: "\(brand.displayName) TV", host: host, port: port, brand: brand)
    }

    // MARK: Save (free-tier gate: TV #2 requires Pro)

    private func add(name: String, host: String, port: Int, brand: TVBrand) {
        guard store.canAddTV(currentCount: savedTVs.count) else {
            showPaywall = true
            return
        }
        let tv = SavedTV(name: name, host: host, port: port, brand: brand)
        modelContext.insert(tv)
    }
}

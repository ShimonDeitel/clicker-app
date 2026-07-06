import Foundation
import Network
import Observation

/// Bonjour (NWBrowser) discovery for the four service types declared in
/// NSBonjourServices, plus manual-IP probing. v1 has NO SSDP (multicast
/// entitlement not requested); Bonjour + manual IP only.
@Observable
final class DiscoveryService {

    /// Bonjour service type -> best-guess brand mapping.
    private static let serviceTypes: [(type: String, brand: TVBrand)] = [
        ("_airplay._tcp", .roku),            // brand refined by probe when saved
        ("_googlecast._tcp", .lg),           // cast-capable; refined by probe
        ("_lg-smart-device._tcp", .lg),
        ("_samsungmsf._tcp", .samsung),
    ]

    private(set) var discovered: [DiscoveredTV] = []
    private(set) var isScanning = false

    private var browsers: [NWBrowser] = []
    private let queue = DispatchQueue(label: "com.deitel.clicker.discovery")

    // MARK: Bonjour scan

    func startScan() {
        stopScan()
        discovered = []
        isScanning = true

        for service in Self.serviceTypes {
            let params = NWParameters()
            params.includePeerToPeer = false
            let browser = NWBrowser(
                for: .bonjour(type: service.type, domain: nil),
                using: params
            )
            browser.browseResultsChangedHandler = { [weak self] results, _ in
                self?.resolve(results: results, brand: service.brand)
            }
            browser.start(queue: queue)
            browsers.append(browser)
        }
    }

    func stopScan() {
        for browser in browsers { browser.cancel() }
        browsers = []
        isScanning = false
    }

    /// Resolves each browse result to host/port by opening a short-lived
    /// NWConnection and reading the remote endpoint from its path.
    private func resolve(results: Set<NWBrowser.Result>, brand: TVBrand) {
        for result in results {
            guard case .service(let name, _, _, _) = result.endpoint else { continue }

            let connection = NWConnection(to: result.endpoint, using: .tcp)
            connection.stateUpdateHandler = { [weak self, weak connection] state in
                guard let self, let connection else { return }
                switch state {
                case .ready:
                    if let endpoint = connection.currentPath?.remoteEndpoint,
                       case .hostPort(let host, let port) = endpoint {
                        let tv = DiscoveredTV(
                            name: name,
                            host: Self.string(from: host),
                            port: Int(port.rawValue),
                            brand: brand,
                            source: .bonjour
                        )
                        Task { @MainActor in
                            if !self.discovered.contains(where: { $0.id == tv.id }) {
                                self.discovered.append(tv)
                            }
                        }
                    }
                    connection.cancel()
                case .failed, .cancelled:
                    connection.cancel()
                default:
                    break
                }
            }
            connection.start(queue: queue)
        }
    }

    private static func string(from host: NWEndpoint.Host) -> String {
        switch host {
        case .ipv4(let address): return "\(address)"
        case .ipv6(let address): return "\(address)"
        case .name(let name, _): return name
        @unknown default: return "\(host)"
        }
    }

    // MARK: Manual IP validation

    /// Probes the given host for a known TV protocol and returns the detected
    /// brand, or nil if nothing answered:
    ///  - Roku:    GET http://host:8060/query/device-info (XML)
    ///  - Samsung: GET http://host:8001/api/v2/ (JSON device descriptor)
    ///  - LG:      TCP connect to :3000
    func validateManualIP(host: String) async -> TVBrand? {
        if await probeRoku(host: host) { return .roku }
        if await probeSamsung(host: host) { return .samsung }
        if await probeTCP(host: host, port: 3000) { return .lg }
        return nil
    }

    private func probeRoku(host: String) async -> Bool {
        guard let url = URL(string: "http://\(host):8060/query/device-info") else { return false }
        var request = URLRequest(url: url)
        request.timeoutInterval = 3
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let body = String(data: data, encoding: .utf8) else { return false }
        return body.contains("<device-info")
    }

    private func probeSamsung(host: String) async -> Bool {
        guard let url = URL(string: "http://\(host):8001/api/v2/") else { return false }
        var request = URLRequest(url: url)
        request.timeoutInterval = 3
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200 else { return false }
        return (try? JSONSerialization.jsonObject(with: data)) is [String: Any]
    }

    private func probeTCP(host: String, port: UInt16) async -> Bool {
        await withCheckedContinuation { continuation in
            let connection = NWConnection(
                host: NWEndpoint.Host(host),
                port: NWEndpoint.Port(rawValue: port)!,
                using: .tcp
            )
            let done = OSAllocatedUnfairLock(initialState: false)
            let finish: (Bool) -> Void = { success in
                let first = done.withLock { alreadyDone -> Bool in
                    if alreadyDone { return false }
                    alreadyDone = true
                    return true
                }
                if first {
                    connection.cancel()
                    continuation.resume(returning: success)
                }
            }
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready: finish(true)
                case .failed, .cancelled: finish(false)
                default: break
                }
            }
            connection.start(queue: queue)
            queue.asyncAfter(deadline: .now() + 3) { finish(false) }
        }
    }
}

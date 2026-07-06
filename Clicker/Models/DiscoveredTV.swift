import Foundation

/// A TV found via Bonjour scan or manual IP validation, not yet saved.
struct DiscoveredTV: Identifiable, Hashable {
    enum Source: String {
        case bonjour
        case manual
    }

    var name: String
    var host: String
    var port: Int
    var brand: TVBrand
    var source: Source

    var id: String { "\(brand.rawValue)-\(host):\(port)" }
}

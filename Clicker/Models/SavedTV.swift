import Foundation
import SwiftData

enum TVBrand: String, Codable, CaseIterable {
    case roku
    case samsung
    case lg

    var displayName: String {
        switch self {
        case .roku: return "Roku"
        case .samsung: return "Samsung"
        case .lg: return "LG"
        }
    }
}

@Model
final class SavedTV {
    var name: String
    var host: String
    var port: Int
    /// Raw value of TVBrand ("roku" | "samsung" | "lg").
    var brand: String
    /// Samsung/LG pairing token (Samsung websocket token or LG client-key). Empty for Roku.
    var authToken: String
    var lastSeenAt: Date
    var createdAt: Date

    init(name: String, host: String, port: Int, brand: TVBrand, authToken: String = "") {
        self.name = name
        self.host = host
        self.port = port
        self.brand = brand.rawValue
        self.authToken = authToken
        self.lastSeenAt = .now
        self.createdAt = .now
    }

    var brandEnum: TVBrand { TVBrand(rawValue: brand) ?? .roku }

    /// Builds the protocol controller for this TV. Token updates are persisted
    /// back onto the model via the callback.
    func makeController(onTokenUpdate: @escaping (String) -> Void) -> TVController {
        switch brandEnum {
        case .roku:
            return RokuController(host: host, port: port)
        case .samsung:
            return SamsungController(host: host, port: port, token: authToken.isEmpty ? nil : authToken, onTokenUpdate: onTokenUpdate)
        case .lg:
            return LGController(host: host, port: port, clientKey: authToken.isEmpty ? nil : authToken, onClientKeyUpdate: onTokenUpdate)
        }
    }
}

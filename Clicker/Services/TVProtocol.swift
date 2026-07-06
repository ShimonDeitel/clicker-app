import Foundation

/// Remote keys shared across all TV protocols. Each controller maps these to
/// its protocol-specific key names.
enum RemoteKey: String, CaseIterable {
    case power
    case volumeUp
    case volumeDown
    case mute
    case up
    case down
    case left
    case right
    case select
    case back
    case home
    case playPause
}

/// A controllable TV over the local network.
protocol TVController: AnyObject {
    func connect() async throws
    func send(_ key: RemoteKey) async throws
    var isConnected: Bool { get }
    /// Whether this protocol supports sending free text (keyboard input).
    var supportsTextInput: Bool { get }
    /// Send free text to the TV. Controllers that do not support text input throw.
    func sendText(_ text: String) async throws
}

enum TVControllerError: LocalizedError {
    case notConnected
    case badResponse(String)
    case unsupported(String)
    case pairingRequired

    var errorDescription: String? {
        switch self {
        case .notConnected: return "Not connected to the TV."
        case .badResponse(let detail): return "TV returned an unexpected response: \(detail)"
        case .unsupported(let what): return "\(what) is not supported on this TV."
        case .pairingRequired: return "The TV requires pairing approval."
        }
    }
}

import Foundation

/// Roku External Control Protocol (ECP) over plain HTTP on port 8060.
/// Keypress: POST http://host:8060/keypress/<Key>
/// Verification: GET http://host:8060/query/device-info (returns XML).
/// Text input: POST /keypress/Lit_<percent-encoded character> per character.
final class RokuController: TVController {

    let host: String
    let port: Int
    private let session: URLSession
    private(set) var isConnected = false

    var supportsTextInput: Bool { true }

    init(host: String, port: Int = 8060, session: URLSession = .shared) {
        self.host = host
        self.port = port
        self.session = session
    }

    private var baseURL: URL {
        URL(string: "http://\(host):\(port)")!
    }

    /// ECP key names per the Roku ECP documentation.
    private static let keyMap: [RemoteKey: String] = [
        .power: "Power",
        .volumeUp: "VolumeUp",
        .volumeDown: "VolumeDown",
        .mute: "VolumeMute",
        .up: "Up",
        .down: "Down",
        .left: "Left",
        .right: "Right",
        .select: "Select",
        .back: "Back",
        .home: "Home",
        .playPause: "Play",
    ]

    /// Verifies the device by fetching /query/device-info.
    func connect() async throws {
        let url = baseURL.appendingPathComponent("query/device-info")
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              let body = String(data: data, encoding: .utf8),
              body.contains("<device-info") else {
            isConnected = false
            throw TVControllerError.badResponse("device-info probe failed")
        }
        isConnected = true
    }

    func send(_ key: RemoteKey) async throws {
        guard let ecpKey = Self.keyMap[key] else {
            throw TVControllerError.unsupported(key.rawValue)
        }
        try await keypress(ecpKey)
    }

    func sendText(_ text: String) async throws {
        for character in text {
            let encoded = String(character)
                .addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? String(character)
            try await keypress("Lit_\(encoded)")
        }
    }

    private func keypress(_ ecpKey: String) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("keypress/\(ecpKey)"))
        request.httpMethod = "POST"
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw TVControllerError.badResponse("keypress \(ecpKey) failed")
        }
    }
}

import Foundation

/// Samsung Tizen remote over secure websocket:
///   wss://host:8002/api/v2/channels/samsung.remote.control?name=<base64 app name>&token=<token>
/// The TV presents a self-signed certificate, so a URLSessionDelegate trust
/// override is applied for the TV host ONLY. On first connect (no token) the
/// TV shows an allow prompt; the ms.channel.connect response carries the token,
/// which is persisted via `onTokenUpdate` and reused on later connects.
final class SamsungController: NSObject, TVController {

    let host: String
    let port: Int
    private var token: String?
    private let onTokenUpdate: (String) -> Void

    private var session: URLSession?
    private var socket: URLSessionWebSocketTask?
    private(set) var isConnected = false

    var supportsTextInput: Bool { true }

    init(host: String, port: Int = 8002, token: String?, onTokenUpdate: @escaping (String) -> Void) {
        self.host = host
        self.port = port
        self.token = token
        self.onTokenUpdate = onTokenUpdate
        super.init()
    }

    // MARK: Connect

    func connect() async throws {
        let appName = Data("Clicker".utf8).base64EncodedString()
        var urlString = "wss://\(host):\(port)/api/v2/channels/samsung.remote.control?name=\(appName)"
        if let token, !token.isEmpty {
            urlString += "&token=\(token)"
        }
        guard let url = URL(string: urlString) else {
            throw TVControllerError.badResponse("bad websocket URL")
        }

        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        self.session = session
        let socket = session.webSocketTask(with: url)
        self.socket = socket
        socket.resume()

        // First message is the ms.channel.connect event; it may carry a new token.
        let message = try await socket.receive()
        guard let payload = Self.json(from: message),
              (payload["event"] as? String) == "ms.channel.connect" else {
            disconnect()
            throw TVControllerError.badResponse("expected ms.channel.connect")
        }
        if let data = payload["data"] as? [String: Any],
           let newToken = (data["token"] as? String) ?? (data["token"] as? Int).map(String.init),
           !newToken.isEmpty, newToken != token {
            token = newToken
            onTokenUpdate(newToken)
        }
        isConnected = true
    }

    func disconnect() {
        socket?.cancel(with: .normalClosure, reason: nil)
        socket = nil
        session?.invalidateAndCancel()
        session = nil
        isConnected = false
    }

    // MARK: Keys

    private static let keyMap: [RemoteKey: String] = [
        .power: "KEY_POWER",
        .volumeUp: "KEY_VOLUP",
        .volumeDown: "KEY_VOLDOWN",
        .mute: "KEY_MUTE",
        .up: "KEY_UP",
        .down: "KEY_DOWN",
        .left: "KEY_LEFT",
        .right: "KEY_RIGHT",
        .select: "KEY_ENTER",
        .back: "KEY_RETURN",
        .home: "KEY_HOME",
        .playPause: "KEY_PLAY",
    ]

    func send(_ key: RemoteKey) async throws {
        guard let samsungKey = Self.keyMap[key] else {
            throw TVControllerError.unsupported(key.rawValue)
        }
        try await sendCommand([
            "method": "ms.remote.control",
            "params": [
                "Cmd": "Click",
                "DataOfCmd": samsungKey,
                "Option": "false",
                "TypeOfRemote": "SendRemoteKey",
            ],
        ])
    }

    /// Sends free text using the Tizen base64 text-input command.
    func sendText(_ text: String) async throws {
        let encoded = Data(text.utf8).base64EncodedString()
        try await sendCommand([
            "method": "ms.remote.control",
            "params": [
                "Cmd": encoded,
                "DataOfCmd": "base64",
                "TypeOfRemote": "SendInputString",
            ],
        ])
    }

    private func sendCommand(_ payload: [String: Any]) async throws {
        guard isConnected, let socket else { throw TVControllerError.notConnected }
        let data = try JSONSerialization.data(withJSONObject: payload)
        guard let string = String(data: data, encoding: .utf8) else {
            throw TVControllerError.badResponse("could not encode command")
        }
        try await socket.send(.string(string))
    }

    private static func json(from message: URLSessionWebSocketTask.Message) -> [String: Any]? {
        let data: Data
        switch message {
        case .string(let string): data = Data(string.utf8)
        case .data(let d): data = d
        @unknown default: return nil
        }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }
}

// MARK: - Self-signed TLS trust for the TV host only

extension SamsungController: URLSessionDelegate {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        // Only trust the self-signed cert for this controller's TV host;
        // everything else falls back to default (strict) handling.
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              challenge.protectionSpace.host == host,
              let trust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        completionHandler(.useCredential, URLCredential(trust: trust))
    }
}

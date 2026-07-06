import Foundation

/// LG webOS remote over websocket ws://host:3000.
/// Flow:
///  1. Send a `register` request with the standard permission manifest
///     (pairingType PROMPT). The TV shows an on-screen prompt; the
///     `registered` response carries a client-key, persisted via callback
///     and passed back on later connects to skip the prompt.
///  2. Volume/power via ssap:// URIs.
///  3. D-pad/back/home via a SECOND websocket: request
///     ssap://com.webos.service.networkinput/getPointerInputSocket, connect
///     to the returned socketPath, then send `type:button\nname:<BUTTON>\n\n`
///     text payloads (UP/DOWN/LEFT/RIGHT/ENTER/BACK/HOME).
final class LGController: NSObject, TVController {

    let host: String
    let port: Int
    private var clientKey: String?
    private let onClientKeyUpdate: (String) -> Void

    private var session: URLSession?
    private var socket: URLSessionWebSocketTask?
    private var pointerSocket: URLSessionWebSocketTask?
    private var requestCounter = 0
    private(set) var isConnected = false

    var supportsTextInput: Bool { false }

    init(host: String, port: Int = 3000, clientKey: String?, onClientKeyUpdate: @escaping (String) -> Void) {
        self.host = host
        self.port = port
        self.clientKey = clientKey
        self.onClientKeyUpdate = onClientKeyUpdate
        super.init()
    }

    // MARK: Register / connect

    func connect() async throws {
        guard let url = URL(string: "ws://\(host):\(port)") else {
            throw TVControllerError.badResponse("bad websocket URL")
        }
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        self.session = session
        let socket = session.webSocketTask(with: url)
        self.socket = socket
        socket.resume()

        var payload = Self.registerManifest
        if let clientKey, !clientKey.isEmpty {
            payload["client-key"] = clientKey
        }
        let register: [String: Any] = [
            "type": "register",
            "id": "register_0",
            "payload": payload,
        ]
        try await sendJSON(register, over: socket)

        // Responses: with a valid client-key we get `registered` immediately;
        // without one we first get `response` (pairing prompt shown on TV),
        // then `registered` once the user accepts.
        for _ in 0..<2 {
            let message = try await socket.receive()
            guard let json = Self.json(from: message), let type = json["type"] as? String else {
                continue
            }
            if type == "registered" {
                if let payload = json["payload"] as? [String: Any],
                   let key = payload["client-key"] as? String, key != clientKey {
                    clientKey = key
                    onClientKeyUpdate(key)
                }
                isConnected = true
                return
            }
            if type == "error" {
                disconnect()
                throw TVControllerError.badResponse((json["error"] as? String) ?? "register error")
            }
            // type == "response": PROMPT pairing pending, keep waiting.
        }
        disconnect()
        throw TVControllerError.pairingRequired
    }

    func disconnect() {
        pointerSocket?.cancel(with: .normalClosure, reason: nil)
        pointerSocket = nil
        socket?.cancel(with: .normalClosure, reason: nil)
        socket = nil
        session?.invalidateAndCancel()
        session = nil
        isConnected = false
    }

    // MARK: Keys

    func send(_ key: RemoteKey) async throws {
        guard isConnected else { throw TVControllerError.notConnected }
        switch key {
        case .volumeUp:
            try await request(uri: "ssap://audio/volumeUp")
        case .volumeDown:
            try await request(uri: "ssap://audio/volumeDown")
        case .mute:
            // Simple toggle is not exposed; setMute true is the honest v1 behavior.
            try await request(uri: "ssap://audio/setMute", payload: ["mute": true])
        case .power:
            try await request(uri: "ssap://system/turnOff")
        case .playPause:
            try await request(uri: "ssap://media.controls/play")
        case .up, .down, .left, .right, .select, .back, .home:
            try await sendPointerButton(Self.pointerButtonName(for: key))
        }
    }

    func sendText(_ text: String) async throws {
        throw TVControllerError.unsupported("Text input")
    }

    private static func pointerButtonName(for key: RemoteKey) -> String {
        switch key {
        case .up: return "UP"
        case .down: return "DOWN"
        case .left: return "LEFT"
        case .right: return "RIGHT"
        case .select: return "ENTER"
        case .back: return "BACK"
        case .home: return "HOME"
        default: return ""
        }
    }

    // MARK: Pointer input socket (second websocket)

    private func sendPointerButton(_ button: String) async throws {
        if pointerSocket == nil {
            try await openPointerSocket()
        }
        guard let pointerSocket else { throw TVControllerError.notConnected }
        // webOS pointer socket speaks a plain-text line protocol.
        let payload = "type:button\nname:\(button)\n\n"
        try await pointerSocket.send(.string(payload))
    }

    private func openPointerSocket() async throws {
        guard let socket, let session else { throw TVControllerError.notConnected }
        let id = nextRequestID()
        try await sendJSON([
            "type": "request",
            "id": id,
            "uri": "ssap://com.webos.service.networkinput/getPointerInputSocket",
        ], over: socket)

        let message = try await socket.receive()
        guard let json = Self.json(from: message),
              let payload = json["payload"] as? [String: Any],
              let socketPath = payload["socketPath"] as? String,
              let url = URL(string: socketPath) else {
            throw TVControllerError.badResponse("no pointer socketPath")
        }
        let pointer = session.webSocketTask(with: url)
        pointer.resume()
        pointerSocket = pointer
    }

    // MARK: Plumbing

    private func request(uri: String, payload: [String: Any] = [:]) async throws {
        guard let socket else { throw TVControllerError.notConnected }
        var message: [String: Any] = [
            "type": "request",
            "id": nextRequestID(),
            "uri": uri,
        ]
        if !payload.isEmpty { message["payload"] = payload }
        try await sendJSON(message, over: socket)
    }

    private func nextRequestID() -> String {
        requestCounter += 1
        return "clicker_\(requestCounter)"
    }

    private func sendJSON(_ object: [String: Any], over socket: URLSessionWebSocketTask) async throws {
        let data = try JSONSerialization.data(withJSONObject: object)
        guard let string = String(data: data, encoding: .utf8) else {
            throw TVControllerError.badResponse("could not encode request")
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

    /// Standard webOS permission manifest used by open-source remotes
    /// (lgtv2 and friends), pairingType PROMPT.
    private static var registerManifest: [String: Any] {
        [
            "pairingType": "PROMPT",
            "manifest": [
                "manifestVersion": 1,
                "appVersion": "1.0",
                "signed": [
                    "created": "20140509",
                    "appId": "com.lge.test",
                    "vendorId": "com.lge",
                    "localizedAppNames": [
                        "": "LG Remote App",
                    ],
                    "localizedVendorNames": [
                        "": "LG Electronics",
                    ],
                    "permissions": [
                        "TEST_SECURE",
                        "CONTROL_INPUT_TEXT",
                        "CONTROL_MOUSE_AND_KEYBOARD",
                        "READ_INSTALLED_APPS",
                        "READ_LGE_SDX",
                        "READ_NOTIFICATIONS",
                        "SEARCH",
                        "WRITE_SETTINGS",
                        "WRITE_NOTIFICATION_ALERT",
                        "CONTROL_POWER",
                        "READ_CURRENT_CHANNEL",
                        "READ_RUNNING_APPS",
                        "READ_UPDATE_INFO",
                        "UPDATE_FROM_REMOTE_APP",
                        "READ_LGE_TV_INPUT_EVENTS",
                        "READ_TV_CURRENT_TIME",
                    ],
                    "serial": "2f930e2d2cfe083771f68e4fe7bb07",
                ],
                "permissions": [
                    "LAUNCH",
                    "LAUNCH_WEBAPP",
                    "APP_TO_APP",
                    "CLOSE",
                    "TEST_OPEN",
                    "TEST_PROTECTED",
                    "CONTROL_AUDIO",
                    "CONTROL_DISPLAY",
                    "CONTROL_INPUT_JOYSTICK",
                    "CONTROL_INPUT_MEDIA_RECORDING",
                    "CONTROL_INPUT_MEDIA_PLAYBACK",
                    "CONTROL_INPUT_TV",
                    "CONTROL_POWER",
                    "READ_APP_STATUS",
                    "READ_CURRENT_CHANNEL",
                    "READ_INPUT_DEVICE_LIST",
                    "READ_NETWORK_STATE",
                    "READ_RUNNING_APPS",
                    "READ_TV_CHANNEL_LIST",
                    "WRITE_NOTIFICATION_TOAST",
                    "READ_POWER_STATE",
                    "READ_COUNTRY_INFO",
                ],
            ],
        ]
    }
}

// MARK: - URLSessionDelegate (ws:// needs no TLS override; kept for :3001 wss later)

extension LGController: URLSessionDelegate {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              challenge.protectionSpace.host == host,
              let trust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        completionHandler(.useCredential, URLCredential(trust: trust))
    }
}

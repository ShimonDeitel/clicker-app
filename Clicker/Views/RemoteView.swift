import SwiftUI
import SwiftData

/// Remote home. // PLACEHOLDER UI — plain button grid, no design pass yet.
struct RemoteView: View {
    @Query(sort: \SavedTV.createdAt) private var savedTVs: [SavedTV]
    @Environment(\.modelContext) private var modelContext

    @State private var activeController: TVController?
    @State private var activeTVID: PersistentIdentifier?
    @State private var statusMessage = ""

    private var activeTV: SavedTV? {
        savedTVs.first { $0.persistentModelID == activeTVID } ?? savedTVs.first
    }

    var body: some View {
        VStack(spacing: 16) {
            if let tv = activeTV {
                Text("\(tv.name) (\(tv.brandEnum.displayName))")
                    .font(.headline)

                if savedTVs.count > 1 {
                    Picker("TV", selection: Binding(
                        get: { activeTV?.persistentModelID },
                        set: { newValue in
                            activeTVID = newValue
                            activeController = nil
                        }
                    )) {
                        ForEach(savedTVs) { tv in
                            Text(tv.name).tag(Optional(tv.persistentModelID))
                        }
                    }
                    .pickerStyle(.menu)
                }

                buttonGrid

                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                ContentUnavailableView(
                    "No TV yet",
                    systemImage: "tv",
                    description: Text("Add a TV from the Devices tab.")
                )
            }
        }
        .padding()
        .navigationTitle("Remote")
    }

    // PLACEHOLDER UI
    private var buttonGrid: some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
        return LazyVGrid(columns: columns, spacing: 12) {
            keyButton("Power", .power)
            keyButton("Vol +", .volumeUp)
            keyButton("Vol -", .volumeDown)
            keyButton("Mute", .mute)
            keyButton("Up", .up)
            keyButton("Down", .down)
            keyButton("Left", .left)
            keyButton("Right", .right)
            keyButton("OK", .select)
            keyButton("Back", .back)
            keyButton("Home", .home)
            keyButton("Play", .playPause)
        }
    }

    private func keyButton(_ label: String, _ key: RemoteKey) -> some View {
        Button(label) {
            Task { await press(key) }
        }
        .buttonStyle(.bordered)
    }

    private func press(_ key: RemoteKey) async {
        guard let tv = activeTV else { return }
        do {
            if activeController == nil || activeController?.isConnected != true {
                let controller = tv.makeController { [weak tv] newToken in
                    Task { @MainActor in
                        tv?.authToken = newToken
                    }
                }
                try await controller.connect()
                activeController = controller
                tv.lastSeenAt = .now
            }
            try await activeController?.send(key)
            statusMessage = ""
        } catch {
            statusMessage = error.localizedDescription
        }
    }
}

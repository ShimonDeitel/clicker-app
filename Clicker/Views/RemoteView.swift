import SwiftUI
import SwiftData

/// Home: a physical-feeling remote for whichever TV is active. Big glowing
/// keys with squash physics and haptics on every press.
struct RemoteView: View {
    @Query(sort: \SavedTV.createdAt) private var savedTVs: [SavedTV]

    @State private var activeTVID: PersistentIdentifier?
    @State private var activeController: TVController?
    @State private var isConnecting = false
    @State private var pressedKey: RemoteKey?
    @State private var errorMessage: String?

    private var activeTV: SavedTV? {
        savedTVs.first { $0.persistentModelID == activeTVID } ?? savedTVs.first
    }

    var body: some View {
        ZStack {
            LivingRoomBackdrop()

            if activeTV == nil {
                emptyState
            } else {
                VStack(spacing: 0) {
                    header
                    Spacer(minLength: 8)
                    powerRow
                        .padding(.top, 18)
                    dPad
                        .padding(.top, 28)
                    volumeAndTransport
                        .padding(.top, 24)
                    Spacer(minLength: 8)
                }
                .padding(.horizontal, 26)
                .padding(.bottom, 20)
            }
        }
        .overlay(alignment: .bottom) { errorToast }
        .onAppear { connectToActiveTV() }
        .onChange(of: activeTVID) { _, _ in connectToActiveTV() }
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: Empty state

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "tv")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(ClickerTheme.neon.opacity(0.7))
            Text("No TV yet")
                .font(ClickerTheme.display(22))
                .foregroundStyle(ClickerTheme.cream)
            Text("Find one on the Devices tab.")
                .font(ClickerTheme.text(14))
                .foregroundStyle(ClickerTheme.creamSoft)
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("CLICKER")
                    .font(ClickerTheme.display(30))
                    .tracking(3)
                    .foregroundStyle(ClickerTheme.cream)
                Text(statusText)
                    .font(ClickerTheme.mono(12))
                    .foregroundStyle(statusColor)
            }
            Spacer()
            if savedTVs.count > 1 {
                Menu {
                    ForEach(savedTVs) { tv in
                        Button(tv.name) { activeTVID = tv.persistentModelID }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "tv")
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(ClickerTheme.neon)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(Capsule().strokeBorder(ClickerTheme.neon.opacity(0.4), lineWidth: 1))
                }
            }
        }
        .padding(.top, 8)
    }

    private var statusText: String {
        guard let activeTV else { return "no tv paired" }
        if isConnecting { return "connecting to \(activeTV.name)…" }
        if activeController?.isConnected == true { return "connected · \(activeTV.name)" }
        return activeTV.name
    }

    private var statusColor: Color {
        activeController?.isConnected == true ? ClickerTheme.neon : ClickerTheme.creamSoft
    }

    // MARK: Power row

    private var powerRow: some View {
        HStack {
            key(.power, systemImage: "power", size: 30, accent: ClickerTheme.danger)
                .frame(width: 76, height: 76)
            Spacer()
            key(.home, systemImage: "house.fill", size: 20)
                .frame(width: 60, height: 60)
            key(.back, systemImage: "arrow.uturn.backward", size: 20)
                .frame(width: 60, height: 60)
        }
    }

    // MARK: D-pad

    private var dPad: some View {
        VStack(spacing: 10) {
            key(.up, systemImage: "chevron.up", size: 22)
                .frame(width: 84, height: 56)
            HStack(spacing: 10) {
                key(.left, systemImage: "chevron.left", size: 22)
                    .frame(width: 56, height: 84)
                key(.select, systemImage: "circle.fill", size: 14)
                    .frame(width: 84, height: 84)
                key(.right, systemImage: "chevron.right", size: 22)
                    .frame(width: 56, height: 84)
            }
            key(.down, systemImage: "chevron.down", size: 22)
                .frame(width: 84, height: 56)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Volume + transport

    private var volumeAndTransport: some View {
        HStack(spacing: 14) {
            VStack(spacing: 10) {
                key(.volumeUp, systemImage: "plus", size: 20)
                key(.volumeDown, systemImage: "minus", size: 20)
            }
            .frame(width: 64)

            key(.playPause, systemImage: "playpause.fill", size: 24)
                .frame(maxWidth: .infinity)
                .frame(height: 64)

            key(.mute, systemImage: "speaker.slash.fill", size: 18)
                .frame(width: 64, height: 64)
        }
    }

    // MARK: Key

    private func key(_ remoteKey: RemoteKey, systemImage: String, size: CGFloat, accent: Color = ClickerTheme.cream) -> some View {
        Button {
            send(remoteKey)
        } label: {
            RemoteKeyView(isPressed: pressedKey == remoteKey) {
                Image(systemName: systemImage)
                    .font(.system(size: size, weight: .semibold))
                    .foregroundStyle(pressedKey == remoteKey ? ClickerTheme.neon : accent)
            }
        }
        .buttonStyle(KeyPressStyle())
    }

    // MARK: Error toast

    @ViewBuilder
    private var errorToast: some View {
        if let errorMessage {
            Text(errorMessage)
                .font(ClickerTheme.text(13, weight: .medium))
                .foregroundStyle(ClickerTheme.cream)
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
                .background(RoundedRectangle(cornerRadius: 12).fill(ClickerTheme.panel))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(ClickerTheme.danger.opacity(0.6), lineWidth: 1))
                .padding(.horizontal, 28)
                .padding(.bottom, 24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .onTapGesture { self.errorMessage = nil }
                .task {
                    try? await Task.sleep(for: .seconds(4))
                    withAnimation { self.errorMessage = nil }
                }
        }
    }

    // MARK: Actions

    private func connectToActiveTV() {
        guard let tv = activeTV else {
            activeController = nil
            return
        }
        isConnecting = true
        let controller = tv.makeController { [weak tv] newToken in
            Task { @MainActor in tv?.authToken = newToken }
        }
        activeController = controller
        Task {
            defer { isConnecting = false }
            do {
                try await controller.connect()
                tv.lastSeenAt = .now
            } catch {
                withAnimation { errorMessage = error.localizedDescription }
            }
        }
    }

    private func send(_ remoteKey: RemoteKey) {
        ClickerHaptics.key()
        pressedKey = remoteKey
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            if pressedKey == remoteKey { pressedKey = nil }
        }
        guard let activeController else { return }
        Task {
            do {
                if !activeController.isConnected {
                    try await activeController.connect()
                }
                try await activeController.send(remoteKey)
            } catch {
                withAnimation { errorMessage = error.localizedDescription }
            }
        }
    }
}

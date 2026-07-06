import SwiftUI
import SwiftData

@main
struct ClickerApp: App {
    @State private var store = StoreManager()
    @State private var discovery = DiscoveryService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(discovery)
        }
        .modelContainer(for: SavedTV.self)
    }
}

/// App shell: Remote home + Devices screen.
struct RootView: View {
    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(ClickerTheme.charcoalDeep)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        Group {
            #if DEBUG
            if let screen = ProcessInfo.processInfo.environment["CLICKER_SCREEN"] {
                DebugScreenHost(screen: screen)
            } else {
                tabs
            }
            #else
            tabs
            #endif
        }
        .tint(ClickerTheme.neon)
        .preferredColorScheme(.dark)
    }

    private var tabs: some View {
        TabView {
            NavigationStack {
                RemoteView()
            }
            .tabItem { Label("Remote", systemImage: "tv") }

            NavigationStack {
                DevicesView()
            }
            .tabItem { Label("Devices", systemImage: "wifi") }
        }
    }
}

#if DEBUG
/// Dev-only direct screen routing for headless screenshot verification:
/// SIMCTL_CHILD_CLICKER_SCREEN=devices|paywall xcrun simctl launch …
/// Never compiled into Release.
private struct DebugScreenHost: View {
    let screen: String

    var body: some View {
        switch screen {
        case "devices":
            NavigationStack { DevicesView() }
        case "paywall":
            PaywallView()
        default:
            NavigationStack { RemoteView() }
        }
    }
}
#endif

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
        .tint(ClickerTheme.neon)
        .preferredColorScheme(.dark)
    }
}

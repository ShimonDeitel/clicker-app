import SwiftUI
import UIKit

/// Clicker's design language: late-night living room, TV-glow blue on
/// near-black, one neon-teal accent. Nothing shared with any sibling app.
enum ClickerTheme {
    // MARK: Palette
    static let charcoal = Color(red: 0.055, green: 0.067, blue: 0.086)
    static let charcoalDeep = Color(red: 0.024, green: 0.031, blue: 0.043)
    static let panel = Color(red: 0.098, green: 0.114, blue: 0.141)
    static let panelLight = Color(red: 0.137, green: 0.157, blue: 0.192)
    static let neon = Color(red: 0.298, green: 0.914, blue: 0.847)
    static let neonDim = Color(red: 0.298, green: 0.914, blue: 0.847).opacity(0.45)
    static let screenGlow = Color(red: 0.451, green: 0.639, blue: 1.0)
    static let cream = Color(red: 0.902, green: 0.914, blue: 0.929)
    static let creamSoft = Color(red: 0.902, green: 0.914, blue: 0.929).opacity(0.55)
    static let danger = Color(red: 0.937, green: 0.412, blue: 0.373)

    static let keyGradient = LinearGradient(
        colors: [panelLight, panel],
        startPoint: .top, endPoint: .bottom
    )

    // MARK: Type
    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
    static func text(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
    static func mono(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

enum ClickerHaptics {
    static func key() { UIImpactFeedbackGenerator(style: .rigid).impactOccurred() }
    static func power() { UIImpactFeedbackGenerator(style: .heavy).impactOccurred() }
    static func found() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
}

/// The living room: near-black with a soft blue TV-glow pool that breathes,
/// as if a screen is on somewhere off-frame.
struct LivingRoomBackdrop: View {
    var intensity: Double = 1

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [ClickerTheme.charcoal, ClickerTheme.charcoalDeep],
                startPoint: .top, endPoint: .bottom
            )

            TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let breathe = 0.5 + 0.5 * sin(t * 0.4)
                RadialGradient(
                    colors: [
                        ClickerTheme.screenGlow.opacity((0.16 + 0.08 * breathe) * intensity),
                        .clear,
                    ],
                    center: .init(x: 0.5, y: 0.0),
                    startRadius: 40, endRadius: 480
                )
                .blendMode(.plusLighter)
            }

            RadialGradient(
                colors: [.clear, ClickerTheme.charcoalDeep.opacity(0.8)],
                center: .center, startRadius: 180, endRadius: 560
            )
        }
        .ignoresSafeArea()
    }
}

/// Squash-press feedback with a neon glow bump, for the physical-key feel.
struct KeyPressStyle: ButtonStyle {
    var glow: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .brightness(configuration.isPressed ? 0.08 : 0)
            .animation(.spring(response: 0.2, dampingFraction: 0.55), value: configuration.isPressed)
    }
}

/// A single glowing hardware-style remote key: rounded rect, subtle bevel,
/// neon glow trail that flashes on press.
struct RemoteKeyView<Label: View>: View {
    var isPressed: Bool
    @ViewBuilder var label: () -> Label

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(ClickerTheme.keyGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(ClickerTheme.neon.opacity(isPressed ? 0.85 : 0.18), lineWidth: isPressed ? 2 : 1)
                )
                .shadow(color: ClickerTheme.neon.opacity(isPressed ? 0.5 : 0), radius: isPressed ? 16 : 0)
                .shadow(color: ClickerTheme.charcoalDeep.opacity(0.6), radius: 6, y: 4)
            label()
                .foregroundStyle(isPressed ? ClickerTheme.neon : ClickerTheme.cream)
        }
        .animation(.spring(response: 0.22, dampingFraction: 0.6), value: isPressed)
    }
}

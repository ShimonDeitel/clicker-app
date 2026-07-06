import SwiftUI

/// The signature: a radar sweep searching the room for TVs. A rotating beam
/// pings outward on concentric rings; discovered devices appear as glowing
/// dots at their arrival angle and fade in with a light haptic (call
/// ClickerHaptics.found() at the call site when a new dot is added).
struct SonarSweepView: View {
    var dots: [SonarDot]
    var scanning: Bool

    var body: some View {
        TimelineView(.animation(paused: !scanning)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let angle = (t.truncatingRemainder(dividingBy: 3)) / 3 * 360

            GeometryReader { geo in
                let side = min(geo.size.width, geo.size.height)
                let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                let radius = side / 2

                ZStack {
                    // Concentric rings.
                    ForEach(1...3, id: \.self) { i in
                        Circle()
                            .stroke(ClickerTheme.neon.opacity(0.14), lineWidth: 1)
                            .frame(width: radius * 2 * CGFloat(i) / 3, height: radius * 2 * CGFloat(i) / 3)
                    }
                    // Crosshair.
                    Path { p in
                        p.move(to: CGPoint(x: center.x - radius, y: center.y))
                        p.addLine(to: CGPoint(x: center.x + radius, y: center.y))
                        p.move(to: CGPoint(x: center.x, y: center.y - radius))
                        p.addLine(to: CGPoint(x: center.x, y: center.y + radius))
                    }
                    .stroke(ClickerTheme.neon.opacity(0.08), lineWidth: 1)

                    if scanning {
                        // Sweeping beam wedge.
                        Path { p in
                            p.move(to: center)
                            p.addArc(
                                center: center, radius: radius,
                                startAngle: .degrees(angle - 26), endAngle: .degrees(angle),
                                clockwise: false
                            )
                            p.closeSubpath()
                        }
                        .fill(
                            AngularGradient(
                                colors: [.clear, ClickerTheme.neon.opacity(0.32)],
                                center: .center,
                                startAngle: .degrees(angle - 26), endAngle: .degrees(angle)
                            )
                        )
                        .blendMode(.plusLighter)

                        // Leading edge line.
                        Path { p in
                            p.move(to: center)
                            let rad = Angle.degrees(angle).radians
                            p.addLine(to: CGPoint(
                                x: center.x + cos(rad) * radius,
                                y: center.y + sin(rad) * radius
                            ))
                        }
                        .stroke(ClickerTheme.neon.opacity(0.75), lineWidth: 1.5)
                    }

                    ForEach(dots) { dot in
                        SonarDotView(dot: dot, center: center, radius: radius)
                    }

                    Circle()
                        .fill(ClickerTheme.neon)
                        .frame(width: 8, height: 8)
                        .shadow(color: ClickerTheme.neon, radius: 6)
                        .position(center)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

/// A discovered TV's position on the sonar, expressed as a stable pseudo-
/// angle/distance derived from its identity so it doesn't jump between
/// scans.
struct SonarDot: Identifiable {
    let id: String
    let label: String

    var angleDegrees: Double {
        let hash = abs(id.hashValue)
        return Double(hash % 360)
    }
    var distanceFraction: Double {
        let hash = abs((id + "d").hashValue)
        return 0.35 + Double(hash % 55) / 100
    }
}

private struct SonarDotView: View {
    let dot: SonarDot
    let center: CGPoint
    let radius: CGFloat

    @State private var appeared = false

    var body: some View {
        let rad = Angle.degrees(dot.angleDegrees).radians
        let r = radius * dot.distanceFraction
        let position = CGPoint(x: center.x + cos(rad) * r, y: center.y + sin(rad) * r)

        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(ClickerTheme.neon.opacity(0.25))
                    .frame(width: 22, height: 22)
                Circle()
                    .fill(ClickerTheme.neon)
                    .frame(width: 9, height: 9)
                    .shadow(color: ClickerTheme.neon, radius: 5)
            }
            Text(dot.label)
                .font(ClickerTheme.mono(9, weight: .semibold))
                .foregroundStyle(ClickerTheme.neon)
                .lineLimit(1)
                .fixedSize()
        }
        .position(position)
        .scaleEffect(appeared ? 1 : 0.2)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                appeared = true
            }
        }
    }
}

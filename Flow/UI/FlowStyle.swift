import SwiftUI

enum FlowStyle {
    static let canvas = Color(red: 0.035, green: 0.045, blue: 0.065)
    static let surface = Color(red: 0.075, green: 0.087, blue: 0.105)
    static let ink = Color(red: 0.95, green: 0.94, blue: 0.90)
    static let muted = Color(red: 0.69, green: 0.73, blue: 0.74)
    static let accent = Color(red: 0.77, green: 0.89, blue: 0.81)
    static let line = Color.white.opacity(0.14)
}

struct FlowPrimaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.medium))
            .frame(maxWidth: .infinity, minHeight: 30)
            .padding(.horizontal, 20).padding(.vertical, 15)
            .foregroundStyle(FlowStyle.canvas)
            .background(FlowStyle.accent.opacity(configuration.isPressed ? 0.75 : 1), in: Capsule())
            .contentShape(Capsule())
    }
}

struct FlowSecondaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.body)
            .frame(maxWidth: .infinity, minHeight: 30)
            .padding(.horizontal, 16).padding(.vertical, 12)
            .foregroundStyle(FlowStyle.ink)
            .background(FlowStyle.surface.opacity(configuration.isPressed ? 0.6 : 1), in: Capsule())
            .overlay(Capsule().stroke(FlowStyle.line, lineWidth: 1))
    }
}

extension View {
    func flowScreen() -> some View {
        foregroundStyle(FlowStyle.ink)
            .tint(FlowStyle.accent)
            .background(FlowStyle.canvas.ignoresSafeArea())
            .toolbarBackground(FlowStyle.canvas, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .preferredColorScheme(.dark)
    }
}

/// Original vector light study; no downloaded artwork or stock photography.
struct Atmosphere: View {
    var warm = false
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(colors: warm ? [Color(red: 0.18, green: 0.12, blue: 0.16), .black]
                               : [Color(red: 0.10, green: 0.19, blue: 0.19), .black],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                Ellipse()
                    .fill(RadialGradient(colors: warm ? [.orange.opacity(0.55), .pink.opacity(0.1), .clear]
                                         : [FlowStyle.accent.opacity(0.45), .teal.opacity(0.09), .clear],
                                         center: .center, startRadius: 0, endRadius: geometry.size.width * 0.6))
                    .frame(width: geometry.size.width * 1.5, height: geometry.size.height * 1.6)
                    .position(x: geometry.size.width * 0.75, y: geometry.size.height * 0.45)
                    .blur(radius: 12)
                Canvas { context, size in
                    for index in 0..<14 {
                        var path = Path()
                        let offset = Double(index) * 8
                        path.move(to: CGPoint(x: -30, y: size.height * 0.48 + offset))
                        path.addCurve(to: CGPoint(x: size.width + 30, y: size.height * 0.68 + offset),
                                      control1: CGPoint(x: size.width * 0.37, y: size.height * 1.15 + offset),
                                      control2: CGPoint(x: size.width * 0.60, y: -size.height * 0.13 + offset))
                        context.stroke(path, with: .color(FlowStyle.ink.opacity(0.09 + Double(index) * 0.007)), lineWidth: 0.6)
                    }
                }
            }.clipped()
        }.accessibilityHidden(true)
    }
}

struct BreathingVisual: View {
    let phase: PhasePosition?
    let running: Bool
    let reduceMotion: Bool
    private var scale: CGFloat {
        guard !reduceMotion, let phase else { return 0.86 }
        let eased = (1 - cos(phase.progress * .pi)) / 2
        return 0.66 + 0.28 * (phase.kind == .inhale ? eased : 1 - eased)
    }
    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            ZStack {
                Circle().fill(RadialGradient(colors: [FlowStyle.accent.opacity(0.20), .clear],
                                            center: .center, startRadius: side * 0.14, endRadius: side * 0.50))
                ForEach(0..<5) { index in
                    Circle().stroke(FlowStyle.accent.opacity(0.10 + Double(index) * 0.035), lineWidth: 0.7)
                        .padding(CGFloat(index) * 12 + 8)
                }
                Circle().fill(RadialGradient(colors: [FlowStyle.accent.opacity(0.025), FlowStyle.accent.opacity(0.14)],
                                            center: .topLeading, startRadius: 0, endRadius: side * 0.75))
                    .overlay(Circle().stroke(FlowStyle.accent.opacity(0.55), lineWidth: 1))
                    .padding(side * 0.10)
                Image(systemName: phase == nil ? "water.waves" : "circle.fill")
                    .font(.system(size: phase == nil ? 26 : 6, weight: .ultraLight))
                    .foregroundStyle(FlowStyle.accent.opacity(0.8))
            }
            .frame(width: side, height: side)
            .scaleEffect(scale)
            .animation(running && !reduceMotion ? .linear(duration: 0.05) : nil, value: phase?.progress)
            .opacity(running ? 1 : 0.62)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }.accessibilityHidden(true)
    }
}

func timeText(_ interval: TimeInterval, roundUp: Bool = false) -> String {
    let seconds = max(0, Int(roundUp ? ceil(interval) : floor(interval)))
    return String(format: "%d:%02d", seconds / 60, seconds % 60)
}

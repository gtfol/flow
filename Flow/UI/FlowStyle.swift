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
        switch phase.kind {
        case .inhale: return 0.66 + 0.28 * eased
        case .holdIn: return 0.94
        case .exhale: return 0.66 + 0.28 * (1 - eased)
        case .holdOut: return 0.66
        }
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

/// Clockwise from bottom-left: inhale, full hold, exhale, empty hold.
private struct BoxTrack: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        return path
    }
}

struct BoxBreathingVisual: View {
    let phase: PhasePosition
    let running: Bool
    let reduceMotion: Bool
    private var side: Int { phase.sequence % 4 }
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height) - 24
            ZStack {
                Rectangle().fill(FlowStyle.accent.opacity(0.025))
                BoxTrack().stroke(FlowStyle.accent.opacity(0.14), lineWidth: 3)
                // Reduced motion keeps the current side highlighted without a moving edge.
                BoxTrack().trim(from: reduceMotion ? Double(side) / 4 : 0,
                                to: reduceMotion ? Double(side + 1) / 4 : (Double(side) + phase.progress) / 4)
                    .stroke(FlowStyle.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                VStack(spacing: 16) {
                    Text(running ? phase.kind.title : "paused")
                        .font(.system(.title, design: .serif))
                        .accessibilityIdentifier("current-cue")
                    Text("\(phase.count ?? 1)")
                        .font(.system(size: 48, weight: .light, design: .rounded).monospacedDigit())
                        .accessibilityIdentifier("breathing-count")
                        .accessibilityLabel("count \(phase.count ?? 1) of 4")
                    HStack(spacing: 9) {
                        ForEach(1...4, id: \.self) { beat in
                            Circle().fill(FlowStyle.accent.opacity(beat == phase.count ? 1 : 0.2))
                                .frame(width: 5, height: 5)
                        }
                    }.accessibilityHidden(true)
                }.multilineTextAlignment(.center).padding(20)
            }.frame(width: size, height: size)
                .opacity(running ? 1 : 0.62)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

func timeText(_ interval: TimeInterval, roundUp: Bool = false) -> String {
    let seconds = max(0, Int(roundUp ? ceil(interval) : floor(interval)))
    return String(format: "%d:%02d", seconds / 60, seconds % 60)
}

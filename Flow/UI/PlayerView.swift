import SwiftUI

struct PlayerView: View {
    @Bindable var coordinator: SessionCoordinator
    // Nil in the app; deterministic rendering tests can exercise the static alternative.
    var reduceMotionOverride: Bool? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    private var engine: SessionEngine { coordinator.engine }

    var body: some View {
        Group {
            if engine.isTerminal { finish }
            else { player }
        }
        .flowScreen()
        .onAppear { coordinator.start() }
        .onDisappear { coordinator.cancel() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { coordinator.appBecameInactive() }
        }
        .interactiveDismissDisabled()
    }

    private var player: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Text(engine.definition.title).font(.subheadline).foregroundStyle(FlowStyle.muted)
                    Text(engine.state == .introduction ? "arrive as you are." : cueTitle)
                        .font(.system(.largeTitle, design: .serif))
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("current-cue")
                }.padding(.top, 28)

                if engine.state == .introduction || (engine.isPaused && engine.elapsed == 0) {
                    if !typeSize.isAccessibilitySize {
                        BreathingVisual(phase: nil, running: true, reduceMotion: true).frame(height: 190)
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Text(Guidance.introductionTitle).font(.caption).foregroundStyle(FlowStyle.muted)
                        Text(Guidance.introduction).font(.body).lineSpacing(5)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("introduction")
                    }
                } else {
                    if !typeSize.isAccessibilitySize {
                        BreathingVisual(phase: engine.phase, running: engine.state == .running,
                                        reduceMotion: reduceMotionOverride ?? reduceMotion)
                            .frame(height: 250)
                    }
                    VStack(spacing: 12) {
                        if engine.mode == .paced && !engine.isPaused {
                            Text("\(Int(ceil(engine.phase?.remaining ?? 4))) seconds · only if comfortable")
                                .font(.subheadline).foregroundStyle(FlowStyle.muted)
                                .monospacedDigit()
                                .accessibilityLabel("optional four second cue. follow your own comfort.")
                        } else {
                            Text(engine.isPaused ? "take all the time you need." : "nothing to match. just your breath.")
                                .font(.subheadline).foregroundStyle(FlowStyle.muted)
                        }
                        Text(timeText(engine.remaining, roundUp: true))
                            .font(.system(.title, design: .rounded).monospacedDigit())
                            .accessibilityLabel("\(Int(ceil(engine.remaining))) seconds remaining")
                            .accessibilityIdentifier("session-remaining")
                        Text("remaining · \(timeText(engine.elapsed)) active")
                            .font(.caption).foregroundStyle(FlowStyle.muted).monospacedDigit()
                            .accessibilityLabel("\(Int(engine.elapsed)) seconds active")
                        ProgressView(value: engine.elapsed, total: engine.definition.duration)
                            .tint(FlowStyle.accent).accessibilityHidden(true)
                    }
                    if engine.mode == .paced {
                        Button("return to natural breathing") { coordinator.setMode(.natural) }
                            .font(.subheadline).frame(minHeight: 44)
                            .accessibilityIdentifier("return-natural")
                    } else {
                        Text("natural breathing").font(.caption).foregroundStyle(FlowStyle.muted)
                    }
                }

                if let notice = engine.interruptionReason ?? coordinator.notice {
                    Text(notice).font(.subheadline).lineSpacing(4)
                        .padding(18).frame(maxWidth: .infinity, alignment: .leading)
                        .background(FlowStyle.surface, in: RoundedRectangle(cornerRadius: 16))
                        .accessibilityIdentifier("recovery-message")
                }
                Toggle(isOn: Binding(get: { coordinator.preferences.sound }, set: { coordinator.setSound($0) })) {
                    Label("sound", systemImage: coordinator.preferences.sound ? "speaker.wave.2" : "speaker.slash")
                }.accessibilityIdentifier("player-sound")
                    .padding(.horizontal, 10).padding(.bottom, 10)
            }.padding(.horizontal, 28).padding(.bottom, 16)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 6) {
                Button(engine.state == .introduction ? (typeSize.isAccessibilitySize ? "begin" : "begin breathing") : engine.isPaused ? "resume" : "pause") {
                    if engine.state == .running { coordinator.pause() }
                    else { coordinator.resume() }
                }.buttonStyle(FlowPrimaryButton())
                    .accessibilityIdentifier("player-primary")
                Button("stop session") { coordinator.stop() }
                    .font(.body).foregroundStyle(FlowStyle.ink)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .accessibilityHint("ends this session without adding a completion")
                    .accessibilityIdentifier("stop-session")
            }.padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 4)
                .background(FlowStyle.canvas)
        }
    }

    private var cueTitle: String {
        if engine.isPaused { return "paused" }
        guard let phase = engine.phase else { return "your own rhythm." }
        return phase.kind == .inhale ? "breathe in" : "breathe out"
    }

    private var finish: some View {
        ScrollView {
            VStack(spacing: 28) {
                Text("flow").font(.system(.title2, design: .serif)).padding(.top, 30)
                if !typeSize.isAccessibilitySize {
                    BreathingVisual(phase: nil, running: true, reduceMotion: true).frame(height: 260)
                }
                VStack(spacing: 14) {
                    Text(engine.state == .completed ? "session finished" : "session stopped")
                        .font(.system(.largeTitle, design: .serif))
                        .accessibilityIdentifier("finish-title")
                    Text("\(timeText(engine.elapsed)) of active time")
                        .font(.subheadline).foregroundStyle(FlowStyle.accent)
                    Text(Guidance.ending).font(.body).lineSpacing(5)
                        .padding(.top, 12)
                    if engine.state == .stopped {
                        Text("you can stop at any time. this session was not added to your history.")
                            .font(.footnote).foregroundStyle(FlowStyle.muted).padding(.top, 8)
                    }
                }.multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }.padding(28)
        }
        .safeAreaInset(edge: .bottom) {
            Button("done") { dismiss() }
                .buttonStyle(FlowPrimaryButton()).accessibilityIdentifier("finish-done")
                .padding(24).background(FlowStyle.canvas)
        }
    }
}

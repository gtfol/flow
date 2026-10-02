import SwiftUI

struct PlayerView: View {
    @Bindable var coordinator: SessionCoordinator
    var reduceMotionOverride: Bool? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var revealedAt: TimeInterval = 0
    @State private var lingering = true
    private var engine: SessionEngine { coordinator.engine }
    private var motionReduced: Bool { reduceMotionOverride ?? reduceMotion }
    private var recentlyRevealed: Bool { engine.elapsed - revealedAt < 14 }
    private var controlsVisible: Bool { voiceOver || recentlyRevealed || engine.state != .running || engine.segment.stage == .returning }
    private var timerVisible: Bool { controlsVisible || engine.elapsed < 25 }
    private var textVisible: Bool { controlsVisible || engine.elapsed < 40 || (motionReduced && engine.phase != nil) }
    private var visualOpacity: Double {
        guard engine.state == .running else { return 0.6 }
        if engine.definition.practice == .silence { return max(0, 1 - engine.elapsed / 18) }
        switch engine.segment.stage {
        case .open: return max(0, 1 - (engine.elapsed - engine.segment.start) / 12)
        case .returning: return min(0.75, (engine.elapsed - engine.segment.start) / 8)
        default: return 1
        }
    }
    var body: some View {
        Group {
            if engine.isTerminal { finish }
            else { player }
        }.flowScreen()
            .onAppear { coordinator.start(); updateAwake() }
            .onDisappear { UIApplication.shared.isIdleTimerDisabled = false; coordinator.cancel() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { coordinator.appBecameActive() }
                updateAwake()
            }
            .onChange(of: engine.state) { _, _ in revealedAt = engine.elapsed; updateAwake() }
            .onChange(of: engine.segment.stage) { _, _ in updateAwake() }
            .interactiveDismissDisabled()
    }
    private var player: some View {
        ZStack {
            FlowStyle.canvas.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 22) {
                    Text(engine.definition.title).font(.subheadline).foregroundStyle(FlowStyle.muted)
                        .opacity(textVisible ? 1 : 0).accessibilityHidden(!textVisible)
                        .animation(motionReduced ? nil : .easeInOut(duration: 2), value: textVisible)
                    Text(cueTitle).font(.system(.largeTitle, design: .serif))
                        .multilineTextAlignment(.center).accessibilityIdentifier("current-cue")
                        .opacity(textVisible ? 1 : 0).accessibilityHidden(!textVisible)
                        .animation(motionReduced ? nil : .easeInOut(duration: 2), value: textVisible)
                    if engine.state == .preparing {
                        ProgressView().tint(FlowStyle.accent).padding(40)
                        Text("making a little space…").foregroundStyle(FlowStyle.muted)
                    } else {
                        if !typeSize.isAccessibilitySize {
                            BreathingVisual(phase: engine.phase, running: engine.state == .running, reduceMotion: motionReduced)
                                .frame(height: 260).opacity(visualOpacity)
                                .blur(radius: engine.segment.stage == .expand && !motionReduced ? 4 : 0)
                        }
                        Text(timeText(engine.remaining, roundUp: true)).font(.system(.title2, design: .rounded).monospacedDigit())
                            .foregroundStyle(FlowStyle.muted).accessibilityIdentifier("session-remaining")
                            .accessibilityLabel("\(Int(ceil(engine.remaining))) seconds remaining")
                            .opacity(timerVisible ? 1 : 0).accessibilityHidden(!timerVisible)
                            .animation(motionReduced ? nil : .easeInOut(duration: 2), value: timerVisible)
                        if let caption, textVisible {
                            Text(caption).font(.body).lineSpacing(5).multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("guidance-caption")
                            if engine.definition.practice != .silence {
                                Text(Guidance.introductionTitle).font(.caption2).foregroundStyle(FlowStyle.muted)
                            }
                        }
                        if engine.elapsed < 12 {
                            Text("the screen will fade. tap to bring it back.").font(.footnote)
                                .foregroundStyle(FlowStyle.muted).multilineTextAlignment(.center)
                        }
                    }
                    if let notice = engine.interruptionReason ?? coordinator.notice {
                        Text(notice).font(.subheadline).padding(18).frame(maxWidth: .infinity)
                            .background(FlowStyle.surface, in: RoundedRectangle(cornerRadius: 16))
                            .accessibilityIdentifier("recovery-message")
                    }
                }.padding(.horizontal, 28).padding(.top, 36).padding(.bottom, 24)
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                if engine.state != .preparing {
                    if engine.mode == .paced && engine.segment.stage == .settle {
                        Button { coordinator.useNaturalBreathing(); reveal(); updateAwake() } label: {
                            Text("return to natural breathing").font(.subheadline)
                                .frame(maxWidth: .infinity, minHeight: 44).contentShape(Rectangle())
                        }.buttonStyle(.plain).accessibilityIdentifier("return-natural").accessibilityHidden(!controlsVisible)
                    }
                    Button { coordinator.setMuted(!coordinator.muted); reveal() } label: {
                        Text(coordinator.muted ? "unmute audio" : "mute audio").font(.subheadline)
                            .frame(maxWidth: .infinity, minHeight: 44).contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityIdentifier("player-mute").accessibilityHidden(!controlsVisible)
                    Button(engine.isPaused ? "resume" : "pause") {
                        if engine.isPaused { coordinator.resume() } else { coordinator.pause() }
                        reveal()
                    }.buttonStyle(FlowPrimaryButton()).accessibilityIdentifier("player-primary").accessibilityHidden(!controlsVisible)
                }
                Button { coordinator.stop() } label: {
                    Text("end session").frame(maxWidth: .infinity, minHeight: 48).contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityIdentifier("stop-session").accessibilityHidden(!controlsVisible)
            }.padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 4)
                .background(FlowStyle.canvas).opacity(controlsVisible ? 1 : 0)
                .allowsHitTesting(controlsVisible)
                .accessibilityElement(children: .contain)
                .animation(motionReduced ? nil : .easeInOut(duration: 2), value: controlsVisible)
        }
        .contentShape(Rectangle())
        .simultaneousGesture(TapGesture().onEnded { reveal() })

    }
    private var caption: String? {
        if engine.isPaused { return "take all the time you need." }
        if engine.definition.practice == .silence { return "a bell will mark the end. rest here." }
        return engine.definition.narration.last(where: { $0.time <= engine.elapsed && engine.elapsed < $0.time + 30 })?.text
    }
    private var cueTitle: String {
        if engine.isPaused { return "paused" }
        if engine.state == .preparing { return "settle in." }
        if let phase = engine.phase { return phase.kind == .inhale ? "breathe in" : "breathe out" }
        return engine.segment.stage.title
    }
    private func reveal() { revealedAt = engine.elapsed }
    private func updateAwake() {
        UIApplication.shared.isIdleTimerDisabled = scenePhase == .active && engine.state == .running && engine.phase != nil
    }
    private var finish: some View {
        VStack(spacing: 24) {
            Spacer()
            if engine.state == .completed && lingering {
                Text("take a moment.").font(.system(.title, design: .serif)).foregroundStyle(FlowStyle.muted)
            } else {
                Text(engine.state == .completed ? "sit complete." : "session stopped")
                    .font(.system(.largeTitle, design: .serif)).accessibilityIdentifier("finish-title")
                Text(timeText(engine.elapsed)).font(.title3.monospacedDigit()).foregroundStyle(FlowStyle.muted)
                Text(Guidance.ending).font(.subheadline).foregroundStyle(FlowStyle.muted)
            }
            Spacer()
            Button("done") { dismiss() }.buttonStyle(FlowPrimaryButton()).accessibilityIdentifier("finish-done")
        }.multilineTextAlignment(.center).padding(28)
            .task {
                guard engine.state == .completed else { lingering = false; return }
                do { try await Task.sleep(for: .seconds(15)) } catch { return }
                lingering = false
            }
    }
}

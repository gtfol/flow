import SwiftUI

struct SetupView: View {
    let definition: SessionDefinition
    @Bindable var store: SessionStore
    @State private var mode: BreathingMode = .natural
    @State private var showingSafety = false
    @State private var startAfterSafety = false
    @State private var playerSession: PlayerSession?

    private struct PlayerSession: Identifiable {
        let coordinator: SessionCoordinator
        var id: UUID { coordinator.engine.runID }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 9) {
                    Text("\(Int(definition.duration / 60)) minutes · your own rhythm").font(.subheadline)
                    Text(definition.title).font(.system(.largeTitle, design: .serif))
                }.fixedSize(horizontal: false, vertical: true)
                    .padding(24).frame(maxWidth: .infinity, minHeight: 220, alignment: .bottomLeading)
                    .background(Atmosphere(warm: definition.id == "small-pause"))
                    .clipShape(RoundedRectangle(cornerRadius: 22))

                Text("settle in. let it be easy.").font(.system(.title2, design: .serif))
                VStack(alignment: .leading, spacing: 12) {
                    Text("breathing").font(.headline.weight(.regular))
                    ForEach(BreathingMode.allCases) { option in
                        Button { mode = option } label: {
                            HStack(alignment: .top, spacing: 14) {
                                Image(systemName: mode == option ? "largecircle.fill.circle" : "circle")
                                    .foregroundStyle(mode == option ? FlowStyle.accent : FlowStyle.muted)
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(option.title).foregroundStyle(FlowStyle.ink)
                                    Text(option == .natural ? "no timing to follow. breathe as you are."
                                         : "an optional visual cue: 4 seconds in, 4 out. no holds. follow while it feels comfortable.")
                                        .font(.subheadline).foregroundStyle(FlowStyle.muted)
                                }.fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 0)
                            }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
                                .background(FlowStyle.surface, in: RoundedRectangle(cornerRadius: 18))
                                .overlay(RoundedRectangle(cornerRadius: 18).stroke(mode == option ? FlowStyle.accent.opacity(0.5) : FlowStyle.line))
                        }.buttonStyle(.plain)
                            .accessibilityAddTraits(mode == option ? .isSelected : [])
                            .accessibilityIdentifier("mode-\(option.rawValue)")
                    }
                }
                VStack(spacing: 18) {
                    Toggle("ambient sound & phase tones", isOn: $store.preferences.sound)
                    Toggle("spoken introduction", isOn: $store.preferences.spokenIntroduction)
                }.font(.body)
                Button { startAfterSafety = false; showingSafety = true } label: {
                    Label("before you begin · safety notes", systemImage: "info.circle")
                        .font(.subheadline).frame(minHeight: 44)
                }.accessibilityIdentifier("safety-notes")
            }.padding(24)
        }
        .navigationTitle("your session").navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button("start session") {
                if store.preferences.hasReadSafety { startPlayer() }
                else { startAfterSafety = true; showingSafety = true }
            }.buttonStyle(FlowPrimaryButton()).accessibilityIdentifier("start-session")
                .padding(.horizontal, 24).padding(.vertical, 12)
                .background(FlowStyle.canvas)
        }
        .flowScreen()
        .sheet(isPresented: $showingSafety, onDismiss: safetyDismissed) {
            SafetyView {
                store.preferences.hasReadSafety = true
                showingSafety = false
            }
        }
        .fullScreenCover(item: $playerSession) { session in
            PlayerView(coordinator: session.coordinator)
        }
    }

    private func safetyDismissed() {
        let shouldStart = startAfterSafety && store.preferences.hasReadSafety
        startAfterSafety = false
        // Present only after the safety sheet has finished dismissing.
        if shouldStart { startPlayer() }
    }

    private func startPlayer() {
        let engine = SessionEngine(definition: definition, mode: mode, clock: ContinuousTimeSource())
        let value = SessionCoordinator(engine: engine, audio: AudioController(), store: store)
        value.onHaptic = {
            guard UIApplication.shared.applicationState == .active else { return }
            UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.35)
        }
        // The same value supplies the player and drives its presentation.
        playerSession = PlayerSession(coordinator: value)
    }
}

struct SafetyView: View {
    var acknowledge: (() -> Void)?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Image(systemName: "hand.raised").font(.largeTitle.weight(.ultraLight))
                        .foregroundStyle(FlowStyle.accent).accessibilityHidden(true)
                    Text("comfort comes first.").font(.system(.largeTitle, design: .serif))
                    Text(Guidance.safety).font(.body).lineSpacing(6)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("flow is a general wellness tool, not treatment or an assessment. these precautions do not mean breathing exercises suit everyone.")
                        .font(.footnote).foregroundStyle(FlowStyle.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }.padding(24)
            }
            .navigationTitle("before you begin").navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                Button(acknowledge == nil ? "done" : "i’ve read this") {
                    if let acknowledge { acknowledge() } else { dismiss() }
                }.buttonStyle(FlowPrimaryButton()).accessibilityIdentifier("acknowledge-safety")
                    .padding(24).background(FlowStyle.canvas)
            }.flowScreen()
        }
    }
}

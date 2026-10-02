import SwiftUI

struct HomeView: View {
    @Bindable var store: SessionStore
    @State private var showingSettings = false
    @State private var showingSetup = false
    @State private var showingSafety = false
    @State private var pendingStart = false
    @State private var playerSession: PlayerSession?
    @Environment(\.dynamicTypeSize) private var typeSize
    private struct PlayerSession: Identifiable {
        let coordinator: SessionCoordinator
        var id: UUID { coordinator.engine.runID }
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    HStack {
                        Text("flow").font(.system(.largeTitle, design: .serif)).tracking(-1.8)
                        Spacer()
                        Button { showingSettings = true } label: {
                            Image(systemName: "slider.horizontal.3").frame(width: 48, height: 48)
                                .background(FlowStyle.surface, in: Circle())
                        }.accessibilityLabel("settings").accessibilityIdentifier("settings")
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("sit for a while.").font(.system(.largeTitle, design: .serif))
                        Text("a little room to be here.").font(.subheadline).foregroundStyle(FlowStyle.muted)
                    }
                    Button { showingSetup = true } label: {
                        VStack(spacing: 12) {
                            if !typeSize.isAccessibilitySize {
                                BreathingVisual(phase: nil, running: true, reduceMotion: true).frame(height: 175)
                            }
                            Text("\(store.preferences.minutes) min")
                                .font(.system(size: typeSize.isAccessibilitySize ? 42 : 56, weight: .light, design: .serif))
                            Text(store.preferences.practice.title).font(.title3)
                            Text(store.preferences.practice.detail).font(.subheadline).foregroundStyle(FlowStyle.muted)
                                .multilineTextAlignment(.center)
                        }.padding(24).frame(maxWidth: .infinity)
                            .background(FlowStyle.surface.opacity(0.65), in: RoundedRectangle(cornerRadius: 28))
                            .overlay(RoundedRectangle(cornerRadius: 28).stroke(FlowStyle.line, lineWidth: 0.5))
                    }.buttonStyle(.plain).accessibilityIdentifier("configure-session")
                        .accessibilityLabel("\(store.preferences.practice.title), \(store.preferences.minutes) minutes. configure practice")
                    VStack(spacing: 0) {
                        setupRow("practice", store.preferences.practice.title)
                        Divider().overlay(FlowStyle.line)
                        setupRow("duration", "\(store.preferences.minutes) minutes")
                        Divider().overlay(FlowStyle.line)
                        setupRow("guidance", store.preferences.practice == .silence ? "silent" : store.preferences.guidance.title)
                    }
                }.padding(24)
            }
            .safeAreaInset(edge: .bottom) {
                Button("begin") {
                    if store.preferences.hasReadSafety { startPlayer() }
                    else { pendingStart = true; showingSafety = true }
                }.buttonStyle(FlowPrimaryButton()).accessibilityIdentifier("start-session")
                    .padding(.horizontal, 24).padding(.vertical, 12).background(FlowStyle.canvas)
            }
            .toolbar(.hidden, for: .navigationBar).flowScreen()
            .sheet(isPresented: $showingSetup) { SetupView(store: store) }
            .sheet(isPresented: $showingSettings) { SettingsView(store: store) }
            .sheet(isPresented: $showingSafety, onDismiss: {
                let start = pendingStart && store.preferences.hasReadSafety
                pendingStart = false
                if start { startPlayer() }
            }) {
                SafetyView { store.preferences.hasReadSafety = true; showingSafety = false }
            }
            .fullScreenCover(item: $playerSession) { PlayerView(coordinator: $0.coordinator) }
        }
    }
    private func setupRow(_ label: String, _ value: String) -> some View {
        Button { showingSetup = true } label: {
            HStack(alignment: .firstTextBaseline) {
                Text(label).foregroundStyle(FlowStyle.muted)
                Spacer(minLength: 20)
                Text(value).multilineTextAlignment(.trailing)
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(FlowStyle.muted)
            }.font(.subheadline).padding(.vertical, 15).frame(minHeight: 48)
        }.buttonStyle(.plain).accessibilityIdentifier("configure-\(label)")
    }
    private func startPlayer() {
        let p = store.preferences.normalized()
        guard let definition = try? SessionDefinition(practice: p.practice, minutes: p.minutes, guidance: p.guidance, breathing: p.breathing) else { return }
        let engine = SessionEngine(definition: definition, clock: ContinuousTimeSource())
        let coordinator = SessionCoordinator(engine: engine, audio: AudioController(), store: store)
        coordinator.onHaptic = {
            guard UIApplication.shared.applicationState == .active else { return }
            UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.35)
        }
        playerSession = PlayerSession(coordinator: coordinator)
    }
}

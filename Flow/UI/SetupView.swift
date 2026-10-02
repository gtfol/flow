import SwiftUI

struct SetupView: View {
    @Bindable var store: SessionStore
    @Environment(\.dismiss) private var dismiss
    @State private var showingSafety = false
    var body: some View {
        NavigationStack {
            Form {
                Section("practice") {
                    ForEach(Practice.allCases) { practice in
                        Button { store.preferences.practice = practice } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(practice.title).foregroundStyle(FlowStyle.ink)
                                    Text(practice.detail).font(.footnote).foregroundStyle(FlowStyle.muted)
                                }
                                Spacer()
                                if practice == store.preferences.practice { Image(systemName: "checkmark").foregroundStyle(FlowStyle.accent) }
                            }.padding(.vertical, 5)
                        }.accessibilityIdentifier("practice-\(practice.rawValue)")
                            .accessibilityAddTraits(practice == store.preferences.practice ? .isSelected : [])
                    }
                }
                Section("duration") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 85))], spacing: 12) {
                        ForEach(SessionDefinition.minuteOptions, id: \.self) { minutes in
                            Button("\(minutes) min") { store.preferences.minutes = minutes }
                                .font(.body.monospacedDigit()).frame(maxWidth: .infinity, minHeight: 48)
                                .background(store.preferences.minutes == minutes ? FlowStyle.accent : FlowStyle.surface, in: Capsule())
                                .foregroundStyle(store.preferences.minutes == minutes ? FlowStyle.canvas : FlowStyle.ink)
                                .buttonStyle(.plain).accessibilityIdentifier("duration-\(minutes)")
                                .accessibilityAddTraits(store.preferences.minutes == minutes ? .isSelected : [])
                        }
                    }.padding(.vertical, 8)
                }
                if store.preferences.practice != .silence {
                    Section {
                        Picker("guidance", selection: $store.preferences.guidance) {
                            ForEach(GuidanceLevel.allCases) { Text($0.title).tag($0) }
                        }.accessibilityIdentifier("guidance-picker")
                        Text(guidanceDescription).font(.footnote).foregroundStyle(FlowStyle.muted)
                        Picker("breathing", selection: $store.preferences.breathing) {
                            ForEach(BreathingMode.allCases) { Text($0.title).tag($0) }
                        }.accessibilityIdentifier("breathing-picker")
                        Toggle("ambient sound", isOn: $store.preferences.sound)
                        Toggle("breathing haptics", isOn: $store.preferences.haptics)
                    } header: { Text("your rhythm") } footer: {
                        Text("pacing is optional and only happens while settling. follow your own comfort. haptics work while the app is on screen; recordings and bells continue with the phone locked.")
                    }
                }
                Section {
                    Text("the screen gradually settles into darkness. tap anywhere to bring back the controls. pause or end whenever you need.")
                        .font(.subheadline).foregroundStyle(FlowStyle.muted)
                    Text("a soft bell opens and closes your practice. longer sessions leave more room for silence.")
                        .font(.subheadline).foregroundStyle(FlowStyle.muted)
                    Button("safety notes") { showingSafety = true }.accessibilityIdentifier("safety-notes")
                }
            }.scrollContentBackground(.hidden).flowScreen()
                .navigationTitle("your practice").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("done") { dismiss() }.accessibilityIdentifier("setup-done") } }
                .sheet(isPresented: $showingSafety) { SafetyView() }
        }
    }
    private var guidanceDescription: String {
        switch store.preferences.guidance {
        case .full: "more frequent reminders, with quiet space between."
        case .minimal: "a few spoken invitations, then long stretches of silence."
        case .silent: "an opening instruction, then no further spoken cues."
        }
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

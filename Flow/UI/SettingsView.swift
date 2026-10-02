import SwiftUI

struct SettingsView: View {
    @Bindable var store: SessionStore
    @Environment(\.dismiss) private var dismiss
    @State private var showingSafety = false
    @State private var confirmingDelete = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("ambient sound", isOn: $store.preferences.sound)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ambient volume")
                        Slider(value: $store.preferences.ambientVolume, in: 0...1)
                            .accessibilityLabel("ambient volume")
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("bell volume")
                        Slider(value: $store.preferences.cueVolume, in: 0...1)
                            .accessibilityLabel("bell volume")
                    }
                    Toggle("gentle haptics", isOn: $store.preferences.haptics)
                } header: { Text("make it yours") }
                footer: {
                    Text("guidance and bells play offline, including with the screen locked. haptics accompany gentle pacing while the app is on screen and depend on your device.")
                }

                Section {
                    if store.history.isEmpty {
                        Text("no completed sessions stored.").foregroundStyle(FlowStyle.muted)
                    } else {
                        DisclosureGroup("completed sessions (\(store.history.count))") {
                            ForEach(store.history.reversed()) { record in
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(Practice(rawValue: record.sessionID)?.title ?? (record.sessionID == "small-pause" ? "a small pause" : "a quiet five"))
                                    Text("\(record.completedAt.formatted(date: .abbreviated, time: .shortened)) · \(timeText(record.activeDuration))")
                                        .font(.footnote).foregroundStyle(FlowStyle.muted)
                                }.padding(.vertical, 4)
                            }
                        }
                    }
                    Button("delete local history", role: .destructive) { confirmingDelete = true }
                        .disabled(store.history.isEmpty)
                } header: { Text("on this device") }
                footer: {
                    Text("only preferences and completed-session details are saved. no account, analytics, diary, or cloud sync. your operating system may include app data in a device backup.")
                }

                Section {
                    Button("safety notes") { showingSafety = true }
                    NavigationLink("source notes") { SourceNotesView() }
                } footer: {
                    Text("flow · a personal space to breathe\noriginal sound, available offline.")
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("settings").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("done") { dismiss() } } }
            .flowScreen()
            .sheet(isPresented: $showingSafety) { SafetyView() }
            .confirmationDialog("delete all local completion history?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("delete history", role: .destructive) { store.deleteHistory() }
                Button("cancel", role: .cancel) {}
            } message: { Text("this cannot be undone. your preferences and bundled sessions stay available.") }
        }
    }
}

struct SourceNotesView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("a few notes on flow.").font(.system(.largeTitle, design: .serif))
                note("the experience", "Othership’s public app experience informed the atmosphere and focus on sound. flow’s interface, vector artwork, session names, guidance, and synthesized audio are original. no Othership recordings or subscription content are included.")
                note("the breathing", "NHS guidance supports gentle, comfortable breathing without forcing and optional counting. flow’s 5-second in / 5-second out cue is a product choice, not an NHS protocol or a clinical recommendation. natural breathing is the default.")
                note("the sound", "the ambient bed and soft bell were synthesized locally. original guidance uses Brian’s AI-generated voice from ElevenLabs. all recordings play offline.")
                note(Guidance.introductionTitle, "original words, voiced with Brian from elevenlabs.io. shared for noncommercial use with attribution.")
                note("the boundaries", "flow is for general wellness. it offers no diagnosis, treatment, breath tests, breath holds, or intense breathing routines. follow your comfort, and stop whenever you want.")
                VStack(alignment: .leading, spacing: 12) {
                    Text("references · internet needed to open").font(.footnote).foregroundStyle(FlowStyle.muted)
                    Link("NHS · gentle breathing", destination: URL(string: "https://www.nhs.uk/mental-health/self-help/guides-tools-and-activities/breathing-exercises-for-stress/")!)
                    Link("Cleveland Clinic · hyperventilation", destination: URL(string: "https://my.clevelandclinic.org/health/diseases/hyperventilation")!)
                    Link("Othership · public app reference", destination: URL(string: "https://www.othership.us/app")!)
                }.font(.subheadline)
            }.padding(24)
        }.navigationTitle("source notes").navigationBarTitleDisplayMode(.inline).flowScreen()
    }

    private func note(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline.weight(.regular))
            Text(body).font(.body).foregroundStyle(FlowStyle.muted).lineSpacing(4)
        }.fixedSize(horizontal: false, vertical: true)
    }
}

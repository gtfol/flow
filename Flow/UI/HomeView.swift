import SwiftUI

struct HomeView: View {
    let sessions: [SessionDefinition]
    @Bindable var store: SessionStore
    @State private var showingSettings = false
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("flow").font(.system(.largeTitle, design: .serif)).tracking(-1.8)
                            .accessibilityAddTraits(.isHeader)
                        Spacer()
                        Button { showingSettings = true } label: {
                            Image(systemName: "slider.horizontal.3").font(.system(size: 20))
                                .frame(width: 48, height: 48)
                                .background(FlowStyle.surface, in: Circle())
                        }.accessibilityLabel("settings").accessibilityIdentifier("settings")
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("come back\nto this moment.")
                            .font(.system(.largeTitle, design: .serif)).tracking(-0.5)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("a little space for your own rhythm.")
                            .font(.subheadline).foregroundStyle(FlowStyle.muted)
                    }.padding(.vertical, 8)

                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("make room").font(.subheadline)
                            Spacer()
                            Text("2 gentle sessions").font(.caption).foregroundStyle(FlowStyle.muted)
                        }.accessibilityElement(children: .combine)
                        ForEach(Array(sessions.enumerated()), id: \.element.id) { index, session in
                            NavigationLink {
                                SetupView(definition: session, store: store)
                            } label: { sessionCard(session, warm: index == 0) }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier(session.id)
                            .accessibilityLabel("\(session.title), \(Int(session.duration / 60)) minutes. \(session.detail) set up session")
                        }
                    }
                }.padding(.horizontal, 24).padding(.top, 8).padding(.bottom, 30)
            }
            .toolbar(.hidden, for: .navigationBar)
            .flowScreen()
            .sheet(isPresented: $showingSettings) { SettingsView(store: store) }
        }
    }

    private func sessionCard(_ session: SessionDefinition, warm: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("\(Int(session.duration / 60)) min").font(.subheadline.monospacedDigit())
                    .padding(.horizontal, 13).padding(.vertical, 8)
                    .background(.black.opacity(0.35), in: Capsule())
                Spacer()
                Image(systemName: "arrow.up.right").font(.system(size: 18))
                    .frame(width: 44, height: 44)
                    .background(.black.opacity(0.25), in: Circle())
            }.padding(20)
            Spacer(minLength: typeSize.isAccessibilitySize ? 28 : 36)
            VStack(alignment: .leading, spacing: 7) {
                Text(session.title).font(.system(.title2, design: .serif))
                Text(session.detail).font(.subheadline).foregroundStyle(FlowStyle.ink.opacity(0.84))
                    .fixedSize(horizontal: false, vertical: true)
            }.frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(LinearGradient(colors: [.clear, .black.opacity(0.72)], startPoint: .top, endPoint: .bottom))
        }
        .frame(minHeight: 206)
        .background(Atmosphere(warm: warm))
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(FlowStyle.line, lineWidth: 0.6))
    }
}

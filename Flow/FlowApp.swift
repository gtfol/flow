import SwiftUI

@main struct FlowApp: App {
    @State private var store = SessionStore()
    private let catalog: Result<[SessionDefinition], Error>

    init() {
        catalog = Result {
            guard let url = Bundle.main.url(forResource: "sessions", withExtension: "json") else {
                throw SessionDefinition.ValidationError.unsupportedDefinition
            }
            return try SessionDefinition.load(data: Data(contentsOf: url))
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                switch catalog {
                case .success(let sessions): HomeView(sessions: sessions, store: store)
                case .failure:
                    ContentUnavailableView("sessions unavailable", systemImage: "waveform.path",
                                           description: Text("the bundled sessions could not be validated. reinstall flow from a verified build."))
                }
            }.flowScreen()
        }
    }
}

import SwiftUI

@main struct FlowApp: App {
    @State private var store = SessionStore()
    var body: some Scene {
        WindowGroup { HomeView(store: store).flowScreen() }
    }
}

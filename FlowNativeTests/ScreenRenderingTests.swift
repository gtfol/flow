import XCTest
import SwiftUI
@testable import Flow

@MainActor private final class SnapshotClock: MonotonicTimeSource { var now: TimeInterval = 0 }
@MainActor private final class SnapshotAudio: SessionAudio {
    var onInterruption: ((String) -> Void)?
    func startAmbient(preferences: Preferences) throws {}
    func cue(_ kind: SessionDefinition.Phase.Kind, volume: Float) throws {}
    func setVolumes(ambient: Float, cue: Float) {}
    func stopSound() {}
    func stopAll() {}
    func playIntroduction() throws -> String? { nil }
}

/// Actual compiled SwiftUI views in a simulator UIWindow. These are deterministic
/// rendering checks, not a claim that the manual end-to-end walkthrough passed.
@MainActor final class ScreenRenderingTests: XCTestCase {
    func testRenderScreensAtNormalAndLargestTextWithReducedMotion() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let originalWindow = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        window.frame = scene.coordinateSpace.bounds
        window.overrideUserInterfaceStyle = .dark
        let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ScreenChecks", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let data = try Data(contentsOf: XCTUnwrap(Bundle.main.url(forResource: "sessions", withExtension: "json")))
        let definitions = try SessionDefinition.load(data: data)
        let definition = try XCTUnwrap(definitions.first)
        let storage = SessionStore(defaults: UserDefaults(suiteName: "flow.screens.\(UUID().uuidString)")!)
        storage.preferences.sound = false

        func coordinator(_ mode: BreathingMode, state: SessionState) -> SessionCoordinator {
            let clock = SnapshotClock()
            let engine = SessionEngine(definition: definition, mode: mode, clock: clock)
            let coordinator = SessionCoordinator(engine: engine, audio: SnapshotAudio(), store: storage)
            coordinator.start()
            if state != .introduction {
                coordinator.resume(automaticallyRefresh: false)
                clock.now = state == .completed ? 120 : 22
                coordinator.tick()
                if state == .paused { coordinator.pause() }
            }
            return coordinator
        }

        for (large, reduced) in [(false, false), (true, true), (false, true)] {
            let screens: [(String, AnyView)] = [
                ("home", AnyView(HomeView(sessions: definitions, store: storage))),
                ("setup", AnyView(NavigationStack { SetupView(definition: definition, store: storage) })),
                ("safety", AnyView(SafetyView(acknowledge: {}))),
                ("introduction", AnyView(PlayerView(coordinator: coordinator(.natural, state: .introduction), reduceMotionOverride: reduced))),
                ("natural", AnyView(PlayerView(coordinator: coordinator(.natural, state: .running), reduceMotionOverride: reduced))),
                ("paced", AnyView(PlayerView(coordinator: coordinator(.paced, state: .running), reduceMotionOverride: reduced))),
                ("paused", AnyView(PlayerView(coordinator: coordinator(.paced, state: .paused), reduceMotionOverride: reduced))),
                ("finish", AnyView(PlayerView(coordinator: coordinator(.natural, state: .completed), reduceMotionOverride: reduced))),
                ("settings", AnyView(SettingsView(store: storage)))
            ]
            for (name, screen) in screens {
                if !large && reduced && name != "paced" { continue }
                let view = screen.flowScreen()
                    .environment(\.dynamicTypeSize, large ? .accessibility5 : .large)
                let controller = UIHostingController(rootView: view)
                window.rootViewController = controller
                window.makeKeyAndVisible()
                controller.view.setNeedsLayout()
                controller.view.layoutIfNeeded()
                try await Task.sleep(for: .milliseconds(350))
                let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
                var rendered = false
                let image = renderer.image { _ in
                    rendered = window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
                }
                XCTAssertTrue(rendered, "\(name) did not render")
                let suffix = large ? "accessibility5-reduce-motion" : reduced ? "reduce-motion" : "standard"
                let filename = "\(name)-\(suffix).png"
                try XCTUnwrap(image.pngData()).write(to: folder.appendingPathComponent(filename))
                let attachment = XCTAttachment(image: image)
                attachment.name = filename
                attachment.lifetime = .keepAlways
                add(attachment)
            }
        }
        window.isHidden = true
        window.rootViewController = nil
        originalWindow?.makeKeyAndVisible()
    }
}

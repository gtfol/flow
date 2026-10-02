import XCTest
import SwiftUI
@testable import Flow

@MainActor private final class SnapshotClock: MonotonicTimeSource { var now: TimeInterval = 0 }
@MainActor private final class SnapshotAudio: SessionAudio {
    var onInterruption: ((String) -> Void)?
    var onFinish: (() -> Void)?
    var onRemotePause: (() -> Void)?
    var onRemoteResume: (() -> Void)?
    var onRemoteStop: (() -> Void)?
    func prepare(definition: SessionDefinition, preferences: Preferences) async throws {}
    func play(from time: TimeInterval) throws {}
    func pause() {}
    func setMuted(_ muted: Bool) {}
    func stopAll() {}
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
        let storage = SessionStore(defaults: UserDefaults(suiteName: "flow.screens.\(UUID().uuidString)")!)
        storage.preferences.sound = false

        func coordinator(_ mode: BreathingMode, time: Double, state: SessionState = .running, practice: Practice = .openAwareness) -> SessionCoordinator {
            let clock = SnapshotClock()
            let engine = SessionEngine(definition: try! SessionDefinition(practice: practice, minutes: 2, breathing: mode), clock: clock)
            let coordinator = SessionCoordinator(engine: engine, audio: SnapshotAudio(), store: storage)
            engine.prepare(); engine.beginRunning()
            clock.now = time; engine.refresh()
            if state == .paused { engine.pause() }
            return coordinator
        }

        for (large, reduced) in [(false, false), (true, true), (false, true)] {
            let screens: [(String, AnyView)] = [
                ("home", AnyView(HomeView(store: storage))),
                ("setup", AnyView(SetupView(store: storage))),
                ("safety", AnyView(SafetyView(acknowledge: {}))),
                ("arrive", AnyView(PlayerView(coordinator: coordinator(.natural, time: 5), reduceMotionOverride: reduced))),
                ("natural", AnyView(PlayerView(coordinator: coordinator(.natural, time: 35), reduceMotionOverride: reduced))),
                ("paced", AnyView(PlayerView(coordinator: coordinator(.paced, time: 47), reduceMotionOverride: reduced))),
                ("open", AnyView(PlayerView(coordinator: coordinator(.natural, time: 101), reduceMotionOverride: reduced))),
                ("silence", AnyView(PlayerView(coordinator: coordinator(.natural, time: 25, practice: .silence), reduceMotionOverride: reduced))),
                ("paused", AnyView(PlayerView(coordinator: coordinator(.paced, time: 42, state: .paused), reduceMotionOverride: reduced))),
                ("finish", AnyView(PlayerView(coordinator: coordinator(.natural, time: 120), reduceMotionOverride: reduced))),
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

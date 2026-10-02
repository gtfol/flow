import XCTest
#if canImport(FlowCore)
@testable import FlowCore
#else
@testable import Flow
#endif

@MainActor final class FakeClock: MonotonicTimeSource { var now: TimeInterval = 0 }
@MainActor final class FakeAudio: SessionAudio {
    var onInterruption: ((String) -> Void)?
    var onFinish: (() -> Void)?
    var onRemotePause: (() -> Void)?
    var onRemoteResume: (() -> Void)?
    var onRemoteStop: (() -> Void)?
    var playing = false
    var prepared = 0
    var plays: [Double] = []
    var fail = false
    var muted = false
    enum Failure: Error { case failed }
    func prepare(definition: SessionDefinition, preferences: Preferences) async throws {
        if fail { throw Failure.failed }; prepared += 1
    }
    func play(from time: TimeInterval) throws {
        if fail { throw Failure.failed }; playing = true; plays.append(time)
    }
    func pause() { playing = false }
    func setMuted(_ muted: Bool) { self.muted = muted }
    func stopAll() { playing = false }
}

@MainActor final class FlowCoreTests: XCTestCase {
    private func store() -> SessionStore { SessionStore(defaults: UserDefaults(suiteName: "flow.tests.\(UUID())")!) }
    private func harness(practice: Practice = .openAwareness, minutes: Int = 2, breathing: BreathingMode = .paced) async throws -> (SessionCoordinator, FakeClock, FakeAudio, SessionStore) {
        let clock = FakeClock(), audio = FakeAudio(), storage = store()
        let definition = try SessionDefinition(practice: practice, minutes: minutes, breathing: breathing)
        let coordinator = SessionCoordinator(engine: SessionEngine(definition: definition, clock: clock), audio: audio, store: storage)
        await coordinator.prepareAndStart(automaticallyRefresh: false)
        return (coordinator, clock, audio, storage)
    }
    func testEveryPracticeDurationAndGuidanceHasContiguousValidSegments() async throws {
        for practice in Practice.allCases {
            for minutes in SessionDefinition.minuteOptions {
                for guidance in GuidanceLevel.allCases {
                    let d = try SessionDefinition(practice: practice, minutes: minutes, guidance: guidance, breathing: .paced)
                    XCTAssertEqual(d.segments.reduce(0) { $0 + $1.duration }, Double(minutes * 60), accuracy: 0.001)
                    var end = 0.0
                    for s in d.segments {
                        XCTAssertGreaterThan(s.duration, 0); XCTAssertEqual(s.start, end, accuracy: 0.001); end = s.end
                        XCTAssertEqual(d.segment(at: s.start).stage, s.stage)
                        XCTAssertEqual(d.segment(at: s.end - 0.001).stage, s.stage)
                    }
                    XCTAssertEqual(d.segment(at: d.duration).stage, d.segments.last?.stage)
                    for e in d.narration { XCTAssertGreaterThanOrEqual(e.time, 0); XCTAssertLessThan(e.time, d.duration) }
                    for pair in zip(d.narration, d.narration.dropFirst()) { XCTAssertGreaterThan(pair.1.time - pair.0.time, 15) }
                }
            }
        }
    }
    func testInvalidDurationsRejected() async {
        for value in [-1, 0, 1, 3, 31, 60, Int.max] { XCTAssertThrowsError(try SessionDefinition(minutes: value)) }
    }
    func testPureSilenceOverridesGuidanceAndPacing() async throws {
        let d = try SessionDefinition(practice: .silence, guidance: .full, breathing: .paced)
        XCTAssertEqual(d.guidance, .silent); XCTAssertEqual(d.breathing, .natural)
        XCTAssertTrue(d.narration.isEmpty); XCTAssertEqual(d.segments.count, 1)
        XCTAssertEqual(d.ambience(at: 5), 0)
    }
    func testSilentGuidanceOnlyHasOpeningAndFullAddsPrompts() async throws {
        let silent = try SessionDefinition(minutes: 30, guidance: .silent)
        XCTAssertEqual(silent.narration.map(\.clip), ["introduction"])
        let full = try SessionDefinition(minutes: 30, guidance: .full)
        let minimal = try SessionDefinition(minutes: 30, guidance: .minimal)
        XCTAssertGreaterThan(full.narration.count, minimal.narration.count)
        let open = try XCTUnwrap(full.segments.first(where: { $0.stage == .open }))
        XCTAssertFalse(full.narration.contains(where: { $0.time > open.start + open.duration * 0.4 && $0.time < open.end }))
        XCTAssertEqual(full.ambience(at: open.start + 11), 0)
        let short = try SessionDefinition(minutes: 10)
        XCTAssertGreaterThan(open.duration, short.segments.first(where: { $0.stage == .open })!.duration)
    }
    func testPacingOnlyExistsDuringSettleAndStopsAtExpand() async throws {
        let (c, clock, _, _) = try await harness()
        XCTAssertNil(c.engine.phase)
        clock.now = 35; c.tick()
        XCTAssertEqual(c.engine.phase?.kind, .inhale)
        clock.now = 39.999; c.tick(); XCTAssertEqual(c.engine.phase?.kind, .inhale)
        clock.now = 40; c.tick(); XCTAssertEqual(c.engine.phase?.kind, .exhale)
        clock.now = 45; c.tick(); XCTAssertEqual(c.engine.phase?.sequence, 2)
        clock.now = 59; c.tick(); XCTAssertNil(c.engine.phase)
        XCTAssertEqual(c.engine.segment.stage, .expand)
    }
    func testDelayedRefreshSkipsStaleHapticsAndDoesNotDrift() async throws {
        let (c, clock, _, _) = try await harness()
        clock.now = 47.5; c.tick()
        XCTAssertEqual(c.engine.elapsed, 47.5)
        XCTAssertEqual(c.engine.phase?.progress, 0.5)
        clock.now = 106; c.tick()
        XCTAssertEqual(c.engine.segment.stage, .returning)
        XCTAssertNil(c.engine.phase)
    }
    func testPauseAndResumePreserveExactTimelinePosition() async throws {
        let (c, clock, audio, _) = try await harness()
        clock.now = 42.5; c.pause()
        XCTAssertEqual(c.engine.elapsed, 42.5); XCTAssertFalse(audio.playing)
        clock.now = 1000; c.tick(); XCTAssertEqual(c.engine.elapsed, 42.5)
        c.resume(automaticallyRefresh: false)
        XCTAssertEqual(audio.plays, [0, 42.5])
        clock.now += 2.5; c.tick()
        XCTAssertEqual(c.engine.elapsed, 45); XCTAssertEqual(c.engine.phase?.kind, .inhale)
    }
    func testScreenLockAndForegroundRefreshDoNotPause() async throws {
        let (c, clock, audio, _) = try await harness()
        clock.now = 100; c.appBecameActive()
        XCTAssertEqual(c.engine.elapsed, 100); XCTAssertTrue(audio.playing)
        XCTAssertEqual(c.engine.state, .running)
    }
    func testInterruptionsRequireExplicitResume() async throws {
        let (c, clock, audio, _) = try await harness()
        clock.now = 9; audio.onInterruption?("headphones removed")
        XCTAssertEqual(c.engine.state, .interrupted); XCTAssertEqual(c.engine.elapsed, 9)
        clock.now = 2000; c.appBecameActive()
        XCTAssertEqual(c.engine.elapsed, 9); XCTAssertFalse(audio.playing)
        c.resume(automaticallyRefresh: false); XCTAssertTrue(audio.playing)
        XCTAssertEqual(audio.plays.last, 9)
    }
    func testAllDurationsCompleteOnceAndBellTailCanFinish() async throws {
        for minutes in SessionDefinition.minuteOptions {
            let (c, clock, audio, storage) = try await harness(minutes: minutes)
            clock.now = Double(minutes * 60) - 0.01; c.tick(); XCTAssertEqual(c.engine.state, .running)
            clock.now += 20; c.tick()
            XCTAssertEqual(c.engine.state, .completed); XCTAssertEqual(c.engine.elapsed, Double(minutes * 60))
            XCTAssertTrue(audio.playing, "coordinator must not cut off the closing bell")
            audio.onFinish?(); c.tick(); c.stop()
            XCTAssertEqual(storage.history.count, 1); XCTAssertFalse(audio.playing)
        }
    }
    func testBackgroundAudioCompletionRecordsWithoutUIRefresh() async throws {
        let (c, _, audio, storage) = try await harness()
        audio.onFinish?()
        XCTAssertEqual(c.engine.state, .completed); XCTAssertEqual(c.engine.elapsed, 120)
        XCTAssertEqual(storage.history.count, 1)
        audio.onFinish?(); XCTAssertEqual(storage.history.count, 1)
    }
    func testEarlyStopAndLateCallbackNeverRecordCompletion() async throws {
        let (c, clock, audio, storage) = try await harness()
        clock.now = 14; c.stop(); audio.onFinish?(); clock.now = 1000; c.tick()
        XCTAssertEqual(c.engine.state, .stopped); XCTAssertEqual(c.engine.elapsed, 14)
        XCTAssertTrue(storage.history.isEmpty); XCTAssertFalse(audio.playing)
    }
    func testAudioFailureDoesNotAdvanceSessionAndCanRetry() async throws {
        let clock = FakeClock(), audio = FakeAudio(), storage = store()
        audio.fail = true
        let c = SessionCoordinator(engine: SessionEngine(definition: try SessionDefinition(), clock: clock), audio: audio, store: storage)
        await c.prepareAndStart(automaticallyRefresh: false)
        XCTAssertEqual(c.engine.state, .interrupted); XCTAssertEqual(c.engine.elapsed, 0)
        audio.fail = false; c.resume(automaticallyRefresh: false)
        for _ in 0..<10 { await Task.yield() }
        XCTAssertEqual(c.engine.state, .running)
    }
    func testNaturalOverrideAndMuteAreIndependentOfTimer() async throws {
        let (c, clock, audio, _) = try await harness()
        clock.now = 38; c.tick(); XCTAssertNotNil(c.engine.phase)
        c.useNaturalBreathing(); XCTAssertNil(c.engine.phase)
        c.setMuted(true); XCTAssertTrue(audio.muted); XCTAssertEqual(c.engine.state, .running)
        clock.now = 50; c.tick(); XCTAssertEqual(c.engine.elapsed, 50)
        c.setMuted(false); XCTAssertFalse(audio.muted)
    }
    func testRemoteCommandsPauseResumeAndStop() async throws {
        let (c, clock, audio, storage) = try await harness()
        clock.now = 5; audio.onRemotePause?(); XCTAssertEqual(c.engine.state, .paused)
        audio.onRemoteResume?(); XCTAssertEqual(c.engine.state, .running)
        audio.onRemoteStop?(); XCTAssertEqual(c.engine.state, .stopped)
        XCTAssertTrue(storage.history.isEmpty)
    }
    func testLegacyPreferencesMigrateWithoutLosingHistoryOrSafety() async throws {
        let defaults = UserDefaults(suiteName: "flow.migrate.\(UUID())")!
        defaults.set(Data(#"{"sound":false,"spokenIntroduction":true,"haptics":true,"ambientVolume":0.2,"cueVolume":0.4,"hasReadSafety":true}"#.utf8), forKey: "flow.preferences.v1")
        let storage = SessionStore(defaults: defaults)
        XCTAssertFalse(storage.preferences.sound); XCTAssertTrue(storage.preferences.haptics)
        XCTAssertTrue(storage.preferences.hasReadSafety); XCTAssertEqual(storage.preferences.minutes, 10)
        storage.preferences.practice = .silence; storage.preferences.minutes = 30; storage.preferences.guidance = .full
        XCTAssertEqual(SessionStore(defaults: defaults).preferences, storage.preferences)
        storage.preferences.minutes = -50
        XCTAssertEqual(SessionStore(defaults: defaults).preferences.minutes, 10)
    }
    func testHistoryRelaunchDedupAndDeletion() async throws {
        let defaults = UserDefaults(suiteName: "flow.history.\(UUID())")!
        let storage = SessionStore(defaults: defaults), clock = FakeClock()
        let engine = SessionEngine(definition: try SessionDefinition(minutes: 2), clock: clock)
        engine.prepare(); engine.beginRunning(); clock.now = 120; engine.refresh()
        storage.recordCompletion(of: engine, at: Date(timeIntervalSince1970: 42))
        let reloaded = SessionStore(defaults: defaults)
        reloaded.recordCompletion(of: engine, at: Date())
        XCTAssertEqual(reloaded.history.count, 1); XCTAssertEqual(reloaded.history[0].activeDuration, 120)
        reloaded.preferences.haptics = true; reloaded.deleteHistory()
        XCTAssertTrue(SessionStore(defaults: defaults).history.isEmpty)
        XCTAssertTrue(SessionStore(defaults: defaults).preferences.haptics)
    }
    func testRepeatedStartAndCancelReleaseCallbacks() async throws {
        let (c, clock, audio, storage) = try await harness()
        c.start(); c.resume(); XCTAssertEqual(audio.prepared, 1)
        c.cancel(); clock.now = 1000; c.tick()
        XCTAssertNil(audio.onInterruption); XCTAssertNil(audio.onRemoteResume)
        XCTAssertFalse(audio.playing); XCTAssertTrue(storage.history.isEmpty)
    }
}

import Foundation
import Observation

@MainActor protocol SessionAudio: AnyObject {
    var onInterruption: ((String) -> Void)? { get set }
    var onFinish: (() -> Void)? { get set }
    var onRemotePause: (() -> Void)? { get set }
    var onRemoteResume: (() -> Void)? { get set }
    var onRemoteStop: (() -> Void)? { get set }
    func prepare(definition: SessionDefinition, preferences: Preferences) async throws
    func play(from time: TimeInterval) throws
    func pause()
    func setMuted(_ muted: Bool)
    func stopAll()
}

@MainActor @Observable final class SessionCoordinator {
    let engine: SessionEngine
    private(set) var notice: String?
    private(set) var muted = false
    private(set) var preferences: Preferences
    @ObservationIgnored private let audio: SessionAudio
    @ObservationIgnored private let store: SessionStoring
    @ObservationIgnored private var refreshTask: Task<Void, Never>?
    @ObservationIgnored private var preparation: Task<Void, Never>?
    @ObservationIgnored private var prepared = false
    @ObservationIgnored private var lastSequence: Int?
    @ObservationIgnored private var savedCompletion = false
    @ObservationIgnored var onHaptic: (() -> Void)?

    init(engine: SessionEngine, audio: SessionAudio, store: SessionStoring) {
        self.engine = engine; self.audio = audio; self.store = store
        preferences = store.preferences
        audio.onInterruption = { [weak self] reason in self?.interrupt(reason) }
        audio.onFinish = { [weak self] in
            guard let self, self.engine.state == .running else { return }
            self.engine.complete(); self.saveCompletion()
        }
        audio.onRemotePause = { [weak self] in self?.pause() }
        audio.onRemoteResume = { [weak self] in self?.resume() }
        audio.onRemoteStop = { [weak self] in self?.stop() }
    }
    func start() {
        guard engine.state == .idle else { return }
        engine.prepare()
        preparation = Task { [weak self] in await self?.prepareAndStart() }
    }
    func prepareAndStart(automaticallyRefresh: Bool = true) async {
        if engine.state == .idle { engine.prepare() }
        guard engine.state == .preparing || engine.isPaused else { return }
        do {
            if !prepared {
                try await audio.prepare(definition: engine.definition, preferences: preferences)
                prepared = true
            }
            guard !Task.isCancelled, engine.state == .preparing else { return }
            play(automaticallyRefresh: automaticallyRefresh)
        } catch {
            guard !Task.isCancelled, !engine.isTerminal else { return }
            interrupt("the session audio could not be prepared. resume to try again, or end this session.")
        }
    }
    func resume(automaticallyRefresh: Bool = true) {
        guard engine.isPaused else { return }
        if !prepared {
            preparation?.cancel()
            preparation = Task { [weak self] in
                guard let self else { return }
                do {
                    try await self.audio.prepare(definition: self.engine.definition, preferences: self.preferences)
                    guard !Task.isCancelled, self.engine.isPaused else { return }
                    self.prepared = true; self.play(automaticallyRefresh: automaticallyRefresh)
                } catch {
                    if !Task.isCancelled { self.notice = "audio is still unavailable. try again or end the session." }
                }
            }
        } else { play(automaticallyRefresh: automaticallyRefresh) }
    }
    private func play(automaticallyRefresh: Bool) {
        do {
            try audio.play(from: engine.elapsed)
            engine.beginRunning(); notice = nil; lastSequence = nil
            tick()
            if automaticallyRefresh { observeTimeline() }
        } catch { interrupt("audio could not start. check your output, then resume when ready.") }
    }
    func tick() {
        guard engine.state == .running else { return }
        engine.refresh()
        if engine.state == .completed { saveCompletion(); return }
        guard let phase = engine.phase else { lastSequence = nil; return }
        guard phase.sequence != lastSequence else { return }
        lastSequence = phase.sequence
        if preferences.haptics && phase.progress * 5 < 0.25 { onHaptic?() }
    }
    func pause() {
        guard engine.state == .running else { return }
        tick()
        guard !engine.isTerminal else { return }
        engine.pause(); audio.pause(); cancelRefresh()
    }
    func interrupt(_ reason: String) {
        guard !engine.isTerminal, engine.state != .idle else { return }
        if engine.isPaused { notice = reason } else { engine.pause(reason: reason) }
        audio.pause(); cancelRefresh()
    }
    // Screen locking does not interrupt the pre-rendered meditation audio timeline.
    func appBecameActive() { tick() }
    func useNaturalBreathing() { engine.useNaturalBreathing(); lastSequence = nil }
    func setMuted(_ value: Bool) { muted = value; audio.setMuted(value) }
    func stop() {
        if engine.state == .running { tick() }
        engine.stop(); preparation?.cancel(); cancelRefresh(); audio.stopAll()
    }
    func cancel() {
        stop()
        audio.onInterruption = nil; audio.onFinish = nil
        audio.onRemotePause = nil; audio.onRemoteResume = nil; audio.onRemoteStop = nil
    }
    private func saveCompletion() {
        cancelRefresh()
        if !savedCompletion {
            savedCompletion = true; store.recordCompletion(of: engine, at: Date())
        }
        // The recording continues through the closing bell's natural decay.
    }
    private func observeTimeline() {
        cancelRefresh()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .milliseconds(100)) } catch { return }
                guard let self, self.engine.state == .running else { return }
                self.tick()
            }
        }
    }
    private func cancelRefresh() { refreshTask?.cancel(); refreshTask = nil }
}

import Foundation
import Observation

@MainActor protocol SessionAudio: AnyObject {
    var onInterruption: ((String) -> Void)? { get set }
    func startAmbient(preferences: Preferences) throws
    func cue(_ kind: SessionDefinition.Phase.Kind, volume: Float) throws
    func setVolumes(ambient: Float, cue: Float)
    func stopSound()
    func stopAll()
    /// Returns a readable fallback if no already-installed voice is available.
    func speakIntroduction(_ text: String) throws -> String?
}

@MainActor @Observable final class SessionCoordinator {
    let engine: SessionEngine
    private(set) var notice: String?
    private(set) var preferences: Preferences
    @ObservationIgnored private let audio: SessionAudio
    @ObservationIgnored private let store: SessionStoring
    @ObservationIgnored private var refreshTask: Task<Void, Never>?
    @ObservationIgnored private var lastSequence: Int?
    @ObservationIgnored private var savedCompletion = false
    @ObservationIgnored var onHaptic: (() -> Void)?

    init(engine: SessionEngine, audio: SessionAudio, store: SessionStoring) {
        self.engine = engine
        self.audio = audio
        self.store = store
        self.preferences = store.preferences
        audio.onInterruption = { [weak self] reason in self?.interrupt(reason) }
    }

    func start() {
        guard engine.state == .idle else { return }
        engine.beginIntroduction()
        if preferences.spokenIntroduction {
            do { notice = try audio.speakIntroduction(Guidance.introduction) }
            catch { interrupt("spoken guidance could not start. resume to continue with the text, or stop.") }
        }
    }

    func resume(automaticallyRefresh: Bool = true) {
        guard engine.state == .introduction || engine.isPaused else { return }
        audio.stopAll()
        do {
            if preferences.sound { try audio.startAmbient(preferences: preferences) }
            engine.beginRunning()
            notice = nil
            lastSequence = nil
            tick()
            if automaticallyRefresh, engine.state == .running { observeTimeline() }
        } catch {
            interrupt("sound could not start. check your audio output, then resume, or turn sound off.")
        }
    }

    func tick() {
        guard engine.state == .running else { return }
        engine.refresh()
        if engine.state == .completed {
            cleanup()
            if !savedCompletion {
                savedCompletion = true
                store.recordCompletion(of: engine, at: Date())
            }
            return
        }
        guard let phase = engine.phase, phase.sequence != lastSequence else { return }
        lastSequence = phase.sequence
        // Late refreshes skip a missed tone instead of playing stale transitions.
        guard phase.progress * 4 < 0.25 else { return }
        do {
            if preferences.sound { try audio.cue(phase.kind, volume: preferences.cueVolume) }
            if preferences.haptics { onHaptic?() }
        } catch { interrupt("the sound stopped working. check your audio output, then resume, or turn sound off.") }
    }

    func pause() {
        engine.pause()
        cleanup()
    }

    func interrupt(_ reason: String) {
        guard !engine.isTerminal, engine.state != .idle else { return }
        if engine.isPaused { notice = reason }
        else { engine.pause(reason: reason) }
        cleanup()
    }

    func appBecameInactive() { interrupt("flow paused when the app became inactive. resume whenever you are ready.") }
    func routeDisconnected() { interrupt("your audio output disconnected. check where sound will play before resuming.") }
    func mediaServicesReset() { interrupt("the audio system restarted. resume to try again, or turn sound off.") }

    func setMode(_ mode: BreathingMode) {
        engine.setMode(mode)
        lastSequence = nil
        if mode == .natural { audio.stopSound() }
        // Reconfigure sound so an in-flight phase tone cannot linger in natural mode.
        if engine.state == .running {
            do {
                if preferences.sound { try audio.startAmbient(preferences: preferences) }
                tick()
            } catch { interrupt("sound could not restart. resume to retry, or turn sound off.") }
        }
    }

    func setSound(_ enabled: Bool) {
        preferences.sound = enabled
        store.preferences.sound = enabled
        guard engine.state == .running else { return }
        if !enabled { audio.stopSound(); return }
        do { try audio.startAmbient(preferences: preferences) }
        catch { interrupt("sound could not start. resume to retry, or turn sound off.") }
    }

    func stop() {
        engine.stop()
        cleanup()
    }

    func cancel() {
        stop()
        audio.onInterruption = nil
    }

    private func observeTimeline() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .milliseconds(50)) } catch { return }
                guard let self, self.engine.state == .running else { return }
                self.tick()
            }
        }
    }

    private func cleanup() {
        refreshTask?.cancel()
        refreshTask = nil
        audio.stopAll()
        lastSequence = nil
    }
}

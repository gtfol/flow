import Foundation
import Observation

@MainActor protocol MonotonicTimeSource { var now: TimeInterval { get } }
@MainActor final class ContinuousTimeSource: MonotonicTimeSource {
    private let clock = ContinuousClock()
    private let origin: ContinuousClock.Instant
    init() { origin = clock.now }
    var now: TimeInterval {
        let parts = origin.duration(to: clock.now).components
        return Double(parts.seconds) + Double(parts.attoseconds) / 1e18
    }
}
enum SessionState: String { case idle, preparing, running, paused, interrupted, completed, stopped }
struct PhasePosition: Equatable {
    let kind: SessionDefinition.Phase.Kind
    let progress: Double
    let remaining: TimeInterval
    let sequence: Int
    var count: Int? = nil
}

@MainActor @Observable final class SessionEngine {
    let definition: SessionDefinition
    let runID: UUID
    private(set) var state: SessionState = .idle
    private(set) var elapsed: TimeInterval = 0
    private(set) var mode: BreathingMode
    private(set) var interruptionReason: String?
    @ObservationIgnored private let clock: MonotonicTimeSource
    private var accumulated: TimeInterval = 0
    private var anchor: TimeInterval?
    init(definition: SessionDefinition, clock: MonotonicTimeSource, runID: UUID = UUID()) {
        self.definition = definition; self.mode = definition.breathing
        self.clock = clock; self.runID = runID
    }
    var remaining: TimeInterval { max(0, definition.duration - elapsed) }
    var isTerminal: Bool { state == .completed || state == .stopped }
    var isPaused: Bool { state == .paused || state == .interrupted }
    var segment: PracticeSegment { definition.segment(at: elapsed) }
    var phase: PhasePosition? {
        guard mode == .paced, !isTerminal, let window = definition.pacingWindow,
              window.contains(elapsed) else { return nil }
        return BreathingRhythm.position(at: elapsed - window.lowerBound)
    }

    func prepare() { guard state == .idle else { return }; state = .preparing }
    func beginRunning() {
        guard state == .preparing || isPaused else { return }
        anchor = clock.now; interruptionReason = nil; state = .running
    }
    func refresh(playbackTime: TimeInterval? = nil) {
        guard state == .running else { return }
        if let playbackTime, playbackTime.isFinite {
            elapsed = min(definition.duration, max(0, playbackTime))
            accumulated = elapsed; anchor = clock.now
        } else { sample() }
        if elapsed >= definition.duration { complete() }
    }
    func complete() {
        guard state == .running else { return }
        elapsed = definition.duration; accumulated = elapsed; anchor = nil; state = .completed
    }
    func pause(reason: String? = nil, playbackTime: TimeInterval? = nil) {
        guard state == .running || state == .preparing else { return }
        if state == .running {
            if let playbackTime, playbackTime.isFinite { elapsed = min(definition.duration, max(0, playbackTime)) }
            else { sample() }
        }
        accumulated = elapsed; anchor = nil; interruptionReason = reason
        state = reason == nil ? .paused : .interrupted
    }
    func useNaturalBreathing() { mode = .natural }
    func stop(playbackTime: TimeInterval? = nil) {
        guard !isTerminal else { return }
        if state == .running {
            if let playbackTime, playbackTime.isFinite { elapsed = min(definition.duration, max(0, playbackTime)) }
            else { sample() }
        }
        accumulated = elapsed; anchor = nil; state = .stopped
    }
    private func sample() {
        guard let anchor else { return }
        elapsed = min(definition.duration, accumulated + max(0, clock.now - anchor))
    }
}

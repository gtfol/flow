import Foundation
import Observation

@MainActor protocol MonotonicTimeSource {
    var now: TimeInterval { get }
}

@MainActor final class ContinuousTimeSource: MonotonicTimeSource {
    private let clock = ContinuousClock()
    private let origin: ContinuousClock.Instant
    init() { origin = clock.now }
    var now: TimeInterval {
        let parts = origin.duration(to: clock.now).components
        return Double(parts.seconds) + Double(parts.attoseconds) / 1e18
    }
}

enum SessionState: String { case idle, introduction, running, paused, interrupted, completed, stopped }

struct PhasePosition: Equatable {
    let kind: SessionDefinition.Phase.Kind
    let progress: Double
    let remaining: TimeInterval
    let sequence: Int
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
    private var phaseOrigin: TimeInterval = 0

    init(definition: SessionDefinition, mode: BreathingMode = .natural,
         clock: MonotonicTimeSource, runID: UUID = UUID()) {
        self.definition = definition
        self.mode = mode
        self.clock = clock
        self.runID = runID
    }

    var remaining: TimeInterval { max(0, definition.duration - elapsed) }
    var isTerminal: Bool { state == .completed || state == .stopped }
    var isPaused: Bool { state == .paused || state == .interrupted }

    var phase: PhasePosition? {
        guard mode == .paced else { return nil }
        let cycleDuration = definition.phases.reduce(0) { $0 + $1.duration }
        let active = max(0, elapsed - phaseOrigin)
        let cycle = Int(floor(active / cycleDuration))
        var offset = active.truncatingRemainder(dividingBy: cycleDuration)
        for (index, phase) in definition.phases.enumerated() {
            if offset < phase.duration {
                return PhasePosition(kind: phase.kind, progress: offset / phase.duration,
                                     remaining: phase.duration - offset,
                                     sequence: cycle * definition.phases.count + index)
            }
            offset -= phase.duration
        }
        return nil
    }

    func beginIntroduction() {
        guard state == .idle else { return }
        state = .introduction
    }

    func beginRunning() {
        guard state == .introduction || isPaused else { return }
        // Preserve every active second; only the optional visual cycle resets.
        // The final cycle may be shorter than eight seconds.
        phaseOrigin = elapsed
        anchor = clock.now
        interruptionReason = nil
        state = .running
    }

    func refresh() {
        guard state == .running else { return }
        sample()
        if elapsed >= definition.duration {
            accumulated = definition.duration
            anchor = nil
            state = .completed
        }
    }

    func pause(reason: String? = nil) {
        guard state == .running || state == .introduction else { return }
        if state == .running { sample() }
        accumulated = elapsed
        anchor = nil
        interruptionReason = reason
        state = reason == nil ? .paused : .interrupted
    }

    func setMode(_ value: BreathingMode) {
        guard !isTerminal else { return }
        if state == .running { sample() }
        mode = value
        phaseOrigin = elapsed
    }

    func stop() {
        guard !isTerminal else { return }
        if state == .running { sample() }
        accumulated = elapsed
        anchor = nil
        state = .stopped
    }

    private func sample() {
        guard let anchor else { return }
        elapsed = min(definition.duration, accumulated + max(0, clock.now - anchor))
    }
}

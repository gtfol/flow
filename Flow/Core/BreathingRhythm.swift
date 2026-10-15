import Foundation

/// Four beats per side; the phase cue is beat one. Counts are beats, not seconds.
/// The bundled cycle and the player both use these exact boundaries.
enum BreathingRhythm {
    static let beatDuration = 1.25
    static let countsPerPhase = 4
    static let phaseDuration = beatDuration * Double(countsPerPhase)
    static let cycleDuration = phaseDuration * 4
    static let phases: [SessionDefinition.Phase.Kind] = [.inhale, .holdIn, .exhale, .holdOut]

    static func position(at time: TimeInterval) -> PhasePosition {
        let beat = Int(floor(max(0, time) / beatDuration + 1e-9))
        let sequence = beat / (countsPerPhase)
        let count = beat % (countsPerPhase)
        let offset = max(0, time - Double(sequence) * phaseDuration)
        return PhasePosition(kind: phases[sequence % phases.count],
                             progress: min(1, offset / phaseDuration),
                             remaining: max(0, phaseDuration - offset), sequence: sequence,
                             count: count + 1)
    }
}

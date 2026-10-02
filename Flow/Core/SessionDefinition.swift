import Foundation

enum Practice: String, Codable, CaseIterable, Identifiable, Sendable {
    case stillness, openAwareness, silence
    var id: String { rawValue }
    var title: String {
        switch self { case .stillness: "stillness"; case .openAwareness: "open awareness"; case .silence: "pure silence" }
    }
    var detail: String {
        switch self {
        case .stillness: "settle with the breath, then let it go."
        case .openAwareness: "make room for body, sound, and whatever is here."
        case .silence: "a bell at either end. the space between is yours."
        }
    }
}

enum GuidanceLevel: String, Codable, CaseIterable, Identifiable, Sendable {
    case full, minimal, silent
    var id: String { rawValue }
    var title: String { rawValue }
}

enum BreathingMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case natural, paced
    var id: String { rawValue }
    var title: String { self == .natural ? "natural" : "gentle pace · 5 in / 5 out" }
}

enum PracticeStage: String, Sendable {
    case arrive, settle, expand, open, returning, silence
    var title: String {
        switch self {
        case .arrive: "arrive as you are."
        case .settle: "find your rhythm."
        case .expand: "a little more space."
        case .open: "let it all be here."
        case .returning: "come back gently."
        case .silence: "your space."
        }
    }
}

struct PracticeSegment: Equatable, Sendable {
    let stage: PracticeStage
    let start: TimeInterval
    let duration: TimeInterval
    var end: TimeInterval { start + duration }
}

struct NarrationEvent: Equatable, Sendable {
    let time: TimeInterval
    let clip: String
    let text: String
}

struct SessionDefinition: Identifiable, Equatable, Sendable {
    enum ValidationError: Error { case unsupportedDefinition }
    struct Phase {
        enum Kind: String, Sendable { case inhale, exhale }
    }
    static let minuteOptions = [2, 5, 10, 15, 20, 30]
    let practice: Practice
    let duration: TimeInterval
    let guidance: GuidanceLevel
    let breathing: BreathingMode
    var id: String { practice.rawValue }
    var title: String { practice.title }
    var detail: String { practice.detail }

    init(practice: Practice = .openAwareness, minutes: Int = 10,
         guidance: GuidanceLevel = .minimal, breathing: BreathingMode = .natural) throws {
        guard Self.minuteOptions.contains(minutes) else { throw ValidationError.unsupportedDefinition }
        self.practice = practice
        duration = Double(minutes * 60)
        self.guidance = practice == .silence ? .silent : guidance
        self.breathing = practice == .silence ? .natural : breathing
    }

    var segments: [PracticeSegment] {
        if practice == .silence { return [.init(stage: .silence, start: 0, duration: duration)] }
        let arrive = min(120, max(35, duration * 0.1))
        let settle = min(300, duration * 0.2)
        let expand = practice == .openAwareness ? min(300, duration * 0.2) : 0
        let returning = min(120, max(15, duration * 0.1))
        let open = duration - arrive - settle - expand - returning
        var cursor: Double = 0
        return [(PracticeStage.arrive, arrive), (.settle, settle), (.expand, expand),
                (.open, open), (.returning, returning)].compactMap { stage, length in
            guard length > 0 else { return nil }
            defer { cursor += length }
            return PracticeSegment(stage: stage, start: cursor, duration: length)
        }
    }

    func segment(at time: TimeInterval) -> PracticeSegment {
        segments.first(where: { time < $0.end }) ?? segments.last!
    }

    var narration: [NarrationEvent] {
        guard practice != .silence else { return [] }
        var events = [NarrationEvent(time: 3, clip: "introduction", text: Guidance.introduction)]
        guard guidance != .silent else { return events }
        for segment in segments where segment.stage != .arrive {
            let clip: String
            switch segment.stage {
            case .settle: clip = breathing == .paced ? "pace" : "settle"
            case .expand: clip = "body"
            case .open: clip = "open"
            case .returning: clip = "return"
            default: continue
            }
            events.append(.init(time: segment.start + 1, clip: clip, text: Guidance.clips[clip]!))
            if segment.stage == .expand && segment.duration >= 70 {
                events.append(.init(time: segment.start + segment.duration / 2, clip: "sound", text: Guidance.clips["sound"]!))
            }
            if guidance == .full && segment.stage != .returning {
                // Even full guidance leaves the latter portion of Open completely quiet.
                let limit = segment.stage == .open ? segment.start + segment.duration * 0.35 : segment.end - 30
                var next = segment.start + 75
                var index = 0
                while next < limit {
                    let extra = ["gentle", "thoughts", "sound"][index % 3]
                    if events.allSatisfy({ abs($0.time - next) >= 35 }) {
                        events.append(.init(time: next, clip: extra, text: Guidance.clips[extra]!))
                    }
                    next += 75; index += 1
                }
            }
        }
        return events.sorted { $0.time < $1.time }
    }

    /// The ambient bed recedes with attention and becomes silent in Open.
    func ambience(at time: TimeInterval) -> Float {
        guard practice != .silence else { return 0 }
        let segment = segment(at: time)
        switch segment.stage {
        case .arrive, .settle: return Float(min(1, time / 3))
        case .expand: return Float(1 - 0.75 * (time - segment.start) / segment.duration)
        case .open: return Float(max(0, (practice == .stillness ? 1 : 0.25) * (1 - (time - segment.start) / 10)))
        case .returning, .silence: return 0
        }
    }
}

enum Guidance {
    static let introductionTitle = "guidance · elevenlabs.io"
    static let introduction = "Find a comfortable place to sit, or lie down. Let your shoulders soften. Let your breathing stay easy. There's no need to make it deeper. For the next few minutes, simply notice your breath. Follow the gentle cue if it feels comfortable, or stay with your own rhythm. You can pause or stop whenever you need."
    static let clips = [
        "settle": "Let the breath find its own rhythm. Notice where you feel it most easily. There is no need to change it.",
        "pace": "If it feels comfortable, follow the gentle cue. Five seconds in, and five seconds out. Keep the breath easy. You can return to your own rhythm at any time.",
        "body": "Let your breathing happen by itself. Feel the weight of the body. Let your attention include the whole body at once.",
        "sound": "Notice sound, alongside the breath. Let nearby sounds and distant sounds be here together.",
        "thoughts": "If a thought appears, you can notice it without following it. Gently include the body and the sounds around you again.",
        "gentle": "Let your shoulders soften. There is no need to make the breath deeper. Stay with what feels comfortable.",
        "open": "Let breathing happen by itself. Let sensations and sounds come and go. For a while, there is nothing else to follow.",
        "return": "Feel the body again. Notice the room. Move your hands and feet gently. Open your eyes whenever you are ready."
    ]
    static let ending = "take a moment. move on when you’re ready."
    static let safety = "Use this seated or lying down in a safe place, never while driving, in water, or operating equipment. Keep breathing comfortable; do not force it or hold your breath. Stop if you feel dizzy, tingly, breathless, or unwell. If you have a medical condition, are pregnant, or are unsure whether breathing exercises suit you, ask a healthcare professional. Chest pain, fainting, or severe breathing trouble needs urgent medical help, not another session."
}

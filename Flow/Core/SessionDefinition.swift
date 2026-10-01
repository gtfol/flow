import Foundation

enum BreathingMode: String, Codable, CaseIterable, Identifiable {
    case natural, paced
    var id: String { rawValue }
    var title: String { self == .natural ? "natural breathing" : "gentle pace" }
}

struct SessionDefinition: Codable, Identifiable, Equatable {
    struct Phase: Codable, Equatable {
        enum Kind: String, Codable { case inhale, exhale }
        let kind: Kind
        let duration: TimeInterval

        init(kind: Kind, duration: TimeInterval) {
            self.kind = kind
            self.duration = duration
        }

        init(from decoder: Decoder) throws {
            try rejectUnknownKeys(decoder, allowed: ["kind", "duration"])
            let values = try decoder.container(keyedBy: CodingKeys.self)
            kind = try values.decode(Kind.self, forKey: .kind)
            duration = try values.decode(TimeInterval.self, forKey: .duration)
        }
    }

    let id: String
    let title: String
    let detail: String
    let duration: TimeInterval
    let contentRevision: Int
    let phases: [Phase]

    init(id: String, title: String, detail: String, duration: TimeInterval,
         contentRevision: Int, phases: [Phase]) throws {
        guard !id.isEmpty, !title.isEmpty, !detail.isEmpty, contentRevision > 0,
              duration.isFinite, duration > 0, duration <= 300,
              phases == [Phase(kind: .inhale, duration: 4), Phase(kind: .exhale, duration: 4)]
        else { throw ValidationError.unsupportedDefinition }
        self.id = id
        self.title = title
        self.detail = detail
        self.duration = duration
        self.contentRevision = contentRevision
        self.phases = phases
    }

    init(from decoder: Decoder) throws {
        try rejectUnknownKeys(decoder, allowed: ["id", "title", "detail", "duration", "contentRevision", "phases"])
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(id: values.decode(String.self, forKey: .id),
                      title: values.decode(String.self, forKey: .title),
                      detail: values.decode(String.self, forKey: .detail),
                      duration: values.decode(TimeInterval.self, forKey: .duration),
                      contentRevision: values.decode(Int.self, forKey: .contentRevision),
                      phases: values.decode([Phase].self, forKey: .phases))
    }

    static func load(data: Data) throws -> [SessionDefinition] {
        let sessions = try JSONDecoder().decode([SessionDefinition].self, from: data)
        guard !sessions.isEmpty, Set(sessions.map(\.id)).count == sessions.count else {
            throw ValidationError.unsupportedDefinition
        }
        return sessions
    }

    enum ValidationError: Error { case unsupportedDefinition, unknownField }
}

private struct AnyCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int? = nil
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { return nil }
}

private func rejectUnknownKeys(_ decoder: Decoder, allowed: Set<String>) throws {
    let container = try decoder.container(keyedBy: AnyCodingKey.self)
    guard container.allKeys.allSatisfy({ allowed.contains($0.stringValue) }) else {
        throw SessionDefinition.ValidationError.unknownField
    }
}

enum Guidance {
    static let introductionTitle = "introduction · elevenlabs.io"
    static let introduction = "Find a comfortable place to sit, or lie down. Let your shoulders soften. Let your breathing stay easy. There's no need to make it deeper. For the next few minutes, simply notice your breath. Follow the gentle cue if it feels comfortable, or stay with your own rhythm. You can pause or stop whenever you need."
    static let ending = "Let go of the cue and return to your usual breathing. Take a moment before moving on."
    static let safety = "Use this seated or lying down in a safe place, never while driving, in water, or operating equipment. Keep breathing comfortable; do not force it or hold your breath. Stop if you feel dizzy, tingly, breathless, or unwell. If you have a medical condition, are pregnant, or are unsure whether breathing exercises suit you, ask a healthcare professional. Chest pain, fainting, or severe breathing trouble needs urgent medical help, not another session."
}

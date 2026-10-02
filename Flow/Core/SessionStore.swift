import Foundation
import Observation

struct Preferences: Codable, Equatable {
    var sound = true
    var haptics = false
    var ambientVolume: Float = 0.35
    var cueVolume: Float = 0.25
    var hasReadSafety = false
    var practice: Practice = .openAwareness
    var minutes = 10
    var guidance: GuidanceLevel = .minimal
    var breathing: BreathingMode = .natural

    init() {}
    enum CodingKeys: String, CodingKey {
        case sound, haptics, ambientVolume, cueVolume, hasReadSafety, practice, minutes, guidance, breathing
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sound = try c.decodeIfPresent(Bool.self, forKey: .sound) ?? true
        haptics = try c.decodeIfPresent(Bool.self, forKey: .haptics) ?? false
        ambientVolume = try c.decodeIfPresent(Float.self, forKey: .ambientVolume) ?? 0.35
        cueVolume = try c.decodeIfPresent(Float.self, forKey: .cueVolume) ?? 0.25
        hasReadSafety = try c.decodeIfPresent(Bool.self, forKey: .hasReadSafety) ?? false
        practice = (try? c.decode(Practice.self, forKey: .practice)) ?? .openAwareness
        minutes = try c.decodeIfPresent(Int.self, forKey: .minutes) ?? 10
        guidance = (try? c.decode(GuidanceLevel.self, forKey: .guidance)) ?? .minimal
        breathing = (try? c.decode(BreathingMode.self, forKey: .breathing)) ?? .natural
    }

    func normalized() -> Preferences {
        var copy = self
        copy.ambientVolume = ambientVolume.isFinite ? min(1, max(0, ambientVolume)) : 0.35
        copy.cueVolume = cueVolume.isFinite ? min(1, max(0, cueVolume)) : 0.25
        if !SessionDefinition.minuteOptions.contains(copy.minutes) { copy.minutes = 10 }
        return copy
    }
}

struct CompletedSession: Codable, Equatable, Identifiable {
    var id: UUID { runID }
    let runID: UUID
    let sessionID: String
    let completedAt: Date
    let activeDuration: TimeInterval
}

@MainActor protocol SessionStoring: AnyObject {
    var preferences: Preferences { get set }
    var history: [CompletedSession] { get }
    func recordCompletion(of engine: SessionEngine, at date: Date)
    func deleteHistory()
}

@MainActor @Observable final class SessionStore: SessionStoring {
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let historyKey = "flow.completed.v1"
    @ObservationIgnored private let preferencesKey = "flow.preferences.v1"
    private(set) var history: [CompletedSession]
    var preferences: Preferences {
        didSet {
            if let data = try? JSONEncoder().encode(preferences.normalized()) {
                defaults.set(data, forKey: preferencesKey)
            }
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        preferences = defaults.data(forKey: "flow.preferences.v1")
            .flatMap { try? JSONDecoder().decode(Preferences.self, from: $0) }?.normalized() ?? Preferences()
        history = defaults.data(forKey: "flow.completed.v1")
            .flatMap { try? JSONDecoder().decode([CompletedSession].self, from: $0) } ?? []
    }

    func recordCompletion(of engine: SessionEngine, at date: Date = Date()) {
        guard engine.state == .completed, !history.contains(where: { $0.runID == engine.runID }) else { return }
        history.append(CompletedSession(runID: engine.runID, sessionID: engine.definition.id,
                                        completedAt: date, activeDuration: engine.elapsed))
        saveHistory()
    }

    func deleteHistory() {
        history = []
        defaults.removeObject(forKey: historyKey)
    }

    private func saveHistory() {
        if let data = try? JSONEncoder().encode(history) { defaults.set(data, forKey: historyKey) }
    }
}

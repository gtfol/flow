import Foundation
import Observation

struct Preferences: Codable, Equatable {
    var sound = true
    var spokenIntroduction = false
    var haptics = false
    var ambientVolume: Float = 0.35
    var cueVolume: Float = 0.25
    var hasReadSafety = false

    func normalized() -> Preferences {
        var copy = self
        copy.ambientVolume = ambientVolume.isFinite ? min(1, max(0, ambientVolume)) : 0.35
        copy.cueVolume = cueVolume.isFinite ? min(1, max(0, cueVolume)) : 0.25
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

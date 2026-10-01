import AVFoundation
import UIKit

@MainActor final class AudioController: NSObject, SessionAudio, AVAudioPlayerDelegate {
    var onInterruption: ((String) -> Void)?
    private var ambient: AVAudioPlayer?
    private var tone: AVAudioPlayer?
    private var introduction: AVAudioPlayer?
    private let introductionURL: URL?
    private var observers: [NSObjectProtocol] = []
    private var retiringPlayers: [AVAudioPlayer] = []
    private var fadeTask: Task<Void, Never>?
    private var sessionActive = false
    var isIntroductionPlaying: Bool { introduction?.isPlaying == true }

    init(introductionURL: URL? = Bundle.main.url(forResource: "introduction", withExtension: "mp3")) {
        self.introductionURL = introductionURL
        super.init()
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: AVAudioSession.interruptionNotification,
                                             object: nil, queue: .main) { [weak self] notification in
            let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            guard raw == AVAudioSession.InterruptionType.began.rawValue else { return }
            Task { @MainActor [weak self] in
                self?.onInterruption?("another app interrupted the audio. resume whenever you are ready.")
            }
        })
        observers.append(center.addObserver(forName: AVAudioSession.routeChangeNotification,
                                             object: nil, queue: .main) { [weak self] notification in
            let raw = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            guard raw == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue else { return }
            Task { @MainActor [weak self] in
                self?.onInterruption?("your audio output disconnected. check where sound will play before resuming.")
            }
        })
        for name in [AVAudioSession.mediaServicesWereResetNotification, AVAudioSession.mediaServicesWereLostNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.stopAll()
                    self?.onInterruption?("the audio system restarted. resume to try again, or turn sound off.")
                }
            })
        }
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
        fadeTask?.cancel()
    }

    func startAmbient(preferences: Preferences) throws {
        finishFades()
        try activate()
        if let ambient, ambient.isPlaying {
            ambient.setVolume(preferences.ambientVolume, fadeDuration: 0.2)
            return
        }
        let player = try makePlayer("ambient")
        player.numberOfLoops = -1
        player.volume = 0
        guard player.play() else { throw AudioError.playbackFailed }
        player.setVolume(preferences.ambientVolume, fadeDuration: 0.8)
        ambient = player
    }

    func cue(_ kind: SessionDefinition.Phase.Kind, volume: Float) throws {
        tone?.stop()
        let player = try makePlayer(kind == .inhale ? "inhale" : "exhale")
        player.volume = volume
        guard player.play() else { throw AudioError.playbackFailed }
        tone = player
    }

    func setVolumes(ambient: Float, cue: Float) {
        self.ambient?.setVolume(ambient, fadeDuration: 0.2)
        tone?.setVolume(cue, fadeDuration: 0.1)
    }

    func stopSound() {
        finishFades()
        retiringPlayers = [ambient, tone].compactMap { $0 }
        ambient = nil
        tone = nil
        retiringPlayers.forEach { $0.setVolume(0, fadeDuration: 0.08) }
        // Retain through the short release so dismissal cannot strand an active audio session.
        fadeTask = Task { [self] in
            do { try await Task.sleep(for: .milliseconds(90)) } catch { return }
            finishFades()
            deactivateIfQuiet()
        }
    }

    func stopAll() {
        introduction?.delegate = nil
        introduction?.stop()
        introduction = nil
        stopSound()
    }

    func playIntroduction() throws -> String? {
        stopAll()
        finishFades()
        deactivateIfQuiet()
        guard let introductionURL else {
            deactivateIfQuiet()
            return "the introduction audio is unavailable. the full introduction is here to read."
        }
        let player = try AVAudioPlayer(contentsOf: introductionURL)
        player.delegate = self
        player.volume = 0.8
        guard player.prepareToPlay() else { throw AudioError.playbackFailed }
        try activate()
        guard player.play() else {
            deactivateIfQuiet()
            throw AudioError.playbackFailed
        }
        introduction = player
        return nil
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor [weak self] in
            guard let self, self.isCurrent(player) else { return }
            self.stopAll()
            self.onInterruption?("an audio file could not play. resume to retry, or turn sound off.")
        }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            guard let self, self.isCurrent(player) else { return }
            if self.introduction === player { self.introduction = nil }
            if self.tone === player { self.tone = nil }
            if self.ambient === player { self.ambient = nil }
            player.delegate = nil
            if !flag {
                self.stopAll()
                self.onInterruption?("audio playback stopped unexpectedly. resume to retry, or turn sound off.")
            }
            self.deactivateIfQuiet()
        }
    }

    private func isCurrent(_ player: AVAudioPlayer) -> Bool {
        introduction === player || ambient === player || tone === player
    }

    private func activate() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [])
        try session.setActive(true)
        sessionActive = true
    }

    private func makePlayer(_ name: String) throws -> AVAudioPlayer {
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else { throw AudioError.missingAsset }
        let player = try AVAudioPlayer(contentsOf: url)
        player.delegate = self
        guard player.prepareToPlay() else { throw AudioError.playbackFailed }
        return player
    }

    private func finishFades() {
        fadeTask?.cancel()
        fadeTask = nil
        retiringPlayers.forEach { $0.stop(); $0.delegate = nil }
        retiringPlayers.removeAll()
    }

    private func deactivateIfQuiet() {
        guard ambient == nil, tone == nil, introduction == nil, sessionActive else { return }
        sessionActive = false
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            onInterruption?("the audio system could not release the session. stop and try again.")
        }
    }

    enum AudioError: Error { case missingAsset, playbackFailed }
}

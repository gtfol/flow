import AVFoundation
import UIKit

@MainActor final class AudioController: NSObject, SessionAudio, AVAudioPlayerDelegate, AVSpeechSynthesizerDelegate {
    var onInterruption: ((String) -> Void)?
    private var ambient: AVAudioPlayer?
    private var tone: AVAudioPlayer?
    private var speech: AVSpeechSynthesizer?
    private var observers: [NSObjectProtocol] = []
    private var retiringPlayers: [AVAudioPlayer] = []
    private var fadeTask: Task<Void, Never>?
    private var voiceTimeout: Task<Void, Never>?
    private var sessionActive = false
    private var speechDidStart = false

    override init() {
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
        voiceTimeout?.cancel()
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
        voiceTimeout?.cancel()
        voiceTimeout = nil
        speech?.delegate = nil
        speech?.stopSpeaking(at: .immediate)
        speech = nil
        stopSound()
    }

    func speakIntroduction(_ text: String) throws -> String? {
        stopAll()
        finishFades()
        // Only use an enumerated, already-available English system voice.
        // There is no voice-download API or network client in flow.
        guard let voice = AVSpeechSynthesisVoice.speechVoices().first(where: {
            $0.language.hasPrefix("en") && $0.quality == .default && !$0.voiceTraits.contains(.isPersonalVoice)
        }) else {
            return "an offline voice is not available. the full introduction is here to read."
        }
        try activate()
        let synthesizer = AVSpeechSynthesizer()
        synthesizer.delegate = self
        speech = synthesizer
        speechDidStart = false
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = 0.43
        utterance.volume = 0.65
        synthesizer.speak(utterance)
        voiceTimeout = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(5)) } catch { return }
            guard let self, !self.speechDidStart else { return }
            self.stopAll()
            self.onInterruption?("the offline voice could not start. read the introduction and resume when ready.")
        }
        return nil
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in self?.speechDidStart = true; self?.voiceTimeout?.cancel() }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in self?.deactivateIfQuiet() }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor [weak self] in
            self?.onInterruption?("an audio file could not play. resume to retry, or turn sound off.")
        }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if !flag {
            Task { @MainActor [weak self] in self?.onInterruption?("audio playback stopped unexpectedly. resume to retry, or turn sound off.") }
        }
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
        guard ambient == nil, tone == nil, speech?.isSpeaking != true, sessionActive else { return }
        sessionActive = false
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            onInterruption?("the audio system could not release the session. stop and try again.")
        }
    }

    enum AudioError: Error { case missingAsset, playbackFailed }
}

import AVFoundation
import MediaPlayer

@MainActor final class AudioController: NSObject, SessionAudio, AVAudioPlayerDelegate {
    var onInterruption: ((String) -> Void)?
    var onFinish: (() -> Void)?
    var onRemotePause: (() -> Void)?
    var onRemoteResume: (() -> Void)?
    var onRemoteStop: (() -> Void)?
    private var player: AVAudioPlayer?
    private var programURL: URL?
    private var definition: SessionDefinition?
    private var observers: [NSObjectProtocol] = []
    private var commands: [(MPRemoteCommand, Any)] = []
    private var active = false
    private var muted = false
    private var needsPlayer = false
    var isPlaying: Bool { player?.isPlaying == true }
    var playbackTime: TimeInterval { player?.currentTime ?? 0 }
    var playbackDuration: TimeInterval { player?.duration ?? 0 }

    override init() {
        super.init()
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] note in
            guard note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt == AVAudioSession.InterruptionType.began.rawValue else { return }
            Task { @MainActor [weak self] in self?.onInterruption?("audio was interrupted. resume whenever you’re ready.") }
        })
        observers.append(center.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] note in
            guard note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue else { return }
            Task { @MainActor [weak self] in self?.onInterruption?("your audio output disconnected. check where sound will play before resuming.") }
        })
        for name in [AVAudioSession.mediaServicesWereResetNotification, AVAudioSession.mediaServicesWereLostNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.needsPlayer = true
                    self?.onInterruption?("the audio system restarted. resume when ready.")
                }
            })
        }
    }
    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
        for (command, token) in commands { command.removeTarget(token) }
        if let programURL { try? FileManager.default.removeItem(at: programURL) }
    }
    func prepare(definition: SessionDefinition, preferences: Preferences) async throws {
        stopAll()
        var assets: [String: URL] = [:]
        for name in Set(definition.narration.map(\.clip)).union(["ambient", "bell"]) {
            if let url = Bundle.main.url(forResource: name, withExtension: ["ambient", "bell"].contains(name) ? "wav" : "mp3") { assets[name] = url }
        }
        let paths = assets
        let task = Task.detached(priority: .userInitiated) {
            try SessionAudioRenderer.render(definition: definition, preferences: preferences, assets: paths)
        }
        let url = try await withTaskCancellationHandler(operation: { try await task.value }, onCancel: { task.cancel() })
        guard !Task.isCancelled else { try? FileManager.default.removeItem(at: url); throw CancellationError() }
        do {
            try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: url.path)
            let value = try AVAudioPlayer(contentsOf: url)
            guard value.prepareToPlay() else { throw PlaybackError.cannotPlay }
            value.delegate = self; value.volume = muted ? 0 : 1
            player = value; programURL = url; self.definition = definition; needsPlayer = false
        } catch { try? FileManager.default.removeItem(at: url); throw error }
    }
    func play(from time: TimeInterval) throws {
        if needsPlayer, let programURL {
            player?.delegate = nil
            let replacement = try AVAudioPlayer(contentsOf: programURL)
            guard replacement.prepareToPlay() else { throw PlaybackError.cannotPlay }
            replacement.delegate = self; replacement.volume = muted ? 0 : 1
            player = replacement; needsPlayer = false
        }
        guard let player else { throw PlaybackError.cannotPlay }
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [])
        try session.setActive(true); active = true
        player.currentTime = min(max(0, time), max(0, player.duration - SessionAudioRenderer.tail))
        guard player.play() else { releaseSession(); throw PlaybackError.cannotPlay }
        installCommands(); updateNowPlaying(playing: true)
    }
    func pause() { player?.pause(); updateNowPlaying(playing: false); releaseSession() }
    func setMuted(_ value: Bool) { muted = value; player?.setVolume(value ? 0 : 1, fadeDuration: 0.15) }
    func stopAll() {
        player?.delegate = nil; player?.stop(); player = nil
        if let programURL { try? FileManager.default.removeItem(at: programURL) }
        programURL = nil
        for (command, token) in commands { command.removeTarget(token) }
        commands = []
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        releaseSession()
    }
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            guard let self, self.player === player else { return }
            if flag { self.onFinish?(); self.stopAll() }
            else { self.onInterruption?("playback stopped unexpectedly. resume to try again.") }
        }
    }
    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor [weak self] in
            guard let self, self.player === player else { return }
            self.onInterruption?("the recording could not play. end the session and try again.")
        }
    }
    private func releaseSession() {
        guard active else { return }; active = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    private func updateNowPlaying(playing: Bool) {
        guard let definition, let player else { return }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: definition.title,
            MPMediaItemPropertyArtist: "flow",
            MPMediaItemPropertyPlaybackDuration: definition.duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: min(definition.duration, player.currentTime),
            MPNowPlayingInfoPropertyPlaybackRate: playing ? 1.0 : 0.0
        ]
    }
    private func installCommands() {
        guard commands.isEmpty else { return }
        let center = MPRemoteCommandCenter.shared()
        for (command, action) in [(center.pauseCommand, 0), (center.playCommand, 1), (center.stopCommand, 2), (center.togglePlayPauseCommand, 3)] {
            command.isEnabled = true
            let token = command.addTarget { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    switch action {
                    case 0: self.onRemotePause?()
                    case 1: self.onRemoteResume?()
                    case 2: self.onRemoteStop?()
                    default: if self.isPlaying { self.onRemotePause?() } else { self.onRemoteResume?() }
                    }
                }
                return .success
            }
            commands.append((command, token))
        }
    }
    enum PlaybackError: Error { case cannotPlay }
}

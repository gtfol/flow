import AVFoundation
import MediaPlayer

@MainActor final class AudioController: NSObject, SessionAudio, AVAudioPlayerDelegate {
    var onInterruption: ((String) -> Void)?
    var onFinish: (() -> Void)?
    var onRemotePause: (() -> Void)?
    var onRemoteResume: (() -> Void)?
    var onRemoteStop: (() -> Void)?
    private var player: AVAudioPlayer?
    private var countPlayer: AVAudioPlayer?
    private var countURL: URL?
    private var countingDisabled = false
    var timelinePosition: TimeInterval? { needsPlayer ? nil : player?.currentTime }
    var countingTime: TimeInterval? { countPlayer?.currentTime }
    var isCounting: Bool { countPlayer?.isPlaying == true }
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
        if let countURL { try? FileManager.default.removeItem(at: countURL) }
        if let programURL { try? FileManager.default.removeItem(at: programURL) }
    }
    func prepare(definition: SessionDefinition, preferences: Preferences) async throws {
        stopAll()
        var assets: [String: URL] = [:]
        for name in Set(definition.narration.map(\.clip)).union(["ambient", "bell", "counting-cycle"]) {
            if let url = Bundle.main.url(forResource: name, withExtension: ["ambient", "bell", "counting-cycle"].contains(name) ? "wav" : "mp3") { assets[name] = url }
        }
        let paths = assets
        let task = Task.detached(priority: .userInitiated) {
            let program = try SessionAudioRenderer.render(definition: definition, preferences: preferences, assets: paths)
            do { return (program, try SessionAudioRenderer.renderCounting(definition: definition, assets: paths)) }
            catch { try? FileManager.default.removeItem(at: program); throw error }
        }
        let (url, counts) = try await withTaskCancellationHandler(operation: { try await task.value }, onCancel: { task.cancel() })
        do {
            try Task.checkCancellation()
            if let counts {
                try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: counts.path)
                let value = try AVAudioPlayer(contentsOf: counts)
                guard value.prepareToPlay() else { throw PlaybackError.cannotPlay }
                value.volume = muted ? 0 : 1; value.delegate = self
                countPlayer = value
            }
            try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: url.path)
            let value = try AVAudioPlayer(contentsOf: url)
            guard value.prepareToPlay() else { throw PlaybackError.cannotPlay }
            value.delegate = self; value.volume = muted ? 0 : 1
            player = value; programURL = url; countURL = counts
            self.definition = definition; needsPlayer = false; countingDisabled = false
        } catch {
            countPlayer = nil
            if let counts { try? FileManager.default.removeItem(at: counts) }
            try? FileManager.default.removeItem(at: url); throw error
        }
    }
    func play(from time: TimeInterval) throws {
        if needsPlayer, let programURL {
            player?.delegate = nil
            let replacement = try AVAudioPlayer(contentsOf: programURL)
            guard replacement.prepareToPlay() else { throw PlaybackError.cannotPlay }
            replacement.delegate = self; replacement.volume = muted ? 0 : 1
            if let countURL, !countingDisabled {
                let counts = try AVAudioPlayer(contentsOf: countURL)
                guard counts.prepareToPlay() else { throw PlaybackError.cannotPlay }
                counts.volume = muted ? 0 : 1; counts.delegate = self; countPlayer = counts
            }
            player = replacement; needsPlayer = false
        }
        guard let player else { throw PlaybackError.cannotPlay }
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [])
        try session.setActive(true); active = true
        player.currentTime = min(max(0, time), max(0, player.duration - SessionAudioRenderer.tail))
        let start = player.deviceCurrentTime + 0.05
        guard player.play(atTime: start) else { releaseSession(); throw PlaybackError.cannotPlay }
        if let countPlayer, !countingDisabled, time < countPlayer.duration {
            countPlayer.currentTime = player.currentTime
            guard countPlayer.play(atTime: start) else {
                player.pause(); releaseSession(); throw PlaybackError.cannotPlay
            }
        }
        installCommands(); updateNowPlaying(playing: true)
    }
    func pause() { player?.pause(); countPlayer?.pause(); updateNowPlaying(playing: false); releaseSession() }
    func disableCounting() { countingDisabled = true; countPlayer?.stop() }
    func setMuted(_ value: Bool) {
        muted = value
        player?.setVolume(value ? 0 : 1, fadeDuration: 0.15)
        countPlayer?.setVolume(value ? 0 : 1, fadeDuration: 0.15)
    }
    func stopAll() {
        player?.delegate = nil; player?.stop(); player = nil
        countPlayer?.stop(); countPlayer = nil
        if let countURL { try? FileManager.default.removeItem(at: countURL) }
        if let programURL { try? FileManager.default.removeItem(at: programURL) }
        programURL = nil; countURL = nil; countingDisabled = false
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
            guard let self, self.player === player || self.countPlayer === player else { return }
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

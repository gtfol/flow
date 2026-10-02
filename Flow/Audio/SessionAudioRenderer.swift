import AVFoundation

/// A finite meditation recording, including the planned silences and closing bell.
/// Rendering ahead of playback keeps transitions sample-aligned while iOS is locked.
enum SessionAudioRenderer {
    static let rate = 24_000.0
    static let tail = 8.0
    enum RenderError: Error { case missingAsset(String), invalidAudio, overlappingGuidance }
    struct Placement {
        let frame: Int
        let samples: [Float]
        let gain: Float
        var end: Int { frame + samples.count }
    }

    static func render(definition: SessionDefinition, preferences: Preferences, assets: [String: URL]) throws -> URL {
        let output = FileManager.default.temporaryDirectory.appendingPathComponent("flow-session-\(UUID().uuidString).wav")
        var succeeded = false
        defer { if !succeeded { try? FileManager.default.removeItem(at: output) } }
        func load(_ name: String) throws -> [Float] {
            guard let url = assets[name] else { throw RenderError.missingAsset(name) }
            return try samples(url)
        }
        let bell = try load("bell")
        let endFrame = Int(definition.duration * rate)
        var placements = [Placement(frame: 0, samples: bell, gain: preferences.cueVolume),
                          Placement(frame: endFrame, samples: bell, gain: preferences.cueVolume)]
        var previousEnd = 0
        for event in definition.narration {
            let data = try load(event.clip)
            let start = Int(event.time * rate)
            guard start >= previousEnd, start + data.count < endFrame else { throw RenderError.overlappingGuidance }
            placements.append(.init(frame: start, samples: data, gain: 0.8))
            previousEnd = start + data.count
        }
        let ambience = preferences.sound && definition.practice != .silence ? try load("ambient") : []
        let settings: [String: Any] = [AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: rate,
                                      AVNumberOfChannelsKey: 1, AVLinearPCMBitDepthKey: 16,
                                      AVLinearPCMIsFloatKey: false, AVLinearPCMIsBigEndianKey: false]
        let file = try AVAudioFile(forWriting: output, settings: settings)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: 8192),
              let channel = buffer.floatChannelData?[0] else { throw RenderError.invalidAudio }
        let total = Int((definition.duration + tail) * rate)
        for base in stride(from: 0, to: total, by: 8192) {
            try Task.checkCancellation()
            let count = min(8192, total - base)
            buffer.frameLength = AVAudioFrameCount(count)
            channel.update(repeating: 0, count: count)
            if !ambience.isEmpty && base < endFrame {
                let startGain = definition.ambience(at: Double(base) / rate) * preferences.ambientVolume
                let endGain = definition.ambience(at: Double(base + count) / rate) * preferences.ambientVolume
                for i in 0..<count {
                    channel[i] = ambience[(base + i) % ambience.count] * (startGain + (endGain - startGain) * Float(i) / Float(count))
                }
            }
            for placement in placements where placement.frame < base + count && placement.end > base {
                let lower = max(base, placement.frame), upper = min(base + count, placement.end)
                for frame in lower..<upper {
                    channel[frame - base] += placement.samples[frame - placement.frame] * placement.gain
                }
            }
            // Conservative hard ceiling; normal source levels remain well below this.
            for i in 0..<count { channel[i] = min(0.95, max(-0.95, channel[i])) }
            try file.write(from: buffer)
        }
        succeeded = true
        return output
    }

    static func samples(_ url: URL) throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        guard file.length > 0, file.length < 10_000_000,
              let input = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)),
              let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1),
              let converter = AVAudioConverter(from: file.processingFormat, to: format),
              let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(Double(file.length) * rate / file.processingFormat.sampleRate) + 1024)
        else { throw RenderError.invalidAudio }
        try file.read(into: input)
        var supplied = false
        var error: NSError?
        let status = converter.convert(to: output, error: &error) { _, state in
            if supplied { state.pointee = .endOfStream; return nil }
            supplied = true; state.pointee = .haveData; return input
        }
        if let error { throw error }
        guard status != .error, output.frameLength > 0, let data = output.floatChannelData?[0] else { throw RenderError.invalidAudio }
        return Array(UnsafeBufferPointer(start: data, count: Int(output.frameLength)))
    }
}

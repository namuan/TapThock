import AVFoundation
import Foundation

/// Plays short audio clips with near-zero latency using AVAudioEngine and
/// pre-loaded PCM buffers. Buffers are loaded from disk once at init;
/// no file I/O occurs on the hot playback path.
@MainActor
final class AudioPlayerPool {
    private let engine = AVAudioEngine()
    private var buffers: [URL: AVAudioPCMBuffer] = [:]
    private var nodes: [URL: AVAudioPlayerNode] = [:]

    init(urls: [URL]) throws {
        AppLog.info("AudioPlayerPool", "Creating audio engine pool", metadata: [
            "urlCount": "\(urls.count)",
        ])

        let mixer = engine.mainMixerNode

        for url in urls {
            AppLog.debug("AudioPlayerPool", "Loading audio buffer", metadata: [
                "filename": url.lastPathComponent,
            ])
            let file = try AVAudioFile(forReading: url)
            guard let buffer = AVAudioPCMBuffer(
                pcmFormat: file.processingFormat,
                frameCapacity: AVAudioFrameCount(file.length)
            ) else {
                throw NSError(
                    domain: "TapThock", code: 2001,
                    userInfo: [NSLocalizedDescriptionKey: "Unable to allocate PCM buffer for \(url.lastPathComponent)"]
                )
            }
            try file.read(into: buffer)

            let node = AVAudioPlayerNode()
            engine.attach(node)
            engine.connect(node, to: mixer, format: buffer.format)

            buffers[url] = buffer
            nodes[url] = node
        }

        try engine.start()
        AppLog.info("AudioPlayerPool", "Audio engine pool ready", metadata: [
            "preparedFiles": "\(buffers.count)",
        ])
    }

    func play(url: URL, volume: Float, rate: Float) {
        guard let buffer = buffers[url], let node = nodes[url] else {
            AppLog.error("AudioPlayerPool", "Missing buffer/node for URL", metadata: [
                "filename": url.lastPathComponent,
                "path": url.path,
            ])
            return
        }

        node.volume = volume
        node.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        node.play()

        AppLog.debug("AudioPlayerPool", "Issued audio playback", metadata: [
            "filename": url.lastPathComponent,
            "volume": String(format: "%.3f", volume),
        ])
    }

    // AVAudioEngine stops and cleans up its graph automatically on deallocation.
    // Calling engine.stop() in deinit is disallowed in Swift 6 (deinit is
    // nonisolated; AVAudioEngine is not Sendable).
}

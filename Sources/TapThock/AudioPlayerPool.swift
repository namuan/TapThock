import AVFoundation
import Foundation

@MainActor
final class AudioPlayerPool {
    private let playersByURL: [URL: [AVAudioPlayer]]

    init(urls: [URL], poolSize: Int = 6) throws {
        AppLog.info("AudioPlayerPool", "Creating audio player pool", metadata: [
            "poolSize": "\(poolSize)",
            "urlCount": "\(urls.count)",
        ])

        var storage: [URL: [AVAudioPlayer]] = [:]
        for url in urls {
            AppLog.debug("AudioPlayerPool", "Preparing audio players", metadata: [
                "filename": url.lastPathComponent,
            ])
            storage[url] = try (0..<poolSize).map { _ in
                let player = try AVAudioPlayer(contentsOf: url)
                player.enableRate = true
                player.prepareToPlay()
                return player
            }
        }
        playersByURL = storage
        AppLog.info("AudioPlayerPool", "Audio player pool ready", metadata: [
            "preparedFiles": "\(playersByURL.count)",
        ])
    }

    func play(url: URL, volume: Float, rate: Float) {
        guard let pool = playersByURL[url], !pool.isEmpty else {
            AppLog.error("AudioPlayerPool", "Missing player pool for URL", metadata: [
                "filename": url.lastPathComponent,
                "path": url.path,
            ])
            return
        }

        let player = pool.first(where: { !$0.isPlaying }) ?? pool[0]

        if player.isPlaying {
            player.stop()
            AppLog.debug("AudioPlayerPool", "Reused busy audio player", metadata: [
                "filename": url.lastPathComponent,
            ])
        }

        player.currentTime = 0
        player.volume = volume
        player.rate = rate
        let didStart = player.play()
        AppLog.debug("AudioPlayerPool", "Issued audio playback", metadata: [
            "didStart": "\(didStart)",
            "filename": url.lastPathComponent,
            "isPlaying": "\(player.isPlaying)",
            "rate": String(format: "%.3f", rate),
            "volume": String(format: "%.3f", volume),
        ])
    }
}

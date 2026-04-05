import AVFoundation
import Foundation

@MainActor
final class AudioPlayerPool {
    private let playersByURL: [URL: [AVAudioPlayer]]

    init(urls: [URL], poolSize: Int = 6) throws {
        var storage: [URL: [AVAudioPlayer]] = [:]
        for url in urls {
            storage[url] = try (0..<poolSize).map { _ in
                let player = try AVAudioPlayer(contentsOf: url)
                player.enableRate = true
                player.prepareToPlay()
                return player
            }
        }
        playersByURL = storage
    }

    func play(url: URL, volume: Float, rate: Float) {
        guard let pool = playersByURL[url], !pool.isEmpty else { return }
        let player = pool.first(where: { !$0.isPlaying }) ?? pool[0]

        if player.isPlaying {
            player.stop()
        }

        player.currentTime = 0
        player.volume = volume
        player.rate = rate
        player.play()
    }
}

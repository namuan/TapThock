import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class SoundManager {
    private(set) var packs: [SoundPack] = []
    private(set) var currentPack: SoundPack?
    private var audioPool: AudioPlayerPool?

    func reload(with packs: [SoundPack], selectedPackID: String) throws {
        self.packs = packs
        audioPool = try AudioPlayerPool(urls: Array(Set(packs.flatMap(\.allURLs))))
        currentPack = packs.first(where: { $0.id == selectedPackID }) ?? packs.first
    }

    func selectPack(id: String) {
        currentPack = packs.first(where: { $0.id == id }) ?? packs.first
    }

    func playKeyboard(event: NSEvent, volume: Float) {
        guard let pack = currentPack else { return }
        let keyType = KeyType.from(event: event)
        let url = keyType == .alphanumeric ? pack.randomVariantURL(for: keyType) : pack.soundURL(for: keyType)
        play(url: url, volume: volume, rate: pack.pitchShift(for: event.keyCode))
    }

    func playMouse(button: MouseButton, volume: Float) {
        guard let pack = currentPack else { return }
        play(url: pack.soundURL(for: button.keyType), volume: volume, rate: Double.random(in: 0.99...1.01) - 1.0)
    }

    func playScroll(deltaY: Double, volume: Float) {
        guard let pack = currentPack else { return }
        let scaledVolume = max(0.12, min(1.0, volume * Float(min(abs(deltaY) / 12.0, 1.0))))
        play(url: pack.soundURL(for: .scroll), volume: scaledVolume, rate: Double.random(in: -0.01...0.01))
    }

    func preview(pack: SoundPack?, volume: Float) {
        guard let pack else { return }
        play(url: pack.randomVariantURL(for: .alphanumeric), volume: volume, rate: Double.random(in: -0.01...0.01))
    }

    func handlePreview(event: NSEvent, keyboardVolume: Float) {
        playKeyboard(event: event, volume: keyboardVolume)
    }

    private func play(url: URL, volume: Float, rate: Double) {
        let playbackRate = Float(max(0.98, min(1.02, 1.0 + rate)))
        audioPool?.play(url: url, volume: volume, rate: playbackRate)
    }
}

import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class SoundManager {
    private(set) var packs: [SoundPack] = []
    private(set) var currentPack: SoundPack?
    private var audioPool: AudioPlayerPool?

    /// Stores all known packs but only loads audio for the selected one.
    func reload(with packs: [SoundPack], selectedPackID: String) throws {
        AppLog.info("SoundManager", "Reloading sound manager", metadata: [
            "packCount": "\(packs.count)",
            "selectedPackID": selectedPackID,
        ])
        self.packs = packs
        let selected = packs.first(where: { $0.id == selectedPackID }) ?? packs.first
        currentPack = selected
        try loadPool(for: selected)
        AppLog.info("SoundManager", "Sound manager ready", metadata: [
            "currentPackID": currentPack?.id ?? "nil",
        ])
    }

    func selectPack(id: String) {
        let pack = packs.first(where: { $0.id == id }) ?? packs.first
        currentPack = pack
        AppLog.info("SoundManager", "Selected active pack", metadata: [
            "currentPackID": currentPack?.id ?? "nil",
            "requestedPackID": id,
        ])
        do {
            try loadPool(for: pack)
        } catch {
            AppLog.error("SoundManager", "Failed to load pool for selected pack", metadata: [
                "error": error.localizedDescription,
                "packID": id,
            ])
        }
    }

    func playKeyboard(event: NSEvent, volume: Float) {
        guard let pack = currentPack else {
            AppLog.error("SoundManager", "Skipped keyboard playback because no pack is selected")
            return
        }
        let keyType = KeyType.from(event: event)
        let url = keyType == .alphanumeric ? pack.randomVariantURL(for: keyType) : pack.soundURL(for: keyType)
        AppLog.debug("SoundManager", "Playing keyboard sound", metadata: [
            "characters": event.charactersIgnoringModifiers ?? "",
            "filename": url.lastPathComponent,
            "keyCode": "\(event.keyCode)",
            "keyType": keyType.rawValue,
            "packID": pack.id,
            "volume": String(format: "%.3f", volume),
        ])
        play(url: url, volume: volume, rate: pack.pitchShift(for: event.keyCode))
    }

    func playMouse(button: MouseButton, volume: Float) {
        guard let pack = currentPack else {
            AppLog.error("SoundManager", "Skipped mouse playback because no pack is selected")
            return
        }
        AppLog.debug("SoundManager", "Playing mouse sound", metadata: [
            "button": button.keyType.rawValue,
            "filename": pack.soundURL(for: button.keyType).lastPathComponent,
            "packID": pack.id,
            "volume": String(format: "%.3f", volume),
        ])
        play(url: pack.soundURL(for: button.keyType), volume: volume, rate: Double.random(in: 0.99...1.01) - 1.0)
    }

    func playScroll(deltaY: Double, volume: Float) {
        guard let pack = currentPack else {
            AppLog.error("SoundManager", "Skipped scroll playback because no pack is selected")
            return
        }
        let scaledVolume = max(0.12, min(1.0, volume * Float(min(abs(deltaY) / 12.0, 1.0))))
        AppLog.debug("SoundManager", "Playing scroll sound", metadata: [
            "deltaY": String(format: "%.3f", deltaY),
            "filename": pack.soundURL(for: .scroll).lastPathComponent,
            "packID": pack.id,
            "scaledVolume": String(format: "%.3f", scaledVolume),
        ])
        play(url: pack.soundURL(for: .scroll), volume: scaledVolume, rate: Double.random(in: -0.01...0.01))
    }

    func preview(pack: SoundPack?, volume: Float) {
        guard let pack else {
            AppLog.error("SoundManager", "Skipped preview because no pack is selected")
            return
        }

        let previewVolume = max(volume, 0.55)
        let previewSteps: [(KeyType, UInt64)] = [
            (.alphanumeric, 0),
            (.enter, 80_000_000),
            (.mouseLeft, 160_000_000),
        ]

        AppLog.info("SoundManager", "Starting pack preview", metadata: [
            "packID": pack.id,
            "previewVolume": String(format: "%.3f", previewVolume),
            "stepCount": "\(previewSteps.count)",
        ])

        Task { @MainActor in
            for (keyType, delay) in previewSteps {
                if delay > 0 {
                    try? await Task.sleep(nanoseconds: delay)
                }

                let url = keyType == .alphanumeric ? pack.randomVariantURL(for: keyType) : pack.soundURL(for: keyType)
                AppLog.debug("SoundManager", "Preview playback step", metadata: [
                    "delayNanoseconds": "\(delay)",
                    "filename": url.lastPathComponent,
                    "keyType": keyType.rawValue,
                    "packID": pack.id,
                ])
                play(url: url, volume: previewVolume, rate: Double.random(in: -0.01...0.01))
            }
        }
    }

    func handlePreview(event: NSEvent, keyboardVolume: Float) {
        AppLog.debug("SoundManager", "Handling preview key event", metadata: [
            "characters": event.charactersIgnoringModifiers ?? "",
            "keyCode": "\(event.keyCode)",
            "keyboardVolume": String(format: "%.3f", keyboardVolume),
        ])
        playKeyboard(event: event, volume: keyboardVolume)
    }

    // MARK: - Private

    private func loadPool(for pack: SoundPack?) throws {
        guard let pack else {
            audioPool = nil
            return
        }
        AppLog.info("SoundManager", "Loading audio pool for pack", metadata: [
            "packID": pack.id,
            "urlCount": "\(pack.allURLs.count)",
        ])
        audioPool = try AudioPlayerPool(urls: pack.allURLs)
    }

    private func play(url: URL, volume: Float, rate: Double) {
        guard let audioPool else {
            AppLog.error("SoundManager", "Audio pool is unavailable", metadata: [
                "filename": url.lastPathComponent,
            ])
            return
        }
        audioPool.play(url: url, volume: volume, rate: Float(max(0.98, min(1.02, 1.0 + rate))))
    }
}

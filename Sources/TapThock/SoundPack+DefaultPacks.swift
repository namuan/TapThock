import AVFoundation
import Foundation

private struct PackCatalogEntry: Codable, Sendable {
    let id: String
    let name: String
    let primaryFrequency: Double
    let secondaryFrequency: Double
    let noiseMix: Double
    let brightness: Double
    let decay: Double
}

extension SoundPack {
    /// Loads (and on first run, renders) all default sound packs.
    /// Rendering is CPU- and I/O-heavy; this function is `nonisolated` so it
    /// can be called from a background task without blocking the main actor.
    static nonisolated func defaultPacks() throws -> [SoundPack] {
        let entries = try loadPackCatalog()
        let rootURL = try generatedPackRootURL()
        AppLog.info("SoundPack", "Loading default sound packs", metadata: [
            "catalogEntryCount": "\(entries.count)",
            "generatedPackRoot": rootURL.path,
        ])

        return try entries.map { entry in
            let folderURL = rootURL.appending(path: entry.id, directoryHint: .isDirectory)
            try SoundPackRenderer.renderIfNeeded(entry: entry, into: folderURL)

            return SoundPack(
                id: entry.id,
                name: entry.name,
                folderURL: folderURL,
                variantCount: 4
            )
        }
    }

    private static nonisolated func loadPackCatalog() throws -> [PackCatalogEntry] {
        guard let url = Bundle.module.url(forResource: "PackCatalog", withExtension: "json") else {
            throw NSError(domain: "TapThock", code: 1001, userInfo: [NSLocalizedDescriptionKey: "PackCatalog.json is missing from resources."])
        }

        let data = try Data(contentsOf: url)
        let entries = try JSONDecoder().decode([PackCatalogEntry].self, from: data)
        AppLog.info("SoundPack", "Loaded pack catalog", metadata: [
            "entryCount": "\(entries.count)",
            "resourceURL": url.path,
        ])
        return entries
    }

    private static nonisolated func generatedPackRootURL() throws -> URL {
        let appSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let root = appSupport
            .appending(path: "TapThock", directoryHint: .isDirectory)
            .appending(path: "GeneratedPacks", directoryHint: .isDirectory)

        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true, attributes: nil)
        AppLog.info("SoundPack", "Prepared generated pack root", metadata: [
            "path": root.path,
        ])
        return root
    }
}

private enum SoundPackRenderer {
    static func renderIfNeeded(entry: PackCatalogEntry, into folderURL: URL) throws {
        let markerURL = folderURL.appending(path: ".rendered")
        if FileManager.default.fileExists(atPath: markerURL.path) {
            AppLog.debug("SoundPackRenderer", "Using cached generated pack", metadata: [
                "packID": entry.id,
                "path": folderURL.path,
            ])
            return
        }

        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
        AppLog.info("SoundPackRenderer", "Rendering generated pack", metadata: [
            "packID": entry.id,
            "path": folderURL.path,
        ])

        for variant in 0..<4 {
            try writeSound(
                to: folderURL.appending(path: "alphanumeric-\(variant).caf"),
                profile: entry,
                flavor: .alphanumeric(index: variant)
            )
        }

        try writeSound(to: folderURL.appending(path: "space.caf"), profile: entry, flavor: .space)
        try writeSound(to: folderURL.appending(path: "enter.caf"), profile: entry, flavor: .enter)
        try writeSound(to: folderURL.appending(path: "backspace.caf"), profile: entry, flavor: .backspace)
        try writeSound(to: folderURL.appending(path: "tab.caf"), profile: entry, flavor: .tab)
        try writeSound(to: folderURL.appending(path: "escape.caf"), profile: entry, flavor: .escape)
        try writeSound(to: folderURL.appending(path: "modifier.caf"), profile: entry, flavor: .modifier)
        try writeSound(to: folderURL.appending(path: "mouse-left.caf"), profile: entry, flavor: .mouseLeft)
        try writeSound(to: folderURL.appending(path: "mouse-right.caf"), profile: entry, flavor: .mouseRight)
        try writeSound(to: folderURL.appending(path: "mouse-middle.caf"), profile: entry, flavor: .mouseMiddle)
        try writeSound(to: folderURL.appending(path: "mouse-back.caf"), profile: entry, flavor: .mouseBack)
        try writeSound(to: folderURL.appending(path: "mouse-forward.caf"), profile: entry, flavor: .mouseForward)
        try writeSound(to: folderURL.appending(path: "scroll.caf"), profile: entry, flavor: .scroll)

        try Data(entry.id.utf8).write(to: markerURL, options: .atomic)
        AppLog.info("SoundPackRenderer", "Finished rendering generated pack", metadata: [
            "packID": entry.id,
        ])
    }

    private static func writeSound(to url: URL, profile: PackCatalogEntry, flavor: Flavor) throws {
        let sampleRate = 44_100.0
        let samples = generateSamples(profile: profile, flavor: flavor, sampleRate: sampleRate)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)) else {
            throw NSError(domain: "TapThock", code: 1002, userInfo: [NSLocalizedDescriptionKey: "Unable to allocate an audio buffer."])
        }

        buffer.frameLength = buffer.frameCapacity
        let pointer = buffer.floatChannelData![0]
        for (index, sample) in samples.enumerated() {
            pointer[index] = sample
        }

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
        ]

        let file = try AVAudioFile(
            forWriting: url,
            settings: settings,
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )
        try file.write(from: buffer)
    }

    private static func generateSamples(profile: PackCatalogEntry, flavor: Flavor, sampleRate: Double) -> [Float] {
        let config = flavor.configuration(profile: profile)
        let frameCount = max(Int(config.duration * sampleRate), 1)
        var samples = Array(repeating: Float.zero, count: frameCount)
        var generator = SeededGenerator(seed: UInt64(abs(profile.id.hashValue ^ flavor.seedOffset)))

        // One-pole low-pass filter for noise (~5 kHz cutoff).
        // Attenuates frequencies above ~5 kHz — real plastic/metal impacts are
        // heavily damped by material, so raw white noise sounds artificially harsh.
        let lpAlpha = 2.0 * Double.pi * 5000.0 / (2.0 * Double.pi * 5000.0 + sampleRate)
        var impactLpState = 0.0
        var bodyLpState = 0.0

        // Low-frequency case thump — 0.28× primary lands in the 120–272 Hz range.
        // Real gasket/plate assemblies resonate here; this is the "weight" that makes
        // a thocky board feel different from a plastic beep.
        let thumpFrequency = config.primaryFrequency * 0.28

        // Loop-invariant phase multipliers and decay scalars — hoisted to avoid
        // recomputing them across the ~44k iterations per sound file.
        let twoPi = 2.0 * Double.pi
        let primaryPhaseRate   = twoPi * config.primaryFrequency
        let secondaryPhaseRate = twoPi * config.secondaryFrequency
        let clickPhaseRate     = twoPi * config.secondaryFrequency * 1.4
        let thumpPhaseRate     = twoPi * thumpFrequency
        let clickDecay         = config.decay * 0.25
        let thumpDecay         = config.decay * 3.5
        let halfBrightness     = config.brightness * 0.5
        let tonalMix           = 1.0 - config.noiseMix

        for frame in 0..<frameCount {
            let t = Double(frame) / sampleRate
            let remaining = max(1.0 - t / config.duration, 0.0)

            // Near-instantaneous attack (~0.4 ms) — real key impact registers in < 0.5 ms.
            let attack = min(t / 0.0004, 1.0)

            // Three tonal components with independent decay times.
            // A single exponential decay produces a homogeneous "beep"; real switch
            // housings have multiple resonant modes that fade at different rates.

            // 1. High-frequency click ring — fast decay, captures the initial crack.
            let clickEnv = attack * exp(-t / clickDecay)
            let click = sin(clickPhaseRate * t) * clickEnv * 0.20

            // 2. Mid-frequency plate ping — main body resonance.
            let plateEnv = attack * exp(-t / config.decay) * pow(remaining, config.brightness)
            let plate = (sin(primaryPhaseRate * t) * 0.65 + sin(secondaryPhaseRate * t) * 0.35) * plateEnv * 0.52

            // 3. Low-frequency case thump — slow decay, adds physical depth and weight.
            let thumpEnv = attack * exp(-t / thumpDecay) * pow(remaining, halfBrightness)
            let thump = sin(thumpPhaseRate * t) * thumpEnv * 0.36

            // Low-pass filtered impact transient — broadband crack at contact.
            // Filtering gives it warmth; raw white noise sounds digital above ~5 kHz.
            let rawImpactNoise = Double.random(in: -1.0...1.0, using: &generator)
            impactLpState += lpAlpha * (rawImpactNoise - impactLpState)
            let impact = impactLpState * exp(-t / 0.003) * 0.50

            // Filtered tactile noise — texture during body decay.
            let rawBodyNoise = Double.random(in: -1.0...1.0, using: &generator)
            bodyLpState += lpAlpha * (rawBodyNoise - bodyLpState)
            let shapedNoise = bodyLpState * config.noiseMix * pow(remaining, 2.5)

            let body = (click + plate + thump) * tonalMix + shapedNoise
            let sample = (body + impact) * config.gain
            samples[frame] = Float(max(min(sample, 0.95), -0.95))
        }

        return samples
    }
}

private enum Flavor {
    case alphanumeric(index: Int)
    case space
    case enter
    case backspace
    case tab
    case escape
    case modifier
    case mouseLeft
    case mouseRight
    case mouseMiddle
    case mouseBack
    case mouseForward
    case scroll

    var seedOffset: Int {
        switch self {
        case .alphanumeric(let index): index
        case .space: 20
        case .enter: 21
        case .backspace: 22
        case .tab: 23
        case .escape: 24
        case .modifier: 25
        case .mouseLeft: 26
        case .mouseRight: 27
        case .mouseMiddle: 28
        case .mouseBack: 29
        case .mouseForward: 30
        case .scroll: 31
        }
    }

    func configuration(profile: PackCatalogEntry) -> ToneConfiguration {
        switch self {
        case .alphanumeric(let index):
            ToneConfiguration(
                duration: 0.055 + Double(index) * 0.004,
                primaryFrequency: profile.primaryFrequency * (1.0 + Double(index) * 0.018),
                secondaryFrequency: profile.secondaryFrequency * (0.96 + Double(index) * 0.015),
                noiseMix: profile.noiseMix,
                brightness: profile.brightness,
                decay: profile.decay,
                gain: 0.85
            )
        case .space:
            ToneConfiguration(duration: 0.09, primaryFrequency: profile.primaryFrequency * 0.72, secondaryFrequency: profile.secondaryFrequency * 0.65, noiseMix: profile.noiseMix * 0.8, brightness: profile.brightness * 0.9, decay: profile.decay * 1.35, gain: 0.88)
        case .enter:
            ToneConfiguration(duration: 0.11, primaryFrequency: profile.primaryFrequency * 0.62, secondaryFrequency: profile.secondaryFrequency * 0.74, noiseMix: profile.noiseMix * 0.75, brightness: profile.brightness * 0.88, decay: profile.decay * 1.5, gain: 0.92)
        case .backspace:
            ToneConfiguration(duration: 0.082, primaryFrequency: profile.primaryFrequency * 0.76, secondaryFrequency: profile.secondaryFrequency * 0.81, noiseMix: profile.noiseMix * 0.84, brightness: profile.brightness, decay: profile.decay * 1.2, gain: 0.84)
        case .tab:
            ToneConfiguration(duration: 0.078, primaryFrequency: profile.primaryFrequency * 0.8, secondaryFrequency: profile.secondaryFrequency * 0.9, noiseMix: profile.noiseMix * 0.78, brightness: profile.brightness, decay: profile.decay * 1.14, gain: 0.83)
        case .escape:
            ToneConfiguration(duration: 0.05, primaryFrequency: profile.primaryFrequency * 1.15, secondaryFrequency: profile.secondaryFrequency * 1.08, noiseMix: profile.noiseMix * 1.1, brightness: profile.brightness * 1.05, decay: profile.decay * 0.86, gain: 0.7)
        case .modifier:
            ToneConfiguration(duration: 0.048, primaryFrequency: profile.primaryFrequency * 0.95, secondaryFrequency: profile.secondaryFrequency * 0.92, noiseMix: profile.noiseMix * 1.05, brightness: profile.brightness * 1.1, decay: profile.decay * 0.84, gain: 0.58)
        case .mouseLeft:
            ToneConfiguration(duration: 0.043, primaryFrequency: profile.primaryFrequency * 0.9, secondaryFrequency: profile.secondaryFrequency * 0.78, noiseMix: profile.noiseMix * 0.95, brightness: profile.brightness, decay: profile.decay * 0.82, gain: 0.8)
        case .mouseRight:
            ToneConfiguration(duration: 0.047, primaryFrequency: profile.primaryFrequency * 0.97, secondaryFrequency: profile.secondaryFrequency * 0.88, noiseMix: profile.noiseMix, brightness: profile.brightness, decay: profile.decay * 0.88, gain: 0.77)
        case .mouseMiddle:
            ToneConfiguration(duration: 0.051, primaryFrequency: profile.primaryFrequency * 0.84, secondaryFrequency: profile.secondaryFrequency * 0.82, noiseMix: profile.noiseMix * 1.15, brightness: profile.brightness * 0.92, decay: profile.decay * 0.92, gain: 0.72)
        case .mouseBack:
            ToneConfiguration(duration: 0.049, primaryFrequency: profile.primaryFrequency * 0.78, secondaryFrequency: profile.secondaryFrequency * 0.7, noiseMix: profile.noiseMix * 1.05, brightness: profile.brightness, decay: profile.decay * 0.88, gain: 0.7)
        case .mouseForward:
            ToneConfiguration(duration: 0.049, primaryFrequency: profile.primaryFrequency * 0.88, secondaryFrequency: profile.secondaryFrequency * 0.73, noiseMix: profile.noiseMix, brightness: profile.brightness, decay: profile.decay * 0.88, gain: 0.72)
        case .scroll:
            ToneConfiguration(duration: 0.028, primaryFrequency: profile.primaryFrequency * 1.35, secondaryFrequency: profile.secondaryFrequency * 1.42, noiseMix: profile.noiseMix * 0.85, brightness: profile.brightness * 1.2, decay: profile.decay * 0.58, gain: 0.45)
        }
    }
}

private struct ToneConfiguration {
    let duration: Double
    let primaryFrequency: Double
    let secondaryFrequency: Double
    let noiseMix: Double
    let brightness: Double
    let decay: Double
    let gain: Double
}

private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }
}

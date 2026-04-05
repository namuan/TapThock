# Sound Synthesis Algorithm

TapThock generates all sounds procedurally at first launch — there are no recorded audio samples. Each sound is synthesised from mathematical components, written to a `.caf` file in Application Support, and cached. On subsequent launches the cached files are loaded directly.

---

## Overview

Every keypress, mouse click, and scroll event produces a short mono audio buffer at 44.1 kHz. The buffer is constructed by summing three independent components:

```
sample(t) = [ body(t) + impact(t) ] × gain
```

| Component | Models | Duration |
|-----------|--------|----------|
| **Impact transient** | The broadband crack of physical contact | ~3 ms |
| **Tonal body** | Housing resonance — the pitched "thock" ring | Full duration |
| **Shaped noise** | Tactile texture during the body decay | Full duration |

---

## Per-frame synthesis

For each sample at time `t` (seconds):

### 1. Attack

```
attack = clamp(t / 0.0004, 0, 1)
```

A 0.4 ms linear ramp to onset. Near-instantaneous by design — real key impact registers in under half a millisecond. A longer ramp produces a soft "fade-in" rather than a sharp click.

### 2. Low-pass filter (noise pre-processing)

Two independent one-pole IIR low-pass filters run across the entire buffer — one for the impact burst, one for the body texture noise:

```
lpAlpha   = 2π × 5000 / (2π × 5000 + sampleRate)   ≈ 0.416 at 44.1 kHz
lpState  += lpAlpha × (whiteNoise - lpState)
```

This approximates pink-ish noise by attenuating frequencies above ~5 kHz. Raw white noise above that range produces a harsh digital hiss; real plastic/metal impacts are heavily attenuated at high frequencies by material damping. Two separate filter states (`impactLpState`, `bodyLpState`) keep the impact crack and body texture spectrally independent.

### 3. Three tonal components with independent decays

A single exponential decay applied to a fixed mix of sines produces a homogeneous "beep". Real switch housings have multiple resonant modes that fade at different rates. Three components model this:

**High-frequency click ring** — captures the initial crack resonance, fades quickly:
```
clickEnv = attack × exp(-t / (decay × 0.25))
click    = sin(2π × secondaryFrequency × 1.4 × t) × clickEnv × 0.20
```

**Mid-frequency plate ping** — main body resonance, full decay:
```
plateEnv = attack × exp(-t / decay) × (1 - progress)^brightness
plate    = (sin(2π × primaryFrequency × t) × 0.65
          + sin(2π × secondaryFrequency × t) × 0.35) × plateEnv × 0.52
```

**Low-frequency case thump** — slow decay, adds physical weight and depth:
```
thumpFrequency = primaryFrequency × 0.28        ← lands in 120–272 Hz
thumpEnv       = attack × exp(-t / (decay × 3.5)) × (1 - progress)^(brightness × 0.5)
thump          = sin(2π × thumpFrequency × t) × thumpEnv × 0.36
```

The thump component is the most perceptually important addition. Real gasket-mounted and plate-mounted keyboards resonate strongly below 300 Hz — this is the "weight" that distinguishes a thocky board from a thin plastic rattle. Packs with a low `primaryFrequency` (e.g. Typewriter Ink at 430 Hz) produce a thump at ~120 Hz; brighter packs (Neon Blue at 970 Hz) thump at ~272 Hz.

```
tonal = click + plate + thump
```

### 4. Impact transient

```
impact = impactLpState × exp(-t / 0.003) × 0.50
```

Low-pass filtered noise with a 3 ms decay time constant. Models the broadband energy of physical contact. The filter gives it a warm rather than harsh character.

### 5. Shaped noise

```
shapedNoise = bodyLpState × noiseMix × (1 - progress)^2.5
```

Filtered noise gated by a fast polynomial envelope, concentrated near the attack. Provides the tactile "scratchy" texture that sits underneath the tonal body ring.

### 6. Final mix

```
body   = tonal × (1 - noiseMix) + shapedNoise
sample = clamp((body + impact) × gain, -0.95, 0.95)
```

The impact transient is added after the body mix so its amplitude is independent of the body envelope. The hard clamp at ±0.95 prevents inter-sample clipping without a separate limiter pass.

---

## Key-type flavours

A single pack profile generates 16 distinct sounds (4 alphanumeric variants + 12 key types). Each key type applies multipliers to the pack's base parameters via a `Flavor`:

| Key type | Duration | Primary freq | Notes |
|----------|----------|-------------|-------|
| Alphanumeric (×4) | 55–67 ms | 1.0–1.05× | Slight pitch/duration spread across variants |
| Space | 90 ms | 0.72× | Lower pitch, longer decay — stabiliser bar resonance |
| Enter | 110 ms | 0.62× | Lowest pitch, longest decay — large keycap |
| Backspace | 82 ms | 0.76× | Similar to Enter but shorter |
| Tab | 78 ms | 0.80× | Mid-size keycap |
| Escape | 50 ms | 1.15× | Higher pitch, sharper — small isolated key |
| Modifier | 48 ms | 0.95× | Quieter (gain 0.58), slightly faster |
| Mouse left/right | 43–47 ms | 0.90–0.97× | Shorter, crisper |
| Mouse middle/back/forward | 49–51 ms | 0.78–0.84× | Lower pitch, higher noise mix |
| Scroll | 28 ms | 1.35× | Very short, higher pitch, low gain (0.45) |

Alphanumeric variants additionally apply a small per-key pitch shift (±1.2% based on key code) so adjacent keys sound subtly different even within the same variant.

---

## Pack profiles

Each pack in `PackCatalog.json` defines six parameters:

| Parameter | Range | Effect |
|-----------|-------|--------|
| `primaryFrequency` | 430–970 Hz | Fundamental pitch of the housing resonance |
| `secondaryFrequency` | 690–1490 Hz | Second resonant mode; spread from primary affects "material" quality |
| `noiseMix` | 0.09–0.30 | Tactile texture vs tonal clarity |
| `brightness` | 0.82–1.34 | Tail cutoff aggressiveness |
| `decay` | 0.031–0.079 s | Exponential decay time constant |
| `gain` | (per flavor) | Output level; applied last |

Low primary frequency + high decay → deep, resonant "thock" (e.g. Typewriter Ink at 430 Hz / 79 ms).  
High primary frequency + low decay → sharp, clicky sound (e.g. Neon Blue at 970 Hz / 31 ms).

---

## Deterministic generation

```swift
var generator = SeededGenerator(seed: UInt64(abs(profile.id.hashValue ^ flavor.seedOffset)))
```

A seeded xoshiro-style PRNG (splitmix64 variant) is initialised from the pack ID and key-type offset. This ensures the same pack configuration always produces the same audio file, making the cache reliable without storing the input parameters separately.

---

## Rendering pipeline

```
PackCatalog.json
      │
      ▼
SoundPackRenderer.renderIfNeeded()   ← skipped if .rendered marker exists
      │
      ├─ generateSamples()           ← per-frame synthesis (described above)
      ├─ AVAudioPCMBuffer            ← float32 samples → PCM buffer
      └─ AVAudioFile (CAF/PCM16)     ← written to ~/Library/Application Support/TapThock/GeneratedPacks/<id>/

AudioPlayerPool.init()
      │
      ├─ AVAudioPCMBuffer per file   ← all files pre-loaded into RAM
      ├─ AVAudioPlayerNode per file  ← connected to AVAudioEngine mixer
      └─ engine.start()

Keypress → scheduleBuffer() → immediate playback (no disk I/O on hot path)
```

Rendered files are regenerated automatically if the `.rendered` marker is absent (e.g. after clearing the cache or on first install).

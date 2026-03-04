#!/usr/bin/env python3
"""Generate WAV instrument samples for the radio music system.

Creates drum and melodic samples with proper harmonics, envelopes, and
noise characteristics. Output: assets/audio/samples/{drums,melodic}/*.wav
"""

import math
import os
import random
import struct
import wave

SAMPLE_RATE = 44100
BASE_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "audio", "samples")


def write_wav(path: str, samples: list[float], sample_rate: int = SAMPLE_RATE):
    """Write mono 16-bit WAV file from float samples [-1, 1]."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "w") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(sample_rate)
        data = b""
        for s in samples:
            s = max(-1.0, min(1.0, s))
            data += struct.pack("<h", int(s * 32767))
        f.writeframes(data)
    print(f"  Written: {path} ({len(samples)} samples, {len(samples)/sample_rate:.2f}s)")


def gen_kick(duration: float = 0.4) -> list[float]:
    """Kick drum: pitch-dropping sine with click transient."""
    n = int(SAMPLE_RATE * duration)
    samples = []
    phase = 0.0
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.exp(-t * 12.0)
        # Pitch drops from 150Hz to 45Hz
        freq = 45.0 + 105.0 * math.exp(-t * 25.0)
        phase += freq / SAMPLE_RATE
        # Sine body + slight click transient
        s = math.sin(phase * 2 * math.pi) * env
        # Click at very start
        if t < 0.003:
            s += (1.0 - t / 0.003) * 0.5
        samples.append(s * 0.9)
    return samples


def gen_snare(duration: float = 0.3) -> list[float]:
    """Snare drum: noise burst + tonal body at ~200Hz."""
    n = int(SAMPLE_RATE * duration)
    rng = random.Random(42)
    samples = []
    phase = 0.0
    for i in range(n):
        t = i / SAMPLE_RATE
        noise_env = math.exp(-t * 20.0)
        tone_env = math.exp(-t * 15.0)
        noise = (rng.random() * 2.0 - 1.0) * noise_env * 0.7
        phase += 200.0 / SAMPLE_RATE
        tone = math.sin(phase * 2 * math.pi) * tone_env * 0.5
        samples.append((noise + tone) * 0.85)
    return samples


def gen_snare_brush(duration: float = 0.35) -> list[float]:
    """Brush snare: softer, filtered noise with gentle body."""
    n = int(SAMPLE_RATE * duration)
    rng = random.Random(43)
    samples = []
    prev = 0.0
    phase = 0.0
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.exp(-t * 10.0)
        noise = (rng.random() * 2.0 - 1.0) * env * 0.4
        # Low-pass filter the noise for brushy sound
        prev += 0.15 * (noise - prev)
        phase += 180.0 / SAMPLE_RATE
        tone = math.sin(phase * 2 * math.pi) * env * 0.15
        samples.append((prev + tone) * 0.8)
    return samples


def gen_hihat_closed(duration: float = 0.08) -> list[float]:
    """Closed hi-hat: very short high-frequency noise."""
    n = int(SAMPLE_RATE * duration)
    rng = random.Random(44)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.exp(-t * 60.0)
        noise = (rng.random() * 2.0 - 1.0) * env
        # High-pass via difference
        samples.append(noise * 0.7)
    # Simple high-pass: subtract low-pass
    hp = [0.0] * len(samples)
    prev = 0.0
    for i in range(len(samples)):
        prev += 0.08 * (samples[i] - prev)
        hp[i] = (samples[i] - prev) * 0.85
    return hp


def gen_hihat_open(duration: float = 0.3) -> list[float]:
    """Open hi-hat: longer metallic noise."""
    n = int(SAMPLE_RATE * duration)
    rng = random.Random(45)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.exp(-t * 8.0)
        noise = (rng.random() * 2.0 - 1.0) * env
        samples.append(noise * 0.6)
    # High-pass
    hp = [0.0] * len(samples)
    prev = 0.0
    for i in range(len(samples)):
        prev += 0.06 * (samples[i] - prev)
        hp[i] = (samples[i] - prev) * 0.8
    return hp


def gen_ride(duration: float = 0.8) -> list[float]:
    """Ride cymbal: long metallic shimmer."""
    n = int(SAMPLE_RATE * duration)
    rng = random.Random(46)
    samples = []
    phase1 = 0.0
    phase2 = 0.0
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.exp(-t * 4.0)
        noise = (rng.random() * 2.0 - 1.0) * env * 0.3
        # Add metallic tones at inharmonic frequencies
        phase1 += 835.0 / SAMPLE_RATE
        phase2 += 1247.0 / SAMPLE_RATE
        tone = (math.sin(phase1 * 2 * math.pi) * 0.2 +
                math.sin(phase2 * 2 * math.pi) * 0.15) * env
        samples.append((noise + tone) * 0.7)
    return samples


def gen_piano(root_hz: float, duration: float = 1.5) -> list[float]:
    """Piano: harmonics with fast attack, medium decay."""
    n = int(SAMPLE_RATE * duration)
    samples = []
    # Piano harmonics with decreasing amplitude
    harmonics = [1.0, 0.6, 0.3, 0.15, 0.08, 0.04]
    phases = [0.0] * len(harmonics)
    for i in range(n):
        t = i / SAMPLE_RATE
        # Fast attack, dual-stage decay (hammer + string)
        if t < 0.005:
            env = t / 0.005
        else:
            env = 0.3 * math.exp(-t * 5.0) + 0.7 * math.exp(-t * 1.5)
        s = 0.0
        for h in range(len(harmonics)):
            freq = root_hz * (h + 1)
            phases[h] += freq / SAMPLE_RATE
            # Higher harmonics decay faster
            h_env = env * math.exp(-t * h * 0.8)
            s += math.sin(phases[h] * 2 * math.pi) * harmonics[h] * h_env
        samples.append(s * 0.7)
    return samples


def gen_distorted_guitar(root_hz: float, duration: float = 1.5) -> list[float]:
    """Distorted electric guitar: clipped harmonics, gritty sustain."""
    n = int(SAMPLE_RATE * duration)
    samples = []
    phase = 0.0
    phase2 = 0.0
    for i in range(n):
        t = i / SAMPLE_RATE
        if t < 0.01:
            env = t / 0.01
        else:
            env = 0.15 * math.exp(-t * 0.5) + 0.85 * math.exp(-t * 2.0)
        phase += root_hz / SAMPLE_RATE
        phase2 += root_hz * 2.01 / SAMPLE_RATE
        # Raw signal with harmonics
        raw = (math.sin(phase * 2 * math.pi) +
               0.5 * math.sin(phase2 * 2 * math.pi) +
               0.3 * math.sin(phase * 3 * 2 * math.pi))
        # Hard clip for distortion
        raw *= 4.0
        raw = max(-1.0, min(1.0, raw))
        samples.append(raw * env * 0.75)
    return samples


def gen_bass_guitar(root_hz: float, duration: float = 1.0) -> list[float]:
    """Bass guitar: warm fundamental with subtle harmonics."""
    n = int(SAMPLE_RATE * duration)
    samples = []
    phases = [0.0, 0.0, 0.0]
    for i in range(n):
        t = i / SAMPLE_RATE
        if t < 0.008:
            env = t / 0.008
        else:
            env = 0.2 * math.exp(-t * 1.0) + 0.8 * math.exp(-t * 3.0)
        phases[0] += root_hz / SAMPLE_RATE
        phases[1] += root_hz * 2.0 / SAMPLE_RATE
        phases[2] += root_hz * 3.0 / SAMPLE_RATE
        s = (math.sin(phases[0] * 2 * math.pi) * 1.0 +
             math.sin(phases[1] * 2 * math.pi) * 0.3 +
             math.sin(phases[2] * 2 * math.pi) * 0.1)
        samples.append(s * env * 0.7)
    return samples


def gen_sax(root_hz: float, duration: float = 1.5) -> list[float]:
    """Saxophone: odd harmonics with vibrato and breathy noise."""
    n = int(SAMPLE_RATE * duration)
    rng = random.Random(47)
    samples = []
    phase = 0.0
    for i in range(n):
        t = i / SAMPLE_RATE
        if t < 0.05:
            env = t / 0.05
        else:
            env = 0.3 * math.exp(-t * 0.5) + 0.7 * math.exp(-t * 1.5)
        # Vibrato
        vib = 1.0 + 0.005 * math.sin(t * 5.5 * 2 * math.pi)
        freq = root_hz * vib
        phase += freq / SAMPLE_RATE
        # Odd harmonics dominate in sax
        s = (math.sin(phase * 2 * math.pi) * 1.0 +
             math.sin(phase * 3 * 2 * math.pi) * 0.5 +
             math.sin(phase * 5 * 2 * math.pi) * 0.25 +
             math.sin(phase * 7 * 2 * math.pi) * 0.12)
        # Breath noise
        noise = (rng.random() * 2.0 - 1.0) * 0.08
        samples.append((s * 0.6 + noise) * env)
    return samples


def gen_upright_bass(root_hz: float, duration: float = 1.2) -> list[float]:
    """Upright/double bass: warm woody tone."""
    n = int(SAMPLE_RATE * duration)
    samples = []
    phases = [0.0] * 4
    for i in range(n):
        t = i / SAMPLE_RATE
        if t < 0.02:
            env = t / 0.02
        else:
            env = 0.4 * math.exp(-t * 1.0) + 0.6 * math.exp(-t * 3.0)
        for h in range(4):
            phases[h] += root_hz * (h + 1) / SAMPLE_RATE
        # Fundamental strong, gentle harmonics
        s = (math.sin(phases[0] * 2 * math.pi) * 1.0 +
             math.sin(phases[1] * 2 * math.pi) * 0.35 +
             math.sin(phases[2] * 2 * math.pi) * 0.15 +
             math.sin(phases[3] * 2 * math.pi) * 0.05)
        samples.append(s * env * 0.65)
    return samples


def gen_synth_lead(root_hz: float, duration: float = 1.0) -> list[float]:
    """Synth lead: bright sawtooth with filter sweep."""
    n = int(SAMPLE_RATE * duration)
    samples = []
    phase = 0.0
    prev = 0.0
    for i in range(n):
        t = i / SAMPLE_RATE
        if t < 0.005:
            env = t / 0.005
        else:
            env = math.exp(-t * 1.5)
        phase += root_hz / SAMPLE_RATE
        # Band-limited sawtooth approximation
        s = 0.0
        for h in range(1, 12):
            s += math.sin(phase * h * 2 * math.pi) / h * ((-1) ** (h + 1))
        s *= 2.0 / math.pi
        # Filter sweep: cutoff decreases over time
        cutoff = 0.4 * math.exp(-t * 3.0) + 0.05
        prev += cutoff * (s - prev)
        samples.append(prev * env * 0.7)
    return samples


def gen_synth_bass(root_hz: float, duration: float = 0.8) -> list[float]:
    """Synth bass: fat square wave with sub."""
    n = int(SAMPLE_RATE * duration)
    samples = []
    phase = 0.0
    phase_sub = 0.0
    prev = 0.0
    for i in range(n):
        t = i / SAMPLE_RATE
        if t < 0.003:
            env = t / 0.003
        else:
            env = math.exp(-t * 3.0)
        phase += root_hz / SAMPLE_RATE
        phase_sub += root_hz * 0.5 / SAMPLE_RATE
        # Square wave + sub-octave sine
        sq = 1.0 if (phase % 1.0) < 0.5 else -1.0
        sub = math.sin(phase_sub * 2 * math.pi)
        raw = sq * 0.6 + sub * 0.5
        # Low-pass
        prev += 0.25 * (raw - prev)
        samples.append(prev * env * 0.8)
    return samples


def gen_violin(root_hz: float, duration: float = 2.0) -> list[float]:
    """Violin: bowed string with vibrato and rich harmonics."""
    n = int(SAMPLE_RATE * duration)
    samples = []
    phase = 0.0
    for i in range(n):
        t = i / SAMPLE_RATE
        # Slow attack (bowing)
        if t < 0.15:
            env = t / 0.15
        elif t > duration - 0.2:
            env = (duration - t) / 0.2
        else:
            env = 1.0
        env *= 0.7
        # Vibrato (delayed onset)
        vib_amount = min(t / 0.5, 1.0) * 0.006
        vib = 1.0 + vib_amount * math.sin(t * 5.8 * 2 * math.pi)
        freq = root_hz * vib
        phase += freq / SAMPLE_RATE
        # Sawtooth-ish (bowed string has all harmonics)
        s = 0.0
        for h in range(1, 10):
            amp = 1.0 / (h * 1.2)
            s += math.sin(phase * h * 2 * math.pi) * amp
        samples.append(s * env * 0.55)
    return samples


def main():
    print("Generating WAV samples...")

    drums_dir = os.path.join(BASE_DIR, "drums")
    melodic_dir = os.path.join(BASE_DIR, "melodic")

    # Drums
    print("\nDrums:")
    write_wav(os.path.join(drums_dir, "kick.wav"), gen_kick())
    write_wav(os.path.join(drums_dir, "snare.wav"), gen_snare())
    write_wav(os.path.join(drums_dir, "snare_brush.wav"), gen_snare_brush())
    write_wav(os.path.join(drums_dir, "hihat_closed.wav"), gen_hihat_closed())
    write_wav(os.path.join(drums_dir, "hihat_open.wav"), gen_hihat_open())
    write_wav(os.path.join(drums_dir, "ride.wav"), gen_ride())

    # Melodic
    print("\nMelodic:")
    write_wav(os.path.join(melodic_dir, "piano_c4.wav"), gen_piano(261.626))
    write_wav(os.path.join(melodic_dir, "piano_c2.wav"), gen_piano(65.406, duration=2.0))
    write_wav(os.path.join(melodic_dir, "guitar_dist_c3.wav"), gen_distorted_guitar(130.813))
    write_wav(os.path.join(melodic_dir, "bass_guitar_c2.wav"), gen_bass_guitar(65.406))
    write_wav(os.path.join(melodic_dir, "sax_c4.wav"), gen_sax(261.626))
    write_wav(os.path.join(melodic_dir, "upright_bass_c2.wav"), gen_upright_bass(65.406))
    write_wav(os.path.join(melodic_dir, "synth_lead_c4.wav"), gen_synth_lead(261.626))
    write_wav(os.path.join(melodic_dir, "synth_bass_c2.wav"), gen_synth_bass(65.406))
    write_wav(os.path.join(melodic_dir, "violin_c4.wav"), gen_violin(261.626))

    print(f"\nDone! {6 + 9} samples generated.")


if __name__ == "__main__":
    main()

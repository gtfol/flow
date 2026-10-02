#!/usr/bin/env python3
"""Original flow sound, reproducible offline with Python's standard library."""
from array import array
from pathlib import Path
import hashlib
import json
import math
import sys
import wave

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "Flow" / "Resources"
RATE = 24000
TAU = math.tau


def render(name, seconds, sample):
    pcm = array("h")
    peak = 0.0
    energy = 0.0
    frames = int(seconds * RATE)
    for index in range(frames):
        t = index / RATE
        for channel in range(2):
            value = sample(t, channel)
            assert abs(value) < 0.9, "unexpected synthesis peak"
            peak = max(peak, abs(value))
            energy += value * value
            pcm.append(round(value * 32767))
    if sys.byteorder != "little":
        pcm.byteswap()
    path = DEST / f"{name}.wav"
    with wave.open(str(path), "wb") as file:
        file.setnchannels(2)
        file.setsampwidth(2)
        file.setframerate(RATE)
        file.writeframes(pcm.tobytes())
    return {"file": path.name, "seconds": seconds, "sample_rate": RATE,
            "peak_dbfs": round(20 * math.log10(peak), 2),
            "rms_dbfs": round(20 * math.log10(math.sqrt(energy / (2 * frames))), 2),
            "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}


def ambient(t, channel):
    # No beat, breath-rate modulation, binaural-beat claims, or escalating intensity.
    fade = min(1.0, t / 1.2, (60 - t) / 1.2)
    envelope = math.sin(max(0, fade) * math.pi / 2) ** 2
    partials = [(110, .023), (165, .015), (220, .009), (275, .006), (330, .004)]
    return envelope * sum(
        gain * (0.78 + 0.12 * math.sin(TAU * t / (20 + 10 * i) + channel * .4))
        * math.sin(TAU * frequency * t + channel * (i + 1) * .13)
        for i, (frequency, gain) in enumerate(partials)
    )


def cue(frequency):
    def sample(t, channel):
        envelope = math.sin(math.pi * t / .8) ** 2 * math.exp(-2.5 * t)
        return .075 * envelope * (math.sin(TAU * frequency * t)
                                  + .2 * math.sin(TAU * frequency * 1.5 * t))
    return sample


def bell(t, channel):
    attack = min(1.0, t / 0.025)
    release = min(1.0, (8 - t) / 0.5)
    partials = [(440, .16, 1.4), (880.7, .055, .85), (1193, .025, .55)]
    return max(0, attack * release) * sum(gain * math.exp(-t / decay) * math.sin(TAU * frequency * t)
                                           for frequency, gain, decay in partials)


if __name__ == "__main__":
    DEST.mkdir(parents=True, exist_ok=True)
    results = [render("ambient", 60, ambient), render("inhale", .8, cue(440)),
               render("exhale", .8, cue(330)), render("bell", 8, bell)]
    (DEST / "audio-metrics.json").write_text(json.dumps(results, indent=2) + "\n")
    print(json.dumps(results, indent=2))

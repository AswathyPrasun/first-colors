#!/usr/bin/env python3
"""Synthesizes the app's original sound effects and music loop (no samples, no licenses).

Writes Resources/Audio/sfx_*.m4a and music_loop.m4a. Needs macOS `afconvert`.
Run from the repo root:  python3 scripts/make_sounds.py

Everything is soft and short on purpose: these play hundreds of times in a session.
"""
import math
import sys
import os
import random
import struct
import subprocess
import tempfile
import wave

RATE = 44100


def note(freq, dur, vol=0.3, attack=0.005, decay=6.0, shape="sine", partials=(1.0,)):
    """One plucked tone with an exponential decay."""
    out = []
    n = int(dur * RATE)
    for i in range(n):
        t = i / RATE
        env = min(1.0, t / attack) * math.exp(-decay * t)
        s = 0.0
        for k, amp in enumerate(partials, start=1):
            phase = 2 * math.pi * freq * k * t
            if shape == "triangle":
                s += amp * (2 / math.pi) * math.asin(math.sin(phase))
            else:
                s += amp * math.sin(phase)
        out.append(vol * env * s / sum(partials))
    return out


def mix(base, other, offset_s):
    start = int(offset_s * RATE)
    if len(base) < start + len(other):
        base.extend([0.0] * (start + len(other) - len(base)))
    for i, v in enumerate(other):
        base[start + i] += v
    return base


def fade(samples, ms=8):
    n = int(ms / 1000 * RATE)
    for i in range(min(n, len(samples))):
        samples[i] *= i / n
        samples[-1 - i] *= i / n
    return samples


def tap():
    return fade(note(1400, 0.05, vol=0.18, decay=70))


def pop():
    # A bubbly "bloop": pitch falls quickly while it fades.
    out = []
    dur = 0.16
    phase = 0.0
    for i in range(int(dur * RATE)):
        t = i / RATE
        freq = 380 + 520 * math.exp(-28 * t)
        phase += 2 * math.pi * freq / RATE
        env = min(1.0, t / 0.003) * math.exp(-22 * t)
        out.append(0.42 * env * math.sin(phase))
    return fade(out, 4)


def sparkle():
    out = []
    for k, f in enumerate([1568, 2093, 2637, 3136, 2637, 3520]):
        mix(out, note(f, 0.35, vol=0.12, decay=9, partials=(1.0, 0.3)), k * 0.07)
    return fade(out)


def cheer():
    out = []
    for k, f in enumerate([523.25, 659.25, 783.99, 1046.5]):
        mix(out, note(f, 0.9 - k * 0.12, vol=0.22, decay=3.5, shape="triangle"), k * 0.11)
    mix(out, note(1046.5, 0.8, vol=0.1, decay=3, partials=(1.0, 0.5, 0.25)), 0.44)
    return fade(out)


def crayon_loop():
    # Soft scratchy noise, gently pulsing like back-and-forth scribbling. Loops seamlessly:
    # the pulse completes whole cycles in exactly one second.
    rnd = random.Random(7)
    out = []
    low = 0.0
    dur = 1.0
    for i in range(int(dur * RATE)):
        t = i / RATE
        white = rnd.uniform(-1, 1)
        low += 0.18 * (white - low)          # one-pole low-pass
        scratch = white - low                # keep the hiss, drop the rumble
        pulse = 0.55 + 0.45 * math.sin(2 * math.pi * 4 * t) ** 2
        out.append(0.07 * pulse * scratch)
    return out


def music_loop():
    # 16 bars of a calm music-box tune in C major pentatonic, 96 bpm, loops exactly.
    beat = 60 / 96
    melody = [
        "E5", "G5", "A5", "G5", "E5", "D5", "C5", "D5",
        "E5", "G5", "C6", "A5", "G5", "E5", "D5", "-",
        "C5", "D5", "E5", "G5", "A5", "G5", "E5", "D5",
        "E5", "D5", "C5", "D5", "C5", "-", "-", "-",
    ]
    bass = ["C3", "A2", "F2", "G2"] * 2
    freqs = {"C3": 130.81, "A2": 110.0, "F2": 87.31, "G2": 98.0,
             "C5": 523.25, "D5": 587.33, "E5": 659.25, "G5": 783.99, "A5": 880.0, "C6": 1046.5}
    length = len(melody) * beat
    out = [0.0] * int(length * RATE)
    for k, name in enumerate(melody):
        if name != "-":
            mix(out, note(freqs[name], beat * 2, vol=0.1, decay=2.2, partials=(1.0, 0.25, 0.08)), k * beat)
    for k, name in enumerate(bass):
        mix(out, note(freqs[name], beat * 4, vol=0.07, decay=0.9, shape="triangle"), k * beat * 4)
    return out[: int(length * RATE)]


def vroom():
    # Finishing a vehicle: a soft toy-engine "vroom" that revs up and drives away.
    out = []
    dur = 0.9
    phase = 0.0
    for i in range(int(dur * RATE)):
        t = i / RATE
        freq = 70 + 90 * math.sin(math.pi * min(t / 0.6, 1.0) / 2) + 6 * math.sin(2 * math.pi * 22 * t)
        phase += 2 * math.pi * freq / RATE
        # Rounded saw-like tone: a few odd and even partials.
        tone = sum(math.sin(k * phase) / k for k in range(1, 7))
        env = min(1.0, t / 0.06) * (1.0 if t < 0.55 else math.exp(-6 * (t - 0.55)))
        out.append(0.16 * env * tone)
    return fade(out, 20)


def woof():
    # Finishing a Rescue Pup: a playful two-note "arf-arf" chime (a toy sound, not a real dog).
    out = []
    for k, start in enumerate([0.0, 0.2]):
        bark = []
        dur = 0.13
        phase = 0.0
        for i in range(int(dur * RATE)):
            t = i / RATE
            freq = (620 if k == 0 else 760) * (1.0 - 0.35 * t / dur)
            phase += 2 * math.pi * freq / RATE
            env = min(1.0, t / 0.008) * math.exp(-14 * t)
            bark.append(0.3 * env * (math.sin(phase) + 0.35 * math.sin(2 * phase) + 0.15 * math.sin(3 * phase)))
        mix(out, bark, start)
    mix(out, note(1318.5, 0.35, vol=0.08, decay=8), 0.34)
    return fade(out)


def whoosh():
    # Finishing a Super Kid: a quick airy swoosh rising past, with a tiny sparkle at the end.
    rnd = random.Random(11)
    out = []
    dur = 0.7
    low = band = 0.0
    for i in range(int(dur * RATE)):
        t = i / RATE
        white = rnd.uniform(-1, 1)
        # State-variable band-pass whose center sweeps upward.
        center = 300 + 2600 * (t / dur) ** 1.5
        f = 2 * math.sin(math.pi * center / RATE)
        low += f * band
        high = white - low - 0.6 * band
        band += f * high
        env = math.sin(math.pi * min(t / dur, 1.0)) ** 2
        out.append(0.5 * env * band)
    mix(out, note(2093, 0.25, vol=0.07, decay=10), 0.5)
    return fade(out, 10)


def write_m4a(name, samples, out_dir):
    peak = max(1e-9, max(abs(s) for s in samples))
    scale = min(1.0, 0.7 / peak)   # leave headroom (~-3 dB)
    with tempfile.TemporaryDirectory() as tmp:
        wav_path = os.path.join(tmp, name + ".wav")
        with wave.open(wav_path, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(RATE)
            w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s * scale)) * 32767)) for s in samples))
        out_path = os.path.join(out_dir, name + ".m4a")
        subprocess.run(["afconvert", "-f", "m4af", "-d", "aac", "-b", "96000", wav_path, out_path], check=True)
    print("wrote", out_path)


def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    out_dir = os.path.join(root, "Resources", "Audio")
    os.makedirs(out_dir, exist_ok=True)
    makers = {"sfx_tap": tap, "sfx_pop": pop, "sfx_sparkle": sparkle, "sfx_cheer": cheer,
              "sfx_crayon_loop": crayon_loop, "music_loop": music_loop,
              "sfx_vroom": vroom, "sfx_woof": woof, "sfx_whoosh": whoosh}
    # `python3 scripts/make_sounds.py sfx_vroom sfx_woof` regenerates only those.
    wanted = sys.argv[1:] or list(makers)
    for name in wanted:
        write_m4a(name, makers[name](), out_dir)


if __name__ == "__main__":
    main()

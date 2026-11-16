#!/usr/bin/env python3
"""Composes the placeholder background music: a cute, seamlessly looping
chiptune track -> assets/music/theme.wav. Replace that file (same name) with a
real track any time. Usage: python3 tools/gen_music.py   (needs numpy)
"""
import wave
from pathlib import Path

import numpy as np

RATE = 32000
BPM = 104
BEAT = 60.0 / BPM
OUT = Path(__file__).resolve().parent.parent / "assets" / "music"

CHORDS = {
    "C": [48, 52, 55], "Am": [45, 48, 52], "F": [41, 45, 48], "G": [43, 47, 50],
    "Em": [40, 43, 47], "E7": [40, 44, 47],
}
# One chord per half bar (2 beats).
PROG = (
    ["C", "C", "Am", "Am", "F", "F", "G", "G", "C", "C", "Am", "Am", "F", "G", "C", "C"]
    + ["F", "F", "G", "G", "Em", "Em", "Am", "Am", "F", "F", "G", "G", "C", "E7", "C", "C"]
)
R = -1
MELODY = [
    (76, 1), (79, 1), (84, 1), (79, .5), (76, .5),
    (81, 1.5), (79, .5), (76, 1), (72, 1),
    (77, 1), (81, 1), (84, 1.5), (81, .5),
    (79, 1.5), (77, .5), (76, 1), (74, 1),
    (76, .5), (76, .5), (79, 1), (84, 1), (86, 1),
    (84, 1.5), (81, .5), (79, 1), (76, 1),
    (77, 1), (81, 1), (79, 1), (74, 1),
    (72, 3), (R, 1),
    (81, 1), (84, 1), (81, 1), (77, 1),
    (79, 1.5), (81, .5), (83, 1), (86, 1),
    (83, 1), (79, 1), (76, 1.5), (79, .5),
    (81, 2), (R, 1), (76, 1),
    (77, .5), (81, .5), (84, 1), (89, 1), (88, 1),
    (86, 1.5), (84, .5), (83, 1), (79, 1),
    (84, 1), (88, 1), (91, 1), (88, 1),
    (84, 3), (R, 1),
]
TOTAL_BEATS = 64
N = int(TOTAL_BEATS * BEAT * RATE)


def hz(m):
    return 440.0 * 2 ** ((m - 69) / 12.0)


def pulse(freq, n, duty=0.25, vib=0.0, t0=0.0):
    t = np.arange(n) / RATE
    f = freq * (1 + vib * np.sin(2 * np.pi * 5.5 * (t + t0)) * np.clip(t * 4 - 0.6, 0, 1))
    ph = np.cumsum(f) / RATE
    return np.where((ph % 1.0) < duty, 1.0, -1.0)


def tri(freq, n):
    ph = np.arange(n) * freq / RATE
    return 2 * np.abs(2 * (ph % 1.0) - 1) - 1


def adsr(n, a=0.01, d=0.08, s=0.6, r=0.06):
    env = np.full(n, s)
    na, nd, nr = int(a * RATE), int(d * RATE), int(r * RATE)
    na = min(na, n)
    env[:na] = np.linspace(0, 1, na, endpoint=False)
    nd = min(nd, n - na)
    env[na:na + nd] = np.linspace(1, s, nd, endpoint=False)
    nr = min(nr, n)
    env[n - nr:] *= np.linspace(1, 0, nr)
    return env


def add(buf, start, sig):
    start = int(start)
    end = start + len(sig)
    if end <= len(buf):
        buf[start:end] += sig
    else:  # wrap around so the loop is seamless
        cut = len(buf) - start
        buf[start:] += sig[:cut]
        buf[:end - len(buf)] += sig[cut:]


def lowpass(x, alpha):
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += alpha * (x[i] - acc)
        y[i] = acc
    return y


def main():
    lead = np.zeros(N)
    echo = np.zeros(N)
    bass = np.zeros(N)
    arp = np.zeros(N)
    drums = np.zeros(N)
    rng = np.random.default_rng(3)

    # Lead melody (soft pulse + vibrato) and a quiet echo.
    t = 0.0
    for m, beats in MELODY:
        n = int(beats * BEAT * RATE)
        if m != R:
            s = pulse(hz(m), n, 0.25, 0.006) * adsr(n, 0.008, 0.12, 0.55, 0.08)
            add(lead, t * BEAT * RATE, s)
            add(echo, (t + 0.75) * BEAT * RATE, s * 0.35)
        t += beats

    # Bass: bouncy root / octave eighth notes. Arp: chord tones in 16ths.
    for i, ch in enumerate(PROG):
        notes = CHORDS[ch]
        base = i * 2 * BEAT * RATE
        for k in range(4):
            m = notes[0] - 12 + (12 if k % 2 else 0)
            n = int(BEAT * 0.5 * RATE * 0.9)
            add(bass, base + k * BEAT * 0.5 * RATE, tri(hz(m), n) * adsr(n, 0.005, 0.05, 0.7, 0.03))
        for k in range(8):
            m = notes[[0, 1, 2, 1][k % 4]] + 24
            n = int(BEAT * 0.25 * RATE * 0.8)
            add(arp, base + k * BEAT * 0.25 * RATE, pulse(hz(m), n, 0.125) * adsr(n, 0.002, 0.04, 0.3, 0.02))

    # Drums: kick on 1 and 3, soft snare on 2 and 4, hats on eighths.
    for b in range(TOTAL_BEATS):
        start = b * BEAT * RATE
        if b % 2 == 0:
            n = int(0.18 * RATE)
            tt = np.arange(n) / RATE
            f = 120 * np.exp(-tt * 25) + 45
            add(drums, start, np.sin(2 * np.pi * np.cumsum(f) / RATE) * np.exp(-tt * 18) * 0.9)
        else:
            n = int(0.12 * RATE)
            tt = np.arange(n) / RATE
            add(drums, start, rng.uniform(-1, 1, n) * np.exp(-tt * 30) * 0.28)
        for h in range(2):
            n = int(0.03 * RATE)
            tt = np.arange(n) / RATE
            hat = rng.uniform(-1, 1, n)
            hat = hat - np.concatenate([[0], hat[:-1]])  # crude highpass
            add(drums, start + h * BEAT * 0.5 * RATE, hat * np.exp(-tt * 120) * (0.12 if h else 0.16))

    mix = lead * 0.28 + echo * 0.28 + bass * 0.34 + arp * 0.07 + drums * 0.5
    mix = lowpass(mix, 0.55)
    mix = mix / max(1e-6, np.max(np.abs(mix))) * 0.85
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / "theme.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes((mix * 32767).astype("<i2").tobytes())
    print("wrote theme.wav", round(N / RATE, 1), "s")


if __name__ == "__main__":
    main()

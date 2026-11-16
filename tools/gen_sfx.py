#!/usr/bin/env python3
"""Generates placeholder sound effects into assets/sounds/ (16-bit mono WAV).

Replace any file with a real recording of the same name and the game uses it.
Usage: python3 tools/gen_placeholder_sfx.py   (standard library only)
"""
import math
import random
import struct
import wave
from pathlib import Path

RATE = 22050
OUT = Path(__file__).resolve().parent.parent / "assets" / "sounds"
random.seed(7)


def write(name, samples):
    peak = max(1e-6, max(abs(s) for s in samples))
    gain = 0.9 / peak
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s * gain)) * 32767)) for s in samples))
    print("wrote", name)


def n(sec):
    return int(sec * RATE)


def env(i, total, attack=0.005, curve=2.0):
    t = i / RATE
    a = min(1.0, t / attack) if attack > 0 else 1.0
    return a * (1.0 - i / total) ** curve


def lowpass(samples, alpha):
    out, y = [], 0.0
    for s in samples:
        y += alpha * (s - y)
        out.append(y)
    return out


def noise(sec, curve=2.0, attack=0.002):
    total = n(sec)
    return [random.uniform(-1, 1) * env(i, total, attack, curve) for i in range(total)]


def tone(freq_fn, sec, wave_fn=math.sin, curve=1.5, attack=0.005):
    total = n(sec)
    out, ph = [], 0.0
    for i in range(total):
        ph += 2 * math.pi * freq_fn(i / total) / RATE
        out.append(wave_fn(ph) * env(i, total, attack, curve))
    return out


def square(ph):
    return 1.0 if math.sin(ph) >= 0 else -1.0


def saw(ph):
    return ((ph / (2 * math.pi)) % 1.0) * 2 - 1


def mix(*parts):
    length = max(len(p) for p in parts)
    return [sum(p[i] if i < len(p) else 0 for p in parts) for i in range(length)]


def concat(*parts):
    out = []
    for p in parts:
        out.extend(p)
    return out


def silence(sec):
    return [0.0] * n(sec)


def arp(freqs, step=0.07, wave=square, tail=0.25):
    parts = [tone(lambda t, f=f: f, step, wave, 1) for f in freqs[:-1]]
    parts.append(tone(lambda t, f=freqs[-1]: f, tail, wave, 2))
    return concat(*parts)


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    # Wheat being pressed flat: soft crunchy swish.
    write("rustle", lowpass(noise(0.12, 2.0, 0.02), 0.25))
    write("stomp", mix(lowpass(noise(0.08, 3), 0.2), [x * 0.6 for x in tone(lambda t: 160 - 80 * t, 0.07, math.sin, 3)]))
    # Crop circle locks in: shimmering rising chime.
    write("lock", mix(arp([523, 784, 1047, 1568], 0.05, math.sin, 0.5), [x * 0.3 for x in arp([659, 988, 1319, 1976], 0.05, square, 0.4)]))
    write("lock_big", mix(arp([392, 523, 659, 784, 1047, 1319, 1568], 0.06, math.sin, 0.9), [x * 0.25 for x in arp([196, 262, 330, 392, 523], 0.08, square, 0.8)]))
    write("coin", concat(tone(lambda t: 1760, 0.04, square, 1), tone(lambda t: 2637, 0.12, square, 2)))
    write("moo", lowpass(tone(lambda t: 140 - 30 * t + 8 * math.sin(t * 20), 0.7, saw, 0.8, 0.08), 0.12))
    # Abduction beam: wobbly rising sine.
    write("beam", tone(lambda t: 300 + 900 * t + 60 * math.sin(t * 90), 1.0, math.sin, 0.6, 0.05))
    write("ufo", lowpass(tone(lambda t: 220 + 40 * math.sin(t * 40), 0.9, saw, 0.5, 0.1), 0.3))
    # Slot machine.
    write("reel", lowpass(tone(lambda t: 900, 0.025, square, 3), 0.6))
    write("clunk", mix(tone(lambda t: 180 - 90 * t, 0.12, square, 3), lowpass(noise(0.08, 3), 0.3)))
    write("jackpot", concat(arp([523, 659, 784, 1047, 784, 1047, 1319], 0.08), arp([1047, 1319, 1568, 2093], 0.06, square, 0.6)))
    write("win", arp([659, 784, 1047, 1319], 0.07, square, 0.3))
    write("lose", lowpass(concat(tone(lambda t: 392 - 20 * t, 0.22, saw, 0.5), tone(lambda t: 370 - 20 * t, 0.22, saw, 0.5), tone(lambda t: 349 - 60 * t, 0.6, saw, 1.0)), 0.25))
    write("lever", mix(tone(lambda t: 300 - 200 * t, 0.15, square, 2), lowpass(noise(0.12, 2), 0.4)))
    # Harvester engine.
    write("harvest", lowpass([math.sin(2 * math.pi * (55 + 10 * math.sin(i / RATE * 9)) * i / RATE) * (0.6 + 0.4 * random.random()) * env(i, n(3.0), 0.3, 0.6) for i in range(n(3.0))], 0.15))
    write("pop", tone(lambda t: 500 + 900 * t, 0.06, math.sin, 2))
    write("hover", tone(lambda t: 1500, 0.015, square, 2))
    write("combo", arp([880, 1175], 0.04, square, 0.1))

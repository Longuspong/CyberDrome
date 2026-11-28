#!/usr/bin/env python3
"""
Kampftoene (28. Nov. 2026, Wunsch des Spielers): ein Ton je Waffe.

Selbst synthetisiert (numpy, fester Seed) statt aus BeepBox: kurze Einzeltoene
mit Tonhoehen-Fahrten, Rauschen und Huellkurven lassen sich so genau formen
und bleiben winzig (Mono, 22 050 Hz, 16 Bit, je unter 20 KB). Stil passend
zur Musik: Synthwave/Arcade, kein Realismus.

    python3 tools/build_sfx.py           # schreibt assets/sfx/*.wav

Das Spiel spielt sie ueber ``BattleSfx`` (scripts/ui/battle_sfx.gd); welche
Datei zu welcher Waffe gehoert, steht dort in ``WEAPON_SOUNDS``.
"""
import pathlib
import wave

import numpy as np

ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "sfx"
RATE = 22050
rng = np.random.default_rng(28112026)


def t_axis(seconds):
    return np.arange(int(RATE * seconds)) / RATE


def sweep(f0, f1, seconds, curve=2.0):
    """Frequenz von f0 nach f1 (exponentiell geformt) -> Phase."""
    t = t_axis(seconds)
    k = (t / seconds) ** (1.0 / curve)
    freq = f0 * (f1 / f0) ** k
    return 2 * np.pi * np.cumsum(freq) / RATE


def env(seconds, attack=0.004, decay=None, power=2.0):
    t = t_axis(seconds)
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    d = (1 - np.clip(t / (decay or seconds), 0, 1)) ** power
    return a * d


def square(phase, duty=0.5):
    return np.where((phase / (2 * np.pi)) % 1.0 < duty, 1.0, -1.0)


def saw(phase):
    return 2 * ((phase / (2 * np.pi)) % 1.0) - 1


def tri(phase):
    return 2 * np.abs(saw(phase)) - 1


def noise(seconds):
    return rng.uniform(-1, 1, int(RATE * seconds))


def lowpass(x, cutoff):
    """Einpoliger Tiefpass; cutoff fest oder als Kurve je Sample."""
    cut = np.broadcast_to(np.asarray(cutoff, dtype=float), x.shape)
    a = 1 - np.exp(-2 * np.pi * cut / RATE)
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += a[i] * (v - acc)
        y[i] = acc
    return y


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[:len(p)] += p
    return out


def write(name, x, peak=0.8):
    x = x / max(1e-6, np.max(np.abs(x))) * peak
    # Kurzes Ausblenden gegen Knacken am Ende.
    fade = min(len(x), int(RATE * 0.008))
    x[-fade:] *= np.linspace(1, 0, fade)
    data = (np.clip(x, -1, 1) * 32767).astype("<i2")
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data.tobytes())
    return OUT / f"{name}.wav"


# ------------------------------------------------------------------ Toene

def blaster():
    """Puls-Blaster: kurzer Laser-Zap, Rechteck faellt 1700 -> 260 Hz."""
    s = 0.16
    tone = square(sweep(1700, 260, s, 1.6), 0.35) * env(s, 0.002, s, 2.2)
    sub = np.sin(sweep(420, 90, s)) * env(s, 0.002, s * 0.6) * 0.5
    hiss = highpass(noise(s), 3000) * env(s, 0.001, 0.04) * 0.35
    return lowpass(mix(tone * 0.6, sub, hiss), 6000)


def rail_lance():
    """Railgun-Lanze: harter Knall, hoher Pfiff, tiefes Nachdroehnen."""
    s = 0.42
    crack = highpass(noise(s), 1200) * env(s, 0.001, 0.05, 1.5)
    whine = saw(sweep(3200, 700, s * 0.5, 1.2)) * env(s * 0.5, 0.001, s * 0.5, 2.5) * 0.35
    boom = np.sin(sweep(140, 45, s, 1.5)) * env(s, 0.003, s, 1.6)
    return lowpass(mix(crack * 0.7, whine, boom * 0.9), 7000)


def rune_staff():
    """Runenstab: kurze aufsteigende Dreieck-Arpeggio-Glocke mit Schimmer."""
    s = 0.26
    out = np.zeros(int(RATE * s))
    for i, f in enumerate((587.3, 880.0, 1174.7)):
        start = int(RATE * 0.035 * i)
        n = len(out) - start
        seg = n / RATE
        tone = (tri(sweep(f, f * 1.01, seg)) + 0.5 * np.sin(sweep(f * 2.01, f * 2.0, seg))) \
            * env(seg, 0.003, seg, 2.4)
        out[start:] += tone * (0.6 + 0.2 * i)
    shimmer = highpass(noise(s), 5000) * env(s, 0.01, s, 3) * 0.15
    return mix(out, shimmer)


def repair_kit():
    """Repair-Kit: freundlicher Doppel-Bleep."""
    s = 0.09
    a = np.sin(sweep(880, 900, s)) * env(s, 0.003, s, 1.8)
    b = np.sin(sweep(1320, 1340, s)) * env(s, 0.003, s, 1.8)
    gap = np.zeros(int(RATE * 0.03))
    return np.concatenate([a, gap, b * 0.9])


def hammer():
    """Hammer: schwerer, dumpfer Schlag mit Klick."""
    s = 0.34
    thud = np.sin(sweep(110, 38, s, 1.3)) * env(s, 0.002, s, 1.8)
    click = lowpass(noise(s), 2500) * env(s, 0.001, 0.03) * 0.8
    body = lowpass(noise(s), np.linspace(900, 120, int(RATE * s))) * env(s, 0.002, 0.18) * 0.7
    return mix(thud, click, body)


def plasma_blade():
    """Plasmaklinge: summendes Zischen, das schnell vorbeizieht."""
    s = 0.22
    buzz = saw(sweep(180, 260, s)) * env(s, 0.02, s, 1.5) * 0.5
    swish = lowpass(noise(s), np.geomspace(800, 5000, int(RATE * s))) \
        * np.sin(np.linspace(0, np.pi, int(RATE * s))) ** 2
    return highpass(mix(buzz, swish), 120)


def deflector():
    """Deflektor (Schildschlag): metallisches Klonk aus unharmonischen Teiltoenen."""
    s = 0.24
    out = np.zeros(int(RATE * s))
    for f, amp, dec in ((310, 1.0, 0.22), (523, 0.6, 0.15), (841, 0.45, 0.1), (1290, 0.3, 0.06)):
        out += np.sin(sweep(f, f * 0.98, s)) * env(s, 0.001, dec, 2.0) * amp
    hit = lowpass(noise(s), 3000) * env(s, 0.001, 0.02) * 0.6
    return mix(out, hit)


SOUNDS = {
    "blaster": blaster, "rail_lance": rail_lance, "rune_staff": rune_staff,
    "repair_kit": repair_kit, "hammer": hammer, "plasma_blade": plasma_blade,
    "deflector": deflector,
}


if __name__ == "__main__":
    for name, make in SOUNDS.items():
        path = write(name, make())
        print(f"{path.relative_to(ROOT)}  {path.stat().st_size // 1024} KB")

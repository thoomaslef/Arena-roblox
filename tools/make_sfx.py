#!/usr/bin/env python3
"""Génère les sons de Cavale — portage de autoload/sfx.gd du jeu Godot (synthèse par code).

Tous les sons sont mis bout à bout dans UNE seule « planche de sons » :
  assets/sfx/cavale_sfx.wav  (et .ogg si ffmpeg est installé)
et leurs positions (début, fin en secondes) sont écrites dans :
  src/shared/SfxAtlas.lua
Le jeu joue chaque son avec Sound.PlaybackRegion : un seul fichier à mettre en ligne sur Roblox.

Usage : python3 tools/make_sfx.py   (depuis la racine du dépôt ; nécessite numpy)
"""
import math
import os
import shutil
import struct
import subprocess
import sys

import numpy as np

RATE = 22050
GAP = 0.25  # silence entre deux sons (évite qu'un son déborde sur le suivant)
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
rng = np.random.default_rng(1234)


def buf(dur):
    return np.zeros(int(dur * RATE), dtype=np.float64)


def tone(b, f0, f1, amp, decay, square=False, start=0.0, dur=-1.0):
    """Balayage sinusoïdal / carré avec enveloppe exponentielle (_tone de sfx.gd)."""
    i0 = int(start * RATE)
    n = len(b) - i0 if dur < 0 else min(int(dur * RATE), len(b) - i0)
    if n <= 0:
        return
    i = np.arange(n)
    t = i / RATE
    k = i / max(n, 1)
    f = f0 + (f1 - f0) * k
    phase = np.cumsum(2 * math.pi * f / RATE)
    v = np.sin(phase)
    if square:
        v = np.where(v > 0, 0.6, -0.6)
    env = np.exp(-t * decay) * np.minimum(1.0, t * 400.0)
    b[i0:i0 + n] += v * amp * env


def noise(b, amp, decay, c0, c1, start=0.0):
    """Bruit filtré passe-bas, coupure qui glisse de c0 à c1 (_noise de sfx.gd)."""
    i0 = int(start * RATE)
    n = len(b) - i0
    if n <= 0:
        return
    r = rng.uniform(-1.0, 1.0, n)
    c = c0 + (c1 - c0) * (np.arange(n) / n)
    y = 0.0
    out = np.empty(n)
    for i in range(n):  # filtre récursif : boucle simple
        y += (r[i] - y) * c[i]
        out[i] = y
    t = np.arange(n) / RATE
    b[i0:] += out * amp * np.exp(-t * decay) * np.minimum(1.0, t * 300.0)


def build():
    s = {}
    b = buf(0.4); noise(b, 0.55, 9.0, 0.5, 0.08); tone(b, 190, 70, 0.5, 10.0); s["rocket"] = b
    b = buf(0.5); tone(b, 2600, 320, 0.35, 7.0); tone(b, 1300, 160, 0.25, 9.0, True); noise(b, 0.35, 25.0, 0.9, 0.6); s["rail"] = b
    b = buf(0.8); noise(b, 0.9, 5.5, 0.35, 0.03); tone(b, 70, 38, 0.7, 6.0); s["explosion"] = b
    b = buf(0.1); tone(b, 1500, 1500, 0.35, 30.0, True, 0.0, 0.04); tone(b, 2100, 2100, 0.35, 30.0, True, 0.04, 0.06); s["hit"] = b
    b = buf(0.32)
    tone(b, 1400, 1400, 0.3, 18.0, True, 0.0, 0.07); tone(b, 1900, 1900, 0.3, 18.0, True, 0.07, 0.07)
    tone(b, 2600, 2600, 0.3, 10.0, True, 0.14, 0.16); s["kill"] = b
    b = buf(0.28); tone(b, 200, 80, 0.5, 9.0, True); noise(b, 0.3, 14.0, 0.4, 0.1); s["hurt"] = b
    b = buf(0.1); tone(b, 240, 430, 0.22, 22.0); s["jump"] = b
    b = buf(0.09); noise(b, 0.4, 35.0, 0.15, 0.05); s["land"] = b
    # Pas : béton (3 variantes), sprint, métal, verre.
    for i in range(3):
        b = buf(0.13); tone(b, 105 + i * 12, 52, 0.5, 38.0); noise(b, 0.32, 48.0 + i * 6, 0.35 + i * 0.05, 0.08); s[f"step{i}"] = b
    b = buf(0.15); tone(b, 120, 55, 0.6, 30.0); noise(b, 0.5, 34.0, 0.6, 0.12); s["step_sprint"] = b
    for i in range(2):
        b = buf(0.22)
        tone(b, 95, 60, 0.32, 34.0); tone(b, 640 + i * 90, 610 + i * 90, 0.14, 16.0)
        tone(b, 1510 + i * 140, 1480 + i * 140, 0.07, 22.0); noise(b, 0.2, 60.0, 0.7, 0.2); s[f"step_metal{i}"] = b
    for i in range(2):
        b = buf(0.16)
        tone(b, 85, 55, 0.22, 45.0); tone(b, 2900 + i * 350, 2850 + i * 350, 0.11, 30.0)
        tone(b, 4300 + i * 300, 4250 + i * 300, 0.05, 40.0); noise(b, 0.12, 80.0, 0.85, 0.5); s[f"step_glass{i}"] = b
    b = buf(0.45); tone(b, 220, 1200, 0.35, 5.0); tone(b, 330, 1800, 0.12, 6.0); s["pad"] = b
    b = buf(0.4); noise(b, 0.5, 6.0, 0.05, 0.7); tone(b, 300, 900, 0.15, 6.0); s["accel"] = b
    b = buf(0.14); tone(b, 880, 880, 0.35, 12.0); s["beep"] = b
    b = buf(0.5); tone(b, 1320, 1320, 0.3, 5.0); tone(b, 660, 660, 0.25, 5.0); s["go"] = b
    # Sirène de police (Flics) : 1 s, deux montées-descentes.
    b = buf(1.0)
    t = np.arange(len(b)) / RATE
    f = 780.0 + 420.0 * (0.5 - 0.5 * np.cos(t * 2 * math.pi * 2.0))
    ph = np.cumsum(2 * math.pi * f / RATE)
    env = np.minimum(1.0, t * 30.0) * np.minimum(1.0, (1.0 - t) * 12.0)
    b += (np.sin(ph) * 0.55 + np.sin(ph * 2.0) * 0.12) * 0.32 * env
    s["siren"] = b
    # Coup de sifflet (Bandits) : trille rapide, deux coups.
    b = buf(0.75)
    t = np.arange(len(b)) / RATE
    on = ((t < 0.22) | ((t > 0.3) & (t < 0.72))).astype(float)
    trill = 0.55 + 0.45 * (0.5 + 0.5 * np.sin(t * 2 * math.pi * 38.0))
    ph = np.cumsum(2 * math.pi * (2850.0 + 60.0 * np.sin(t * 2 * math.pi * 38.0)) / RATE)
    env = on * np.minimum(1.0, t * 80.0)
    b += (np.sin(ph) * 0.28 * trill + (rng.random(len(b)) - 0.5) * 0.05) * env
    s["whistle"] = b
    b = buf(0.9)
    for i, n in enumerate([523.0, 659.0, 784.0, 1046.0]):
        tone(b, n, n, 0.22, 4.0, False, i * 0.11, 0.9 - i * 0.11)
    s["win"] = b
    b = buf(0.9)
    for i, n in enumerate([440.0, 349.0, 293.0, 220.0]):
        tone(b, n, n, 0.22, 4.0, True, i * 0.13, 0.9 - i * 0.13)
    s["lose"] = b
    b = buf(0.08); tone(b, 1250, 1250, 0.2, 30.0); s["tick"] = b
    b = buf(0.06); noise(b, 0.25, 60.0, 0.9, 0.9); s["empty"] = b
    b = buf(0.35); tone(b, 110, 110, 0.35, 3.0, True); tone(b, 116, 116, 0.25, 3.0, True); s["zone"] = b
    b = buf(0.07); tone(b, 720, 980, 0.18, 30.0); s["switch"] = b
    b = buf(0.7); noise(b, 0.5, 5.0, 0.4, 0.05); tone(b, 420, 55, 0.35, 4.0, True); s["death"] = b
    b = buf(0.05); tone(b, 1100, 1300, 0.15, 50.0); s["ui"] = b
    return s


def write_wav(path, samples):
    pcm = (np.clip(samples, -1.0, 1.0) * 32000.0).astype("<i2").tobytes()
    with open(path, "wb") as f:
        f.write(b"RIFF" + struct.pack("<I", 36 + len(pcm)) + b"WAVE")
        f.write(b"fmt " + struct.pack("<IHHIIHH", 16, 1, 1, RATE, RATE * 2, 2, 16))
        f.write(b"data" + struct.pack("<I", len(pcm)) + pcm)


def main():
    sounds = build()
    parts, regions, pos = [], [], 0.0
    gap = np.zeros(int(GAP * RATE))
    for name, b in sounds.items():
        start = pos
        parts.append(b)
        pos += len(b) / RATE
        regions.append((name, start, pos))
        parts.append(gap)
        pos += GAP
    atlas = np.concatenate(parts)

    out_dir = os.path.join(ROOT, "assets", "sfx")
    os.makedirs(out_dir, exist_ok=True)
    wav = os.path.join(out_dir, "cavale_sfx.wav")
    write_wav(wav, atlas)
    print(f"{wav} : {len(sounds)} sons, {len(atlas) / RATE:.1f} s")
    if shutil.which("ffmpeg"):
        ogg = os.path.join(out_dir, "cavale_sfx.ogg")
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "6", ogg], check=True)
        print(ogg)

    lua = os.path.join(ROOT, "src", "shared", "SfxAtlas.lua")
    with open(lua, "w", encoding="utf-8") as f:
        f.write("-- FICHIER GÉNÉRÉ par tools/make_sfx.py — ne pas modifier à la main.\n")
        f.write("-- Position de chaque son (début, fin en secondes) dans assets/sfx/cavale_sfx.wav.\n\n")
        f.write("return {\n")
        for name, a, z in regions:
            f.write(f"\t{name} = {{ {a:.4f}, {z:.4f} }},\n")
        f.write("}\n")
    print(lua)


if __name__ == "__main__":
    sys.exit(main())

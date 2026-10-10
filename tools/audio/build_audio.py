#!/usr/bin/env python3
"""Synthesises every sound effect (WAV) and music/ambience loop (OGG).

    python3 tools/audio/build_audio.py            # everything
    python3 tools/audio/build_audio.py sfx        # only effects
    python3 tools/audio/build_audio.py music boss # only some tracks

Requires numpy, scipy and ffmpeg with libvorbis. Output is deterministic
except for the Vorbis encoder.
"""
import os
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import numpy as np  # noqa: E402

import music  # noqa: E402
import sfx  # noqa: E402
from synth import SR, write_wav  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SFX_DIR = os.path.join(ROOT, "assets", "audio", "sfx")
MUSIC_DIR = os.path.join(ROOT, "assets", "audio", "music")


def report(name, x):
    peak = float(np.max(np.abs(x)))
    rms = float(np.sqrt(np.mean(np.square(x))))
    dur = len(x) / SR
    print(f"  {name:14s} {dur:6.2f}s  peak {peak:.2f}  rms {rms:.3f}")
    if peak < 0.05 or not np.isfinite(x).all():
        raise RuntimeError(f"{name}: silent or invalid output")


def trim_tail(x, threshold=0.003, keep=0.05):
    """Drops the silent end of reverb tails."""
    idx = np.nonzero(np.abs(x) > threshold)[0]
    if len(idx) == 0:
        return x
    end = min(len(x), idx[-1] + int(keep * SR))
    out = x[:end].copy()
    f = min(len(out), int(0.02 * SR))
    out[-f:] *= np.linspace(1, 0, f)
    return out


def build_sfx(only=None):
    os.makedirs(SFX_DIR, exist_ok=True)
    for name, fn in sorted(sfx.ALL.items()):
        if only and name not in only:
            continue
        x = fn()
        x = x - np.mean(x)
        x = trim_tail(x)
        report(name, x)
        write_wav(os.path.join(SFX_DIR, name + ".wav"), x)


def build_music(only=None):
    os.makedirs(MUSIC_DIR, exist_ok=True)
    for name, fn in music.TRACKS.items():
        if only and name not in only:
            continue
        x = fn()
        report(name, x)
        with tempfile.TemporaryDirectory() as tmp:
            wav = os.path.join(tmp, name + ".wav")
            write_wav(wav, x)
            out = os.path.join(MUSIC_DIR, name + ".ogg")
            subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "4", out], check=True)


def main(argv):
    what = argv[0] if argv else "all"
    only = set(argv[1:]) or None
    if what in ("all", "sfx"):
        print("effects:")
        build_sfx(only)
    if what in ("all", "music"):
        print("music:")
        build_music(only)


if __name__ == "__main__":
    main(sys.argv[1:])

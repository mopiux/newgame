"""Tiny synthesis toolkit (numpy + scipy) used to create every sound of Lumbre.

All functions work on float32 mono arrays at SR samples per second unless
noted. Stereo helpers return arrays shaped (n, 2).
"""
import numpy as np
from scipy import signal

SR = 44100
RNG = np.random.default_rng(12345)


def seconds(n):
    return int(round(n * SR))


def t_axis(dur):
    return np.arange(seconds(dur)) / SR


# --- oscillators -----------------------------------------------------------------

def phase_from_freq(freq, dur=None):
    """freq: scalar or array (Hz per sample). Returns phase in cycles."""
    if np.isscalar(freq):
        freq = np.full(seconds(dur), float(freq))
    return np.cumsum(freq) / SR


def sine(freq, dur=None, phase0=0.0):
    ph = phase_from_freq(freq, dur)
    return np.sin(2 * np.pi * (ph + phase0)).astype(np.float32)


def tri(freq, dur=None):
    ph = phase_from_freq(freq, dur) % 1.0
    return (4 * np.abs(ph - 0.5) - 1).astype(np.float32)


def saw(freq, dur=None):
    ph = phase_from_freq(freq, dur) % 1.0
    return (2 * ph - 1).astype(np.float32)


def square(freq, dur=None, duty=0.5):
    ph = phase_from_freq(freq, dur) % 1.0
    return np.where(ph < duty, 1.0, -1.0).astype(np.float32)


def noise(dur, rng=RNG):
    return rng.uniform(-1, 1, seconds(dur)).astype(np.float32)


def brown(dur, rng=RNG):
    w = rng.normal(0, 1, seconds(dur))
    b = np.cumsum(w)
    b = signal.lfilter([1, -1], [1, -0.995], b)
    b /= np.max(np.abs(b)) + 1e-9
    return b.astype(np.float32)


def sweep(f0, f1, dur, curve="exp"):
    n = seconds(dur)
    if curve == "exp":
        return f0 * (f1 / f0) ** np.linspace(0, 1, n)
    return np.linspace(f0, f1, n)


# --- envelopes -------------------------------------------------------------------

def env_exp(dur, decay, attack=0.002):
    t = t_axis(dur)
    e = np.exp(-t / max(decay, 1e-4))
    a = np.clip(t / max(attack, 1e-5), 0, 1)
    return (e * a).astype(np.float32)


def env_adsr(dur, a=0.01, d=0.1, s=0.7, r=0.2):
    n = seconds(dur)
    t = np.arange(n) / SR
    e = np.ones(n) * s
    e[t < a] = t[t < a] / max(a, 1e-5)
    m = (t >= a) & (t < a + d)
    e[m] = 1 - (1 - s) * (t[m] - a) / max(d, 1e-5)
    rel_start = max(0.0, dur - r)
    m = t >= rel_start
    e[m] *= np.clip(1 - (t[m] - rel_start) / max(r, 1e-5), 0, 1)
    return e.astype(np.float32)


def fade(x, fin=0.005, fout=0.02):
    x = x.copy()
    a, b = seconds(fin), seconds(fout)
    if a > 0:
        x[:a] *= np.linspace(0, 1, a)
    if b > 0:
        x[-b:] *= np.linspace(1, 0, b)
    return x


# --- filters --------------------------------------------------------------------

def lowpass(x, cutoff, q=0.707):
    b, a = signal.iirfilter(2, min(cutoff, SR * 0.45) / (SR / 2), btype="low", ftype="butter")
    return signal.lfilter(b, a, x).astype(np.float32)


def highpass(x, cutoff):
    b, a = signal.iirfilter(2, min(cutoff, SR * 0.45) / (SR / 2), btype="high", ftype="butter")
    return signal.lfilter(b, a, x).astype(np.float32)


def bandpass(x, lo, hi):
    b, a = signal.iirfilter(2, [lo / (SR / 2), min(hi, SR * 0.45) / (SR / 2)], btype="band", ftype="butter")
    return signal.lfilter(b, a, x).astype(np.float32)


def sweep_lowpass(x, f0, f1, steps=32):
    """Time-varying lowpass approximated in blocks."""
    out = np.zeros_like(x)
    n = len(x)
    edges = np.linspace(0, n, steps + 1).astype(int)
    zi = None
    for i in range(steps):
        f = f0 * (f1 / f0) ** (i / max(1, steps - 1))
        b, a = signal.iirfilter(2, min(f, SR * 0.45) / (SR / 2), btype="low", ftype="butter")
        if zi is None:
            zi = signal.lfilter_zi(b, a) * 0
        seg, zi = signal.lfilter(b, a, x[edges[i]:edges[i + 1]], zi=zi)
        out[edges[i]:edges[i + 1]] = seg
    return out.astype(np.float32)


def soft_clip(x, drive=1.0):
    return np.tanh(x * drive).astype(np.float32)


# --- space ---------------------------------------------------------------------

def reverb(x, room=0.6, damp=3500.0, mix=0.3, predelay=0.01):
    """Small Schroeder reverb (4 combs + 2 allpasses)."""
    x = np.asarray(x, dtype=np.float64)
    tail = seconds(1.2 + room * 1.5)
    xin = np.concatenate([np.zeros(seconds(predelay)), x, np.zeros(tail)])
    xin = signal.lfilter(*signal.iirfilter(1, damp / (SR / 2), btype="low"), xin)
    combs = [1557, 1617, 1491, 1422]
    g = 0.7 + 0.25 * room
    wet = np.zeros_like(xin)
    for d in combs:
        a = np.zeros(d + 1)
        a[0] = 1.0
        a[d] = -g
        wet += signal.lfilter([1.0], a, xin)
    for d, ga in ((225, 0.5), (556, 0.5)):
        b = np.zeros(d + 1)
        b[0] = -ga
        b[d] = 1.0
        a = np.zeros(d + 1)
        a[0] = 1.0
        a[d] = -ga
        wet = signal.lfilter(b, a, wet)
    wet /= len(combs)
    dry = np.concatenate([x, np.zeros(len(xin) - len(x))])
    out = dry * (1 - mix) + wet * mix
    return out.astype(np.float32)


def normalize(x, peak=0.9):
    m = np.max(np.abs(x)) + 1e-9
    return (x / m * peak).astype(np.float32)


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n, dtype=np.float32)
    for p in parts:
        out[:len(p)] += p
    return out


def place(buf, x, at_sec, gain=1.0):
    i = seconds(at_sec)
    if i >= len(buf):
        return
    j = min(len(buf), i + len(x))
    buf[i:j] += x[:j - i] * gain


def stereo(x, pan=0.0, width=0.0):
    l = x * np.sqrt(0.5 * (1 - pan))
    r = x * np.sqrt(0.5 * (1 + pan))
    if width > 0:
        d = seconds(0.011)
        r = np.concatenate([np.zeros(d), r])[:len(r)] * (1 - width) + r * width
    return np.stack([l, r], axis=1).astype(np.float32)


# --- instruments ----------------------------------------------------------------

def midi_hz(n):
    return 440.0 * 2 ** ((n - 69) / 12.0)


def pluck(freq, dur, bright=0.5, decay=0.6):
    """Karplus-Strong string."""
    n = seconds(dur)
    period = max(2, int(SR / freq))
    buf = RNG.uniform(-1, 1, period)
    buf = signal.lfilter([1 - bright * 0.5], [1, -bright * 0.5], buf)
    out = np.zeros(n)
    fb = 0.996 if decay > 0.5 else 0.985
    for i in range(n):
        v = buf[i % period]
        out[i] = v
        buf[i % period] = fb * 0.5 * (v + buf[(i + 1) % period])
    return (out * env_exp(dur, decay * 1.5, 0.001)).astype(np.float32)


def bell(freq, dur, decay=1.2, bright=1.0):
    t = t_axis(dur)
    mod = np.sin(2 * np.pi * freq * 3.5 * t) * 2.2 * bright * np.exp(-t / (decay * 0.4))
    x = np.sin(2 * np.pi * freq * t + mod)
    x += 0.4 * np.sin(2 * np.pi * freq * 2.76 * t) * np.exp(-t / (decay * 0.5))
    return (x * env_exp(dur, decay, 0.003) * 0.6).astype(np.float32)


def pad(freq, dur, cutoff=1400.0, detune=0.006, attack=0.6, release=0.8):
    x = np.zeros(seconds(dur), dtype=np.float32)
    for d in (-detune, 0.0, detune):
        x += saw(freq * (1 + d), dur) / 3
    x += 0.3 * sine(freq / 2, dur)
    x = lowpass(x, cutoff)
    return x * env_adsr(dur, attack, 0.2, 0.85, release)


def organ(freq, dur, attack=0.05, release=0.3):
    x = sine(freq, dur) + 0.5 * sine(freq * 2, dur) + 0.25 * sine(freq * 3, dur) + 0.12 * sine(freq * 4, dur)
    return (x * 0.45 * env_adsr(dur, attack, 0.1, 0.9, release)).astype(np.float32)


def choir(freq, dur, vowel="a", attack=0.5, release=0.7):
    formants = {"a": (800, 1150, 2900), "o": (450, 800, 2830), "u": (325, 700, 2530)}[vowel]
    vib = 1 + 0.004 * np.sin(2 * np.pi * 5.0 * t_axis(dur))
    src = np.zeros(seconds(dur), dtype=np.float32)
    for d in (-0.004, 0.0, 0.005):
        src += saw(freq * (1 + d) * vib)
    out = np.zeros_like(src)
    for i, f in enumerate(formants):
        out += bandpass(src, f * 0.85, f * 1.15) * (1.0, 0.5, 0.25)[i]
    return (out * env_adsr(dur, attack, 0.2, 0.9, release) * 0.6).astype(np.float32)


def bass(freq, dur, cutoff=600.0):
    x = 0.7 * tri(freq, dur) + 0.3 * saw(freq, dur)
    x = lowpass(x, cutoff)
    return (x * env_adsr(dur, 0.005, 0.1, 0.8, 0.06)).astype(np.float32)


def lead(freq, dur, duty=0.25, cutoff=3000.0):
    vib = 1 + 0.006 * np.sin(2 * np.pi * 5.5 * t_axis(dur)) * np.clip(t_axis(dur) / 0.25, 0, 1)
    x = square(freq * vib, dur, duty)
    x = lowpass(x, cutoff)
    return (x * 0.35 * env_adsr(dur, 0.01, 0.08, 0.7, 0.08)).astype(np.float32)


def kick(dur=0.35, f0=120, f1=42):
    x = sine(sweep(f0, f1, dur), dur) * env_exp(dur, 0.12)
    x += 0.3 * lowpass(noise(dur), 2000) * env_exp(dur, 0.01)
    return soft_clip(x * 1.2)


def snare(dur=0.25):
    n = highpass(noise(dur), 1200) * env_exp(dur, 0.06)
    tone = sine(sweep(240, 180, dur), dur) * env_exp(dur, 0.05)
    return (n * 0.8 + tone * 0.5).astype(np.float32)


def hat(dur=0.06, open_=False):
    d = 0.18 if open_ else 0.03
    return (highpass(noise(max(dur, d * 3)), 7000) * env_exp(max(dur, d * 3), d) * 0.5).astype(np.float32)


def metal(freq, dur, decay=0.4):
    ratios = (1.0, 1.47, 2.09, 2.56, 3.91)
    x = np.zeros(seconds(dur), dtype=np.float32)
    for i, r in enumerate(ratios):
        x += sine(freq * r, dur) * env_exp(dur, decay / (1 + i * 0.4)) / (1 + i * 0.3)
    return x * 0.5


def write_wav(path, x, sr=SR):
    from scipy.io import wavfile
    x = np.asarray(x)
    x = np.clip(x, -1, 1)
    wavfile.write(path, sr, (x * 32767).astype(np.int16))

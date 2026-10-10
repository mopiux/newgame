"""Music and ambience composed as code. Each track renders a seamless loop."""
import numpy as np

from synth import (SR, bandpass, bass, bell, brown, choir, env_adsr, env_exp, hat, highpass,
                   kick, lead, lowpass, metal, midi_hz, noise, normalize, organ, pad, pluck,
                   reverb, seconds, sine, snare, sweep, t_axis)

# note names -> midi (octave 4 = middle)
NOTES = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5, "F#": 6, "Gb": 6,
         "G": 7, "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11}


def n(name):
    """'D4' -> 62, 'Bb3' -> 58."""
    pitch, octave = name[:-1], int(name[-1])
    return 12 * (octave + 1) + NOTES[pitch]


def chord(root, quality="m"):
    r = n(root)
    if quality == "m":
        return [r, r + 3, r + 7]
    if quality == "M":
        return [r, r + 4, r + 7]
    if quality == "dim":
        return [r, r + 3, r + 6]
    if quality == "sus":
        return [r, r + 5, r + 7]
    return [r, r + 7]


class Song:
    def __init__(self, bpm, beats_per_bar, bars):
        self.bpm = bpm
        self.bpb = beats_per_bar
        self.bars = bars
        self.beat = 60.0 / bpm
        self.length = self.beat * beats_per_bar * bars
        self.n = seconds(self.length)
        # render two passes so the loop includes the reverb tails of itself
        self.L = np.zeros(self.n * 2 + seconds(4), dtype=np.float32)
        self.R = np.zeros_like(self.L)
        self.sends = np.zeros_like(self.L)

    def add(self, x, beat, gain=1.0, pan=0.0, send=0.3):
        for rep in range(2):
            i = seconds(beat * self.beat) + rep * self.n
            j = min(len(self.L), i + len(x))
            seg = x[:j - i] * gain
            self.L[i:j] += seg * np.sqrt(0.5 * (1 - pan))
            self.R[i:j] += seg * np.sqrt(0.5 * (1 + pan))
            self.sends[i:j] += seg * send

    def render(self, room=0.7, damp=4000, wet=0.5):
        rev = reverb(self.sends, room, damp, 1.0)[:len(self.L)]
        rev = np.pad(rev, (0, max(0, len(self.L) - len(rev))))
        # cheap stereo widening of the reverb
        d = seconds(0.013)
        rev_r = np.concatenate([np.zeros(d), rev])[:len(rev)]
        L = self.L + rev * wet
        R = self.R + rev_r * wet
        out = np.stack([L[self.n:self.n * 2], R[self.n:self.n * 2]], axis=1)
        return normalize(out, 0.85)


def beats(song, b):
    return b * song.beat


# --- tracks ------------------------------------------------------------------------

def menu():
    s = Song(76, 3, 16)
    prog = [("D3", "m"), ("Bb2", "M"), ("G2", "m"), ("A2", "M"), ("D3", "m"), ("F2", "M"), ("G2", "m"), ("A2", "M")] * 2
    melody = [
        ["A5", "F5", "D5"], ["D5", "F5", "Bb5"], ["G5", "Bb5", "D6"], ["C#6", "A5", "E5"],
        ["F5", "E5", "D5"], ["C5", "A4", "F5"], ["G5", "F5", "E5"], ["E5", "C#5", "A4"],
        ["D5", "A5", "F5"], ["Bb5", "A5", "G5"], ["G5", "D5", "Bb4"], ["A4", "C#5", "E5"],
        ["F5", "A5", "D6"], ["C6", "A5", "F5"], ["E5", "G5", "Bb5"], ["A5", "C#5", "D5"],
    ]
    for bar, ((root, q), mel) in enumerate(zip(prog, melody)):
        b0 = bar * 3
        ch = chord(root, q)
        s.add(pad(midi_hz(ch[0] + 12), beats(s, 3.2), 900, attack=0.5, release=0.9) * 0.22, b0, pan=-0.2, send=0.5)
        s.add(pad(midi_hz(ch[1] + 12), beats(s, 3.2), 900, attack=0.5, release=0.9) * 0.18, b0, pan=0.2, send=0.5)
        s.add(bass(midi_hz(ch[0] - 12), beats(s, 1.5), 400) * 0.35, b0, send=0.1)
        for i, note in enumerate(mel):
            s.add(bell(midi_hz(n(note)), 1.6, 0.9, 0.6) * 0.42, b0 + i, pan=0.1 * (i - 1), send=0.6)
    return s.render(0.85, 3500, 0.55)


def plaza():
    s = Song(84, 3, 16)
    prog = [("F2", "M"), ("C3", "M"), ("D3", "m"), ("Bb2", "M"), ("F2", "M"), ("A2", "m"), ("Bb2", "M"), ("C3", "M")] * 2
    mel = [
        ["A4", "C5", "F5"], ["E5", "G5", "C5"], ["D5", "F5", "A5"], ["Bb4", "D5", "F5"],
        ["C5", "A4", "F4"], ["E4", "A4", "C5"], ["D5", "Bb4", "F5"], ["E5", "G5", "C6"],
        ["A5", "G5", "F5"], ["E5", "C5", "G4"], ["F5", "E5", "D5"], ["D5", "F5", "Bb5"],
        ["A5", "F5", "C5"], ["C5", "E5", "A5"], ["Bb5", "A5", "G5"], ["G5", "E5", "C5"],
    ]
    for bar, ((root, q), m) in enumerate(zip(prog, mel)):
        b0 = bar * 3
        ch = chord(root, q)
        s.add(pad(midi_hz(ch[0] + 12), beats(s, 3.1), 1300, attack=0.3) * 0.16, b0, pan=-0.3, send=0.4)
        s.add(pad(midi_hz(ch[2] + 12), beats(s, 3.1), 1300, attack=0.3) * 0.14, b0, pan=0.3, send=0.4)
        s.add(bass(midi_hz(ch[0]), beats(s, 1.0), 500) * 0.4, b0, send=0.05)
        for i in range(3):
            arp = ch[(i + 1) % 3] + 12
            s.add(pluck(midi_hz(arp), 0.8, 0.6, 0.5) * 0.3, b0 + i + 0.5, pan=0.4, send=0.3)
        for i, note in enumerate(m):
            s.add(bell(midi_hz(n(note)), 1.2, 0.8, 0.4) * 0.35, b0 + i, pan=-0.1, send=0.5)
    return s.render(0.7, 4500, 0.45)


def sewer():
    s = Song(84, 4, 16)
    prog = [("A2", "m"), ("F2", "M"), ("D2", "m"), ("E2", "M")] * 4
    rng = np.random.default_rng(11)
    drips = ["A5", "C6", "E6", "B5", "G5", "E5"]
    for bar, (root, q) in enumerate(prog):
        b0 = bar * 4
        ch = chord(root, q)
        s.add(pad(midi_hz(ch[0] + 12), beats(s, 4.2), 700, attack=1.0, release=1.2) * 0.2, b0, pan=-0.25, send=0.6)
        s.add(pad(midi_hz(ch[1] + 12), beats(s, 4.2), 700, attack=1.0, release=1.2) * 0.16, b0, pan=0.25, send=0.6)
        for b in (0, 1.5, 2.5):
            s.add(bass(midi_hz(ch[0] - 12 if ch[0] > 40 else ch[0]), beats(s, 0.9), 300) * 0.45, b0 + b, send=0.05)
        s.add(kick(0.4, 90, 38) * 0.45, b0, send=0.1)
        s.add(kick(0.4, 90, 38) * 0.3, b0 + 2.5, send=0.1)
        for e in range(8):
            s.add(hat(0.05) * (0.12 if e % 2 else 0.07), b0 + e * 0.5, pan=0.3, send=0.05)
        for _ in range(rng.integers(1, 4)):
            when = b0 + rng.integers(0, 8) * 0.5
            s.add(pluck(midi_hz(n(drips[rng.integers(0, len(drips))])), 1.2, 0.7, 0.6) * 0.32, when, pan=float(rng.uniform(-0.7, 0.7)), send=0.7)
        if bar % 4 == 3:
            s.add(bell(midi_hz(n("E5")), 2.5, 1.5, 0.5) * 0.3, b0 + 2, send=0.8)
    return s.render(0.8, 3000, 0.5)


def crypt():
    s = Song(66, 4, 12)
    prog = [("E2", "m"), ("F2", "M"), ("E2", "m"), ("D2", "m"), ("E2", "m"), ("F2", "M"),
            ("G2", "M"), ("F2", "M"), ("E2", "m"), ("C2", "M"), ("D2", "m"), ("E2", "sus")]
    line = ["B4", "C5", "B4", "A4", "G4", "A4", "B4", "C5", "B4", "G4", "A4", "B4"]
    for bar, (root, q) in enumerate(prog):
        b0 = bar * 4
        ch = chord(root, q)
        s.add(choir(midi_hz(ch[0] + 24), beats(s, 4.3), "o") * 0.2, b0, pan=-0.3, send=0.7)
        s.add(choir(midi_hz(ch[2] + 12), beats(s, 4.3), "o") * 0.17, b0, pan=0.3, send=0.7)
        s.add(organ(midi_hz(ch[0]), beats(s, 4.2), 0.3, 0.6) * 0.35, b0, send=0.4)
        if bar % 2 == 0:
            s.add(bell(midi_hz(ch[0] + 24), 4.0, 2.2, 0.8) * 0.35, b0, pan=0.1, send=0.8)
        s.add(choir(midi_hz(n(line[bar])), beats(s, 2.0), "a", 0.3, 0.5) * 0.18, b0 + 2, pan=0.0, send=0.7)
        s.add(kick(0.6, 70, 30) * 0.3, b0, send=0.4)
    return s.render(0.95, 2500, 0.6)


def foundry():
    s = Song(100, 4, 16)
    prog = [("C#2", "m"), ("C#2", "m"), ("A1", "M"), ("B1", "M")] * 4
    for bar, (root, q) in enumerate(prog):
        b0 = bar * 4
        ch = chord(root, q)
        for e in range(8):
            note = ch[0] + (12 if e in (3, 6) else 0)
            s.add(bass(midi_hz(note), beats(s, 0.45), 700) * 0.42, b0 + e * 0.5, send=0.05)
        s.add(pad(midi_hz(ch[1] + 12), beats(s, 4.1), 1100, attack=0.4) * 0.14, b0, pan=-0.3, send=0.5)
        s.add(pad(midi_hz(ch[2] + 12), beats(s, 4.1), 1100, attack=0.4) * 0.12, b0, pan=0.3, send=0.5)
        s.add(kick(0.3, 110, 40) * 0.5, b0, send=0.05)
        s.add(kick(0.3, 110, 40) * 0.4, b0 + 2, send=0.05)
        s.add(metal(420, 0.4, 0.2) * 0.25, b0 + 1, pan=-0.4, send=0.3)
        s.add(metal(310, 0.4, 0.2) * 0.25, b0 + 3, pan=0.4, send=0.3)
        for e in range(16):
            s.add(hat(0.04) * (0.1 if e % 4 == 2 else 0.05), b0 + e * 0.25, pan=0.2, send=0.02)
        if bar >= 4:
            arp = [ch[0] + 24, ch[1] + 24, ch[2] + 24, ch[1] + 24]
            for e in range(8):
                s.add(pluck(midi_hz(arp[e % 4]), 0.5, 0.8, 0.3) * 0.18, b0 + e * 0.5 + 0.25, pan=0.5 if e % 2 else -0.5, send=0.4)
    return s.render(0.6, 4000, 0.35)


def boss():
    s = Song(132, 4, 16)
    prog = [("D2", "m"), ("D2", "m"), ("Bb1", "M"), ("C2", "M"), ("D2", "m"), ("D2", "m"), ("G1", "m"), ("A1", "M")] * 2
    riff = ["D5", "F5", "A5", "G5", "F5", "E5", "D5", "C5"]
    for bar, (root, q) in enumerate(prog):
        b0 = bar * 4
        ch = chord(root, q)
        for e in range(8):
            s.add(bass(midi_hz(ch[0] + (12 if e % 2 else 0)), beats(s, 0.45), 900) * 0.45, b0 + e * 0.5, send=0.03)
        for b in (0, 1, 2, 3):
            s.add(kick(0.25, 130, 45) * 0.55, b0 + b, send=0.03)
        for b in (1, 3):
            s.add(snare(0.25) * 0.4, b0 + b, send=0.2)
        for e in range(8):
            s.add(hat(0.04) * 0.1, b0 + e * 0.5 + 0.25, pan=0.3, send=0.02)
        s.add(pad(midi_hz(ch[1] + 12), beats(s, 4), 1800, attack=0.05, release=0.3) * 0.12, b0, pan=-0.3, send=0.3)
        if bar >= 8:
            for e in range(8):
                note = n(riff[(e + bar) % len(riff)]) + (0 if bar % 4 < 2 else -2)
                s.add(lead(midi_hz(note), beats(s, 0.45), 0.25, 2600) * 0.32, b0 + e * 0.5, pan=0.1, send=0.25)
        else:
            s.add(lead(midi_hz(ch[2] + 24), beats(s, 1.8), 0.5, 2000) * 0.25, b0, send=0.3)
            s.add(lead(midi_hz(ch[1] + 24), beats(s, 1.8), 0.5, 2000) * 0.25, b0 + 2, send=0.3)
    return s.render(0.5, 4500, 0.3)


def boss_final():
    s = Song(140, 4, 16)
    prog = [("B1", "m"), ("G1", "M"), ("D2", "M"), ("A1", "M"), ("B1", "m"), ("G1", "M"), ("E2", "m"), ("F#2", "M")] * 2
    for bar, (root, q) in enumerate(prog):
        b0 = bar * 4
        ch = chord(root, q)
        for e in range(8):
            s.add(bass(midi_hz(ch[0] + (12 if e in (2, 5) else 0)), beats(s, 0.45), 1000) * 0.45, b0 + e * 0.5, send=0.03)
        for b in (0, 1.5, 2, 3.5):
            s.add(kick(0.25, 140, 40) * 0.55, b0 + b, send=0.03)
        for b in (1, 3):
            s.add(snare(0.3) * 0.45, b0 + b, send=0.25)
        for e in range(16):
            s.add(hat(0.04) * (0.12 if e % 2 else 0.06), b0 + e * 0.25, pan=-0.2, send=0.02)
        s.add(choir(midi_hz(ch[0] + 24), beats(s, 4.1), "a", 0.2, 0.4) * 0.22, b0, pan=-0.3, send=0.5)
        s.add(choir(midi_hz(ch[2] + 24), beats(s, 4.1), "a", 0.2, 0.4) * 0.2, b0, pan=0.3, send=0.5)
        arp = [ch[0] + 36, ch[1] + 36, ch[2] + 36, ch[1] + 36]
        for e in range(16):
            s.add(pluck(midi_hz(arp[e % 4]), 0.3, 0.9, 0.2) * 0.13, b0 + e * 0.25, pan=0.4, send=0.2)
        if bar % 2 == 1:
            s.add(bell(midi_hz(ch[0] + 36), 2.0, 1.0, 1.0) * 0.25, b0 + 3, send=0.6)
    return s.render(0.6, 4000, 0.35)


def victory():
    s = Song(96, 4, 8)
    prog = [("C3", "M"), ("G2", "M"), ("A2", "m"), ("F2", "M"), ("C3", "M"), ("F2", "M"), ("G2", "M"), ("C3", "M")]
    mel = ["C5", "E5", "G5", "C6", "B5", "G5", "A5", "E5", "F5", "A5", "C6", "A5", "G5", "E5", "D5", "C5"]
    for bar, (root, q) in enumerate(prog):
        b0 = bar * 4
        ch = chord(root, q)
        for c in ch:
            s.add(pad(midi_hz(c + 12), beats(s, 4.1), 2200, attack=0.2) * 0.12, b0, send=0.5)
        s.add(bass(midi_hz(ch[0]), beats(s, 2), 600) * 0.4, b0, send=0.1)
        s.add(bass(midi_hz(ch[0]), beats(s, 2), 600) * 0.35, b0 + 2, send=0.1)
        for i in range(2):
            s.add(bell(midi_hz(n(mel[(bar * 2 + i) % len(mel)])), 1.6, 1.0, 0.7) * 0.4, b0 + i * 2, send=0.6)
    return s.render(0.8, 6000, 0.5)


def defeat():
    s = Song(60, 4, 6)
    prog = [("A2", "m"), ("F2", "M"), ("D2", "m"), ("E2", "M"), ("A2", "m"), ("A2", "m")]
    line = ["E5", "D5", "C5", "B4", "A4", "A4"]
    for bar, (root, q) in enumerate(prog):
        b0 = bar * 4
        ch = chord(root, q)
        s.add(pad(midi_hz(ch[0] + 12), beats(s, 4.2), 800, attack=1.0, release=1.5) * 0.2, b0, pan=-0.2, send=0.6)
        s.add(pad(midi_hz(ch[1] + 12), beats(s, 4.2), 800, attack=1.0, release=1.5) * 0.16, b0, pan=0.2, send=0.6)
        s.add(pluck(midi_hz(n(line[bar])), 3.0, 0.5, 0.9) * 0.4, b0, send=0.6)
        s.add(pluck(midi_hz(n(line[bar]) - 12), 3.0, 0.5, 0.9) * 0.2, b0 + 2, send=0.6)
    return s.render(0.9, 3000, 0.55)


# --- ambiences (30 s loops) ----------------------------------------------------------

def _loop_crossfade(x, fade_s=2.0):
    """Makes a mono/stereo buffer loop seamlessly by crossfading its tail into the head."""
    f = seconds(fade_s)
    head = x[:f].copy()
    tail = x[-f:].copy()
    ramp = np.linspace(0, 1, f)
    if x.ndim == 2:
        ramp = ramp[:, None]
    blended = tail * (1 - ramp) + head * ramp
    out = x[f:].copy()
    out[-f:] = blended
    return out


def amb_drips():
    d = 32.0
    base = lowpass(brown(d), 160) * 0.35
    rng = np.random.default_rng(5)
    L = base.copy()
    R = base.copy()
    for _ in range(70):
        at = rng.uniform(0, d - 1)
        f = rng.uniform(900, 2200)
        drop = sine(sweep(f, f * 0.55, 0.12), 0.12) * env_exp(0.12, 0.03) * rng.uniform(0.1, 0.35)
        pan = rng.uniform(-1, 1)
        i = seconds(at)
        L[i:i + len(drop)] += drop * np.sqrt(0.5 * (1 - pan))
        R[i:i + len(drop)] += drop * np.sqrt(0.5 * (1 + pan))
    L = reverb(L, 0.85, 3000, 0.45)[:seconds(d)]
    R = reverb(R, 0.8, 3000, 0.45)[:seconds(d)]
    return normalize(_loop_crossfade(np.stack([L, R], axis=1)), 0.6)


def amb_wind():
    d = 32.0
    t = t_axis(d)
    gust = 0.55 + 0.45 * np.sin(2 * np.pi * t / 7.3) * np.sin(2 * np.pi * t / 3.1 + 1.0)
    L = bandpass(noise(d), 200, 900) * gust
    R = bandpass(noise(d), 220, 1000) * (0.55 + 0.45 * np.sin(2 * np.pi * t / 6.1 + 2.0))
    whistle = sine(600 + 80 * np.sin(2 * np.pi * t / 5.0), d) * 0.04 * gust
    return normalize(_loop_crossfade(np.stack([L + whistle, R + whistle * 0.7], axis=1)), 0.5)


def amb_hum():
    d = 32.0
    t = t_axis(d)
    hum = (np.sin(2 * np.pi * 55 * t) * 0.5 + np.sin(2 * np.pi * 110 * t) * 0.25 + np.sin(2 * np.pi * 165.5 * t) * 0.1)
    hum *= 0.8 + 0.2 * np.sin(2 * np.pi * t / 4.0)
    L = hum.astype(np.float32) * 0.5 + lowpass(brown(d), 300) * 0.3
    R = L.copy()
    rng = np.random.default_rng(9)
    for _ in range(14):
        at = rng.uniform(0, d - 2)
        c = metal(rng.uniform(150, 400), 1.5, 0.6) * rng.uniform(0.08, 0.2)
        pan = rng.uniform(-1, 1)
        i = seconds(at)
        L[i:i + len(c)] += c * np.sqrt(0.5 * (1 - pan))
        R[i:i + len(c)] += c * np.sqrt(0.5 * (1 + pan))
    L = reverb(L, 0.9, 2000, 0.5)[:seconds(d)]
    R = reverb(R, 0.85, 2000, 0.5)[:seconds(d)]
    return normalize(_loop_crossfade(np.stack([L, R], axis=1)), 0.55)


TRACKS = {"menu": menu, "plaza": plaza, "sewer": sewer, "crypt": crypt, "foundry": foundry,
          "boss": boss, "boss_final": boss_final, "victory": victory, "defeat": defeat,
          "amb_drips": amb_drips, "amb_wind": amb_wind, "amb_hum": amb_hum}

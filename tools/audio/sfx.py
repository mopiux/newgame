"""Sound effect recipes. Each function returns a mono float32 array."""
import numpy as np

from synth import (SR, bandpass, bell, brown, env_adsr, env_exp, fade, highpass, kick, lowpass,
                   metal, midi_hz, mix, noise, normalize, reverb, saw, seconds, sine, soft_clip,
                   square, sweep, sweep_lowpass, t_axis, tri)


def _n(x, peak=0.8):
    return fade(normalize(x, peak), 0.002, 0.01)


# --- player -------------------------------------------------------------------

def shoot():
    d = 0.16
    chirp = sine(sweep(1400, 520, d), d) * env_exp(d, 0.05)
    air = bandpass(noise(d), 1500, 6000) * env_exp(d, 0.03) * 0.5
    body = tri(sweep(420, 260, d), d) * env_exp(d, 0.06) * 0.4
    return _n(mix(chirp * 0.7, air, body), 0.7)


def swing():
    d = 0.2
    w = bandpass(noise(d), 300, 1800) * np.sin(np.linspace(0, np.pi, seconds(d))) ** 2
    return _n(w, 0.6)


def dash():
    d = 0.24
    w = sweep_lowpass(noise(d), 600, 5000, 16) * np.sin(np.linspace(0, np.pi, seconds(d)))
    return _n(w, 0.55)


def hurt():
    d = 0.32
    tone = square(sweep(420, 140, d), d, 0.4) * env_exp(d, 0.12)
    crunch = lowpass(noise(d), 1500) * env_exp(d, 0.05)
    return _n(soft_clip(lowpass(tone, 2200) * 0.7 + crunch * 0.6, 1.6), 0.85)


def fizzle():
    d = 0.22
    return _n(highpass(noise(d), 3000) * env_exp(d, 0.07) + sine(sweep(300, 120, d), d) * env_exp(d, 0.05) * 0.3, 0.45)


def flare():
    d = 0.9
    boom = sine(sweep(140, 40, d), d) * env_exp(d, 0.25)
    burst = lowpass(noise(d), 4000) * env_exp(d, 0.18)
    shimmer = sum(bell(midi_hz(n), d, 0.6) for n in (84, 88, 91)) * 0.25
    return _n(reverb(mix(boom, burst * 0.6, shimmer), 0.5, 4000, 0.25), 0.9)


def step():
    d = 0.05
    return _n(bandpass(noise(d), 300, 1100) * env_exp(d, 0.012), 0.4)


def heartbeat():
    d = 0.6
    out = np.zeros(seconds(d), dtype=np.float32)
    for at, amp in ((0.0, 1.0), (0.17, 0.7)):
        th = sine(sweep(70, 40, 0.15), 0.15) * env_exp(0.15, 0.05)
        i = seconds(at)
        out[i:i + len(th)] += th * amp
    return _n(lowpass(out, 400), 0.8)


def extinguish():
    d = 1.6
    hiss = sweep_lowpass(noise(d), 6000, 300, 24) * env_exp(d, 0.5)
    fall = sine(sweep(500, 60, d), d) * env_exp(d, 0.6) * 0.4
    return _n(reverb(mix(hiss * 0.7, fall), 0.7, 3000, 0.35), 0.8)


def phoenix():
    d = 1.4
    roar = sweep_lowpass(noise(d), 300, 6000, 24) * env_adsr(d, 0.4, 0.2, 0.6, 0.6)
    chord = sum(bell(midi_hz(n), d, 1.0) for n in (72, 76, 79, 84)) * 0.3
    return _n(reverb(mix(roar * 0.6, chord), 0.6, 5000, 0.3), 0.9)


def shield():
    d = 0.35
    thup = sine(sweep(260, 120, d), d) * env_exp(d, 0.06)
    ding = bell(midi_hz(88), d, 0.25) * 0.5
    return _n(mix(thup, ding), 0.7)


# --- world --------------------------------------------------------------------------

def ember():
    d = 0.09
    return _n(sine(sweep(1100, 1700, d), d) * env_exp(d, 0.03) + sine(2600, d) * env_exp(d, 0.015) * 0.3, 0.5)


def spark():
    d = 0.6
    x = bell(midi_hz(91), d, 0.35) + bell(midi_hz(96), d, 0.25) * 0.6
    return _n(reverb(x, 0.5, 6000, 0.3), 0.6)


def ignite():
    d = 0.7
    whoomp = sweep_lowpass(noise(d), 200, 3500, 16) * env_adsr(d, 0.06, 0.15, 0.4, 0.4)
    low = sine(sweep(90, 55, d), d) * env_exp(d, 0.2) * 0.6
    crackle = np.zeros(seconds(d), dtype=np.float32)
    rng = np.random.default_rng(3)
    for _ in range(18):
        i = rng.integers(seconds(0.1), seconds(d) - 200)
        crackle[i:i + 60] += highpass(noise(60 / SR, rng), 2000)[:60] * rng.uniform(0.3, 0.8)
    return _n(mix(whoomp, low, crackle * 0.5), 0.8)


def lamp_lit():
    d = 1.8
    base = ignite()
    chord = sum(sine(midi_hz(n), d) * env_adsr(d, 0.4, 0.3, 0.6, 0.8) for n in (60, 64, 67, 72)) * 0.18
    bells_ = sum(bell(midi_hz(n), d, 1.2) for n in (79, 84)) * 0.2
    return _n(reverb(mix(base * 0.8, chord, bells_), 0.7, 5000, 0.35), 0.85)


def door_close():
    d = 0.45
    clank = metal(220, d, 0.25)
    thud = sine(sweep(110, 60, d), d) * env_exp(d, 0.08)
    return _n(mix(clank, thud * 0.8, bandpass(noise(d), 800, 3000) * env_exp(d, 0.02) * 0.5), 0.75)


def door_open():
    d = 0.5
    grind = bandpass(noise(d), 200, 900) * env_adsr(d, 0.05, 0.1, 0.6, 0.15) * 0.6
    clank = metal(330, d, 0.15) * 0.6
    return _n(mix(grind, clank), 0.6)


def door_pass():
    d = 0.3
    return _n(lowpass(noise(d), 1200) * np.sin(np.linspace(0, np.pi, seconds(d))), 0.35)


def pot_break():
    d = 0.4
    crash = bandpass(noise(d), 1500, 7000) * env_exp(d, 0.06)
    clinks = sum(sine(f, d) * env_exp(d, 0.05) for f in (1800, 2600, 3400)) * 0.15
    thud = sine(sweep(160, 70, d), d) * env_exp(d, 0.05) * 0.5
    return _n(mix(crash, clinks, thud), 0.7)


def secret():
    d = 1.8
    notes = (69, 72, 76, 81)
    out = np.zeros(seconds(d), dtype=np.float32)
    for i, n in enumerate(notes):
        b = bell(midi_hz(n), 1.2, 0.8)
        j = seconds(i * 0.14)
        out[j:j + len(b)] += b[:len(out) - j]
    rumble = lowpass(brown(d), 200) * env_exp(d, 0.4) * 0.5
    return _n(reverb(mix(out, rumble), 0.8, 5000, 0.4), 0.8)


def room_clear():
    d = 1.2
    out = np.zeros(seconds(d), dtype=np.float32)
    for i, n in enumerate((67, 71, 74, 79)):
        b = bell(midi_hz(n), 0.9, 0.5)
        j = seconds(i * 0.09)
        out[j:j + len(b)] += b[:len(out) - j] * 0.8
    return _n(reverb(out, 0.6, 6000, 0.3), 0.6)


def relic():
    d = 1.6
    out = np.zeros(seconds(d), dtype=np.float32)
    for i, n in enumerate((72, 76, 79, 83, 84, 88)):
        b = bell(midi_hz(n), 1.0, 0.7)
        j = seconds(i * 0.07)
        out[j:j + len(b)] += b[:len(out) - j] * 0.7
    swell = sweep_lowpass(noise(d), 500, 8000, 16) * env_adsr(d, 0.3, 0.2, 0.3, 0.8) * 0.15
    return _n(reverb(mix(out, swell), 0.7, 7000, 0.35), 0.75)


def buy():
    d = 0.4
    return _n(metal(1200, d, 0.15) + np.concatenate([np.zeros(seconds(0.08)), metal(1600, d - 0.08, 0.15)]), 0.6)


def descend():
    d = 1.8
    sweep_down = sine(sweep(300, 40, d), d) * env_adsr(d, 0.05, 0.2, 0.7, 0.8)
    rumble = lowpass(brown(d), 180) * env_adsr(d, 0.3, 0.2, 0.8, 0.8)
    return _n(reverb(mix(sweep_down * 0.6, rumble), 0.8, 2500, 0.4), 0.85)


def wave():
    d = 1.0
    drone = (saw(55, d) + saw(55.6, d)) * 0.5
    drone = lowpass(drone, 500) * env_adsr(d, 0.3, 0.2, 0.6, 0.4)
    hiss = bandpass(noise(d), 400, 1500) * env_adsr(d, 0.5, 0.1, 0.4, 0.3) * 0.3
    return _n(reverb(mix(drone, hiss), 0.6, 2500, 0.3), 0.6)


def pause():
    d = 0.5
    return _n(bell(midi_hz(64), d, 0.4) * 0.6 + bell(midi_hz(71), d, 0.3) * 0.3, 0.5)


def ui_move():
    d = 0.04
    return _n(sine(1250, d) * env_exp(d, 0.012), 0.35)


def ui_select():
    d = 0.14
    a = sine(midi_hz(79), d) * env_exp(d, 0.04)
    b = np.concatenate([np.zeros(seconds(0.05)), sine(midi_hz(86), d - 0.05) * env_exp(d - 0.05, 0.04)])
    return _n(mix(a, b), 0.45)


def ui_back():
    d = 0.14
    a = sine(midi_hz(83), d) * env_exp(d, 0.04)
    b = np.concatenate([np.zeros(seconds(0.05)), sine(midi_hz(76), d - 0.05) * env_exp(d - 0.05, 0.04)])
    return _n(mix(a, b), 0.45)


# --- combat -----------------------------------------------------------------------

def hit():
    d = 0.09
    thump = sine(sweep(220, 90, d), d) * env_exp(d, 0.03)
    click = highpass(noise(d), 2500) * env_exp(d, 0.008) * 0.6
    return _n(mix(thump, click), 0.7)


def enemy_die():
    d = 0.5
    crumble = sweep_lowpass(noise(d), 3000, 300, 12) * env_exp(d, 0.14)
    drop = sine(sweep(260, 70, d), d) * env_exp(d, 0.12) * 0.6
    tinkle = sum(sine(f, d) * env_exp(d, 0.08) for f in (2200, 3100)) * 0.1
    return _n(mix(crumble, drop, tinkle), 0.7)


def deflect():
    d = 0.3
    return _n(metal(900, d, 0.15) + highpass(noise(d), 4000) * env_exp(d, 0.01) * 0.4, 0.65)


def bounce():
    d = 0.08
    return _n(sine(sweep(1800, 2400, d), d) * env_exp(d, 0.025), 0.35)


def explode():
    d = 0.6
    boom = sine(sweep(120, 35, d), d) * env_exp(d, 0.18)
    burst = lowpass(noise(d), 3000) * env_exp(d, 0.1)
    return _n(soft_clip(mix(boom, burst * 0.8), 1.5), 0.8)


def orb_cast():
    d = 0.35
    vib = 1 + 0.05 * np.sin(2 * np.pi * 18 * t_axis(d))
    whum = sine(sweep(240, 110, d) * vib, d) * env_adsr(d, 0.02, 0.1, 0.6, 0.15)
    airy = bandpass(noise(d), 300, 1200) * env_exp(d, 0.1) * 0.3
    return _n(mix(whum, airy), 0.6)


def slam():
    d = 0.7
    boom = sine(sweep(90, 30, d), d) * env_exp(d, 0.25)
    crack = bandpass(noise(d), 600, 4000) * env_exp(d, 0.05)
    debris = lowpass(noise(d), 1200) * env_exp(d, 0.2) * 0.3
    return _n(soft_clip(mix(boom * 1.2, crack, debris), 1.8), 0.9)


def shade_hiss():
    d = 0.45
    h = bandpass(noise(d), 2000, 6000) * env_adsr(d, 0.08, 0.1, 0.6, 0.2)
    formant = bandpass(noise(d), 700, 1100) * env_adsr(d, 0.08, 0.1, 0.5, 0.2) * 0.6
    return _n(mix(h, formant), 0.55)


def nest_pulse():
    d = 0.35
    am = 0.6 + 0.4 * np.sin(2 * np.pi * 22 * t_axis(d))
    return _n(sine(sweep(90, 60, d), d) * am * env_adsr(d, 0.03, 0.1, 0.6, 0.15) + lowpass(noise(d), 600) * env_exp(d, 0.08) * 0.3, 0.6)


def golem_roar():
    d = 0.8
    vib = 1 + 0.03 * np.sin(2 * np.pi * 7 * t_axis(d))
    g = lowpass(saw(sweep(85, 65, d) * vib, d) + saw(sweep(86, 66, d) * vib, d), 900)
    g = soft_clip(g * env_adsr(d, 0.08, 0.2, 0.7, 0.3), 2.0)
    return _n(g + lowpass(noise(d), 700) * env_adsr(d, 0.1, 0.1, 0.5, 0.3) * 0.3, 0.8)


def mimic_scream():
    d = 0.6
    wob = 1 + 0.15 * np.sin(2 * np.pi * 13 * t_axis(d))
    s = square(sweep(500, 320, d) * wob, d, 0.3) * env_adsr(d, 0.01, 0.1, 0.7, 0.2)
    return _n(soft_clip(lowpass(s, 3000) + highpass(noise(d), 2000) * env_exp(d, 0.2) * 0.4, 1.5), 0.75)


def bite():
    d = 0.15
    snap = highpass(noise(d), 1500) * env_exp(d, 0.01)
    thud = sine(sweep(200, 90, d), d) * env_exp(d, 0.04)
    return _n(mix(snap, thud), 0.7)


def blink():
    d = 0.35
    t = t_axis(d)
    fm = np.sin(2 * np.pi * sweep(1600, 300, d) * t + 3 * np.sin(2 * np.pi * 37 * t))
    return _n(fm * env_exp(d, 0.12) * 0.6 + highpass(noise(d), 5000) * env_exp(d, 0.05) * 0.2, 0.5)


def snuff():
    d = 1.3
    rev = sweep_lowpass(noise(d), 300, 3000, 20)[::-1] * np.linspace(0, 1, seconds(d)) ** 2
    low = sine(sweep(60, 40, d), d) * env_adsr(d, 0.6, 0.2, 0.7, 0.3) * 0.5
    return _n(reverb(mix(rev, low), 0.5, 2000, 0.3), 0.8)


def boss_screech():
    d = 0.7
    t = t_axis(d)
    car = sweep(1300, 900, d)
    fm = np.sin(2 * np.pi * car * t + 4 * np.sin(2 * np.pi * 61 * t))
    return _n(fm * env_adsr(d, 0.02, 0.1, 0.7, 0.25) * 0.6 + bandpass(noise(d), 2000, 6000) * env_exp(d, 0.2) * 0.3, 0.7)


def boss_phase():
    d = 1.2
    swell = sweep_lowpass(noise(d), 200, 4000, 20) * np.linspace(0, 1, seconds(d)) ** 3
    hitx = np.concatenate([np.zeros(seconds(0.9)), kick(0.3, 90, 30)])[:seconds(d)]
    return _n(reverb(mix(swell * 0.7, hitx), 0.6, 3000, 0.3), 0.85)


def boss_die():
    d = 3.0
    boom = sine(sweep(100, 25, d), d) * env_exp(d, 0.8)
    roar = sweep_lowpass(noise(d), 5000, 200, 32) * env_exp(d, 0.9)
    scream = sine(sweep(900, 120, d), d) * env_exp(d, 0.7) * 0.3
    chord = sum(bell(midi_hz(n), d, 1.6) for n in (60, 67, 72, 76)) * 0.15
    return _n(reverb(mix(boom, roar * 0.6, scream, chord), 0.8, 3500, 0.4), 0.9)


ALL = {name: fn for name, fn in globals().items()
       if callable(fn) and not name.startswith("_") and fn.__module__ == __name__}

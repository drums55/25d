#!/usr/bin/env python3
"""Every sound in the game, synthesized from code (no samples, no AI audio).

    python3 tools/audio/gen_audio.py [out_dir]      # default assets/audio
    python3 tools/audio/gen_audio.py out sfx_pickup # just the named ones

Writes mono Ogg Vorbis (ffmpeg + libvorbis) into music/, ambience/, sfx/.
Loops are made seamless by rendering on a circle: every note's tail and the
reverb wrap from the end back to the start, and noise beds are filtered in
the FFT domain (circular).

Instruments (Thai flavour, owner 2026-10-02 "ทำเสียงต่อเลย"):
  ranad  - ระนาด: bright bars, inharmonic partials, mallet click, tremolo
           (kro) on long notes
  khim   - ขิม: hammered strings (Karplus-Strong, two detuned strings)
  ching  - ฉิ่ง open ring / chap - closed; gong - ฆ้อง; thon - โทน drum
  organ  - the luk-thung keyboard on the pier radio (odd harmonics + vibrato)
Thai classical pieces use 7 equal steps per octave (7-TET); the ranad/khim
music here does too. Luk-thung (radio, wedding) is 12-TET.
"""

import os
import subprocess
import sys
import tempfile

import numpy as np
from scipy import signal

SR = 44100
RNG = np.random.default_rng(2090)
# ---------------------------------------------------------------- helpers


def secs(n):
    return int(round(n * SR))


def t_axis(dur):
    return np.arange(secs(dur)) / SR


def noise(dur, rng=RNG):
    return rng.standard_normal(secs(dur))


def sos(kind, f, order=2):
    if kind == "band":
        return signal.butter(order, [f[0] / (SR / 2), f[1] / (SR / 2)], "band", output="sos")
    return signal.butter(order, f / (SR / 2), kind, output="sos")


def filt(x, kind, f, order=2):
    return signal.sosfilt(sos(kind, f, order), x)


def fft_filter(x, lo=None, hi=None, tilt=0.0):
    """Circular (loop-safe) filter: brick-ish band with soft edges + 1/f^tilt."""
    n = len(x)
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(n, 1 / SR)
    g = np.ones_like(f)
    if lo:
        g *= 1 / (1 + (lo / np.maximum(f, 1e-3)) ** 4)
    if hi:
        g *= 1 / (1 + (f / hi) ** 4)
    if tilt:
        g *= 1 / np.maximum(f, 20.0) ** tilt
    return np.fft.irfft(spec * g, n)


def env_exp(dur, tau, attack=0.002):
    t = t_axis(dur)
    e = np.exp(-t / tau)
    a = secs(attack)
    if a > 0:
        e[:a] *= np.linspace(0, 1, a)
    return e


def fade(x, a=0.005, r=0.02):
    x = x.copy()
    na, nr = secs(a), secs(r)
    if na:
        x[:na] *= np.linspace(0, 1, na)
    if nr:
        x[-nr:] *= np.linspace(1, 0, nr)
    return x


def norm(x, peak=0.85):
    m = np.max(np.abs(x))
    return x * (peak / m) if m > 0 else x


def place(buf, x, at, loop=False):
    """Add `x` into `buf` at sample `at` (wrapping round when `loop`)."""
    n = len(buf)
    if loop:
        idx = (np.arange(len(x)) + at) % n
        np.add.at(buf, idx, x)
    else:
        end = min(n, at + len(x))
        if end > at:
            buf[at:end] += x[: end - at]


def reverb_ir(dur=1.6, damp=3000.0, seed=7):
    r = np.random.default_rng(seed)
    ir = r.standard_normal(secs(dur)) * np.exp(-t_axis(dur) / (dur / 6.0))
    ir = filt(ir, "low", damp)
    ir[0] = 0
    return ir / np.sqrt(np.sum(ir**2))


def reverb(x, wet=0.25, dur=1.6, damp=3000.0, loop=False):
    ir = reverb_ir(dur, damp)
    if loop:
        n = len(x)
        h = np.zeros(n)
        h[: min(n, len(ir))] = ir[:n]
        w = np.fft.irfft(np.fft.rfft(x) * np.fft.rfft(h), n)
        return x + wet * w
    w = signal.fftconvolve(x, ir)
    out = np.zeros(len(w))
    out[: len(x)] += x
    return out + wet * w


# ------------------------------------------------------------ tunings


def tet7(step, base=293.66):
    return base * 2 ** (step / 7.0)


PENTA7 = [0, 1, 2, 4, 5]  # Thai pentatonic in 7-TET steps


def p7(i, base=293.66):
    """Pentatonic index -> Hz (index 5 = one octave up)."""
    return tet7(PENTA7[i % 5] + 7 * (i // 5), base)


MINOR_PENTA = [0, 3, 5, 7, 10]


def p12(i, base=220.0):
    return base * 2 ** ((MINOR_PENTA[i % 5] + 12 * (i // 5)) / 12.0)


# --------------------------------------------------------- instruments


def ranad(f, dur=1.2, vel=1.0):
    t = t_axis(dur)
    out = np.zeros_like(t)
    for ratio, amp, tau in [(1.0, 1.0, 0.45), (2.76, 0.32, 0.12), (5.40, 0.14, 0.05), (8.93, 0.06, 0.02)]:
        if f * ratio < SR / 2.2:
            out += amp * np.sin(2 * np.pi * f * ratio * t + RNG.uniform(0, 6)) * np.exp(-t / tau)
    click = filt(noise(0.012), "band", (1800, 6000)) * np.linspace(1, 0, secs(0.012))
    out[: len(click)] += 0.25 * click
    out *= np.minimum(1, t / 0.0015 + 0.01)
    return fade(out * vel, 0.0, 0.05)


def ranad_note(f, beats, spb, vel=1.0):
    """A ranad note; long ones are played as a tremolo roll (kro)."""
    if beats < 1.5:
        return ranad(f, max(beats * spb + 0.6, 0.8), vel)
    step = spb / 4.0
    n = int(beats * spb / step)
    out = np.zeros(secs(beats * spb + 0.8))
    for k in range(n):
        v = vel * (0.55 + 0.25 * (k == 0)) * (1 - 0.3 * k / n)
        place(out, ranad(f, 0.8, v), secs(k * step))
    return out


def khim(f, dur=1.8, vel=1.0, bright=0.6):
    out = np.zeros(secs(dur))
    for det in (1.0, 1.0035):
        period = SR / (f * det)
        p = int(period)
        n = secs(dur)
        y = np.zeros(n + p + 2)
        burst = RNG.uniform(-1, 1, p + 1)
        burst = filt(burst, "low", 1500 + 5000 * bright)
        y[: p + 1] = burst
        d = 0.997
        start = p + 1
        while start < len(y):
            end = min(start + p, len(y))
            y[start:end] = d * 0.5 * (y[start - p : end - p] + y[start - p - 1 : end - p - 1])
            start = end
        out += y[:n]
    return fade(out * vel * 0.5, 0.0, 0.08)


def ching(open_=True, vel=1.0):
    dur = 1.3 if open_ else 0.12
    t = t_axis(dur)
    out = np.zeros_like(t)
    for f, a in [(3120, 1.0), (4335, 0.7), (5570, 0.5), (7010, 0.35), (8650, 0.2)]:
        out += a * np.sin(2 * np.pi * f * t + RNG.uniform(0, 6))
    tau = 0.38 if open_ else 0.025
    out *= np.exp(-t / tau)
    hit = filt(noise(dur), "high", 5000) * np.exp(-t / 0.01)
    return fade((out * 0.4 + 0.3 * hit) * vel, 0.0, 0.02)


def gong(f=98.0, dur=3.5, vel=1.0):
    t = t_axis(dur)
    out = np.zeros_like(t)
    bend = 1 + 0.01 * np.exp(-t / 0.3)
    for ratio, amp, tau in [(1.0, 1.0, 1.6), (2.02, 0.5, 1.0), (2.97, 0.3, 0.7), (4.1, 0.2, 0.4), (5.3, 0.1, 0.25)]:
        out += amp * np.sin(2 * np.pi * np.cumsum(f * ratio * bend) / SR) * np.exp(-t / tau)
    out *= np.minimum(1, t / 0.01)
    return fade(out * vel, 0.0, 0.2)


def thon(low=True, vel=1.0):
    dur = 0.35 if low else 0.15
    t = t_axis(dur)
    if low:
        f = 70 + 60 * np.exp(-t / 0.04)
        out = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.12)
    else:
        f = 210 + 80 * np.exp(-t / 0.02)
        out = 0.6 * np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.05)
        out += 0.5 * filt(noise(dur), "band", (800, 4000)) * np.exp(-t / 0.02)
    return fade(out * vel, 0.0, 0.02)


def pad(freqs, dur, vel=1.0, cutoff=900.0):
    t = t_axis(dur)
    out = np.zeros_like(t)
    for f in freqs:
        for det in (-0.004, 0.0, 0.0045):
            out += signal.sawtooth(2 * np.pi * f * (1 + det) * t + RNG.uniform(0, 6))
    out = filt(out, "low", cutoff)
    a = min(1.2, dur / 3)
    e = np.minimum(1, t / a) * np.minimum(1, (dur - t) / a)
    return out * e * vel / (3 * len(freqs))


def organ(f, dur, vel=1.0):
    t = t_axis(dur)
    vib = 1 + 0.006 * np.sin(2 * np.pi * 5.5 * t) * np.minimum(1, t / 0.25)
    ph = 2 * np.pi * np.cumsum(f * vib) / SR
    out = np.sin(ph) + 0.45 * np.sin(3 * ph) + 0.25 * np.sin(5 * ph) + 0.12 * np.sin(2 * ph)
    e = np.minimum(1, t / 0.015) * np.exp(-t / 2.5)
    return fade(out * e * vel * 0.35, 0.0, 0.04)


def bass(f, dur, vel=1.0):
    t = t_axis(dur)
    out = np.sin(2 * np.pi * f * t) + 0.35 * np.sin(4 * np.pi * f * t) + 0.12 * np.sin(6 * np.pi * f * t)
    return fade(out * np.exp(-t / 0.35) * vel * 0.6, 0.003, 0.03)


def tick(vel=1.0):
    t = t_axis(0.05)
    out = filt(noise(0.05), "band", (2500, 7000)) * np.exp(-t / 0.004)
    return out * vel


# --------------------------------------------------------------- music


def seq(buf, notes, start_beat, spb, fn, loop=True):
    b = start_beat
    for idx, beats, *rest in notes:
        vel = rest[0] if rest else 1.0
        if idx is not None:
            place(buf, fn(idx, beats, vel), secs(b * spb), loop)
        b += beats
    return b


DAY_MELODY = [
    [(7, 0.5), (8, 0.5), (9, 1), (8, 0.5), (7, 0.5), (5, 1)],
    [(6, 0.5), (7, 0.5), (8, 0.5), (7, 0.5), (6, 1), (5, 1)],
    [(7, 0.5), (8, 0.5), (9, 0.5), (10, 0.5), (9, 1), (8, 1)],
    [(7, 1), (5, 0.5), (6, 0.5), (7, 2)],
    [(10, 1.5), (9, 0.5), (8, 1), (9, 1)],
    [(8, 0.5), (7, 0.5), (8, 0.5), (9, 0.5), (10, 2)],
    [(11, 1), (10, 0.5), (9, 0.5), (8, 1), (7, 1)],
    [(8, 1.5), (7, 0.5), (5, 2)],
    [(6, 0.5), (7, 0.5), (6, 0.5), (5, 0.5), (5, 2)],
    [(6, 1), (7, 0.5), (6, 0.5), (5, 2)],
]


def music_day():
    bpm, bars = 104, 16
    spb = 60 / bpm
    n = secs(bars * 4 * spb)
    mel = np.zeros(n)
    m = DAY_MELODY
    order = [0, 1, 2, 3, 0, 1, 2, 9, 4, 5, 6, 7, 0, 1, 2, 8]
    b = 0
    for bar in order:
        b = seq(mel, m[bar], b, spb, lambda i, beats, v: ranad_note(p7(i), beats, spb, 0.8 * v))
    low = np.zeros(n)
    roots = [0, 2, 3, 0, 0, 2, 3, 1, 3, 1, 3, 0, 0, 2, 3, 0]
    for bar, r in enumerate(roots):
        for beat, off in enumerate([0, 2, 3, 2]):
            place(low, ranad(p7(r + off, 146.83), 0.9, 0.55), secs((bar * 4 + beat) * spb), True)
    perc = np.zeros(n)
    for beat in range(bars * 4):
        place(perc, ching(beat % 2 == 0, 0.35 if beat % 2 == 0 else 0.3), secs(beat * spb), True)
        if beat % 4 == 0:
            place(perc, thon(True, 0.7), secs(beat * spb), True)
        if beat % 4 == 1:
            place(perc, thon(False, 0.4), secs((beat + 0.5) * spb), True)
        if beat % 4 == 2:
            place(perc, thon(True, 0.5), secs(beat * spb), True)
    mix = mel + 0.6 * low + 0.7 * perc
    return norm(reverb(mix, 0.18, 1.2, loop=True), 0.8)


def music_title():
    bpm, bars = 72, 8
    spb = 60 / bpm
    n = secs(bars * 4 * spb)
    chords = [[0, 3, 5], [1, 3, 6], [2, 4, 7], [0, 3, 5]]
    pads = np.zeros(n)
    arp = np.zeros(n)
    for c, ch in enumerate(chords):
        place(pads, pad([p7(i, 146.83) for i in ch], 2 * 4 * spb + 1.0, 0.9), secs(c * 8 * spb), True)
        pattern = [ch[0], ch[1], ch[2], ch[0] + 5, ch[2], ch[1], ch[2] + 5, ch[1] + 5]
        for k in range(16):
            i = pattern[k % 8]
            v = 0.55 if k % 4 == 0 else 0.4
            place(arp, khim(p7(i + 5, 146.83), 2.0, v, 0.4), secs((c * 8 + k * 0.5) * spb), True)
    mel = np.zeros(n)
    tune = [(None, 16), (9, 2), (8, 1), (7, 1), (8, 3), (None, 1), (7, 2), (5, 1), (6, 1), (5, 4)]
    seq(mel, tune, 0, spb, lambda i, beats, v: ranad_note(p7(i), beats, spb, 0.45))
    mix = 0.9 * pads + arp + mel
    return norm(reverb(mix, 0.35, 2.2, 2500, loop=True), 0.75)


def music_night():
    bpm, bars = 60, 12
    spb = 60 / bpm
    beats = bars * 4
    n = secs(beats * spb)
    # a constant drone with whole cycles in the loop (seamless)
    t = np.arange(n) / SR
    drone = np.zeros(n)
    for f in (p7(0, 73.42), p7(3, 73.42), p7(0, 146.83)):
        for det in (-0.003, 0.0, 0.003):
            cyc = round(f * (1 + det) * n / SR) / (n / SR)  # whole cycles in the loop
            drone += signal.sawtooth(2 * np.pi * cyc * t + RNG.uniform(0, 6))
    drone = fft_filter(drone, hi=420)
    swell = 0.6 + 0.4 * np.sin(2 * np.pi * t / (n / SR) * 3) ** 2
    drone *= swell / 9
    ticks = np.zeros(n)
    for b in range(beats):
        place(ticks, tick(0.5 if b % 2 == 0 else 0.35), secs(b * spb), True)
    heart = np.zeros(n)
    for b in range(0, beats, 4):
        place(heart, thon(True, 0.6), secs(b * spb), True)
        place(heart, thon(True, 0.4), secs((b + 0.35) * spb), True)
    notes = np.zeros(n)
    rng = np.random.default_rng(3)
    for b in range(1, beats, 3):
        i = int(rng.choice([0, 1, 2, 3, 5, 6]))
        v = rng.uniform(0.3, 0.5)
        place(notes, ranad(p7(i, 146.83), 1.6, v), secs((b + rng.choice([0, 0.5])) * spb), True)
        if rng.random() < 0.3:  # a neutral-second rub, uneasy
            place(notes, ranad(tet7(1, 146.83), 1.6, v * 0.6), secs((b + 1) * spb), True)
    place(notes, gong(65.0, 6.0, 0.5), 0, True)
    place(notes, gong(65.0, 6.0, 0.35), secs(beats / 2 * spb), True)
    mix = drone + 0.5 * ticks + 0.8 * heart + notes
    return norm(reverb(mix, 0.45, 2.8, 2000, loop=True), 0.75)


LT_MELODY = [
    [(7, 1), (6, 0.5), (5, 0.5), (6, 1), (4, 1)],
    [(5, 0.5), (6, 0.5), (5, 0.5), (4, 0.5), (3, 2)],
    [(4, 1), (5, 0.5), (6, 0.5), (7, 1), (8, 1)],
    [(7, 0.5), (6, 0.5), (5, 1), (5, 2)],
    [(4, 0.5), (3, 0.5), (2, 1), (0, 2)],
    [(8, 2), (7, 1), (6, 1)],
    [(7, 1), (8, 0.5), (7, 0.5), (6, 2)],
    [(5, 1), (6, 1), (7, 1), (8, 1)],
    [(9, 2), (8, 1), (7, 1)],
]


def music_lukthung():
    bpm, bars = 120, 16
    spb = 60 / bpm
    n = secs(bars * 4 * spb)
    lead = np.zeros(n)
    order = [0, 1, 2, 3, 0, 1, 2, 4, 5, 6, 7, 8, 0, 1, 2, 4]
    b = 0
    for bar in order:
        b = seq(lead, LT_MELODY[bar], b, spb, lambda i, beats, v: organ(p12(i), beats * spb + 0.1, v))
    low = np.zeros(n)
    roots = [0, 3, 5, 0, 0, 3, 5, 0, 5, 3, 5, 7, 0, 3, 5, 0]
    for bar, r in enumerate(roots):
        f = 110.0 * 2 ** (r / 12)
        for beat, mul in enumerate([1, 1.5, 1, 1.5]):  # oom-pah: root, fifth
            place(low, bass(f * mul, 0.45), secs((bar * 4 + beat) * spb), True)
    perc = np.zeros(n)
    for beat in range(bars * 4):
        place(perc, thon(True, 0.8) if beat % 2 == 0 else thon(False, 0.6), secs(beat * spb), True)
        place(perc, ching(False, 0.3), secs(beat * spb), True)
        place(perc, ching(True, 0.25), secs((beat + 0.5) * spb), True)
    return lead + 0.8 * low + 0.7 * perc


def music_wedding():
    return norm(reverb(music_lukthung(), 0.2, 1.4, loop=True), 0.8)


def music_radio():
    x = music_lukthung()
    x = fft_filter(x, lo=380, hi=3000)
    x = np.tanh(2.2 * x / np.max(np.abs(x)))
    n = len(x)
    rng = np.random.default_rng(11)
    hiss = fft_filter(rng.standard_normal(n), lo=1500, hi=6000) * 0.04
    crackle = np.zeros(n)
    pops = rng.integers(0, n, size=int(n / SR * 9))
    crackle[pops] = rng.uniform(-1, 1, len(pops))
    crackle = fft_filter(crackle, lo=800, hi=7000) * 2.5
    t = np.arange(n) / SR
    wobble = 1 - 0.12 * (np.sin(2 * np.pi * t * 4 / (n / SR)) ** 8)
    return norm((x * wobble + hiss + crackle), 0.7)


# ------------------------------------------------------------ stingers


def sting_chapter():
    out = np.zeros(secs(5.0))
    for k, i in enumerate([5, 6, 7, 8, 9, 10, 11, 12]):
        place(out, ranad(p7(i), 0.9, 0.5 + 0.06 * k), secs(k * 0.07))
    place(out, gong(98.0, 4.0, 0.9), secs(0.62))
    place(out, ching(True, 0.6), secs(0.62))
    place(out, ching(True, 0.45), secs(1.2))
    return norm(reverb(out, 0.3, 2.0), 0.85)


def sting_good():
    out = np.zeros(secs(4.0))
    for k, i in enumerate([5, 7, 8, 9, 10]):
        place(out, organ(p12(i), 0.3 if k < 4 else 1.6, 0.9), secs(k * 0.13))
    for k in range(4):
        place(out, ching(k % 2 == 0, 0.5), secs(0.52 + k * 0.25))
    place(out, thon(True, 0.9), secs(0.52))
    return norm(reverb(out, 0.25, 1.6), 0.85)


def sting_sad():
    out = np.zeros(secs(6.0))
    for k, i in enumerate([7, 6, 5, 3]):
        place(out, khim(p7(i, 146.83), 3.0, 0.7, 0.3), secs(k * 0.7))
    place(out, pad([p7(0, 73.42), p7(3, 73.42)], 5.0, 0.8, 600), 0)
    place(out, gong(65.0, 5.0, 0.5), secs(2.1))
    return norm(reverb(out, 0.4, 2.5, 2000), 0.8)


# ------------------------------------------------------------ ambience


def amb_water(dur=20.0, seed=5, laps=1.0):
    rng = np.random.default_rng(seed)
    n = secs(dur)
    base = fft_filter(rng.standard_normal(n), lo=60, hi=900, tilt=0.5)
    base = base / np.max(np.abs(base))
    t = np.arange(n) / SR
    sway = 0.6 + 0.4 * np.sin(2 * np.pi * t * 5 / dur) * np.sin(2 * np.pi * t * 3 / dur + 1)
    out = base * sway * 0.5
    for _ in range(int(dur * 1.6 * laps)):
        d = rng.uniform(0.15, 0.35)
        f0 = rng.uniform(250, 600)
        lap = filt(rng.standard_normal(secs(d)), "band", (f0, f0 * 3))
        lap *= np.sin(np.pi * np.arange(secs(d)) / secs(d)) ** 2
        place(out, lap * rng.uniform(0.15, 0.35), int(rng.integers(0, n)), True)
    return out


def amb_day():
    return norm(amb_water(), 0.6)


def amb_night():
    dur = 24.0
    n = secs(dur)
    out = amb_water(dur, 6, 0.6) * 0.8
    rng = np.random.default_rng(8)
    t1 = t_axis(0.03)
    for k in range(int(dur * 2.2)):  # crickets: little trains of chirps
        at = int(rng.integers(0, n))
        f = rng.uniform(4200, 4800)
        for j in range(int(rng.integers(3, 6))):
            chirp = np.sin(2 * np.pi * f * t1) * np.sin(np.pi * np.arange(len(t1)) / len(t1))
            place(out, chirp * 0.08, at + secs(j * 0.045), True)
    for k in range(int(dur / 3)):  # a frog now and then
        at = int(rng.integers(0, n))
        d = 0.18
        tt = t_axis(d)
        croak = signal.square(2 * np.pi * 95 * tt) * np.sin(np.pi * tt / d)
        croak = filt(croak, "low", 900)
        for j in range(2):
            place(out, croak * 0.18, at + secs(j * 0.25), True)
    return norm(out, 0.6)


def amb_engine():
    dur = 6.0  # 54 putts at 9/s
    n = secs(dur)
    out = np.zeros(n)
    putt_rate = 9.0
    for k in range(int(dur * putt_rate)):
        d = 0.09
        tt = t_axis(d)
        p = np.sin(2 * np.pi * 58 * tt) * np.exp(-tt / 0.03)
        p += 0.6 * filt(noise(d), "band", (120, 700)) * np.exp(-tt / 0.02)
        place(out, p * (0.9 if k % 2 == 0 else 0.7), secs(k / putt_rate), True)
    hiss = fft_filter(np.random.default_rng(4).standard_normal(n), lo=2500, hi=8000) * 0.05
    water = amb_water(dur, 9, 2.0) * 0.5
    return norm(out + hiss + water, 0.7)


# ----------------------------------------------------------------- sfx


def sfx_sign():  # tapping a tin sign button
    t = t_axis(0.25)
    out = np.zeros_like(t)
    for f, a in [(1180, 1.0), (2630, 0.5), (4100, 0.3)]:
        out += a * np.sin(2 * np.pi * f * t) * np.exp(-t / 0.05)
    out += 0.6 * filt(noise(0.25), "band", (150, 900)) * np.exp(-t / 0.015)
    return norm(fade(out, 0, 0.03), 0.7)


def sfx_pencil():  # pencil / paper tap in the notebook
    t = t_axis(0.09)
    out = filt(noise(0.09), "band", (1800, 6500)) * np.exp(-t / 0.018)
    return norm(out, 0.55)


def sfx_page(dur=0.4, seed=1):
    rng = np.random.default_rng(seed)
    t = t_axis(dur)
    lo = filt(rng.standard_normal(len(t)), "band", (900, 2500))
    hi = filt(rng.standard_normal(len(t)), "band", (2500, 6500))
    out = lo * (1 - t / dur) + hi * (t / dur)  # rising swish
    out *= np.sin(np.pi * t / dur) ** 1.5
    return out


def sfx_book_open():
    out = sfx_page(0.38, 2)
    thump = filt(noise(0.12), "low", 300) * np.exp(-t_axis(0.12) / 0.03)
    place(out, 1.5 * thump, secs(0.26))
    return norm(out, 0.7)


def sfx_book_close():
    out = np.zeros(secs(0.3))
    place(out, 0.6 * sfx_page(0.18, 3), 0)
    thump = filt(noise(0.15), "low", 260) * np.exp(-t_axis(0.15) / 0.035)
    place(out, 2.0 * thump, secs(0.12))
    return norm(out, 0.75)


def sfx_tag():  # flicking a paper tag on the bag
    t = t_axis(0.12)
    out = filt(noise(0.12), "band", (2500, 8000)) * np.exp(-t / 0.012)
    out += 0.4 * np.sin(2 * np.pi * 900 * t) * np.exp(-t / 0.02)
    return norm(out, 0.55)


def sfx_pickup():
    out = np.zeros(secs(1.2))
    place(out, ranad(p7(7), 0.9, 0.8), 0)
    place(out, ranad(p7(9), 1.1, 0.9), secs(0.09))
    place(out, ching(True, 0.25), secs(0.09))
    return norm(reverb(out, 0.2, 0.8)[: secs(1.5)], 0.8)


def sfx_use_ok():
    out = np.zeros(secs(1.6))
    for k, i in enumerate([5, 7, 9, 10]):
        place(out, ranad(p7(i), 1.0, 0.7 + 0.08 * k), secs(k * 0.08))
    place(out, ching(True, 0.45), secs(0.25))
    return norm(reverb(out, 0.2, 0.8)[: secs(2.0)], 0.85)


def sfx_fail():  # comedic wooden bonk + falling whistle
    out = np.zeros(secs(0.8))
    t = t_axis(0.18)
    knock = np.sin(2 * np.pi * (330 + 200 * np.exp(-t / 0.01)) * t) * np.exp(-t / 0.04)
    place(out, knock, 0)
    t2 = t_axis(0.5)
    f = 640 * 2 ** (-1.2 * t2 / 0.5)
    whistle = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.sin(np.pi * t2 / 0.5) * 0.4
    place(out, whistle, secs(0.12))
    return norm(fade(out, 0, 0.05), 0.75)


def sfx_combine():
    out = np.zeros(secs(1.4))
    place(out, sfx_tag() * 0.7, 0)
    place(out, sfx_tag() * 0.7, secs(0.1))
    for k, i in enumerate([5, 6, 7, 8, 9]):
        place(out, khim(p7(i), 1.0, 0.5), secs(0.18 + k * 0.045))
    return norm(out, 0.8)


def sfx_line():  # a new line of dialogue: a soft wooden tok
    t = t_axis(0.08)
    out = np.sin(2 * np.pi * (520 + 300 * np.exp(-t / 0.006)) * t) * np.exp(-t / 0.018)
    return norm(out, 0.45)


def sfx_whoosh():
    dur = 0.55
    t = t_axis(dur)
    x = noise(dur)
    lo = filt(x, "band", (300, 1500))
    hi = filt(x, "band", (1500, 5000))
    mix = lo * (1 - t / dur) + hi * (t / dur)
    return norm(mix * np.sin(np.pi * t / dur) ** 2, 0.55)


def sfx_alert():  # robot spots you: two-tone beep + steam
    out = np.zeros(secs(0.7))
    for k, f in enumerate([880, 1320]):
        t = t_axis(0.13)
        b = signal.square(2 * np.pi * f * t) * 0.3
        place(out, fade(filt(b, "low", 3500), 0.003, 0.01), secs(k * 0.15))
    t = t_axis(0.4)
    steam = filt(noise(0.4), "high", 3000) * np.exp(-t / 0.12) * 0.4
    place(out, steam, secs(0.3))
    return norm(out, 0.75)


def sfx_caught():
    out = np.zeros(secs(0.9))
    t = t_axis(0.5)
    f = 300 * 2 ** (-t / 0.5)
    buzz = signal.square(2 * np.pi * np.cumsum(f) / SR) * 0.3
    place(out, filt(buzz, "low", 2500) * (1 - t / 0.5), 0)
    t2 = t_axis(0.3)
    clunk = np.sin(2 * np.pi * 120 * t2) * np.exp(-t2 / 0.05)
    clunk += filt(noise(0.3), "low", 900) * np.exp(-t2 / 0.03)
    place(out, clunk, secs(0.45))
    return norm(out, 0.8)


def sfx_spark():  # the fuse comes out: crackle, then power-down
    out = np.zeros(secs(1.0))
    rng = np.random.default_rng(12)
    cr = np.zeros(secs(0.3))
    idx = rng.integers(0, len(cr), 60)
    cr[idx] = rng.uniform(-1, 1, 60)
    place(out, filt(cr, "high", 2000) * 3.0, 0)
    t = t_axis(0.7)
    f = 420 * 2 ** (-2.5 * t / 0.7)
    down = np.sin(2 * np.pi * np.cumsum(f) / SR) * (1 - t / 0.7) * 0.5
    place(out, down, secs(0.15))
    return norm(out, 0.75)


def sfx_tide():
    dur = 2.2
    t = t_axis(dur)
    x = filt(noise(dur), "low", 700, 3)
    sw = np.sin(np.pi * t / dur) ** 2
    out = x * sw
    for k in range(5):
        place(out, ranad(p7(5 - k, 146.83), 0.6, 0.15), secs(0.3 + k * 0.18))
    return norm(out, 0.7)


def sfx_bump():
    t = t_axis(0.25)
    out = np.sin(2 * np.pi * (90 + 60 * np.exp(-t / 0.02)) * t) * np.exp(-t / 0.07)
    out += 0.5 * filt(noise(0.25), "band", (200, 1500)) * np.exp(-t / 0.03)
    return norm(out, 0.8)


def sfx_bike_start():  # pull-start cough, then putts
    out = np.zeros(secs(1.3))
    t = t_axis(0.35)
    pull = filt(noise(0.35), "band", (400, 2500)) * np.sin(np.pi * t / 0.35) * 0.4
    place(out, pull, 0)
    for k in range(7):
        d = 0.09
        tt = t_axis(d)
        p = np.sin(2 * np.pi * 58 * tt) * np.exp(-tt / 0.03)
        p += 0.6 * filt(noise(d), "band", (120, 700)) * np.exp(-tt / 0.02)
        place(out, p * (1.0 if k else 1.4), secs(0.4 + k * (0.16 - 0.008 * k)))
    return norm(out, 0.8)


def sfx_bell():  # the temple bell: one strike, long ring (the convoy keeps time by it)
    out = np.zeros(secs(2.8))
    place(out, gong(f=392.0, dur=2.8), 0)
    place(out, 0.45 * gong(f=392.0 * 2.76, dur=1.1), 0)
    t = t_axis(0.03)
    place(out, 0.5 * filt(noise(0.03), "high", 3000) * np.exp(-t / 0.006), 0)
    return norm(out, 0.8)


def sfx_firecracker():  # a string of firecrackers from the bell tower
    out = np.zeros(secs(1.4))
    at = 0.0
    for k in range(11):
        d = 0.06
        t = t_axis(d)
        bang = filt(noise(d), "band", (700, 7000)) * np.exp(-t / 0.009)
        bang += 0.6 * np.sin(2 * np.pi * 140 * t) * np.exp(-t / 0.012)
        place(out, bang * RNG.uniform(0.6, 1.0), secs(at))
        at += RNG.uniform(0.06, 0.14)
    return norm(out, 0.85)


def sfx_splash():  # someone goes into the canal
    dur = 0.7
    t = t_axis(dur)
    out = filt(noise(dur), "band", (300, 5000)) * np.minimum(1, t / 0.03) * np.exp(-t / 0.16)
    out += 0.8 * np.sin(2 * np.pi * (260 - 180 * np.minimum(1, t / 0.12)) * t) * np.exp(-t / 0.08)
    out += 0.3 * filt(noise(dur), "low", 400) * np.exp(-(t - 0.25) ** 2 / 0.01)
    return norm(out, 0.8)


TRACKS = {
    "music/title": (music_title, 3),
    "music/day": (music_day, 3),
    "music/night": (music_night, 3),
    "music/radio": (music_radio, 3),
    "music/wedding": (music_wedding, 3),
    "music/sting_chapter": (sting_chapter, 4),
    "music/sting_good": (sting_good, 4),
    "music/sting_sad": (sting_sad, 4),
    "ambience/day": (amb_day, 2),
    "ambience/night": (amb_night, 2),
    "ambience/engine": (amb_engine, 2),
    "sfx/sign": (sfx_sign, 4),
    "sfx/pencil": (sfx_pencil, 4),
    "sfx/book_open": (sfx_book_open, 4),
    "sfx/book_close": (sfx_book_close, 4),
    "sfx/tag": (sfx_tag, 4),
    "sfx/pickup": (sfx_pickup, 4),
    "sfx/use_ok": (sfx_use_ok, 4),
    "sfx/fail": (sfx_fail, 4),
    "sfx/combine": (sfx_combine, 4),
    "sfx/line": (sfx_line, 4),
    "sfx/whoosh": (sfx_whoosh, 4),
    "sfx/alert": (sfx_alert, 4),
    "sfx/caught": (sfx_caught, 4),
    "sfx/spark": (sfx_spark, 4),
    "sfx/tide": (sfx_tide, 4),
    "sfx/bump": (sfx_bump, 4),
    "sfx/bike_start": (sfx_bike_start, 4),
    "sfx/bell": (sfx_bell, 4),
    "sfx/firecracker": (sfx_firecracker, 4),
    "sfx/splash": (sfx_splash, 4),
}


def write_ogg(x, path, quality):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    pcm = (np.clip(x, -1, 1) * 32767).astype("<i2")
    with tempfile.NamedTemporaryFile(suffix=".raw", delete=False) as f:
        f.write(pcm.tobytes())
        raw = f.name
    subprocess.run(
        ["ffmpeg", "-y", "-loglevel", "error", "-f", "s16le", "-ar", str(SR), "-ac", "1", "-i", raw,
         "-c:a", "libvorbis", "-q:a", str(quality), path],
        check=True,
    )
    os.unlink(raw)


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else "assets/audio"
    only = set(sys.argv[2:])
    for name, (fn, q) in TRACKS.items():
        if only and name.split("/")[-1] not in only and name not in only:
            continue
        x = fn()
        if name.startswith("sfx/") or "/sting_" in name:
            x = fade(x, 0.0, 0.03)  # one-shots: no click where they stop
        write_ogg(x, os.path.join(out, name + ".ogg"), q)
        print(f"{name}: {len(x) / SR:.1f}s")


if __name__ == "__main__":
    main()

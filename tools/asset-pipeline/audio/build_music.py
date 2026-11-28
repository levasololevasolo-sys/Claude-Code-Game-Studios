"""Background music of «Навь»: one seamless loop per location, an underground
stem per location (same key, tempo and length, so the game cross-fades the two
in sync with AudioStreamSynchronized), a battle theme per boss and a title theme.

Everything is synthesised here (numpy + scipy), no samples, no third-party
audio. Instruments, all built additively so they stay in tune and loop cleanly:
- gusli: plucked string, partials decaying faster the higher they are;
- lira: hurdy-gurdy drone, band-limited saw with buzz and a slow bow swell;
- choir: saw harmonics shaped by vowel formants, three detuned singers, vibrato;
- flute (svirel): sine with a little 2nd/3rd harmonic and filtered breath;
- frame drum / toms: pitch-dropping sine thump plus skin noise;
- bells: inharmonic partials (church bell for the base, glass for the frost);
- wind and water drops for the beds.
A stereo convolution reverb (synthetic decaying noise) is shared per track.
Loops: each track is rendered `bars` long plus a tail; the tail (reverb, notes
ringing past the end) is folded onto the start, so the last sample runs into the
first. Drones use frequencies with a whole number of cycles per loop.

Fixed seeds keep a rebuild byte-identical. Run:
    python3 tools/asset-pipeline/audio/build_music.py [--out assets/audio/music] [--only swamp,forest]
Writes <id>.ogg (Vorbis q5) and, with --wav, the float WAV beside it.
"""
import argparse
import os
import subprocess
import tempfile
import wave

import numpy as np
from scipy import signal

SR = 44100
TAIL = 8.0  # seconds rendered past the loop end and folded back

NOTE_IDX = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def midi(name):
    """'D4', 'Eb3', 'F#5' -> MIDI number."""
    letter = name[0]
    acc = 0
    rest = name[1:]
    while rest and rest[0] in "#b":
        acc += 1 if rest[0] == "#" else -1
        rest = rest[1:]
    return 12 * (int(rest) + 1) + NOTE_IDX[letter] + acc


def hz(m):
    return 440.0 * 2.0 ** ((m - 69) / 12.0)


def f_of(name):
    return hz(midi(name)) if isinstance(name, str) else hz(name)


def lp(x, fc, order=2):
    b, a = signal.butter(order, min(fc / (SR / 2), 0.99), "low")
    return signal.lfilter(b, a, x)


def hp(x, fc, order=2):
    b, a = signal.butter(order, fc / (SR / 2), "high")
    return signal.lfilter(b, a, x)


def bp(x, lo, hi, order=2):
    b, a = signal.butter(order, [lo / (SR / 2), min(hi / (SR / 2), 0.99)], "band")
    return signal.lfilter(b, a, x)


def adsr(n, a, r, sustain_shape=None):
    """Linear attack `a` s, cosine release `r` s over n samples."""
    e = np.ones(n)
    na = max(1, min(n, int(a * SR)))
    nr = max(1, min(n - na, int(r * SR))) if n > na else 1
    e[:na] = np.linspace(0, 1, na)
    if nr > 1:
        e[n - nr:] *= 0.5 + 0.5 * np.cos(np.linspace(0, np.pi, nr))
    return e


# ---------------------------------------------------------------- instruments

def gusli(f, dur, rng, bright=1.0, decay=2.6):
    """Plucked string: partial k decays with t60 = decay / (1 + 0.45 k)."""
    n = int((dur + decay) * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    pos = 0.18 + 0.05 * rng.random()  # pluck position shapes the spectrum
    for k in range(1, 18):
        fk = f * k * (1 + 0.0004 * k * k)  # slight stiffness
        if fk > 9000:
            break
        amp = abs(np.sin(np.pi * k * pos)) / k ** (1.25 - 0.35 * bright)
        t60 = decay / (1 + 0.45 * k * (1.4 - 0.4 * bright))
        out += amp * np.exp(-6.9 * t / t60) * np.sin(2 * np.pi * fk * t + rng.random() * 6.28)
    attack = np.minimum(1.0, t / 0.004)
    # damp when the note is let go
    damp = np.ones(n)
    nd = int(dur * SR)
    if nd < n:
        damp[nd:] = np.exp(-(t[nd:] - dur) / 0.35)
    return out * attack * damp * 0.5


def lira(f, n, loop_n, rng, bright=0.6, buzz=0.15, swell=0.25, harm=28):
    """Hurdy-gurdy drone for the whole loop: whole cycles per loop, so it is seamless."""
    t = np.arange(n) / SR
    L = loop_n / SR
    f = round(f * L) / L
    sw_c = max(1, round(L / 9.0))  # bow swell ~ every 9 s, whole cycles per loop
    sw = 1 - swell + swell * (0.5 + 0.5 * np.sin(2 * np.pi * sw_c * t / L + rng.random() * 6.28))
    vib_c = round(4.8 * L)
    ph = 2 * np.pi * f * t + 0.0025 * f / 4.8 * np.sin(2 * np.pi * vib_c * t / L)
    out = np.zeros(n)
    for k in range(1, harm + 1):
        if f * k > 7000:
            break
        amp = (1.0 / k) * np.exp(-k * (1.2 - bright) * 0.18)
        out += amp * np.sin(k * ph + rng.random() * 6.28)
    # buzz: the 'dog' rattle, a pulse riding on the drone
    if buzz > 0:
        rat = (np.sin(ph * 1.0) > 0.6).astype(float)
        out += buzz * lp(rat * rng.uniform(-1, 1, n), 3000)
    return out * sw * 0.25


VOWELS = {
    "a": ((800, 1.0), (1150, 0.5), (2900, 0.12)),
    "o": ((450, 1.0), (800, 0.45), (2830, 0.08)),
    "u": ((325, 1.0), (700, 0.25), (2530, 0.05)),
    "e": ((400, 1.0), (1700, 0.35), (2600, 0.15)),
    "i": ((270, 1.0), (2290, 0.3), (3010, 0.2)),
}


def choir_note(f, dur, rng, vowel="o", a=1.2, r=1.8, voices=3, vib=0.004, breath=0.03):
    """Sustained vowel: saw harmonics weighted by formant bumps, detuned singers."""
    n = int((dur + r) * SR)
    t = np.arange(n) / SR
    fmts = VOWELS[vowel]
    out = np.zeros(n)
    for v in range(voices):
        det = 1 + (v - (voices - 1) / 2) * 0.0035 + rng.normal(0, 0.0008)
        vr = 4.6 + rng.random() * 1.2
        vdepth = vib * (0.6 + 0.4 * rng.random()) * np.minimum(1, t / 1.2)
        inst = f * det * (1 + vdepth * np.sin(2 * np.pi * vr * t + rng.random() * 6.28))
        ph = 2 * np.pi * np.cumsum(inst) / SR
        for k in range(1, 40):
            fk = f * k
            if fk > 5000:
                break
            w = sum(g * np.exp(-((fk - fc) / (90 + fc * 0.08)) ** 2) for fc, g in fmts)
            w = w / k ** 0.3 + 0.02 / k
            if w < 0.004:
                continue
            out += w * np.sin(k * ph + rng.random() * 6.28)
    out /= voices
    if breath:
        out += breath * bp(rng.uniform(-1, 1, n), fmts[0][0] * 0.8, fmts[1][0] * 1.4)
    return out * adsr(n, a, r) * 0.22


def flute(f, dur, rng, a=0.08, r=0.35, vib=0.006, breath=0.12, glide_from=None):
    n = int((dur + r) * SR)
    t = np.arange(n) / SR
    fi = np.full(n, f)
    if glide_from:
        g = int(0.09 * SR)
        fi[:g] = np.geomspace(glide_from, f, min(g, n))[:g] if g <= n else fi[:g]
    vd = vib * np.clip((t - 0.25) / 0.4, 0, 1)
    fi = fi * (1 + vd * np.sin(2 * np.pi * 5.2 * t + rng.random() * 6.28))
    ph = 2 * np.pi * np.cumsum(fi) / SR
    tone = np.sin(ph) + 0.18 * np.sin(2 * ph) + 0.06 * np.sin(3 * ph) + 0.03 * np.sin(4 * ph)
    br = bp(rng.uniform(-1, 1, n), f * 0.9, min(f * 3.0, 15000)) * breath
    chiff = bp(rng.uniform(-1, 1, n), 2000, 8000) * np.exp(-t / 0.03) * 0.15
    e = adsr(n, a, r)
    return (tone * 0.35 + br * 0.6) * e + chiff * 0.5


def drum(rng, f0=95, f1=52, dec=0.55, skin=0.25, size=1.0):
    """Frame drum / tom: sine with a pitch drop plus a skin slap."""
    n = int((dec * 3) * SR)
    t = np.arange(n) / SR
    fi = f1 + (f0 - f1) * np.exp(-t / 0.045)
    ph = 2 * np.pi * np.cumsum(fi) / SR
    body = np.sin(ph) * np.exp(-t / dec) + 0.3 * np.sin(1.6 * ph) * np.exp(-t / (dec * 0.4))
    sl = lp(rng.uniform(-1, 1, n), 1800 * size) * np.exp(-t / 0.03) * skin
    return (body * 0.8 + sl) * size


def jingle(rng, n_hits=6):
    """Bubenets / jingles: a cloud of tiny metal pings."""
    n = int(0.5 * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for _ in range(n_hits):
        d = int(rng.random() * 0.05 * SR)
        f = 5000 + rng.random() * 4000
        seg = np.sin(2 * np.pi * f * t[: n - d]) * np.exp(-t[: n - d] / 0.06)
        out[d:] += seg * (0.3 + 0.7 * rng.random())
    return hp(out, 3000) * 0.08


BELL = (0.5, 1.0, 1.19, 1.5, 2.0, 2.52, 2.66, 3.0, 4.07)
GLASS = (1.0, 2.76, 5.40, 8.93)


def bell(f, rng, kind="glass", dec=4.0):
    ratios = GLASS if kind == "glass" else BELL
    n = int(dec * 1.6 * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for i, rt in enumerate(ratios):
        fk = f * rt
        if fk > 16000:
            continue
        amp = 1.0 / (1 + i * (0.9 if kind == "glass" else 0.45))
        d = dec / (1 + i * 0.7)
        beat = 1 + 0.002 * rng.normal()
        out += amp * np.exp(-t / d * 2.3) * np.sin(2 * np.pi * fk * beat * t + rng.random() * 6.28)
    return out * np.minimum(1, t / 0.002) * 0.25


def drop(rng, f=None):
    """Water drop in a cave or bog: a quick upward-chirping sine."""
    n = int(0.25 * SR)
    t = np.arange(n) / SR
    f = f or (900 + rng.random() * 1400)
    fi = f * (1 + 1.6 * (1 - np.exp(-t / 0.02)))
    ph = 2 * np.pi * np.cumsum(fi) / SR
    return np.sin(ph) * np.exp(-t / 0.035) * np.minimum(1, t / 0.0015) * 0.25


def wind(n, loop_n, rng, lo=300, hi=1600, depth=0.7):
    """Looping wind: band noise with a slow periodic gust envelope (wrapped)."""
    x = bp(rng.uniform(-1, 1, n + SR), lo, hi)[SR:]
    L = loop_n / SR
    t = np.arange(n) / SR
    g = np.zeros(n)
    for c, w in ((max(1, round(L / 13)), 1.0), (max(1, round(L / 5)), 0.4)):
        g += w * (0.5 + 0.5 * np.sin(2 * np.pi * c * t / L + rng.random() * 6.28))
    g /= g.max()
    return x * (1 - depth + depth * g) * 0.6


# ---------------------------------------------------------------- the mix

class Mix:
    """Stereo dry bus plus a reverb send; folds the tail onto the start."""

    def __init__(self, bpm, bars, beats_per_bar=4, seed=1, room=4.0, room_dark=5000, wet=0.35):
        self.bpm = bpm
        self.beat = 60.0 / bpm
        self.bpb = beats_per_bar
        self.loop_n = int(round(bars * beats_per_bar * self.beat * SR))
        self.n = self.loop_n + int(TAIL * SR)
        self.dry = np.zeros((2, self.n))
        self.send = np.zeros((2, self.n))
        self.rng = np.random.default_rng(seed)
        self.room = room
        self.room_dark = room_dark
        self.wet = wet

    def t(self, bar, beat=0.0):
        """Seconds at bar (0-based) + beat."""
        return (bar * self.bpb + beat) * self.beat

    def add(self, x, at, gain=1.0, pan=0.0, rev=0.4, human=0.0):
        if human:
            at += self.rng.normal(0, human)
        i = int(max(0.0, at) * SR) % self.loop_n
        x = x * gain
        th = (pan + 1) * np.pi / 4
        lg, rg = np.cos(th), np.sin(th)
        end = min(self.n, i + len(x))
        seg = x[: end - i]
        self.dry[0, i:end] += seg * lg * (1 - rev * 0.5)
        self.dry[1, i:end] += seg * rg * (1 - rev * 0.5)
        self.send[0, i:end] += seg * lg * rev
        self.send[1, i:end] += seg * rg * rev
        if len(x) > end - i:  # wraps past the rendered tail: fold to the start
            rest = x[end - i:]
            j = (i + (end - i)) - self.loop_n
            self.add_raw(rest, j, lg, rg, rev)

    def add_raw(self, x, i, lg, rg, rev):
        end = min(self.n, i + len(x))
        seg = x[: end - i]
        self.dry[0, i:end] += seg * lg * (1 - rev * 0.5)
        self.dry[1, i:end] += seg * rg * (1 - rev * 0.5)
        self.send[0, i:end] += seg * lg * rev
        self.send[1, i:end] += seg * rg * rev

    def add_bed(self, x, gain=1.0, pan=0.0, rev=0.3):
        """A full-length layer (drone, wind): made circular over the loop by an
        equal-power cross-fade of what runs past the end into the start."""
        L = self.loop_n
        xf = min(int(2.0 * SR), len(x) - L)
        y = x[:L].copy()
        if xf > 0:
            w = np.linspace(0, np.pi / 2, xf)
            y[:xf] = y[:xf] * np.sin(w) + x[L: L + xf] * np.cos(w)
        self.add_raw(y * gain, 0, np.cos((pan + 1) * np.pi / 4), np.sin((pan + 1) * np.pi / 4), rev)

    def reverb(self):
        rng = np.random.default_rng(99)
        m = int(self.room * SR)
        t = np.arange(m) / SR
        ir = np.zeros((2, m))
        for c in range(2):
            nz = rng.normal(0, 1, m)
            nz = lp(nz, self.room_dark)
            ir[c] = nz * np.exp(-6.9 * t / self.room)
            ir[c, : int(0.018 * SR)] = 0  # pre-delay
        ir /= np.sqrt((ir ** 2).sum(axis=1, keepdims=True))
        # circular convolution over the loop: send is folded first
        s = self.fold(self.send)
        out = np.zeros((2, self.loop_n))
        for c in range(2):
            full = signal.fftconvolve(np.concatenate([s[c], s[c]]), ir[c])[: 2 * self.loop_n]
            out[c] = full[self.loop_n: 2 * self.loop_n]
        return out

    def fold(self, x):
        y = x[:, : self.loop_n].copy()
        rest = x[:, self.loop_n:]
        y[:, : rest.shape[1]] += rest
        return y

    def render(self, rms_db=-20.0, peak_db=-1.0):
        out = self.fold(self.dry) + self.wet * self.reverb() * 3.0
        L = out.shape[1]
        two = np.concatenate([out, out], axis=1)
        out = hp(two, 28)[:, L:]  # rumble guard, circular
        out += 0.6 * hp(two, 2800)[:, L:]  # air: a gentle high shelf, the synths run dark
        rms = np.sqrt((out ** 2).mean())
        out *= 10 ** (rms_db / 20) / max(rms, 1e-9)
        pk = np.abs(out).max()
        lim = 10 ** (peak_db / 20)
        if pk > lim:  # gentle soft clip above 70 % of the ceiling
            k = 0.7 * lim
            over = np.abs(out) > k
            out[over] = np.sign(out[over]) * (k + (lim - k) * np.tanh((np.abs(out[over]) - k) / (lim - k)))
        return out


# ---------------------------------------------------------------- writing helpers

def parse(seq):
    """'D4:1 E4:.5 r:1 F4:2:0.7' -> [(note|None, beats, vel)]."""
    out = []
    for tok in seq.split():
        p = tok.split(":")
        nt = None if p[0] == "r" else p[0]
        out.append((nt, float(p[1]) if len(p) > 1 else 1.0, float(p[2]) if len(p) > 2 else 1.0))
    return out


def play_line(mx, seq, start_bar, inst, gain=1.0, pan=0.0, rev=0.45, legato=0.95, human=0.01, **kw):
    """Plays a parsed line from start_bar; returns the end position in beats."""
    pos = start_bar * mx.bpb
    prev = None
    for nt, beats, vel in parse(seq):
        if nt is not None:
            f = f_of(nt)
            dur = beats * mx.beat * legato
            if inst == "flute":
                x = flute(f, dur, mx.rng, glide_from=(prev * 0.94 if prev and abs(prev - f) > 1 and kw.get("glide") else None),
                          vib=kw.get("vib", 0.006), breath=kw.get("breath", 0.12))
            elif inst == "voice":
                x = choir_note(f, dur, mx.rng, vowel=kw.get("vowel", "a"), a=kw.get("a", 0.25), r=kw.get("r", 0.8), voices=kw.get("voices", 1), vib=kw.get("vib", 0.009), breath=0.015)
            elif inst == "gusli":
                x = gusli(f, dur, mx.rng, bright=kw.get("bright", 1.0), decay=kw.get("decay", 2.6))
            elif inst == "bell":
                x = bell(f, mx.rng, kw.get("kind", "glass"), kw.get("dec", 4.0))
            else:
                raise ValueError(inst)
            mx.add(x, pos * mx.beat, gain * vel, pan, rev, human)
            prev = f
        pos += beats
    return pos


def chord_notes(root, kind, octave=3):
    iv = {"m": (0, 3, 7), "M": (0, 4, 7), "sus2": (0, 2, 7), "sus4": (0, 5, 7), "5": (0, 7, 12), "m7": (0, 3, 7, 10)}[kind]
    r = midi(root + str(octave))
    return [r + i for i in iv]


def choir_chords(mx, prog, bars_each, start_bar=0, vowel="o", gain=1.0, octave=3, rev=0.55, spread=0.5, a=1.5, r=2.2, only=None):
    """prog = [('D','m'), ...]; one chord per `bars_each` bars."""
    for i, (root, kind) in enumerate(prog):
        bar = start_bar + i * bars_each
        if only and bar not in only:
            continue
        notes = chord_notes(root, kind, octave)
        dur = bars_each * mx.bpb * mx.beat
        for j, m in enumerate(notes):
            x = choir_note(hz(m), dur, mx.rng, vowel=vowel, a=a, r=r)
            pan = (j - (len(notes) - 1) / 2) * spread / max(1, len(notes) - 1) * 2
            mx.add(x, mx.t(bar), gain * (1.0 if j == 0 else 0.8), pan, rev)


def arp(mx, prog, bars_each, pattern, start_bar, end_bar, octave=3, gain=1.0, pan_spread=0.5, rev=0.4, step=0.5, bright=1.0, decay=2.6, vel=None, skip=None):
    """Gusli broken chords: pattern indexes chord tones (with +3 = next octave root)."""
    nb = mx.bpb / step
    for bar in range(start_bar, end_bar):
        ci = (bar // bars_each) % len(prog)
        root, kind = prog[ci]
        tones = chord_notes(root, kind, octave)
        tones = tones + [tn + 12 for tn in tones]
        for s in range(int(nb)):
            p = pattern[s % len(pattern)]
            if p is None or (skip and skip(bar, s)):
                continue
            m = tones[p % len(tones)]
            v = (vel[s % len(vel)] if vel else 1.0) * (0.85 + 0.15 * mx.rng.random())
            x = gusli(hz(m), step * mx.beat * 2.5, mx.rng, bright=bright, decay=decay)
            pan = ((p % 4) / 3 - 0.5) * pan_spread * 2
            mx.add(x, mx.t(bar, s * step), gain * v, pan, rev, human=0.006)


def drums(mx, pattern, start_bar, end_bar, gain=1.0, rev=0.25, pan=0.0, **kw):
    """pattern: [(beat, vel, kind)] per bar; kind 'lo' / 'hi' / 'tom' / 'jing'."""
    for bar in range(start_bar, end_bar):
        for beat, vel, kind in pattern:
            if kind == "lo":
                x = drum(mx.rng, 90, 50, 0.6, 0.18, 1.0)
            elif kind == "hi":
                x = drum(mx.rng, 220, 160, 0.18, 0.45, 0.6)
            elif kind == "tom":
                x = drum(mx.rng, 140, 85, 0.35, 0.3, 0.9)
            elif kind == "boom":
                x = drum(mx.rng, 70, 34, 1.2, 0.12, 1.3)
            else:
                x = jingle(mx.rng)
            mx.add(x, mx.t(bar, beat), gain * vel, pan + (0.25 if kind == "hi" else 0), rev, human=0.004)


def drops(mx, count, lo=700, hi=2200, gain=0.5, rev=0.7):
    for _ in range(count):
        at = mx.rng.random() * mx.loop_n / SR
        x = drop(mx.rng, lo + mx.rng.random() * (hi - lo))
        mx.add(x, at, gain * (0.4 + 0.6 * mx.rng.random()), mx.rng.uniform(-0.8, 0.8), rev)


# ---------------------------------------------------------------- the tracks
# Location keys and progressions are shared by a surface track and its cave stem.

SWAMP = dict(bpm=56, bars=24, prog=[("D", "m"), ("Eb", "M"), ("D", "m"), ("C", "m"), ("Bb", "M"), ("Eb", "M"), ("G", "m"), ("A", "sus4")] * 2 + [("D", "m"), ("Eb", "M"), ("D", "m"), ("D", "m")])
FOREST = dict(bpm=72, bars=32, prog=[("E", "m"), ("D", "M"), ("E", "m"), ("A", "M"), ("C", "M"), ("D", "M"), ("E", "m"), ("B", "m")])
FROST = dict(bpm=52, bars=22, prog=[("B", "m"), ("G", "M"), ("E", "m"), ("F#", "sus4"), ("B", "m"), ("D", "M"), ("A", "M"), ("F#", "M")] + [("B", "m"), ("G", "M"), ("E", "m")])
BASE = dict(bpm=80, bars=32, prog=[("G", "M"), ("F", "M"), ("C", "M"), ("G", "M"), ("E", "m"), ("C", "M"), ("D", "M"), ("G", "M")])


def bed_lira(mx, notes, gain, bright=0.5, buzz=0.12, swell=0.3, seed=3):
    rng = np.random.default_rng(seed)
    for k, nt in enumerate(notes):
        mx.add_bed(lira(f_of(nt), mx.n, mx.loop_n, rng, bright, buzz, swell), gain, pan=(-0.3 if k % 2 else 0.3), rev=0.35)


def t_swamp(cave=False):
    c = SWAMP
    mx = Mix(c["bpm"], c["bars"], seed=11 + cave, room=6.0 if cave else 4.5, room_dark=3500 if cave else 5000, wet=0.5 if cave else 0.38)
    prog = c["prog"]
    # bog drone: D and A, the low one barely there
    bed_lira(mx, ["D2", "A2"] if not cave else ["D1", "A1", "D2"], 0.55 if not cave else 0.7, bright=0.35, buzz=0.06, swell=0.45)
    mx.add_bed(wind(mx.n, mx.loop_n, mx.rng, 120, 500, 0.8), 0.10 if not cave else 0.16, rev=0.5)
    choir_chords(mx, [p for p in prog[: 12]], 2, 0, vowel="u", gain=0.75 if not cave else 0.5, octave=3, a=2.5, r=3.0)
    if not cave:
        # Kikimora's lullaby, a low svirel, enters at bar 4, answered at bar 14
        lull = ("A4:1.5 Bb4:.5 A4:1 G4:1 F4:2 E4:1 D4:1 "
                "F4:1.5 G4:.5 A4:1 C5:1 Bb4:3 r:1 "
                "A4:1.5 Bb4:.5 A4:1 G4:1 F4:1 Eb4:1 D4:2 "
                "E4:1 F4:1 Eb4:1 C4:1 D4:4")
        play_line(mx, lull, 4, "flute", gain=0.55, pan=-0.15, rev=0.55, breath=0.18, vib=0.005, glide=True)
        ans = ("D5:2 C5:1 Bb4:1 A4:3 r:1 G4:1 A4:1 Bb4:1 G4:1 A4:4 "
               "F4:2 Eb4:1 D4:1 C4:2 Eb4:2 D4:6 r:2")
        play_line(mx, ans, 14, "voice", gain=0.5, pan=0.2, rev=0.6, vowel="o", a=0.4, r=1.2, voices=2)
        # sparse gusli: a low broken chord every other bar
        arp(mx, prog, 2, [0, None, 1, None, 2, None, None, None], 2, 24, octave=3, gain=0.45, step=0.5, bright=0.6, decay=3.2,
            skip=lambda bar, s: bar % 2 == 1)
        for bar in (0, 8, 16):
            mx.add(bell(f_of("D5"), mx.rng, "bell", 6.0), mx.t(bar), 0.18, 0.4, 0.7)
        drops(mx, 26, 600, 1600, 0.35, 0.6)
    else:
        # underground: drips, a muffled bell, low gusli harmonics on the downbeats
        drops(mx, 60, 900, 2600, 0.3, 0.75)
        for bar in range(0, 24, 4):
            root = prog[bar // 2][0]
            mx.add(gusli(f_of(root + "2"), 6.0, mx.rng, bright=0.3, decay=5.0), mx.t(bar), 0.5, -0.2, 0.6)
        for bar in (2, 10, 18):
            mx.add(bell(f_of("A4"), mx.rng, "bell", 7.0), mx.t(bar, 2), 0.12, 0.5, 0.85)
        play_line(mx, "A3:6 Bb3:2 A3:8 r:8 D4:4 C4:4 D4:8", 8, "voice", gain=0.25, rev=0.8, vowel="u", a=1.5, r=2.5, voices=2)
    return mx


def t_forest(cave=False):
    c = FOREST
    mx = Mix(c["bpm"], c["bars"], seed=21 + cave, room=5.5 if cave else 3.8, room_dark=3200 if cave else 6000, wet=0.5 if cave else 0.33)
    prog = c["prog"]
    bed_lira(mx, ["E2", "B2"] if not cave else ["E1", "B1"], 0.4 if not cave else 0.65, bright=0.55, buzz=0.12, swell=0.35, seed=4)
    mx.add_bed(wind(mx.n, mx.loop_n, mx.rng, 250, 1200, 0.6), 0.07 if not cave else 0.05, rev=0.5)
    if not cave:
        # the gusli ostinato: the dark forest breathes in eighths
        arp(mx, prog, 4, [0, 2, 3, 2, 1, 2, 3, 4], 0, 32, octave=3, gain=0.5, step=0.5, bright=0.9, decay=2.2,
            vel=[1.0, 0.6, 0.8, 0.6, 0.9, 0.6, 0.8, 0.7], skip=lambda bar, s: bar < 4 and s % 2 == 1)
        # heartbeat drum from bar 8
        drums(mx, [(0, 0.8, "lo"), (0.45, 0.45, "lo"), (2.5, 0.25, "hi")], 8, 32, gain=0.55, rev=0.3)
        # svirel tune, Dorian, enters bar 8
        tune = ("B4:1 E5:1 D5:.5 B4:.5 A4:1 B4:2 G4:1 A4:1 "
                "B4:1 D5:1 C#5:.5 B4:.5 A4:1 F#4:3 r:1 "
                "G4:1 A4:1 B4:1 D5:1 E5:1.5 D5:.5 B4:2 "
                "A4:1 G4:.5 F#4:.5 G4:1 A4:1 E4:4 "
                "B4:1 E5:1 D5:.5 B4:.5 A4:1 B4:2 G4:1 A4:1 "
                "B4:1 D5:1 E5:.5 F#5:.5 E5:1 D5:3 r:1 "
                "C#5:1 B4:1 A4:1 F#4:1 G4:1.5 A4:.5 B4:2 "
                "A4:1 G4:.5 F#4:.5 D4:1 F#4:1 E4:4")
        play_line(mx, tune, 8, "flute", gain=0.5, pan=0.1, rev=0.45, glide=True)
        # 'ау' calls: a falling fifth far away, before the tune and at its end
        for bar in (3, 26, 30):
            play_line(mx, "B5:1.5 E5:2.5", bar, "flute", gain=0.22, pan=-0.7, rev=0.9, breath=0.2)
        choir_chords(mx, prog * 4, 4, 16, vowel="o", gain=0.45, octave=3, a=2.0, r=2.5, only=set(range(16, 32, 4)))
    else:
        drops(mx, 40, 800, 2200, 0.25, 0.7)
        arp(mx, prog, 4, [0, None, None, None, 2, None, None, None], 0, 32, octave=2, gain=0.5, step=0.5, bright=0.35, decay=4.0)
        drums(mx, [(0, 0.6, "lo"), (0.45, 0.35, "lo")], 0, 32, gain=0.35, rev=0.55)
        choir_chords(mx, prog * 4, 4, 0, vowel="u", gain=0.45, octave=2, a=2.5, r=3.0)
        for bar in (6, 22):
            play_line(mx, "B5:1.5 E5:2.5", bar, "flute", gain=0.12, pan=0.7, rev=0.95, breath=0.25)
    return mx


def t_frost(cave=False):
    c = FROST
    mx = Mix(c["bpm"], c["bars"], seed=31 + cave, room=7.0, room_dark=7000 if not cave else 4500, wet=0.5)
    prog = c["prog"]
    bed_lira(mx, ["B1", "F#2"], 0.3 if not cave else 0.45, bright=0.25, buzz=0.0, swell=0.5, seed=5)
    mx.add_bed(wind(mx.n, mx.loop_n, mx.rng, 1200, 5000, 0.85), 0.07, rev=0.4)
    mx.add_bed(wind(mx.n, mx.loop_n, mx.rng, 200, 700, 0.7), 0.06, rev=0.4)
    choir_chords(mx, prog, 2, 0, vowel="i" if not cave else "u", gain=0.5, octave=4 if not cave else 3, a=3.0, r=3.5, spread=0.8)
    if not cave:
        # falling glass: slow celesta arpeggios, high register
        arp_bells = []
        for bar in range(0, 22):
            root, kind = prog[(bar // 2) % len(prog)]
            tones = chord_notes(root, kind, 5)
            for s, idx in enumerate([2, 1, 0, 1] if bar % 2 == 0 else [3 % len(tones), 2, 1]):
                if mx.rng.random() < 0.25:
                    continue
                m = tones[idx % len(tones)] + (12 if idx == 3 else 0)
                arp_bells.append((bar, s * (1.33 if bar % 2 else 1.0), m))
        for bar, beat, m in arp_bells:
            mx.add(bell(hz(m), mx.rng, "glass", 3.5), mx.t(bar, beat), 0.32, mx.rng.uniform(-0.7, 0.7), 0.7, human=0.01)
        # Morena's lament, one voice
        lament = ("F#5:2 E5:1 D5:1 C#5:2 B4:2 "
                  "D5:1.5 C#5:.5 B4:1 A4:1 B4:4 "
                  "G5:2 F#5:1 E5:1 F#5:2 D5:2 "
                  "E5:1 D5:1 C#5:1 A4:1 B4:4 r:8")
        play_line(mx, lament, 6, "voice", gain=0.55, pan=0.0, rev=0.7, vowel="a", a=0.35, r=1.6, voices=1, vib=0.011)
        play_line(mx, "B5:2 A5:1 F#5:1 G5:3 F#5:1 E5:2 D5:2 C#5:4", 16, "flute", gain=0.3, pan=-0.3, rev=0.7, breath=0.22)
    else:
        for bar in range(0, 22, 2):
            root = prog[bar // 2][0]
            mx.add(bell(f_of(root + "4"), mx.rng, "glass", 6.0), mx.t(bar, 1), 0.18, mx.rng.uniform(-0.5, 0.5), 0.9)
        drops(mx, 30, 1800, 3800, 0.3, 0.9)
        # ice groan: very low glide
        for bar in (4, 15):
            mx.add(lp(choir_note(f_of("B1"), 6.0, mx.rng, "u", 2.0, 3.0), 400), mx.t(bar), 0.8, 0.0, 0.6)
    return mx


def t_base(cave=False):
    c = BASE
    mx = Mix(c["bpm"], c["bars"], seed=41 + cave, room=2.6 if not cave else 4.5, room_dark=6000 if not cave else 3500, wet=0.28 if not cave else 0.45)
    prog = c["prog"]
    bed_lira(mx, ["G2", "D3"], 0.25 if not cave else 0.4, bright=0.6, buzz=0.1, swell=0.25, seed=6)
    if not cave:
        # gusli strum: rolled chords on 1 and 3, a little run on 4
        for bar in range(32):
            root, kind = prog[(bar // 4) % len(prog)] if False else prog[(bar // 2) % len(prog)]
            tones = chord_notes(root, kind, 3) + [chord_notes(root, kind, 4)[0]]
            for beat in (0, 2):
                for j, m in enumerate(tones):
                    mx.add(gusli(hz(m), 1.6 * mx.beat, mx.rng, bright=1.0, decay=2.0), mx.t(bar, beat) + j * 0.022, 0.32, (j / 3 - 0.5), 0.3, human=0.004)
            if bar % 2 == 1:
                for k, m in enumerate([tones[2], tones[1]]):
                    mx.add(gusli(hz(m + 12), 0.5 * mx.beat, mx.rng, decay=1.4), mx.t(bar, 3 + k * 0.5), 0.25, 0.4, 0.3)
        drums(mx, [(0, 0.5, "lo"), (2, 0.3, "lo"), (3, 0.18, "hi")], 8, 32, gain=0.5, rev=0.2)
        drums(mx, [(1, 0.5, "jing"), (3, 0.5, "jing")], 16, 32, gain=0.6, rev=0.2)
        tune = ("D5:1 E5:.5 D5:.5 B4:1 G4:1 A4:1 B4:.5 A4:.5 G4:2 "
                "C5:1 B4:.5 A4:.5 G4:1 F4:1 G4:3 r:1 "
                "B4:1 C5:.5 D5:.5 E5:1 D5:1 C5:1 B4:1 A4:2 "
                "B4:1 A4:.5 G4:.5 A4:1 F#4:1 G4:3 r:1 "
                "D5:1 E5:.5 D5:.5 B4:1 G4:1 A4:1 B4:.5 A4:.5 G4:2 "
                "C5:1 B4:.5 A4:.5 G4:1 F4:1 G4:3 r:1 "
                "E5:1 D5:1 C5:1 B4:1 C5:1 B4:.5 A4:.5 G4:2 "
                "A4:1 B4:.5 A4:.5 F#4:1 A4:1 G4:4")
        play_line(mx, tune, 8, "flute", gain=0.45, pan=-0.1, rev=0.35, glide=True)
        choir_chords(mx, prog, 2, 24, vowel="a", gain=0.3, octave=3, a=1.0, r=1.5, only={24, 26, 28, 30})
        mx.add(bell(f_of("G4"), mx.rng, "bell", 5.0), mx.t(0), 0.2, 0.5, 0.5)
    else:
        arp(mx, prog, 2, [0, None, 2, None, 1, None, None, None], 0, 32, octave=2, gain=0.5, step=0.5, bright=0.4, decay=3.0)
        drops(mx, 24, 900, 2000, 0.35, 0.8)
        choir_chords(mx, prog * 2, 2, 0, vowel="o", gain=0.35, octave=3, a=2.0, r=2.5)
    return mx


# ---------------------------------------------------------------- battles

def t_boss_kikimora():
    mx = Mix(104, 32, seed=51, room=3.0, room_dark=5000, wet=0.3)
    prog = [("D", "m"), ("D", "m"), ("Eb", "M"), ("D", "m"), ("C", "m"), ("Bb", "M"), ("Eb", "M"), ("A", "sus4")]
    bed_lira(mx, ["D2", "A2", "D3"], 0.55, bright=0.8, buzz=0.3, swell=0.2, seed=7)
    groove = [(0, 1.0, "lo"), (1.5, 0.6, "tom"), (2, 0.8, "lo"), (2.75, 0.4, "hi"), (3, 0.7, "tom"), (3.5, 0.5, "hi")]
    drums(mx, [(0, 0.9, "lo"), (2, 0.7, "lo")], 0, 4, gain=0.5)
    drums(mx, groove, 4, 32, gain=0.5, rev=0.2)
    drums(mx, [(0.5, 0.4, "jing"), (1.5, 0.4, "jing"), (2.5, 0.4, "jing"), (3.5, 0.4, "jing")], 16, 32, gain=0.5)
    arp(mx, prog, 4, [0, 1, 0, 2, 0, 1, 3, 2], 4, 32, octave=3, gain=0.42, step=0.5, bright=1.0, decay=1.4)
    choir_chords(mx, prog * 4, 4, 8, vowel="a", gain=0.6, octave=3, a=0.6, r=1.2)
    riff = "D5:.5 Eb5:.5 D5:.5 C5:.5 D5:1 A4:1 Bb4:.5 A4:.5 G4:.5 F4:.5 Eb4:1 D4:1"
    for bar in (12, 14, 20, 22, 28, 30):
        play_line(mx, riff, bar, "flute", gain=0.42, pan=0.2, rev=0.35, breath=0.2)
    for bar in range(0, 32, 8):
        mx.add(drum(mx.rng, 70, 34, 1.2, 0.12, 1.3), mx.t(bar), 0.5, 0, 0.5)
    return mx


def t_boss_likho():
    mx = Mix(116, 32, seed=61, room=3.5, room_dark=4500, wet=0.32)
    prog = [("E", "m"), ("E", "m"), ("C", "M"), ("B", "m"), ("E", "m"), ("D", "M"), ("C", "M"), ("B", "M")]
    bed_lira(mx, ["E2", "B2"], 0.5, bright=0.85, buzz=0.35, swell=0.2, seed=8)
    # the one-eyed one counts in threes over four: 3+3+2
    groove = [(0, 1.0, "lo"), (1.5, 0.8, "tom"), (3, 0.8, "lo"), (3.5, 0.4, "hi"), (2.25, 0.35, "hi")]
    drums(mx, [(0, 0.8, "lo"), (0.45, 0.5, "lo")], 0, 4, gain=0.55)
    drums(mx, groove, 4, 32, gain=0.55, rev=0.2)
    arp(mx, prog, 4, [0, 0, 2, 0, 0, 3, 0, 1], 0, 32, octave=2, gain=0.5, step=0.5, bright=0.8, decay=1.2)
    choir_chords(mx, prog * 4, 4, 8, vowel="o", gain=0.6, octave=3, a=0.4, r=1.0)
    for bar in (6, 14, 22, 30):
        play_line(mx, "B5:1 E5:1 r:.5 B5:.5 E5:1", bar, "flute", gain=0.35, pan=-0.6, rev=0.8, breath=0.25)
    tune = "E5:1 G5:1 F#5:.5 E5:.5 D5:1 E5:2 B4:2 C5:1 B4:1 A4:1 G4:1 F#4:4"
    for bar in (16, 24):
        play_line(mx, tune, bar, "voice", gain=0.45, rev=0.5, vowel="a", a=0.1, r=0.6, voices=3)
    return mx


def t_boss_morena():
    mx = Mix(92, 32, seed=71, room=5.0, room_dark=6500, wet=0.4)
    prog = [("B", "m"), ("G", "M"), ("E", "m"), ("F#", "M")] * 2
    bed_lira(mx, ["B1", "F#2", "B2"], 0.5, bright=0.5, buzz=0.15, swell=0.3, seed=9)
    mx.add_bed(wind(mx.n, mx.loop_n, mx.rng, 1500, 6000, 0.8), 0.06, rev=0.4)
    drums(mx, [(0, 1.0, "boom"), (3, 0.6, "tom"), (3.5, 0.6, "tom")], 0, 32, gain=0.45, rev=0.35)
    drums(mx, [(1, 0.5, "hi"), (2, 0.8, "lo"), (2.5, 0.4, "hi")], 8, 32, gain=0.45, rev=0.3)
    choir_chords(mx, prog * 2, 2, 0, vowel="a", gain=0.65, octave=3, a=0.8, r=1.5, spread=0.8)
    choir_chords(mx, prog * 2, 2, 16, vowel="i", gain=0.35, octave=4, a=1.0, r=1.5, spread=0.9)
    for bar in range(32):
        root, kind = prog[(bar // 2) % len(prog)]
        tones = chord_notes(root, kind, 5)
        for s in range(4):
            mx.add(bell(hz(tones[(s * 2 + bar) % 3]), mx.rng, "glass", 2.0), mx.t(bar, s + 0.5), 0.17, mx.rng.uniform(-0.8, 0.8), 0.6)
    lament = "F#5:2 E5:1 D5:1 C#5:2 B4:2 D5:1.5 C#5:.5 B4:1 A4:1 B4:4 G5:2 F#5:1 E5:1 F#5:2 D5:2 E5:1 D5:1 C#5:1 A#4:1 B4:4"
    play_line(mx, lament, 8, "voice", gain=0.55, rev=0.6, vowel="a", a=0.2, r=1.0, voices=2, vib=0.01)
    play_line(mx, lament, 24, "flute", gain=0.4, pan=0.3, rev=0.5, breath=0.18)
    return mx


def t_title():
    """Main menu: the lantern in the dark, A minor, slow; the theme the hero carries."""
    mx = Mix(60, 20, seed=81, room=5.5, room_dark=5500, wet=0.45)
    prog = [("A", "m"), ("F", "M"), ("C", "M"), ("G", "M"), ("A", "m"), ("F", "M"), ("D", "m"), ("E", "M"), ("A", "m"), ("A", "m")]
    bed_lira(mx, ["A1", "E2"], 0.35, bright=0.4, buzz=0.05, swell=0.4, seed=10)
    mx.add_bed(wind(mx.n, mx.loop_n, mx.rng, 200, 900, 0.7), 0.06, rev=0.5)
    choir_chords(mx, prog, 2, 0, vowel="o", gain=0.55, octave=3, a=2.0, r=2.5)
    arp(mx, prog, 2, [0, 1, 2, 4, 3, 2, 1, 2], 2, 20, octave=3, gain=0.4, step=0.5, bright=0.8, decay=2.6,
        vel=[1, .6, .7, .9, .7, .6, .7, .6])
    theme = ("E5:2 D5:1 C5:1 B4:2 A4:2 C5:1.5 B4:.5 A4:1 G4:1 A4:4 "
             "E5:2 F5:1 E5:1 D5:2 C5:2 B4:1 C5:1 A4:1 G#4:1 A4:4")
    play_line(mx, theme, 4, "flute", gain=0.5, rev=0.55, glide=True)
    play_line(mx, "A5:2 G5:1 E5:1 F5:2 E5:2 D5:1 C5:1 B4:1 G#4:1 A4:4", 14, "voice", gain=0.35, rev=0.7, vowel="a", a=0.4, r=1.5, voices=1)
    mx.add(bell(f_of("A4"), mx.rng, "bell", 6.0), mx.t(0), 0.25, -0.3, 0.7)
    return mx


TRACKS = {
    "mus_swamp": lambda: t_swamp(False),
    "mus_swamp_cave": lambda: t_swamp(True),
    "mus_forest": lambda: t_forest(False),
    "mus_forest_cave": lambda: t_forest(True),
    "mus_frost": lambda: t_frost(False),
    "mus_frost_cave": lambda: t_frost(True),
    "mus_base": lambda: t_base(False),
    "mus_boss_kikimora": t_boss_kikimora,
    "mus_boss_likho": t_boss_likho,
    "mus_boss_morena": t_boss_morena,
    "mus_title": t_title,
}
LOUD = {"mus_boss_kikimora": -17.0, "mus_boss_likho": -17.0, "mus_boss_morena": -17.5}


def write_wav(path, x):
    pcm = (np.clip(x, -1, 1) * 32767).astype("<i2").T.copy()
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="assets/audio/music")
    ap.add_argument("--only", default="")
    ap.add_argument("--wav", action="store_true")
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    only = [s for s in a.only.split(",") if s]
    for tid, fn in TRACKS.items():
        if only and not any(o in tid for o in only):
            continue
        mx = fn()
        x = mx.render(LOUD.get(tid, -20.0))
        with tempfile.TemporaryDirectory() as td:
            wp = os.path.join(td, tid + ".wav")
            write_wav(wp, x)
            if a.wav:
                write_wav(os.path.join(a.out, tid + ".wav"), x)
            subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", wp, "-c:a", "libvorbis", "-q:a", "5",
                            os.path.join(a.out, tid + ".ogg")], check=True)
        print(f"{tid}: {x.shape[1] / SR:.1f} s, {mx.bpm} bpm, peak {20 * np.log10(np.abs(x).max()):.1f} dB")


if __name__ == "__main__":
    main()

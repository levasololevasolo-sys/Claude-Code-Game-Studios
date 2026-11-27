#!/usr/bin/env python3
"""Synthesises the first SFX pass of «Навь» into assets/audio/sfx/*.wav.

Standard library only (wave, math, random, array). Every sound is built from
noise bursts through swept state-variable filters, pitch-dropping sines for
impacts and a layered low thump, so nothing is sampled and nothing is licensed:
the output is generated in-house (CC0-equivalent, see assets/provenance.yaml).
Each sound uses its own fixed seed, so a rebuild is byte-identical.

Output: mono, 44.1 kHz, 16-bit PCM, peak-normalised to -1 dBFS, 2 ms fade-in
and 10 ms fade-out. Run from the repo root:
    python3 tools/asset-pipeline/audio/build_sfx.py
"""
import array
import math
import os
import random
import wave

SR = 44100
PEAK = 0.89  # -1 dBFS
OUT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "assets", "audio", "sfx"))


# ---------------------------------------------------------------- primitives

def n_of(sec):
    return int(sec * SR)


def noise(sec, rng):
    return [rng.uniform(-1.0, 1.0) for _ in range(n_of(sec))]


def env_exp(n, attack, decay):
    """Linear attack (s), then exponential decay with time constant `decay` (s)."""
    a = max(1, n_of(attack))
    return [i / a if i < a else math.exp(-(i - a) / (decay * SR)) for i in range(n)]


def sweep(n, start, end, curve=1.0):
    """Exponential sweep of a parameter from start to end over n samples."""
    return [start * (end / start) ** ((i / max(1, n - 1)) ** curve) for i in range(n)]


def svf(sig, cutoff, q=0.7, mode="lp"):
    """Chamberlin state-variable filter; `cutoff` is a float or a per-sample list."""
    low = band = 0.0
    damp = 1.0 / q
    out = []
    for i, x in enumerate(sig):
        fc = cutoff[i] if isinstance(cutoff, list) else cutoff
        f = 2.0 * math.sin(math.pi * min(fc, SR / 6.0) / SR)
        low += f * band
        high = x - low - damp * band
        band += f * high
        out.append(low if mode == "lp" else band if mode == "bp" else high)
    return out


def osc(freqs, shape="sine"):
    """Oscillator following a per-sample frequency list."""
    out = []
    p = 0.0
    for f in freqs:
        p += f / SR
        p -= math.floor(p)
        if shape == "sine":
            out.append(math.sin(2 * math.pi * p))
        elif shape == "saw":
            out.append(2.0 * p - 1.0)
        else:  # triangle
            out.append(4.0 * abs(p - 0.5) - 1.0)
    return out


def mul(a, b):
    return [x * y for x, y in zip(a, b)]


def scale(a, k):
    return [x * k for x in a]


def mix(*layers):
    out = [0.0] * max(len(l) for l in layers)
    for l in layers:
        for i, x in enumerate(l):
            out[i] += x
    return out


def delay(sig, sec):
    return [0.0] * n_of(sec) + sig


def drive(sig, k):
    """Soft clip (tanh) for grit and perceived loudness."""
    return [math.tanh(x * k) for x in sig]


def thump(sec, f0, f1, decay):
    """Pitch-dropping sine body: the low punch under every impact."""
    n = n_of(sec)
    return mul(osc(sweep(n, f0, f1, 0.5)), env_exp(n, 0.002, decay))


def burst(sec, rng, c0, c1, decay, q=0.8, mode="lp", attack=0.001):
    """Noise burst through a filter whose cutoff sweeps c0 -> c1."""
    n = n_of(sec)
    return mul(svf(noise(sec, rng), sweep(n, c0, c1), q, mode), env_exp(n, attack, decay))


def whoosh(sec, rng, c0, cpeak, c1, q=1.6, mode="bp"):
    """Noise through a filter that rises then falls, with a rise-fall envelope."""
    n = n_of(sec)
    third = n // 3
    cut = sweep(third, c0, cpeak) + sweep(n - third, cpeak, c1)
    env = [math.sin(math.pi * min(1.0, (i / n) ** 0.6)) ** 1.5 for i in range(n)]
    return mul(svf(noise(sec, rng), cut, q, mode), env)


def finish(sig, tail=0.010):
    peak = max(abs(x) for x in sig) or 1.0
    sig = [x / peak * PEAK for x in sig]
    fi, fo = n_of(0.002), n_of(tail)
    for i in range(min(fi, len(sig))):
        sig[i] *= i / fi
    for i in range(min(fo, len(sig))):
        sig[-1 - i] *= i / fo
    return sig


def write(name, sig):
    sig = finish(sig)
    data = array.array("h", (int(max(-1.0, min(1.0, x)) * 32767) for x in sig))
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    return path, len(sig) / SR


# ---------------------------------------------------------------- the sounds

def swing(seed):
    rng = random.Random(seed)
    v = seed % 3
    k = 1.0 + v * 0.12
    sec = 0.17 + v * 0.025
    air = whoosh(sec, rng, 500 * k, 3200 * k, 900 * k, q=2.2)
    body = whoosh(sec, rng, 250 * k, 900 * k, 300 * k, q=1.2, mode="lp")
    return mix(air, scale(body, 0.6))


def hit_flesh(seed):
    rng = random.Random(seed)
    v = seed % 3
    body = thump(0.16, 170 - v * 15, 48, 0.045)
    smack = burst(0.10, rng, 4200 - v * 500, 500, 0.022, q=0.9)
    crunch = burst(0.06, rng, 2500, 1200, 0.012, q=3.0, mode="bp")
    return drive(mix(body, scale(smack, 0.9), scale(crunch, 0.5)), 1.8)


def hit_heavy():
    rng = random.Random(301)
    sub = thump(0.42, 120, 32, 0.12)
    body = thump(0.25, 260, 70, 0.05)
    smack = burst(0.22, rng, 6000, 300, 0.05, q=0.8)
    ring = mul(osc(sweep(n_of(0.3), 900, 600)), env_exp(n_of(0.3), 0.001, 0.07))
    return drive(mix(sub, scale(body, 0.7), smack, scale(ring, 0.15)), 2.4)


def wall_slam():
    rng = random.Random(401)
    sub = thump(0.5, 90, 28, 0.15)
    knock = burst(0.25, rng, 1800, 150, 0.06, q=0.7)
    rubble = [0.0] * n_of(0.45)
    grain = n_of(0.006)
    for _ in range(26):  # sparse grit falling after the hit
        at = n_of(0.03) + int(rng.random() ** 1.6 * n_of(0.38))
        amp = rng.uniform(0.2, 0.6) * math.exp(-at / n_of(0.2))
        for j in range(grain):
            if at + j < len(rubble):
                rubble[at + j] += amp * rng.uniform(-1, 1) * (1 - j / grain)
    rubble = svf(rubble, 2500, 0.8, "bp")
    return drive(mix(sub, knock, scale(rubble, 0.9)), 2.0)


def pogo():
    rng = random.Random(501)
    hit = thump(0.12, 200, 60, 0.04)
    spring = mul(osc(sweep(n_of(0.16), 220, 520, 0.7), "tri"), env_exp(n_of(0.16), 0.004, 0.06))
    puff = burst(0.08, rng, 3000, 800, 0.02)
    return mix(hit, scale(spring, 0.45), scale(puff, 0.5))


def roll():
    rng = random.Random(601)
    cloth = whoosh(0.32, rng, 250, 1300, 300, q=0.9, mode="lp")
    grit = whoosh(0.32, rng, 1500, 4000, 1800, q=1.5)
    return mix(cloth, scale(grit, 0.25))


def dash():
    rng = random.Random(701)
    air = whoosh(0.24, rng, 900, 5200, 1500, q=2.4)
    low = whoosh(0.24, rng, 200, 700, 200, q=1.0, mode="lp")
    kick = thump(0.08, 140, 60, 0.02)
    return mix(air, scale(low, 0.5), scale(kick, 0.5))


def jump():
    rng = random.Random(801)
    puff = burst(0.09, rng, 2400, 600, 0.025, q=0.9)
    lift = mul(osc(sweep(n_of(0.09), 150, 260)), env_exp(n_of(0.09), 0.002, 0.03))
    return mix(puff, scale(lift, 0.6))


def land():
    rng = random.Random(901)
    body = thump(0.16, 110, 40, 0.04)
    dust = burst(0.14, rng, 1600, 300, 0.035, q=0.7)
    return drive(mix(body, scale(dust, 0.8)), 1.5)


def hero_hurt():
    rng = random.Random(1001)
    n = n_of(0.32)
    pitch = [f * (1 + 0.03 * math.sin(i / SR * 2 * math.pi * 23)) for i, f in enumerate(sweep(n, 320, 140))]
    groan = mul(svf(osc(pitch, "saw"), sweep(n, 2200, 500), 1.2), env_exp(n, 0.004, 0.09))
    hit = thump(0.18, 180, 55, 0.04)
    smack = burst(0.08, rng, 5000, 900, 0.018)
    return drive(mix(scale(groan, 0.8), hit, scale(smack, 0.7)), 2.0)


def enemy_death():
    rng = random.Random(1101)
    n = n_of(0.62)
    wail = mul(svf(osc(sweep(n, 230, 50, 0.8), "saw"), sweep(n, 1800, 200), 1.4), env_exp(n, 0.005, 0.18))
    gore = burst(0.4, rng, 3500, 150, 0.08, q=0.8)
    body = thump(0.3, 130, 35, 0.09)
    return drive(mix(scale(wail, 0.6), gore, body), 1.8)


def amulet_tick():
    n = n_of(0.07)
    tone = mix(osc([1760] * n), scale(osc([2650] * n), 0.4), scale(osc([4400] * n), 0.15))
    return mul(tone, env_exp(n, 0.001, 0.018))


def flare():
    rng = random.Random(1301)
    pre = n_of(0.16)
    swell = mul(svf(noise(0.16, rng), sweep(pre, 400, 6000, 2.0), 2.0, "bp"), [(i / pre) ** 2 for i in range(pre)])
    sec = 1.3
    n = n_of(sec)
    sub = thump(sec, 75, 24, 0.35)
    blast = burst(sec, rng, 7000, 120, 0.25, q=0.7)
    shimmer = mul(mix(osc([660] * n), osc([990 * 1.004] * n), scale(osc([1320 * 0.997] * n), 0.6)), env_exp(n, 0.02, 0.4))
    boom = drive(mix(scale(sub, 1.2), blast, scale(shimmer, 0.12)), 2.2)
    return mix(scale(swell, 0.5), delay(boom, 0.16))


def rune_chime():
    n = n_of(1.1)
    parts = [(880, 1.0, 0.45), (1320 * 1.003, 0.55, 0.3), (2210, 0.3, 0.18), (3520 * 0.998, 0.15, 0.1)]
    layers = [mul(scale(osc([f] * n), a), env_exp(n, 0.002, d)) for f, a, d in parts]
    second = delay(mix(*[mul(scale(osc([f * 1.5] * n), a * 0.5), env_exp(n, 0.002, d)) for f, a, d in parts[:2]]), 0.09)
    return mix(*layers, second)


def door_open():
    rng = random.Random(1501)
    sec = 0.75
    n = n_of(sec)
    creak_f = [95 + 25 * math.sin(i / SR * 2 * math.pi * 3.1) + 8 * math.sin(i / SR * 2 * math.pi * 17) for i in range(n)]
    creak = mul(svf(osc(creak_f, "saw"), 900, 4.0, "bp"), [math.sin(math.pi * i / n) for i in range(n)])
    rumble = mul(svf(noise(sec, rng), 220, 0.8), [math.sin(math.pi * i / n) ** 0.5 for i in range(n)])
    clunk = thump(0.25, 100, 40, 0.06)
    return mix(scale(creak, 0.6), scale(rumble, 0.9), scale(clunk, 0.8))


def ember_pickup():
    rng = random.Random(1601)
    n = n_of(0.16)
    blips = [delay(mul(osc([f] * n), env_exp(n, 0.001, 0.04)), at) for f, at in [(990, 0.0), (1320, 0.045), (1760, 0.09)]]
    sparkle = burst(0.2, rng, 9000, 6000, 0.05, q=2.0, mode="bp")
    return mix(*blips, scale(sparkle, 0.25))


def boss_roar():
    rng = random.Random(1701)
    sec = 1.5
    n = n_of(sec)
    lfo = osc([5.5] * n)
    base_f = [58 + 10 * math.sin(math.pi * i / n) + 3 * lfo[i] for i in range(n)]
    growl = mix(osc(base_f, "saw"), scale(osc([f * 1.51 for f in base_f], "saw"), 0.5), scale(osc([f * 0.5 for f in base_f]), 0.8))
    rough = svf(noise(sec, rng), 60, 0.7)
    rmax = max(abs(x) for x in rough) or 1.0
    growl = [g * (0.65 + 0.35 * r / rmax) for g, r in zip(growl, rough)]
    growl = svf(growl, [700 + 900 * math.sin(math.pi * i / n) for i in range(n)], 1.6)
    breath = svf(noise(sec, rng), 1200, 1.0, "bp")
    att = n_of(0.18)
    env = [min(1.0, i / att) * (1.0 if i < n * 0.6 else math.exp(-(i - n * 0.6) / (0.18 * SR))) for i in range(n)]
    return mul(drive(mix(growl, scale(breath, 0.35)), 2.6), env)


def ui_move():
    n = n_of(0.045)
    return mul(mix(osc([1250] * n, "tri"), scale(osc([2500] * n), 0.2)), env_exp(n, 0.001, 0.012))


def ui_confirm():
    a = mul(osc([700] * n_of(0.07), "tri"), env_exp(n_of(0.07), 0.001, 0.03))
    b = mul(osc([1050] * n_of(0.14), "tri"), env_exp(n_of(0.14), 0.001, 0.05))
    return mix(a, delay(b, 0.055))


SOUNDS = {
    "swing_1": lambda: swing(101), "swing_2": lambda: swing(102), "swing_3": lambda: swing(103),
    "hit_flesh_1": lambda: hit_flesh(201), "hit_flesh_2": lambda: hit_flesh(202), "hit_flesh_3": lambda: hit_flesh(203),
    "hit_heavy": hit_heavy, "wall_slam": wall_slam, "pogo": pogo, "roll": roll, "dash": dash,
    "jump": jump, "land": land, "hero_hurt": hero_hurt, "enemy_death": enemy_death,
    "amulet_tick": amulet_tick, "flare": flare, "rune_chime": rune_chime, "door_open": door_open,
    "ember_pickup": ember_pickup, "boss_roar": boss_roar, "ui_move": ui_move, "ui_confirm": ui_confirm,
}


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, fn in SOUNDS.items():
        path, dur = write(name, fn())
        print("%-14s %5.2f s  %s" % (name, dur, path))


if __name__ == "__main__":
    main()

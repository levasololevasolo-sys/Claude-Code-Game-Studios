"""Second SFX pass of «Навь»: UI cues (ui-style-guide §10.2), dismemberment,
parry, enemy wind-ups and attacks, bosses, world, footsteps and ambient loops.

Imported by build_sfx.py (which writes the files). numpy only. Design rules:
- nothing is a bare oscillator: every sound is layered filtered noise, struck
  inharmonic modes (wood, iron, bone, bells), pitch envelopes and a short
  synthetic room tail, so it reads as weighty and organic, not as 8-bit;
- frequent sounds have 2-3 variants (different seeds and tunings); Audio adds a
  random pitch spread on top (audio.json `pitch`);
- ambient loops are built circularly (FFT-shaped noise, events wrapped around
  the end, circular reverb), so the last sample runs into the first: seamless.
Each function takes nothing and returns a float numpy array at SR; fixed seeds
keep a rebuild byte-identical.
"""
import numpy as np

SR = 44100


# ---------------------------------------------------------------- primitives

def n_of(sec):
    return int(sec * SR)


def t_of(n):
    return np.arange(n) / SR


def rng_of(seed):
    return np.random.default_rng(seed)


def noise(n, rng):
    return rng.uniform(-1.0, 1.0, n)


def env(n, attack, decay):
    """Linear attack (s), exponential decay with time constant `decay` (s)."""
    t = t_of(n)
    a = max(attack, 1e-4)
    return np.where(t < a, t / a, np.exp(-(t - a) / decay))


def sweep(n, a, b, curve=1.0):
    x = (np.arange(n) / max(1, n - 1)) ** curve
    return a * (b / a) ** x


def svf(sig, cutoff, q=0.7, mode="lp"):
    """Chamberlin state-variable filter, cutoff a float or per-sample array."""
    cut = np.broadcast_to(np.asarray(cutoff, dtype=float), sig.shape)
    f = 2.0 * np.sin(np.pi * np.minimum(cut, SR / 6.0) / SR)
    damp = 1.0 / q
    out = np.empty_like(sig)
    low = band = 0.0
    sl, fl = sig.tolist(), f.tolist()
    o = [0.0] * len(sl)
    for i in range(len(sl)):
        low += fl[i] * band
        high = sl[i] - low - damp * band
        band += fl[i] * high
        o[i] = low if mode == "lp" else (band if mode == "bp" else high)
    out[:] = o
    return out


def band(sig, lo, hi, tilt=0.0):
    """Static FFT band-pass (circular, zero-phase); tilt dB/octave above lo."""
    spec = np.fft.rfft(sig)
    fr = np.fft.rfftfreq(len(sig), 1.0 / SR)
    g = np.ones_like(fr)
    g *= 1.0 / (1.0 + (lo / np.maximum(fr, 1.0)) ** 4)
    g *= 1.0 / (1.0 + (fr / hi) ** 4)
    if tilt:
        g *= (np.maximum(fr, lo) / lo) ** (tilt / 6.02)
    return np.fft.irfft(spec * g, len(sig))


def osc(freq, n=None, shape="sine", phase=0.0):
    f = np.broadcast_to(np.asarray(freq, dtype=float), (n,)) if n else np.asarray(freq, dtype=float)
    p = np.cumsum(f) / SR + phase
    if shape == "sine":
        return np.sin(2 * np.pi * p)
    if shape == "saw":
        return 2.0 * (p - np.floor(p)) - 1.0
    return 4.0 * np.abs(p - np.floor(p) - 0.5) - 1.0


def pad(sig, n):
    return np.pad(sig, (0, max(0, n - len(sig))))


def mix(*layers):
    n = max(len(l) for l in layers)
    out = np.zeros(n)
    for l in layers:
        out[:len(l)] += l
    return out


def at(sig, sec):
    return np.concatenate([np.zeros(n_of(sec)), sig])


def drive(sig, k):
    return np.tanh(sig * k)


def thump(sec, f0, f1, decay, curve=0.5):
    n = n_of(sec)
    return osc(sweep(n, f0, f1, curve)) * env(n, 0.002, decay)


def burst(sec, rng, c0, c1, decay, q=0.8, mode="lp", attack=0.001):
    n = n_of(sec)
    return svf(noise(n, rng), sweep(n, c0, c1), q, mode) * env(n, attack, decay)


def whoosh(sec, rng, c0, cpeak, c1, q=1.6, mode="bp", shape=0.6):
    n = n_of(sec)
    k = n // 3
    cut = np.concatenate([sweep(k, c0, cpeak), sweep(n - k, cpeak, c1)])
    e = np.sin(np.pi * np.minimum(1.0, (np.arange(n) / n) ** shape)) ** 1.5
    return svf(noise(n, rng), cut, q, mode) * e


def modes(sec, rng, partials, attack=0.001, detune=0.003):
    """Struck body: sum of decaying partials (freq, amp, decay) + random detune."""
    n = n_of(sec)
    out = np.zeros(n)
    for f, a, d in partials:
        ff = f * (1.0 + rng.uniform(-detune, detune))
        out += a * osc(ff, n, phase=rng.uniform()) * env(n, attack, d)
    return out


def grains(sec, rng, count, glen, amp_decay, lo=800.0, hi=6000.0, start=0.0, power=1.4):
    """Sparse clicks / crackle / grit: `count` tiny noise grains."""
    n = n_of(sec)
    out = np.zeros(n)
    g = max(8, n_of(glen))
    for _ in range(count):
        p = n_of(start) + int(rng.random() ** power * max(1, n - n_of(start) - g))
        a = rng.uniform(0.3, 1.0) * np.exp(-(p / SR) / amp_decay)
        out[p:p + g] += a * rng.uniform(-1, 1, g) * np.linspace(1, 0, g) ** 2
    return band(out, lo, hi)


def tail(sig, rng, sec=0.35, decay=0.09, wet=0.18, lo=300.0, hi=5000.0):
    """Short synthetic room: convolve with a decaying band-limited noise burst."""
    n = n_of(sec)
    ir = band(noise(n, rng), lo, hi) * env(n, 0.003, decay)
    ir /= np.sqrt(np.sum(ir ** 2)) + 1e-9
    m = len(sig) + n
    wetsig = np.fft.irfft(np.fft.rfft(sig, m) * np.fft.rfft(ir, m), m)
    return mix(sig, wetsig * wet * 4.0)


def vib(n, rate, depth, rng):
    return 1.0 + depth * np.sin(2 * np.pi * rate * t_of(n) + rng.uniform(0, 6.28))


def voice(sec, rng, f0, f1, formants, rough=0.3, curve=1.0):
    """Throat-like source (saw + jitter) through formant band-passes."""
    n = n_of(sec)
    f = sweep(n, f0, f1, curve) * vib(n, 5.5, 0.03, rng) * (1 + 0.02 * band(noise(n, rng), 20, 80) * 8)
    src = osc(f, n, "saw") * (1 - rough) + noise(n, rng) * rough
    return mix(*[svf(src, fc, q, "bp") * a for fc, q, a in formants])


# ---------------------------------------------------------------- UI (§10.2)

def ui_hover_wood():
    r = rng_of(2001)
    knock = modes(0.05, r, [(1850, 1.0, 0.008), (2930, 0.5, 0.006), (4100, 0.25, 0.004)])
    return mix(knock, burst(0.05, r, 5000, 2000, 0.004, 0.9, "bp") * 0.5)


def ui_open_wood():
    r = rng_of(2002)
    knock = modes(0.2, r, [(310, 1.0, 0.03), (720, 0.6, 0.02), (1240, 0.35, 0.012)])
    cloth = whoosh(0.19, r, 400, 2400, 900, 0.8) * 0.5
    return tail(mix(knock + thump(0.2, 160, 70, 0.03) * 0.5, cloth), r, 0.2, 0.05, 0.12)


def ui_close():
    r = rng_of(2003)
    return tail(mix(modes(0.11, r, [(220, 1.0, 0.025), (540, 0.4, 0.012)]), thump(0.1, 120, 60, 0.02) * 0.6,
                    burst(0.06, r, 1500, 400, 0.01) * 0.3), r, 0.15, 0.04, 0.1)


def ui_cancel_wood():
    r = rng_of(2004)
    return mix(modes(0.08, r, [(420, 1.0, 0.018), (980, 0.4, 0.01)]), burst(0.05, r, 2500, 700, 0.008) * 0.3)


def ui_confirm_gold():
    r = rng_of(2005)
    strike = burst(0.04, r, 8000, 3000, 0.005, 0.7) * 0.8
    ring = modes(0.32, r, [(1180, 1.0, 0.12), (2790, 0.5, 0.07), (4410, 0.3, 0.05), (6120, 0.15, 0.03)])
    return tail(mix(strike, ring, thump(0.08, 300, 150, 0.015) * 0.4), r, 0.3, 0.08, 0.15)


def ui_error_clank():
    r = rng_of(2006)
    dull = modes(0.15, r, [(240, 1.0, 0.03), (385, 0.8, 0.025), (610, 0.5, 0.02), (930, 0.3, 0.012)], detune=0.02)
    return drive(mix(dull, burst(0.06, r, 2200, 500, 0.012, 0.7) * 0.6), 1.6)


def ui_open_god():
    r = rng_of(2007)
    n = n_of(0.4)
    choir = voice(0.4, r, 146.8, 146.8, [(600, 4, 1.0), (1040, 5, 0.6), (2250, 6, 0.3)], 0.15)
    choir += voice(0.4, r, 220.0 * 1.003, 220.0, [(700, 4, 0.7), (1220, 5, 0.4)], 0.15) * 0.6
    swell = (np.arange(n) / n) ** 1.6
    hum = osc(73.4, n) * 0.4 * swell
    return tail(choir * swell + hum, r, 0.4, 0.15, 0.2)


def ui_card_deal():
    r = rng_of(2008)
    return mix(whoosh(0.07, r, 1500, 6000, 2500, 1.2), grains(0.07, r, 6, 0.003, 0.05, 2000, 8000) * 0.4)


def ui_rune_select():
    r = rng_of(2009)
    anvil = modes(0.4, r, [(880, 1.0, 0.16), (2350, 0.5, 0.1), (3900, 0.3, 0.06), (5300, 0.12, 0.04)])
    hit = mix(burst(0.04, r, 9000, 2000, 0.006), thump(0.12, 220, 90, 0.025) * 0.8)
    thread = at(osc(sweep(n_of(0.22), 1320, 1500), n_of(0.22), "tri") * env(n_of(0.22), 0.02, 0.06) * 0.15, 0.05)
    bell = at(modes(0.35, r, [(1760, 0.5, 0.15), (2640, 0.25, 0.1)]), 0.09)
    return tail(mix(anvil, hit, thread, bell), r, 0.4, 0.12, 0.18)


def ui_thread_run():
    r = rng_of(2010)
    n = n_of(0.2)
    return whoosh(0.2, r, 3000, 7000, 4000, 3.0) * 0.6 + svf(noise(n, r), 9000, 2.0, "bp") * env(n, 0.05, 0.06) * 0.2


def ui_bark_unroll():
    r = rng_of(2011)
    crinkle = grains(0.2, r, 40, 0.004, 0.2, 1500, 7000, power=1.0)
    return mix(whoosh(0.2, r, 600, 3000, 1200, 1.0) * 0.6, crinkle * 0.7)


def ui_text_tick():
    r = rng_of(2012)
    return modes(0.02, r, [(1500, 1.0, 0.004), (2700, 0.4, 0.003)]) + burst(0.02, r, 3000, 1500, 0.003) * 0.3


def ui_shop_knock():
    r = rng_of(2013)
    k = mix(modes(0.12, r, [(260, 1.0, 0.03), (610, 0.6, 0.02), (1300, 0.3, 0.01)]), thump(0.12, 140, 60, 0.03))
    return tail(mix(k, at(k * 0.8, 0.13)), r, 0.25, 0.07, 0.15)


def ui_forge_buy():
    r = rng_of(2014)
    anvil = modes(0.4, r, [(660, 1.0, 0.15), (1720, 0.6, 0.09), (2980, 0.3, 0.06), (4350, 0.15, 0.04)])
    hiss = at(burst(0.3, r, 6000, 2500, 0.1, 1.2, "bp", attack=0.03) * 0.4, 0.08)
    return tail(mix(anvil, thump(0.15, 180, 70, 0.03), burst(0.03, r, 9000, 3000, 0.004), hiss), r, 0.3, 0.1, 0.15)


def ui_page_turn():
    r = rng_of(2015)
    return mix(whoosh(0.15, r, 800, 4500, 1500, 1.1, shape=0.4), grains(0.15, r, 14, 0.003, 0.15, 2000, 8000) * 0.5)


def ui_tab_switch():
    r = rng_of(2016)
    return mix(whoosh(0.08, r, 1200, 4000, 2000, 1.3), modes(0.04, r, [(1600, 0.3, 0.006)]))


def ui_count_tick():
    r = rng_of(2017)
    return mix(grains(0.03, r, 3, 0.002, 0.02, 1500, 9000), thump(0.03, 900, 400, 0.005) * 0.2)


def ui_thread_snap():
    r = rng_of(2018)
    n = n_of(0.08)
    snap = osc(sweep(n, 2400, 300, 0.4), n, "tri") * env(n, 0.0005, 0.012) * 0.6
    whip = whoosh(0.1, r, 3000, 7000, 1500, 2.0) * 0.5
    thud = at(mix(thump(0.3, 110, 40, 0.08), burst(0.2, r, 1200, 200, 0.04) * 0.6), 0.09)
    return tail(mix(burst(0.01, r, 8000, 4000, 0.002), snap, whip, thud), r, 0.4, 0.12, 0.2)


def ui_victory_swell():
    r = rng_of(2019)
    bell = modes(0.6, r, [(392, 1.0, 0.35), (784 * 1.002, 0.5, 0.25), (1050, 0.35, 0.18), (1470, 0.2, 0.12), (196, 0.4, 0.4)])
    n = n_of(0.6)
    choir = voice(0.6, r, 196, 196, [(650, 4, 1.0), (1100, 5, 0.5)], 0.12) * np.minimum(1, np.arange(n) / n_of(0.25)) * 0.5
    return tail(mix(bell, choir), r, 0.6, 0.2, 0.25)


def ui_door_near():
    r = rng_of(2020)
    return tail(modes(0.2, r, [(1320, 1.0, 0.08), (3170, 0.3, 0.04), (2210, 0.2, 0.05)], attack=0.004), r, 0.25, 0.08, 0.2)


def ui_codex_new():
    r = rng_of(2021)
    return tail(mix(ui_page_turn() * 0.6, at(modes(0.25, r, [(2093, 0.7, 0.1), (3140, 0.3, 0.06)]), 0.06)), r, 0.3, 0.1, 0.18)


def ui_rebind_wait():
    r = rng_of(2022)
    one = modes(0.03, r, [(1100, 1.0, 0.006), (2400, 0.3, 0.004)]) * 0.6
    return mix(pad(one, n_of(0.5)), at(one * 0.5, 0.25))


def ui_menu_start():
    r = rng_of(2023)
    bell = modes(1.6, r, [(98, 1.0, 0.8), (196 * 1.004, 0.6, 0.6), (233, 0.35, 0.45), (293, 0.3, 0.4), (523, 0.15, 0.2), (49, 0.4, 0.9)])
    return tail(mix(bell, thump(0.3, 90, 45, 0.1) * 0.5), r, 0.9, 0.35, 0.25, 150, 3000)


UI = [ui_hover_wood, ui_open_wood, ui_close, ui_cancel_wood, ui_confirm_gold, ui_error_clank, ui_open_god,
      ui_card_deal, ui_rune_select, ui_thread_run, ui_bark_unroll, ui_text_tick, ui_shop_knock, ui_forge_buy,
      ui_page_turn, ui_tab_switch, ui_count_tick, ui_thread_snap, ui_victory_swell, ui_door_near, ui_codex_new,
      ui_rebind_wait, ui_menu_start]


# ---------------------------------------------------------------- combat: limbs, parry, deaths

def _bone_crack(r, sec=0.08):
    return grains(sec, r, 9, 0.0025, 0.03, 1200, 7000, power=2.0) * 1.4


def limb_sever(seed):
    r = rng_of(seed)
    v = seed % 2
    chop = burst(0.06, r, 7000 - v * 800, 1500, 0.01, 0.8) * 1.0
    wet = burst(0.25, r, 1800 + v * 300, 250, 0.06, 1.8, "bp") * 0.8
    squelch = svf(noise(n_of(0.22), r) * env(n_of(0.22), 0.01, 0.05), sweep(n_of(0.22), 900, 300), 4.0, "bp") * 0.6
    body = thump(0.2, 190 - v * 20, 55, 0.045)
    return tail(drive(mix(chop, at(_bone_crack(r), 0.012), wet, squelch, body), 1.7), r, 0.3, 0.06, 0.12)


def limb_head_pop():
    r = rng_of(3101)
    chop = mix(burst(0.08, r, 8000, 1000, 0.016, 0.8) * 1.2, thump(0.3, 150, 38, 0.08) * 1.2)
    crack = at(_bone_crack(r, 0.1) * 1.2, 0.01)
    wet = burst(0.3, r, 1500, 200, 0.08, 1.6, "bp")
    fly = at(whoosh(0.35, r, 300, 1800, 500, 1.4) * 0.7, 0.07)
    return tail(drive(mix(chop, crack, wet, fly), 1.9), r, 0.35, 0.08, 0.14)


def limb_part_thud(seed):
    r = rng_of(seed)
    v = seed % 2
    thud = mix(thump(0.18, 120 + v * 25, 45, 0.04), burst(0.12, r, 1400, 250, 0.025, 0.7) * 0.7)
    slap = burst(0.05, r, 2500, 800, 0.01, 1.5, "bp") * 0.5
    bounce = at(thump(0.1, 110, 50, 0.02) * 0.35, 0.11 + v * 0.03)
    return mix(thud, slap, bounce)


def parry_clang(seed):
    r = rng_of(seed)
    v = seed % 2
    k = 1.0 + v * 0.07
    ring = modes(0.45, r, [(1530 * k, 1.0, 0.11), (2310 * k, 0.8, 0.08), (3720 * k, 0.6, 0.05), (5150 * k, 0.4, 0.035),
                           (7020 * k, 0.25, 0.02)], detune=0.006)
    strike = burst(0.02, r, 12000, 5000, 0.003, 0.6) * 1.5
    spark = at(grains(0.12, r, 18, 0.0015, 0.05, 5000, 14000), 0.004) * 0.8
    return tail(mix(strike, ring, spark, thump(0.06, 400, 200, 0.01) * 0.4), r, 0.3, 0.07, 0.16, 1500, 9000)


def parry_start():
    """Short swish of the guard coming up (parry pressed)."""
    r = rng_of(3311)
    return mix(whoosh(0.13, r, 1500, 6500, 2500, 2.4), whoosh(0.1, r, 400, 1200, 500, 1.2, "lp") * 0.3)


def parry_whiff():
    r = rng_of(3301)
    return mix(whoosh(0.22, r, 700, 4200, 900, 2.0), whoosh(0.22, r, 200, 600, 200, 1.0, "lp") * 0.4)


def enemy_death_v(seed):
    """Death variants: gurgle + slump, distinct from the first enemy_death."""
    r = rng_of(seed)
    v = seed % 2
    n = n_of(0.6)
    gurgle = voice(0.45, r, 170 + v * 40, 60, [(500 + v * 150, 5, 1.0), (1100, 6, 0.4)], 0.35, 0.7) * env(n_of(0.45), 0.01, 0.15)
    wet = burst(0.3, r, 2500, 200, 0.07, 0.8)
    slump = at(mix(thump(0.25, 100, 35, 0.07), burst(0.2, r, 1200, 200, 0.04) * 0.7), 0.25 + v * 0.06)
    out = drive(mix(gurgle * 0.7, wet, thump(0.2, 140, 50, 0.05), slump), 1.7)
    return tail(pad(out, n), r, 0.3, 0.07, 0.12)


# ---------------------------------------------------------------- hero

def step(seed, surface):
    r = rng_of(seed)
    v = seed % 3
    if surface == "mud":
        body = thump(0.12, 90 + v * 8, 45, 0.03) * 0.6
        squish = svf(noise(n_of(0.14), r) * env(n_of(0.14), 0.008, 0.035), sweep(n_of(0.14), 700 + v * 80, 250), 3.0, "bp")
        return mix(body, squish, burst(0.08, r, 1500, 400, 0.015) * 0.3)
    if surface == "snow":
        crunch = grains(0.12, r, 30, 0.002, 0.06, 1500, 8000, power=1.2)
        return mix(crunch, thump(0.08, 100, 50, 0.02) * 0.4, burst(0.09, r, 3000 + v * 300, 1200, 0.02, 0.9, "bp") * 0.4)
    if surface == "wood":
        return mix(modes(0.1, r, [(180 + v * 15, 1.0, 0.025), (410 + v * 20, 0.5, 0.015), (950, 0.2, 0.008)]),
                   burst(0.05, r, 2500, 600, 0.008) * 0.4, thump(0.08, 110, 55, 0.02) * 0.5)
    # dirt / forest floor: leaves and soil
    return mix(thump(0.1, 100 + v * 10, 48, 0.025) * 0.7, burst(0.1, r, 1800 + v * 200, 400, 0.02, 0.7) * 0.6,
               grains(0.1, r, 8, 0.003, 0.05, 2000, 7000) * 0.4)


def hero_death():
    r = rng_of(4101)
    groan = voice(0.6, r, 210, 90, [(650, 5, 1.0), (1100, 5, 0.5), (2400, 6, 0.2)], 0.25, 0.8) * env(n_of(0.6), 0.01, 0.2)
    fall = at(mix(thump(0.4, 90, 30, 0.12) * 1.2, burst(0.3, r, 1500, 150, 0.06) * 0.8,
                  modes(0.3, r, [(520, 0.3, 0.06), (1340, 0.2, 0.04)])), 0.35)
    return tail(drive(mix(groan * 0.8, fall), 1.6), r, 0.6, 0.2, 0.2)


def hero_revive():
    r = rng_of(4102)
    n = n_of(0.9)
    rise = svf(noise(n, r), sweep(n, 300, 5000, 1.5), 3.0, "bp") * np.minimum(1, np.arange(n) / n) ** 1.5
    bell = at(modes(0.9, r, [(523, 0.6, 0.3), (784, 0.4, 0.22), (1047, 0.3, 0.15)]), 0.55)
    breath = at(burst(0.3, r, 2500, 600, 0.08, 0.8) * 0.5, 0.6)
    return tail(mix(rise * 0.6, bell, breath), r, 0.5, 0.15, 0.2)


def weapon_swap():
    r = rng_of(4103)
    scrape = svf(noise(n_of(0.16), r), sweep(n_of(0.16), 3000, 6000), 6.0, "bp") * env(n_of(0.16), 0.03, 0.05)
    clink = at(modes(0.15, r, [(2100, 0.6, 0.04), (3400, 0.4, 0.03)]), 0.12)
    return mix(scrape * 0.6, clink, at(thump(0.06, 200, 100, 0.012) * 0.4, 0.12))


def weapon_pickup():
    r = rng_of(4104)
    return tail(mix(weapon_swap(), at(modes(0.3, r, [(880, 0.4, 0.1), (1320, 0.3, 0.08)]), 0.15)), r, 0.3, 0.08, 0.12)


# ---------------------------------------------------------------- amulet

def amulet_ready():
    r = rng_of(4201)
    n = n_of(0.5)
    hum = (osc(220, n) + 0.5 * osc(330.7, n) + 0.3 * osc(441, n)) * env(n, 0.06, 0.15) * 0.4
    shimmer = svf(noise(n, r), 7000, 4.0, "bp") * env(n, 0.05, 0.12) * 0.3
    return tail(mix(hum, shimmer, modes(0.4, r, [(1760, 0.3, 0.1), (2640, 0.2, 0.07)])), r, 0.4, 0.12, 0.2)


def amulet_overcharge():
    r = rng_of(4202)
    n = n_of(0.7)
    f = 110 * vib(n, 9.0, 0.04, r)
    buzz = svf(osc(f, n, "saw") + 0.5 * osc(f * 1.5, n, "saw"), 1500, 1.2) * env(n, 0.05, 0.35)
    crackle = grains(0.7, r, 50, 0.002, 0.6, 3000, 12000, power=1.0)
    return drive(mix(buzz * 0.6, crackle * 0.7), 1.8)


def amulet_crack():
    r = rng_of(4203)
    crack = mix(burst(0.02, r, 10000, 4000, 0.003), grains(0.15, r, 14, 0.002, 0.05, 2000, 10000, power=2.0) * 1.2)
    ring = modes(0.5, r, [(1950, 0.5, 0.12), (3130, 0.35, 0.08), (4770, 0.2, 0.05)], detune=0.02)
    spill = at(burst(0.4, r, 4000, 600, 0.12, 1.1, "bp") * 0.5, 0.05)
    return tail(mix(crack, ring, spill, thump(0.15, 160, 60, 0.03) * 0.6), r, 0.4, 0.1, 0.18)


def flare_fizzle():
    r = rng_of(4204)
    n = n_of(0.35)
    puff = svf(noise(n, r), sweep(n, 3000, 400), 1.0, "bp") * env(n, 0.01, 0.1)
    return mix(puff, grains(0.3, r, 10, 0.002, 0.12, 2000, 8000) * 0.4, thump(0.15, 140, 60, 0.04) * 0.3)


# ---------------------------------------------------------------- enemies

def enemy_wake():
    r = rng_of(5001)
    g = voice(0.3, r, 120, 150, [(450, 4, 1.0), (900, 4, 0.5)], 0.4) * env(n_of(0.3), 0.04, 0.1)
    return tail(drive(g, 2.0), r, 0.3, 0.08, 0.15)


def growl_small(seed):
    r = rng_of(seed)
    v = seed % 2
    sec = 0.35 + v * 0.05
    g = voice(sec, r, 140 + v * 30, 110, [(500 + v * 100, 4, 1.0), (1200, 5, 0.5), (2500, 6, 0.15)], 0.45)
    n = n_of(sec)
    return drive(g * np.minimum(1, np.arange(n) / n_of(0.08)) * env(n, 0.0, 0.25), 2.2)


def wolf_growl():
    r = rng_of(5101)
    n = n_of(0.6)
    g = voice(0.6, r, 85, 95, [(380, 4, 1.0), (820, 5, 0.6), (2100, 6, 0.2)], 0.5)
    trem = 0.6 + 0.4 * np.abs(np.sin(2 * np.pi * 14 * t_of(n)))
    return drive(g * trem * np.minimum(1, np.arange(n) / n_of(0.1)) * env(n, 0.0, 0.4), 2.4)


def bite_snap():
    r = rng_of(5102)
    clack = modes(0.06, r, [(900, 1.0, 0.01), (1700, 0.6, 0.008), (2600, 0.3, 0.005)], detune=0.03)
    return mix(whoosh(0.08, r, 500, 2500, 800, 1.5) * 0.5, at(mix(clack, burst(0.05, r, 4000, 800, 0.01) * 0.6), 0.06),
               at(thump(0.08, 160, 70, 0.02) * 0.5, 0.06))


def lunge_whoosh(seed):
    r = rng_of(seed)
    v = seed % 2
    k = 1.0 - v * 0.25
    return mix(whoosh(0.3, r, 250 * k, 2200 * k, 400 * k, 1.4), whoosh(0.3, r, 100, 500 * k, 120, 0.9, "lp") * 0.7)


def claw_swipe():
    r = rng_of(5104)
    rip = mix(whoosh(0.18, r, 1200, 6500, 2000, 2.6), whoosh(0.18, r, 800, 4200, 1500, 2.0) * 0.6)
    return mix(rip, grains(0.18, r, 10, 0.002, 0.1, 3000, 9000, start=0.05) * 0.5)


def bat_screech():
    r = rng_of(5105)
    n = n_of(0.3)
    f = sweep(n, 2600, 3600, 0.5) * vib(n, 38, 0.06, r)
    s = svf(osc(f, n, "saw"), 4500, 3.0, "bp") * env(n, 0.01, 0.1)
    return mix(s * 0.7, whoosh(0.3, r, 2000, 7000, 3000, 2.0) * 0.4)


def spit_wind():
    r = rng_of(5106)
    spit = mix(burst(0.12, r, 3500, 800, 0.03, 1.8, "bp"), svf(noise(n_of(0.1), r) * env(n_of(0.1), 0.002, 0.02), 1200, 5.0, "bp") * 0.6)
    return mix(spit, at(whoosh(0.35, r, 300, 2500, 700, 1.2) * 0.6, 0.04))


def bloat_swell():
    r = rng_of(5107)
    n = n_of(0.8)
    stretch = svf(noise(n, r), sweep(n, 150, 700, 1.5), 6.0, "bp") * np.minimum(1, np.arange(n) / n) ** 1.2
    bubbles = mix(*[at(svf(noise(n_of(0.04), r) * env(n_of(0.04), 0.002, 0.01), 400 + i * 90, 8.0, "bp"), 0.1 + i * 0.09)
                    for i in range(7)])
    return mix(stretch * 0.8, bubbles * 0.7, osc(sweep(n, 50, 90), n) * 0.3 * np.arange(n) / n)


def bloat_burst():
    r = rng_of(5108)
    pop = mix(burst(0.04, r, 9000, 2000, 0.008) * 1.2, thump(0.4, 110, 30, 0.1) * 1.2)
    splat = burst(0.4, r, 2500, 200, 0.1, 1.3, "bp")
    drips = grains(0.6, r, 16, 0.012, 0.4, 400, 2000, start=0.15)
    return tail(drive(mix(pop, splat, drips * 0.8), 2.0), r, 0.4, 0.1, 0.15)


def frost_charge():
    r = rng_of(5109)
    n = n_of(0.6)
    swell = np.minimum(1, np.arange(n) / n) ** 1.5
    crys = grains(0.6, r, 40, 0.002, 2.0, 4000, 14000, power=0.6) * swell
    wind = svf(noise(n, r), sweep(n, 800, 4000), 4.0, "bp") * swell * 0.5
    return mix(crys, wind, modes(0.6, r, [(2637, 0.15, 0.4), (3951, 0.1, 0.3)]) * swell)


def frost_breath():
    r = rng_of(5110)
    n = n_of(1.0)
    e = np.minimum(1, np.arange(n) / n_of(0.1)) * env(n, 0.0, 0.6)
    gust = svf(noise(n, r), 2500 + 800 * np.sin(2 * np.pi * 1.5 * t_of(n)), 0.9, "bp") * e
    ice = grains(1.0, r, 60, 0.002, 0.8, 4000, 12000, power=1.0)
    return mix(gust, ice * 0.5, svf(noise(n, r), 200, 0.7) * e * 0.6)


def knight_windup():
    r = rng_of(5111)
    n = n_of(0.45)
    scrape = svf(noise(n, r), sweep(n, 1500, 4500, 0.8), 8.0, "bp") * np.minimum(1, np.arange(n) / n) * 0.5
    grunt = at(voice(0.25, r, 110, 90, [(500, 4, 1.0), (1000, 5, 0.4)], 0.3) * env(n_of(0.25), 0.02, 0.1), 0.15)
    rattle = grains(0.45, r, 12, 0.004, 1.0, 1500, 6000, power=1.0) * 0.4
    return drive(mix(scrape, grunt * 0.8, rattle), 1.5)


def shield_raise():
    r = rng_of(5112)
    return mix(whoosh(0.18, r, 300, 1200, 400, 1.0, "lp"),
               at(modes(0.2, r, [(330, 0.8, 0.05), (760, 0.4, 0.03), (1450, 0.2, 0.02)]), 0.12), at(thump(0.1, 150, 70, 0.02) * 0.6, 0.12))


def shield_block():
    r = rng_of(5113)
    wood = modes(0.25, r, [(190, 1.0, 0.05), (450, 0.7, 0.03), (870, 0.4, 0.02)], detune=0.02)
    iron = modes(0.3, r, [(1270, 0.4, 0.08), (2050, 0.3, 0.05)])
    return tail(drive(mix(wood, iron, thump(0.15, 150, 50, 0.04), burst(0.05, r, 5000, 1000, 0.008) * 0.6), 1.6), r, 0.3, 0.07, 0.14)


def shield_bash():
    r = rng_of(5114)
    return mix(whoosh(0.12, r, 300, 1500, 500, 1.2) * 0.5, at(shield_block() * 1.0, 0.08), at(thump(0.3, 100, 35, 0.07) * 0.8, 0.08))


def bell_ring():
    r = rng_of(5115)
    bell = modes(1.4, r, [(311, 1.0, 0.6), (622 * 1.006, 0.5, 0.45), (741, 0.4, 0.4), (933, 0.3, 0.3), (1245, 0.2, 0.2), (155, 0.3, 0.7)])
    clap = burst(0.03, r, 8000, 2000, 0.005) * 0.8
    return tail(mix(bell, clap), r, 0.8, 0.3, 0.25, 200, 4000)


def spirit_appear():
    r = rng_of(5116)
    n = n_of(0.6)
    rise = svf(noise(n, r), sweep(n, 200, 3000, 1.3), 5.0, "bp") * np.sin(np.pi * np.arange(n) / n)
    moan = voice(0.6, r, 180, 260, [(550, 6, 1.0), (900, 6, 0.4)], 0.5) * np.sin(np.pi * np.arange(n) / n) * 0.4
    return tail(mix(rise, moan), r, 0.5, 0.15, 0.25)


def spirit_vanish():
    r = rng_of(5117)
    n = n_of(0.45)
    fall = svf(noise(n, r), sweep(n, 4000, 250, 0.7), 4.0, "bp") * env(n, 0.005, 0.15)
    return tail(mix(fall, thump(0.2, 200, 60, 0.05) * 0.3), r, 0.4, 0.12, 0.25)


def dig_dirt():
    r = rng_of(5118)
    out = np.zeros(n_of(0.6))
    for i in range(4):
        s = burst(0.1, r, 1500, 300, 0.025, 0.8) * 0.8 + grains(0.1, r, 8, 0.003, 0.06, 800, 4000) * 0.5
        out = mix(out, at(s, i * 0.13 + r.uniform(0, 0.03)))
    return out


def dirt_burst():
    r = rng_of(5119)
    blast = mix(thump(0.3, 130, 35, 0.07) * 1.2, burst(0.3, r, 2500, 200, 0.06, 0.7))
    rubble = grains(0.5, r, 40, 0.005, 0.25, 500, 4000, start=0.03)
    return tail(drive(mix(blast, rubble), 1.8), r, 0.3, 0.08, 0.12)


def bow_draw():
    r = rng_of(5120)
    n = n_of(0.45)
    creak = svf(osc(70 + 30 * np.arange(n) / n + 6 * np.sin(2 * np.pi * 13 * t_of(n)), n, "saw"), 1100, 5.0, "bp")
    return mix(creak * np.minimum(1, np.arange(n) / n_of(0.1)) * 0.5, svf(noise(n, r), 3500, 3.0, "bp") * 0.15 * np.arange(n) / n)


def shot_fire():
    r = rng_of(5121)
    return mix(whoosh(0.2, r, 600, 3500, 1200, 1.8), burst(0.05, r, 3000, 800, 0.01, 1.3, "bp") * 0.6)


def fire_whoosh():
    r = rng_of(5122)
    n = n_of(0.6)
    roar = svf(noise(n, r), sweep(n, 400, 1500, 0.5), 0.8) * np.sin(np.pi * np.minimum(1, np.arange(n) / n) ** 0.5)
    crackle = grains(0.6, r, 30, 0.002, 0.5, 2000, 9000, power=1.0)
    return mix(roar, crackle * 0.5)


# ---------------------------------------------------------------- bosses

def boss_summon():
    r = rng_of(5201)
    n = n_of(1.0)
    swell = np.minimum(1, np.arange(n) / n) ** 1.3
    choir = voice(1.0, r, 73, 70, [(400, 4, 1.0), (750, 5, 0.6), (2000, 6, 0.2)], 0.35) * swell
    rumble = svf(noise(n, r), 120, 0.8) * swell
    return tail(drive(mix(choir, rumble * 1.4, at(thump(0.3, 80, 30, 0.1), 0.95)[:n]), 1.8), r, 0.6, 0.2, 0.2)


def boss_death():
    r = rng_of(5202)
    wail = voice(1.6, r, 140, 40, [(550, 4, 1.0), (1000, 5, 0.5), (2300, 6, 0.2)], 0.4, 0.8) * env(n_of(1.6), 0.02, 0.6)
    fall = at(mix(thump(0.8, 70, 22, 0.3) * 1.4, burst(0.8, r, 1500, 100, 0.2), grains(1.0, r, 50, 0.006, 0.5, 400, 3000) * 0.7), 0.9)
    return tail(drive(mix(wail, fall), 1.8), r, 1.0, 0.35, 0.25, 150, 3000)


def likho_gaze():
    r = rng_of(5203)
    n = n_of(1.0)
    drone = (osc(55, n) + 0.6 * osc(55 * 1.059, n) + 0.4 * osc(82.4 * 0.995, n)) * np.minimum(1, np.arange(n) / n_of(0.4))
    whisper = svf(noise(n, r), 2500 + 1500 * np.sin(2 * np.pi * 0.8 * t_of(n)), 3.0, "bp") * 0.4
    return tail(svf(drone, 600, 0.9) * env(n, 0.0, 0.8) + whisper * env(n, 0.2, 0.5), r, 0.6, 0.2, 0.25)


def darkness_fall():
    r = rng_of(5204)
    n = n_of(1.2)
    fall = svf(noise(n, r), sweep(n, 3000, 80, 0.6), 1.2) * env(n, 0.02, 0.6)
    sub = osc(sweep(n, 60, 30), n) * env(n, 0.1, 0.7)
    return tail(mix(fall, sub * 0.8), r, 0.8, 0.3, 0.25)


def scythe_windup():
    r = rng_of(5205)
    n = n_of(0.5)
    ring = svf(noise(n, r), sweep(n, 2500, 6500, 1.2), 12.0, "bp") * (np.arange(n) / n) ** 1.3
    return mix(ring * 0.8, modes(0.5, r, [(2960, 0.2, 0.3)]) * (np.arange(n) / n))


def scythe_swing():
    r = rng_of(5206)
    return mix(whoosh(0.4, r, 300, 3500, 500, 2.0), whoosh(0.4, r, 2000, 7000, 3000, 6.0) * 0.4,
               whoosh(0.4, r, 100, 400, 100, 0.8, "lp") * 0.6)


def dive_whoosh():
    r = rng_of(5207)
    n = n_of(0.6)
    return mix(svf(noise(n, r), sweep(n, 600, 2800, 2.0), 1.5, "bp") * (np.arange(n) / n) ** 1.5,
               at(thump(0.35, 90, 28, 0.1), 0.45)[:n_of(0.95)])


def heavy_thud():
    r = rng_of(5208)
    return tail(drive(mix(thump(0.6, 80, 24, 0.18) * 1.3, burst(0.4, r, 1200, 120, 0.1),
                          grains(0.5, r, 30, 0.006, 0.3, 400, 3000, start=0.04) * 0.7), 2.0), r, 0.5, 0.15, 0.15)


# ---------------------------------------------------------------- world

def chest_open():
    r = rng_of(6001)
    n = n_of(0.6)
    creak_f = 140 + 40 * np.sin(2 * np.pi * 2.5 * t_of(n)) + 10 * np.sin(2 * np.pi * 19 * t_of(n))
    creak = svf(osc(creak_f, n, "saw"), 1300, 5.0, "bp") * np.sin(np.pi * np.arange(n) / n) * 0.5
    latch = modes(0.1, r, [(1400, 0.6, 0.02), (2300, 0.4, 0.012)])
    lid = at(mix(modes(0.25, r, [(230, 0.8, 0.05), (520, 0.4, 0.03)]), thump(0.2, 120, 50, 0.04)), 0.5)
    glint = at(modes(0.5, r, [(1760, 0.25, 0.15), (2637, 0.18, 0.1)]), 0.55)
    return tail(mix(latch, at(creak, 0.05), lid, glint), r, 0.4, 0.1, 0.15)


def trap_warn():
    r = rng_of(6002)
    clicks = mix(*[at(modes(0.03, r, [(1900, 0.6, 0.006), (3300, 0.3, 0.004)]), i * 0.07) for i in range(3)])
    return mix(clicks, grains(0.25, r, 12, 0.003, 0.2, 1000, 5000) * 0.4)


def trap_spikes():
    r = rng_of(6003)
    shing = mix(*[at(svf(noise(n_of(0.15), r), 5000 + i * 900, 10.0, "bp") * env(n_of(0.15), 0.002, 0.03), i * 0.012) for i in range(4)])
    return mix(burst(0.03, r, 8000, 2000, 0.005), shing, thump(0.15, 200, 70, 0.03) * 0.6)


def trap_log():
    r = rng_of(6004)
    swing = whoosh(0.4, r, 150, 700, 200, 1.0, "lp")
    creak = svf(osc(90 + 20 * np.sin(2 * np.pi * 4 * t_of(n_of(0.4))), n_of(0.4), "saw"), 700, 5.0, "bp") * env(n_of(0.4), 0.05, 0.2) * 0.3
    return mix(swing, creak, at(heavy_thud() * 0.5, 0.35))


def wall_crack():
    r = rng_of(6005)
    return drive(mix(thump(0.2, 110, 40, 0.05), burst(0.15, r, 2000, 300, 0.03, 0.7) * 0.7,
                     grains(0.3, r, 22, 0.004, 0.2, 800, 5000, start=0.02) * 0.8), 1.6)


def reward_take():
    r = rng_of(6006)
    n = n_of(0.6)
    rise = svf(noise(n, r), sweep(n, 600, 6000, 1.0), 6.0, "bp") * np.sin(np.pi * np.arange(n) / n) * 0.4
    chime = at(modes(0.5, r, [(1047, 0.6, 0.18), (1568, 0.4, 0.14), (2093, 0.3, 0.1)]), 0.2)
    return tail(mix(rise, chime), r, 0.5, 0.15, 0.2)


def gate_whoosh():
    r = rng_of(6007)
    n = n_of(1.0)
    swirl = svf(noise(n, r), 600 + 1500 * np.sin(np.pi * np.arange(n) / n) + 300 * np.sin(2 * np.pi * 6 * t_of(n)), 1.8, "bp")
    return tail(mix(swirl * np.sin(np.pi * np.arange(n) / n), osc(sweep(n, 60, 120), n) * 0.4 * np.sin(np.pi * np.arange(n) / n)), r, 0.6, 0.2, 0.2)


def god_voice():
    r = rng_of(6008)
    n = n_of(1.2)
    e = np.minimum(1, np.arange(n) / n_of(0.25)) * env(n, 0.0, 0.7)
    choir = mix(*[voice(1.2, r, f, f, [(fo, 5, 1.0), (fo * 1.8, 6, 0.4)], 0.2) * a
                  for f, fo, a in [(110, 600, 1.0), (165 * 1.004, 700, 0.6), (220 * 0.997, 800, 0.4)]])
    return tail(choir * e, r, 0.9, 0.3, 0.25, 150, 4000)


WORLD = [chest_open, trap_warn, trap_spikes, trap_log, wall_crack, reward_take, gate_whoosh, god_voice]


# ---------------------------------------------------------------- ambient loops

AMB_SEC = 36.0


def _place(buf, ev, pos):
    """Adds `ev` at sample `pos`, wrapping around the end (seamless loop)."""
    n = len(buf)
    idx = (pos + np.arange(len(ev))) % n
    np.add.at(buf, idx, ev)


def _circ_tail(sig, rng, sec, decay, wet, lo=200.0, hi=4000.0):
    n = n_of(sec)
    ir = band(noise(n, rng), lo, hi) * env(n, 0.005, decay)
    ir /= np.sqrt(np.sum(ir ** 2)) + 1e-9
    return sig + np.fft.irfft(np.fft.rfft(sig) * np.fft.rfft(pad(ir, len(sig))), len(sig)) * wet * 4.0


def _slow_lfo(n, cycles, rng):
    """Slow modulation with an integer number of cycles per loop (seamless)."""
    t = np.arange(n) / n
    return 0.5 + 0.5 * np.sin(2 * np.pi * cycles * t + rng.uniform(0, 6.28))


def amb_bed(rng, lo, hi, cycles=(2, 3)):
    n = n_of(AMB_SEC)
    bed = band(noise(n, rng), lo, hi, -3.0)
    bed /= np.max(np.abs(bed)) + 1e-9
    return bed * (0.6 + 0.4 * _slow_lfo(n, cycles[0], rng)) * (0.8 + 0.2 * _slow_lfo(n, cycles[1], rng))


def amb_swamp():
    r = rng_of(7001)
    n = n_of(AMB_SEC)
    buf = amb_bed(r, 60, 900) * 0.5
    for _ in range(70):  # bubbles and plops in the mud
        f = r.uniform(250, 700)
        m = n_of(0.06)
        ev = osc(sweep(m, f, f * 1.8), m) * env(m, 0.003, 0.015) * r.uniform(0.05, 0.2)
        _place(buf, ev, int(r.uniform(0, n)))
    for _ in range(10):  # distant frog-ish croaks: rough voice through a formant
        ev = voice(0.25, r, r.uniform(70, 110), r.uniform(60, 90), [(500, 6, 1.0), (1200, 6, 0.3)], 0.4) * env(n_of(0.25), 0.02, 0.06) * 0.12
        _place(buf, band(ev, 200, 2000), int(r.uniform(0, n)))
    buf += band(noise(n, r), 3000, 7000) * 0.04 * _slow_lfo(n, 5, r)  # insect haze
    return _circ_tail(buf, r, 1.2, 0.4, 0.2)


def amb_forest():
    r = rng_of(7002)
    n = n_of(AMB_SEC)
    buf = amb_bed(r, 150, 2500, (3, 2)) * 0.45  # wind in the crowns
    for _ in range(14):  # creaking trunks
        m = n_of(r.uniform(0.6, 1.2))
        f = r.uniform(60, 110) * (1 + 0.15 * np.sin(2 * np.pi * r.uniform(1, 3) * t_of(m)))
        ev = svf(osc(f, m, "saw"), r.uniform(500, 900), 6.0, "bp") * np.sin(np.pi * np.arange(m) / m) * r.uniform(0.03, 0.08)
        _place(buf, ev, int(r.uniform(0, n)))
    for _ in range(90):  # leaves and twigs
        ev = band(noise(n_of(0.02), r) * env(n_of(0.02), 0.001, 0.005), 1500, 6000) * r.uniform(0.03, 0.12)
        _place(buf, ev, int(r.uniform(0, n)))
    for _ in range(6):  # a far owl-like hoot pair, heavily filtered
        m = n_of(0.35)
        hoot = osc(sweep(m, 420, 380), m) * np.sin(np.pi * np.arange(m) / m) ** 2 * 0.05
        _place(buf, mix(hoot, at(hoot * 0.8, 0.45)), int(r.uniform(0, n)))
    return _circ_tail(buf, r, 1.5, 0.5, 0.25)


def amb_frost():
    r = rng_of(7003)
    n = n_of(AMB_SEC)
    howl = band(noise(n, r), 300, 1800)
    howl /= np.max(np.abs(howl)) + 1e-9
    howl *= 0.35 + 0.65 * _slow_lfo(n, 3, r) ** 2
    buf = howl * 0.5 + amb_bed(r, 40, 300, (2, 1)) * 0.35
    for _ in range(50):  # ice ticks and tinkles
        ev = modes(0.15, r, [(r.uniform(2500, 5000), 1.0, 0.03), (r.uniform(5000, 8000), 0.4, 0.02)]) * r.uniform(0.02, 0.06)
        _place(buf, ev, int(r.uniform(0, n)))
    for _ in range(5):  # far groans of the ice
        m = n_of(1.0)
        ev = osc(sweep(m, r.uniform(60, 90), r.uniform(40, 60)), m) * np.sin(np.pi * np.arange(m) / m) * 0.08
        _place(buf, ev, int(r.uniform(0, n)))
    return _circ_tail(buf, r, 1.8, 0.6, 0.3)


def amb_base():
    r = rng_of(7004)
    n = n_of(AMB_SEC)
    fire = band(noise(n, r), 80, 600) * (0.7 + 0.3 * _slow_lfo(n, 7, r))
    fire /= np.max(np.abs(fire)) + 1e-9
    buf = fire * 0.35
    for _ in range(240):  # hearth crackle
        ev = band(noise(n_of(0.008), r) * env(n_of(0.008), 0.0005, 0.002), 1500, 9000) * r.uniform(0.04, 0.25)
        _place(buf, ev, int(r.uniform(0, n)))
    for i in range(6):  # far forge strikes
        ev = modes(0.8, r, [(620, 1.0, 0.2), (1610, 0.5, 0.12), (2800, 0.25, 0.08)]) * 0.05
        _place(buf, band(ev, 300, 3000), int((i + r.uniform(0, 0.6)) * n / 6))
    buf += amb_bed(r, 200, 1500, (1, 2)) * 0.12  # wind outside
    return _circ_tail(buf, r, 1.0, 0.3, 0.2)


AMBIENT = {"amb_swamp": amb_swamp, "amb_forest": amb_forest, "amb_frost": amb_frost, "amb_base": amb_base}


def sounds():
    """name -> builder, every new file of the second pass (excluding ambient)."""
    s = {f.__name__: f for f in UI}
    s.update({"limb_sever_1": lambda: limb_sever(3001), "limb_sever_2": lambda: limb_sever(3002),
              "limb_head_pop": limb_head_pop,
              "limb_part_thud_1": lambda: limb_part_thud(3201), "limb_part_thud_2": lambda: limb_part_thud(3202),
              "parry_clang_1": lambda: parry_clang(3401), "parry_clang_2": lambda: parry_clang(3402),
              "parry_whiff": parry_whiff, "parry_start": parry_start,
              "enemy_death_2": lambda: enemy_death_v(3501), "enemy_death_3": lambda: enemy_death_v(3502)})
    for surf, base in [("mud", 4001), ("dirt", 4011), ("snow", 4021), ("wood", 4031)]:
        for i in range(3):
            s["step_%s_%d" % (surf, i + 1)] = (lambda b=base + i, sf=surf: step(b, sf))
    for f in [hero_death, hero_revive, weapon_swap, weapon_pickup, amulet_ready, amulet_overcharge, amulet_crack,
              flare_fizzle, enemy_wake, wolf_growl, bite_snap, claw_swipe, bat_screech, spit_wind, bloat_swell,
              bloat_burst, frost_charge, frost_breath, knight_windup, shield_raise, shield_block, shield_bash,
              bell_ring, spirit_appear, spirit_vanish, dig_dirt, dirt_burst, bow_draw, shot_fire, fire_whoosh,
              boss_summon, boss_death, likho_gaze, darkness_fall, scythe_windup, scythe_swing, dive_whoosh,
              heavy_thud] + WORLD:
        s[f.__name__] = f
    s["growl_small_1"] = lambda: growl_small(5001 + 100)
    s["growl_small_2"] = lambda: growl_small(5002 + 100)
    s["lunge_whoosh_1"] = lambda: lunge_whoosh(5301)
    s["lunge_whoosh_2"] = lambda: lunge_whoosh(5302)
    s.update(SWAMP)
    s.update(FROST)
    s.update(FOREST)
    return s


# ---------------------------------------------------------------- Топь roster (bestiary §3.2)

def swing_heavy():
    """Болванчик raises the clay club: a slow heavy whoosh with a creak of straw."""
    r = rng_of(8001)
    air = whoosh(0.6, r, 150, 900, 220, 1.2, "bp", 0.7) * 1.1
    creak = at(modes(0.25, r, [(310, 1.0, 0.06), (720, 0.5, 0.04), (1350, 0.25, 0.03)]) * 0.35, 0.05)
    straw = grains(0.4, r, 18, 0.004, 0.2, 2500, 8000) * 0.25
    return tail(mix(air, creak, straw), r, 0.3, 0.07, 0.12)


def shishiga_squeak(seed):
    """Small imp squeak before the leap: a rising nasal chirp."""
    r = rng_of(seed)
    v = seed % 2
    n = n_of(0.22)
    sq = voice(0.22, r, 900 + v * 120, 1500 + v * 200, [(1800, 6, 1.0), (3200, 7, 0.5)], 0.15, 0.6)
    return tail(sq * env(n, 0.01, 0.08) * 1.4, r, 0.15, 0.04, 0.1)


def cling_latch():
    """Шишига lands on the shoulders: a wet slap and a grab of claws."""
    r = rng_of(8011)
    slap = burst(0.12, r, 3000, 600, 0.02, 1.2, "bp") * 1.0
    body = thump(0.15, 160, 70, 0.03) * 0.8
    claws = at(grains(0.12, r, 6, 0.003, 0.05, 3000, 9000) * 0.6, 0.02)
    return mix(slap, body, claws)


def bog_bubble():
    """The hummock bubbles and sighs: low gulps in mud and a breathy exhale."""
    r = rng_of(8021)
    buf = np.zeros(n_of(0.9))
    for i in range(6):
        g = thump(0.12, r.uniform(140, 260), r.uniform(60, 90), 0.03) * r.uniform(0.4, 0.8)
        g = mix(g, burst(0.06, r, 900, 300, 0.015, 2.0, "bp") * 0.4)
        st = int((0.05 + i * 0.12 + r.uniform(0, 0.04)) * SR)
        buf[st:st + len(g)] += g[:len(buf) - st]
    sigh = at(whoosh(0.5, r, 300, 900, 250, 1.0, "bp", 0.5) * 0.35, 0.35)
    return tail(mix(buf, sigh), r, 0.3, 0.08, 0.15)


def bog_plunge():
    """Болотница dives or surfaces: a deep splash and sucking mud."""
    r = rng_of(8031)
    splash = burst(0.35, r, 2500, 300, 0.08, 0.9) * 1.1
    boom = thump(0.4, 110, 35, 0.12) * 1.0
    suck = at(svf(noise(n_of(0.3), r) * env(n_of(0.3), 0.05, 0.1), sweep(n_of(0.3), 1200, 200), 5.0, "bp") * 0.6, 0.12)
    return tail(drive(mix(splash, boom, suck), 1.4), r, 0.4, 0.1, 0.18)


def song_ward():
    """Водяница's song: a wordless drowned voice, wavering, with water shimmer."""
    r = rng_of(8041)
    n = n_of(0.9)
    v = voice(0.9, r, 440, 520, [(700, 5, 1.0), (1150, 6, 0.6), (2600, 8, 0.25)], 0.08, 1.0)
    v = v * vib(n, 6.0, 0.25, r) * env(n, 0.15, 0.35)
    shimmer = grains(0.9, r, 30, 0.006, 0.6, 3000, 7000) * 0.15
    return tail(mix(v * 0.9, shimmer), r, 0.6, 0.15, 0.3)


def ward_gain():
    """Tina wraps an ally: a soft wet chime."""
    r = rng_of(8051)
    chime = modes(0.5, r, [(880, 1.0, 0.12), (1320, 0.6, 0.09), (2210, 0.3, 0.06)]) * 0.5
    wet = burst(0.2, r, 1500, 400, 0.05, 1.5, "bp") * 0.4
    return tail(mix(chime, wet), r, 0.3, 0.08, 0.2)


def ward_break():
    """The tina shield tears: a wet rip and a dull crack."""
    r = rng_of(8061)
    rip = svf(noise(n_of(0.18), r) * env(n_of(0.18), 0.002, 0.05), sweep(n_of(0.18), 3500, 600), 2.5, "bp") * 1.1
    crack = at(_bone_crack(r, 0.06) * 0.6, 0.01)
    body = thump(0.15, 200, 80, 0.03) * 0.6
    return tail(mix(rip, crack, body), r, 0.25, 0.06, 0.12)


def water_push():
    """Водяница shoves with water: a rushing wave hit."""
    r = rng_of(8071)
    rush = whoosh(0.35, r, 400, 2500, 600, 1.0, "bp", 0.4) * 0.9
    hit = at(burst(0.2, r, 2800, 500, 0.05, 0.9) * 0.8, 0.12)
    body = at(thump(0.2, 140, 60, 0.05) * 0.6, 0.12)
    return tail(mix(rush, hit, body), r, 0.3, 0.08, 0.15)


SWAMP = {"swing_heavy": swing_heavy, "shishiga_squeak_1": lambda: shishiga_squeak(8081),
         "shishiga_squeak_2": lambda: shishiga_squeak(8082), "cling_latch": cling_latch, "bog_bubble": bog_bubble,
         "bog_plunge": bog_plunge, "song_ward": song_ward, "ward_gain": ward_gain, "ward_break": ward_break,
         "water_push": water_push}


# ---------------------------------------------------------------- Царство Морены roster (bestiary §3.4)

def _ice_tink(r, sec, f0):
    """A struck ice body: high inharmonic glassy modes."""
    return modes(sec, r, [(f0, 1.0, 0.08), (f0 * 2.31, 0.6, 0.05), (f0 * 3.97, 0.35, 0.03), (f0 * 5.4, 0.2, 0.02)])


def staff_raise():
    """Карачун lifts the staff: a creaking groan of wood and gathering rime."""
    r = rng_of(8101)
    creak = modes(0.6, r, [(180, 1.0, 0.2), (410, 0.5, 0.15), (770, 0.25, 0.1)]) * 0.5
    rise = whoosh(0.8, r, 300, 2500, 4500, 1.4, "bp", 0.9) * 0.45
    rime = grains(0.8, r, 40, 0.003, 0.6, 4000, 11000, power=0.7) * 0.3
    return tail(mix(creak, rise, rime), r, 0.35, 0.08, 0.15)


def ice_wave():
    """Spikes burst along the floor: a running crackle of breaking ice over a low crunch."""
    r = rng_of(8111)
    buf = np.zeros(n_of(1.2))
    for i in range(14):
        tk = _ice_tink(r, 0.12, r.uniform(1800, 3200)) * r.uniform(0.25, 0.5) * (1.0 - i / 18.0)
        st = int((i * 0.07 + r.uniform(0, 0.02)) * SR)
        buf[st:st + len(tk)] += tk[:len(buf) - st]
    crunch = burst(0.9, r, 2500, 600, 0.25, 0.7, "lp") * 0.6
    body = thump(0.3, 120, 50, 0.08) * 0.8
    return tail(mix(buf, crunch, body), r, 0.3, 0.07, 0.12)


def needle_cast():
    """Снежница gathers needles: a thin rising shimmer."""
    r = rng_of(8121)
    shim = mix(*[at(_ice_tink(r, 0.25, 2600 + i * 420) * 0.25, i * 0.12) for i in range(4)])
    air = whoosh(0.55, r, 2000, 7000, 9000, 2.0, "bp", 0.9) * 0.3
    return tail(mix(shim, air), r, 0.3, 0.07, 0.2)


def needle_fly():
    """A frost needle flies: a short high hiss."""
    r = rng_of(8131)
    return burst(0.18, r, 9000, 5000, 0.05, 2.0, "bp", 0.005) * 0.7


def hero_freeze():
    """The hero freezes: a sharp ice clamp closing with a crackle."""
    r = rng_of(8141)
    clamp = burst(0.08, r, 6000, 2000, 0.02, 1.0, "bp") * 1.0
    crack = at(grains(0.5, r, 30, 0.003, 0.25, 2500, 10000) * 0.6, 0.02)
    body = mix(_ice_tink(r, 0.6, 1200) * 0.5, thump(0.25, 220, 90, 0.06) * 0.5)
    return tail(mix(clamp, crack, body), r, 0.4, 0.1, 0.2)


def freeze_shatter():
    """The ice on the hero breaks: a bright shatter of glassy pieces."""
    r = rng_of(8151)
    hit = burst(0.12, r, 8000, 2000, 0.03, 0.9) * 0.9
    shards = mix(*[at(_ice_tink(r, 0.2, r.uniform(2000, 4500)) * r.uniform(0.2, 0.4), r.uniform(0.0, 0.25)) for _ in range(9)])
    return tail(mix(hit, shards), r, 0.3, 0.07, 0.15)


def icicle_creak():
    """An icicle strains on the ceiling: a high strained creak with grit."""
    r = rng_of(8161)
    n = n_of(0.5)
    cr = osc(sweep(n, 900, 1300, 0.7), shape="saw") * env(n, 0.05, 0.25) * 0.12
    cr = band(cr, 600, 4000)
    grit = grains(0.5, r, 25, 0.002, 0.4, 3000, 9000) * 0.5
    return tail(mix(cr, grit), r, 0.25, 0.06, 0.1)


def icicle_fall():
    """The icicle drops: a falling whistle into a hard crash."""
    r = rng_of(8171)
    fall = whoosh(0.35, r, 1500, 5000, 3000, 2.2, "bp", 0.3) * 0.5
    crash = at(mix(burst(0.3, r, 7000, 1500, 0.06, 0.8) * 0.9, thump(0.25, 160, 60, 0.06) * 0.8), 0.3)
    return tail(mix(fall, crash), r, 0.35, 0.08, 0.15)


def ice_shatter():
    """An ice body breaks into pieces: crash and tinkling shards."""
    r = rng_of(8181)
    hit = mix(burst(0.15, r, 7000, 1800, 0.04, 0.8), thump(0.2, 200, 80, 0.05) * 0.6)
    shards = mix(*[at(_ice_tink(r, 0.18, r.uniform(1800, 4200)) * r.uniform(0.15, 0.35), r.uniform(0.02, 0.4)) for _ in range(12)])
    return tail(mix(hit, shards), r, 0.35, 0.08, 0.18)


def mara_raise():
    """Мара calls the dead: a breathy low whisper choir with a cold shimmer."""
    r = rng_of(8191)
    wh = voice(0.9, r, 140, 110, [(500, 4, 1.0), (1100, 5, 0.6), (2400, 6, 0.3)], 0.6, 1.0) * env(n_of(0.9), 0.25, 0.4) * 0.9
    air = band(noise(n_of(0.9), r), 1500, 6000) * env(n_of(0.9), 0.3, 0.35) * 0.15
    shim = at(_ice_tink(r, 0.4, 1900) * 0.25, 0.5)
    return tail(mix(wh, air, shim), r, 0.45, 0.12, 0.25)


def frozen_rise():
    """A body rises in ice: growing crackle and a frozen thud."""
    r = rng_of(8201)
    grow = grains(0.6, r, 50, 0.003, 0.5, 2000, 9000, power=0.6) * 0.6
    thud = at(mix(thump(0.3, 180, 70, 0.07) * 0.7, _ice_tink(r, 0.3, 1500) * 0.4), 0.45)
    return tail(mix(grow, thud), r, 0.35, 0.08, 0.15)


def frozen_crack():
    """An ice copy cracks: a dry crack and a few falling shards."""
    r = rng_of(8211)
    crack = burst(0.1, r, 5000, 1500, 0.025, 1.2, "bp") * 1.0
    shards = mix(*[at(_ice_tink(r, 0.15, r.uniform(1500, 3500)) * 0.25, r.uniform(0.03, 0.25)) for _ in range(6)])
    return tail(mix(crack, shards), r, 0.3, 0.07, 0.12)


FROST = {f.__name__: f for f in [staff_raise, ice_wave, needle_cast, needle_fly, hero_freeze, freeze_shatter,
                                  icicle_creak, icicle_fall, ice_shatter, mara_raise, frozen_rise, frozen_crack]}
# ---------------------------------------------------------------- Тёмный бор roster (bestiary §3.3)

def auka_call():
    """Аука calls: a hollow far-off "a-u" through the trees, falling, with a forest echo."""
    r = rng_of(8101)
    n = n_of(0.75)
    a = voice(0.35, r, 520, 480, [(800, 5, 1.0), (1250, 6, 0.5)], 0.12, 1.0) * env(n_of(0.35), 0.04, 0.2)
    u = at(voice(0.4, r, 470, 360, [(350, 5, 1.0), (800, 6, 0.3)], 0.1, 1.0) * env(n_of(0.4), 0.03, 0.25), 0.3)
    v = mix(a, u)
    v = v[:n] * vib(min(n, len(v)), 5.0, 0.2, r)[:len(v[:n])]
    return tail(v * 1.2, r, 0.7, 0.22, 0.4, 250.0, 3500.0)


def branch_creak():
    """Сучковик draws the branch back: a slow wooden creak, strained fibres."""
    r = rng_of(8111)
    n = n_of(0.7)
    fric = svf(noise(n, r) * env(n, 0.2, 0.4), sweep(n, 250, 520), 12.0, "bp") * 1.2
    groan = modes(0.7, r, [(180, 1.0, 0.3), (410, 0.5, 0.25), (930, 0.25, 0.15)], 0.15) * 0.5
    ticks = grains(0.7, r, 14, 0.004, 0.6, 900, 3000) * 0.3
    return tail(mix(fric, groan, ticks), r, 0.3, 0.08, 0.15)


def branch_spear():
    """The branch-spear leaves: a sharp woody whip and a fast airy swish."""
    r = rng_of(8121)
    whip = burst(0.06, r, 4000, 1200, 0.015, 1.4, "bp") * 1.0
    knock = modes(0.15, r, [(620, 1.0, 0.04), (1480, 0.5, 0.03)]) * 0.6
    air = at(whoosh(0.3, r, 800, 3500, 900, 1.4, "bp", 0.3) * 0.9, 0.02)
    return tail(mix(whip, knock, air), r, 0.25, 0.05, 0.1)


def spear_thunk():
    """The spear sticks in the wall: a hard wooden thunk with a short twang of the shaft."""
    r = rng_of(8131)
    hit = thump(0.18, 210, 90, 0.04) * 1.1
    wood = modes(0.3, r, [(340, 1.0, 0.08), (780, 0.6, 0.05), (1620, 0.3, 0.03)]) * 0.7
    twang = at(modes(0.35, r, [(95, 1.0, 0.12), (190, 0.4, 0.08)]) * vib(n_of(0.35), 18.0, 0.6, r) * 0.35, 0.01)
    return tail(mix(hit, wood, twang), r, 0.3, 0.08, 0.14)


def lesavka_whistle():
    """Лесавка whistles: a shrill rising two-note whistle through the leaves."""
    r = rng_of(8141)
    n1, n2 = n_of(0.22), n_of(0.38)
    f1 = sweep(n1, 1900, 2300)
    f2 = sweep(n2, 2300, 3100, 0.6)
    w1 = np.sin(2 * np.pi * np.cumsum(f1) / SR) * env(n1, 0.02, 0.12)
    w2 = np.sin(2 * np.pi * np.cumsum(f2) / SR) * env(n2, 0.03, 0.2)
    breath = svf(noise(n1 + n2, r) * 0.25, 2600, 3.0, "bp")
    buf = np.concatenate([w1, w2]) * 0.6 + breath * env(n1 + n2, 0.02, 0.3)
    leaves = grains(0.6, r, 20, 0.005, 0.5, 2500, 8000) * 0.2
    return tail(mix(buf, leaves), r, 0.4, 0.1, 0.2)


def haste_on():
    """Haste takes an ally: a quick rising rustle and a dry ember crackle."""
    r = rng_of(8151)
    rise = whoosh(0.3, r, 500, 3000, 4500, 1.6, "bp", 0.7) * 0.7
    crack = grains(0.3, r, 16, 0.003, 0.2, 2000, 9000) * 0.5
    tick = at(modes(0.12, r, [(1760, 1.0, 0.03), (2640, 0.5, 0.02)]) * 0.35, 0.2)
    return tail(mix(rise, crack, tick), r, 0.25, 0.06, 0.12)


FOREST = {"auka_call": auka_call, "branch_creak": branch_creak, "branch_spear": branch_spear,
          "spear_thunk": spear_thunk, "lesavka_whistle": lesavka_whistle, "haste_on": haste_on}

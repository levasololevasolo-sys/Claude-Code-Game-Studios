"""The six enemies of Царство Морены (bestiary §3.4), one rig + pose set each.

Same pipeline and style as kinds.py (the Swamp): hero2d sdf2d ink-and-paint,
base.Body layers, the 'arm' / 'head' tags for limb_zones.json. Frost rules
(art bible §4.2): the location is the only light one, so the enemies are dark
or ink-heavy (OUTLINE 2.6 instead of 1.9), and the threat accents are the
darker rust #9E3A1C and magenta #A3206F with ice #8FD3F5 as the local accent.
Карачун is a dark fur coat under a snow mantle (a white drift alone vanished
into the snow, frost roster note), with a frost-red nose and rust sash.
Registry key = Enemy.kind_id: the Студёный дух is "jelly".
"""
import numpy as np

from base import Body, W, hexc, ik, rot, lerp, ease, unit, RUST_D, MAG, MAG_D, INK  # noqa: F401
from kinds import limb, fingers, cyc, seq, LIVE

TAU = 2 * np.pi
ICE = hexc('8FD3F5')
ICE_L = hexc('CFE7F6')
ICE_D = hexc('4F7FA8')
SNOW = hexc('E4ECF3')
DEEP = hexc('2C3B52')
NIGHT = hexc('1A2436')


def _safe_cone(cv, a, b, r1, r2):
    """Canvas.cone with a zero-length guard (a == b gave NaN pixels)."""
    if np.hypot(b[0] - a[0], b[1] - a[1]) < 1e-4:
        return cv.circle(a, max(r1, r2))
    return _cone(cv, a, b, r1, r2)


from sdf2d import Canvas  # noqa: E402
_cone = Canvas.cone
Canvas.cone = _safe_cone   # only in processes that import kinds_frost (build_frost)
FROST_OUT = 2.6


def facets(cv, k=7.0, a=0.13):
    """Angular crystal facets: a checker of two skewed grids."""
    wx = cv.X + cv.n_mid * 0.6 / k * 4
    wy = cv.Y + cv.n_lo * 0.6 / k * 4
    f = (np.floor(wx * k * 0.8 + wy * k * 0.35) * 0.37 + np.floor(-wx * k * 0.45 + wy * k * 0.9) * 0.61) % 1.0
    return 1 - a * 0.6 * f


def fur(cv, ang=0.4, a=0.16, k=55):
    return 1 - a * np.clip(np.sin((cv.X * np.cos(ang) + cv.Y * np.sin(ang)) * k + cv.n_mid * 9), 0, 1)


def glint(cv, c, r, alpha=0.9):
    """Four-ray ice glint."""
    d = np.minimum(cv.cone((c[0] - r, c[1]), (c[0] + r, c[1]), 0.02, 0.006),
                   cv.cone((c[0], c[1] - r), (c[0], c[1] + r), 0.02, 0.006))
    cv.flat(d, np.array([1.0, 1.0, 1.0]), alpha=alpha)


def nopaint(cv, d, col, **kw):
    """Flat-ish paint that does not join the outline union (effects)."""
    cv.paint(d, col, R=0.03, line=0.0, shade=False, rim=False, cast=False, union=False, **kw)


# =====================================================================
class Wolf(Body):
    """Снежный волк: long low slate wolf, ice-needle mane, icicle tail, red eyes."""
    BOUNDS = (-2.9, 3.1, -2.9, 0.4)
    OUTLINE = FROST_OUT
    FUR = hexc('4A5A72')
    BELLY = hexc('77879F')
    MANE = hexc('DDE8F0')
    EYE = hexc('FF5A3A')
    BASE = dict(bob=0.0, gait=0.0, stretch=0.0, crouch=0.0, jaw=0.1, eye=1.0, tail=0.0, tuck=0.0, neck_r=0.22,
                lift=0.0)

    def setup(self):
        p = self.p
        c, s = p['crouch'], p['stretch']
        y = p['bob'] - p['lift']
        self.chest = np.array([0.45 + 0.3 * s, -1.0 + 0.3 * c + y])
        self.haunch = np.array([-0.7 - 0.2 * s, -0.98 + 0.2 * c + y - 0.1 * s])
        self.neck = self.chest + (0.42 + 0.12 * s, -0.28 + 0.12 * c + 0.12 * s)
        self.hc = self.neck + (0.3 + 0.1 * s, -0.08 + 0.08 * c)

    def stump_n(self, key):
        return (1.0, -0.2)

    def layers(self):
        return [(None, self.far_legs), (None, self.tail), (None, self.body), ('head', self.head),
                (None, self.near_legs)]

    def feet(self):
        p = self.p
        g = p['gait']
        s = np.sin(g * TAU)
        lift = lambda v: -0.22 * max(0.0, v)  # noqa: E731
        tk = p['tuck']
        f = dict(fF=(self.chest[0] + 0.3 + 0.35 * s, lift(np.cos(g * TAU))),
                 fN=(self.chest[0] + 0.15 - 0.35 * s, lift(-np.cos(g * TAU))),
                 bF=(self.haunch[0] - 0.05 - 0.35 * s, lift(-np.cos(g * TAU))),
                 bN=(self.haunch[0] + 0.1 + 0.35 * s, lift(np.cos(g * TAU))))
        if tk:
            f['fF'] = lerp(f['fF'], self.chest + (0.75, 0.45), tk)
            f['fN'] = lerp(f['fN'], self.chest + (0.55, 0.55), tk)
            f['bF'] = lerp(f['bF'], self.haunch + (-0.7, 0.5), tk)
            f['bN'] = lerp(f['bN'], self.haunch + (-0.5, 0.6), tk)
        f['fF'] = np.array(f['fF'], float) + (0, -self.p['lift'] * (1 - tk))
        return f

    def leg(self, root, foot, dim, front):
        cv = self.cv
        d, kn, an = limb(cv, root, foot, 0.52, 0.5, 0.16 if front else 0.2, 0.07, (-1, 0.1) if front else (1, 0.2))
        d = cv.smin(d, cv.ellipse(np.asarray(an) + (0.08, -0.03), 0.13, 0.07), 0.04)
        cv.paint(d, self.FUR * (0.92 if front else 1.0), R=0.12, dim=dim, pattern=fur(cv, 1.4, 0.1))
        cl = fingers(cv, np.asarray(an) + (0.14, 0.0), unit((1, 0.4)), n=3, ln=0.1, spread=0.6, r=0.02, curl=0.6)
        cv.paint(cl, hexc('D8D4C8'), R=0.02, line=0.5, dim=dim, cast=False)

    def far_legs(self):
        f = self.feet()
        self.leg(self.chest + (0.05, 0.15), f['fF'], 0.72, True)
        self.leg(self.haunch + (0.05, 0.05), f['bF'], 0.72, False)

    def near_legs(self):
        f = self.feet()
        self.leg(self.haunch + (0.15, 0.12), f['bN'], 1.0, False)
        self.leg(self.chest + (-0.05, 0.22), f['fN'], 1.0, True)

    def tail(self):
        cv, p = self.cv, self.p
        b = self.haunch + (-0.48, -0.18)
        tip = b + (-1.15, 0.45 - 0.35 * p['tail'] - 0.25 * p['stretch'])
        mid = lerp(b, tip, 0.5) + (0.0, 0.12 - 0.1 * p['tail'])
        tuft = cv.ellipse(b + (-0.12, 0.02), 0.25, 0.17, rot=-0.3)
        cv.paint(tuft, self.FUR, R=0.12, pattern=fur(cv, -0.3, 0.12))
        ice = cv.path([b + (-0.2, 0.02), mid, tip], 0.14, 0.015)
        cv.paint(ice, ICE_L, R=0.1, pattern=facets(cv, 9), hl=1.3)
        cv.flat(cv.path([b + (-0.3, -0.04), mid + (0, -0.05)], 0.018, 0.008), np.array([1.0, 1.0, 1.0]), alpha=0.7)

    def body(self):
        cv, p = self.cv, self.p
        ch, ha = self.chest, self.haunch
        d = cv.smin(cv.ellipse(ch, 0.62, 0.42, rot=-0.12 - 0.15 * p['stretch']), cv.ellipse(ha, 0.56, 0.37, rot=0.1), 0.35)
        d = cv.smin(d, cv.cone(ch + (0.2, -0.05), self.neck, 0.36, 0.24), 0.12)
        cv.paint(d, self.FUR, R=0.42, pattern=fur(cv))
        belly = cv.inter(d + 0.03, -(cv.Y - (ch[1] + 0.12 + (cv.X - ch[0]) * 0.05)))
        cv.paint(cv.inter(d + 0.02, cv.Y - (ch[1] + 0.12)), self.BELLY, R=0.12, line=0.0, cast=False,
                 pattern=fur(cv, 1.3, 0.2))
        del belly
        # chest ruff
        ruff = cv.ellipse(self.neck + (-0.05, 0.25), 0.22, 0.3, rot=0.4)
        cv.paint(ruff, self.MANE * 0.93, R=0.1, line=0.5, cast=False, pattern=fur(cv, 1.2, 0.2, 70))
        # ice-needle mane along the spine, swept back
        dd = None
        for i in range(8):
            k = i / 7
            base = lerp(self.neck + (0.0, -0.18), ha + (0.1, -0.33), k)
            ln = 0.48 - 0.25 * k + 0.06 * (i % 2)
            ang = -np.pi / 2 - 0.95 - 0.25 * p['stretch']
            e = base + np.array([np.cos(ang), np.sin(ang)]) * ln
            di = cv.cone(base, e, 0.09, 0.012)
            dd = di if dd is None else np.minimum(dd, di)
        cv.paint(dd, self.MANE, R=0.06, line=0.7, hl=1.3, pattern=facets(cv, 10, 0.1))
        # dark rust scar of the frostbite on the flank
        self.crack([ha + (0.2, -0.15), ha + (0.32, 0.02), ha + (0.26, 0.15)], 0.02, 0.6)

    def head(self):
        cv, p = self.cv, self.p
        c = self.hc
        j = p['jaw']
        jaw = cv.cone(c + (0.0, 0.14), c + (0.55, 0.12 + 0.28 * j), 0.11, 0.05)
        cv.paint(jaw, self.FUR * 0.85, R=0.08)
        if j > 0.15:
            m = cv.poly([c + (0.05, 0.08), c + (0.6, 0.06), c + (0.55, 0.1 + 0.26 * j)], 0.02)
            nopaint(cv, m, hexc('4A0E16'))
            for x in (0.32, 0.48):
                cv.paint(cv.cone(c + (x, 0.06), c + (x + 0.02, 0.06 + 0.1 * j), 0.025, 0.006), hexc('F3F6FA'),
                         R=0.02, line=0.4, cast=False, union=False)
        skull = cv.smin(cv.ellipse(c, 0.3, 0.22, rot=0.1), cv.cone(c + (0.1, 0.0), c + (0.62, 0.06), 0.17, 0.075), 0.08)
        ears = np.minimum(cv.poly([c + (-0.22, -0.1), c + (-0.2, -0.5), c + (0.0, -0.16)], 0.02),
                          cv.poly([c + (-0.05, -0.12), c + (0.02, -0.46), c + (0.14, -0.12)], 0.02))
        cv.paint(ears, self.FUR * 0.95, R=0.06)
        cv.paint(skull, self.FUR * 1.05, R=0.18, pattern=fur(cv, 0.1, 0.12))
        cv.flat(cv.circle(c + (0.62, 0.04), 0.05), INK)
        self.eyes([c + (0.14, -0.05)], 0.05 + 0.012 * p['eye'], self.EYE, glow=p['eye'], slit=True, ang=0.25)
        cv.ink(cv.cone(c + (0.02, -0.14), c + (0.27, -0.09), 0.03, 0.015), alpha=0.85)


def wolf_anims():
    idle = cyc(8, lambda k: dict(bob=0.03 * np.sin(k * TAU), jaw=0.1 + 0.06 * np.sin(k * TAU), tail=0.15 * np.sin(k * TAU)))
    move = cyc(8, lambda k: dict(gait=k, bob=-0.06 * abs(np.sin(k * TAU)), stretch=0.25, tail=0.3 + 0.15 * np.sin(k * TAU)))
    windup = seq(5, lambda k: dict(crouch=ease(k), jaw=0.1 + 0.6 * ease(k), eye=1 + 1.4 * ease(k), tail=-0.4 * ease(k),
                                    dx=-0.1 * ease(k), bob=0.02 * np.sin(k * 11)))
    attack = seq(5, lambda k: dict(stretch=1.0, tuck=0.8 * np.sin(k * np.pi), lift=0.35 * np.sin(k * np.pi),
                                   jaw=0.95 if k < 0.6 else 0.15, eye=2.0, tail=0.6, dx=0.35 * ease(k)))
    hop = seq(5, lambda k: dict(tuck=np.sin(k * np.pi), lift=0.4 * np.sin(k * np.pi), crouch=0.3 * (1 - k), jaw=0.2,
                                tail=-0.3, rot=float(-14 * np.sin(k * np.pi)), pivot=(0.0, -1.0), eye=1.3))
    hurt = seq(3, lambda k: dict(crouch=0.5 * np.sin(k * np.pi), jaw=0.6, eye=0.5, dx=-0.1 * np.sin(k * np.pi), tail=-0.5))
    death = seq(8, lambda k: dict(jaw=0.7, eye=max(0.0, 1 - 1.5 * k), crouch=0.3, tuck=0.4 * ease(k), tail=-0.6,
                                  rot=float(-170 * ease(max(0, (k - 0.15) / 0.85))), pivot=(-0.1, -1.0), rest=True,
                                  rest_sink=0.05))
    return dict(idle=(idle, 8, True), move=(move, 14, True), windup=(windup, 10, False), attack=(attack, 14, False),
                hop=(hop, 12, False), hurt=(hurt, 12, False), death=(death, 10, False))


# =====================================================================
class ColdSpirit(Body):
    """Студёный дух: ice-bell jelly, magenta core, ice eyes, hanging frost threads."""
    BOUNDS = (-2.0, 2.0, -3.3, 0.6)
    OUTLINE = FROST_OUT
    BELL = hexc('3A5C8A')
    BASE = dict(bob=0.0, swell=1.0, sway=0.0, core=0.4, eye=1.0, puff=0.0, crack=0.0, drop=0.0, tilt=0.0)

    def setup(self):
        self.c = np.array([0.0, -1.45 + self.p['bob'] + self.p['drop']])

    def layers(self):
        return [(None, self.threads), (None, self.bell), (None, self.mist)]

    def threads(self):
        cv, p = self.cv, self.p
        c = self.c
        s = p['swell']
        roots = [(c[0] + x * s, c[1] + 0.3) for x in (-0.6, -0.35, -0.1, 0.15, 0.4, 0.62)]
        self.strands(roots, [0.9, 1.25, 1.05, 1.3, 1.0, 0.8], ICE_L, sway=p['sway'] - 0.1 * p['tilt'], w=0.075,
                     line=0.3, drip=1.0 - 0.3 * p['puff'])

    def bell(self):
        cv, p = self.cv, self.p
        c, s = self.c, p['swell']
        d = cv.inter(cv.ellipse(c, 0.95 * s, 0.95 * s), cv.Y - (c[1] + 0.2))
        teeth = None
        for i in range(9):
            x = c[0] + (-0.84 + i * 0.21) * s
            di = cv.cone((x, c[1] + 0.12), (x + p['sway'] * 0.15, c[1] + 0.42 + 0.1 * (i % 2)), 0.1, 0.015)
            teeth = di if teeth is None else np.minimum(teeth, di)
        d = cv.smin(d, teeth, 0.05)
        cv.paint(d, self.BELL, R=0.6, pattern=facets(cv, 6, 0.16), hl=1.3)
        # inner lighter dome and crystal ribs
        inner = cv.inter(cv.ellipse(c + (0, -0.05), 0.72 * s, 0.7 * s), cv.Y - (c[1] + 0.05))
        cv.paint(inner, ICE * 0.8, R=0.3, line=0.35, cast=False, union=False, alpha=0.55, pattern=facets(cv, 8, 0.2))
        for a in (-0.55, -0.2, 0.2, 0.55):
            cv.ink(cv.path([c + (a * 0.25, -0.85 * s), c + (a * 0.9 * s, 0.1)], 0.012, 0.006), alpha=0.45)
        core = p['core']
        cc = c + (0.05, -0.2)
        cv.paint(cv.circle(cc, 0.2 + 0.1 * core), MAG_D * (1 + 0.5 * core), R=0.15, line=0.5, cast=False, union=False,
                 glow=(MAG, 0.08 + 0.06 * core, 0.5 + 0.7 * core))
        cv.flat(cv.circle(cc + (-0.05, -0.06), 0.07), np.array([1.0, 0.75, 0.9]), alpha=0.8)
        self.eyes([c + (0.12, -0.55), c + (0.45, -0.5)], 0.06 + 0.01 * p['eye'], ICE * 1.1, glow=p['eye'])
        cv.ink(cv.cone(c + (0.04, -0.68), c + (0.55, -0.62), 0.025, 0.012), alpha=0.8)
        glint(cv, c + (-0.45, -0.55), 0.12, 0.8)
        if p['crack'] > 0:
            k = p['crack']
            self.crack([c + (-0.1, -0.9), c + (0.05, -0.5), c + (-0.15, -0.2), c + (0.1, 0.15)], 0.02, 0.9 * k)
            self.crack([c + (0.4, -0.7), c + (0.25, -0.35), c + (0.5, -0.05)], 0.018, 0.8 * k)

    def mist(self):
        cv, p = self.cv, self.p
        k = p['puff']
        if k <= 0:
            return
        c = self.c
        for i in range(7):
            u = (i - 3) / 3
            q = c + (u * (0.4 + 0.9 * k), 0.6 + 1.1 * k * (1 - 0.3 * abs(u)))
            nopaint(cv, cv.ellipse(q, 0.22 + 0.2 * k, 0.1 + 0.06 * k), np.array([0.9, 0.96, 1.0]), alpha=0.75 * (1.1 - k))
        for i in range(5):
            q = c + ((i - 2) * 0.35 * (0.5 + k), 0.9 + 1.2 * k)
            cv.paint(cv.cone(q + (0, -0.18), q + (0, 0.12), 0.05, 0.01), ICE_L, R=0.03, line=0.5, cast=False,
                     union=False, alpha=1.1 - k)


def jelly_anims():
    idle = cyc(8, lambda k: dict(bob=0.08 * np.sin(k * TAU), swell=1.0 + 0.05 * np.sin(k * TAU), sway=0.12 * np.sin(k * TAU + 1),
                                 core=0.4 + 0.15 * np.sin(k * TAU)))
    move = cyc(8, lambda k: dict(bob=0.06 * np.sin(k * TAU), swell=1.0 + 0.07 * np.sin(k * TAU * 2), sway=-0.3 + 0.1 * np.sin(k * TAU),
                                 core=0.45, rot=-8, pivot=(0.0, -1.4), tilt=1.0))
    windup = seq(5, lambda k: dict(swell=1.0 + 0.25 * ease(k), core=0.4 + 1.2 * ease(k), eye=1 + 1.2 * ease(k),
                                    sway=0.08 * np.sin(k * 17), bob=-0.1 * ease(k)))
    attack = seq(5, lambda k: dict(swell=float(lerp(1.25, 0.9, ease(min(1, k * 2)))) + 0.1 * ease(k), core=1.4 - k,
                                   puff=ease(k), bob=-0.1 + 0.15 * np.sin(k * np.pi), eye=1.5))
    hurt = seq(3, lambda k: dict(swell=1 - 0.12 * np.sin(k * np.pi), eye=0.5, core=0.8, dx=-0.08 * np.sin(k * np.pi)))
    death = seq(8, lambda k: dict(crack=min(1.0, k * 2.5), core=max(0.0, 0.8 - k), eye=max(0.0, 1 - 2 * k),
                                  swell=1 - 0.1 * k, drop=1.1 * ease(max(0, (k - 0.3) / 0.7)), sway=0.3,
                                  rot=float(25 * ease(k)), pivot=(0.0, -1.4), fade=1 - ease(max(0, (k - 0.55) / 0.45))))
    return dict(idle=(idle, 8, True), move=(move, 8, True), windup=(windup, 8, False), attack=(attack, 12, False),
                hurt=(hurt, 12, False), death=(death, 10, False))


# =====================================================================
class Karachun(Body):
    """Карачун: wide snowdrift of a dark fur coat, snow mantle, small head with an
    icicle beard and a frost-red nose, rust sash and mittens, a staff taller than the hero."""
    BOUNDS = (-3.0, 4.0, -7.6, 0.4)
    OUTLINE = FROST_OUT
    COAT = hexc('3D5072')
    SKIN = hexc('B9A2A6')
    NOSE = hexc('B0466E')
    STAFF = hexc('4A3A40')
    MITT = RUST_D
    BASE = dict(bob=0.0, lean=0.0, squash=0.0, hand=(1.15, -2.5), sa=-np.pi / 2 - 0.04, up=2.9, dn=2.35, rime=0.0,
                eye=1.0, farh=(-1.05, -1.55), mouth=0.0, burst=0.0, stump_r=0.26, neck_r=0.24, sink=0.0)

    def setup(self):
        p = self.p
        lean, sq = p['lean'], p['squash']
        y = p['bob'] + p['sink']
        self.top_y = -3.05 + 0.35 * sq + y
        self.sh = np.array([0.15 + lean, self.top_y])
        self.neck = np.array([0.22 + 1.3 * lean, self.top_y - 0.12])
        self.hc = self.neck + (0.1 + 0.2 * lean, -0.3)
        self.arm_root = self.sh + (0.6, 0.2)
        self.far_sh = self.sh + (-0.55, 0.2)

    def stump_n(self, key):
        return (0.9, -0.4) if key == 'arm' else (0.1, -1.0)

    def layers(self):
        return [(None, self.far_arm), (None, self.body), ('head', self.head), ('arm', self.staff_arm),
                (None, self.burst_fx)]

    def far_arm(self):
        cv, p = self.cv, self.p
        d, el, h = limb(cv, self.far_sh, p['farh'], 0.75, 0.7, 0.3, 0.22, (-1, 0.5))
        cv.paint(d, self.COAT, R=0.2, dim=0.75, pattern=fur(cv, 1.0, 0.12))
        cv.paint(cv.circle(h, 0.22), self.MITT, R=0.15, dim=0.75)

    def body(self):
        cv, p = self.cv, self.p
        lean, ty = p['lean'], self.top_y
        bl = -0.05 + p['sink']
        d = cv.poly([(-1.65, bl), (-0.6 + lean, ty + 0.15), (-0.2 + lean, ty - 0.05), (0.55 + lean, ty - 0.05),
                     (0.85 + lean, ty + 0.2), (1.55, bl)], 0.22)
        cv.paint(d, self.COAT, R=0.7, pattern=fur(cv, 1.35, 0.13, 40))
        # snow mantle on the shoulders: wavy edge, icicles hanging from it
        edge = ty + 0.85 + 0.12 * np.sin(cv.X * 5.5 + 1.0)
        mant = cv.inter(d + 0.02, cv.Y - edge)
        cv.paint(mant, SNOW, R=0.35, line=0.7, cast=True, pattern=1 - 0.06 * (cv.n_mid > 0.1))
        dd = None
        for i, x in enumerate(np.linspace(-0.9, 1.05, 8)):
            xx = x + lean * (1 - (ty + 0.85 - ty) / 3.0)
            y0 = ty + 0.82 + 0.12 * np.sin(xx * 5.5 + 1.0)
            di = cv.cone((xx, y0), (xx + 0.02, y0 + 0.22 + 0.14 * (i % 3)), 0.06, 0.012)
            dd = di if dd is None else np.minimum(dd, di)
        cv.paint(dd, ICE_L, R=0.04, line=0.55, cast=False, union=False, hl=1.3)
        # rust sash with hanging ends
        sy = -1.75 + p['bob'] + 0.25 * p['squash'] + p['sink']
        belt = cv.inter(d - 0.02, np.abs(cv.Y - sy - (cv.X * 0.06)) - 0.13)
        cv.paint(belt, RUST_D, R=0.08, line=0.7, cast=False, pattern=1 - 0.2 * np.clip(np.sin(cv.X * 30), 0, 1))
        ends = np.minimum(cv.cone((-0.55, sy + 0.05), (-0.7, sy + 0.85), 0.09, 0.07),
                          cv.cone((-0.4, sy + 0.05), (-0.45, sy + 0.7), 0.08, 0.06))
        cv.paint(ends, RUST_D * 0.9, R=0.05, line=0.6, cast=False)
        # a white zig-zag band of frost on the coat front (one ornament stripe)
        zz = np.abs(cv.Y - (sy + 0.55) - 0.09 * np.abs(((cv.X * 3.0) % 1.0) - 0.5) * 4) - 0.03
        cv.flat(cv.inter(zz, d + 0.05), SNOW * 0.9, alpha=0.75)
        # snowdrift hem: lumps over the bottom edge
        lumps = None
        for x, r in ((-1.5, 0.32), (-1.0, 0.38), (-0.35, 0.3), (0.3, 0.36), (0.95, 0.34), (1.45, 0.3)):
            di = cv.ellipse((x, bl - 0.1), r * 1.2, r * 0.7)
            lumps = di if lumps is None else cv.smin(lumps, di, 0.12)
        lumps = cv.inter(lumps, cv.Y - bl)
        cv.paint(lumps, SNOW, R=0.25, line=0.8)

    def head(self):
        cv, p = self.cv, self.p
        c = self.hc
        cap = cv.cone(c + (-0.05, -0.12), c + (-0.4, -1.05), 0.36, 0.05)
        cv.paint(cap, SNOW, R=0.25, pattern=1 - 0.08 * (cv.n_mid > 0.1))
        band = cv.ellipse(c + (-0.04, -0.15), 0.4, 0.13, rot=-0.15)
        cv.paint(band, self.COAT * 0.9, R=0.08, pattern=fur(cv, 1.4, 0.2))
        face = cv.ellipse(c + (0.05, 0.08), 0.3, 0.3)
        cv.paint(face, self.SKIN, R=0.2)
        sock = cv.ellipse(c + (0.13, 0.0), 0.17, 0.07)
        nopaint(cv, sock, INK * 1.5)
        self.eyes([c + (0.06, 0.0), c + (0.22, 0.0)], 0.04 + 0.012 * p['eye'], RUST_D * 1.5, glow=p['eye'])
        brows = cv.ellipse(c + (0.13, -0.1), 0.24, 0.07, rot=0.12)
        cv.paint(brows, SNOW, R=0.05, line=0.6, cast=False)
        # icicle beard
        dd = None
        for i, (x, ln) in enumerate(((-0.12, 0.6), (0.0, 0.9), (0.12, 1.05), (0.24, 0.85), (0.34, 0.55))):
            di = cv.cone(c + (x, 0.22), c + (x - 0.06, 0.22 + ln + 0.3 * p['mouth'] * (i % 2)), 0.08, 0.012)
            dd = di if dd is None else np.minimum(dd, di)
        cv.paint(dd, ICE, R=0.06, line=0.6, hl=1.3, pattern=facets(cv, 11, 0.12))
        must = cv.smin(cv.ellipse(c + (0.05, 0.22), 0.2, 0.07, rot=0.3), cv.ellipse(c + (0.3, 0.22), 0.16, 0.06, rot=-0.3), 0.05)
        cv.paint(must, SNOW, R=0.05, line=0.6, cast=False)
        cv.paint(cv.circle(c + (0.3, 0.1), 0.1), self.NOSE, R=0.08, line=0.6, cast=False, hl=1.4)
        if p['mouth'] > 0.2:
            nopaint(cv, cv.ellipse(c + (0.17, 0.32), 0.1, 0.03 + 0.05 * p['mouth']), hexc('2A0E14'))

    def staff_arm(self):
        cv, p = self.cv, self.p
        h = np.asarray(p['hand'], float)
        sd = np.array([np.cos(p['sa']), np.sin(p['sa'])])
        top = h + sd * p['up']
        bot = h - sd * p['dn']
        grain = 1 - 0.18 * np.clip(np.sin((cv.X * sd[1] - cv.Y * sd[0]) * 60 + cv.n_mid * 8), 0, 1)
        cv.paint(cv.path([bot, h, top - sd * 0.1], 0.075, 0.09), self.STAFF, R=0.08, pattern=grain)
        for k in (0.55, 0.75):
            q = h + sd * p['up'] * k
            cv.paint(cv.cone(q - sd * 0.06, q + sd * 0.06, 0.11, 0.11), RUST_D, R=0.04, line=0.6, cast=False)
        # ice crystal knob, rime collecting magenta in the wind-up
        kn = None
        for a, ln in ((0.0, 0.55), (0.55, 0.38), (-0.55, 0.38), (1.1, 0.25), (-1.1, 0.25)):
            dd = rot(sd, a)
            di = cv.cone(top - sd * 0.05, top + dd * ln, 0.12, 0.015)
            kn = di if kn is None else np.minimum(kn, di)
        r = p['rime']
        cv.paint(kn, ICE_L, R=0.08, hl=1.4, pattern=facets(cv, 12, 0.15),
                 glow=(MAG, 0.05 + 0.1 * r, 0.9 * r) if r > 0 else None)
        if r > 0:
            cv.paint(cv.circle(top + sd * 0.1, 0.08 + 0.12 * r), MAG_D * 1.3, R=0.05, line=0.5, cast=False,
                     union=False, glow=(MAG, 0.1 + 0.08 * r, 0.6 * r))
            for i in range(4):
                q = top + rot(sd, i * 1.57 + 0.4) * (0.45 - 0.25 * r)
                cv.paint(cv.circle(q, 0.03), MAG, R=0.02, line=0, shade=False, rim=False, cast=False, union=False,
                         glow=(MAG, 0.03, 0.6 * r))
        d, el, hh = limb(cv, self.arm_root, h, 0.85, 0.8, 0.32, 0.24, (-0.3, 1))
        cv.paint(cv.smin(d, cv.circle(self.arm_root, 0.33), 0.08), self.COAT * 1.05, R=0.25, pattern=fur(cv, 1.0, 0.12))
        cv.paint(cv.ellipse(self.arm_root + (0.0, -0.12), 0.34, 0.2), SNOW, R=0.1, line=0.6, cast=False)
        cv.paint(cv.circle(h, 0.21), self.MITT, R=0.15)

    def burst_fx(self):
        cv, p = self.cv, self.p
        b = p['burst']
        if b <= 0:
            return
        h = np.asarray(p['hand'], float)
        sd = np.array([np.cos(p['sa']), np.sin(p['sa'])])
        g = h - sd * p['dn']
        g = np.array([g[0], 0.0])
        for i in range(7):
            a = -np.pi / 2 + (i - 3) * 0.38
            ln = (0.5 + 0.35 * (i % 2)) * min(1.0, b * 1.6)
            e = g + np.array([np.cos(a), np.sin(a)]) * ln
            cv.paint(cv.cone(g + np.array([np.cos(a), np.sin(a)]) * 0.1, e, 0.08, 0.01), ICE_L, R=0.04, line=0.6,
                     cast=False, union=False, alpha=min(1.0, 2.2 - 1.6 * b))
        nopaint(cv, cv.ellipse(g + (0, -0.08), 0.6 + 0.9 * b, 0.12 + 0.1 * b), np.array([0.93, 0.97, 1.0]),
                alpha=0.8 * (1.2 - b))


K_REST = dict(hand=(1.15, -2.5), sa=-np.pi / 2 - 0.04)


def karachun_anims():
    idle = cyc(8, lambda k: dict(bob=0.04 * np.sin(k * TAU), squash=0.04 * np.sin(k * TAU), hand=(1.15, -2.5 + 0.04 * np.sin(k * TAU)),
                                 farh=(-1.05, -1.55 + 0.05 * np.sin(k * TAU)), mouth=0.1 + 0.1 * np.sin(k * TAU)))
    move = cyc(8, lambda k: dict(bob=-0.07 * abs(np.sin(k * TAU)), lean=0.06 * np.sin(k * TAU),
                                 hand=(1.15 + 0.25 * np.sin(k * TAU), -2.55), sa=-np.pi / 2 - 0.04 + 0.12 * np.sin(k * TAU),
                                 farh=(-1.0 - 0.15 * np.sin(k * TAU), -1.55)))

    def wind(k):
        e = ease(k)
        return dict(hand=lerp((1.15, -2.5), (0.95, -3.75), e), sa=float(lerp(-np.pi / 2 - 0.04, -np.pi / 2 + 0.08, e)),
                    lean=-0.12 * e, squash=-0.12 * e, rime=e, eye=1 + 1.5 * e, mouth=0.6 * e,
                    farh=lerp((-1.05, -1.55), (-1.55, -2.5), e))
    windup = seq(5, wind)

    def slam(k):
        e = ease(min(1.0, k * 1.8))
        return dict(hand=lerp((0.95, -3.75), (1.35, -2.4), e), sa=float(lerp(-np.pi / 2 + 0.08, -np.pi / 2 - 0.05, e)),
                    lean=float(lerp(-0.12, 0.22, e)), squash=float(lerp(-0.12, 0.22, e)), rime=1 - e, eye=2.2,
                    mouth=0.8, burst=max(0.0, (k - 0.35) / 0.65), farh=lerp((-1.55, -2.5), (-1.2, -1.3), e))
    attack = seq(5, slam)
    slam_end = seq(6, lambda k: dict(hand=lerp((1.35, -2.4), (1.15, -2.5), ease(k)), sa=-np.pi / 2 - 0.05,
                                     lean=float(lerp(0.22, 0.0, ease(k))), squash=float(lerp(0.22, 0.0, ease(k))),
                                     burst=1.0 + 0.0 * k if k < 0.2 else 0.0, eye=float(lerp(2.0, 1.0, k)), mouth=0.5 * (1 - k),
                                     farh=lerp((-1.2, -1.3), (-1.05, -1.55), ease(k))))
    poke_wind = seq(4, lambda k: dict(hand=lerp((1.15, -2.5), (0.25, -2.35), ease(k)), sa=float(lerp(-np.pi / 2 - 0.04, -np.pi + 0.02, ease(k))),
                                      lean=-0.1 * ease(k), rime=0.6 * ease(k), eye=1 + ease(k), mouth=0.4 * ease(k)))
    poke = seq(4, lambda k: dict(hand=lerp((0.25, -2.35), (1.55, -2.3), ease(min(1, k * 2))), sa=-np.pi + 0.02,
                                 lean=float(lerp(-0.1, 0.18, ease(min(1, k * 2)))), eye=2.0, mouth=0.6))
    hurt = seq(3, lambda k: dict(lean=-0.15 * np.sin(k * np.pi + 0.3), hand=(0.95, -2.7), sa=-np.pi / 2 - 0.3, eye=0.5, mouth=0.6))

    def die(k):
        e = ease(k)
        return dict(lean=-0.2 * e, squash=0.3 * e, eye=max(0.0, 1 - 1.4 * k), mouth=0.7,
                    hand=lerp((1.15, -2.5), (1.6, -0.9), e), sa=float(lerp(-np.pi / 2, -0.25, e)),
                    farh=lerp((-1.05, -1.55), (-1.3, -0.6), e), dy=1.6 * ease(max(0, (k - 0.3) / 0.7)), clip=0.05)
    death = seq(8, die)
    return dict(idle=(idle, 6, True), move=(move, 8, True), windup=(windup, 8, False), attack=(attack, 16, False),
                slam_end=(slam_end, 8, False), poke_wind=(poke_wind, 8, False), poke=(poke, 16, False),
                hurt=(hurt, 12, False), death=(death, 9, False))


# =====================================================================
class Snezhnitsa(Body):
    """Снежница: tall thin ice maiden, snowflake kokoshnik, triangle skirt, symmetric."""
    BOUNDS = (-2.1, 3.5, -5.0, 0.4)
    OUTLINE = FROST_OUT
    SKIN = hexc('C9DDEE')
    DRESS = hexc('3F5F8C')
    BODICE = hexc('7E9EC2')
    CROWN = hexc('F4FAFF')
    HAIR = hexc('E2EEF8')
    BASE = dict(bob=0.0, sway=0.0, lean=0.0, hand=(0.42, -1.85), farh=(-0.38, -1.85), cast=0.0, n=3, eye=1.0,
                crack=0.0, neck_r=0.12, sink=0.0)

    def setup(self):
        p = self.p
        y = p['bob'] + p['sink']
        self.base_y = y
        self.waist = np.array([0.0 + 0.2 * p['lean'], -2.3 + y])
        self.sh = np.array([0.03 + 0.35 * p['lean'], -2.88 + y])
        self.arm_root = self.sh + (0.2, 0.04)
        self.far_sh = self.sh + (-0.2, 0.04)
        self.neck = self.sh + (0.03, -0.16)
        self.hc = self.neck + (0.04, -0.27)

    def stump_n(self, key):
        return (0.1, -1.0)

    def layers(self):
        return [('head', self.braid), (None, self.far_arm), (None, self.dress), ('head', self.head), (None, self.near_arm)]

    def braid(self):
        c = self.hc
        self.strands([c + (-0.2, 0.0), c + (-0.12, 0.05)], [1.7, 1.5], self.HAIR, sway=-0.25 + self.p['sway'], w=0.07,
                     line=0.55)

    def dress(self):
        cv, p = self.cv, self.p
        y0 = min(0.0, self.base_y) - 0.02
        sw = p['sway'] * 0.35
        d = cv.poly([(-1.0 + sw, y0), (-0.2, self.waist[1]), (self.sh[0] - 0.22, self.sh[1] + 0.06),
                     (self.sh[0] + 0.24, self.sh[1] + 0.06), (0.22 + 0.2 * p['lean'], self.waist[1]), (1.0 + sw, y0)], 0.06)
        folds = 1 - 0.13 * np.clip(np.sin(cv.X * 14 + cv.Y * 1.2 + cv.n_mid * 5), 0, 1)
        cv.paint(d, self.DRESS, R=0.4, pattern=folds)
        bod = cv.inter(d - 0.02, cv.Y - (self.waist[1] + 0.05))
        cv.paint(bod, self.BODICE, R=0.15, line=0.6, cast=False)
        # magenta front panel stripe and white-ice saw-tooth hem
        panel = cv.inter(d - 0.03, np.abs(cv.X - (self.waist[0] + (cv.Y - self.waist[1]) * -0.0)) - (0.05 + 0.1 * (cv.Y - self.waist[1]) / 2.3))
        panel = cv.inter(panel, -(cv.Y - self.waist[1] - 0.05))
        cv.paint(panel, MAG_D, R=0.05, line=0.5, cast=False)
        tooth = cv.Y - (y0 - 0.32 - 0.22 * np.abs(((cv.X * 2.6) % 1.0) - 0.5) * 2)
        cv.paint(cv.inter(d - 0.015, -tooth), self.CROWN * 0.95, R=0.06, line=0.6, cast=False, pattern=facets(cv, 10, 0.1))
        belt = cv.inter(d - 0.01, np.abs(cv.Y - self.waist[1] - 0.05) - 0.05)
        cv.paint(belt, self.CROWN, R=0.03, line=0.5, cast=False)
        if p['crack'] > 0:
            w = self.waist
            self.crack([w + (-0.1, 0.1), w + (0.15, 0.6), w + (-0.1, 1.2), w + (0.2, 1.9)], 0.02, p['crack'])
            self.crack([w + (0.0, -0.4), w + (-0.15, -0.1)], 0.018, p['crack'])

    def head(self):
        cv, p = self.cv, self.p
        c = self.hc
        # snowflake kokoshnik: a fan of rays with cross-bars behind the head
        rays = None
        for i in range(7):
            a = np.pi + np.pi * (i + 0.5) / 7
            dd = np.array([np.cos(a), np.sin(a)])
            b = c + (0.0, -0.08)
            e = b + dd * (0.62 + 0.1 * (i % 2 == 1))
            di = cv.cone(b, e, 0.06, 0.02)
            m = b + dd * 0.42
            di = np.minimum(di, cv.cone(m - rot(dd, np.pi / 2) * 0.11, m + rot(dd, np.pi / 2) * 0.11, 0.025, 0.025))
            rays = di if rays is None else np.minimum(rays, di)
        half = cv.inter(cv.circle(c + (0, -0.08), 0.36), cv.Y - (c[1] - 0.05))
        rays = np.minimum(rays, half)
        cv.paint(rays, self.CROWN, R=0.06, line=0.75, hl=1.2, pattern=facets(cv, 12, 0.12))
        for i in range(7):
            a = np.pi + np.pi * (i + 0.5) / 7
            q = c + (0.0, -0.08) + np.array([np.cos(a), np.sin(a)]) * (0.62 + 0.1 * (i % 2 == 1))
            cv.paint(cv.circle(q, 0.045), ICE, R=0.03, line=0.5, cast=False, union=False)
        face = cv.ellipse(c + (0.02, 0.05), 0.2, 0.25)
        cv.paint(face, self.SKIN, R=0.15)
        cv.paint(cv.inter(face - 0.01, cv.Y - (c[1] - 0.03)), self.HAIR, R=0.06, line=0.5, cast=False)
        cv.paint(cv.circle(c + (0.02, -0.12), 0.06), MAG_D, R=0.03, line=0.5, cast=False, union=False,
                 glow=(MAG, 0.04, 0.4))
        self.eyes([c + (-0.05, 0.06), c + (0.1, 0.06)], 0.035, MAG_D * 1.6, glow=p['eye'])
        cv.paint(cv.ellipse(c + (0.03, 0.2), 0.04, 0.015), hexc('6E2A44'), R=0.01, line=0, shade=False, rim=False,
                 cast=False, union=False)

    def far_arm(self):
        cv, p = self.cv, self.p
        d, el, h = limb(cv, self.far_sh, p['farh'], 0.55, 0.55, 0.07, 0.045, (-1, 0.3))
        cv.paint(d, self.SKIN, R=0.05, dim=0.75)
        cv.paint(cv.cone(self.far_sh, el, 0.12, 0.15), self.BODICE, R=0.08, dim=0.75, line=0.7)

    def near_arm(self):
        cv, p = self.cv, self.p
        d, el, h = limb(cv, self.arm_root, p['hand'], 0.58, 0.58, 0.07, 0.045, (-1, 0.6))
        d = cv.smin(d, fingers(cv, h, unit(np.asarray(h) - el), n=4, ln=0.18, r=0.02, spread=0.7, curl=0.2), 0.02)
        cv.paint(d, self.SKIN, R=0.05)
        cv.paint(cv.cone(self.arm_root, lerp(self.arm_root, el, 1.15), 0.12, 0.17), self.BODICE, R=0.08, line=0.7)
        k = p['cast']
        if k > 0:
            fd = unit(np.asarray(h) - el)
            for i in range(int(p['n'])):
                a = (i - 1) * 0.38 * (1 - 0.6 * k) if p['n'] == 3 else (i - (p['n'] - 1) / 2) * 0.3
                dd = rot(fd, a)
                b = np.asarray(h) + dd * 0.12
                e = b + dd * (0.4 + 0.6 * k)
                cv.paint(cv.cone(b, e, 0.07, 0.012), ICE_L, R=0.03, line=0.55, cast=False, union=False, hl=1.4)
            cv.paint(cv.circle(h, 0.06), MAG, R=0.03, line=0, shade=False, rim=False, cast=False, union=False,
                     glow=(MAG, 0.08 + 0.05 * k, 0.7 * k + 0.2))


def snezhnitsa_anims():
    idle = cyc(8, lambda k: dict(bob=-0.06 - 0.05 * np.sin(k * TAU), sway=0.08 * np.sin(k * TAU),
                                 hand=(0.42, -1.85 + 0.04 * np.sin(k * TAU)), farh=(-0.38, -1.85 + 0.04 * np.sin(k * TAU))))
    move = cyc(8, lambda k: dict(bob=-0.08 - 0.04 * np.sin(k * TAU * 2), sway=-0.3 + 0.1 * np.sin(k * TAU), lean=0.12,
                                 hand=(0.3, -1.95), farh=(-0.5, -1.9)))
    windup = seq(5, lambda k: dict(bob=-0.08, hand=lerp((0.42, -1.85), (1.3, -2.5), ease(k)), cast=ease(k), eye=1 + 1.4 * ease(k),
                                    farh=lerp((-0.38, -1.85), (-0.7, -2.2), ease(k)), lean=-0.05 * ease(k)))
    attack = cyc(6, lambda k: dict(bob=-0.08, hand=(1.3 + 0.12 * np.sin(k * TAU * 3), -2.5), cast=1.0,
                                   n=3 - min(2, int(k * 3)), eye=2.2, farh=(-0.7, -2.2), lean=0.05))
    hurt = seq(3, lambda k: dict(lean=-0.2 * np.sin(k * np.pi + 0.3), eye=0.4, sway=0.2, hand=(0.3, -2.1)))

    def die(k):
        return dict(crack=min(1.0, k * 2.5), eye=max(0.0, 1 - 1.5 * k), lean=-0.1 * ease(k), hand=(0.2, -1.6),
                    farh=(-0.3, -1.6), sink=2.6 * ease(max(0, (k - 0.35) / 0.65)), clip=0.0,
                    fade=1 - 0.5 * ease(max(0, (k - 0.6) / 0.4)))
    death = seq(8, die)
    return dict(idle=(idle, 7, True), move=(move, 8, True), windup=(windup, 8, False), attack=(attack, 13, False),
                hurt=(hurt, 12, False), death=(death, 9, False))


# =====================================================================
class Sosulnik(Body):
    """Сосульник: an upside-down icicle with a magenta core under a frozen stone cap;
    after the fall a triangle on three needle legs; dies by cracking into 3 shards."""
    BOUNDS = (-2.5, 3.6, -3.9, 0.5)
    OUTLINE = FROST_OUT
    ROCK = hexc('4A5468')
    BASE = dict(hang=1.0, jit=0.0, core=0.6, eye=1.0, gait=0.0, lean=0.0, spike=0.0, crack=0.0, stretch=0.0,
                shatter=0.0, dust=0.0, legs=1.0)

    def layers(self):
        if self.p['shatter'] > 0:
            return [(None, self.shards)]
        if self.p['hang'] > 0.5:
            return [(None, self.hanging), (None, self.fx)]
        return [(None, self.legs_l), (None, self.standing), (None, self.fx)]

    def icicle(self, pts, col=ICE_L):
        cv = self.cv
        d = cv.poly(pts, 0.04)
        cv.paint(d, col, R=0.35, pattern=facets(cv, 6, 0.15), hl=1.3)
        return d

    def hanging(self):
        cv, p = self.cv, self.p
        j = p['jit']
        s = 1 + p['stretch']
        top = -3.0
        side = np.minimum(cv.cone((-0.62 + j, top), (-0.5 + j, top + 1.05), 0.16, 0.02),
                          cv.cone((0.6 + j, top), (0.5 + j, top + 0.8), 0.14, 0.02))
        cv.paint(side, ICE * 0.95, R=0.1, pattern=facets(cv, 9, 0.12))
        self.icicle([(-0.66 + j, top), (0.66 + j, top), (j, top + 3.0 * s)])
        cv.flat(cv.path([(-0.3 + j, top + 0.2), (-0.08 + j, top + 2.2)], 0.035, 0.01), np.array([1.0, 1.0, 1.0]), alpha=0.65)
        cap = cv.smin(cv.ellipse((j, top - 0.02), 0.85, 0.2), cv.ellipse((0.3 + j, top - 0.12), 0.4, 0.16), 0.1)
        cv.paint(cap, self.ROCK, R=0.12)
        cv.paint(cv.inter(cap - 0.01, cv.Y - (top - 0.1)), SNOW, R=0.06, line=0.5, cast=False)
        self.core((j, top + 0.95), p['core'])
        self.eyes([(j - 0.16, top + 0.55), (j + 0.16, top + 0.55)], 0.05 + 0.015 * p['eye'], MAG_D * 1.6, glow=p['eye'],
                  slit=True, ang=0.0)
        if p['crack'] > 0:
            self.crack([(j - 0.4, top + 0.05), (j - 0.25, top + 0.35), (j - 0.35, top + 0.6)], 0.02, p['crack'])
            self.crack([(j + 0.35, top + 0.05), (j + 0.2, top + 0.4)], 0.02, p['crack'])

    def core(self, c, k):
        cv = self.cv
        cv.paint(cv.circle(c, 0.19 + 0.05 * k), MAG_D * (1 + 0.4 * k), R=0.12, line=0.5, cast=False, union=False,
                 glow=(MAG, 0.07 + 0.05 * k, 0.4 + 0.6 * k))
        cv.flat(cv.circle(np.asarray(c) + (-0.05, -0.05), 0.06), np.array([1.0, 0.8, 0.92]), alpha=0.8)

    def legs_l(self):
        cv, p = self.cv, self.p
        lg = p['legs']
        by = -0.9 * lg
        for i, dim in ((0, 0.75), (2, 0.75), (1, 1.0)):
            x = (i - 1) * 0.55
            sw = 0.15 * np.sin(p['gait'] * TAU + i * 2.1)
            d = cv.path([(x * 0.4, by), (x * 0.9 + sw * 0.5, by * 0.45 - 0.08), (x + sw, 0.0)], 0.07, 0.015)
            cv.paint(d, ICE, R=0.05, dim=dim, pattern=facets(cv, 12, 0.1))

    def standing(self):
        cv, p = self.cv, self.p
        lg = p['legs']
        by = -0.9 * lg
        ln = p['lean']
        if p['spike'] > 0:
            s = p['spike']
            a = np.array([0.35 + ln * 0.5, -1.55])
            cv.paint(cv.cone(a, a + (0.35 + 2.4 * s, 0.05), 0.11, 0.015), ICE_L, R=0.05, hl=1.4, pattern=facets(cv, 12, 0.1))
        self.icicle([(-0.62, by), (0.62, by), (ln, -3.0 + 0.9 * (1 - lg))])
        cv.flat(cv.path([(-0.35, by - 0.1), (ln - 0.08, by - 1.6)], 0.035, 0.01), np.array([1.0, 1.0, 1.0]), alpha=0.6)
        self.core((ln * 0.35, by - 0.55), p['core'])
        self.eyes([(ln * 0.5 + 0.0, by - 1.15), (ln * 0.5 + 0.22, by - 1.12)], 0.05 + 0.015 * p['eye'], MAG_D * 1.6,
                  glow=p['eye'], slit=True, ang=0.2)

    def fx(self):
        cv, p = self.cv, self.p
        if p['dust'] > 0:
            k = p['dust']
            for i in range(6):
                u = (i - 2.5) / 2.5
                q = (u * (0.5 + 1.3 * k), -0.15 - 0.5 * k * (1 - abs(u)))
                nopaint(cv, cv.ellipse(q, 0.25 + 0.15 * k, 0.12), np.array([0.92, 0.96, 1.0]), alpha=0.8 * (1.1 - k))
            for i in range(5):
                a = -np.pi / 2 + (i - 2) * 0.5
                q = np.array([np.cos(a), np.sin(a)]) * (0.4 + 1.2 * k) + (0, -0.1)
                cv.paint(cv.cone(q, q + np.array([np.cos(a), np.sin(a)]) * 0.18, 0.05, 0.01), ICE_L, R=0.02,
                         line=0.5, cast=False, union=False, alpha=1.1 - k)
        if p['stretch'] > 0:
            for x in (-0.45, 0.0, 0.45):
                cv.flat(cv.cone((x, -3.7), (x, -3.2), 0.015, 0.03), np.array([1.0, 1.0, 1.0]), alpha=0.6)

    def shards(self):
        cv, p = self.cv, self.p
        k = p['shatter']
        tris = ([(-0.62, -0.9), (0.0, -0.9), (-0.2, -2.2)], [(0.0, -0.9), (0.62, -0.9), (0.2, -2.0)],
                [(-0.28, -1.95), (0.28, -1.95), (0.0, -3.0)])
        dirs = ((-1.0, -0.4), (1.0, -0.5), (0.2, -1.0))
        for tri, dv in zip(tris, dirs):
            c = np.mean(tri, axis=0)
            off = np.array(dv) * 1.3 * k + (0, 2.6 * k * k)
            ang = 1.8 * k * np.sign(dv[0] + 0.01)
            pts = [c + off + rot(np.array(q) - c, ang) for q in tri]
            pts = [(q[0], min(q[1], 0.0)) for q in pts]
            self.icicle(pts, ICE_L * (1 - 0.15 * k))
        if k < 0.5:
            self.core((0.0, -1.45 + 1.5 * k), 1.2 - 2 * k)
        for i in range(6):
            a = i * 1.05 + 0.3
            q = np.array([np.cos(a), np.sin(a)]) * (0.4 + 1.6 * k) + (0, -1.5 + 1.2 * k)
            glint(cv, q, 0.1 * (1 - k) + 0.02, 0.9)


def sosulnik_anims():
    hang = cyc(6, lambda k: dict(core=0.5 + 0.25 * np.sin(k * TAU), eye=0.8 + 0.3 * np.sin(k * TAU)))
    shake = seq(6, lambda k: dict(jit=0.09 * (1 if (int(k * 10) % 2) else -1) * (0.4 + k), core=0.6 + 0.8 * k,
                                  eye=1 + 1.2 * k, crack=k))
    fall = cyc(2, lambda k: dict(stretch=0.06 + 0.04 * k, core=1.2, eye=2.0, crack=1.0))

    def land(k):
        if k < 0.35:
            return dict(dy=0.45, clip=0.0, dust=k / 0.35, core=1.2, eye=1.5, crack=1.0)
        if k < 0.85:
            u = (k - 0.35) / 0.5
            return dict(rot=float(180 * ease(u)), pivot=(0.0, -1.5), dy=0.45 * (1 - u), dust=min(1.0, 0.7 + u),
                        core=1.0, eye=1.2)
        return dict(hang=0.0, legs=(k - 0.85) / 0.15, core=0.8)
    land_a = seq(8, land)
    idle = cyc(6, lambda k: dict(hang=0.0, core=0.6 + 0.2 * np.sin(k * TAU), lean=0.05 * np.sin(k * TAU)))
    move = cyc(6, lambda k: dict(hang=0.0, gait=k, lean=0.12, core=0.6, dy=-0.04 * abs(np.sin(k * TAU * 2))))
    windup = seq(5, lambda k: dict(hang=0.0, lean=-0.25 * ease(k), spike=0.25 * ease(k), core=0.6 + 0.9 * ease(k), eye=1 + 1.4 * ease(k)))
    attack = seq(4, lambda k: dict(hang=0.0, lean=float(lerp(-0.25, 0.35, ease(min(1, k * 2)))), spike=float(lerp(0.25, 1.0, ease(min(1, k * 2.2)))),
                                   core=1.4, eye=2.0, dx=0.2 * ease(min(1, k * 2))))
    hurt = seq(3, lambda k: dict(hang=0.0, lean=-0.2 * np.sin(k * np.pi), eye=0.4, core=1.0, dx=-0.08 * np.sin(k * np.pi)))
    death = seq(8, lambda k: dict(shatter=0.02 + 0.98 * ease(k), fade=1 - ease(max(0, (k - 0.6) / 0.4))))
    return dict(hang=(hang, 6, True), shake=(shake, 14, False), fall=(fall, 12, True), land=(land_a, 14, False),
                idle=(idle, 6, True), move=(move, 12, True), windup=(windup, 8, False), attack=(attack, 14, False),
                hurt=(hurt, 12, False), death=(death, 12, False))


# =====================================================================
class Mara(Body):
    """Мара: thin dark vertical in a torn veil, pointed hood, a pale gaunt face with
    magenta eyes, long bony arms; magenta thread bands at the wrists."""
    BOUNDS = (-2.6, 3.4, -5.1, 0.4)
    OUTLINE = FROST_OUT
    VEIL = hexc('2C3B52')
    SKIN = hexc('C3CCD8')
    BASE = dict(bob=0.0, sway=0.0, lean=0.0, hand=(0.5, -1.55), farh=(-0.4, -1.6), eye=1.0, palm=0.0, claw=0.0,
                stump_r=0.1, neck_r=0.14, billow=0.0)

    def setup(self):
        p = self.p
        y = p['bob']
        self.sh = np.array([0.05 + 0.35 * p['lean'], -3.4 + y])
        self.arm_root = self.sh + (0.22, 0.06)
        self.far_sh = self.sh + (-0.22, 0.06)
        self.neck = self.sh + (0.05 + 0.1 * p['lean'], -0.14)
        self.hc = self.neck + (0.06 + 0.1 * p['lean'], -0.3)

    def stump_n(self, key):
        return (1.0, -0.3) if key == 'arm' else (0.1, -1.0)

    def layers(self):
        return [(None, self.far_arm), (None, self.veil), ('head', self.head), ('arm', self.near_arm)]

    def veil(self):
        cv, p = self.cv, self.p
        sw, b = p['sway'], p['billow']
        hem = -0.45 + p['bob'] * 0.5
        d = cv.poly([(-0.75 + sw * 0.5 - 0.4 * b, hem), (-0.32, self.sh[1] + 0.9), (self.sh[0] - 0.3, self.sh[1] + 0.05),
                     (self.sh[0] + 0.32, self.sh[1] + 0.05), (0.3 + 0.25 * p['lean'], self.sh[1] + 1.0),
                     (0.7 + sw * 0.5 + 0.2 * b, hem)], 0.08)
        folds = 1 - 0.16 * np.clip(np.sin(cv.X * 16 + cv.Y * 0.8 + cv.n_mid * 5), 0, 1)
        cv.paint(d, self.VEIL, R=0.35, pattern=folds)
        roots = [(x, hem - 0.15) for x in np.linspace(-0.65 - 0.3 * b, 0.6 + 0.15 * b, 8)]
        self.strands(roots, [0.55, 0.4, 0.5, 0.3, 0.48, 0.38, 0.52, 0.35], self.VEIL * 0.85, sway=sw - 0.15 - 0.3 * b,
                     w=0.09, line=0.55)
        # torn holes showing the snow through, magenta thread sash
        for c, r in (((-0.3, -1.3), 0.08), ((0.25, -0.9), 0.06)):
            nopaint(cv, cv.ellipse((c[0] + sw * 0.2, c[1]), r, r * 1.6), NIGHT)
        sy = self.sh[1] + 1.25
        sash = cv.inter(d - 0.02, np.abs(cv.Y - sy - cv.X * 0.25) - 0.035)
        cv.paint(sash, MAG_D, R=0.03, line=0.4, cast=False)

    def head(self):
        cv, p = self.cv, self.p
        c = self.hc
        hood = cv.poly([c + (-0.38, 0.35), c + (-0.2, -0.3), c + (0.0, -0.75), c + (0.32, -0.25), c + (0.42, 0.35)], 0.1)
        cv.paint(hood, self.VEIL * 1.08, R=0.2, pattern=1 - 0.1 * np.clip(np.sin(cv.X * 20 + cv.Y * 4), 0, 1))
        hole = cv.ellipse(c + (0.12, 0.08), 0.23, 0.28)
        nopaint(cv, hole, NIGHT)
        face = cv.inter(cv.ellipse(c + (0.16, 0.12), 0.16, 0.24), cv.Y - (c[1] + 0.4))
        cv.paint(face, self.SKIN, R=0.12, line=0.5, cast=False, union=False)
        nopaint(cv, cv.ellipse(c + (0.17, 0.02), 0.13, 0.06), INK * 1.3)
        self.eyes([c + (0.1, 0.02), c + (0.25, 0.03)], 0.04 + 0.012 * p['eye'], MAG, glow=p['eye'] * 1.2)
        cv.ink(cv.path([c + (0.1, 0.22), c + (0.17, 0.25), c + (0.24, 0.22)], 0.012), alpha=0.8)

    def arm(self, root, hand, dim, near):
        cv, p = self.cv, self.p
        d, el, h = limb(cv, root, hand, 0.92, 0.9, 0.065, 0.045, (-1, 0.5) if near else (-1, 0.3))
        fd = unit(np.asarray(h) - el)
        cl = fingers(cv, h, fd, n=4, ln=0.34 + 0.08 * p['claw'], spread=0.7 + 0.3 * p['claw'], r=0.024, curl=0.5 - 0.4 * p['claw'])
        cv.paint(cv.smin(d, cl, 0.02), self.SKIN, R=0.05, dim=dim)
        sl = cv.cone(root, lerp(root, el, 1.05), 0.14, 0.2)
        cv.paint(sl, self.VEIL * 0.95, R=0.1, dim=dim, line=0.7)
        self.strands([lerp(root, el, 1.0) + (0, 0.1)], [0.45], self.VEIL * 0.85, sway=-0.2, w=0.06, line=0.5, dim=dim)
        wr = lerp(el, h, 0.8)
        cv.paint(cv.cone(wr - fd * 0.04, wr + fd * 0.04, 0.06, 0.06), MAG_D * 1.2, R=0.02, line=0.4, cast=False,
                 union=False, dim=dim)
        if p['palm'] > 0:
            cv.paint(cv.circle(np.asarray(h) + fd * 0.12, 0.07), MAG, R=0.03, line=0, shade=False, rim=False, cast=False,
                     union=False, glow=(MAG, 0.1 + 0.06 * p['palm'], 0.8 * p['palm']))

    def far_arm(self):
        self.arm(self.far_sh, self.p['farh'], 0.72, False)

    def near_arm(self):
        self.arm(self.arm_root, self.p['hand'], 1.0, True)


def mara_anims():
    idle = cyc(8, lambda k: dict(bob=-0.05 + 0.06 * np.sin(k * TAU), sway=0.12 * np.sin(k * TAU),
                                 hand=(0.5, -1.55 + 0.05 * np.sin(k * TAU)), farh=(-0.4, -1.6 + 0.05 * np.sin(k * TAU + 1))))
    move = cyc(8, lambda k: dict(bob=-0.08 + 0.04 * np.sin(k * TAU * 2), sway=-0.35 + 0.1 * np.sin(k * TAU), lean=0.1,
                                 hand=(0.35, -1.65), farh=(-0.6, -1.7), billow=0.4))
    windup = seq(5, lambda k: dict(hand=lerp((0.5, -1.55), (0.0, -4.4), ease(k)), farh=(-0.6, -2.0), lean=-0.15 * ease(k),
                                    claw=ease(k), eye=1 + 1.5 * ease(k), sway=0.15 * ease(k), palm=0.4 * ease(k)))
    attack = seq(4, lambda k: dict(hand=lerp((0.0, -4.4), (2.3, -1.4), ease(min(1, k * 1.8))), farh=(-0.7, -1.8),
                                   lean=float(lerp(-0.15, 0.3, ease(min(1, k * 1.8)))), claw=1.0, eye=2.2, sway=-0.2))
    raise_a = seq(6, lambda k: dict(hand=lerp((0.5, -1.55), (1.15, -2.65), ease(min(1, k * 1.6))),
                                    farh=lerp((-0.4, -1.6), (0.85, -2.75), ease(min(1, k * 1.6))),
                                    palm=ease(k), eye=1 + 1.6 * ease(k), billow=0.9 * ease(k), bob=-0.25 * ease(k),
                                    sway=0.12 * np.sin(k * 14), claw=0.3))
    hurt = seq(3, lambda k: dict(lean=-0.22 * np.sin(k * np.pi + 0.3), eye=0.4, sway=0.3, hand=(0.3, -1.9)))

    def die(k):
        f = max(0.0, (k - 0.25) / 0.75)
        return dict(eye=max(0.0, 1 - 1.4 * k), lean=-0.1 * ease(k), hand=(0.6, -1.2), farh=(-0.6, -1.2), sway=0.3,
                    rot=-84 * ease(f), pivot=(-0.4, 0.0), rest=True, rest_sink=0.05 * f)
    death = seq(8, die)
    return dict(idle=(idle, 7, True), move=(move, 8, True), windup=(windup, 8, False), attack=(attack, 14, False),
                raise_=(raise_a, 8, False), hurt=(hurt, 12, False), death=(death, 10, False))


def _rename(fn, old, new):
    def g():
        a = fn()
        a[new] = a.pop(old)
        return a
    return g


KINDS_FROST = {
    'wolf': (Wolf, wolf_anims, ['head'], []),
    'jelly': (ColdSpirit, jelly_anims, [], []),
    'karachun': (Karachun, karachun_anims, ['arm', 'head'], LIVE + ['poke_wind', 'poke', 'slam_end']),
    'snezhnitsa': (Snezhnitsa, snezhnitsa_anims, ['head'], LIVE),
    'sosulnik': (Sosulnik, sosulnik_anims, [], []),
    'mara': (Mara, _rename(mara_anims, 'raise_', 'raise'), ['arm', 'head'], LIVE + ['raise']),
}

# enemy state -> animation (build.py STATES format, read by drawn_enemy_visual.gd).
STATES_FROST = {
    'wolf': {'idle': {'anim': 'idle', 'moving': 'move'}, 'run': {'anim': 'idle', 'moving': 'move'},
             'crouch': {'anim': 'windup', 'k': 'crouch'}, 'bite': {'anim': 'attack', 'k': 'bite_time'},
             'hop': {'anim': 'hop', 'k': 'hop_time'}, 'recover': {'anim': 'idle'}},
    'jelly': {'idle': {'anim': 'idle', 'moving': 'move'}, 'drift': {'anim': 'idle', 'moving': 'move'},
              'chill_w': {'anim': 'windup', 'k': 'chill_w', 'after': 'attack'}},
    'karachun': {'walk': {'anim': 'idle', 'moving': 'move'}, 'slam_wind': {'anim': 'windup', 'k': 'slam_wind'},
                 'slam': {'anim': 'attack', 'k': 'slam_time', 'after': 'slam_end'},
                 'poke_wind': {'anim': 'poke_wind', 'k': 'poke_wind'}, 'poke': {'anim': 'poke', 'k': 'poke_time'},
                 'recover': {'anim': 'idle'}},
    'snezhnitsa': {'walk': {'anim': 'idle', 'moving': 'move'}, 'cast': {'anim': 'windup', 'k': 'cast'},
                   'volley': {'anim': 'attack'}},
    'sosulnik': {'idle': {'anim': 'hang'}, 'hang': {'anim': 'hang'}, 'shake': {'anim': 'shake', 'k': 'shake'},
                 'fall': {'anim': 'fall'}, 'land': {'anim': 'land', 'k': 'land'},
                 'walk': {'anim': 'idle', 'moving': 'move'}, 'poke_wind': {'anim': 'windup', 'k': 'poke_wind'},
                 'poke': {'anim': 'attack', 'k': 'poke_time'}, 'recover': {'anim': 'idle'}},
    'mara': {'walk': {'anim': 'idle', 'moving': 'move'}, 'raise_w': {'anim': 'raise', 'k': 'raise'},
             'scratch_wind': {'anim': 'windup', 'k': 'scratch_wind'}, 'scratch': {'anim': 'attack', 'k': 'scratch_time'}},
}


# ---------------- effect sprites (not enemies) ----------------
def fx_puddle():
    """Ice puddle of the Студёный дух: zone_w 170 world px wide, drawn for the floor line at y = 0."""
    from base import S_RENDER, DOWN
    from sdf2d import Canvas
    hw = W(85)
    cv = Canvas(-hw - 0.2, hw + 0.2, -1.25, 0.3, S_RENDER, seed=11)
    slab = cv.ellipse((0.0, -0.08), hw, 0.2)
    cv.paint(slab, ICE * 0.9, R=0.15, line=0.6, pattern=facets(cv, 6, 0.15), hl=1.3)
    for i, x in enumerate(np.linspace(-hw + 0.35, hw - 0.35, 9)):
        h = 0.45 + 0.35 * ((i * 7) % 3) / 2
        d = cv.cone((x, -0.1), (x + 0.05 * ((i % 3) - 1), -0.1 - h), 0.11, 0.012)
        d = np.minimum(d, cv.cone((x + 0.12, -0.1), (x + 0.28, -0.1 - h * 0.55), 0.06, 0.01))
        cv.paint(d, ICE_L, R=0.06, line=0.6, hl=1.4, pattern=facets(cv, 12, 0.12))
    for x in (-1.8, -0.4, 1.1, 2.3):
        cv.ink(cv.path([(x, -0.15), (x + 0.25, -0.05), (x + 0.15, 0.05)], 0.012), alpha=0.6, col=MAG_D)
    cv.outer_outline(1.6)
    img = cv.image(DOWN)
    return img, {'origin': [round((hw + 0.2) * S_RENDER / DOWN, 1), round(1.25 * S_RENDER / DOWN, 1)]}


def fx_spike():
    """One Карачун wave spike (3 variants in a row), base centre at the cell's bottom middle."""
    from base import S_RENDER, DOWN
    from sdf2d import Canvas
    from PIL import Image
    cells = []
    for v in range(3):
        cv = Canvas(-0.6, 0.6, -2.0, 0.1, S_RENDER, seed=20 + v)
        hh = W(40) * (1.0 + 0.12 * (v - 1))
        d = cv.cone((0.0, 0.0), (0.04 * (v - 1), -hh), 0.24, 0.02)
        d = np.minimum(d, cv.cone((-0.2, 0.0), (-0.35, -hh * 0.5), 0.13, 0.015))
        d = np.minimum(d, cv.cone((0.22, 0.0), (0.33 - 0.05 * v, -hh * (0.4 + 0.1 * v)), 0.12, 0.015))
        cv.paint(d, ICE_L, R=0.12, hl=1.4, pattern=facets(cv, 9, 0.16))
        cv.flat(cv.cone((-0.05, -0.15), (0.0, -hh * 0.8), 0.03, 0.008), np.array([1.0, 1.0, 1.0]), alpha=0.7)
        cv.ink(cv.path([(0.05, -0.1), (0.1, -hh * 0.35)], 0.015), alpha=0.6, col=MAG_D)
        cv.outer_outline(1.8)
        cells.append(cv.image(DOWN))
    w, h = cells[0].size
    out = Image.new('RGBA', (w * 3, h), (0, 0, 0, 0))
    for i, c in enumerate(cells):
        out.paste(c, (i * w, 0))
    return out, {'cell': [w, h], 'frames': 3, 'origin': [w / 2, round(2.0 * S_RENDER / DOWN, 1)]}


def fx_needle():
    """Frost needle of the Снежница, along +x, centre = the needle's hit point."""
    from base import S_RENDER, DOWN
    from sdf2d import Canvas
    cv = Canvas(-1.3, 0.6, -0.3, 0.3, S_RENDER, seed=31)
    trail = cv.cone((-1.2, 0.0), (-0.2, 0.0), 0.02, 0.1)
    nopaint(cv, trail, ICE, alpha=0.45)
    d = cv.cone((-0.7, 0.0), (0.5, 0.0), 0.075, 0.01)
    d = np.minimum(d, cv.cone((-0.55, 0.0), (-0.8, -0.13), 0.035, 0.01))
    d = np.minimum(d, cv.cone((-0.55, 0.0), (-0.8, 0.13), 0.035, 0.01))
    cv.paint(d, ICE_L, R=0.05, hl=1.5, pattern=facets(cv, 14, 0.12))
    cv.flat(cv.cone((-0.5, -0.02), (0.35, -0.01), 0.018, 0.005), np.array([1.0, 1.0, 1.0]), alpha=0.85)
    cv.paint(cv.circle((-0.62, 0.0), 0.05), MAG, R=0.02, line=0, shade=False, rim=False, cast=False, union=False,
             glow=(MAG, 0.05, 0.5))
    cv.outer_outline(1.5)
    img = cv.image(DOWN)
    return img, {'origin': [round(1.3 * S_RENDER / DOWN, 1), round(0.3 * S_RENDER / DOWN, 1)]}


FX = {'jelly': {'puddle': fx_puddle}, 'karachun': {'spike': fx_spike}, 'snezhnitsa': {'needle': fx_needle}}

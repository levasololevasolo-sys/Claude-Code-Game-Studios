"""The seven Swamp enemies (bestiary §3.2), one rig + pose set each.

Silhouettes after design/gdd/bestiary.md §3.2, colours after the enemies.json
rows and art bible §4 (rust / Nav magenta eyes, swamp greens, ink #120D12).
Sizes match the hit boxes (enemies.json w, h; base.W converts world px).
"""
import numpy as np

from base import Body, W, hexc, ik, rot, lerp, ease, unit, RUST, MAG, ROT, INK  # noqa: F401

TAU = 2 * np.pi
WATER = hexc('2A3A33')


def limb(cv, a, t, l1, l2, r1, r2, hint):
    """Two-bone limb SDF (IK): returns sdf, joint, end."""
    j, e = ik(a, t, l1, l2, hint)
    rm = (r1 + r2) * 0.5
    d = cv.smin(cv.cone(a, j, r1, rm), cv.cone(j, e, rm, r2), 0.04)
    return d, j, e


def fingers(cv, at, fd, n=4, ln=0.22, spread=0.5, r=0.035, curl=0.0):
    d = None
    for i in range(n):
        k = (i / max(n - 1, 1) - 0.5) * spread
        dd = rot(fd, k)
        mid = np.asarray(at) + dd * ln * 0.55
        tip = mid + rot(dd, curl) * ln * 0.5
        di = cv.path([at, mid, tip], r, r * 0.5)
        d = di if d is None else np.minimum(d, di)
    return d


def cyc(n, fn):
    return [fn(i / n) for i in range(n)]


def seq(n, fn):
    return [fn(i / max(n - 1, 1)) for i in range(n)]


def water_ring(cv, c, rx, k=1.0, col=None):
    """Flat ink ripple on the bog surface."""
    d = np.abs(cv.ellipse(c, rx, rx * 0.16)) - 0.025
    cv.ink(d, alpha=0.55 * k, col=col)


# =====================================================================
class Balvan(Body):
    """Болванчик: stocky clay idol with a club, cracks, straw, rust eyes."""
    BOUNDS = (-2.1, 3.4, -4.5, 0.4)
    CLAY = hexc('8A6A4A')
    CLUB = hexc('5B3A24')
    STRAW = hexc('C9A85A')
    ROPE = hexc('6B5236')
    BASE = dict(bob=0.0, lean=0.0, fN=(0.42, 0.0), fF=(-0.32, 0.0), hand=(0.98, -1.3), ca=1.0,
                farh=(-0.62, -1.35), eye=1.0, squash=0.0, mouth=0.0, stump_r=0.2, neck_r=0.24)

    def setup(self):
        p = self.p
        lean = p['lean']
        self.hip = np.array([0.0, -0.95 + p['bob'] + p['squash'] * 0.2])
        self.tc = self.hip + (0.12 + lean * 0.8, -0.78 + p['squash'] * 0.15)
        self.neck = self.hip + (0.2 + lean * 1.5, -1.55 + p['squash'] * 0.3)
        self.hc = self.neck + (0.06 + lean * 0.3, -0.36)
        self.arm_root = self.hip + (0.42 + lean * 1.2, -1.2 + p['squash'] * 0.25)
        self.far_sh = self.hip + (-0.42 + lean * 1.2, -1.25 + p['squash'] * 0.25)

    def stump_n(self, key):
        return (0.9, -0.5) if key == 'arm' else (0.15, -1.0)

    def layers(self):
        return [(None, self.far_arm), (None, self.legs), (None, self.body), ('head', self.head),
                ('arm', self.club_arm)]

    def far_arm(self):
        cv, p = self.cv, self.p
        d, el, h = limb(cv, self.far_sh, p['farh'], 0.55, 0.55, 0.2, 0.17, (-1, 0.2))
        d = cv.smin(d, cv.circle(h, 0.2), 0.05)
        cv.paint(d, self.CLAY, R=0.2, dim=0.78)

    def legs(self):
        cv, p = self.cv, self.p
        for f, dim, off in ((p['fF'], 0.8, -0.28), (p['fN'], 1.0, 0.3)):
            hip = self.hip + (off, 0.0)
            d, kn, an = limb(cv, hip, np.asarray(f) + (0, -0.12), 0.5, 0.42, 0.3, 0.24, (1, -0.2))
            d = cv.smin(d, cv.ellipse(np.asarray(f) + (0.08, -0.1), 0.3, 0.13), 0.06)
            cv.paint(d, self.CLAY, R=0.22, dim=dim)
            self.crack([kn + (-0.08, -0.05), kn + (0.02, 0.06), kn + (-0.03, 0.16)], alpha=0.5 * dim)

    def body(self):
        cv = self.cv
        tc = self.tc
        d = cv.ellipse(tc, 0.82, 0.92)
        d = cv.smin(d, cv.ellipse(self.hip + (0.02, -0.05), 0.72, 0.4), 0.15)
        d = cv.smin(d, cv.ellipse(self.neck + (0, 0.12), 0.34, 0.22), 0.1)
        pat = 1 - 0.12 * np.clip(np.sin((cv.X * 3.1 + cv.Y * 5.3) * 3 + cv.n_mid * 6), 0, 1)
        cv.paint(d, self.CLAY, R=0.45, pattern=pat)
        # cracks of dried clay
        self.crack([tc + (-0.2, -0.6), tc + (-0.05, -0.32), tc + (-0.18, -0.05), tc + (0.02, 0.2)], 0.018)
        self.crack([tc + (0.3, -0.2), tc + (0.45, 0.05), tc + (0.38, 0.3)], 0.014, 0.55)
        # rope belt with straw tufts (an obereg sheaf)
        y = self.hip[1] - 0.12
        belt = cv.inter(d - 0.01, np.abs(cv.Y - y - (cv.X - self.hip[0]) * 0.08) - 0.07)
        cv.paint(belt, self.ROPE, R=0.06, line=0.6, cast=False,
                 pattern=1 - 0.3 * np.clip(np.sin((cv.X - cv.Y) * 40), 0, 1))
        roots = [(self.hip[0] + x, y + 0.05) for x in (-0.6, -0.45, -0.3, 0.42, 0.55)]
        self.strands(roots, [0.42, 0.55, 0.38, 0.45, 0.36], self.STRAW, sway=-0.12, w=0.035, line=0.45)
        # shoulder straw
        sh = [(self.far_sh[0] + x, self.far_sh[1] - 0.05) for x in (-0.1, 0.0, 0.1)]
        self.strands(sh, [0.3, 0.38, 0.28], self.STRAW, sway=-0.2, w=0.03, line=0.4, dim=0.9)

    def head(self):
        cv, p = self.cv, self.p
        c = self.hc
        d = cv.ellipse(c, 0.42, 0.38)
        d = cv.smin(d, cv.ellipse(c + (0, 0.22), 0.36, 0.2), 0.08)
        cv.paint(d, self.CLAY * 1.04, R=0.3)
        self.crack([c + (-0.15, -0.36), c + (-0.05, -0.18), c + (-0.12, 0.0)], 0.014)
        # straw tuft on top
        tips = [c + (dx, -0.33) for dx in (-0.18, -0.08, 0.02, 0.12)]
        dd = None
        for i, tp in enumerate(tips):
            a = -np.pi / 2 - 0.5 + i * 0.3
            e = tp + np.array([np.cos(a), np.sin(a)]) * (0.36 + 0.06 * (i % 2))
            di = cv.cone(tp, e, 0.035, 0.012)
            dd = di if dd is None else np.minimum(dd, di)
        cv.paint(dd, self.STRAW, R=0.03, line=0.5, cast=False)
        # carved eye holes with rust glow, a carved mouth
        e = p['eye']
        sock = np.minimum(cv.ellipse(c + (0.05, -0.04), 0.1, 0.07), cv.ellipse(c + (0.3, -0.05), 0.08, 0.065))
        cv.paint(sock, INK * 1.6, R=0.02, line=0, shade=False, rim=False, cast=False, union=False)
        self.eyes([c + (0.06, -0.04), c + (0.3, -0.05)], 0.05 + 0.012 * e, RUST, glow=e)
        m = cv.ellipse(c + (0.2, 0.17), 0.12, 0.025 + 0.06 * p['mouth'])
        cv.paint(m, INK * 1.4, R=0.02, line=0, shade=False, rim=False, cast=False, union=False)

    def club_arm(self):
        cv, p = self.cv, self.p
        d, el, h = limb(cv, self.arm_root, p['hand'], 0.6, 0.58, 0.24, 0.19, (-0.3, 1))
        a = p['ca']
        cd = np.array([np.cos(a), np.sin(a)])
        b0 = np.asarray(h) - cd * 0.25
        b1 = np.asarray(h) + cd * 1.65
        club = cv.cone(b0, b1, 0.08, 0.2)
        for k, rr in ((0.75, 0.07), (1.15, 0.08), (1.45, 0.06)):
            club = cv.smin(club, cv.circle(np.asarray(h) + cd * k + rot(cd, 1.4) * 0.17, rr), 0.03)
        grain = 1 - 0.18 * np.clip(np.sin((cv.X * cd[1] - cv.Y * cd[0]) * 60 + cv.n_mid * 8), 0, 1)
        cv.paint(club, self.CLUB, R=0.15, pattern=grain)
        d = cv.smin(d, cv.ellipse(self.arm_root, 0.28, 0.24), 0.06)
        cv.paint(d, self.CLAY, R=0.22)
        self.crack([el + (-0.05, -0.1), el + (0.04, 0.02)], 0.013, 0.5)
        fist = cv.smin(cv.circle(h, 0.2), cv.cone(h, np.asarray(h) + cd * 0.12, 0.17, 0.15), 0.05)
        cv.paint(fist, self.CLAY, R=0.15)


def balvan_anims():
    idle = cyc(8, lambda k: dict(bob=0.04 * np.sin(k * TAU), squash=0.04 * np.sin(k * TAU),
                                 hand=(0.98, -1.3 + 0.04 * np.sin(k * TAU)), ca=1.0 + 0.03 * np.sin(k * TAU),
                                 farh=(-0.62, -1.35 + 0.04 * np.sin(k * TAU))))

    def step(k):
        s = np.sin(k * TAU)
        return dict(bob=-0.06 * abs(np.cos(k * TAU)), lean=0.05,
                    fN=(0.25 + 0.3 * s, -0.16 * max(0, np.cos(k * TAU))),
                    fF=(-0.2 - 0.3 * s, -0.16 * max(0, -np.cos(k * TAU))),
                    hand=(0.95 - 0.1 * s, -1.4), ca=0.85 - 0.12 * s, farh=(-0.62 + 0.15 * s, -1.4))
    move = cyc(8, step)

    def wind(k):
        e = ease(k)
        return dict(lean=-0.16 * e, squash=0.18 * e, bob=0.05 * e, hand=lerp((0.98, -1.3), (-0.05, -3.55), e),
                    ca=float(lerp(1.0, -2.25, e)), eye=1.0 + 1.6 * e, mouth=0.6 * e, farh=(-0.8, -1.6 - 0.3 * e),
                    fN=(0.55, 0.0), fF=(-0.45, 0.0))
    windup = seq(5, wind)

    def hit(k):
        e = ease(min(1, k * 1.7))
        back = max(0.0, k - 0.6) / 0.4
        return dict(lean=float(lerp(-0.16, 0.26, e) - 0.08 * back), squash=float(lerp(0.18, -0.05, e)),
                    hand=lerp((-0.05, -3.55), (1.55, -1.45), e), ca=float(lerp(-2.25, 0.55, e)),
                    eye=2.0 - back, mouth=0.4, fN=(0.75, 0.0), fF=(-0.5, 0.0), farh=(-0.9, -1.2))
    attack = seq(5, hit)
    hurt = seq(3, lambda k: dict(lean=-0.2 * np.sin(k * np.pi + 0.3), bob=0.03, hand=(0.7, -1.6), ca=1.4,
                                 eye=0.4, mouth=0.5, fN=(0.35, 0.0), fF=(-0.45, 0.0)))

    def die(k):
        e = ease(k)
        f = max(0.0, (k - 0.25) / 0.75)
        return dict(lean=-0.1 * e, squash=0.15 * e, hand=lerp((0.98, -1.3), (0.8, -0.8), e), ca=1.5,
                    eye=max(0.0, 1.0 - 1.4 * k), mouth=0.7 * e, rot=88 * ease(f), pivot=(-0.7, 0.0), rest=True,
                    rest_sink=0.06 * f)
    death = seq(8, die)
    return dict(idle=(idle, 8, True), move=(move, 10, True), windup=(windup, 8, False),
                attack=(attack, 16, False), hurt=(hurt, 12, False), death=(death, 10, False))


# =====================================================================
class Crawler(Body):
    """Трясинник: low heavy drop, heavy front, rust claws, tina from the back."""
    BOUNDS = (-2.4, 2.9, -2.6, 0.4)
    HIDE = hexc('4D5E43')
    MOSS = hexc('5E6E44')
    TINA = hexc('2F4530')
    CLAW = RUST
    BASE = dict(bob=0.0, rear=0.0, crouch=0.0, gait=0.0, stretch=0.0, jaw=0.15, eye=1.0, sway=0.0,
                neck_r=0.3)

    def setup(self):
        p = self.p
        c = p['crouch']
        self.front = np.array([0.45 + 0.15 * p['stretch'], -0.78 + 0.18 * c + p['bob']])
        self.back = np.array([-0.75 - 0.15 * p['stretch'], -0.6 - 0.22 * p['rear'] + p['bob']])
        self.hc = self.front + (0.72 + 0.12 * p['stretch'], 0.12 + 0.12 * c)
        self.neck = self.front + (0.42, -0.02)

    def stump_n(self, key):
        return (1.0, 0.1)

    def layers(self):
        return [(None, self.far_legs), (None, self.body), ('head', self.head), (None, self.near_legs)]

    def paw(self, sh, foot, dim, big):
        cv = self.cv
        d, kn, an = limb(cv, sh, foot, 0.42 if big else 0.36, 0.36, 0.22 if big else 0.18, 0.13, (1, 0.3) if big else (-1, 0.3))
        cv.paint(d, self.HIDE, R=0.18, dim=dim)
        fd = unit((1.0, 0.15))
        cl = fingers(cv, np.asarray(an) + (0.02, 0.04), fd, n=3, ln=0.24, spread=0.7, r=0.04, curl=0.6)
        cv.paint(cl, self.CLAW, R=0.04, line=0.6, dim=dim, cast=False)

    def legs_at(self, g):
        p = self.p
        s = np.sin(g * TAU)
        lift = lambda v: -0.18 * max(0.0, v)  # noqa: E731
        return dict(fF=(self.front[0] + 0.55 + 0.25 * s, lift(np.cos(g * TAU))),
                    bF=(self.back[0] + 0.2 - 0.25 * s, lift(-np.cos(g * TAU))),
                    fN=(self.front[0] + 0.35 - 0.25 * s + 0.1 * p['stretch'], lift(-np.cos(g * TAU))),
                    bN=(self.back[0] + 0.05 + 0.25 * s, lift(np.cos(g * TAU))))

    def far_legs(self):
        L = self.legs_at(self.p['gait'])
        self.paw(self.front + (0.1, 0.1), L['fF'], 0.75, True)
        self.paw(self.back + (0.1, 0.12), L['bF'], 0.75, False)

    def near_legs(self):
        L = self.legs_at(self.p['gait'])
        self.paw(self.back + (0.0, 0.2), L['bN'], 1.0, False)
        self.paw(self.front + (-0.05, 0.25), L['fN'], 1.0, True)

    def body(self):
        cv, p = self.cv, self.p
        d = cv.smin(cv.ellipse(self.front, 1.0, 0.66, rot=-0.08 - 0.12 * p['crouch']),
                    cv.ellipse(self.back, 0.72, 0.48, rot=0.25 * p['rear']), 0.3)
        spots = 1 - 0.12 * (cv.n_mid > 0.12)
        cv.paint(d, self.HIDE, R=0.5, pattern=spots)
        moss = cv.inter(d + 0.04, -(cv.Y - (self.front[1] - 0.2 + (cv.X - self.front[0]) * 0.15)) - 0.0)
        cv.paint(moss, self.MOSS, R=0.25, line=0.5, cast=False,
                 pattern=1 - 0.25 * np.clip(np.sin(cv.X * 30 + cv.n_mid * 20), 0, 1))
        # tina locks from the spine, streaming back in the charge
        roots = [self.back + (x, -0.42 + 0.06 * x) for x in (-0.3, 0.0, 0.3)] + \
                [self.front + (x, -0.62) for x in (-0.5, -0.2, 0.1)]
        sw = -0.35 - 0.9 * p['stretch'] + p['sway']
        self.strands(roots, [0.55, 0.7, 0.6, 0.55, 0.65, 0.45], self.TINA, sway=sw, w=0.06, line=0.5,
                     drip=1.0 - 0.45 * p['stretch'], rotk=True)

    def head(self):
        cv, p = self.cv, self.p
        c = self.hc
        j = p['jaw']
        skull = cv.smin(cv.ellipse(c, 0.46, 0.36, rot=0.1), cv.ellipse(c + (0.3, 0.06), 0.26, 0.2), 0.1)
        jaw = cv.ellipse(c + (0.2, 0.26 + 0.18 * j), 0.36, 0.13, rot=0.3 * j)
        cv.paint(jaw, self.HIDE * 0.9, R=0.12)
        if j > 0.2:
            cv.paint(cv.ellipse(c + (0.28, 0.2 + 0.08 * j), 0.24, 0.07 + 0.08 * j), hexc('3A0F14'), R=0.03,
                     line=0.0, shade=False, rim=False, cast=False, union=False)
        cv.paint(skull, self.HIDE * 1.05, R=0.3)
        tusk = cv.cone(c + (0.36, 0.2), c + (0.48, -0.05 - 0.1 * j), 0.05, 0.015)
        cv.paint(tusk, hexc('D8CFB0'), R=0.03, line=0.5, cast=False)
        e = p['eye']
        self.eyes([c + (0.12, -0.1), c + (0.32, -0.08)], 0.055 + 0.01 * e, RUST * 1.15, glow=e, slit=True, ang=0.2)
        brow = cv.cone(c + (0.0, -0.2), c + (0.42, -0.14), 0.035, 0.02)
        cv.ink(brow, alpha=0.8)


def crawler_anims():
    idle = cyc(8, lambda k: dict(bob=0.04 * np.sin(k * TAU), sway=0.08 * np.sin(k * TAU), jaw=0.15 + 0.08 * np.sin(k * TAU)))
    move = cyc(8, lambda k: dict(gait=k, bob=-0.05 * abs(np.sin(k * TAU)), sway=0.1 * np.sin(k * TAU)))
    windup = seq(5, lambda k: dict(crouch=ease(k), rear=ease(k), jaw=0.15 + 0.85 * ease(k), eye=1 + 1.5 * ease(k),
                                    bob=0.03 * np.sin(k * 9)))
    charge = cyc(6, lambda k: dict(gait=k, stretch=1.0, crouch=0.5, jaw=0.6, eye=2.2, bob=-0.06 * abs(np.sin(k * TAU))))
    attack = seq(5, lambda k: dict(stretch=0.6, jaw=0.9, eye=2.0, crouch=0.2, rot=float(lerp(-8, 18, k)) if k < 0.8 else 10,
                                   pivot=(0.0, -0.6), dy=-0.35 * np.sin(k * np.pi)))
    hurt = seq(3, lambda k: dict(crouch=0.4 * np.sin(k * np.pi), jaw=0.5, eye=0.5, dx=-0.08 * np.sin(k * np.pi)))
    death = seq(8, lambda k: dict(jaw=0.7, eye=max(0.0, 1 - 1.5 * k), gait=0.25 * k, crouch=0.3,
                                  rot=-float(150 * ease(max(0, (k - 0.15) / 0.85))), pivot=(0.2, -0.6), rest=True,
                                  rest_sink=0.05))
    return dict(idle=(idle, 8, True), move=(move, 12, True), windup=(windup, 10, False),
                attack=(attack, 12, False), charge=(charge, 16, True), hurt=(hurt, 12, False), death=(death, 10, False))


# =====================================================================
class Thrower(Body):
    """Упырь-метатель: hunched ghoul, long whip arm to the knees, a tina clod."""
    BOUNDS = (-2.2, 2.9, -4.6, 0.4)
    SKIN = hexc('6A5A4E')
    RAG = hexc('4A3A2C')
    CLOD = hexc('39462E')
    BASE = dict(bob=0.0, hunch=0.0, hand=(0.62, -0.62), farh=(0.1, -1.3), clod=True, eye=1.0, open=0.0,
                fN=(0.4, 0.0), fF=(-0.3, 0.0), jaw=0.2, stump_r=0.14, neck_r=0.17)

    def setup(self):
        p = self.p
        h = p['hunch']
        self.hip = np.array([-0.05, -1.12 + p['bob']])
        self.hump = self.hip + (-0.05 + 0.15 * h, -1.25 + 0.1 * h)
        self.arm_root = self.hip + (0.35 + 0.2 * h, -1.05 + 0.05 * h)
        self.far_sh = self.hip + (-0.1 + 0.2 * h, -1.1)
        self.neck = self.hip + (0.42 + 0.25 * h, -1.25 + 0.1 * h)
        self.hc = self.neck + (0.24, -0.08)

    def stump_n(self, key):
        return (0.7, -0.7) if key == 'arm' else (0.8, -0.6)

    def layers(self):
        return [(None, self.far_arm), (None, self.legs), (None, self.body), ('head', self.head), ('arm', self.whip_arm)]

    def far_arm(self):
        cv, p = self.cv, self.p
        d, el, h = limb(cv, self.far_sh, p['farh'], 0.5, 0.5, 0.12, 0.08, (-1, 0.3))
        cv.paint(d, self.SKIN, R=0.12, dim=0.75)
        cv.paint(fingers(cv, h, unit(np.asarray(h) - el), n=3, ln=0.2, r=0.025, curl=0.5), self.SKIN, R=0.03, dim=0.75,
                 line=0.5, cast=False)

    def legs(self):
        cv, p = self.cv, self.p
        for f, dim, off in ((p['fF'], 0.78, -0.12), (p['fN'], 1.0, 0.12)):
            d, kn, an = limb(cv, self.hip + (off, 0.0), np.asarray(f) + (0, -0.08), 0.62, 0.58, 0.16, 0.09, (1, -0.4))
            foot = fingers(cv, an, unit((1, 0.25)), n=3, ln=0.3, spread=0.4, r=0.04, curl=0.3)
            cv.paint(cv.smin(d, foot, 0.04), self.SKIN, R=0.12, dim=dim)

    def body(self):
        cv = self.cv
        d = cv.smin(cv.cone(self.hip, self.neck, 0.34, 0.24), cv.ellipse(self.hump, 0.5, 0.42, rot=-0.5), 0.2)
        cv.paint(d, self.SKIN, R=0.35)
        for k in (0.2, 0.45, 0.7):  # ribs / spine knobs
            q = lerp(self.hip, self.hump, k) + (-0.22, 0.0)
            cv.paint(cv.circle(q, 0.06), self.SKIN * 1.08, R=0.05, line=0.5, cast=False)
        # rags: a tattered shirt and a loincloth with a ragged hem
        teeth = 0.06 * np.abs(np.sin(cv.X * 22))
        rag = cv.inter(d - 0.03, (cv.Y - (self.hump[1] + 0.25)) * -1)
        rag = cv.inter(rag, cv.Y - (self.hip[1] - 0.25) - teeth)
        loin = cv.inter(cv.ellipse(self.hip + (0.0, 0.18), 0.4, 0.38), (self.hip[1] - 0.05) - cv.Y)
        loin = cv.inter(loin, cv.Y - (self.hip[1] + 0.45 - teeth * 2.0))
        cv.paint(np.minimum(rag, loin), self.RAG, R=0.2, pattern=1 - 0.2 * np.clip(np.sin((cv.X + cv.Y) * 30), 0, 1))
        self.crack([self.hump + (-0.25, 0.1), self.hump + (0.05, 0.3)], 0.012, 0.4)

    def head(self):
        cv, p = self.cv, self.p
        c = self.hc
        skull = cv.smin(cv.ellipse(c, 0.3, 0.27, rot=0.35), cv.ellipse(c + (0.2, 0.12), 0.16, 0.12), 0.06)
        jaw = cv.ellipse(c + (0.14, 0.2 + 0.1 * p['jaw']), 0.17, 0.08, rot=0.4)
        cv.paint(jaw, self.SKIN * 0.9, R=0.08)
        cv.paint(skull, self.SKIN * 1.05, R=0.24)
        ear = cv.cone(c + (-0.18, -0.1), c + (-0.4, -0.3), 0.07, 0.015)
        cv.paint(ear, self.SKIN, R=0.04, line=0.6, cast=False)
        hair = [c + (x, -0.2 + x * 0.3) for x in (-0.2, -0.1, 0.0)]
        self.strands(hair, [0.35, 0.45, 0.3], hexc('2E2820'), sway=-0.15, w=0.025, line=0.35)
        self.eyes([c + (0.1, -0.06), c + (0.25, -0.0)], 0.045, RUST * 1.1, glow=p['eye'])
        cv.ink(cv.path([c + (0.05, 0.15), c + (0.18, 0.2), c + (0.3, 0.16)], 0.012), alpha=0.7)

    def whip_arm(self):
        cv, p = self.cv, self.p
        d, el, h = limb(cv, self.arm_root, p['hand'], 0.78, 0.86, 0.15, 0.08, (-0.6, 0.5))
        d = cv.smin(d, cv.ellipse(self.arm_root, 0.2, 0.17), 0.05)
        cv.paint(d, self.SKIN, R=0.13)
        fd = unit(np.asarray(h) - el)
        if p['clod']:
            cc = np.asarray(h) + fd * 0.14
            cv.paint(cv.circle(cc, 0.2), self.CLOD, R=0.18, pattern=1 - 0.25 * (cv.n_hi > 0.15),
                     glow=(MAG, 0.08, 0.25 * p['open']) if p['open'] > 0 else None)
            for q in ((-0.06, -0.08), (0.08, 0.04)):
                cv.paint(cv.circle(cc + q, 0.025), ROT, R=0.02, line=0, shade=False, rim=False, cast=False, union=False,
                         glow=(ROT, 0.03, 0.3))
            f = fingers(cv, h, fd, n=4, ln=0.3, spread=1.1, r=0.03, curl=0.9)
        else:
            f = fingers(cv, h, fd, n=4, ln=0.34, spread=0.8 + 0.4 * p['open'], r=0.03, curl=0.3 - 0.3 * p['open'])
        cv.paint(f, self.SKIN, R=0.03, line=0.55, cast=False)


def thrower_anims():
    idle = cyc(8, lambda k: dict(bob=0.035 * np.sin(k * TAU), hand=(0.62 + 0.05 * np.sin(k * TAU), -0.62),
                                 farh=(0.1, -1.3 + 0.03 * np.sin(k * TAU))))

    def walk(k):
        s = np.sin(k * TAU)
        return dict(bob=-0.05 * abs(np.cos(k * TAU)), fN=(0.15 + 0.35 * s, -0.14 * max(0, np.cos(k * TAU))),
                    fF=(-0.05 - 0.35 * s, -0.14 * max(0, -np.cos(k * TAU))), hand=(0.6 - 0.25 * s, -0.6),
                    farh=(0.05 + 0.2 * s, -1.3))
    move = cyc(8, walk)
    windup = seq(5, lambda k: dict(hand=lerp((0.62, -0.62), (-0.6, -3.7), ease(k)), hunch=-0.3 * ease(k),
                                    eye=1 + 1.4 * ease(k), open=ease(k), jaw=0.2 + 0.6 * ease(k),
                                    fN=(0.55, 0.0), fF=(-0.45, 0.0), farh=(0.5, -1.6)))
    throw = seq(5, lambda k: dict(hand=lerp((-0.6, -3.7), (1.7, -1.7), ease(min(1, k * 1.6))), clod=k < 0.3,
                                  hunch=float(lerp(-0.3, 0.45, ease(k))), eye=2.0 - k, open=1.0,
                                  fN=(0.6, 0.0), fF=(-0.4, 0.0), farh=(-0.3, -1.1)))
    attack = seq(5, lambda k: dict(hand=lerp((-0.05, -1.75), (1.75, -1.5), ease(max(0, (k - 0.4) / 0.6))),
                                   clod=False, open=1.0, hunch=float(lerp(-0.2, 0.4, ease(k))), eye=1.8,
                                   fN=(0.6 + 0.2 * k, 0.0), fF=(-0.4, 0.0)))
    hurt = seq(3, lambda k: dict(hunch=-0.4 * np.sin(k * np.pi), hand=(0.2, -0.9), eye=0.5, jaw=0.7))
    death = seq(8, lambda k: dict(hunch=0.4 * k, hand=lerp((0.62, -0.62), (0.9, -0.2), k), eye=max(0, 1 - 1.4 * k),
                                  jaw=0.8, rot=-float(80 * ease(max(0, (k - 0.2) / 0.8))), pivot=(0.5, 0.0),
                                  rest=True, rest_sink=0.05))
    return dict(idle=(idle, 8, True), move=(move, 10, True), windup=(windup, 7, False), throw=(throw, 14, False),
                attack=(attack, 12, False), hurt=(hurt, 12, False), death=(death, 10, False))


# =====================================================================
class Bloat(Body):
    """Утопленник: round drowned body, dangling whip arms, magenta slit eyes."""
    BOUNDS = (-2.3, 2.3, -3.4, 1.4)
    SKIN = hexc('5E786A')
    BLOT = hexc('4E6658')
    TINA = hexc('2F4530')
    BASE = dict(swell=1.0, sway=0.0, bob=0.0, eye=1.0, mouth=0.3, burst=0.0, lean=0.0)

    def setup(self):
        self.c = np.array([0.0, -W(28) + self.p['bob']])

    def layers(self):
        return [(None, self.arms), (None, self.body)]

    def arms(self):
        cv, p = self.cv, self.p
        if p['burst'] > 0.4:
            return
        r = 1.0 * p['swell']
        for side, dim in ((-1, 0.75), (1, 1.0)):
            root = self.c + (0.8 * side * r - 0.1 * p['lean'], 0.05 * r)
            sw = p['sway'] * side + (-0.3 * p['lean'])
            pts = [root, root + (0.3 * side + sw * 0.2, 0.35), root + (0.22 * side + sw * 0.5, 0.85),
                   root + (0.38 * side + sw * 0.8, 1.3), root + (0.25 * side + sw * 1.1, 1.75)]
            d = cv.path(pts, 0.1, 0.04)
            d = cv.smin(d, fingers(cv, pts[-1], unit((sw * 0.3 - 0.2 * side, 1)), n=3, ln=0.28, spread=0.7, r=0.022,
                                   curl=0.6 * side), 0.03)
            cv.paint(d, self.SKIN, R=0.08, dim=dim)

    def body(self):
        cv, p = self.cv, self.p
        b = p['burst']
        r = W(28) * p['swell'] * (1 + 0.25 * b)
        c = self.c
        if b > 0.4:
            # flesh scraps and tina flying out, then only the spray
            k = (b - 0.4) / 0.6
            for i in range(9):
                a = i / 9 * TAU + 0.3
                q = c + np.array([np.cos(a), np.sin(a)]) * r * (0.6 + 1.1 * k)
                cv.paint(cv.ellipse(q, 0.16 * (1 - k * 0.6), 0.1 * (1 - k * 0.6), rot=a), self.SKIN if i % 2 else self.TINA,
                         R=0.06, line=0.6, cast=False, alpha=1 - k * 0.7, glow=(MAG, 0.1, 0.35 * (1 - k)))
            ring = np.abs(cv.circle(c, r * (0.5 + 1.0 * k))) - 0.05 * (1 - k)
            cv.paint(ring, MAG, R=0.02, line=0, shade=False, rim=False, cast=False, union=False, alpha=0.6 * (1 - k),
                     glow=(MAG, 0.15, 0.7 * (1 - k)))
            return
        d = cv.smin(cv.ellipse(c, r, r * 0.96), cv.ellipse(c + (0, r * 0.45), r * 0.75, r * 0.55), 0.2)
        blot = 1 - 0.18 * (cv.n_mid > 0.1) - 0.08 * (cv.n_hi > 0.2)
        cv.paint(d, self.SKIN * (1 + 0.08 * (p['swell'] - 1)), R=0.7, pattern=blot)
        if p['swell'] > 1.1 or b > 0:
            vk = (p['swell'] - 1.0) / 0.4
            veins = cv.inter(d + 0.08, np.abs(np.sin(cv.X * 9 + cv.n_mid * 9) * np.cos(cv.Y * 7)) - 0.04)
            cv.paint(veins, MAG * 0.8, R=0.02, line=0, shade=False, rim=False, cast=False, union=False, alpha=0.6 * vk,
                     glow=(MAG, 0.05, 0.25 * vk))
        # rope band of the drowned and tina locks on top
        belly = cv.inter(d + 0.06, cv.ellipse(c + (0.1, r * 0.55), r * 0.7, r * 0.45))
        cv.paint(belly, self.BLOT, R=0.2, line=0, cast=False, rim=False)
        roots = [c + (x * r, -r * 0.9 + abs(x) * r * 0.4) for x in (-0.5, -0.25, 0.0, 0.25, 0.45)]
        self.strands(roots, [0.7, 0.9, 1.0, 0.8, 0.6], self.TINA, sway=-0.2 + p['sway'] * 0.3, w=0.06, line=0.5, rotk=True)
        # puffy face: slit magenta eyes, swollen lips
        f = c + (0.3 * r + 0.1 * p['lean'], -0.1 * r)
        e = p['eye']
        self.eyes([f + (-0.2, -0.1), f + (0.18, -0.12)], 0.075 + 0.03 * (p['swell'] - 1), MAG, glow=e)
        m = cv.ellipse(f + (0.0, 0.3), 0.18, 0.05 + 0.1 * p['mouth'])
        cv.paint(m, hexc('2A1420'), R=0.03, line=0.6, shade=False, rim=False, cast=False, union=False)


def bloat_anims():
    idle = cyc(8, lambda k: dict(bob=0.08 * np.sin(k * TAU), sway=0.25 * np.sin(k * TAU + 0.6), mouth=0.3 + 0.1 * np.sin(k * TAU)))
    move = cyc(8, lambda k: dict(bob=0.06 * np.sin(k * TAU), sway=-0.35 + 0.12 * np.sin(k * TAU), lean=1.0))
    inflate = seq(6, lambda k: dict(swell=1.0 + 0.4 * ease(k), eye=1 + 1.5 * k, mouth=0.3 + 0.6 * k,
                                    sway=0.1 * np.sin(k * 30), dx=0.03 * np.sin(k * 40)))
    explode = seq(4, lambda k: dict(swell=1.4, burst=0.25 + 0.75 * k, eye=2.5))
    hurt = seq(3, lambda k: dict(swell=0.95, sway=0.4 * np.sin(k * np.pi), eye=0.6, mouth=0.8))
    return dict(idle=(idle, 8, True), move=(move, 8, True), windup=(inflate, 7, False), inflate=(inflate, 7, False),
                explode=(explode, 12, False), hurt=(hurt, 12, False), death=(inflate, 17, False))


# =====================================================================
class Shishiga(Body):
    """Шишига: knee-high bog imp, frog hind legs, hummock head with sedge, long fingers."""
    BOUNDS = (-1.6, 2.1, -2.7, 0.3)
    HIDE = hexc('4D5F3A')
    SEDGE = hexc('7D9A7F')
    MOSS = hexc('5A6B40')
    BASE = dict(bob=0.0, squat=0.0, stretch=0.0, hand=(0.6, -0.02), farh=(0.42, -0.02), mouth=0.1, eye=1.0,
                legx=0.0, kick=0.0, hang=0.0, neck_r=0.18)

    def setup(self):
        p = self.p
        s, st, hg = p['squat'], p['stretch'], p['hang']
        self.hip = np.array([-0.2 - 0.25 * st, -0.5 + 0.18 * s + p['bob'] - 0.1 * st - 0.25 * hg])
        self.chest = self.hip + (0.3 + 0.4 * st, -0.32 + 0.12 * s + 0.12 * st - 0.25 * hg)
        self.neck = self.chest + (0.12 + 0.1 * st - 0.08 * hg, -0.18 + 0.06 * s - 0.05 * hg)
        self.hc = self.neck + (0.12 + 0.12 * st, -0.22 + 0.05 * s)
        self.sh = self.chest + (0.1, 0.0)

    def stump_n(self, key):
        return (0.3, -1.0)

    def layers(self):
        return [(None, self.far_limbs), (None, self.body), ('head', self.head), (None, self.near_limbs)]

    def hind(self, dim, off):
        cv, p = self.cv, self.p
        hip = self.hip + (off, 0.0)
        if p['stretch'] > 0.3:
            foot = hip + (-0.85 * p['stretch'], 0.25 + p['kick'] * 0.1)
        elif p['hang'] > 0.3:
            foot = hip + (0.1 + 0.25 * np.sin(p['kick'] * TAU + off * 9), 0.62)
        else:
            foot = np.array([hip[0] - 0.1 + p['legx'], 0.0])
        # frog leg: thick haunch, knee forward, long foot
        knee = hip + unit(foot - hip + (0.55, -0.2)) * 0.42
        d = cv.smin(cv.ellipse(lerp(hip, knee, 0.5), 0.3, 0.2, rot=np.arctan2(*(knee - hip)[::-1])),
                    cv.cone(knee, foot, 0.12, 0.07), 0.06)
        toe = fingers(cv, foot, unit((1, 0.1)) if p['hang'] < 0.3 else unit((0.3, 1)), n=3, ln=0.26, spread=0.6, r=0.03)
        cv.paint(cv.smin(d, toe, 0.03), self.HIDE, R=0.15, dim=dim)

    def fore(self, h, dim):
        cv = self.cv
        d, el, hh = limb(cv, self.sh, h, 0.3, 0.32, 0.08, 0.05, (-1, -0.2))
        fd = unit(np.asarray(hh) - el)
        d = cv.smin(d, fingers(cv, hh, fd, n=4, ln=0.3, spread=0.9, r=0.025, curl=0.5), 0.02)
        cv.paint(d, self.HIDE, R=0.06, dim=dim)

    def far_limbs(self):
        self.hind(0.75, -0.08)
        self.fore(self.p['farh'], 0.75)

    def near_limbs(self):
        self.hind(1.0, 0.08)
        self.fore(self.p['hand'], 1.0)

    def body(self):
        cv = self.cv
        d = cv.smin(cv.ellipse(self.hip, 0.38, 0.3), cv.ellipse(self.chest, 0.28, 0.25), 0.15)
        cv.paint(d, self.HIDE, R=0.25, pattern=1 - 0.15 * (cv.n_mid > 0.15))
        cv.paint(cv.inter(d + 0.05, cv.ellipse(self.chest + (0.08, 0.12), 0.2, 0.15)), self.HIDE * 1.2, R=0.1,
                 line=0, cast=False, rim=False)

    def head(self):
        cv, p = self.cv, self.p
        c = self.hc
        dome = cv.smin(cv.ellipse(c, 0.36, 0.3), cv.ellipse(c + (0.12, 0.12), 0.24, 0.16), 0.08)
        cv.paint(dome, self.MOSS, R=0.25, pattern=1 - 0.25 * np.clip(np.sin(cv.X * 40 + cv.n_mid * 20) * np.sin(cv.Y * 35), 0, 1))
        dd = None
        for i in range(6):
            a = -np.pi / 2 - 0.8 + i * 0.32
            r0 = c + (-0.1 + i * 0.05, -0.24)
            e = r0 + np.array([np.cos(a), np.sin(a)]) * (0.45 + 0.1 * (i % 3))
            di = cv.path([r0, lerp(r0, e, 0.5) + (-0.05, 0), e], 0.03, 0.008)
            dd = di if dd is None else np.minimum(dd, di)
        cv.paint(dd, self.SEDGE, R=0.02, line=0.45, cast=False)
        cv.paint(cv.circle(c + (-0.2, -0.3), 0.025), ROT, R=0.02, line=0, shade=False, rim=False, cast=False, union=False,
                 glow=(ROT, 0.03, 0.4))
        self.eyes([c + (0.1, 0.0), c + (0.28, 0.02)], 0.05, MAG, glow=p['eye'])
        m = cv.ellipse(c + (0.24, 0.17), 0.1, 0.02 + 0.07 * p['mouth'])
        cv.paint(m, hexc('2A1420'), R=0.02, line=0.5, shade=False, rim=False, cast=False, union=False)


def shishiga_anims():
    idle = cyc(8, lambda k: dict(bob=0.025 * np.sin(k * TAU), squat=0.1 + 0.08 * np.sin(k * TAU), mouth=0.1))

    def hop(k):
        up = np.sin(k * np.pi)
        return dict(dy=-0.3 * up, squat=0.3 * (1 - up), legx=-0.2 * up, hand=(0.6, -0.02 - 0.2 * up),
                    farh=(0.45, -0.05 - 0.2 * up))
    move = cyc(8, hop)
    windup = seq(5, lambda k: dict(squat=0.25 + 0.75 * ease(k), mouth=0.2 + 0.8 * ease(k), eye=1 + 1.5 * ease(k),
                                    hand=(0.55, -0.02), dx=0.02 * np.sin(k * 30)))
    attack = seq(5, lambda k: dict(stretch=float(lerp(0.4, 1.0, ease(k))), hand=lerp((0.9, -0.7), (1.35, -0.85), k),
                                   farh=lerp((0.8, -0.5), (1.2, -0.6), k), mouth=0.9, eye=2.0, rot=float(lerp(12, -6, k)),
                                   pivot=(0.0, -0.6), dy=-0.4))
    cling = cyc(6, lambda k: dict(hang=1.0, kick=k, hand=(0.35, -1.55 + 0.04 * np.sin(k * TAU)),
                                  farh=(0.12, -1.5), mouth=0.4 + 0.3 * np.sin(k * TAU), eye=1.3))
    hurt = seq(3, lambda k: dict(squat=0.4 * np.sin(k * np.pi), mouth=1.0, eye=0.4, dx=-0.08 * np.sin(k * np.pi)))
    death = seq(8, lambda k: dict(squat=0.5 * k, mouth=0.9, eye=max(0, 1 - 1.5 * k),
                                  rot=-float(170 * ease(max(0, (k - 0.1) / 0.9))), pivot=(0.0, -0.4), rest=True,
                                  rest_sink=0.03))
    return dict(idle=(idle, 8, True), move=(move, 12, True), windup=(windup, 8, False), attack=(attack, 10, False),
                cling=(cling, 10, True), hurt=(hurt, 12, False), death=(death, 12, False))


# =====================================================================
class Bognitsa(Body):
    """Болотница: wide drop in the bog, tina hair to the water, one whip arm; a hummock disguise."""
    BOUNDS = (-3.0, 5.0, -4.2, 0.7)
    BODY = hexc('3E5A4A')
    HAIR = hexc('24392F')
    MOSS = hexc('4D5F3A')
    SEDGE = hexc('7D9A7F')
    BASE = dict(mode='body', rise=1.0, bob=0.0, sway=0.0, hand=(1.8, -0.55), eye=1.0, mouth=0.1, shake=0.0,
                sink=0.0, bubbles=0.0, stump_r=0.17, neck_r=0.3, splash=0.0, ringk=0.0)

    def setup(self):
        p = self.p
        hh = W(58)
        self.top = -hh + p['bob']
        self.hc = np.array([0.15, self.top + 0.55])
        self.neck = np.array([0.2, self.top + 0.95])
        self.arm_root = np.array([0.8, -0.65 * hh + p['bob']])

    def stump_n(self, key):
        return (1.0, -0.2) if key == 'arm' else (0.0, -1.0)

    def layers(self):
        if self.p['mode'] == 'hummock':
            return [(None, self.hummock)]
        return [(None, self.water), (None, self.body), ('head', self.head), ('arm', self.arm), (None, self.front_hair)]

    def water(self):
        cv, p = self.cv, self.p
        cv.paint(cv.ellipse((0.1, 0.05), 1.9 + 0.3 * p['splash'], 0.2), WATER, R=0.1, line=0.6, cast=False, rim=False,
                 shade=False, union=False)
        water_ring(self.cv, (0.1, 0.05), 1.6 + 0.6 * p['ringk'], 1.0)

    def body(self):
        cv, p = self.cv, self.p
        t = self.top
        d = cv.smin(cv.ellipse((0.05, -0.35), 1.5, 0.55), cv.ellipse((0.05, t * 0.5), 1.15, 0.85), 0.45)
        d = cv.smin(d, cv.ellipse((0.1, t + 0.85), 0.75, 0.45), 0.3)
        d = cv.inter(d, cv.Y - 0.05)
        cv.paint(d, self.BODY, R=0.6, pattern=1 - 0.12 * (cv.n_mid > 0.1))
        roots = [(x, t + 0.85 + 0.25 * abs(x)) for x in np.linspace(-1.1, 1.0, 9)]
        self.strands(roots, [abs(r[1]) * 1.0 for r in roots], self.HAIR, sway=-0.12 + p['sway'], w=0.09, line=0.55,
                     rotk=True)

    def head(self):
        cv, p = self.cv, self.p
        c = self.hc
        dome = cv.smin(cv.ellipse(c, 0.62, 0.5), cv.ellipse(c + (0.2, 0.3), 0.45, 0.3), 0.1)
        cv.paint(dome, self.BODY * 1.08, R=0.4)
        cap = cv.inter(dome - 0.03, cv.Y - (c[1] - 0.08 + 0.25 * np.abs(cv.X - c[0] - 0.25)))
        cv.paint(cap, self.HAIR, R=0.25, line=0.5, cast=False, pattern=1 - 0.2 * np.clip(np.sin(cv.X * 30), 0, 1))
        dd = None
        for i in range(5):
            a = -np.pi / 2 - 0.6 + i * 0.3
            r0 = c + (-0.3 + i * 0.12, -0.4)
            e = r0 + np.array([np.cos(a), np.sin(a)]) * (0.45 + 0.1 * (i % 2))
            di = cv.cone(r0, e, 0.035, 0.01)
            dd = di if dd is None else np.minimum(dd, di)
        cv.paint(dd, self.SEDGE, R=0.02, line=0.45, cast=False)
        self.eyes([c + (0.12, 0.12), c + (0.48, 0.14)], 0.065, MAG, glow=p['eye'])
        m = cv.ellipse(c + (0.33, 0.38), 0.14, 0.02 + 0.08 * p['mouth'])
        cv.paint(m, hexc('1A1418'), R=0.02, line=0.5, shade=False, rim=False, cast=False, union=False)

    def front_hair(self):
        c = self.hc
        roots = [c + (x, 0.2 + 0.15 * abs(x)) for x in (-0.5, -0.32, 0.65)]
        self.strands(roots, [1.4, 1.6, 1.3], self.HAIR, sway=-0.08 + self.p['sway'], w=0.08, line=0.5)

    def arm(self):
        cv, p = self.cv, self.p
        h = np.asarray(p['hand'], float)
        r = self.arm_root
        mid = lerp(r, h, 0.5) + rot(unit(h - r), -np.pi / 2) * 0.25 * min(1.0, np.hypot(*(h - r)) / 3)
        d = cv.path([r, lerp(r, mid, 0.5), mid, lerp(mid, h, 0.5), h], 0.17, 0.07)
        cv.paint(d, self.BODY * 1.1, R=0.12)
        tina = [lerp(r, h, k) + (0, 0.05) for k in (0.15, 0.35, 0.55, 0.75)]
        self.strands(tina, [0.35, 0.3, 0.25, 0.2], self.HAIR, sway=-0.05, w=0.035, line=0.4)
        fd = unit(h - mid)
        cv.paint(fingers(cv, h, fd, n=4, ln=0.36, spread=1.0, r=0.035, curl=0.7), self.BODY * 1.1, R=0.03, line=0.6,
                 cast=False)
        cl = [h + rot(fd, (i - 1.5) * 0.25) * 0.42 for i in range(4)]
        for q in cl:
            cv.paint(cv.circle(q, 0.03), RUST, R=0.02, line=0.4, cast=False, shade=False, rim=False)

    def hummock(self):
        cv, p = self.cv, self.p
        o = np.array([p['shake'], p['sink']])
        hw, hh = W(120) / 2, W(26)
        cv.paint(cv.ellipse(o + (0, 0.1), hw * 1.05, 0.2), WATER, R=0.1, line=0.6, cast=False, rim=False, shade=False,
                 union=False)
        mound = cv.smin(cv.ellipse(o + (0, 0.05), hw * 0.85, hh), cv.ellipse(o + (0.2, -0.1), hw * 0.5, hh * 1.15), 0.2)
        mound = cv.inter(mound, cv.Y - (0.12 + o[1]) * 1.0 - 0.0)
        cv.paint(mound, self.MOSS, R=0.5, pattern=1 - 0.22 * np.clip(np.sin(cv.X * 28 + cv.n_mid * 22) * np.sin(cv.Y * 30), 0, 1))
        dd = None
        for i in range(9):
            x = -hw * 0.6 + i * hw * 0.15
            a = -np.pi / 2 + (x / hw) * 0.9 + 0.12 * np.sin(p['sway'] * TAU + i)
            r0 = o + (x, -hh * 0.85 + abs(x) * 0.25)
            e = r0 + np.array([np.cos(a), np.sin(a)]) * (0.55 + 0.15 * (i % 3))
            di = cv.path([r0, lerp(r0, e, 0.5) + (0.04, 0), e], 0.035, 0.008)
            dd = di if dd is None else np.minimum(dd, di)
        cv.paint(dd, self.SEDGE, R=0.02, line=0.45, cast=False)
        for q in ((-hw * 0.4, -0.55), (hw * 0.45, -0.5)):
            cv.paint(cv.circle(o + q, 0.035), ROT, R=0.02, line=0, shade=False, rim=False, cast=False, union=False,
                     glow=(ROT, 0.04, 0.4))
        self.eyes([o + (-0.38, -0.22), o + (0.38, -0.2)], 0.045, MAG * 0.7, glow=0.5 + p['eye'] * 0.4)
        if p['bubbles'] > 0:
            for i in range(4):
                ph = (p['bubbles'] + i * 0.27) % 1.0
                q = o + (-hw * 0.5 + i * hw * 0.33, -0.1 - ph * 0.9)
                ring = np.abs(cv.circle(q, 0.07 + 0.08 * ph)) - 0.02
                cv.paint(ring, ROT, R=0.02, line=0, shade=False, rim=False, cast=False, union=False, alpha=1 - ph,
                         glow=(ROT, 0.03, 0.25 * (1 - ph)))
        if p['ringk'] > 0:
            water_ring(cv, (0.0, 0.1), hw * (0.8 + 0.5 * p['ringk']), 1 - p['ringk'] * 0.6)


def bognitsa_anims():
    hummock = cyc(4, lambda k: dict(mode='hummock', sway=k, eye=0.5 + 0.5 * np.sin(k * TAU)))
    bubble = cyc(4, lambda k: dict(mode='hummock', sway=k, shake=0.08 * np.sin(k * TAU * 2 + 0.5), bubbles=k, eye=1.5))
    dive = seq(6, lambda k: dict(mode='hummock', sink=1.3 * ease(k), clip=0.1, ringk=k, bubbles=k, eye=1.0))
    surface = seq(6, lambda k: dict(dy=float(lerp(2.5, 0.0, ease(k))), clip=0.12, splash=1 - k, ringk=k, eye=1.5,
                                    hand=(1.2, -0.3), mouth=0.6))
    idle = cyc(8, lambda k: dict(bob=0.04 * np.sin(k * TAU), sway=0.08 * np.sin(k * TAU),
                                 hand=(1.8, -0.55 + 0.06 * np.sin(k * TAU))))
    move = cyc(8, lambda k: dict(bob=0.06 * np.sin(k * TAU * 2), sway=-0.15 + 0.05 * np.sin(k * TAU),
                                 hand=(1.7 + 0.1 * np.sin(k * TAU), -0.45), ringk=(k * 2) % 1))
    windup = seq(5, lambda k: dict(hand=lerp((1.8, -0.55), (0.3, -3.9), ease(k)), eye=1 + 1.5 * ease(k),
                                    mouth=ease(k), sway=0.1 * ease(k)))
    attack = seq(5, lambda k: dict(hand=lerp((0.3, -3.9), (4.5, -1.1), ease(min(1, k * 1.5))), eye=2.0, mouth=0.8,
                                   sway=-0.2 * k))
    hurt = seq(3, lambda k: dict(bob=0.1 * np.sin(k * np.pi), sway=0.25 * np.sin(k * np.pi), hand=(1.3, -0.4), eye=0.5,
                                 mouth=0.9))
    death = seq(8, lambda k: dict(dy=2.6 * ease(max(0, (k - 0.2) / 0.8)), clip=0.12, eye=max(0, 1 - 1.3 * k), mouth=0.9,
                                  hand=lerp((1.8, -0.55), (1.4, -0.1), k), ringk=k, splash=k))
    return dict(hummock=(hummock, 5, True), bubble=(bubble, 10, True), dive=(dive, 9, False), surface=(surface, 10, False),
                idle=(idle, 7, True), move=(move, 9, True), windup=(windup, 8, False), attack=(attack, 14, False),
                hurt=(hurt, 12, False), death=(death, 10, False))


# =====================================================================
class Vodyanitsa(Body):
    """Водяница: tall thin drowned singer, hair to the heels, hem melting into tina."""
    BOUNDS = (-2.2, 2.8, -5.1, 0.4)
    DRESS = hexc('7D9A7F')
    SKIN = hexc('A4B59C')
    HAIR = hexc('24392F')
    TINA = hexc('2F4530')
    RING = ROT
    BASE = dict(bob=0.0, sway=0.0, hand=(0.55, -1.9), farh=(-0.1, -1.85), eye=1.0, mouth=0.0, song=0.0, lean=0.0,
                splash=0.0, stump_r=0.11, neck_r=0.12)

    def setup(self):
        p = self.p
        hh = W(84)
        self.base_y = -0.25 + p['bob']
        self.waist = np.array([0.0 + 0.2 * p['lean'], -hh * 0.5 + p['bob']])
        self.sh = np.array([0.08 + 0.35 * p['lean'], -hh * 0.72 + p['bob']])
        self.arm_root = self.sh + (0.2, 0.02)
        self.far_sh = self.sh + (-0.18, 0.0)
        self.neck = self.sh + (0.04 + 0.08 * p['lean'], -0.22)
        self.hc = self.neck + (0.06 + 0.05 * p['lean'], -0.3 + 0.06 * p['song'])

    def stump_n(self, key):
        return (1.0, -0.3) if key == 'arm' else (0.1, -1.0)

    def layers(self):
        return [('head', self.back_hair), (None, self.far_arm), (None, self.dress), ('head', self.head),
                ('arm', self.near_arm)]

    def back_hair(self):
        c = self.hc
        roots = [c + (x, -0.1 + 0.05 * abs(x)) for x in (-0.3, -0.2, -0.1, 0.0)]
        self.strands(roots, [3.2, 3.4, 3.1, 2.6], self.HAIR, sway=-0.35 + self.p['sway'], w=0.1, line=0.55, rotk=True)

    def dress(self):
        cv, p = self.cv, self.p
        y0 = self.base_y
        d = cv.poly([(-0.6 + p['sway'] * 0.3, y0), (-0.32, self.waist[1]), (self.sh[0] - 0.28, self.sh[1] + 0.05),
                     (self.sh[0] + 0.3, self.sh[1] + 0.05), (0.32 + 0.2 * p['lean'], self.waist[1]),
                     (0.62 + p['sway'] * 0.3, y0)], 0.1)
        folds = 1 - 0.15 * np.clip(np.sin(cv.X * 18 + cv.Y * 1.5 + cv.n_mid * 5), 0, 1)
        cv.paint(d, self.DRESS * 0.92, R=0.35, pattern=folds)
        belt = cv.inter(d - 0.01, np.abs(cv.Y - self.waist[1] - 0.1) - 0.05)
        cv.paint(belt, hexc('5E7A62'), R=0.04, line=0.5, cast=False)
        roots = [(x, y0 - 0.12) for x in np.linspace(-0.55, 0.6, 7)]
        self.strands(roots, [0.4, 0.3, 0.38, 0.32, 0.4, 0.3, 0.36], self.TINA, sway=p['sway'] - 0.1, w=0.07, line=0.5,
                     rotk=True)
        cv.ink(np.abs(cv.ellipse((0.0, 0.05), 1.0 + 0.4 * p['splash'], 0.12)) - 0.02, alpha=0.45)

    def head(self):
        cv, p = self.cv, self.p
        c = self.hc
        face = cv.smin(cv.ellipse(c, 0.27, 0.32, rot=0.1), cv.ellipse(c + (0.12, 0.15), 0.14, 0.14), 0.06)
        cv.paint(face, self.SKIN, R=0.22)
        cap = cv.inter(face - 0.02, cv.Y - (c[1] - 0.1 + 0.4 * np.maximum(0, cv.X - c[0] - 0.05)))
        cv.paint(cap, self.HAIR, R=0.15, line=0.5, cast=False)
        self.strands([c + (0.17, -0.12)], [0.75], self.HAIR, sway=0.04, w=0.06, line=0.4)
        self.eyes([c + (0.06, 0.0), c + (0.21, 0.02)], 0.04, MAG, glow=p['eye'])
        m = cv.ellipse(c + (0.15, 0.2), 0.05 + 0.03 * p['mouth'], 0.015 + 0.06 * p['mouth'])
        cv.paint(m, hexc('1A1418'), R=0.02, line=0.4, shade=False, rim=False, cast=False, union=False)

    def hand_glow(self, h):
        if self.p['song'] > 0:
            self.cv.paint(self.cv.circle(h, 0.06), self.RING, R=0.02, line=0, shade=False, rim=False, cast=False,
                          union=False, glow=(self.RING, 0.12, 0.6 * self.p['song']))

    def far_arm(self):
        cv, p = self.cv, self.p
        d, el, h = limb(cv, self.far_sh, p['farh'], 0.55, 0.6, 0.08, 0.05, (-1, 0.4))
        d = cv.smin(d, fingers(cv, h, unit(np.asarray(h) - el), n=4, ln=0.22, r=0.02, curl=0.4), 0.02)
        cv.paint(d, self.SKIN, R=0.06, dim=0.75)
        self.hand_glow(h)

    def near_arm(self):
        cv, p = self.cv, self.p
        d, el, h = limb(cv, self.arm_root, p['hand'], 0.58, 0.62, 0.09, 0.055, (-1, 0.6))
        sleeve = cv.cone(self.arm_root, el, 0.13, 0.11)
        d = cv.smin(d, fingers(cv, h, unit(np.asarray(h) - el), n=4, ln=0.24, spread=0.8, r=0.022, curl=0.3), 0.02)
        cv.paint(d, self.SKIN, R=0.06)
        cv.paint(sleeve, self.DRESS, R=0.1, line=0.7)
        self.hand_glow(h)
        if p['splash'] > 0:
            fd = unit(np.asarray(h) - el)
            for i in range(7):
                q = np.asarray(h) + rot(fd, (i - 3) * 0.22) * (0.3 + 0.5 * p['splash'] + 0.1 * (i % 2))
                cv.paint(cv.ellipse(q, 0.08, 0.04, rot=np.arctan2(fd[1], fd[0])), hexc('8FB8B0'), R=0.03, line=0.5,
                         cast=False, alpha=1 - 0.4 * p['splash'])


def vodyanitsa_anims():
    idle = cyc(8, lambda k: dict(bob=0.06 * np.sin(k * TAU), sway=0.12 * np.sin(k * TAU),
                                 hand=(0.55, -1.9 + 0.05 * np.sin(k * TAU)), farh=(-0.1, -1.85)))
    move = cyc(8, lambda k: dict(bob=0.05 * np.sin(k * TAU), sway=-0.25 + 0.08 * np.sin(k * TAU), lean=0.25,
                                 hand=(0.65, -2.0), farh=(-0.2, -1.9)))
    song = cyc(8, lambda k: dict(song=0.7 + 0.3 * np.sin(k * TAU), mouth=0.7 + 0.3 * np.sin(k * TAU * 2),
                                 hand=(0.55 + 0.1 * np.sin(k * TAU), -4.45), farh=(-0.45, -4.35 + 0.08 * np.sin(k * TAU)),
                                 eye=1.6, bob=-0.08 + 0.05 * np.sin(k * TAU), sway=0.15 * np.sin(k * TAU)))
    windup = seq(5, lambda k: dict(hand=lerp((0.55, -1.9), (-0.1, -2.6), ease(k)), farh=lerp((-0.1, -1.85), (-0.4, -2.5), ease(k)),
                                    lean=-0.2 * ease(k), eye=1 + 1.4 * ease(k), mouth=0.5 * k))
    attack = seq(5, lambda k: dict(hand=lerp((-0.1, -2.6), (1.45, -2.4), ease(min(1, k * 1.6))),
                                   farh=lerp((-0.4, -2.5), (1.25, -2.3), ease(min(1, k * 1.6))), lean=0.3 * ease(k),
                                   splash=max(0.0, k * 1.6 - 0.6), eye=2.0, mouth=0.6))
    hurt = seq(3, lambda k: dict(lean=-0.35 * np.sin(k * np.pi), sway=0.3 * np.sin(k * np.pi), hand=(0.4, -2.3), eye=0.5,
                                 mouth=1.0))
    death = seq(8, lambda k: dict(dy=3.3 * ease(max(0, (k - 0.15) / 0.85)), clip=0.05, sway=0.4 * k, lean=-0.3 * k,
                                  eye=max(0, 1 - 1.3 * k), mouth=1.0, hand=lerp((0.55, -1.9), (0.3, -3.6), k),
                                  farh=lerp((-0.1, -1.85), (-0.3, -3.5), k), splash=k))
    return dict(idle=(idle, 7, True), move=(move, 8, True), song=(song, 9, True), windup=(windup, 9, False),
                attack=(attack, 14, False), hurt=(hurt, 12, False), death=(death, 10, False))


# kind id -> (class, anims, severable parts, anims that get one-armed / headless frames)
LIVE = ['idle', 'move', 'windup', 'attack', 'hurt']
KINDS = {
    'balvan': (Balvan, balvan_anims, ['arm', 'head'], LIVE),
    'crawler': (Crawler, crawler_anims, ['head'], []),
    'thrower': (Thrower, thrower_anims, ['arm', 'head'], LIVE + ['throw']),
    'bloat': (Bloat, bloat_anims, [], []),
    'shishiga': (Shishiga, shishiga_anims, ['head'], LIVE + ['cling']),
    'bognitsa': (Bognitsa, bognitsa_anims, ['arm', 'head'], LIVE),
    'vodyanitsa': (Vodyanitsa, vodyanitsa_anims, ['arm', 'head'], LIVE + ['song']),
}

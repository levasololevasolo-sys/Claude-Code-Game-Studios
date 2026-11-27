"""The six Тёмный бор enemies (bestiary §3.3), one rig + pose set each.

Same renderer and rules as kinds.py (the Swamp): sdf2d ink-and-paint, sizes
after the enemies.json hit boxes (base.W converts world px), the enemy faces +x.
Forest shape language (bestiary §3.3): tall thin verticals, broken joints,
long branch arms; accent the Likho eye #FF8A3D (art bible §4.2).

Readability in the dark forest: ForestBody adds a cool moonlight back rim
(MOON, upper-left edge) on top of the warm paint rim (right edge), and the
base colours are lifted one step above the enemies.json debug colours.
Extra pose keys of ForestBody: dissolve (0..1, the body breaks up into
noise, bottom first: Аука vanishing / appearing). Layers tagged 'fx' are
painted after the outline and the dissolve (particles, sparks, dirt).
"""
import numpy as np

from base import Body, W, hexc, ik, rot, lerp, ease, unit, RUST, MAG, INK  # noqa: F401
from kinds import limb, fingers, cyc, seq

TAU = 2 * np.pi
EYE = hexc('FF8A3D')      # глаз Лиха, the forest accent
MOON = hexc('A9C2EA')     # cool back rim (forest sky #2E4466 lifted)
SPARK = hexc('FFB35C')


def leaf(cv, c, ln, wd, ang):
    """A pointed leaf SDF along angle ang."""
    d = np.array([np.cos(ang), np.sin(ang)])
    return cv.smin(cv.cone(np.asarray(c) - d * ln * 0.5, np.asarray(c) + d * ln * 0.1, wd * 0.25, wd),
                   cv.cone(np.asarray(c) + d * ln * 0.1, np.asarray(c) + d * ln * 0.5, wd, 0.005), 0.03)


def twigs(cv, root, ang, ln, r, depth=2, spread=0.55, seed=0):
    """Branching twig SDF from root at angle ang."""
    e = np.asarray(root) + np.array([np.cos(ang), np.sin(ang)]) * ln
    d = cv.cone(root, e, r, r * 0.5)
    if depth > 0:
        s = 1 if seed % 2 == 0 else -1
        d = np.minimum(d, twigs(cv, e, ang + spread * s, ln * 0.6, r * 0.55, depth - 1, spread, seed + 1))
        mid = lerp(root, e, 0.55)
        d = np.minimum(d, cv.cone(mid, mid + np.array([np.cos(ang - spread * s * 1.2), np.sin(ang - spread * s * 1.2)]) * ln * 0.4,
                                  r * 0.6, r * 0.25))
    return d


def clods(cv, c, k, n=7, spread=1.2, col=None, size=0.09, up=1.6, seed=3):
    """Dirt clods / chips flying up from c, phase k (0..1)."""
    rng = np.random.default_rng(seed)
    d = None
    for i in range(n):
        vx = (rng.random() - 0.5) * 2 * spread
        vy = -up * (0.6 + 0.6 * rng.random())
        q = np.asarray(c) + (vx * k, vy * k + 2.2 * k * k)
        s = size * (0.6 + 0.8 * rng.random()) * (1 - 0.4 * k)
        di = cv.ellipse(q, s, s * 0.7, rot=rng.random() * 3)
        d = di if d is None else np.minimum(d, di)
    return d


class ForestBody(Body):
    """Body with the moonlight back rim, a noise dissolve and 'fx' layers."""
    MOON_K = 0.65

    def moon_rim(self):
        cv = self.cv
        d = cv.union
        if d.min() > 0:
            return
        gy, gx = np.gradient(d, 1.0 / cv.S)
        gn = np.hypot(gx, gy) + 1e-6
        gx, gy = gx / gn, gy / gn
        band = np.clip(1 - (-d) / 0.075, 0, 1) * (d < 0) * (cv.a > 0.5)
        k = np.clip(-gx * 0.75 - gy * 0.6 - 0.1, 0, 1) * band
        cv.rgb = np.clip(cv.rgb + k[..., None] * MOON * self.MOON_K, 0, 1)

    def build(self):
        m = self.mode
        cv = self.cv
        fx = []
        for tag, fn in self.layers():
            if tag == 'fx':
                fx.append(fn)
                continue
            if m in ('arm', 'head'):
                if tag == m:
                    fn()
                continue
            if tag == 'arm' and m in ('noarm', 'noboth'):
                continue
            if tag == 'head' and m in ('nohead', 'noboth'):
                continue
            fn()
        if m in ('noarm', 'noboth') and hasattr(self, self.ARM_ROOT):
            self.stump(getattr(self, self.ARM_ROOT), self.stump_n('arm'), self.p.get('stump_r', 0.16))
        if m in ('nohead', 'noboth') and hasattr(self, self.NECK):
            self.stump(getattr(self, self.NECK), self.stump_n('head'), self.p.get('neck_r', 0.2))
        self.moon_rim()
        cv.outer_outline(self.OUTLINE)
        k = self.p.get('dissolve', 0.0)
        if k > 0:
            y0, y1 = self.BOUNDS[2], self.BOUNDS[3]
            yy = (cv.Y - y0) / (y1 - y0)
            nz = cv.n_mid + 0.5 * cv.n_hi + 0.5
            mask = np.clip((nz + (1 - yy) * 0.6 - k * 1.75) * 7, 0, 1)
            cv.a *= mask
            cv.glow *= mask[..., None]
        if m not in ('arm', 'head'):
            for fn in fx:
                fn()
        return cv


# =====================================================================
class Ringer(ForestBody):
    """Аука: tall thin forest voice, one long branch arm, hollow head with a rust eye."""
    BOUNDS = (-2.6, 3.4, -4.2, 0.4)
    BODY = hexc('5C7658')
    RAG = hexc('3E5640')
    BARK = hexc('76604A')
    HOLLOW = hexc('1A0F12')
    BASE = dict(bob=0.0, lean=0.0, hand=(1.05, -1.05), farh=(-0.3, -1.25), fN=(0.32, 0.0), fF=(-0.3, 0.0), eye=1.0,
                call=0.0, sway=0.0, wisps=0.0, stump_r=0.1, neck_r=0.15)

    def setup(self):
        p = self.p
        lean = p['lean']
        self.hip = np.array([0.0, -1.3 + p['bob']])
        self.chest = self.hip + (0.2 + lean * 0.9, -1.0)
        self.neck = self.hip + (0.34 + lean * 1.4, -1.32)
        self.hc = self.neck + (0.16 + lean * 0.35, -0.48)
        self.arm_root = self.chest + (0.12, -0.08)
        self.far_sh = self.chest + (-0.16, 0.0)

    def stump_n(self, key):
        return (0.8, -0.6) if key == 'arm' else (0.3, -1.0)

    def layers(self):
        return [(None, self.far_arm), (None, self.legs), (None, self.body), ('head', self.head), ('arm', self.arm),
                ('fx', self.wisps)]

    def far_arm(self):
        cv, p = self.cv, self.p
        d, el, h = limb(cv, self.far_sh, p['farh'], 0.55, 0.5, 0.08, 0.05, (-1, 0.3))
        d = np.minimum(d, fingers(cv, h, unit(np.asarray(h) - el), n=3, ln=0.25, spread=0.8, r=0.025, curl=0.4))
        cv.paint(d, self.BARK, R=0.08, dim=0.72)

    def legs(self):
        cv, p = self.cv, self.p
        for f, dim, off in ((p['fF'], 0.75, -0.1), (p['fN'], 1.0, 0.1)):
            d, kn, an = limb(cv, self.hip + (off, 0.0), np.asarray(f) + (0, -0.08), 0.7, 0.66, 0.12, 0.06, (1, -0.25))
            d = np.minimum(d, fingers(cv, an, unit((1, 0.35)), n=3, ln=0.34, spread=1.1, r=0.03, curl=0.3))
            cv.paint(d, self.BARK, R=0.1, dim=dim)

    def body(self):
        cv, p = self.cv, self.p
        d = cv.smin(cv.cone(self.hip, self.chest, 0.24, 0.2), cv.ellipse(self.chest + (0, -0.04), 0.3, 0.22), 0.12)
        d = cv.smin(d, cv.cone(self.chest, self.neck, 0.17, 0.11), 0.08)
        d = cv.smin(d, cv.ellipse(self.hip + (0, 0.02), 0.26, 0.16), 0.08)
        grain = 1 - 0.16 * np.clip(np.sin(cv.X * 38 + cv.n_mid * 12), 0, 1)
        cv.paint(d, self.BODY, R=0.25, pattern=grain)
        # lichen rags hanging from the shoulders and the hips
        roots = [self.chest + (x, -0.12 + 0.1 * abs(x)) for x in (-0.28, -0.14, 0.0, 0.14)] + \
                [self.hip + (x, 0.05) for x in (-0.22, -0.05, 0.12)]
        self.strands(roots, [0.7, 0.85, 0.6, 0.5, 0.55, 0.7, 0.45], self.RAG, sway=-0.12 + p['sway'], w=0.05, line=0.5)

    def head(self):
        cv, p = self.cv, self.p
        c = self.hc
        d = cv.smin(cv.ellipse(c, 0.42, 0.56, rot=0.35), cv.ellipse(c + (-0.14, -0.38), 0.24, 0.22), 0.1)
        cv.paint(d, self.BARK * 1.08, R=0.3, pattern=1 - 0.14 * np.clip(np.sin((cv.X + cv.Y * 0.4) * 34 + cv.n_mid * 9), 0, 1))
        moss = cv.inter(d + 0.02, cv.ellipse(c + (-0.2, -0.42), 0.3, 0.18))
        cv.paint(moss, self.BODY * 1.1, R=0.12, line=0.5, cast=False, pattern=1 - 0.25 * (cv.n_hi > 0.15))
        tw = np.minimum(twigs(cv, c + (-0.2, -0.45), -2.0, 0.42, 0.035, 1, seed=1),
                        twigs(cv, c + (-0.02, -0.44), -1.35, 0.32, 0.03, 1, seed=2))
        cv.paint(tw, self.BARK, R=0.03, line=0.5, cast=False)
        # the hollow (дупло) with one burning eye; the «ау» O glows under it
        lip = cv.ellipse(c + (0.17, 0.02), 0.25, 0.33, rot=0.3)
        cv.paint(lip, self.BARK * 1.35, R=0.08, line=0.5, cast=False, union=False)
        hol = cv.ellipse(c + (0.18, 0.02), 0.18, 0.26, rot=0.3)
        cv.paint(hol, self.HOLLOW, R=0.05, line=0.6, shade=False, rim=False, cast=False, union=False)
        e = p['eye']
        self.eyes([c + (0.2, -0.07)], 0.075 + 0.012 * e, EYE, glow=e)
        ck = p['call']
        if ck > 0:
            o = cv.ellipse(c + (0.22, 0.16), 0.04 + 0.04 * ck, 0.035 + 0.075 * ck)
            cv.paint(o, EYE * 1.1, R=0.02, line=0.5, shade=False, rim=False, cast=False, union=False,
                     glow=(EYE, 0.05 + 0.06 * ck, 0.6 * ck))

    def arm(self):
        cv, p = self.cv, self.p
        d, el, h = limb(cv, self.arm_root, p['hand'], 0.95, 0.95, 0.09, 0.055, (0.3, 1))
        d = cv.smin(d, cv.circle(self.arm_root, 0.12), 0.04)
        fd = unit(np.asarray(h) - el)
        cl = fingers(cv, h, fd, n=3, ln=0.46, spread=0.95, r=0.03, curl=0.55)
        cv.paint(np.minimum(d, cl), self.BARK * 1.05, R=0.08)
        lf = leaf(cv, lerp(self.arm_root, el, 0.6) + (0.0, -0.1), 0.26, 0.07, -1.0)
        cv.paint(lf, self.BODY * 1.15, R=0.04, line=0.5, cast=False)
        tips = [np.asarray(h) + rot(fd, (i - 1) * 0.48) * 0.47 for i in range(3)]
        for q in tips:
            cv.paint(cv.circle(q, 0.025), RUST * 1.2, R=0.02, line=0.3, cast=False, shade=False, rim=False)

    def wisps(self):
        """Leaves and grey wisps swirling up as it melts away / gathers."""
        cv, p = self.cv, self.p
        k = p['wisps']
        if k <= 0:
            return
        for i in range(8):
            a = i * 0.79 + k * 4.0
            q = np.array([0.25 + np.cos(a) * (0.5 + 0.3 * k), -1.0 - 2.4 * ((i / 8 + k * 0.6) % 1.0)])
            lf = leaf(cv, q, 0.2, 0.06, a)
            cv.paint(lf, (self.BODY if i % 2 else self.BARK) * 1.2, R=0.03, line=0.5, cast=False, union=False,
                     alpha=np.sin(np.pi * min(1, k * 1.2)), glow=(EYE, 0.03, 0.12 * k))


def ringer_anims():
    idle = cyc(8, lambda k: dict(bob=0.035 * np.sin(k * TAU), lean=0.03 * np.sin(k * TAU), sway=0.1 * np.sin(k * TAU),
                                 hand=(1.05 + 0.05 * np.cos(k * TAU), -1.05 + 0.07 * np.sin(k * TAU)),
                                 farh=(-0.3, -1.25 + 0.05 * np.sin(k * TAU)), eye=1.0 + 0.2 * np.sin(k * TAU * 2)))

    def step(k):
        s = np.sin(k * TAU)
        return dict(bob=-0.06 * abs(np.cos(k * TAU)), lean=0.14, sway=-0.2,
                    fN=(0.3 + 0.38 * s, -0.18 * max(0, np.cos(k * TAU))),
                    fF=(-0.25 - 0.38 * s, -0.18 * max(0, -np.cos(k * TAU))),
                    hand=(1.15 - 0.15 * s, -0.95), farh=(-0.35 + 0.2 * s, -1.3))
    move = cyc(8, step)
    call = seq(6, lambda k: dict(lean=-0.12 * ease(k), hand=lerp((1.05, -1.05), (1.0, -2.75), ease(k)), call=ease(k),
                                 eye=1.0 + 1.2 * ease(k), sway=0.08 * np.sin(k * 14), farh=(-0.45, -1.45)))
    vanish = seq(6, lambda k: dict(hand=(1.0, -2.75), call=1 - k, lean=-0.12 + 0.1 * k, dissolve=0.12 + 0.88 * ease(k),
                                   wisps=k, eye=2.2 - k, bob=0.1 * k))

    def raised(k, pre=0.0):
        e = ease(k)
        return dict(lean=float(lerp(0.1, -0.16, e)), hand=lerp((1.0, -1.2), (-0.7, -3.55), e), eye=1.2 + 1.2 * e,
                    farh=(-0.1, -1.6), fN=(0.55, 0.0), fF=(-0.4, 0.0), bob=0.08 * e, sway=0.15 * e)
    appear = seq(6, lambda k: dict(raised(k), dissolve=float(max(0.0, 1.0 - k * 1.35)), wisps=1 - k))
    windup = seq(4, raised)

    def hit(k):
        e = ease(min(1, k * 1.6))
        return dict(lean=float(lerp(-0.16, 0.32, e)), hand=lerp((-0.7, -3.55), (2.35, -0.75), e), eye=2.2 - k,
                    fN=(0.8, 0.0), fF=(-0.45, 0.0), farh=(-0.6, -1.0), sway=-0.3 * e)
    attack = seq(5, hit)
    hurt = seq(3, lambda k: dict(lean=-0.22 * np.sin(k * np.pi + 0.3), hand=(0.7, -1.6), eye=0.4, sway=0.3,
                                 fN=(0.3, 0.0), fF=(-0.4, 0.0)))

    def die(k):
        e = ease(k)
        f = max(0.0, (k - 0.2) / 0.8)
        return dict(lean=-0.1 * e, hand=lerp((1.05, -1.05), (0.7, -0.6), e), eye=max(0.0, 1 - 1.4 * k),
                    rot=84 * ease(f), pivot=(-0.5, 0.0), rest=True, rest_sink=0.04,
                    dissolve=float(max(0.0, (k - 0.7) / 0.3) * 0.45), wisps=float(max(0.0, (k - 0.6) / 0.4)))
    death = seq(8, die)
    return dict(idle=(idle, 7, True), move=(move, 10, True), call=(call, 9, False), vanish=(vanish, 14, False),
                appear=(appear, 12, False), windup=(windup, 9, False), attack=(attack, 18, False),
                hurt=(hurt, 12, False), death=(death, 10, False))


# =====================================================================
class Rootling(ForestBody):
    """Лешачонок: a stump-child on root legs, twig horns, moss cap, green eyes."""
    BOUNDS = (-2.0, 2.1, -3.0, 0.5)
    BARK = hexc('7C6046')
    WOOD = hexc('B8925E')
    MOSS = hexc('6E9040')
    TWIG = hexc('927658')
    DIRT = hexc('5E4A36')
    GLOW = hexc('C8F07A')
    BASE = dict(mode='body', bob=0.0, squash=0.0, gait=0.0, eye=1.0, jaw=0.0, lean=0.0, hands=0.0, mound=0.0,
                crack=0.0, shake=0.0, spray=0.0, horns=0.0, stump_r=0.1, neck_r=0.5)

    def setup(self):
        p = self.p
        s = p['squash']
        self.base = np.array([p['shake'], -0.22 + p['bob']])
        self.top = self.base + (0.05 + p['lean'] * 0.5, -1.25 * (1 - 0.15 * s))
        self.neck = self.base + (0.02 + p['lean'] * 0.3, -0.72 * (1 - 0.15 * s))

    def stump_n(self, key):
        return (0.0, -1.0)

    def layers(self):
        if self.p['mode'] == 'mound':
            return [(None, self.mound), ('fx', self.spray)]
        return [(None, self.far_legs), (None, self.trunk), ('head', self.head), (None, self.near_legs),
                (None, self.arms), ('fx', self.spray)]

    def legs_at(self, g):
        s, c = np.sin(g * TAU), np.cos(g * TAU)
        return [(-0.35 - 0.22 * s, -0.14 * max(0, c)), (0.45 + 0.22 * s, -0.14 * max(0, -c)),
                (0.05 + 0.2 * s, -0.12 * max(0, -c))]

    def root_leg(self, hip, foot, dim):
        cv = self.cv
        d = cv.path([hip, lerp(hip, foot, 0.5) + (0.08, 0.0), foot], 0.16, 0.06)
        d = np.minimum(d, fingers(cv, foot, unit((1, 0.4)), n=3, ln=0.22, spread=1.2, r=0.03, curl=0.2))
        cv.paint(d, self.BARK, R=0.1, dim=dim)

    def far_legs(self):
        L = self.legs_at(self.p['gait'])
        self.root_leg(self.base + (-0.25, -0.1), L[0], 0.72)

    def near_legs(self):
        L = self.legs_at(self.p['gait'])
        self.root_leg(self.base + (0.3, -0.05), L[1], 1.0)
        self.root_leg(self.base + (0.0, 0.0), L[2], 0.88)

    def trunk(self):
        cv = self.cv
        b, n = self.base, self.neck
        d = cv.poly([b + (-0.62, 0.05), n + (-0.55, 0.0), n + (0.58, 0.0), b + (0.66, 0.05)], 0.1)
        d = cv.smin(d, cv.ellipse(b + (0.02, -0.02), 0.7, 0.2), 0.1)
        bark = 1 - 0.2 * np.clip(np.sin(cv.X * 26 + cv.n_mid * 10 + cv.Y * 2), 0, 1)
        cv.paint(d, self.BARK, R=0.35, pattern=bark)
        cv.paint(cv.inter(d + 0.03, cv.ellipse(b + (-0.3, -0.25), 0.18, 0.12)), self.MOSS * 0.9, R=0.08, line=0.4,
                 cast=False, pattern=1 - 0.3 * (cv.n_hi > 0.1))

    def head(self):
        cv, p = self.cv, self.p
        n, t = self.neck, self.top
        d = cv.poly([n + (-0.58, 0.06), t + (-0.56, 0.0), t + (0.56, 0.06), n + (0.6, 0.06)], 0.1)
        d = cv.smin(d, cv.ellipse(t + (0.0, 0.02), 0.6, 0.15), 0.06)
        bark = 1 - 0.2 * np.clip(np.sin(cv.X * 26 + cv.n_mid * 10 + cv.Y * 2), 0, 1)
        cv.paint(d, self.BARK * 1.05, R=0.35, pattern=bark)
        # the sawn top with rings under a moss cap
        top = cv.ellipse(t + (0.0, 0.02), 0.52, 0.12)
        rings = 1 - 0.25 * np.clip(np.sin(np.hypot((cv.X - t[0]) / 1.0, (cv.Y - t[1]) * 4) * 60), 0, 1)
        cv.paint(top, self.WOOD, R=0.06, line=0.5, cast=False, shade=False, pattern=rings)
        moss = cv.smin(cv.ellipse(t + (-0.12, -0.05), 0.4, 0.16), cv.ellipse(t + (0.2, -0.02), 0.25, 0.12), 0.08)
        cv.paint(moss, self.MOSS, R=0.1, line=0.5, cast=False, pattern=1 - 0.3 * (cv.n_hi > 0.12))
        # twig horns
        tw = np.minimum(twigs(cv, t + (-0.32, -0.08), -2.0, 0.55, 0.06, 2, seed=1),
                        twigs(cv, t + (0.3, -0.06), -1.2, 0.62, 0.065, 2, seed=2))
        cv.paint(tw, self.TWIG, R=0.04, line=0.55)
        # face: deep eye knots, a bark mouth
        f = n + (0.32, -0.3)
        for q in (f + (-0.2, 0.0), f + (0.1, 0.02)):
            cv.paint(cv.ellipse(q, 0.1, 0.08), INK * 1.4, R=0.02, line=0, shade=False, rim=False, cast=False, union=False)
        self.eyes([f + (-0.19, 0.0), f + (0.11, 0.02)], 0.055 + 0.012 * p['eye'], self.GLOW, glow=p['eye'])
        m = cv.ellipse(f + (-0.02, 0.22), 0.16, 0.025 + 0.07 * p['jaw'])
        cv.paint(m, hexc('1A1012'), R=0.02, line=0.5, shade=False, rim=False, cast=False, union=False)

    def arms(self):
        cv, p = self.cv, self.p
        for side, dim in ((-1, 0.8), (1, 1.0)):
            sh = self.neck + (0.5 * side, 0.2)
            hk = p['hands']
            h = sh + (0.32 * side, 0.4 - 0.9 * hk)
            d = cv.path([sh, lerp(sh, h, 0.5) + (0.08 * side, 0.0), h], 0.07, 0.04)
            d = np.minimum(d, fingers(cv, h, unit(np.asarray(h) - sh), n=3, ln=0.18, spread=1.0, r=0.022, curl=0.4))
            cv.paint(d, self.TWIG, R=0.05, dim=dim, line=0.5)

    def mound(self):
        cv, p = self.cv, self.p
        o = np.array([p['shake'], 0.0])
        m = p['mound']
        hw, hh = W(56) / 2, 0.22 + 0.4 * m
        d = cv.smin(cv.ellipse(o + (0, 0.05), hw, hh), cv.ellipse(o + (0.15, -0.02), hw * 0.55, hh * 1.1), 0.15)
        d = cv.inter(d, cv.Y - 0.08)
        cv.paint(d, self.DIRT, R=0.3, pattern=1 - 0.2 * (cv.n_mid > 0.08) - 0.1 * (cv.n_hi > 0.2))
        for i in range(5):
            q = o + (-hw * 0.7 + i * hw * 0.35, -hh * (0.55 + 0.25 * np.sin(i * 2.3)) * 0.9)
            cv.paint(cv.ellipse(q, 0.08, 0.06, rot=i), self.DIRT * 1.3, R=0.04, line=0.45, cast=False, union=False)
        if p['crack'] > 0:
            k = p['crack']
            cr = None
            for a in (-2.4, -1.6, -0.9):
                q0 = o + (0.0, -hh * 0.6)
                q1 = q0 + np.array([np.cos(a), np.sin(a) * 0.6]) * hw * 0.75
                di = cv.path([q0, lerp(q0, q1, 0.5) + (0.05, -0.04), q1], 0.03, 0.01)
                cr = di if cr is None else np.minimum(cr, di)
            cv.paint(cv.inter(cr, d), self.GLOW, R=0.02, line=0, shade=False, rim=False, cast=False, union=False,
                     glow=(self.GLOW, 0.05, 0.5 * k), alpha=min(1.0, k * 1.5))
        if p['horns'] > 0:
            hk = p['horns']
            tw = np.minimum(twigs(cv, o + (-0.25, -hh + 0.2 - 0.5 * hk), -2.0, 0.4 * hk + 0.05, 0.05, 1, seed=1),
                            twigs(cv, o + (0.25, -hh + 0.2 - 0.5 * hk), -1.2, 0.45 * hk + 0.05, 0.055, 1, seed=2))
            cv.paint(cv.inter(tw, -(cv.Y - (-hh * 0.6 + 0.12))), self.TWIG, R=0.04, line=0.55)

    def spray(self):
        cv, p = self.cv, self.p
        k = p['spray']
        if k <= 0:
            return
        d = clods(cv, (p['shake'], -0.1), k, n=9, spread=1.4, size=0.1, up=1.9)
        cv.paint(d, self.DIRT * 1.15, R=0.05, line=0.6, cast=False, union=False, alpha=float(1 - max(0, k - 0.7) / 0.3))


def rootling_anims():
    idle = cyc(6, lambda k: dict(bob=0.03 * np.sin(k * TAU), squash=0.05 * np.sin(k * TAU), hands=0.1 + 0.08 * np.sin(k * TAU),
                                 eye=1.0 + 0.2 * np.sin(k * TAU)))
    move = cyc(8, lambda k: dict(gait=k, bob=-0.06 * abs(np.sin(k * TAU)), lean=0.08, hands=0.2 + 0.15 * np.sin(k * TAU)))
    burrow = seq(6, lambda k: dict(dy=2.9 * ease(k), clip=0.02, shake=0.06 * np.sin(k * 40), squash=0.2, spray=k * 0.95,
                                   eye=1.4, hands=0.9))
    under = cyc(4, lambda k: dict(mode='mound', mound=0.15, shake=0.05 * np.sin(k * TAU * 2), spray=0.0))
    rise = seq(5, lambda k: dict(mode='mound', mound=0.15 + 0.85 * ease(k), crack=ease(k), horns=ease(k),
                                 shake=0.06 * np.sin(k * 33)))
    emerge = seq(5, lambda k: dict(dy=float(lerp(0.9, -0.15, ease(min(1, k * 2)))), clip=0.06 if k < 0.5 else None,
                                   spray=0.25 + 0.75 * k, hands=1.0, jaw=1.0, eye=2.2, squash=-0.15))
    hurt = seq(3, lambda k: dict(squash=0.2 * np.sin(k * np.pi), lean=-0.15 * np.sin(k * np.pi), eye=0.4, jaw=0.6))

    def die(k):
        f = ease(max(0.0, (k - 0.15) / 0.85))
        return dict(eye=max(0.0, 1 - 1.5 * k), jaw=0.8, hands=0.6, rot=-82 * f, pivot=(0.6, 0.0), rest=True,
                    rest_sink=0.05)
    death = seq(8, die)
    return dict(idle=(idle, 7, True), move=(move, 12, True), burrow=(burrow, 12, False), under=(under, 10, True),
                windup=(rise, 9, False), attack=(emerge, 16, False), hurt=(hurt, 12, False), death=(death, 10, False))


# =====================================================================
class Bat(ForestBody):
    """Нетопырь: small furry body, wide ragged wings, twig ears, magenta eyes."""
    BOUNDS = (-2.9, 2.9, -2.9, 1.3)
    BODY = hexc('5E4C74')
    WING = hexc('4C3D63')
    BONE = hexc('7A6690')
    TWIG = hexc('7A6248')
    BASE = dict(bob=0.0, flap=0.3, fold=0.0, mouth=0.1, eye=1.0, head=0.0, glob=0.0)

    def setup(self):
        p = self.p
        self.c = np.array([0.0, -W(15) + p['bob']])
        self.hc = self.c + (0.2 + 0.15 * p['head'], -0.45)

    def layers(self):
        return [(None, lambda: self.wing(-1, 0.7)), (None, self.body), (None, lambda: self.wing(1, 1.0)),
                (None, self.head), ('fx', self.spit)]

    def wing(self, side, dim):
        cv, p = self.cv, self.p
        fold = p['fold']
        a = p['flap'] + (0.15 if side < 0 else 0.0)
        sh = self.c + (0.2 * side, -0.15)
        span = 1.05 * (1 - 0.55 * fold)
        wr = sh + np.array([side * np.cos(a), -np.sin(a)]) * span
        base = unit(wr - sh)
        tips = []
        for i, ln in enumerate((1.15, 1.0, 0.75)):
            ang = side * (0.45 + 0.6 * i) + side * 0.5 * fold
            tips.append(wr + rot(base, ang) * ln * (1 - 0.45 * fold))
        foot = self.c + (0.1 * side, 0.35)
        poly = [sh, wr] + tips + [foot]
        d = cv.poly(poly, 0.02)
        # ragged trailing edge: bites between the finger tips
        for q0, q1 in ((tips[0], tips[1]), (tips[1], tips[2]), (tips[2], foot)):
            mid = lerp(q0, q1, 0.5)
            out = unit(mid - lerp(sh, wr, 0.5))
            d = cv.sub(d, cv.circle(mid + out * 0.18, 0.22))
        d = cv.sub(d, cv.circle(lerp(tips[0], tips[1], 0.3) + (0, 0.05), 0.06))
        veins = 1 - 0.18 * np.clip(np.sin((cv.X * 0.5 - cv.Y) * 30 + cv.n_mid * 8), 0, 1)
        cv.paint(d, self.WING, R=0.12, dim=dim, pattern=veins)
        bones = cv.cone(sh, wr, 0.07, 0.05)
        for tp in tips:
            bones = np.minimum(bones, cv.cone(wr, tp, 0.035, 0.015))
        bones = np.minimum(bones, cv.cone(wr, wr + rot(base, -side * 0.8) * 0.22, 0.03, 0.01))
        cv.paint(bones, self.BONE, R=0.03, dim=dim, line=0.5, cast=False)

    def body(self):
        cv = self.cv
        c = self.c
        d = cv.smin(cv.ellipse(c, 0.34, 0.42), cv.ellipse(c + (0.0, 0.3), 0.2, 0.18), 0.1)
        fur = 1 - 0.2 * np.clip(np.sin((cv.X * 0.3 + cv.Y) * 45 + cv.n_mid * 14), 0, 1)
        cv.paint(d, self.BODY, R=0.3, pattern=fur)
        cv.paint(cv.inter(d + 0.05, cv.ellipse(c + (0.08, 0.05), 0.16, 0.28)), self.BODY * 1.25, R=0.1, line=0, cast=False)
        feet = np.minimum(fingers(cv, c + (-0.1, 0.42), unit((0, 1)), n=3, ln=0.18, spread=0.8, r=0.02, curl=0.6),
                          fingers(cv, c + (0.12, 0.42), unit((0.2, 1)), n=3, ln=0.18, spread=0.8, r=0.02, curl=0.6))
        cv.paint(feet, self.BONE, R=0.02, line=0.5, cast=False)

    def head(self):
        cv, p = self.cv, self.p
        c = self.hc
        tw = np.minimum(twigs(cv, c + (-0.12, -0.18), -2.0, 0.42, 0.05, 1, seed=1),
                        twigs(cv, c + (0.1, -0.2), -1.25, 0.46, 0.055, 1, seed=2))
        cv.paint(tw, self.TWIG, R=0.03, line=0.55)
        d = cv.smin(cv.ellipse(c, 0.27, 0.23), cv.ellipse(c + (0.24, 0.06), 0.13, 0.1), 0.06)
        cv.paint(d, self.BODY * 1.1, R=0.2)
        mo = p['mouth']
        if mo > 0.15:
            m = cv.ellipse(c + (0.26, 0.15), 0.1, 0.03 + 0.08 * mo)
            cv.paint(m, hexc('2A1020'), R=0.02, line=0.5, shade=False, rim=False, cast=False, union=False)
        for x in (0.2, 0.32):
            fang = cv.cone(c + (x, 0.12), c + (x, 0.12 + 0.08 + 0.04 * mo), 0.022, 0.005)
            cv.paint(fang, hexc('E9DFC9'), R=0.01, line=0.3, cast=False, union=False)
        self.eyes([c + (0.06, -0.04), c + (0.22, -0.03)], 0.05 + 0.01 * p['eye'], MAG * 1.1, glow=p['eye'])

    def spit(self):
        cv, p = self.cv, self.p
        g = p['glob']
        if g <= 0:
            return
        q = self.hc + (0.36 + 0.1 * g, 0.17)
        cv.paint(cv.circle(q, 0.05 + 0.08 * g), MAG * 1.15, R=0.03, line=0.4, shade=False, rim=False, cast=False,
                 union=False, glow=(MAG, 0.06 + 0.06 * g, 0.7 * g))


def bat_anims():
    idle = cyc(6, lambda k: dict(flap=0.25 + 0.75 * np.sin(k * TAU), bob=0.1 * np.cos(k * TAU), mouth=0.1,
                                 eye=1.0 + 0.2 * np.sin(k * TAU)))
    windup = seq(5, lambda k: dict(flap=float(lerp(0.4, 1.25, ease(k))), bob=-0.2 * ease(k), mouth=0.2 + 0.8 * k,
                                   eye=1.0 + 1.4 * ease(k), head=-0.3 * ease(k)))
    dive = cyc(4, lambda k: dict(flap=float(lerp(-0.2, 0.1, 0.5 + 0.5 * np.sin(k * TAU))), fold=0.85, mouth=1.0, eye=2.2,
                                 head=0.6, rot=-38.0, pivot=(0.0, -0.6)))
    spit = seq(5, lambda k: dict(flap=0.6 + 0.4 * np.sin(k * TAU * 1.5), mouth=ease(k), head=0.5 * ease(k), glob=ease(k),
                                 eye=1.0 + 1.3 * ease(k), bob=0.05 * np.sin(k * 12)))
    hurt = seq(3, lambda k: dict(flap=-0.4 * np.sin(k * np.pi) + 0.3, fold=0.3 * np.sin(k * np.pi), mouth=0.9, eye=0.4,
                                 rot=14 * np.sin(k * np.pi), pivot=(0.0, -0.6)))
    death = seq(8, lambda k: dict(flap=-0.5, fold=0.5 + 0.3 * k, mouth=0.8, eye=max(0.0, 1 - 1.6 * k),
                                  rot=-200 * ease(k), pivot=(0.0, -0.6), dy=0.6 * k * k, fade=float(min(1.0, 1.6 - 1.4 * k))))
    return dict(idle=(idle, 12, True), move=(idle, 14, True), windup=(windup, 9, False), attack=(dive, 18, True),
                dive=(dive, 18, True), spit=(spit, 9, False), hurt=(hurt, 12, False), death=(death, 11, False))


# =====================================================================
class Sentry(ForestBody):
    """Упырь-щитник: a lanky dead man, straight back, behind a huge knotted oak board."""
    BOUNDS = (-2.3, 3.6, -4.7, 0.4)
    SKIN = hexc('808C9A')
    RAG = hexc('4E5462')
    BOARD = hexc('957F58')
    BOARD_D = hexc('6A5638')
    EDGE = hexc('C9B88A')
    STRAP = hexc('4A4440')
    GLOW = hexc('9FFFB0')
    BASE = dict(bob=0.0, lean=0.0, fN=(0.3, 0.0), fF=(-0.35, 0.0), bx=0.0, by=0.0, bang=0.0, eye=1.0, jaw=0.1,
                chips=0.0, farh=(-0.45, -1.4), dust=0.0, stump_r=0.12, neck_r=0.15)

    def setup(self):
        p = self.p
        lean = p['lean']
        self.hip = np.array([-0.15, -1.5 + p['bob']])
        self.chest = self.hip + (0.04 + lean * 0.85, -1.05)
        self.neck = self.hip + (0.1 + lean * 1.25, -1.38)
        self.hc = self.neck + (0.12 + lean * 0.25, -0.32)
        self.near_sh = self.chest + (0.1, -0.1)
        self.far_sh = self.chest + (-0.12, -0.08)
        self.bc = np.array([1.05 + p['bx'] + lean * 0.8, -2.08 + p['by'] + p['bob'] * 0.5])

    def stump_n(self, key):
        return (0.25, -1.0)

    def layers(self):
        return [(None, self.far_arm), (None, self.legs), (None, self.body), ('head', self.head), (None, self.near_arm),
                (None, self.board), ('fx', self.fx)]

    def bpt(self, x, y):
        return self.bc + rot(np.array([x, y]), self.p['bang'])

    def far_arm(self):
        cv, p = self.cv, self.p
        d, el, h = limb(cv, self.far_sh, p['farh'], 0.6, 0.55, 0.09, 0.06, (-1, 0.2))
        d = np.minimum(d, fingers(cv, h, unit(np.asarray(h) - el), n=4, ln=0.26, spread=0.7, r=0.025, curl=0.5))
        cv.paint(d, self.SKIN, R=0.08, dim=0.7)

    def legs(self):
        cv, p = self.cv, self.p
        for f, dim, off in ((p['fF'], 0.75, -0.08), (p['fN'], 1.0, 0.1)):
            d, kn, an = limb(cv, self.hip + (off, 0.0), np.asarray(f) + (0, -0.08), 0.8, 0.75, 0.13, 0.07, (1, -0.15))
            d = np.minimum(d, fingers(cv, an, unit((1, 0.25)), n=3, ln=0.3, spread=0.5, r=0.035, curl=0.3))
            cv.paint(d, self.SKIN, R=0.1, dim=dim)
            cv.paint(cv.cone(kn + (-0.05, -0.15), kn + (0.0, 0.2), 0.13, 0.1), self.RAG, R=0.06, dim=dim, line=0.5,
                     cast=False)

    def body(self):
        cv, p = self.cv, self.p
        d = cv.smin(cv.cone(self.hip, self.chest, 0.22, 0.26), cv.cone(self.chest, self.neck, 0.22, 0.1), 0.1)
        ribs = 1 - 0.2 * np.clip(np.sin((cv.Y - cv.X * 0.2) * 34), 0, 1) * (cv.Y < self.chest[1] + 0.35)
        cv.paint(d, self.SKIN, R=0.25, pattern=ribs)
        # a torn shroud from the shoulders, a rope belt
        rag = cv.inter(d + 0.04, cv.Y - (self.chest[1] + 0.15))
        cv.paint(rag, self.RAG, R=0.15, line=0.5, cast=False, pattern=1 - 0.2 * np.clip(np.sin(cv.X * 50), 0, 1))
        roots = [self.hip + (x, 0.12) for x in (-0.22, -0.08, 0.06, 0.2)]
        self.strands(roots, [0.5, 0.65, 0.45, 0.55], self.RAG, sway=-0.1, w=0.05, line=0.5)

    def head(self):
        cv, p = self.cv, self.p
        c = self.hc
        d = cv.smin(cv.ellipse(c, 0.26, 0.3, rot=0.15), cv.ellipse(c + (0.12, 0.18), 0.16, 0.14), 0.06)
        cv.paint(d, self.SKIN * 1.06, R=0.22)
        hair = cv.inter(d + 0.02, -(cv.Y - (c[1] - 0.08 - 0.3 * (cv.X - c[0]))))
        cv.paint(hair, self.RAG * 0.85, R=0.08, line=0.5, cast=False)
        self.strands([c + (x, -0.12) for x in (-0.22, -0.12, -0.02)], [0.45, 0.55, 0.35], self.RAG * 0.85, sway=-0.1,
                     w=0.035, line=0.4)
        for q in (c + (0.06, -0.02), c + (0.2, -0.01)):
            cv.paint(cv.ellipse(q, 0.075, 0.06), INK * 1.3, R=0.02, line=0, shade=False, rim=False, cast=False, union=False)
        self.eyes([c + (0.07, -0.02), c + (0.2, -0.01)], 0.045 + 0.01 * p['eye'], self.GLOW, glow=p['eye'])
        m = cv.ellipse(c + (0.18, 0.2), 0.08, 0.02 + 0.06 * p['jaw'])
        cv.paint(m, hexc('1A1012'), R=0.02, line=0.5, shade=False, rim=False, cast=False, union=False)

    def near_arm(self):
        cv = self.cv
        grip = self.bpt(-0.25, 0.1)
        d, el, h = limb(cv, self.near_sh, grip, 0.62, 0.6, 0.1, 0.07, (0, 1))
        cv.paint(cv.smin(d, cv.circle(h, 0.09), 0.03), self.SKIN, R=0.08)

    def board(self):
        cv, p = self.cv, self.p
        hw, hh = 0.32, 2.05
        pts = [self.bpt(-hw, -hh + 0.1), self.bpt(-hw + 0.12, -hh), self.bpt(hw, -hh + 0.06), self.bpt(hw, hh),
               self.bpt(-hw, hh)]
        d = cv.poly(pts, 0.04)
        d = cv.sub(d, cv.circle(self.bpt(hw, -0.7), 0.07))
        a = p['bang']
        ax = np.cos(a) * (cv.X - self.bc[0]) + np.sin(a) * (cv.Y - self.bc[1])
        planks = 1 - 0.28 * np.clip(1 - np.abs(np.abs(ax) - 0.0) / 0.03, 0, 1) - 0.12 * np.clip(np.sin(cv.Y * 9 + cv.n_mid * 14), 0, 1)
        cv.paint(d, self.BOARD, R=0.18, pattern=planks)
        # worn pale edges, two straps, knots with rings and branch stubs (сучки)
        edge = cv.inter(d, -(d + 0.05))
        cv.paint(edge, self.EDGE, R=0.02, line=0, shade=False, rim=False, cast=False, union=False, alpha=0.55)
        for y in (-1.15, 1.05):
            st = cv.poly([self.bpt(-hw - 0.02, y - 0.08), self.bpt(hw + 0.02, y - 0.1), self.bpt(hw + 0.02, y + 0.06),
                          self.bpt(-hw - 0.02, y + 0.08)])
            cv.paint(st, self.STRAP, R=0.04, line=0.5, cast=False, union=False)
            cv.paint(cv.circle(self.bpt(0.05, y - 0.01), 0.04), self.EDGE, R=0.02, line=0.4, cast=False, union=False)
        for (x, y, r) in ((0.08, -1.6, 0.09), (-0.1, -0.15, 0.11), (0.12, 0.55, 0.07)):
            q = self.bpt(x, y)
            cv.paint(cv.ellipse(q, r, r * 1.4, rot=a), self.BOARD_D, R=0.04, line=0.45, cast=False, union=False)
            cv.ink(np.abs(cv.ellipse(q, r * 0.5, r * 0.75, rot=a)) - 0.008, alpha=0.6)
        stub = np.minimum(cv.cone(self.bpt(hw - 0.05, -1.45), self.bpt(hw + 0.28, -1.65), 0.06, 0.035),
                          cv.cone(self.bpt(hw - 0.05, 0.3), self.bpt(hw + 0.22, 0.42), 0.05, 0.03))
        stub = np.minimum(stub, cv.cone(self.bpt(0.0, -hh + 0.05), self.bpt(-0.12, -hh - 0.32), 0.05, 0.03))
        cv.paint(stub, self.BOARD * 0.9, R=0.03, line=0.55)
        # the hand gripping the far edge (the fingers over the board)
        g = self.bpt(-hw + 0.02, 0.1)
        cv.paint(fingers(cv, g, rot(np.array([1.0, 0.15]), a), n=3, ln=0.16, spread=0.5, r=0.03, curl=0.4), self.SKIN, R=0.03,
                 line=0.5, cast=False)

    def fx(self):
        cv, p = self.cv, self.p
        if p['chips'] > 0:
            k = p['chips']
            d = clods(cv, self.bpt(0.4, -0.9), k, n=9, spread=1.3, size=0.11, up=1.5, seed=5)
            cv.paint(d, self.EDGE * 1.1, R=0.03, line=0.5, cast=False, union=False, alpha=float(1 - max(0, k - 0.6) / 0.4))
        if p['dust'] > 0:
            k = p['dust']
            for i in range(3):
                q = self.bpt(0.45, -1.3 + i * 1.1)
                ln = cv.cone(q + (0.1, 0), q + (0.1 + 0.7 * k, 0.0), 0.03, 0.01)
                cv.paint(ln, self.EDGE, R=0.01, line=0, shade=False, rim=False, cast=False, union=False, alpha=0.7 * (1 - k * 0.5))


def sentry_anims():
    idle = cyc(6, lambda k: dict(bob=0.03 * np.sin(k * TAU), by=0.02 * np.sin(k * TAU + 1), eye=1.0 + 0.2 * np.sin(k * TAU),
                                 farh=(-0.45, -1.4 + 0.05 * np.sin(k * TAU))))

    def step(k):
        s = np.sin(k * TAU)
        return dict(bob=-0.05 * abs(np.cos(k * TAU)), lean=0.04, by=0.03 * s,
                    fN=(0.2 + 0.36 * s, -0.16 * max(0, np.cos(k * TAU))),
                    fF=(-0.25 - 0.36 * s, -0.16 * max(0, -np.cos(k * TAU))), farh=(-0.4 + 0.15 * s, -1.4))
    move = cyc(8, step)
    windup = seq(5, lambda k: dict(lean=-0.16 * ease(k), bx=-0.4 * ease(k), bang=-0.16 * ease(k), by=-0.05 * ease(k),
                                    eye=1.0 + 1.4 * ease(k), jaw=0.6 * ease(k), fN=(0.45, 0.0), fF=(-0.5, 0.0),
                                    farh=(-0.6, -1.7)))

    def bash(k):
        e = ease(min(1, k * 2.0))
        back = max(0.0, k - 0.5) / 0.5
        return dict(lean=float(lerp(-0.16, 0.28, e) - 0.12 * back), bx=float(lerp(-0.4, 0.75, e) - 0.35 * back),
                    bang=float(lerp(-0.16, 0.12, e) - 0.08 * back), eye=2.2 - back, jaw=0.8, fN=(0.7, 0.0),
                    fF=(-0.45, 0.0), farh=(-0.7, -1.2), dust=float(e * (1 - back)))
    attack = seq(5, bash)
    block = seq(4, lambda k: dict(bx=-0.14 * np.sin(k * np.pi), bang=-0.06 * np.sin(k * np.pi * 2), lean=-0.06 * np.sin(k * np.pi),
                                  chips=0.15 + 0.85 * k, eye=0.8, jaw=0.4))
    hurt = seq(3, lambda k: dict(lean=-0.2 * np.sin(k * np.pi), bx=-0.1, eye=0.4, jaw=0.8, fN=(0.3, 0.0), fF=(-0.45, 0.0)))

    def die(k):
        f = ease(max(0.0, (k - 0.15) / 0.85))
        return dict(lean=-0.12 * ease(k), bx=0.1 * k, bang=0.3 * k, eye=max(0.0, 1 - 1.5 * k), jaw=0.9, rot=80 * f,
                    pivot=(-0.6, 0.0), rest=True, rest_sink=0.05)
    death = seq(8, die)
    return dict(idle=(idle, 7, True), move=(move, 9, True), windup=(windup, 8, False), attack=(attack, 14, False),
                block=(block, 16, False), hurt=(hurt, 12, False), death=(death, 10, False))


# =====================================================================
class Suchkovik(ForestBody):
    """Сучковик: a living tree by the wall, broken joints, branch arms, one burning eye, a loaded branch-spear."""
    BOUNDS = (-2.9, 3.4, -5.0, 0.4)
    BARK = hexc('725C48')
    BARK_L = hexc('947A5A')
    LICHEN = hexc('7E9460')
    SPEAR = hexc('B8925E')
    BASE = dict(sway=0.0, pull=0.0, throw=0.0, spear=True, eye=1.0, creak=0.0, tipglow=0.0, lean=0.0, stump_r=0.1,
                neck_r=0.2, chips=0.0)
    MUZZLE = (W(18), -W(44))

    def setup(self):
        p = self.p
        cr = p['creak']
        l = p['lean']
        self.trunk_pts = [np.array(q) for q in ((0.0, -0.1), (0.14 + l * 0.2, -1.0), (-0.06 + l * 0.5, -1.8 + cr * 0.03),
                                                (0.12 + l * 0.8 + cr * 0.04, -2.5), (0.02 + l * 1.0, -3.1))]
        self.neck = self.trunk_pts[-1]
        self.crown = self.neck + (-0.06 + p['sway'] * 0.3, -0.85)
        self.sh = self.trunk_pts[3] + (0.08, -0.1)
        self.sh2 = self.trunk_pts[3] + (-0.1, -0.05)
        mx, my = self.MUZZLE
        self.hand = np.array([mx - 1.25 * p['pull'] + 0.75 * p['throw'], my - 0.15 * p['throw']])

    def stump_n(self, key):
        return (0.0, -1.0)

    def layers(self):
        return [(None, self.back_arm), (None, self.roots), (None, self.trunk), ('head', self.head), (None, self.front_arm),
                ('fx', self.fx)]

    def back_arm(self):
        cv, p = self.cv, self.p
        s = p['sway']
        pts = [self.sh2, self.sh2 + (-0.55, 0.45), self.sh2 + (-0.85 + s * 0.2, 1.3), self.sh2 + (-1.25 + s * 0.3, 2.15)]
        d = cv.path(pts, 0.1, 0.04)
        d = np.minimum(d, twigs(cv, pts[-1], 1.9, 0.35, 0.035, 1, seed=3))
        d = np.minimum(d, twigs(cv, pts[1], -2.6, 0.4, 0.04, 1, seed=4))
        cv.paint(d, self.BARK, R=0.06, dim=0.72)

    def roots(self):
        cv = self.cv
        d = None
        for x, dim in ((-0.95, 0.8), (-0.45, 0.9), (0.55, 1.0), (1.0, 0.9)):
            r = cv.path([(0.0, -0.45), (x * 0.45, -0.25), (x * 0.8, -0.04), (x, 0.0)], 0.13, 0.04)
            d = r if d is None else np.minimum(d, r)
        cv.paint(d, self.BARK, R=0.1, dim=0.9)

    def trunk(self):
        cv = self.cv
        pts = self.trunk_pts
        d = cv.path(pts, 0.34, 0.2)
        for q in pts[1:4]:
            d = cv.smin(d, cv.circle(q, 0.27), 0.05)
        grain = 1 - 0.22 * np.clip(np.sin(cv.X * 34 + cv.n_mid * 16 + cv.Y * 0.8), 0, 1)
        cv.paint(d, self.BARK, R=0.3, pattern=grain)
        for q in pts[1:4]:
            self.crack([q + (-0.15, -0.05), q + (0.0, 0.03), q + (0.17, -0.02)], 0.02, 0.8)
        lich = cv.inter(d + 0.04, cv.ellipse(pts[1] + (-0.12, 0.25), 0.2, 0.3))
        lich = np.minimum(lich, cv.inter(d + 0.04, cv.ellipse(pts[3] + (-0.15, 0.1), 0.15, 0.2)))
        cv.paint(lich, self.LICHEN, R=0.06, line=0.4, cast=False, pattern=1 - 0.35 * (cv.n_hi > 0.1))

    def head(self):
        cv, p = self.cv, self.p
        n, c = self.neck, self.crown
        d = cv.smin(cv.cone(n + (0, 0.1), c, 0.24, 0.17), cv.circle(lerp(n, c, 0.45), 0.24), 0.08)
        cv.paint(d, self.BARK * 1.05, R=0.25, pattern=1 - 0.22 * np.clip(np.sin(cv.X * 34 + cv.n_mid * 16), 0, 1))
        tw = None
        for i, (a, ln) in enumerate(((-2.5, 0.6), (-2.0, 0.75), (-1.55, 0.8), (-1.05, 0.65), (-0.6, 0.5))):
            t = twigs(cv, c + (-0.12 + 0.06 * i, 0.05), a + p['sway'] * 0.3, ln, 0.06, 2, seed=i)
            tw = t if tw is None else np.minimum(tw, t)
        cv.paint(tw, self.BARK_L * 0.9, R=0.04, line=0.55)
        for i in range(4):
            q = c + (-0.5 + i * 0.32, -0.45 - 0.2 * (i % 2))
            cv.paint(leaf(cv, q, 0.2, 0.06, -1.2 + i * 0.6), self.LICHEN, R=0.03, line=0.45, cast=False)
        # the eye in a bark crevice: the only thing that tells it from a tree
        e = lerp(n, c, 0.42) + (0.1, 0.0)
        cv.paint(cv.ellipse(e, 0.15, 0.065, rot=-0.2), INK * 1.3, R=0.02, line=0.5, shade=False, rim=False, cast=False,
                 union=False)
        self.eyes([e + (0.02, 0.0)], 0.06 + 0.015 * p['eye'], EYE, glow=p['eye'] * 1.2)

    def front_arm(self):
        cv, p = self.cv, self.p
        h = self.hand
        d, el, hh = limb(cv, self.sh, h, 1.05, 1.0, 0.11, 0.06, (0.2, -1))
        d = cv.smin(d, cv.circle(el, 0.08), 0.03)
        d = np.minimum(d, twigs(cv, el, -2.0, 0.32, 0.035, 1, seed=6))
        if p['spear']:
            # the loaded spear: a sharpened branch, tip forward
            tip = h + (0.85, 0.0)
            tail = h - (1.95, 0.0)
            sp = cv.smin(cv.cone(tail, h + (0.35, 0), 0.06, 0.08), cv.cone(h + (0.35, 0), tip, 0.08, 0.01), 0.02)
            sp = np.minimum(sp, cv.cone(lerp(tail, h, 0.35), lerp(tail, h, 0.35) + (-0.2, -0.22), 0.03, 0.01))
            cv.paint(sp, self.SPEAR, R=0.06, line=0.6,
                     pattern=1 - 0.15 * np.clip(np.sin(cv.X * 40 + cv.n_mid * 10), 0, 1))
            cv.paint(leaf(cv, lerp(tail, h, 0.35) + (-0.22, -0.3), 0.22, 0.06, -2.2), self.LICHEN, R=0.03, line=0.45,
                     cast=False)
            if p['tipglow'] > 0:
                cv.paint(cv.circle(tip + (-0.05, 0), 0.04), EYE * 1.2, R=0.02, line=0, shade=False, rim=False, cast=False,
                         union=False, glow=(EYE, 0.08, 0.8 * p['tipglow']))
        fist = fingers(cv, hh, unit(np.asarray(hh) - el), n=3, ln=0.24, spread=1.4, r=0.035, curl=1.2)
        cv.paint(np.minimum(d, fist), self.BARK * 1.05, R=0.08)

    def fx(self):
        cv, p = self.cv, self.p
        if p['chips'] > 0:
            k = p['chips']
            d = clods(cv, self.trunk_pts[2] + (0.25, 0.0), k, n=6, spread=1.0, size=0.07, up=1.0, seed=8)
            cv.paint(d, self.BARK_L, R=0.03, line=0.5, cast=False, union=False, alpha=float(1 - max(0, k - 0.6) / 0.4))


def suchkovik_anims():
    idle = cyc(6, lambda k: dict(sway=0.1 * np.sin(k * TAU), eye=1.0 + 0.35 * np.sin(k * TAU * 2), lean=0.02 * np.sin(k * TAU)))
    windup = seq(5, lambda k: dict(pull=ease(k), creak=np.sin(k * 25) * ease(k), eye=1.0 + 1.5 * ease(k), tipglow=ease(k),
                                    lean=-0.06 * ease(k), sway=-0.1 * ease(k)))
    throw = seq(5, lambda k: dict(spear=False, throw=float(ease(min(1, k * 2.5)) * (1 - 0.6 * max(0, k - 0.4) / 0.6)),
                                  lean=0.1 * (1 - k), eye=2.0 - k, sway=0.15 * (1 - k)))
    hurt = seq(3, lambda k: dict(lean=-0.12 * np.sin(k * np.pi), sway=0.3 * np.sin(k * np.pi), eye=0.4, chips=0.2 + 0.7 * k))

    def die(k):
        f = ease(max(0.0, (k - 0.2) / 0.8))
        return dict(eye=max(0.0, 1 - 1.4 * k), sway=0.3 * k, creak=0.5 * np.sin(k * 30) * (1 - f), rot=72 * f,
                    pivot=(-0.4, 0.0), rest=True, rest_sink=0.05, chips=float(min(1.0, k * 1.3)))
    death = seq(8, die)
    return dict(idle=(idle, 6, True), windup=(windup, 8, False), throw=(throw, 12, False), attack=(throw, 12, False),
                hurt=(hurt, 12, False), death=(death, 9, False))


def spear_canvas(stuck):
    """The flying / stuck branch-spear: tip at x = 0 pointing +x, 80 world px long."""
    from sdf2d import Canvas
    from base import S_RENDER
    ln = W(80)
    cv = Canvas(-ln - 0.3, 0.45, -0.5, 0.5, S_RENDER, seed=11)
    tip = np.array([0.0 if not stuck else -0.05, 0.0])
    tail = np.array([-ln, 0.0])
    sp = cv.smin(cv.cone(tail, tip - (0.9, 0), 0.07, 0.1), cv.cone(tip - (0.9, 0), tip, 0.1, 0.012), 0.02)
    for x, a in ((-2.2, -2.3), (-1.4, 2.4)):
        sp = np.minimum(sp, cv.cone((x, 0.0), (x - 0.25, 0.3 * np.sign(a)), 0.035, 0.012))
    cv.paint(sp, Suchkovik.SPEAR, R=0.08, line=0.7, pattern=1 - 0.18 * np.clip(np.sin(cv.X * 36 + cv.n_mid * 10), 0, 1))
    shav = cv.inter(sp + 0.02, cv.X - (tip[0] - 0.85))
    cv.paint(shav, hexc('E2C696'), R=0.03, line=0.0, cast=False, union=False, alpha=0.8)
    cv.paint(leaf(cv, (-2.6, -0.28), 0.26, 0.07, -2.4), Suchkovik.LICHEN, R=0.03, line=0.5, cast=False)
    if stuck:
        d = None
        for a in (-2.4, -1.9, 1.9, 2.5, 2.9):
            q1 = np.array([np.cos(a), np.sin(a)]) * 0.32
            di = cv.cone((0.05, 0.0), (0.05 + q1[0], q1[1]), 0.04, 0.008)
            d = di if d is None else np.minimum(d, di)
        cv.paint(d, hexc('6A5440'), R=0.02, line=0.5, cast=False)
    cv.outer_outline(1.6)
    return cv


# =====================================================================
class Lesavka(ForestBody):
    """Лесавка: a root granny, a huge mop of leaves, a long root nose, thin legs."""
    BOUNDS = (-1.9, 2.2, -3.0, 0.35)
    SKIN = hexc('927050')
    LEAF = hexc('5C8C3A')
    LEAF_D = hexc('3E6428')
    LEAF_HI = hexc('A2C650')
    BASE = dict(bob=0.0, gait=0.0, run=0.0, lean=0.0, puff=0.0, sparks=0.0, sk=0.0, jaw=0.0, eye=1.0, mop=0.0,
                scatter=0.0, stump_r=0.08, neck_r=0.18)

    def setup(self):
        p = self.p
        self.hip = np.array([0.0, -0.62 + p['bob']])
        self.neck = self.hip + (0.08 + p['lean'] * 0.6, -0.42)
        self.mc = self.neck + (-0.12 + p['lean'] * 0.4 + p['mop'] * 0.08, -0.58)
        self.face = self.neck + (0.3 + p['lean'] * 0.3, -0.2)

    def stump_n(self, key):
        return (0.2, -1.0)

    def layers(self):
        return [(None, self.legs), (None, self.body), ('head', self.head), ('fx', self.fx)]

    def legs(self):
        cv, p = self.cv, self.p
        g = p['gait']
        s = np.sin(g * TAU) * p['run']
        for side, dim in ((-1, 0.75), (1, 1.0)):
            f = (0.08 * side + 0.32 * s * side, -0.14 * p['run'] * max(0, np.cos(g * TAU) * side))
            d, kn, an = limb(cv, self.hip + (0.06 * side, 0.0), np.asarray(f) + (0, -0.05), 0.34, 0.32, 0.06, 0.035, (1, 0))
            d = np.minimum(d, fingers(cv, an, unit((1, 0.4)), n=3, ln=0.16, spread=1.0, r=0.022, curl=0.3))
            cv.paint(d, self.SKIN * 0.9, R=0.05, dim=dim)

    def body(self):
        cv, p = self.cv, self.p
        d = cv.smin(cv.ellipse(self.hip + (0.02, -0.15), 0.24, 0.26), cv.cone(self.hip, self.neck, 0.2, 0.13), 0.08)
        cv.paint(d, self.SKIN, R=0.2, pattern=1 - 0.2 * np.clip(np.sin(cv.X * 40 + cv.n_mid * 12), 0, 1))
        sw = 0.25 * np.sin(p['gait'] * TAU) * p['run']
        for side, dim in ((-1, 0.75), (1, 1.0)):
            sh = self.neck + (0.08 * side, 0.12)
            h = sh + (0.18 * side + sw * side, 0.4)
            a = cv.path([sh, lerp(sh, h, 0.5) + (0.05 * side, 0), h], 0.04, 0.025)
            a = np.minimum(a, fingers(cv, h, unit(np.asarray(h) - sh), n=3, ln=0.12, spread=1.0, r=0.015, curl=0.4))
            cv.paint(a, self.SKIN * 1.05, R=0.03, dim=dim, line=0.5)

    def head(self):
        cv, p = self.cv, self.p
        c, f = self.mc, self.face
        # face first (under the mop): cheek, the long root nose, mouth
        fd = cv.ellipse(f, 0.2, 0.2)
        cv.paint(fd, self.SKIN * 1.08, R=0.15)
        cheek = cv.circle(f + (0.08, 0.12), 0.06 + 0.11 * p['puff'])
        cv.paint(cheek, self.SKIN * 1.2, R=0.08, line=0.5)
        if p['jaw'] > 0.1:
            m = cv.ellipse(f + (0.12, 0.17), 0.1, 0.03 + 0.07 * p['jaw'])
            cv.paint(m, hexc('1A1012'), R=0.02, line=0.5, shade=False, rim=False, cast=False, union=False)
            for x in (0.06, 0.16):
                cv.paint(cv.cone(f + (x, 0.12), f + (x, 0.18 + 0.03 * p['jaw']), 0.02, 0.005), hexc('E9DFC9'), R=0.01,
                         line=0.3, cast=False, union=False)
        nose = cv.path([f + (0.12, -0.05), f + (0.4 + 0.05 * p['puff'], 0.02), f + (0.62 + 0.06 * p['puff'], 0.14)], 0.065, 0.02)
        nose = np.minimum(nose, cv.cone(f + (0.4, 0.02), f + (0.5, -0.1), 0.02, 0.006))
        cv.paint(nose, self.SKIN * 1.12, R=0.05, line=0.6)
        # the mop of leaves, bigger than her body
        base = cv.smin(cv.circle(c, 0.56), cv.ellipse(c + (0.0, 0.25), 0.62, 0.3), 0.15)
        cv.paint(base, self.LEAF_D, R=0.35)
        rng = np.random.default_rng(4)
        for i in range(26):
            a = rng.random() * TAU
            r = 0.15 + 0.45 * np.sqrt(rng.random())
            q = c + (np.cos(a) * r * 1.05, np.sin(a) * r * 0.95 + 0.06) + (p['mop'] * 0.05 * np.sin(i), 0)
            if q[1] > c[1] + 0.45 and q[0] > c[0] + 0.1:
                continue
            col = (self.LEAF, self.LEAF_D * 1.15, self.LEAF_HI)[i % 3 if i % 5 else 2]
            cv.paint(leaf(cv, q, 0.3, 0.085, a + 0.6 * rng.random()), col, R=0.05, line=0.45, cast=False)
        # eyes under the fringe
        self.eyes([f + (-0.05, -0.06), f + (0.1, -0.05)], 0.045 + 0.01 * p['eye'], EYE, glow=p['eye'])

    def fx(self):
        cv, p = self.cv, self.p
        if p['sk'] > 0:
            k = p['sk']
            for i in range(9):
                a = p['sparks'] * TAU + i * TAU / 9
                rr = 0.5 + 0.55 * k + 0.1 * np.sin(i * 2.1)
                q = self.mc + (0.1 + np.cos(a) * rr, 0.35 + np.sin(a) * rr * 0.55 - 0.45 * k)
                cv.paint(cv.circle(q, 0.035 + 0.02 * (i % 2)), SPARK, R=0.02, line=0, shade=False, rim=False, cast=False,
                         union=False, glow=(EYE, 0.05, 0.6 * k))
            q = self.face + (0.7, 0.12)
            cv.paint(cv.circle(q, 0.04 + 0.04 * k), SPARK, R=0.02, line=0, shade=False, rim=False, cast=False, union=False,
                     glow=(EYE, 0.07, 0.8 * k))
        if p['scatter'] > 0:
            k = p['scatter']
            rng = np.random.default_rng(9)
            for i in range(8):
                q = self.mc + ((rng.random() - 0.5) * 2.4 * k, -0.2 - 1.2 * k * rng.random() + 1.6 * k * k)
                cv.paint(leaf(cv, q, 0.24, 0.07, rng.random() * TAU + k * 3), (self.LEAF, self.LEAF_HI)[i % 2], R=0.04,
                         line=0.45, cast=False, union=False, alpha=float(1 - max(0.0, k - 0.6) / 0.4))


def lesavka_anims():
    idle = cyc(6, lambda k: dict(bob=0.03 * np.sin(k * TAU), mop=np.sin(k * TAU), eye=1.0 + 0.2 * np.sin(k * TAU * 2)))
    flee = cyc(8, lambda k: dict(gait=k, run=1.0, lean=0.28, bob=-0.07 * abs(np.sin(k * TAU)), mop=-1.0 + 0.4 * np.sin(k * TAU * 2),
                                 eye=1.3))
    whistle = seq(6, lambda k: dict(puff=ease(min(1, k * 1.5)), lean=-0.12 * ease(k), sk=ease(k), sparks=k * 0.7, eye=1.0 + 1.4 * k,
                                    bob=0.03 * np.sin(k * 20), mop=0.4 * np.sin(k * 9)))
    windup = seq(4, lambda k: dict(lean=-0.18 * ease(k), jaw=ease(k), eye=1.0 + 1.4 * ease(k), mop=-0.5 * k))
    attack = seq(4, lambda k: dict(lean=float(lerp(-0.18, 0.3, ease(min(1, k * 2)))), dx=0.3 * np.sin(k * np.pi),
                                   jaw=1.0 if k < 0.4 else 0.15, eye=2.2 - k, mop=0.6))
    hurt = seq(3, lambda k: dict(lean=-0.25 * np.sin(k * np.pi), mop=1.2 * np.sin(k * np.pi), eye=0.4, jaw=0.5,
                                 scatter=0.25 * k))

    def die(k):
        f = ease(max(0.0, (k - 0.15) / 0.85))
        return dict(eye=max(0.0, 1 - 1.5 * k), jaw=0.6, mop=k, rot=86 * f, pivot=(-0.3, 0.0), rest=True, rest_sink=0.04,
                    scatter=float(k))
    death = seq(8, die)
    return dict(idle=(idle, 7, True), move=(flee, 14, True), flee=(flee, 14, True), whistle=(whistle, 9, False),
                windup=(windup, 8, False), attack=(attack, 14, False), hurt=(hurt, 12, False), death=(death, 10, False))


# kind id -> (class, anims, severable parts, anims that get one-armed / headless frames); limb_zones.json
KINDS = {
    'ringer': (Ringer, ringer_anims, ['arm', 'head'], ['idle', 'move', 'call', 'appear', 'windup', 'attack', 'hurt']),
    'rootling': (Rootling, rootling_anims, ['head'], ['idle', 'move', 'burrow', 'attack', 'hurt']),
    'bat': (Bat, bat_anims, [], []),
    'sentry': (Sentry, sentry_anims, ['head'], ['idle', 'move', 'windup', 'attack', 'block', 'hurt']),
    'suchkovik': (Suchkovik, suchkovik_anims, ['head'], ['idle', 'windup', 'throw', 'hurt']),
    'lesavka': (Lesavka, lesavka_anims, ['head'], ['idle', 'move', 'flee', 'whistle', 'windup', 'attack', 'hurt']),
}

# enemy state -> animation (see build.STATES). Rootling under the floor: the mound sheets.
STATES = {
    'ringer': {'walk': {'anim': 'idle', 'moving': 'move'}, 'call': {'anim': 'call', 'k': 'call'},
               'gone': {'anim': 'vanish', 'k': 'gone'}, 'appear': {'anim': 'appear', 'k': 'appear'},
               'swipe': {'anim': 'attack', 'k': 'swipe_time'}, 'recover': {'anim': 'idle'}},
    'rootling': {'walk': {'anim': 'idle', 'moving': 'move'}, 'dig': {'anim': 'burrow', 'k': 'dig'},
                 'under': {'anim': 'under'}, 'rise_w': {'anim': 'windup', 'k': 'rise_w'},
                 'burst': {'anim': 'attack', 'k': 'burst_time'}, 'recover': {'anim': 'idle'}},
    'bat': {'hover': {'anim': 'idle'}, 'wind': {'anim': 'windup', 'k': 'wind'}, 'swoop': {'anim': 'dive'},
            'spitwind': {'anim': 'spit', 'k': 'wind'}},
    'sentry': {'walk': {'anim': 'idle', 'moving': 'move'}, 'bash': {'anim': 'windup', 'k': 'bash_wind'},
               'recover': {'anim': 'attack', 'k': 'bash_recover'}},
    'suchkovik': {'stand': {'anim': 'idle'}, 'wind': {'anim': 'windup', 'k': 'wind'},
                  'recover': {'anim': 'throw', 'k': 'recover'}},
    'lesavka': {'run': {'anim': 'idle', 'moving': 'flee'}, 'whistle': {'anim': 'whistle', 'k': 'whistle'},
                'bite_wind': {'anim': 'windup', 'k': 'bite_wind'}, 'bite': {'anim': 'attack', 'k': 'bite_time'}},
}

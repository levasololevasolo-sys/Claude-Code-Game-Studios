"""Hand-drawn hero «Медвежья шкура» (variant 1), 2D cutout/skeletal pose system.

Every frame is a *pose* (pelvis, torso lean, IK targets for feet and fists, head
tilt, breath, cape drag). The same pose is painted for each of the 5 armour
tiers (art bible §5.6), so all tiers share one animation. Painting reuses the
SDF ink-and-paint renderer of sdf2d.py (outline #120D12, 3-tone shading,
painterly noise, warm rim light) from the variant sketches (hero.py).

Units: 1 unit ~ one head height, y grows downward, ground at y = 0, the hero
faces +x (right) and is turned 3/4 toward the camera: the near (weapon) arm and
the near shoulder with the bear head are on screen-left of the chest.
"""
import numpy as np
from sdf2d import Canvas, hexc, INK

SKIN = hexc('E0A07A')
CANVAS = hexc('CDBB98')
LINEN = hexc('E9DFC9')
WRAP = hexc('9A8A72')
ONUCHI = hexc('DCCFAE')
LAPTI = hexc('BFA36A')
RED = hexc('B3262E')
STEEL = hexc('B8C4CC')
MAIL = hexc('8E9AA3')
GOLD = hexc('C8902E')
GOLDL = hexc('FFC94A')
BRONZE = hexc('B07A3A')
HAIR = hexc('8A5A34')
LEATHER = hexc('6B4428')
LEATHER2 = hexc('7A4A2A')
TEGIL = hexc('9A7448')
WOOD = hexc('A07A4E')
SILVER = hexc('EDE6F2')
PANTS3 = hexc('5A4A40')
FUR = hexc('6E4A30')
FUR_D = hexc('5E3E2A')
FUR_H = hexc('7A5236')

# body proportions of variant 1 (hero.py: sw=1.12, armk=1.1, handk=1.1)
AK, HK, HR = 1.1, 1.1, 0.44
UPPER, FORE, FIST = 0.72, 0.64, 0.17
THIGH, SHIN = 0.86, 0.80
# torso-local points (origin = pelvis centre, -v = up the spine, +u = forward)
NECK = (0.12, -1.52)
SH_N = (-0.46, -1.30)
SH_F = (0.66, -1.26)
HIP_N = (-0.18, -0.02)
HIP_F = (0.24, -0.06)
AMU = (0.34, -0.93)

# canvas: 320x288 px cell at 50 px/unit (rendered 2x, downsampled)
X0, X1, Y0, Y1 = -3.2, 3.2, -5.41, 0.35
S_RENDER = 100
DOWN = 2


def rot(v, a):
    c, s = np.cos(a), np.sin(a)
    return np.array([v[0] * c - v[1] * s, v[0] * s + v[1] * c])


def ik(a, t, l1, l2, hint):
    """Two-bone IK: joint and (reach-clamped) end for root a, target t."""
    a = np.asarray(a, float); t = np.asarray(t, float)
    d = t - a
    L0 = max(np.hypot(*d), 1e-6)
    u = d / L0
    L = np.clip(L0, abs(l1 - l2) + 1e-3, l1 + l2 - 1e-3)
    A = np.arccos(np.clip((l1 * l1 + L * L - l2 * l2) / (2 * l1 * L), -1, 1))
    c1, c2 = rot(u, A), rot(u, -A)
    h = np.asarray(hint, float)
    c = c1 if np.dot(c1, h) >= np.dot(c2, h) else c2
    return a + l1 * c, a + u * L


class Frame:
    """Temporarily maps the canvas grid into a rotated/scaled local frame."""

    def __init__(self, cv, origin, ang, sx=1.0, sy=1.0):
        self.cv, self.o, self.a, self.sx, self.sy = cv, np.asarray(origin, float), ang, sx, sy

    def __enter__(self):
        cv = self.cv
        self._s = (cv.X, cv.Y)
        dx, dy = cv.X - self.o[0], cv.Y - self.o[1]
        c, s = np.cos(self.a), np.sin(self.a)
        cv.X = ((c * dx + s * dy) / self.sx).astype(np.float32)
        cv.Y = ((-s * dx + c * dy) / self.sy).astype(np.float32)
        return self

    def __exit__(self, *exc):
        self.cv.X, self.cv.Y = self._s

    def w(self, p):
        c, s = np.cos(self.a), np.sin(self.a)
        u, v = p[0] * self.sx, p[1] * self.sy
        return np.array([self.o[0] + u * c - v * s, self.o[1] + u * s + v * c])


BASE_POSE = dict(hip=(0.0, -1.70), lean=0.06, tilt=0.0, breath=0.0,
                 fN=(-0.42, -0.11), fF=(0.52, -0.11), pN=0.0, pF=0.0,
                 hN=(0.08, -1.80), hF=(0.92, -1.86), eN=(-0.6, 0.8), eF=(-0.5, 0.8),
                 handF='fist', drag=(0.0, 0.0), face='calm', glow=1.0, thread=0.0,
                 rot=0.0, pivot=(0.0, -1.5))


class Drawn:
    def __init__(self, tier, pose, seed=11):
        self.t = tier
        self.p = dict(BASE_POSE); self.p.update(pose)
        self.cv = Canvas(X0, X1, Y0, Y1, S_RENDER, seed=seed)
        p = self.p
        self.torso = Frame(self.cv, p['hip'], p['lean'])
        b = p['breath']
        self.chest_k = 1.0 + 0.035 * b
        T = self.torso
        self.shN = T.w((SH_N[0] - 0.02 * b, SH_N[1] - 0.04 * b))
        self.shF = T.w((SH_F[0] + 0.01 * b, SH_F[1] - 0.04 * b))
        self.neck = T.w((NECK[0], NECK[1] - 0.035 * b))
        self.hipN, self.hipF = T.w(HIP_N), T.w(HIP_F)
        self.head_c = self.neck + rot(np.array([0.07, -0.6]), p['lean'] + p['tilt'])
        self.head = Frame(self.cv, self.head_c, p['lean'] * 0.5 + p['tilt'])
        self.amulet_pos = T.w((AMU[0], AMU[1] - 0.03 * b))
        # limbs (IK)
        self.legs = {}
        for side, hip, f, pitch in (('N', self.hipN, p['fN'], p['pN']), ('F', self.hipF, p['fF'], p['pF'])):
            knee, ank = ik(hip, f, THIGH, SHIN, (1.0, -0.15))
            self.legs[side] = (hip, knee, ank, pitch)
        self.arms = {}
        for side, sh, h, e in (('N', self.shN, p['hN'], p['eN']), ('F', self.shF, p['hF'], p['eF'])):
            el, fist = ik(sh, h, UPPER, FORE + FIST, e)
            fdir = (fist - el) / max(np.hypot(*(fist - el)), 1e-6)
            wr = el + fdir * FORE
            self.arms[side] = (sh, el, wr, fist, fdir)
        self.hand = self.arms['N'][3]

    # ---------------- helpers ----------------
    def fur(self):
        cv = self.cv
        s = np.sin(cv.X * 46 + cv.n_mid * 14 + np.sin(cv.Y * 7) * 1.5)
        return 1 - 0.22 * np.clip(s, 0, 1) ** 2 + 0.06 * np.clip(-s, 0, 1)

    def mail_pat(self):
        cv = self.cv
        u = cv.X * 24; v = cv.Y * 24
        return 0.88 + 0.14 * np.abs(np.sin(u + np.sin(v) * 0.6)) * np.abs(np.sin(v * 1.1))

    def scale_pat(self):
        cv = self.cv
        rowh, cw = 0.13, 0.17
        r = np.floor(cv.Y / rowh)
        u = cv.X / cw + (r % 2) * 0.5
        fu = u - np.floor(u) - 0.5
        v = cv.Y / rowh - r
        edge = 1 - 3.2 * fu * fu
        sh = np.where(v < edge, 1.08 - 0.42 * (v / np.maximum(edge, 0.1)), 0.62 + 0.25 * v)
        return np.where(np.abs(v - edge) < 0.09, 0.4, sh)

    def quilt_pat(self):
        cv = self.cv
        a = np.abs(((cv.X + cv.Y) * 7) % 2 - 1) < 0.1
        b = np.abs(((cv.X - cv.Y) * 7) % 2 - 1) < 0.1
        return 1 - 0.22 * (a | b)

    def band(self, d, y0, y1):
        cv = self.cv
        return cv.inter(d, np.maximum(y0 - cv.Y, cv.Y - y1))

    # ---------------- build ----------------
    def build(self):
        cv, t = self.cv, self.t
        if t >= 3:
            self.cape()
        self.pelt_back()
        self.arm('F')
        self.leg('F')
        self.leg('N')
        self.torso_()
        self.amulet()
        self.head_()
        self.pelt_front()
        self.arm('N')
        cv.outer_outline(1.0)
        return cv

    # ---------------- cape (tiers 3-5) ----------------
    def cape(self):
        cv, t, p = self.cv, self.t, self.p
        dx, dy = p['drag']
        T = self.torso
        a = T.w((SH_N[0] - 0.12, SH_N[1] - 0.05))
        b = T.w((SH_F[0] - 0.15, SH_F[1] - 0.1))
        if t == 3:
            mid = T.w((-0.2, -0.55))
            pts = [a, b, T.w((0.4, -0.8)) + (dx * 0.3, dy * 0.2), mid + (dx * 0.5, dy * 0.4),
                   T.w((-0.85, -0.7)) + (dx * 0.6, dy * 0.5)]
            bot = None
        else:
            bot = -0.55 if t == 4 else -0.32
            L = bot - a[1]
            k = 1.0
            pts = [a, b, (b[0] + 0.1 + dx * 0.25, b[1] + L * 0.45 + dy * 0.3),
                   (0.45 + p['hip'][0] + dx * 0.55, bot + dy * 0.6 + 0.05 * np.sin(dx * 3)),
                   (-0.35 + p['hip'][0] + dx * 0.85, bot + 0.06 + dy * 0.8),
                   (-1.05 + p['hip'][0] + dx * 1.0, bot - 0.05 + dy * 0.95),
                   (a[0] - 0.4 + dx * 0.5, a[1] + L * 0.45 + dy * 0.4)]
        pts = [tuple(np.asarray(q, float)) for q in pts]
        d = cv.poly(pts, 0.07) + 0.03 * np.sin(cv.X * 13 + cv.Y * 3) * np.clip((cv.Y - pts[0][1]) / 2.0, 0, 1)
        folds = 1 - 0.2 * np.clip(np.sin((cv.X * 1.0 - cv.Y * 0.3) * 8.0 + dx * 2), 0, 1) ** 2
        cv.paint(d, RED * 0.92, R=0.6, pattern=folds, dim=0.88)
        if t == 5:
            band = cv.inter(d, -(d + 0.09))
            hem = max(q[1] for q in pts) - 0.32
            band = cv.inter(band, -(cv.Y - hem))
            orn = 1 - 0.35 * (np.abs(((cv.X * 9) % 2) - 1) > 0.6)
            cv.paint(band, GOLD, R=0.05, line=0.6, cast=False, pattern=orn, rim=False, dim=0.9)

    # ---------------- bear pelt ----------------
    def pelt_back(self):
        cv, p = self.cv, self.p
        dx, dy = p['drag']
        T = self.torso
        a = T.w((SH_N[0] - 0.3, SH_N[1] - 0.1))
        b = T.w((SH_F[0] - 0.05, SH_F[1] - 0.12))
        pts = [a, b, T.w((0.3, -0.75)) + (dx * 0.2, dy * 0.15), T.w((-0.3, -0.45)) + (dx * 0.35, dy * 0.3),
               T.w((-0.75, -0.55)) + (dx * 0.45, dy * 0.4), T.w((-0.95, -0.95)) + (dx * 0.2, dy * 0.2)]
        pts = [tuple(np.asarray(q, float)) for q in pts]
        d = cv.poly(pts, 0.08) + 0.04 * np.sin(cv.X * 30 + cv.Y * 9) * (cv.Y > pts[2][1] - 0.3)
        cv.paint(d, FUR_D, R=0.5, pattern=self.fur(), dim=0.85)

    def pelt_front(self):
        cv = self.cv
        b = self.p['breath']
        with Frame(cv, self.p['hip'], self.p['lean'], 1.0, 1.0):
            fur = self.fur()
            y = -0.04 * b
            m = cv.poly([(-0.95, -1.3 + y), (-0.3, -1.6 + y), (0.55, -1.58 + y), (1.0, -1.32 + y), (0.92, -1.0 + y),
                         (0.62, -1.08 + y), (0.38, -0.98 + y), (0.05, -1.05 + y), (-0.4, -0.92 + y), (-0.85, -0.85 + y),
                         (-1.05, -1.05 + y)], 0.07)
            m = cv.sub(m, cv.ellipse((0.16, -1.5 + y), 0.36, 0.22))
            m = m + 0.03 * np.sin(cv.X * 40) * (cv.Y > -1.15 + y)
            cv.paint(m, FUR, R=0.3, pattern=fur)
            # claws on the chest
            for xx in (0.05, 0.2):
                cv.paint(cv.poly([(xx, -1.06 + y), (xx + 0.06, -1.04 + y), (xx + 0.03, -0.88 + y)], 0.01),
                         hexc('E8DCC0'), R=0.03, line=0.5, cast=False)
            # bear head on the near shoulder
            bh = (SH_N[0] - 0.12, SH_N[1] - 0.34 + y)
            for ex in (-0.26, 0.22):
                cv.paint(cv.circle((bh[0] + ex, bh[1] - 0.23), 0.1), FUR, R=0.08)
                cv.flat(cv.circle((bh[0] + ex, bh[1] - 0.23), 0.045), hexc('3A2418'))
            hd = cv.smin(cv.ellipse(bh, 0.36, 0.29), cv.ellipse((bh[0] - 0.1, bh[1] + 0.2), 0.21, 0.15), 0.08)
            cv.paint(hd, FUR_H, R=0.3, pattern=fur)
            cv.paint(cv.ellipse((bh[0] - 0.16, bh[1] + 0.26), 0.08, 0.06), hexc('2A1A14'), R=0.05, line=0.4)
            cv.flat(cv.ellipse((bh[0] - 0.02, bh[1] + 0.01), 0.05, 0.025, rot=0.3), hexc('1A1010'))
            cv.flat(cv.ellipse((bh[0] + 0.18, bh[1] - 0.01), 0.045, 0.022, rot=-0.3), hexc('1A1010'))
            if self.t >= 5:  # fibula pinning the korzno
                cv.paint(cv.circle((SH_F[0] - 0.3, -1.25 + y), 0.1), GOLD, R=0.06, line=0.6, hl=1.6)

    # ---------------- torso ----------------
    def torso_(self):
        cv, t, p = self.cv, self.t, self.p
        b = p['breath']
        k = self.chest_k
        with Frame(cv, p['hip'], p['lean']):
            y = -0.035 * b
            chest = cv.ellipse((0.14, -1.03 + y), 0.72 * k, 0.5 * k)
            chest = cv.smin(chest, cv.ellipse((0.44, -0.97 + y), 0.4 * k, 0.36 * k), 0.12)
            chest = cv.smin(chest, cv.ellipse((0.08, -1.32 + y), 0.62, 0.2), 0.15)
            belly = cv.ellipse((0.14, -0.48), 0.55, 0.44)
            pelvis = cv.ellipse((0.04, -0.04), 0.5, 0.28)
            d = cv.smin(cv.smin(chest, belly, 0.22), pelvis, 0.15)
            neck = cv.cone((NECK[0] + 0.02, NECK[1] - 0.3 + y), (NECK[0], NECK[1] + 0.12 + y), 0.21, 0.27)
            cv.paint(neck, SKIN, R=0.15, dim=0.9)
            if t == 1:
                cv.paint(d, SKIN, R=0.55)
                cv.ink(cv.path([(-0.3, -0.82 + y), (0.0, -0.72 + y), (0.24, -0.8 + y)], 0.012), alpha=0.7)
                cv.ink(cv.path([(0.32, -0.8 + y), (0.52, -0.72 + y), (0.72, -0.82 + y)], 0.011), alpha=0.55)
                cv.ink(cv.path([(0.36, -0.62), (0.38, -0.4), (0.36, -0.2)], 0.008), alpha=0.35)
                cv.ink(cv.circle((0.3, -0.3), 0.025), alpha=0.7)
                for kk in range(3):  # scrapes on the shoulders
                    x0 = 0.5 + 0.05 * kk
                    cv.ink(cv.seg((x0, -1.3 + 0.05 * kk), (x0 + 0.12, -1.22 + 0.05 * kk), 0.008), col=hexc('8C3A2E'), alpha=0.6)
                pants = cv.poly([(-0.52, -0.3), (0.62, -0.3), (0.66, 0.28), (-0.56, 0.28)], 0.04)
                cv.paint(pants, CANVAS, R=0.3)
                self.rope_belt(-0.28)
            elif t == 2:
                pants = cv.poly([(-0.52, -0.3), (0.62, -0.3), (0.66, 0.28), (-0.56, 0.28)], 0.04)
                cv.paint(pants, CANVAS, R=0.3)
                shirt = cv.smin(d - 0.04, cv.poly([(-0.6, -0.5), (0.72, -0.5), (0.82, 0.36), (-0.66, 0.38)], 0.05), 0.15)
                shirt = cv.inter(shirt, cv.Y - (0.36 + 0.02 * np.sin(cv.X * 20)))
                folds = 1 - 0.1 * np.clip(np.sin(cv.X * 16 + cv.Y * 3), 0, 1)
                cv.paint(shirt, LINEN, R=0.45, pattern=folds)
                self.embroidery(self.band(shirt, 0.22, 0.32))
                coll = cv.inter(cv.ellipse((NECK[0] + 0.02, NECK[1] + 0.15 + y), 0.36, 0.16), -cv.ellipse((NECK[0] + 0.02, NECK[1] + 0.1 + y), 0.26, 0.1))
                self.embroidery(coll)
                self.rope_belt(-0.26)
            else:
                pants = cv.poly([(-0.52, -0.3), (0.62, -0.3), (0.66, 0.28), (-0.56, 0.28)], 0.04)
                cv.paint(pants, PANTS3, R=0.3)
                hem = 0.45 if t == 3 else 0.8
                coat = cv.smin(d - 0.07, cv.poly([(-0.66, -0.5), (0.78, -0.5), (0.9, hem), (-0.72, hem + 0.02)], 0.06), 0.15)
                coat = cv.inter(coat, cv.Y - (hem + 0.03 * np.sin(cv.X * 25)))
                if t == 3:
                    cv.paint(coat, TEGIL, R=0.5, pattern=self.quilt_pat())
                else:
                    cv.paint(coat, MAIL, R=0.5, pattern=self.mail_pat())
                if t == 5:
                    sc = cv.smin(d - 0.1, cv.poly([(-0.6, -0.5), (0.72, -0.5), (0.8, 0.12), (-0.62, 0.12)], 0.05), 0.1)
                    sc = cv.inter(sc, cv.Y - 0.12)
                    cv.paint(sc, STEEL, R=0.55, pattern=self.scale_pat(), hl=1.3)
                belt = self.band(coat + 0.02, -0.32, -0.18)
                cv.paint(belt, LEATHER, R=0.08, line=0.7)
                cv.paint(cv.ellipse((0.42, -0.25), 0.11, 0.09), GOLD if t == 5 else BRONZE, R=0.06, line=0.6, hl=1.6)

    def rope_belt(self, y):
        cv = self.cv
        belt = cv.path([(-0.55, y), (0.1, y + 0.05), (0.66, y)], 0.045)
        cv.paint(belt, hexc('B49A6A'), R=0.04, line=0.6)
        knot = cv.path([(0.4, y + 0.04), (0.44, y + 0.26), (0.4, y + 0.38)], 0.03, 0.018)
        cv.paint(knot, hexc('B49A6A'), R=0.03, line=0.5)

    def embroidery(self, d):
        cv = self.cv
        emb = 1 - 0.45 * ((np.abs(((cv.X + cv.Y) * 18) % 2 - 1) < 0.3) & (np.abs(((cv.X - cv.Y) * 18) % 2 - 1) < 0.3))
        cv.paint(d, RED, R=0.04, line=0.35, cast=False, rim=False, pattern=emb)

    # ---------------- amulet (glows on every tier) ----------------
    def amulet(self):
        cv, t, p = self.cv, self.t, self.p
        a = self.amulet_pos
        g = p['glow']
        n0 = self.torso.w((NECK[0] - 0.22, NECK[1] + 0.05))
        n1 = self.torso.w((NECK[0] + 0.28, NECK[1] + 0.05))
        cord = np.minimum(cv.path([n0, (a[0] - 0.04, a[1] - 0.09)], 0.013), cv.path([n1, (a[0] + 0.04, a[1] - 0.09)], 0.013))
        cv.ink(cord, col=hexc('3A2418'))
        rim = {1: WOOD, 2: BRONZE, 3: BRONZE, 4: GOLD, 5: GOLD}[t]
        r = 0.11 if t <= 3 else 0.15
        cv.paint(cv.circle(a, r), rim, R=0.08, line=0.7, hl=1.4)
        core = {1: 0.055, 2: 0.06, 3: 0.065, 4: 0.075, 5: 0.085}[t]
        strength = (0.7 + 0.08 * t) * g
        cv.paint(cv.circle(a, core), GOLDL, R=0.05, line=0.4, cast=False, flat=True,
                 glow=(np.array([1.0, 0.75, 0.3]), 0.12 + 0.03 * g, min(strength, 2.2)))
        if t == 1:
            for k in range(6):
                ang = k * np.pi / 3
                cv.ink(cv.seg((a[0] + 0.07 * np.cos(ang), a[1] + 0.07 * np.sin(ang)),
                              (a[0] + 0.095 * np.cos(ang), a[1] + 0.095 * np.sin(ang)), 0.008), col=hexc('5A3A22'))

    # ---------------- head ----------------
    def head_(self):
        cv, t, p = self.cv, self.t, self.p
        with self.head:
            hr = HR
            if t <= 2:  # shaggy back hair
                dbh = cv.poly([(-hr * 1.1, -hr * 0.3), (-hr * 0.3, -hr * 1.05), (hr * 0.4, -hr * 0.95),
                               (-hr * 0.2, hr * 0.6), (-hr * 1.1, hr * 0.75)], 0.08)
                cv.paint(dbh, HAIR, R=0.25, dim=0.85)
            if t == 5:  # aventail (barmitsa) over neck and shoulders, behind the beard
                bm = cv.poly([(-hr * 1.2, -hr * 0.3), (hr * 1.0, -hr * 0.3), (hr * 1.05, hr * 1.4), (hr * 0.6, hr * 2.2),
                              (-hr * 0.5, hr * 2.35), (-hr * 1.5, hr * 1.9), (-hr * 1.45, hr * 0.5)], 0.06)
                bm = cv.inter(bm, cv.Y - (hr * 2.2 + 0.035 * np.abs(np.sin(cv.X * 22))))
                cv.paint(bm, MAIL, R=0.4, pattern=self.mail_pat())
            dh = cv.smin(cv.circle((0, 0), hr), cv.ellipse((0.05, hr * 0.5), hr * 0.82, hr * 0.62), 0.1)
            cv.paint(dh, SKIN, R=0.45)
            ear = cv.ellipse((-hr * 0.62, 0.04), 0.09, 0.13, rot=0.2)
            cv.paint(ear, SKIN, R=0.08, dim=0.95)
            ex1 = (hr * 0.08, 0.02); ex2 = (hr * 0.66, 0.01)
            face = p['face']
            for ex, sc in ((ex1, 1.0), (ex2, 0.82)):
                if face == 'pain':
                    cv.ink(cv.path([(ex[0] - 0.07 * sc, ex[1] - 0.02), (ex[0], ex[1] + 0.02), (ex[0] + 0.07 * sc, ex[1] - 0.02)], 0.014))
                else:
                    cv.paint(cv.ellipse(ex, 0.075 * sc, 0.06), hexc('F2E6D6'), R=0.03, line=0.55, cast=False, rim=False, shade=False)
                    cv.flat(cv.ellipse((ex[0] + 0.022, ex[1] + 0.005), 0.038 * sc, 0.048), INK)
                    cv.flat(cv.circle((ex[0] + 0.03, ex[1] - 0.018), 0.012), hexc('FFFFFF'))
            bc = HAIR * 0.6
            fr = 0.03 if face in ('shout', 'pain') else 0.0
            cv.paint(cv.path([(ex1[0] - 0.09, ex1[1] - 0.1 + fr), (ex1[0] + 0.02, ex1[1] - 0.12), (ex1[0] + 0.1, ex1[1] - 0.08 + fr)], 0.032, 0.02),
                     bc, R=0.03, line=0.4, cast=False, rim=False)
            cv.paint(cv.path([(ex2[0] - 0.08, ex2[1] - 0.08 + fr), (ex2[0], ex2[1] - 0.12), (ex2[0] + 0.07, ex2[1] - 0.1)], 0.026, 0.016),
                     bc, R=0.03, line=0.4, cast=False, rim=False)
            self.beard(face)
            nose = cv.cone((hr * 0.42, 0.02), (hr * 0.54, 0.17), 0.05, 0.085)
            cv.paint(nose, SKIN, R=0.07, line=0.6)
            if t == 1:
                self.hair_top()
            elif t == 2:
                self.hair_top()
                ob = cv.inter(cv.circle((-0.02, 0.0), hr * 1.08), np.abs(cv.Y + hr * 0.42 + cv.X * 0.12) - 0.055)
                cv.paint(ob, LINEN, R=0.05, line=0.6)
                self.embroidery(cv.inter(ob, np.abs(cv.Y + hr * 0.42 + cv.X * 0.12) - 0.02))
            elif t == 3:
                self.hair_top(short=True)
                cap = cv.inter(cv.circle((-0.03, -0.05), hr * 1.08), cv.Y + hr * 0.3 + cv.X * 0.15)
                cv.paint(cap, LEATHER2, R=0.35)
                cv.paint(cv.inter(cap, np.abs(cv.Y + hr * 0.36 + cv.X * 0.15) - 0.06), LEATHER, R=0.05, line=0.6, cast=False)
            else:
                self.helmet(t)

    def beard(self, face):
        cv = self.cv
        hr = HR
        pts = [(-hr * 0.6, 0.05), (-hr * 0.5, hr * 1.1), (-hr * 0.05, hr * 1.65), (hr * 0.25, hr * 1.75),
               (hr * 0.55, hr * 1.45), (hr * 0.95, hr * 0.85), (hr * 0.78, 0.2), (hr * 0.4, 0.32), (-hr * 0.3, 0.2)]
        d = cv.poly(pts, 0.05)
        strands = 1 - 0.16 * np.clip(np.sin((cv.X * 3 - cv.Y * 0.4) * 22 + cv.n_mid * 6), 0, 1)
        cv.paint(d, HAIR, R=0.25, pattern=strands)
        mx, my = hr * 0.45, hr * 0.62
        if face == 'shout':
            cv.paint(cv.ellipse((mx, my + 0.1), 0.1, 0.08), hexc('3A1418'), R=0.04, line=0.5, cast=False, rim=False, shade=False)
        mu = cv.path([(mx - 0.22, my + 0.08), (mx - 0.05, my - 0.02), (mx + 0.04, my - 0.02), (mx + 0.2, my + 0.06)], 0.035, 0.03)
        cv.paint(mu, HAIR * 1.08, R=0.04, line=0.55)

    def hair_top(self, short=False):
        cv = self.cv
        hr = HR
        tufts = []
        n = 9
        for i in range(n + 1):
            a = np.pi * (1.05 + 0.95 * i / n)
            rr = hr * ((1.1 if i % 2 == 0 else 1.3) if not short else 1.12)
            tufts.append((np.cos(a) * rr, -0.05 + np.sin(a) * rr))
        tufts += [(hr * 0.95, -hr * 0.2), (hr * 0.55, -hr * 0.48), (hr * 0.25, -hr * 0.3),
                  (-hr * 0.05, -hr * 0.5), (-hr * 0.4, -hr * 0.2), (-hr * 0.65, hr * 0.35), (-hr * 1.0, hr * 0.5)]
        d = cv.poly(tufts, 0.04)
        strands = 1 - 0.14 * np.clip(np.sin((cv.X * 2 + cv.Y) * 26 + cv.n_mid * 5), 0, 1)
        cv.paint(d, HAIR, R=0.3, pattern=strands)

    def helmet(self, t):
        cv = self.cv
        hr = HR
        top = -hr * (2.15 if t == 5 else 1.75)
        dome = cv.poly([(-hr * 1.1, -hr * 0.25), (-hr * 0.95, -hr * 0.95), (-hr * 0.45, -hr * 1.35), (0.02, top),
                        (hr * 0.5, -hr * 1.35), (hr * 1.0, -hr * 0.95), (hr * 1.12, -hr * 0.25)], 0.05)
        cv.paint(dome, STEEL, R=0.45, hl=1.4)
        cv.ink(cv.path([(0.02, top + 0.05), (0.06, -hr * 0.9), (0.08, -hr * 0.35)], 0.012), alpha=0.5)
        rim = cv.inter(dome, np.abs(cv.Y + hr * 0.34) - 0.075)
        if t == 5:
            orn = 1 - 0.3 * (np.abs(((cv.X * 11) % 2) - 1) > 0.55)
            cv.paint(rim, GOLD, R=0.07, line=0.7, pattern=orn, hl=1.5)
            cv.paint(cv.circle((0.02, top - 0.04), 0.06), GOLD, R=0.05, line=0.6)
        else:
            cv.paint(rim, STEEL * 0.85, R=0.07, line=0.7)

    # ---------------- legs ----------------
    def leg(self, side):
        cv, t = self.cv, self.t
        hip, knee, ank, pitch = self.legs[side]
        dim = 0.86 if side == 'F' else 1.0
        kd = knee - hip; kd = kd / max(np.hypot(*kd), 1e-6)
        sd = ank - knee; sd = sd / max(np.hypot(*sd), 1e-6)
        fwd = rot(np.array([1.0, 0.0]), pitch * 0.6)
        toe = ank + rot(np.array([0.36, 0.07]), pitch)
        heel = ank + rot(np.array([-0.08, 0.06]), pitch)
        # thigh with a front bulge, knee, calf with a back bulge
        th = cv.cone(hip, knee, 0.28, 0.18)
        th = cv.smin(th, cv.ellipse(hip + kd * 0.38 + rot(kd, -np.pi / 2) * -0.06, 0.3, 0.22, rot=np.arctan2(kd[1], kd[0])), 0.06)
        calf = cv.cone(knee, ank, 0.18, 0.1)
        nrm = rot(sd, np.pi / 2)  # points to the back of the leg when sd points down
        calf = cv.smin(calf, cv.ellipse(knee + sd * 0.27 + nrm * 0.05, 0.27, 0.15, rot=np.arctan2(sd[1], sd[0])), 0.06)
        foot = cv.smin(cv.cone(heel, toe, 0.1, 0.09), cv.circle(ank + (0, 0.0), 0.11), 0.05)
        if t == 1:
            cv.paint(calf, SKIN, R=0.2, dim=dim)
            wr = 1 - 0.25 * np.clip(np.sin((cv.Y + cv.X * 0.45) * 38), 0, 1)
            wraps = cv.smin(cv.cone(knee + sd * 0.38, ank, 0.17, 0.12), foot + 0.01, 0.05)
            cv.paint(wraps, WRAP, R=0.18, dim=dim, pattern=wr, line=0.8)
            hem = knee + sd * 0.14
            pant = cv.smin(cv.cone(hip, knee, 0.31, 0.22), cv.cone(knee, hem, 0.22, 0.24), 0.05)
            teeth = 0.05 * np.abs(np.sin((cv.X - cv.Y) * 26))
            pant = cv.inter(pant, (cv.X - hem[0]) * sd[0] + (cv.Y - hem[1]) * sd[1] - teeth)
            cv.paint(pant, CANVAS, R=0.3, dim=dim)
        elif t == 2:
            cv.paint(cv.smin(cv.cone(knee, ank, 0.2, 0.13), calf - 0.02, 0.05), ONUCHI, R=0.2, dim=dim,
                     pattern=1 - 0.2 * np.clip(np.sin((cv.Y - cv.X * 0.5) * 30), 0, 1))
            straps = cv.inter(cv.smin(cv.cone(knee, ank, 0.21, 0.14), calf - 0.01, 0.05), np.abs(np.sin((cv.Y + cv.X * 0.8) * 11)) - 0.12)
            cv.paint(straps, LEATHER2, R=0.03, line=0.35, cast=False, rim=False, dim=dim)
            weave = 1 - 0.3 * ((np.abs(((cv.X + cv.Y) * 22) % 2 - 1) < 0.3) ^ (np.abs(((cv.X - cv.Y) * 22) % 2 - 1) < 0.3))
            cv.paint(foot - 0.01, LAPTI, R=0.12, dim=dim, pattern=weave)
            cv.paint(cv.smin(th, cv.cone(hip, knee, 0.3, 0.2), 0.04), CANVAS, R=0.3, dim=dim)
        else:
            cv.paint(cv.smin(th, cv.cone(hip, knee, 0.3, 0.2), 0.04), PANTS3, R=0.3, dim=dim)
            boot = cv.smin(cv.cone(knee + sd * 0.02, ank, 0.22, 0.15), calf - 0.035, 0.05)
            boot = cv.smin(boot, foot - 0.025, 0.05)
            cv.paint(boot, LEATHER, R=0.22, dim=dim)
            cv.paint(cv.inter(boot, np.abs((cv.X - knee[0]) * sd[0] + (cv.Y - knee[1]) * sd[1] - 0.05) - 0.05), LEATHER * 0.8, R=0.04, line=0.5, cast=False, dim=dim)
            if t >= 4:
                fr = rot(sd, -np.pi / 2)  # front of the shin
                gr = cv.cone(knee + sd * 0.14 + fr * 0.08, ank - sd * 0.15 + fr * 0.06, 0.13, 0.1)
                cv.paint(gr, STEEL, R=0.15, dim=dim, hl=1.3)
                if t == 5:
                    cv.paint(cv.circle(knee + fr * 0.08, 0.16), STEEL, R=0.15, dim=dim, hl=1.3)
                    cv.paint(cv.inter(gr, -(gr + 0.04)), GOLD, R=0.03, line=0.4, cast=False, rim=False, dim=dim)

    # ---------------- arms and hands ----------------
    def arm(self, side):
        cv, t, p = self.cv, self.t, self.p
        sh, el, wr, fist, fd = self.arms[side]
        dim = 0.84 if side == 'F' else 1.0
        ud = el - sh; ud = ud / max(np.hypot(*ud), 1e-6)
        ua = np.arctan2(ud[1], ud[0]); fa = np.arctan2(fd[1], fd[0])
        # deltoid cap + biceps + tapered upper arm
        up = cv.cone(sh + ud * 0.05, el, 0.22 * AK, 0.15 * AK)
        up = cv.smin(up, cv.ellipse(sh + ud * 0.12, 0.3 * AK, 0.24 * AK, rot=ua), 0.08)
        up = cv.smin(up, cv.ellipse(sh + ud * 0.45 + rot(ud, np.pi / 2) * 0.04, 0.26 * AK, 0.17 * AK, rot=ua), 0.06)
        # forearm: fat near the elbow, slim wrist
        fo = cv.cone(el, wr, 0.16 * AK, 0.1 * AK)
        fo = cv.smin(fo, cv.ellipse(el + fd * 0.2, 0.25 * AK, 0.16 * AK, rot=fa), 0.06)
        sleeve_up = {1: None, 2: LINEN, 3: TEGIL, 4: MAIL, 5: MAIL}[t]
        if sleeve_up is None:
            cv.paint(up, SKIN, R=0.25, dim=dim)
            cv.ink(cv.path([sh + ud * 0.28 + rot(ud, -np.pi / 2) * 0.12, sh + ud * 0.36 + rot(ud, -np.pi / 2) * 0.02], 0.01), alpha=0.45)
        else:
            pat = self.mail_pat() if t >= 4 else (self.quilt_pat() if t == 3 else 1 - 0.1 * np.clip(np.sin(cv.X * 16 + cv.Y * 9), 0, 1))
            cv.paint(up - 0.03, sleeve_up, R=0.25, dim=dim, pattern=pat)
        if t >= 5:
            pl = cv.ellipse(sh + ud * 0.06, 0.34 * AK, 0.26 * AK, rot=ua)
            cv.paint(pl, STEEL, R=0.3, dim=dim, hl=1.3)
            cv.paint(cv.inter(pl, -(pl + 0.05)), GOLD, R=0.04, line=0.4, cast=False, rim=False, dim=dim)
        cv.paint(fo if t != 2 else fo - 0.02, SKIN if t != 2 else LINEN, R=0.22, dim=dim)
        if t >= 2:
            br0 = el + fd * (0.22 if t >= 3 else 0.18)
            br = cv.cone(br0, wr + fd * 0.02, 0.17 * AK, 0.13 * AK)
            col = {2: LEATHER2, 3: LEATHER, 4: STEEL, 5: STEEL}[t]
            pat = (1 - 0.25 * np.clip(np.sin((cv.X * np.cos(fa) + cv.Y * np.sin(fa)) * 40), 0, 1)) if t == 2 else None
            cv.paint(br, col, R=0.18, dim=dim, hl=1.3 if t >= 4 else 1.0, pattern=pat)
            if t == 3:
                for kk in (0.3, 0.65):
                    cv.paint(cv.circle(br0 + (wr - br0) * kk, 0.045), BRONZE, R=0.03, line=0.4, cast=False, dim=dim, hl=1.5)
            if t == 5:
                cv.paint(cv.inter(cv.cone(wr - fd * 0.06, wr + fd * 0.02, 0.16 * AK, 0.16 * AK), br - 0.0), GOLD, R=0.03, line=0.4, cast=False, rim=False, dim=dim)
        if p['handF'] == 'open' and side == 'F':
            self.open_hand(wr, fd, dim)
        else:
            self.fist(wr, fd, dim, side)
        if side == 'N':
            self.thread(wr, fd)

    def fist(self, wr, fd, dim, side):
        cv = self.cv
        c = wr + fd * 0.13 * HK
        n = rot(fd, -np.pi / 2)  # thumb side
        L, W = 0.14 * HK, 0.13 * HK
        pts = [c - fd * L - n * W, c + fd * L - n * W * 0.9, c + fd * L + n * W * 0.9, c - fd * L + n * W]
        d = cv.poly([tuple(q) for q in pts], 0.06)
        cv.paint(d, SKIN, R=0.12, dim=dim)
        for kk in (-0.45, 0.0, 0.45):  # finger separations along the knuckles
            a = c + fd * L * 0.9 + n * W * kk
            cv.ink(cv.seg(a - fd * 0.1, a - fd * 0.02, 0.009), alpha=0.75)
        th = cv.cone(c - fd * L * 0.4 - n * W * 0.9, c + fd * L * 0.3 - n * W * 0.55, 0.06, 0.05)
        cv.paint(th, SKIN, R=0.05, dim=dim * 0.97, line=0.6, cast=False)

    def open_hand(self, wr, fd, dim):
        cv = self.cv
        c = wr + fd * 0.1
        n = rot(fd, -np.pi / 2)
        palm = cv.ellipse(c, 0.13 * HK, 0.12 * HK, rot=np.arctan2(fd[1], fd[0]))
        fingers = None
        for kk, ang in ((-0.6, -0.25), (-0.2, -0.08), (0.2, 0.08), (0.6, 0.22)):
            base = c + fd * 0.08 + n * 0.08 * kk
            tip = base + rot(fd, ang) * 0.17
            f = cv.cone(base, tip, 0.04, 0.032)
            fingers = f if fingers is None else np.minimum(fingers, f)
        thumb = cv.cone(c - n * 0.08, c - n * 0.2 + fd * 0.08, 0.045, 0.035)
        cv.paint(np.minimum(fingers, thumb), SKIN, R=0.04, dim=dim, line=0.7)
        cv.paint(palm, SKIN, R=0.1, dim=dim)

    def thread(self, wr, fd):
        """Mokosh red thread on the near wrist, over the bracer (bible §5.6 p.2)."""
        cv, p = self.cv, self.p
        col = RED * 1.15 * (1 - p['thread']) + SILVER * p['thread']
        n = rot(fd, -np.pi / 2)
        a = wr - fd * 0.02
        ring = cv.cone(a - n * 0.15, a + n * 0.15, 0.04, 0.04)
        cv.paint(ring, col, R=0.03, line=0.5, cast=False, rim=False, hl=1.5,
                 glow=(SILVER, 0.08, 0.6) if p['thread'] > 0.2 else None)
        ends = np.minimum(cv.path([a + n * 0.12, a + n * 0.2 - fd * 0.1, a + n * 0.2 - fd * 0.22], 0.022, 0.012),
                          cv.path([a + n * 0.1, a + n * 0.26 - fd * 0.05, a + n * 0.32 - fd * 0.14], 0.02, 0.01))
        cv.paint(ends, col, R=0.03, line=0.45, cast=False, rim=False)


def to_px(pt):
    """Unit point -> final cell pixel."""
    return ((pt[0] - X0) * S_RENDER / DOWN, (pt[1] - Y0) * S_RENDER / DOWN)


def render(tier, pose, seed=11):
    """RGBA cell image, the near fist and the amulet in cell px."""
    from PIL import Image
    h = Drawn(tier, pose, seed)
    cv = h.build()
    img = cv.image(DOWN)
    hand, amu = to_px(h.hand), to_px(h.amulet_pos)
    ang = h.p['rot']
    if ang:
        # pad first: rotated parts must not be cut by the cell edge before they rest on the ground
        P = 160
        big = Image.new('RGBA', (img.size[0] + 2 * P, img.size[1] + 2 * P), (0, 0, 0, 0))
        big.paste(img, (P, P))
        piv = to_px(h.p['pivot'])
        big = big.rotate(ang, resample=Image.BICUBIC, center=(piv[0] + P, piv[1] + P))
        th = np.radians(ang)

        def rp(q):
            dx, dy = q[0] - piv[0], q[1] - piv[1]
            return (piv[0] + dx * np.cos(th) + dy * np.sin(th), piv[1] - dx * np.sin(th) + dy * np.cos(th))
        hand, amu = rp(hand), rp(amu)
        dy = 0
        if h.p.get('rest'):  # rotated poses lie on the ground, not through it
            a = np.asarray(big)[..., 3]
            ys = np.where(a.max(axis=1) > 128)[0]
            if len(ys):
                dy = int(round(to_px((0.0, 0.0))[1] + P - ys.max() - 1))
        img = big.crop((P, P - dy, P + img.size[0], P - dy + img.size[1]))
        hand, amu = (hand[0], hand[1] + dy), (amu[0], amu[1] + dy)
    return img, [round(float(hand[0]), 1), round(float(hand[1]), 1)], [round(float(amu[0]), 1), round(float(amu[1]), 1)]

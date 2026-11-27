"""Shared rig helpers of the hand-drawn Застава NPCs (same style as the hero).

Reuses the hero pipeline by import (tools/asset-pipeline/hero2d): sdf2d.Canvas
(ink outline #120D12, 3-tone shading, painterly noise, warm rim light) and
rig.ik / rig.rot / rig.Frame. Nothing is copied.

Units: 1 unit = 24 world px (the hero's head-height unit; the drawn hero is
~4.5 units). NPC sheets are drawn at the hero's 2x density: SHEET_PX = 48
sheet px per unit = 2 sheet px per world px. y grows downward, the ground under
the feet is y = 0, the NPC faces +x (toward the hero; Godot mirrors it).

Each NPC is a subclass of Npc with layers() (ordered draw functions) and
anims() -> {name: (poses, fps, loop)}. A pose is a dict merged over BASE.
"""
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'hero2d'))
from sdf2d import Canvas, hexc, INK  # noqa: E402,F401
from rig import ik, rot, Frame  # noqa: E402,F401

UNIT_WORLD = 24.0
S_RENDER = 96
DOWN = 2
SHEET_PX = S_RENDER / DOWN            # 48 sheet px per unit
PX_PER_WORLD = SHEET_PX / UNIT_WORLD  # 2.0
TAU = 2 * np.pi

EYEW = hexc('F2E6D6')
MOUTH = hexc('3A1418')
LINEN = hexc('E9DFC9')
RED = hexc('B3262E')
GOLD = hexc('C8902E')
GOLDL = hexc('FFC94A')
EMBER = hexc('FF9A3C')


def lerp(a, b, k):
    return np.asarray(a, float) * (1 - k) + np.asarray(b, float) * k


def ease(k):
    return 0.5 - 0.5 * np.cos(np.pi * np.clip(k, 0, 1))


def bump(t, a, b):
    """0 outside [a, b], a smooth 0-1-0 hump inside."""
    if t <= a or t >= b:
        return 0.0
    return float(np.sin(np.pi * (t - a) / (b - a)))


def cyc(n, fn):
    """n poses of a loop, t in [0, 1)."""
    return [fn(i / n) for i in range(n)]


def seq(n, fn):
    """n poses of a one-shot, t in [0, 1]."""
    return [fn(i / max(n - 1, 1)) for i in range(n)]


def V(*a):
    return np.array(a, float)


class Npc:
    """One NPC frame. Subclasses set BOUNDS, PORTRAIT, BASE, layers(), anims()."""
    BOUNDS = (-3.0, 3.0, -5.0, 0.3)
    PORTRAIT = (0.0, -3.5, 1.2)   # bust centre x, y and half size, units
    BASE = {}
    OUTLINE = 1.9
    FLIP = True                    # mirrored by Godot to face the hero

    def __init__(self, pose, bounds=None, S=S_RENDER, seed=7):
        self.p = dict(self.BASE)
        self.p.update(pose)
        x0, x1, y0, y1 = bounds or self.BOUNDS
        self.cv = Canvas(x0, x1, y0, y1, S, seed=seed)
        self.setup()

    def setup(self):
        pass

    def layers(self):
        return []

    def build(self):
        for fn in self.layers():
            fn()
        self.cv.outer_outline(self.OUTLINE)
        return self.cv

    # ---------------- shared drawing helpers ----------------
    def P(self, d, col, **kw):
        self.cv.paint(d, np.asarray(col, float), **kw)

    def deco(self, d, col, alpha=1.0, line=0.0):
        """Flat-ish decoration that does not change the silhouette."""
        self.cv.paint(d, np.asarray(col, float), R=0.04, line=line, shade=False, rim=False, cast=False,
                      union=False, alpha=alpha)

    def limb(self, a, t, l1, l2, r1, r2, hint):
        """Two-bone limb SDF (IK): sdf, joint, end."""
        cv = self.cv
        j, e = ik(a, t, l1, l2, hint)
        rm = (r1 + r2) * 0.5
        d = cv.smin(cv.cone(a, j, r1, rm), cv.cone(j, e, rm, r2), 0.04)
        return d, j, e

    def eye(self, c, rx, ry, look=(0.0, 0.0), lid=0.0, skin=None, iris=None, glow=0.0, slit=False,
            happy=False, lw=0.018):
        """Hero-style eye: white, dark pupil (or a coloured iris), highlight, a lid that
        closes from the top (lid 0..1), happy = closed upturned arc."""
        cv = self.cv
        c = np.asarray(c, float)
        if happy:
            cv.ink(cv.path([c + (-rx, ry * 0.25), c + (0, -ry * 0.55), c + (rx, ry * 0.25)], lw, lw * 0.8))
            return
        if lid >= 0.88:
            cv.ink(cv.path([c + (-rx, -ry * 0.05), c + (0, ry * 0.35), c + (rx, -ry * 0.05)], lw, lw * 0.8))
            return
        d = cv.ellipse(c, rx, ry)
        cv.paint(d, EYEW, R=0.03, line=0.55, cast=False, rim=False, shade=False, union=False)
        pc = c + (look[0] * rx * 0.4, look[1] * ry * 0.35)
        if iris is not None:
            ir = min(rx, ry) * 0.8
            cv.paint(cv.inter(cv.circle(pc, ir), d), np.asarray(iris, float), R=0.03, line=0.3, cast=False,
                     rim=False, shade=False, union=False,
                     glow=(np.asarray(iris, float), 0.03, 0.22 * glow) if glow else None)
            pup = cv.ellipse(pc, ir * (0.22 if slit else 0.45), ir * (0.85 if slit else 0.45))
            cv.flat(cv.inter(pup, d), INK)
        else:
            cv.flat(cv.inter(cv.ellipse(pc + (rx * 0.1, 0.0), rx * 0.5, ry * 0.78), d), INK)
        cv.flat(cv.circle(pc + (rx * 0.18, -ry * 0.3), min(rx, ry) * 0.2), hexc('FFFFFF'))
        if lid > 0.02 and skin is not None:
            cut = c[1] - ry + 2 * ry * lid
            ld = cv.inter(d - 0.006, cv.Y - cut)
            cv.paint(ld, np.asarray(skin, float), R=0.03, line=0.5, cast=False, rim=False, shade=False,
                     union=False)

    def mouth(self, c, w, m=0.0, smile=0.0, col=MOUTH, teeth=False):
        """Mouth: a line (m ~ 0, smile bends it up) or an open dark oval (m 0..1)."""
        cv = self.cv
        c = np.asarray(c, float)
        if m < 0.08:
            cv.ink(cv.path([c + (-w, -smile * w * 0.35), c + (0, smile * w * 0.25), c + (w, -smile * w * 0.35)],
                           0.017, 0.014))
            return
        d = cv.ellipse(c + (0, m * w * 0.25), w * (0.8 + 0.15 * smile), w * 0.12 + m * w * 0.42)
        cv.paint(d, col, R=0.03, line=0.5, cast=False, rim=False, shade=False, union=False)
        if teeth:
            for sx in (-0.45, 0.45):
                t = cv.poly([c + (sx * w - 0.04, -0.005 * w), c + (sx * w + 0.04, -0.005 * w),
                             c + (sx * w, m * w * 0.28)])
                cv.flat(cv.inter(t, d), EYEW)

    def embroidery(self, band, y, period=0.16, size=0.05, col=RED, alpha=0.95):
        """Red folk cross-stitch diamonds along a band (clipped to it)."""
        cv = self.cv
        u = np.mod(cv.X, period) - period * 0.5
        dia = np.abs(u) + np.abs(cv.Y - y) - size
        dot = np.hypot(u, cv.Y - y) - size * 0.3
        d = cv.inter(cv.sub(dia, dot), band)
        cv.flat(d, np.asarray(col, float), alpha=alpha)

    def fur(self, k=14.0, amt=0.16):
        cv = self.cv
        return 1 - amt * np.clip(np.sin((cv.X * 2.0 + cv.Y * 5.0) * k + cv.n_mid * 9), 0, 1)

    def grain(self, k=26.0, amt=0.2):
        cv = self.cv
        return 1 - amt * np.clip(np.sin(cv.X * k + np.sin(cv.Y * 3.0) * 1.5 + cv.n_mid * 10), 0, 1)

    def spark(self, c, r, col=GOLDL, k=1.0):
        cv = self.cv
        cv.paint(cv.circle(c, r), np.minimum(np.asarray(col, float) * 1.2 + 0.1, 1), R=0.02, line=0, shade=False,
                 rim=False, cast=False, union=False, glow=(np.asarray(col, float), 0.05 + r, 0.45 * k))

    def flame(self, base, h, w, sway, col_out=EMBER, col_in=GOLDL):
        cv = self.cv
        b = np.asarray(base, float)
        tip = b + (sway, -h)
        d = cv.smin(cv.ellipse(b + (0, -w * 0.4), w, w * 0.8), cv.cone(b + (0, -w * 0.5), tip, w * 0.8, 0.01), 0.08)
        cv.paint(d, col_out, R=0.05, line=0, shade=False, rim=False, cast=False, union=False,
                 glow=(np.asarray(col_out, float), 0.18, 0.35))
        d2 = cv.smin(cv.ellipse(b + (0, -w * 0.3), w * 0.5, w * 0.45),
                     cv.cone(b + (0, -w * 0.4), b + (sway * 0.6, -h * 0.6), w * 0.45, 0.01), 0.06)
        cv.paint(d2, col_in, R=0.05, line=0, shade=False, rim=False, cast=False, union=False)


def to_px(cls, pt):
    x0, _, y0, _ = cls.BOUNDS
    return ((pt[0] - x0) * SHEET_PX, (pt[1] - y0) * SHEET_PX)


def render(cls, pose, seed=7):
    """RGBA sheet cell of one frame."""
    return cls(pose, seed=seed).build().image(DOWN)


def render_portrait(cls, pose, size=512, seed=7):
    """Square bust (size px) around cls.PORTRAIT, rendered at 2x and downsampled."""
    cx, cy, h = cls.PORTRAIT
    S = int(round(size * 2 / (2 * h)))
    b = cls(pose, bounds=(cx - h, cx + h, cy - h, cy + h), S=S, seed=seed)
    img = b.build().image(2)
    return img.resize((size, size), Image.LANCZOS) if img.size != (size, size) else img

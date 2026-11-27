"""Shared rig and renderer of the hand-drawn enemies (same style as the hero).

Reuses the hero pipeline modules by import (tools/asset-pipeline/hero2d):
sdf2d.Canvas (ink outline #120D12, 3-tone shading, painterly noise, warm rim
light) and rig.ik / rig.rot (2D two-bone IK). Nothing is copied.

Units: 1 unit = UNIT_WORLD world px (the hero's head-height unit: the drawn
hero is ~4.5 units = 107 world px = 160 screen px at 1080p). Enemy sheets are
1x (art bible: only the hero, bosses and icons are drawn at 2x): SHEET_PX
sheet px per unit = 1.5 sheet px per world px = 1 screen px at camera zoom 1.5.
y grows downward, the ground under the feet is y = 0, the enemy faces +x.

Each kind is a subclass of Body with layers(): an ordered list of
(tag, draw_fn); tag 'arm' / 'head' marks the severable parts
(assets/data/limb_zones.json). render() paints a frame in one of the modes:
full, noarm (arm skipped, a stump painted), nohead, noboth, or 'arm' / 'head'
(only that part: the cut-out sprite of the flying piece).
"""
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'hero2d'))
from sdf2d import Canvas, hexc, INK  # noqa: E402,F401
from rig import ik, rot  # noqa: E402,F401

UNIT_WORLD = 24.0
S_RENDER = 72
DOWN = 2
SHEET_PX = S_RENDER / DOWN            # sheet px per unit
PX_PER_WORLD = SHEET_PX / UNIT_WORLD  # 1.5

# shared enemy colours (art bible §4: threat rust, Nav magenta, ink)
RUST = hexc('C2502A')
RUST_D = hexc('9E3A1C')
MAG = hexc('D23A9A')
MAG_D = hexc('A3206F')
ROT = hexc('B6E36B')       # rot-glow: only on tina and sedge
BLOOD = hexc('6E0E16')
STUMP = hexc('8E1C22')


def W(px):
    """World px -> units."""
    return px / UNIT_WORLD


def lerp(a, b, k):
    return np.asarray(a, float) * (1 - k) + np.asarray(b, float) * k


def ease(k):
    return 0.5 - 0.5 * np.cos(np.pi * np.clip(k, 0, 1))


def unit(v):
    v = np.asarray(v, float)
    return v / max(np.hypot(*v), 1e-6)


class Body:
    """One enemy frame. Subclasses set BOUNDS, BASE and implement layers()."""
    BOUNDS = (-3.0, 3.0, -4.0, 0.5)   # x0, x1, y0, y1 in units
    BASE = {}
    OUTLINE = 1.9
    ARM_ROOT = 'arm_root'   # attribute holding the shoulder point (stump, part pivot)
    NECK = 'neck'           # attribute holding the neck point

    def __init__(self, pose, mode='full', seed=7):
        self.p = dict(self.BASE)
        self.p.update(pose)
        self.mode = mode
        x0, x1, y0, y1 = self.BOUNDS
        self.cv = Canvas(x0, x1, y0, y1, S_RENDER, seed=seed)
        self.setup()

    # subclasses
    def setup(self):
        pass

    def layers(self):
        return []

    # helpers shared by the kinds
    def eyes(self, pts, r, col, glow=1.0, slit=False, ang=0.0):
        cv = self.cv
        for c in pts:
            if slit:
                d = cv.ellipse(c, r * 1.5, r * 0.45, rot=ang)
            else:
                d = cv.circle(c, r)
            cv.paint(d, col * (0.8 + 0.4 * min(glow, 1.5)), R=0.02, line=0.0, shade=False, rim=False, cast=False,
                     union=False, glow=(col, 0.03 + 0.015 * min(glow, 2.0), 0.3 * min(glow, 2.0)))
            cv.flat(cv.circle(np.asarray(c) + (r * 0.25, -r * 0.25), r * 0.32), np.minimum(col * 1.5 + 0.2, 1), alpha=0.8)

    def crack(self, pts, w=0.016, alpha=0.7):
        self.cv.ink(self.cv.path(pts, w, w * 0.4), alpha=alpha)

    def strands(self, roots, length, col, sway=0.0, w=0.07, drip=1.0, line=0.6, dim=1.0, rotk=False):
        """Tina / hair strands hanging from roots (dripping down, swaying)."""
        cv = self.cv
        d = None
        for i, r in enumerate(roots):
            ln = length[i] if hasattr(length, '__len__') else length
            sw = sway * (1 + 0.3 * np.sin(i * 2.1))
            pts = [r, (r[0] + sw * 0.3 - 0.04, r[1] + ln * 0.35), (r[0] + sw * 0.7, r[1] + ln * 0.7), (r[0] + sw, r[1] + ln * drip)]
            di = cv.path(pts, w * (1 + 0.25 * np.sin(i * 1.7)), w * 0.35)
            d = di if d is None else np.minimum(d, di)
        if d is not None:
            cv.paint(d, col, R=0.06, line=line, dim=dim, cast=False)
            if rotk:
                for i, r in enumerate(roots[::3]):
                    cv.paint(cv.circle((r[0] + 0.02, r[1] + 0.25), 0.03), ROT, R=0.02, line=0, shade=False,
                             rim=False, cast=False, union=False, glow=(ROT, 0.04, 0.35))

    def stump(self, at, n, r):
        """Cut face: dark red ellipse with a bone dot, n = normal of the cut."""
        cv = self.cv
        ang = np.arctan2(n[1], n[0])
        cv.paint(cv.ellipse(at, r * 0.45, r, rot=ang), STUMP, R=0.05, line=0.7, cast=False, rim=False)
        cv.flat(cv.circle(at, r * 0.28), hexc('E9DFC9'), alpha=0.8)
        cv.flat(cv.ellipse(np.asarray(at) + np.asarray(n) * r * 0.5, r * 0.15, r * 0.3, rot=ang), BLOOD, alpha=0.9)

    def stump_n(self, key):
        """Normal of the cut at a stump: subclasses may override."""
        return (1.0, -0.4) if key == 'arm' else (0.0, -1.0)

    def build(self):
        m = self.mode
        for tag, fn in self.layers():
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
        self.cv.outer_outline(self.OUTLINE)
        return self.cv


def to_px(cls, pt):
    x0, _, y0, _ = cls.BOUNDS
    return ((pt[0] - x0) * SHEET_PX, (pt[1] - y0) * SHEET_PX)


def render(cls, pose, mode='full', seed=7):
    """RGBA cell image of one frame. Pose keys applied after painting:
    rot (deg, about pivot), dx/dy (units), rest (drop onto the ground after
    rotating), clip (units: erase below this y, sinking into the bog), fade."""
    b = cls(pose, mode, seed)
    img = b.build().image(DOWN)
    p = b.p
    ang = p.get('rot', 0.0)
    if ang:
        P = 120
        big = Image.new('RGBA', (img.size[0] + 2 * P, img.size[1] + 2 * P), (0, 0, 0, 0))
        big.paste(img, (P, P))
        pv = to_px(cls, p.get('pivot', (0.0, 0.0)))
        big = big.rotate(ang, resample=Image.BICUBIC, center=(pv[0] + P, pv[1] + P))
        dy = 0
        if p.get('rest'):
            a = np.asarray(big)[..., 3]
            ys = np.where(a.max(axis=1) > 128)[0]
            if len(ys):
                dy = int(round(to_px(cls, (0.0, 0.0))[1] + P - ys.max() - 1 + p.get('rest_sink', 0.0) * SHEET_PX))
        img = big.crop((P, P - dy, P + img.size[0], P - dy + img.size[1]))
    if p.get('dx') or p.get('dy'):
        out = Image.new('RGBA', img.size, (0, 0, 0, 0))
        out.paste(img, (int(round(p.get('dx', 0) * SHEET_PX)), int(round(p.get('dy', 0) * SHEET_PX))))
        img = out
    if p.get('clip') is not None or p.get('fade', 1.0) < 1.0:
        a = np.asarray(img).astype(np.float32)
        if p.get('clip') is not None:
            cy = to_px(cls, (0.0, p['clip']))[1]
            ys = np.arange(a.shape[0])[:, None]
            a[..., 3] *= np.clip((cy - ys) / 3.0, 0, 1)
        a[..., 3] *= p.get('fade', 1.0)
        img = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), 'RGBA')
    return img


def part_pivot(cls, pose, limb):
    """Sheet px of the arm root / neck for the cut-out part sprite."""
    b = cls(pose, 'full')
    pt = getattr(b, b.ARM_ROOT if limb == 'arm' else b.NECK)
    return to_px(cls, pt)

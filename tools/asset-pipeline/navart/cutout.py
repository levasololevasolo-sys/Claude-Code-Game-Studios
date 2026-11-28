"""Cut-out puppet renderer for the approved «Навь» character sheets: the parts
cut by prepare.py (head, torso, arms, hands, legs, cape) are pinned on the
drawn hero's skeleton (tools/asset-pipeline/hero2d/rig.py: same joints, same
two-bone IK, same poses.py animations) and composited per frame.

A character is a dict of parts; every part names its piece of the sheet
(assets/art/navart/<group>/<sheet>/NN.webp) and its joints as fractions of the
piece's box (x, y; 0..1). A limb piece is split at `split` into an upper and a
lower segment (the lower one drawn over the upper, so the elbow / knee bends
without a gap). The scale comes from the legs: hip-to-ankle in the art equals
THIGH + SHIN of the rig.

    render(char, pose) -> (RGBA 320x288 cell, hand px, amulet px)

Used by hero.py (hero and skins); deterministic.
"""
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
sys.path.insert(0, os.path.join(REPO, 'tools', 'asset-pipeline', 'hero2d'))
from rig import (AMU, BASE_POSE, FIST, HIP_F, HIP_N, NECK, SH_F, SH_N, SHIN, THIGH, X0, X1, Y0, Y1,  # noqa: E402
                 ik, rot)

SRC = os.path.join(REPO, 'assets', 'art', 'navart')
PX = 100.0  # render px per unit (2x the 50 px/unit cell)
CELL = (320, 288)
_cache = {}


def piece(group, sheet, i):
    k = (group, sheet, i)
    if k not in _cache:
        _cache[k] = Image.open(os.path.join(SRC, group, sheet, '%02d.webp' % i)).convert('RGBA')
    return _cache[k]


def _pt(im, f):
    return np.array([f[0] * im.width, f[1] * im.height], float)


class Part:
    """An image with two joints in its own px (a = root, b = tip)."""

    def __init__(self, im, a, b):
        self.im, self.a, self.b = im, np.asarray(a, float), np.asarray(b, float)


def split_limb(im, top, bot, split, overlap=0.06):
    """(upper, lower) Parts of a straight limb piece cut at `split` of its height."""
    h = im.height
    ys = int(h * split)
    o = int(h * overlap)
    a, b = _pt(im, top), _pt(im, bot)
    mid = a + (b - a) * ((ys - a[1]) / max(b[1] - a[1], 1e-6))
    up = im.crop((0, 0, im.width, min(h, ys + o)))
    lo = im.crop((0, max(0, ys - o), im.width, h))
    # feather the upper segment's cut so the seam under the lower one is soft
    ua = np.asarray(up).astype(np.float32)
    ramp = np.clip((up.height - np.arange(up.height)) / max(o, 1), 0, 1)
    ua[..., 3] *= ramp[:, None]
    up = Image.fromarray(ua.astype(np.uint8), 'RGBA')
    return Part(up, a, mid), Part(lo, mid - (0, max(0, ys - o)), b - (0, max(0, ys - o)))


def place(canvas, part, j0, j1, g, stretch=(0.82, 1.22)):
    """Draws `part` so its root sits on unit point j0 and it points at j1:
    scale g across, along fitted to the bone (clamped to `stretch` x g)."""
    ds = part.b - part.a
    dt = (np.asarray(j1, float) - np.asarray(j0, float)) * PX
    ls, lt = max(np.hypot(*ds), 1e-6), np.hypot(*dt)
    sa = np.clip(lt / ls, stretch[0] * g, stretch[1] * g) if lt > 1e-6 else g
    ang = (np.arctan2(dt[1], dt[0]) if lt > 1e-6 else np.arctan2(ds[1], ds[0])) - np.arctan2(ds[1], ds[0])
    # source frame: u along the bone, v across
    us = ds / ls
    vs = np.array([-us[1], us[0]])
    c, s = np.cos(ang), np.sin(ang)
    ut = np.array([us[0] * c - us[1] * s, us[0] * s + us[1] * c])
    vt = np.array([-ut[1], ut[0]])
    o = (np.asarray(j0, float) - (X0, Y0)) * PX
    # forward map: p_t = o + ut * sa * dot(p - a, us) + vt * g * dot(p - a, vs)
    M = np.column_stack([ut * sa, vt * g]) @ np.vstack([us, vs])
    Mi = np.linalg.inv(M)
    t = part.a - Mi @ o
    coeffs = (Mi[0, 0], Mi[0, 1], t[0], Mi[1, 0], Mi[1, 1], t[1])
    im = part.im.transform(canvas.size, Image.AFFINE, coeffs, resample=Image.BICUBIC)
    canvas.alpha_composite(im)
    return o + (M @ (part.b - part.a))


def place_rigid(canvas, part, j0, ang, g):
    """Draws `part` with its root on j0, turned by `ang` (radians), scale g."""
    d = rot(np.array([0.0, 1.0]), ang)
    return place(canvas, Part(part.im, part.a, part.a + (0, 100.0)), j0, np.asarray(j0) + d * (100.0 * g / PX), g,
                 stretch=(1.0, 1.0))


class Char:
    """A biped built from a sheet config (see hero.py CHARS)."""

    def __init__(self, cfg):
        self.cfg = cfg
        grp, sh = cfg['sheet']
        P = lambda i: piece(grp, sh, i)  # noqa: E731
        self.limbs = {}
        for k in ('armN', 'armF', 'legN', 'legF'):
            c = cfg[k]
            if 'pieces' in c:  # already separate segments
                up, lo = c['pieces']
                self.limbs[k] = (Part(P(up[0]), _pt(P(up[0]), up[1]), _pt(P(up[0]), up[2])),
                                 Part(P(lo[0]), _pt(P(lo[0]), lo[1]), _pt(P(lo[0]), lo[2])))
            else:
                self.limbs[k] = split_limb(P(c['piece']), c['top'], c['bot'], c['split'])
        self.hands = {}
        for k in ('handN', 'handF'):
            c = cfg.get(k)
            if c:
                im = P(c['piece'])
                self.hands[k] = Part(im, _pt(im, c['pivot']), _pt(im, c['pivot']) + (0, 100.0))
        self.feet = {}
        for k in ('footN', 'footF'):
            c = cfg.get(k)
            if c:
                im = P(c['piece'])
                self.feet[k] = Part(im, _pt(im, c['pivot']), _pt(im, c['pivot']) + (0, 100.0))
        h = cfg['head']
        im = P(h['piece'])
        self.head = Part(im, _pt(im, h['pivot']), _pt(im, h['pivot']) - (0, 100.0))
        t = cfg['torso']
        im = P(t['piece'])
        self.torso = Part(im, _pt(im, t['hip']), _pt(im, t['neck']))
        self.cape = None
        if cfg.get('cape'):
            c = cfg['cape']
            im = P(c['piece'])
            self.cape = (Part(im, _pt(im, c['anchor']), _pt(im, c['anchor']) + (0, 100.0)), c)
        # scale: hip-to-ankle in the art = THIGH + SHIN
        up, lo = self.limbs['legN']
        leg_px = np.hypot(*(up.b - up.a)) + np.hypot(*(lo.b - lo.a))
        self.g = (THIGH + SHIN) / leg_px * PX * cfg.get('scale', 1.0)

    def joints(self, pose):
        p = dict(BASE_POSE)
        p.update(pose)
        hip = np.asarray(p['hip'], float)
        lean = p['lean']
        b = p.get('breath', 0.0)

        def T(v):
            return hip + rot(np.asarray(v, float), lean)
        J = {'hip': hip, 'lean': lean, 'tilt': p['tilt'], 'drag': p['drag'], 'p': p}
        J['neck'] = T((NECK[0], NECK[1] - 0.035 * b))
        J['shN'] = T((SH_N[0] - 0.02 * b, SH_N[1] - 0.04 * b))
        J['shF'] = T((SH_F[0] + 0.01 * b, SH_F[1] - 0.04 * b))
        J['hipN'], J['hipF'] = T(HIP_N), T(HIP_F)
        J['amulet'] = T((AMU[0], AMU[1] - 0.03 * b))
        for side in 'NF':
            up, lo = self.limbs['leg' + side]
            l1, l2 = np.hypot(*(up.b - up.a)) * self.g / PX, np.hypot(*(lo.b - lo.a)) * self.g / PX
            knee, ank = ik(J['hip' + side], p['f' + side], l1, l2, (1.0, -0.15))
            J['knee' + side], J['ank' + side] = knee, ank
            up, lo = self.limbs['arm' + side]
            l1, l2 = np.hypot(*(up.b - up.a)) * self.g / PX, np.hypot(*(lo.b - lo.a)) * self.g / PX
            el, wr = ik(J['sh' + side], p['h' + side], l1, l2, p['e' + side])
            J['el' + side], J['wr' + side] = el, wr
            d = (wr - el) / max(np.hypot(*(wr - el)), 1e-6)
            J['fist' + side] = wr + d * FIST * 0.6
            J['fdir' + side] = d
        return J

    def draw(self, pose):
        J = self.joints(pose)
        p = J['p']
        cv = Image.new('RGBA', (int((X1 - X0) * PX), int((Y1 - Y0) * PX)), (0, 0, 0, 0))
        g = self.g
        cape_front = None
        if self.cape:
            part, c = self.cape
            dx, dy = J['drag']
            ang = J['lean'] * 0.6 - 0.18 * dx + c.get('turn', 0.0)
            at = J['neck'] + rot(np.asarray(c.get('at', (0.0, 0.0)), float), J['lean'])
            place_rigid(cv, part, at, ang, g)
            if c.get('front'):  # the hood over the head: drawn again after it
                im = part.im
                fy = int(im.height * c['front'])
                top = im.crop((0, 0, im.width, fy))
                ta = np.asarray(top).astype(np.float32)
                ramp = np.clip((fy - np.arange(fy)) / 18.0, 0, 1)
                ta[..., 3] *= ramp[:, None]
                cape_front = (Part(Image.fromarray(ta.astype(np.uint8), 'RGBA'), part.a, part.b), at, ang)

        def arm(side):
            up, lo = self.limbs['arm' + side]
            place(cv, up, J['sh' + side], J['el' + side], g)
            place(cv, lo, J['el' + side], J['wr' + side], g)
            hk = self.hands.get('hand' + side)
            if hk:
                d = J['fdir' + side]
                place_rigid(cv, hk, J['wr' + side] - d * 0.04, np.arctan2(d[1], d[0]) - np.pi / 2, g)

        def leg(side):
            up, lo = self.limbs['leg' + side]
            place(cv, up, J['hip' + side], J['knee' + side], g)
            place(cv, lo, J['knee' + side], J['ank' + side], g)
            fk = self.feet.get('foot' + side)
            if fk:
                place_rigid(cv, fk, J['ank' + side], p['p' + side], g)

        arm('F')
        leg('F')
        leg('N')
        place(cv, self.torso, J['hip'], J['neck'], g, stretch=(0.92, 1.08))
        over = J['fistN'][1] < J['shN'][1] - 0.55
        if over:
            arm('N')
        place_rigid(cv, self.head, J['neck'], J['lean'] * 0.5 + p['tilt'] + self.cfg['head'].get('turn', 0.0), g)
        if cape_front:
            place_rigid(cv, cape_front[0], cape_front[1], cape_front[2], g)
        if not over:
            arm('N')
        return cv, J


def to_px(pt):
    return ((pt[0] - X0) * PX / 2, (pt[1] - Y0) * PX / 2)


def render(char, pose):
    """RGBA cell image, the near fist and the amulet in cell px (like rig.render)."""
    cv, J = char.draw(pose)
    img = cv.resize(CELL, Image.LANCZOS)
    hand, amu = to_px(J['fistN']), to_px(J['amulet'])
    p = dict(BASE_POSE)
    p.update(pose)
    ang = p['rot']
    if ang:
        P = 160
        big = Image.new('RGBA', (img.size[0] + 2 * P, img.size[1] + 2 * P), (0, 0, 0, 0))
        big.paste(img, (P, P))
        piv = to_px(p['pivot'])
        big = big.rotate(ang, resample=Image.BICUBIC, center=(piv[0] + P, piv[1] + P))
        th = np.radians(ang)

        def rp(q):
            dx, dy = q[0] - piv[0], q[1] - piv[1]
            return (piv[0] + dx * np.cos(th) + dy * np.sin(th), piv[1] - dx * np.sin(th) + dy * np.cos(th))
        hand, amu = rp(hand), rp(amu)
        dy = 0
        if p.get('rest'):
            a = np.asarray(big)[..., 3]
            ys = np.where(a.max(axis=1) > 128)[0]
            if len(ys):
                dy = int(round(to_px((0.0, 0.0))[1] + P - ys.max() - 1))
        img = big.crop((P, P - dy, P + img.size[0], P - dy + img.size[1]))
        hand, amu = (hand[0], hand[1] + dy), (amu[0], amu[1] + dy)
    return img, [round(float(hand[0]), 1), round(float(hand[1]), 1)], [round(float(amu[0]), 1), round(float(amu[1]), 1)]

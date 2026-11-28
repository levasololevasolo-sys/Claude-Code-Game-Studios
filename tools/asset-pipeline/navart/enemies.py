"""Enemy and boss sheets from the approved «Навь» art: each kind's painted
full-body piece is animated as a whole-body puppet (squash, bob, lean,
lunge, fall) and written over the hand-drawn enemy sheets, keeping their
registries (assets/art/sprites/enemies_drawn/*.json: cell, origin, anims,
frame counts, variants, parts, states) so gameplay and hit boxes do not move:

    python3 tools/asset-pipeline/navart/enemies.py            # all kinds
    python3 tools/asset-pipeline/navart/enemies.py --preview DIR [kind ...]

Per kind: the body is scaled so it stands as tall as the old idle frame (and
fits the cell), its feet on the cell origin. Variants: "nohead" cuts the body
at the neck (a dark stump), "rage" (bosses) reddens it. Two-legged kinds in
enemy_rig.RIGS are joint-animated on the hero skeleton instead (their cut
parts moved by the hero poses), and "noarm" / "nohead" leave that part out. Parts: the
sheet's separate head / arm pieces at the same scale. Kinds without art in the
drop (KINDS has no entry) keep their old sheets. Deterministic.
"""
import json
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import enemy_rig  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
SRC = os.path.join(REPO, 'assets', 'art', 'navart', 'chars')
OUT = os.path.join(REPO, 'assets', 'art', 'sprites', 'enemies_drawn')
REGS = ['enemies_drawn', 'enemies_drawn_forest', 'enemies_drawn_frost', 'enemies_drawn_bosses']

# kind -> sheet, head piece, arm piece (None = none), optional extras:
#   body: full-figure piece (default: the largest), flip: art faces left,
#   fly: hovers (death drops instead of falling over), pieces for special anims
KINDS = {
    'crawler': {'sheet': 'char_en_swamp_tryasinnik', 'head': 0, 'arm': 4, 'quad': True},
    'balvan': {'sheet': 'char_en_swamp_balvan', 'head': 0, 'arm': 6, 'body': 5},
    'thrower': {'sheet': 'char_en_swamp_upyr_thrower', 'head': 0, 'arm': 2},
    'bloat': {'sheet': 'char_en_swamp_utoplennik', 'head': 0, 'arm': 3},
    'shishiga': {'sheet': 'char_en_swamp_shishiga', 'head': 0, 'arm': 3},
    'bognitsa': {'sheet': 'char_en_swamp_bolotnitsa', 'head': 0, 'arm': 1, 'hummock': 5},
    'vodyanitsa': {'sheet': 'char_en_swamp_vodyanitsa', 'head': 0, 'arm': 2},
    'kikimora': {'sheet': 'char_boss_kikimora', 'head': 0, 'arm': 5},
    'ringer': {'sheet': 'char_en_forest_auka', 'head': 0, 'arm': 2},
    'rootling': {'sheet': 'char_en_forest_leshachonok', 'head': 0, 'arm': 2},
    'bat': {'sheet': 'char_en_forest_netopyr', 'head': 1, 'arm': None, 'fly': True},
    'sentry': {'sheet': 'char_en_forest_upyr_shield', 'head': 0, 'arm': 1},
    'suchkovik': {'sheet': 'char_en_forest_suchkovik', 'head': 0, 'arm': 1},
    'lesavka': {'sheet': 'char_en_forest_lesavka', 'head': 1, 'arm': None},
    'likho': {'sheet': 'char_boss_likho', 'head': 0, 'arm': 4},
    'wolf': {'sheet': 'char_en_frost_wolf', 'head': 0, 'arm': None, 'quad': True},
    'jelly': {'sheet': 'char_en_frost_studeny_dukh', 'head': 0, 'arm': None, 'fly': True},
    'karachun': {'sheet': 'char_en_frost_karachun', 'head': 2, 'arm': 4},
    'snezhnitsa': {'sheet': 'char_en_frost_snezhnitsa', 'head': 0, 'arm': 4},
    'sosulnik': {'sheet': 'char_en_frost_sosulnik', 'head': None, 'arm': None, 'fly': True},
    'mara': {'sheet': 'char_en_frost_mara', 'head': 0, 'arm': 5},
    'morena': {'sheet': 'char_boss_morena', 'head': 0, 'arm': 2},
}

WIND = ('windup', 'aim', 'inflate', 'call', 'whistle', 'song', 'shake', 'summon', 'block', 'poke_wind', 'roar',
        'mirror_w', 'stuck')
STRIKE = ('attack', 'throw', 'lunge', 'charge', 'poke', 'spit', 'slam', 'leap', 'gaze', 'woe', 'wave', 'pend',
          'breath', 'spears', 'scythe', 'explode', 'cling')


def load(sheet, i):
    return Image.open(os.path.join(SRC, sheet, '%02d.webp' % i)).convert('RGBA')


def pieces(sheet):
    return json.load(open(os.path.join(SRC, sheet, 'sheet.json')))['pieces']


def bbox_a(im, thr=40):
    return im.getchannel('A').point(lambda v: 255 if v > thr else 0).getbbox()


def ease(t):
    return t * t * (3 - 2 * t)


def motion(anim, i, n, fly, quad=False):
    """(dx, dy, rot rad, sx, sy, alpha, flash, sink) of frame i of n."""
    t = i / max(n - 1, 1)
    ph = 2 * math.pi * i / max(n, 1)
    base = anim.split('_sever')[0]
    w = base[:-2] if base.endswith('_w') else base
    if base.endswith('_w') or w in WIND:
        k = ease(t)
        return (-8 * k, 0, -0.10 * k, 1 - 0.03 * k, 0.96 - 0.02 * math.sin(ph * 2) * k, 1, 0, 0)
    if w in STRIKE:
        k = math.sin(math.pi * min(t * 1.4, 1.0))
        return (16 * k, -4 * k if fly else 0, 0.14 * k, 1 + 0.08 * k, 1 - 0.04 * k, 1, 0, 0)
    if w in ('idle', 'hang', 'hummock', 'under', 'bubble'):
        s = math.sin(ph)
        return (0, (3 * s if fly else 0), 0.015 * s, 1 - 0.012 * s, 1 + 0.022 * s, 1, 0, 0)
    if w in ('move', 'flee', 'hop', 'unstick'):
        s = math.sin(ph)
        return (0, -5 * abs(s) - (6 * abs(s) if w == 'hop' else 0), 0.05 * s, 1, 1 - 0.03 * abs(math.cos(ph)), 1, 0, 0)
    if w == 'hurt':
        k = 1 - t
        return (-8 * k, 0, -0.14 * k, 1, 1, 1, k, 0)
    if w in ('death',):
        if fly:
            return (-10 * t, 60 * ease(t), -0.6 * t, 1, 1, 1 - max(0, t - 0.6) / 0.4, 0, 0)
        if quad:  # slumps onto its side
            k = ease(min(t * 1.3, 1))
            return (-6 * k, 0, 0.12 * k, 1 + 0.1 * k, 1 - 0.4 * k, 1 - max(0, t - 0.75) / 0.25 * 0.9, 0, 0)
        k = ease(min(t * 1.3, 1))
        return (-14 * k, 0, -1.35 * k, 1, 1, 1 - max(0, t - 0.75) / 0.25 * 0.9, 0, 0)
    if w in ('vanish', 'dive', 'burrow'):
        k = ease(t)
        return (0, 0, 0, 1, 1, 1 - k if w == 'vanish' else 1, 0, k)
    if w in ('appear', 'surface', 'raise', 'intro'):
        k = 1 - ease(t)
        return (0, 0, 0, 1, 1, 1 - k if w == 'appear' else 1, 0, k)
    if w in ('fall',):
        return (0, 0, 0, 0.94, 1.08, 1, 0, 0)
    if w in ('land', 'slam_end'):
        k = 1 - t
        return (0, 0, 0, 1 + 0.12 * k, 1 - 0.14 * k, 1, 0, 0)
    return (0, 0, 0, 1, 1, 1, 0, 0)


class Kind:
    def __init__(self, name, spec, meta):
        self.name, self.spec, self.meta = name, spec, meta
        sh = spec['sheet']
        ps = pieces(sh)
        bi = spec.get('body', max(ps, key=lambda p: p['area'])['i'])
        body = load(sh, bi)
        body = body.crop(bbox_a(body))
        if spec.get('flip'):
            body = body.transpose(Image.FLIP_LEFT_RIGHT)
        self.cell = tuple(meta['cell'])
        self.origin = meta['origin']
        old_h = self.old_height()
        k = old_h / body.height
        k = min(k, self.cell[0] * 0.98 / body.width, self.origin[1] * 0.98 / body.height)
        self.k = k
        self.body = body.resize((max(1, round(body.width * k)), max(1, round(body.height * k))), Image.LANCZOS)
        self.head = self.arm = None
        if spec.get('head') is not None:
            h = load(sh, spec['head'])
            h = h.crop(bbox_a(h))
            self.head = h.resize((max(1, round(h.width * k)), max(1, round(h.height * k))), Image.LANCZOS)
        if spec.get('arm') is not None:
            a = load(sh, spec['arm'])
            a = a.crop(bbox_a(a))
            self.arm = a.resize((max(1, round(a.width * k)), max(1, round(a.height * k))), Image.LANCZOS)
        self.rig = None
        if name in enemy_rig.RIGS and not spec.get('puppet'):
            self.rig = enemy_rig.Rig(name)
            self.rig_h = min(old_h, self.origin[1] * 0.98)
        self.hummock = None
        if spec.get('hummock') is not None:
            m = load(sh, spec['hummock'])
            m = m.crop(bbox_a(m))
            km = min(k * 1.0, self.cell[0] * 0.9 / m.width)
            self.hummock = m.resize((round(m.width * km), round(m.height * km)), Image.LANCZOS)

    def old_height(self):
        p = os.path.join(OUT, self.name, '%s_idle.png' % self.name)
        if not os.path.exists(p):
            return self.origin[1] * 0.9
        im = Image.open(p).convert('RGBA').crop((0, 0, self.cell[0], self.cell[1]))
        b = bbox_a(im, 100)
        return (self.origin[1] - b[1]) if b else self.origin[1] * 0.9

    def nohead(self, im):
        if self.head is None:
            return im
        a = np.asarray(im).astype(np.float32)
        if self.spec.get('quad'):  # the head is in front: cut it off at the neck
            cx = a.shape[1] - int(self.head.width * 0.8)
            xs = np.arange(a.shape[1])[None, :]
            ys = np.arange(a.shape[0])[:, None]
            a[..., 3] *= (xs < cx + 3 * np.sin(ys * 0.7))
            out = Image.fromarray(a.astype(np.uint8), 'RGBA')
            rows = np.where(a[:, max(cx - 8, 0):cx - 3, 3].max(axis=1) > 100)[0]
            if len(rows):
                ImageDraw.Draw(out).ellipse([cx - 10, rows.min() + (rows.max() - rows.min()) * 0.2, cx + 1,
                                             rows.min() + (rows.max() - rows.min()) * 0.8], fill=(70, 12, 14, 255))
            return out
        cut = int(self.head.height * 0.85)
        ys = np.arange(a.shape[0])[:, None]
        xs = np.arange(a.shape[1])[None, :]
        edge = cut + 3 * np.sin(xs * 0.7)
        a[..., 3] *= (ys > edge)
        out = Image.fromarray(a.astype(np.uint8), 'RGBA')
        dr = ImageDraw.Draw(out)
        cols = np.where(a[cut + 4:cut + 8, :, 3].max(axis=0) > 100)[0] if cut + 8 < a.shape[0] else []
        if len(cols):
            x0, x1 = cols.min(), cols.max()
            dr.ellipse([x0 + (x1 - x0) * 0.2, cut - 2, x0 + (x1 - x0) * 0.8, cut + 9], fill=(70, 12, 14, 255))
        return out

    def rig_frame(self, anim, i, n, variant=''):
        """Joint-animated frame (enemy_rig): the pose moves the limbs; whole-body
        motion is kept only for anims the hero poses do not cover, plus fade,
        flash, sink and rage. A severed head / arm is left out of the drawing."""
        skip = ()
        if variant == 'nohead' or anim == 'death_sever_head':
            skip = ('head',)
        elif variant == 'noarm' or anim == 'death_sever_arm':
            skip = ('armN',)
        im, whole = self.rig.frame(anim, i, n, self.cell, self.origin, self.rig_h, skip)
        dx, dy, r, sx, sy, alpha, flash, sink = motion(anim, i, n, False)
        if not whole:
            dx, dy, r, sx, sy = 0, 0, 0, 1, 1
        if (dx, dy, r, sx, sy, sink) != (0, 0, 0, 1, 1, 0):
            # affine about the feet (cell origin): scale, turn, shift, sink
            ox, oy = self.origin
            oy2 = oy + self.rig_h * sink
            c, sn = math.cos(-r), math.sin(-r)
            # inverse map: out -> in
            a_ = c / sx; b_ = sn / sx; d_ = -sn / sy; e_ = c / sy
            tx, ty = ox + dx, oy2 + dy
            im = im.transform(im.size, Image.AFFINE, (a_, b_, ox - a_ * tx - b_ * ty, d_, e_, oy - d_ * tx - e_ * ty),
                              resample=Image.BICUBIC)
        a = np.asarray(im).astype(np.float32)
        if flash:
            a[..., :3] = a[..., :3] + (255 - a[..., :3]) * 0.6 * flash
        if variant == 'rage':
            a[..., 0] = np.minimum(255, a[..., 0] * 1.15 + 18)
            a[..., 1] *= 0.82
            a[..., 2] *= 0.82
        a[..., 3] *= alpha
        if sink:
            a[int(self.origin[1]) + 4:, :, 3] = 0
        return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), 'RGBA')

    def frame(self, anim, i, n, variant=''):
        if self.rig is not None and anim not in ('hummock', 'bubble'):
            return self.rig_frame(anim, i, n, variant)
        body = self.body
        if anim in ('hummock', 'bubble') and self.hummock is not None:
            body = self.hummock
        if variant == 'nohead' or anim == 'death_sever_head':
            body = self.nohead(body)
        dx, dy, r, sx, sy, alpha, flash, sink = motion(anim, i, n, self.spec.get('fly', False), self.spec.get('quad', False))
        if anim == 'bubble':
            sy *= 1 + 0.05 * math.sin(2 * math.pi * i / max(n, 1))
        bw, bh = body.size
        im = body.resize((max(1, round(bw * sx)), max(1, round(bh * sy))), Image.BICUBIC)
        a = np.asarray(im).astype(np.float32)
        if flash:
            a[..., :3] = a[..., :3] + (255 - a[..., :3]) * 0.6 * flash
        if variant == 'rage':
            a[..., 0] = np.minimum(255, a[..., 0] * 1.15 + 18)
            a[..., 1] *= 0.82
            a[..., 2] *= 0.82
        a[..., 3] *= alpha
        if sink:
            cut = int(a.shape[0] * (1 - sink))
            a[cut:, :, 3] = 0
        im = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), 'RGBA')
        # pivot: bottom centre (feet) -> rotate about it; sinking slides down
        P = max(im.size)
        big = Image.new('RGBA', (im.width + 2 * P, im.height + 2 * P), (0, 0, 0, 0))
        big.paste(im, (P, P))
        piv = (P + im.width / 2, P + im.height)
        if r:
            big = big.rotate(math.degrees(-r), resample=Image.BICUBIC, center=piv)
        cell = Image.new('RGBA', self.cell, (0, 0, 0, 0))
        ox = self.origin[0] - piv[0] + dx
        oy = self.origin[1] - piv[1] + dy + (bh * sy * sink if sink else 0)
        cell.paste(big, (int(round(ox)), int(round(oy))), big)
        return cell

    def sheets(self, out_dir):
        os.makedirs(out_dir, exist_ok=True)
        for anim, m in self.meta['anims'].items():
            n, cols, rows = m['frames'], m['cols'], m['rows']
            for var in [''] + list(m.get('variants', [])):
                sheet = Image.new('RGBA', (self.cell[0] * cols, self.cell[1] * rows), (0, 0, 0, 0))
                for i in range(n):
                    sheet.alpha_composite(self.frame(anim, i, n, var), ((i % cols) * self.cell[0], (i // cols) * self.cell[1]))
                name = '%s_%s%s.png' % (self.name, anim, ('_' + var) if var else '')
                sheet.save(os.path.join(out_dir, name), optimize=True)
        parts = self.meta.get('parts') or {}
        if 'head' in parts and self.head is not None:
            self.head.save(os.path.join(out_dir, parts['head']['file']))
            parts['head']['pivot'] = [round(self.head.width * 0.5, 1), round(self.head.height * 0.9, 1)]
            parts['head']['size'] = list(self.head.size)
        if 'arm' in parts and self.arm is not None:
            self.arm.save(os.path.join(out_dir, parts['arm']['file']))
            parts['arm']['pivot'] = [round(self.arm.width * 0.5, 1), round(self.arm.height * 0.08, 1)]
            parts['arm']['size'] = list(self.arm.size)


def registries():
    for r in REGS:
        p = os.path.join(OUT, r + '.json')
        yield p, json.load(open(p))


def main():
    args = sys.argv[1:]
    preview = None
    if args and args[0] == '--preview':
        preview, args = args[1], args[2:]
    only = set(args)
    done = []
    for path, reg in registries():
        changed = False
        for name, meta in reg['kinds'].items():
            if name not in KINDS or (only and name not in only):
                continue
            kd = Kind(name, KINDS[name], meta)
            if preview:
                os.makedirs(preview, exist_ok=True)
                anims = list(meta['anims'])
                W = kd.cell[0] * 8
                img = Image.new('RGBA', (W, kd.cell[1] * len(anims)), (60, 70, 64, 255))
                for r, a in enumerate(anims):
                    n = meta['anims'][a]['frames']
                    for i in range(min(n, 8)):
                        img.alpha_composite(kd.frame(a, i, n), (i * kd.cell[0], r * kd.cell[1]))
                img.save(os.path.join(preview, name + '.png'))
            else:
                kd.sheets(os.path.join(OUT, name))
                changed = True
            done.append(name)
        if changed:
            reg['_note'] += ' Kinds with approved art are rebuilt by tools/asset-pipeline/navart/enemies.py.' \
                if 'navart' not in reg['_note'] else ''
            with open(path, 'w') as f:
                json.dump(reg, f, indent=1, ensure_ascii=False)
    print('enemies:', ' '.join(done))


if __name__ == '__main__':
    main()

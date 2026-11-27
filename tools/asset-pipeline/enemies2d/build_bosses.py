"""Builds the hand-drawn boss sheets (kinds_bosses.py), same pipeline as build_forest.py.

    python3 tools/asset-pipeline/enemies2d/build_bosses.py                    # all three + QA sheets
    python3 tools/asset-pipeline/enemies2d/build_bosses.py --kinds=likho
    python3 tools/asset-pipeline/enemies2d/build_bosses.py --evidence-only

Output: assets/art/sprites/enemies_drawn/<boss>/<boss>_<anim>[_rage].png and the
registry assets/art/sprites/enemies_drawn/enemies_drawn_bosses.json (merged
with enemies_drawn*.json by src/enemies/drawn_enemy_visual.gd). Extra keys per
boss: "intro" (one-shot played when the boss says its intro line), and the
"rage" variant listed in an anim's "variants" (the phase-2 look, shown while
LairBoss.phase >= 2). No severable parts: bosses are not dismembered.
QA: production/qa/evidence/bosses-drawn.png, bosses-drawn-anims.png.
Deterministic: fixed seeds.
"""
import json
import os
import sys
from multiprocessing import Pool

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import kinds_bosses  # noqa: E402,F401  (sets the boss render density in base)
from base import render, to_px, PX_PER_WORLD  # noqa: E402
from kinds_bosses import KINDS, STATES  # noqa: E402
from build import grid, hero_idle, FONT, OUT, EV  # noqa: E402

REG = os.path.join(OUT, 'enemies_drawn_bosses.json')
ORDER = ['kikimora', 'likho', 'morena']
NAMES = {'kikimora': 'Кикимора', 'likho': 'Лихо Одноглазое', 'morena': 'Морена'}
SEED = {'kikimora': 8, 'likho': 9, 'morena': 10}


def plan(kind):
    """[(sheet, anim, poses, fps, loop)]: every anim, plus a `_rage` copy (rage = 1)."""
    cls, anims_fn, no_rage = KINDS[kind]
    anims = anims_fn()
    out = []
    for a, (poses, fps, loop) in anims.items():
        out.append((a, a, poses, fps, loop))
        if a not in no_rage:
            out.append((a + '_rage', a, [dict(p, rage=1.0) for p in poses], fps, loop))
    return cls, anims, out


def job(args):
    kind, sheet, i = args
    cls, _, out = plan(kind)
    poses = [o for o in out if o[0] == sheet][0][2]
    return kind, sheet, i, render(cls, poses[i], seed=SEED[kind])


def build_kinds(kinds):
    reg = json.load(open(REG)) if os.path.exists(REG) else {}
    reg['_note'] = ('Hand-drawn location bosses (tools/asset-pipeline/enemies2d/build_bosses.py); format as '
                    'enemies_drawn.json. intro: one-shot when the boss speaks its intro line; variant "rage": '
                    'the phase-2 look (LairBoss.phase >= 2).')
    reg['px_per_world'] = PX_PER_WORLD
    reg.setdefault('kinds', {})
    jobs, plans = [], {}
    for k in kinds:
        plans[k] = plan(k)
        for sheet, a, poses, fps, loop in plans[k][2]:
            jobs += [(k, sheet, i) for i in range(len(poses))]
    res = {}
    with Pool(os.cpu_count() or 2) as pool:
        for k, sheet, i, im in pool.imap_unordered(job, jobs, chunksize=1):
            res[(k, sheet, i)] = im
    for k in kinds:
        cls, anims, out = plans[k]
        x0, x1, y0, y1 = cls.BOUNDS
        cell = list(res[(k, 'idle', 0)].size)
        d = os.path.join(OUT, k)
        os.makedirs(d, exist_ok=True)
        meta = {'cell': cell, 'origin': [round(v, 1) for v in to_px(cls, (0.0, 0.0))], 'anims': {}, 'parts': {},
                'states': STATES[k], 'intro': 'intro'}
        for sheet, a, poses, fps, loop in out:
            n = len(poses)
            cols, rows = grid(n)
            img = Image.new('RGBA', (cell[0] * cols, cell[1] * rows), (0, 0, 0, 0))
            for i in range(n):
                img.paste(res[(k, sheet, i)], ((i % cols) * cell[0], (i // cols) * cell[1]))
            img.save(os.path.join(d, '%s_%s.png' % (k, sheet)), optimize=True)
            if sheet == a:
                meta['anims'][a] = {'frames': n, 'fps': fps, 'loop': loop, 'cols': cols, 'rows': rows, 'variants': []}
        for sheet, a, *_ in out:
            if sheet != a:
                meta['anims'][a]['variants'].append('rage')
        reg['kinds'][k] = meta
        print(k, 'frames', sum(len(o[2]) for o in out))
    json.dump(reg, open(REG, 'w'), indent=1, ensure_ascii=False)


# ---------------- QA sheets ----------------
LOOK = {'kikimora': ((0x3E, 0x5A, 0x4A), (0x12, 0x1E, 0x19)), 'likho': ((0x2E, 0x44, 0x66), (0x0F, 0x16, 0x26)),
        'morena': ((0x7C, 0x93, 0xAD), (0x2C, 0x3B, 0x52))}


def frame(kind, sheet, i):
    reg = json.load(open(REG))['kinds'][kind]
    a = reg['anims'][sheet.replace('_rage', '')]
    cw, ch = reg['cell']
    im = Image.open(os.path.join(OUT, kind, '%s_%s.png' % (kind, sheet)))
    i = min(i, a['frames'] - 1) if i >= 0 else a['frames'] - 1
    return im.crop(((i % a['cols']) * cw, (i // a['cols']) * ch, (i % a['cols'] + 1) * cw, (i // a['cols'] + 1) * ch)), reg


def panel(w, h, kind):
    """Location sky (art bible §4.2): sky / far layer at the top -> near layer at the bottom."""
    top, bot = np.array(LOOK[kind][0]) * 0.75, np.array(LOOK[kind][1])
    y = np.linspace(0, 1, h)[:, None, None]
    arr = (top * (1 - y) + bot * y) * np.ones((1, w, 1))
    return Image.fromarray(arr.astype(np.uint8)).convert('RGBA')


def lineup(path):
    """1080p scale (sheet px = screen px, the hero 160 px): idle and one wind-up per boss."""
    f = ImageFont.truetype(FONT, 18)
    shows = {'kikimora': (('idle', 0, 'стойка'), ('pend_w', -1, 'замах: маятники')),
             'likho': (('idle', 0, 'стойка'), ('gaze_w', -1, 'замах: взгляд')),
             'morena': (('idle', 0, 'стойка'), ('scythe_w', -1, 'замах: серп'))}
    PW, H_ = 1000, 560
    can = Image.new('RGBA', (PW * 3, H_), (0, 0, 0, 255))
    hero, ho = hero_idle()
    for n, k in enumerate(ORDER):
        p = panel(PW, H_, k)
        dr = ImageDraw.Draw(p)
        gy = 500
        dr.line((0, gy, PW, gy), fill=(70, 62, 52), width=2)
        p.alpha_composite(hero, (int(70 - ho[0]), int(gy - ho[1])))
        x = 380
        for sheet, idx, label in shows[k]:
            im, reg = frame(k, sheet, idx)
            ox, oy = reg['origin']
            yy = gy - (60 if k == 'morena' else 0)
            p.alpha_composite(im, (int(x - ox), int(yy - oy)))
            dr.text((x - 60, gy + 12), label, font=f, fill=(230, 220, 190))
            x += 400
        dr.text((16, 14), NAMES[k], font=ImageFont.truetype(FONT, 26), fill=(240, 230, 200))
        can.alpha_composite(p, (n * PW, 0))
    can.convert('RGB').save(path)


def contact(path):
    f = ImageFont.truetype(FONT, 13)
    reg_all = json.load(open(REG))['kinds']
    rows = []
    for k in ORDER:
        for a, m in reg_all[k]['anims'].items():
            rows.append((k, a, m['frames']))
        rows.append((k, 'idle_rage', reg_all[k]['anims']['idle']['frames']))
    cw, rh = 118, 132
    W_ = 150 + cw * 12
    half = (len(rows) + 1) // 2
    H_ = rh * half + 20
    can = Image.new('RGBA', (W_ * 2, H_), (24, 30, 40, 255))
    dr = ImageDraw.Draw(can)
    for r, (k, a, n) in enumerate(rows):
        col, rr = divmod(r, half)
        ox, oy = col * W_, 10 + rr * rh
        can.alpha_composite(panel(W_ - 4, rh - 2, k), (ox, oy))
        dr.text((ox + 6, oy + 50), '%s\n%s' % (k, a), font=f, fill=(230, 220, 190))
        for i in range(min(n, 12)):
            im, reg = frame(k, a, i)
            sc = min(1.0, (rh - 4) / im.size[1], (cw + 30) / im.size[0])
            im = im.resize((max(1, int(im.size[0] * sc)), max(1, int(im.size[1] * sc))), Image.LANCZOS)
            can.alpha_composite(im, (ox + 130 + i * cw, oy))
    can.convert('RGB').save(path)


def evidence():
    os.makedirs(EV, exist_ok=True)
    lineup(os.path.join(EV, 'bosses-drawn.png'))
    contact(os.path.join(EV, 'bosses-drawn-anims.png'))


if __name__ == '__main__':
    args = sys.argv[1:]
    if '--evidence-only' not in args:
        kinds = ORDER
        for a in args:
            if a.startswith('--kinds='):
                kinds = a.split('=')[1].split(',')
        build_kinds(kinds)
    evidence()

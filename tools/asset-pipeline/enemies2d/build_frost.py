"""Builds the hand-drawn Царство Морены enemies (kinds_frost.py) into their own registry.

    python3 tools/asset-pipeline/enemies2d/build_frost.py                 # sheets + fx + QA sheets
    python3 tools/asset-pipeline/enemies2d/build_frost.py --kinds=wolf,mara
    python3 tools/asset-pipeline/enemies2d/build_frost.py --evidence-only

Same output layout as build.py (assets/art/sprites/enemies_drawn/<kind>/...), but
the registry is enemies_drawn_frost.json (drawn_enemy_visual.gd merges every
enemies_drawn*.json), plus per kind "fx" sprites: the spirit's ice puddle, the
Карачун wave spike (3 variants), the Снежница needle. Reuses build.py's planner
and renderer; build.py itself is untouched. QA: production/qa/evidence/
enemies-drawn-frost.png (lineup with the hero on snow), enemies-drawn-frost-anims.png.
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
import build  # noqa: E402
from base import render, to_px, part_pivot, PX_PER_WORLD, SHEET_PX  # noqa: E402
from kinds_frost import KINDS_FROST, STATES_FROST, FX  # noqa: E402

build.KINDS.update(KINDS_FROST)   # build.plan / build.job read this dict (fork keeps it in the pool)
build.STATES.update(STATES_FROST)
OUT = build.OUT
REG = os.path.join(OUT, 'enemies_drawn_frost.json')
EV = build.EV
FONT = build.FONT
ORDER = ['wolf', 'jelly', 'karachun', 'snezhnitsa', 'sosulnik', 'mara']
NAMES = {'wolf': 'Снежный волк', 'jelly': 'Студёный дух', 'karachun': 'Карачун', 'snezhnitsa': 'Снежница',
         'sosulnik': 'Сосульник', 'mara': 'Мара'}


def build_kinds(kinds):
    reg = json.load(open(REG)) if os.path.exists(REG) else {}
    reg['_note'] = ('Hand-drawn Царство Морены enemies (tools/asset-pipeline/enemies2d/build_frost.py), same format as '
                    'enemies_drawn.json; fx: effect sprites of the kind (file, origin px, cell/frames when a strip).')
    reg['px_per_world'] = PX_PER_WORLD
    reg.setdefault('kinds', {})
    plans, jobs = {}, []
    for k in kinds:
        plans[k] = build.plan(k)
        for sheet, a, mode, poses, fps, loop in plans[k][3]:
            jobs += [(k, sheet, i, mode) for i in range(len(poses))]
    res = {}
    with Pool(os.cpu_count() or 2) as pool:
        for k, sheet, i, im in pool.imap_unordered(build.job, jobs, chunksize=2):
            res[(k, sheet, i)] = im
    for k in kinds:
        cls, anims, sever, out = plans[k]
        x0, x1, y0, y1 = cls.BOUNDS
        cell = [int((x1 - x0) * SHEET_PX), int((y1 - y0) * SHEET_PX)]
        d = os.path.join(OUT, k)
        os.makedirs(d, exist_ok=True)
        meta = {'cell': cell, 'origin': [round(v, 1) for v in to_px(cls, (0.0, 0.0))], 'anims': {}, 'parts': {},
                'states': STATES_FROST[k]}
        for sheet, a, mode, poses, fps, loop in out:
            n = len(poses)
            cols, rows = build.grid(n)
            img = Image.new('RGBA', (cell[0] * cols, cell[1] * rows), (0, 0, 0, 0))
            for i in range(n):
                img.paste(res[(k, sheet, i)], ((i % cols) * cell[0], (i // cols) * cell[1]))
            img.save(os.path.join(d, '%s_%s.png' % (k, sheet)), optimize=True)
            if mode == 'full':
                meta['anims'][a] = {'frames': n, 'fps': fps, 'loop': loop, 'cols': cols, 'rows': rows, 'variants': []}
        for sheet, a, mode, *_ in out:
            if mode != 'full' and a in meta['anims']:
                meta['anims'][a]['variants'].append(mode)
            elif mode != 'full':
                meta['anims'][a] = dict(meta['anims']['death'], variants=[])
        idle0 = anims['idle'][0][0]
        for limb in sever:
            im = render(cls, idle0, limb)
            part, pv = build.crop_part(im, part_pivot(cls, idle0, limb))
            part.save(os.path.join(d, '%s_part_%s.png' % (k, limb)), optimize=True)
            meta['parts'][limb] = {'file': '%s_part_%s.png' % (k, limb), 'pivot': pv, 'size': list(part.size)}
        if k in FX:
            meta['fx'] = {}
            for name, fn in FX[k].items():
                im, fm = fn()
                im.save(os.path.join(d, '%s_%s.png' % (k, name)), optimize=True)
                meta['fx'][name] = dict(fm, file='%s_%s.png' % (k, name), size=list(im.size))
        reg['kinds'][k] = meta
        print(k, 'frames', sum(len(o[3]) for o in out))
    json.dump(reg, open(REG, 'w'), indent=1, ensure_ascii=False)


# ---------------- QA sheets ----------------
def frame(kind, sheet, i):
    reg = json.load(open(REG))['kinds'][kind]
    a = reg['anims'][sheet.replace('_noarm', '').replace('_nohead', '')]
    cw, ch = reg['cell']
    im = Image.open(os.path.join(OUT, kind, '%s_%s.png' % (kind, sheet)))
    i = min(i, a['frames'] - 1)
    return im.crop(((i % a['cols']) * cw, (i // a['cols']) * ch, (i % a['cols'] + 1) * cw, (i // a['cols'] + 1) * ch)), reg


def snow_bg(w, h):
    """Art bible §4.2 Морена: sky #C9D8E6 -> middle #7C93AD."""
    y = np.linspace(0, 1, h)[:, None, None]
    top, bot = np.array([0xC9, 0xD8, 0xE6]), np.array([0x9C, 0xB0, 0xC6])
    arr = (top * (1 - y) + bot * y) * np.ones((1, w, 1))
    return Image.fromarray(arr.astype(np.uint8)).convert('RGBA')


def lineup(path):
    f = ImageFont.truetype(FONT, 18)
    W_, H_ = 1900, 700
    can = snow_bg(W_, H_)
    dr = ImageDraw.Draw(can)
    hero, ho = build.hero_idle()
    rows = (('idle', 0, 'стойка'), ('windup', 4, 'замах'))
    for row, (sheet, idx, label) in enumerate(rows):
        gy = 300 + row * 330
        dr.rectangle((0, gy, W_, gy + 30), fill=(0xDD, 0xE8, 0xF0))
        dr.line((0, gy, W_, gy), fill=(0x7C, 0x93, 0xAD), width=2)
        dr.text((10, gy - 280), label, font=f, fill=(0x2C, 0x3B, 0x52))
        can.alpha_composite(hero, (int(90 - ho[0]), int(gy - ho[1])))
        x = 330
        for k in ORDER:
            s = sheet
            if k == 'sosulnik' and row == 0:
                s = 'hang'
            if k == 'mara' and row == 1:
                s = 'raise'
            im, reg = frame(k, s, idx if s != 'raise' else 5)
            ox, oy = reg['origin']
            yy = gy - oy - (150 if s == 'hang' else 0)
            can.alpha_composite(im, (int(x - ox), int(yy)))
            if k == 'sosulnik' and row == 0:
                im2, _ = frame(k, 'idle', 0)
                can.alpha_composite(im2, (int(x + 110 - ox), int(gy - oy)))
            if row == 0:
                dr.text((x - 50, gy + 6), NAMES[k], font=f, fill=(0x2C, 0x3B, 0x52))
            x += 255 if k != 'sosulnik' else 300
    # fx strip
    fx = json.load(open(REG))['kinds']
    x = 1500
    dr.text((x, 12), 'эффекты: лужа, шип волны, игла', font=ImageFont.truetype(FONT, 14), fill=(0x2C, 0x3B, 0x52))
    for k, name in (('jelly', 'puddle'), ('karachun', 'spike'), ('snezhnitsa', 'needle')):
        m = fx[k]['fx'][name]
        im = Image.open(os.path.join(OUT, k, m['file']))
        can.alpha_composite(im, (x, 40 if name == 'puddle' else (110 if name == 'spike' else 190)))
    can.convert('RGB').save(path)


def contact(path):
    f = ImageFont.truetype(FONT, 13)
    rows = []
    for k in ORDER:
        reg = json.load(open(REG))['kinds'][k]
        for a, m in reg['anims'].items():
            if a.startswith('death_sever'):
                continue
            rows.append((k, a, m['frames']))
    for k, a in (('karachun', 'idle_noarm'), ('mara', 'attack_noarm'), ('mara', 'idle_nohead'), ('wolf', 'death_sever_head')):
        rows.append((k, a, 8))
    cw = 130
    W_ = 160 + cw * 8
    half = (len(rows) + 1) // 2
    H_ = 122 * half + 30
    can = snow_bg(W_ * 2, H_)
    dr = ImageDraw.Draw(can)
    for r, (k, a, n) in enumerate(rows):
        col, rr = divmod(r, half)
        ox, oy = col * W_, 15 + rr * 122
        dr.text((ox + 6, oy + 50), '%s\n%s' % (k, a), font=f, fill=(0x2C, 0x3B, 0x52))
        base = a.replace('_noarm', '').replace('_nohead', '')
        reg = json.load(open(REG))['kinds'][k]
        n = min(n, reg['anims'][base]['frames'])
        for i in range(min(n, 8)):
            im, reg = frame(k, a, i)
            sc = min(1.0, 118.0 / im.size[1], (cw - 4) / im.size[0])
            im = im.resize((max(1, int(im.size[0] * sc)), max(1, int(im.size[1] * sc))), Image.LANCZOS)
            can.alpha_composite(im, (ox + 150 + i * cw, oy))
    can.convert('RGB').save(path)


def evidence():
    os.makedirs(EV, exist_ok=True)
    lineup(os.path.join(EV, 'enemies-drawn-frost.png'))
    contact(os.path.join(EV, 'enemies-drawn-frost-anims.png'))


if __name__ == '__main__':
    args = sys.argv[1:]
    if '--evidence-only' not in args:
        kinds = ORDER
        for a in args:
            if a.startswith('--kinds='):
                kinds = a.split('=')[1].split(',')
        build_kinds(kinds)
    evidence()

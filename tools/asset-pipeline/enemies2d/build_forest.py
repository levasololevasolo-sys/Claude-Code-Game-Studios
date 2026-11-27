"""Builds the hand-drawn Тёмный бор enemy sheets (kinds_forest.py), same pipeline as build.py.

    python3 tools/asset-pipeline/enemies2d/build_forest.py                  # all six + QA sheets
    python3 tools/asset-pipeline/enemies2d/build_forest.py --kinds=bat,sentry
    python3 tools/asset-pipeline/enemies2d/build_forest.py --evidence-only

Output: assets/art/sprites/enemies_drawn/<kind>/... (as build.py) and the
registry assets/art/sprites/enemies_drawn/enemies_drawn_forest.json (merged
with enemies_drawn*.json by src/enemies/drawn_enemy_visual.gd). Extra keys:
"block" (one-shot played when the front shield takes a hit), "projectile"
(Сучковик's flying / stuck branch-spear: file, stuck, tip in sprite px).
QA: production/qa/evidence/enemies-drawn-forest.png, enemies-drawn-forest-anims.png.
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
from base import render, to_px, part_pivot, PX_PER_WORLD, SHEET_PX, DOWN  # noqa: E402
from kinds_forest import KINDS, STATES, spear_canvas  # noqa: E402
from build import grid, crop_part, hero_idle, FONT, OUT, EV, SUFFIX  # noqa: E402

REG = os.path.join(OUT, 'enemies_drawn_forest.json')
ORDER = ['ringer', 'rootling', 'bat', 'sentry', 'suchkovik', 'lesavka']
NAMES = {'ringer': 'Аука', 'rootling': 'Лешачонок', 'bat': 'Нетопырь', 'sentry': 'Упырь-щитник',
         'suchkovik': 'Сучковик', 'lesavka': 'Лесавка'}
EXTRA = {'sentry': {'block': 'block'}}


def plan(kind):
    cls, anims_fn, sever, live = KINDS[kind]
    anims = anims_fn()
    out = []
    for a, (poses, fps, loop) in anims.items():
        out.append((a, a, 'full', poses, fps, loop))
        for limb in sever:
            if a in live:
                out.append((a + SUFFIX['no' + limb], a, 'no' + limb, poses, fps, loop))
    if 'death' in anims:
        for limb in sever:
            poses, fps, loop = anims['death']
            out.append(('death_sever_' + limb, 'death_sever_' + limb, 'no' + limb, poses, fps, loop))
    return cls, anims, sever, out


def job(args):
    kind, sheet, i, mode = args
    cls, _, _, out = plan(kind)
    poses = [o for o in out if o[0] == sheet][0][3]
    return kind, sheet, i, render(cls, poses[i], mode, seed=7 + sum(map(ord, kind)) % 5)


def build_spear(d):
    meta = {}
    for stuck, name in ((False, 'suchkovik_spear.png'), (True, 'suchkovik_spear_stuck.png')):
        cv = spear_canvas(stuck)
        im = cv.image(DOWN)
        im.save(os.path.join(d, name), optimize=True)
        x0 = float(cv.X[0, 0]) - 0.5 / cv.S
        tip = [round(-x0 * SHEET_PX, 1), round(im.size[1] / 2.0, 1)]
        meta['stuck' if stuck else 'file'] = name
        meta['tip'] = tip
    meta['size'] = list(im.size)
    return meta


def build_kinds(kinds):
    reg = json.load(open(REG)) if os.path.exists(REG) else {}
    reg['_note'] = ('Hand-drawn Тёмный бор enemies (tools/asset-pipeline/enemies2d/build_forest.py); format as '
                    'enemies_drawn.json. block: one-shot when the front shield stops a hit; projectile: the '
                    'branch-spear sprites (tip = sprite px of the point, the spear lies along +x).')
    reg['px_per_world'] = PX_PER_WORLD
    reg.setdefault('kinds', {})
    jobs, plans = [], {}
    for k in kinds:
        plans[k] = plan(k)
        for sheet, a, mode, poses, fps, loop in plans[k][3]:
            jobs += [(k, sheet, i, mode) for i in range(len(poses))]
    res = {}
    with Pool(os.cpu_count() or 2) as pool:
        for k, sheet, i, im in pool.imap_unordered(job, jobs, chunksize=2):
            res[(k, sheet, i)] = im
    for k in kinds:
        cls, anims, sever, out = plans[k]
        x0, x1, y0, y1 = cls.BOUNDS
        cell = [int((x1 - x0) * SHEET_PX), int((y1 - y0) * SHEET_PX)]
        d = os.path.join(OUT, k)
        os.makedirs(d, exist_ok=True)
        meta = {'cell': cell, 'origin': [round(v, 1) for v in to_px(cls, (0.0, 0.0))], 'anims': {}, 'parts': {},
                'states': STATES[k]}
        meta.update(EXTRA.get(k, {}))
        for sheet, a, mode, poses, fps, loop in out:
            n = len(poses)
            cols, rows = grid(n)
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
            part, pv = crop_part(im, part_pivot(cls, idle0, limb))
            part.save(os.path.join(d, '%s_part_%s.png' % (k, limb)), optimize=True)
            meta['parts'][limb] = {'file': '%s_part_%s.png' % (k, limb), 'pivot': pv, 'size': list(part.size)}
        if k == 'suchkovik':
            meta['projectile'] = build_spear(d)
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


def bg(w, h):
    """Forest night: art bible §4.2 Тёмный бор middle -> near layer."""
    y = np.linspace(0, 1, h)[:, None, None]
    top, bot = np.array([0x1B, 0x2A, 0x44]), np.array([0x0F, 0x16, 0x26])
    arr = (top * (1 - y) + bot * y) * np.ones((1, w, 1))
    return Image.fromarray(arr.astype(np.uint8)).convert('RGBA')


def lineup(path):
    """1080p scale: enemy sheet px = screen px; the hero is 160 px."""
    f = ImageFont.truetype(FONT, 18)
    W_, H_ = 1900, 700
    can = bg(W_, H_)
    dr = ImageDraw.Draw(can)
    hero, ho = hero_idle()
    rows = (('idle', 0, 'стойка'), ('windup', 3, 'замах'))
    for row, (sheet, idx, label) in enumerate(rows):
        gy = 300 + row * 330
        dr.line((0, gy, W_, gy), fill=(70, 62, 52), width=2)
        dr.text((10, gy - 270), label, font=f, fill=(220, 210, 180))
        can.alpha_composite(hero, (int(90 - ho[0]), int(gy - ho[1])))
        x = 300
        for k in ORDER:
            s = sheet
            if k == 'bat':
                s = 'idle' if row == 0 else 'windup'
            im, reg = frame(k, s, idx)
            ox, oy = reg['origin']
            yy = gy - (130 if k == 'bat' else 0)
            can.alpha_composite(im, (int(x - ox), int(yy - oy)))
            if row == 0:
                dr.text((x - 50, gy + 8), NAMES[k], font=f, fill=(230, 220, 190))
            if k == 'suchkovik' and row == 1:
                sp = Image.open(os.path.join(OUT, k, reg['projectile']['file']))
                can.alpha_composite(sp, (int(x + 110), int(gy - 250 - sp.size[1] / 2)))
            x += 270
    can.convert('RGB').save(path)


def contact(path):
    f = ImageFont.truetype(FONT, 13)
    reg_all = json.load(open(REG))['kinds']
    rows = []
    for k in ORDER:
        for a, m in reg_all[k]['anims'].items():
            if a.startswith('death_sever') or (k, a) in (('bat', 'move'), ('bat', 'attack'), ('lesavka', 'move'),
                                                       ('suchkovik', 'attack')):
                continue
            rows.append((k, a, m['frames']))
    cw = 130
    W_ = 160 + cw * 8
    half = (len(rows) + 1) // 2
    H_ = 120 * half + 40
    can = bg(W_ * 2, H_)
    dr = ImageDraw.Draw(can)
    for r, (k, a, n) in enumerate(rows):
        col, rr = divmod(r, half)
        ox, oy = col * W_, 20 + rr * 120
        dr.text((ox + 6, oy + 50), '%s\n%s' % (k, a), font=f, fill=(230, 220, 190))
        for i in range(min(n, 8)):
            im, reg = frame(k, a, i)
            sc = min(1.0, 118.0 / im.size[1], (cw - 4) / im.size[0])
            im = im.resize((max(1, int(im.size[0] * sc)), max(1, int(im.size[1] * sc))), Image.LANCZOS)
            can.alpha_composite(im, (ox + 150 + i * cw, oy))
    can.convert('RGB').save(path)


def sever(path):
    f = ImageFont.truetype(FONT, 16)
    can = bg(1900, 520)
    dr = ImageDraw.Draw(can)
    reg_all = json.load(open(REG))['kinds']
    x = 150
    for k in ORDER:
        reg = reg_all[k]
        if not reg['parts']:
            continue
        dr.text((x - 60, 12), NAMES[k], font=f, fill=(230, 220, 190))
        y = 200
        for s in ('idle_noarm', 'idle_nohead'):
            if 'no' + s.split('_no')[1] not in reg['anims']['idle']['variants']:
                continue
            im, _ = frame(k, s, 0)
            ox, oy = reg['origin']
            can.alpha_composite(im, (int(x - ox), int(y - oy)))
            dr.text((x - 60, y + 4), s, font=f, fill=(200, 190, 160))
            y += 190
        px = x - 70
        for limb, p in reg['parts'].items():
            pim = Image.open(os.path.join(OUT, k, p['file'])).rotate(25, expand=True, resample=Image.BICUBIC)
            can.alpha_composite(pim, (px, 500 - pim.size[1]))
            px += pim.size[0] + 10
        x += 300
    can.convert('RGB').save(path)


def evidence():
    os.makedirs(EV, exist_ok=True)
    lineup(os.path.join(EV, 'enemies-drawn-forest.png'))
    contact(os.path.join(EV, 'enemies-drawn-forest-anims.png'))
    sever(os.path.join(EV, 'enemies-drawn-forest-sever.png'))


if __name__ == '__main__':
    args = sys.argv[1:]
    if '--evidence-only' not in args:
        kinds = ORDER
        for a in args:
            if a.startswith('--kinds='):
                kinds = a.split('=')[1].split(',')
        build_kinds(kinds)
    evidence()

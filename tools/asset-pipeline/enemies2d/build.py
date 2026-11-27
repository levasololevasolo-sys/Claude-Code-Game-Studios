"""Builds the hand-drawn Swamp enemy sheets, cut-out parts and the drawn weapons.

    python3 tools/asset-pipeline/enemies2d/build.py              # everything -> assets/art/sprites/
    python3 tools/asset-pipeline/enemies2d/build.py --kinds balvan,crawler --no-weapons
    python3 tools/asset-pipeline/enemies2d/build.py --evidence-only   # QA sheets from the built PNGs

Output: assets/art/sprites/enemies_drawn/<kind>/<kind>_<anim>[_noarm|_nohead].png
(frames in a cols x rows grid), <kind>_part_arm.png / _part_head.png, and the
registry enemies_drawn.json (cell, origin, px_per_world, anims with variants,
parts with pivots, the state -> animation map read by
src/enemies/drawn_enemy_visual.gd). Weapons: assets/art/sprites/weapons_drawn/.
QA sheets: production/qa/evidence/enemies-drawn-*.png, weapons-drawn.png.
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
from base import render, to_px, part_pivot, PX_PER_WORLD, SHEET_PX  # noqa: E402
from kinds import KINDS  # noqa: E402
import weapons  # noqa: E402

REPO = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
OUT = os.path.join(REPO, 'assets', 'art', 'sprites', 'enemies_drawn')
WOUT = os.path.join(REPO, 'assets', 'art', 'sprites', 'weapons_drawn')
EV = os.path.join(REPO, 'production', 'qa', 'evidence')
FONT = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'

# enemy state -> animation. anim: the sheet; k: stat whose duration drives the
# progress (1 - t / stat), "" = by time; moving: the sheet while |vel.x| > 5.
# after: one-shot played when the enemy leaves that state (the thrower's throw).
STATES = {
    'balvan': {'walk': {'anim': 'idle', 'moving': 'move'}, 'wind': {'anim': 'windup', 'k': 'wind'},
               'swing': {'anim': 'attack', 'k': 'swing_time'}, 'recover': {'anim': 'idle'}},
    'crawler': {'walk': {'anim': 'idle', 'moving': 'move'}, 'crouch': {'anim': 'windup', 'k': 'crouch'},
                'wind': {'anim': 'windup', 'k': 'wind'}, 'charge': {'anim': 'charge'}, 'leap': {'anim': 'attack'},
                'recover': {'anim': 'idle'}},
    'thrower': {'walk': {'anim': 'idle', 'moving': 'move'}, 'aim': {'anim': 'windup', 'k': 'aim', 'after': 'throw'},
                'shove': {'anim': 'attack', 'k': 'shove_wind'}},
    'bloat': {'approach': {'anim': 'idle', 'moving': 'move'}, 'swell': {'anim': 'inflate', 'k': 'fuse'}},
    'shishiga': {'walk': {'anim': 'idle', 'moving': 'move'}, 'crouch': {'anim': 'windup', 'k': 'crouch'},
                 'leap': {'anim': 'attack'}, 'cling': {'anim': 'cling'}, 'recover': {'anim': 'idle'}},
    'bognitsa': {'hide': {'anim': 'hummock'}, 'bubble': {'anim': 'bubble'}, 'dive': {'anim': 'dive', 'k': 'dive_time'},
                 'rise': {'anim': 'surface', 'k': 'rise'}, 'walk': {'anim': 'idle', 'moving': 'move'},
                 'wind': {'anim': 'windup', 'k': 'wind'}, 'swipe': {'anim': 'attack', 'k': 'swipe_time'},
                 'recover': {'anim': 'idle'}},
    'vodyanitsa': {'walk': {'anim': 'idle', 'moving': 'move'}, 'song': {'anim': 'song'},
                   'push_wind': {'anim': 'windup', 'k': 'push_wind'}, 'push': {'anim': 'attack', 'k': 'push_time'}},
}
SUFFIX = {'full': '', 'noarm': '_noarm', 'nohead': '_nohead'}


def plan(kind):
    cls, anims_fn, sever, live = KINDS[kind]
    anims = anims_fn()
    out = []  # (sheet name, anim, mode, poses, fps, loop)
    for a, (poses, fps, loop) in anims.items():
        out.append((a, a, 'full', poses, fps, loop))
        for limb in sever:
            mode = 'no' + limb
            if a in live and not (kind == 'crawler'):
                out.append((a + SUFFIX[mode], a, mode, poses, fps, loop))
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


def grid(n):
    cols = min(n, 8)
    return cols, (n + cols - 1) // cols


def crop_part(img, pivot, pad=3):
    a = np.asarray(img)[..., 3]
    ys, xs = np.where(a > 8)
    x0, x1 = max(0, xs.min() - pad), min(img.size[0], xs.max() + pad + 1)
    y0, y1 = max(0, ys.min() - pad), min(img.size[1], ys.max() + pad + 1)
    return img.crop((x0, y0, x1, y1)), [round(pivot[0] - x0, 1), round(pivot[1] - y0, 1)]


def build_kinds(kinds):
    reg_path = os.path.join(OUT, 'enemies_drawn.json')
    reg = json.load(open(reg_path)) if os.path.exists(reg_path) else {}
    reg['_note'] = ('Hand-drawn enemy sheets (tools/asset-pipeline/enemies2d/build.py). cell/origin in sheet px '
                    '(origin = ground under the hit box centre); px_per_world sheet px per world px; anims: '
                    'frames/fps/loop/cols/rows and variants (noarm, nohead) with their own sheets; parts: cut-out '
                    'arm/head sprites with the pivot (shoulder / neck) in part px; states: enemy state -> '
                    '{anim, k: stat driving the progress, moving: sheet while moving, after: one-shot on leaving}.')
    reg['px_per_world'] = PX_PER_WORLD
    reg.setdefault('kinds', {})
    jobs = []
    plans = {}
    for k in kinds:
        cls, anims, sever, out = plan(k)
        plans[k] = (cls, anims, sever, out)
        for sheet, a, mode, poses, fps, loop in out:
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
        reg['kinds'][k] = meta
        print(k, 'frames', sum(len(o[3]) for o in out))
    json.dump(reg, open(reg_path, 'w'), indent=1, ensure_ascii=False)
    return res


def build_weapons():
    os.makedirs(WOUT, exist_ok=True)
    reg = {'_note': 'Drawn hero weapon bodies (tools/asset-pipeline/enemies2d/weapons.py): the sprite lies along +x '
                    'from grip; tip_px / back_px = forward / rear length in sprite px (player.gd scales them to reach).'}
    for name in weapons.BOX:
        im = weapons.draw(name)
        im.save(os.path.join(WOUT, '%s.png' % name), optimize=True)
        reg[name] = dict(weapons.meta(name), file='%s.png' % name)
    json.dump(reg, open(os.path.join(WOUT, 'weapons_drawn.json'), 'w'), indent=1)


# ---------------- QA sheets ----------------
def frame(kind, sheet, i):
    reg = json.load(open(os.path.join(OUT, 'enemies_drawn.json')))['kinds'][kind]
    a = reg['anims'][sheet.replace('_noarm', '').replace('_nohead', '')]
    cw, ch = reg['cell']
    im = Image.open(os.path.join(OUT, kind, '%s_%s.png' % (kind, sheet)))
    i = min(i, a['frames'] - 1)
    return im.crop(((i % a['cols']) * cw, (i // a['cols']) * ch, (i % a['cols'] + 1) * cw, (i // a['cols'] + 1) * ch)), reg


def bg(w, h):
    y = np.linspace(0, 1, h)[:, None, None]
    top, bot = np.array([34, 44, 40]), np.array([20, 24, 22])
    arr = (top * (1 - y) + bot * y) * np.ones((1, w, 1))
    return Image.fromarray(arr.astype(np.uint8)).convert('RGBA')


NAMES = {'balvan': 'Болванчик', 'crawler': 'Трясинник', 'thrower': 'Упырь-метатель', 'bloat': 'Утопленник',
         'shishiga': 'Шишига', 'bognitsa': 'Болотница', 'vodyanitsa': 'Водяница'}
ORDER = ['balvan', 'crawler', 'thrower', 'bloat', 'shishiga', 'bognitsa', 'vodyanitsa']


def hero_idle():
    im = Image.open(os.path.join(REPO, 'assets/art/sprites/hero_drawn/t1/hero_idle.png')).crop((0, 0, 320, 288))
    meta = json.load(open(os.path.join(REPO, 'assets/art/sprites/hero_drawn/hero_drawn_sheets.json')))
    k = 160.0 / meta['height_px']
    return im.resize((int(320 * k), int(288 * k)), Image.LANCZOS), (meta['origin'][0] * k, meta['origin'][1] * k)


def lineup(path):
    """1080p scale: enemy sheet px = screen px; the hero is 160 px."""
    f = ImageFont.truetype(FONT, 18)
    W_, H_ = 1900, 640
    can = bg(W_, H_)
    dr = ImageDraw.Draw(can)
    hero, ho = hero_idle()
    for row, (sheet, idx, label) in enumerate((('idle', 0, 'стойка'), ('windup', 3, 'замах'))):
        gy = 280 + row * 300
        dr.line((0, gy, W_, gy), fill=(60, 74, 62), width=2)
        dr.text((10, gy - 250), label, font=f, fill=(220, 210, 180))
        can.alpha_composite(hero, (int(90 - ho[0]), int(gy - ho[1])))
        x = 260
        for k in ORDER:
            s = 'hummock' if (k == 'bognitsa' and row == 0) else sheet
            im, reg = frame(k, s, idx if s != 'hummock' else 0)
            ox, oy = reg['origin']
            can.alpha_composite(im, (int(x - ox), int(gy - oy)))
            if k == 'bognitsa' and row == 0:
                im2, _ = frame(k, 'idle', 0)
                can.alpha_composite(im2, (int(x + 190 - ox), int(gy - oy)))
            if row == 0:
                dr.text((x - 40, gy + 8), NAMES[k], font=f, fill=(230, 220, 190))
            x += 250 if k != 'bognitsa' else 330
    can.convert('RGB').save(path)


def contact(path):
    f = ImageFont.truetype(FONT, 13)
    rows = []
    for k in ORDER:
        reg = json.load(open(os.path.join(OUT, 'enemies_drawn.json')))['kinds'][k]
        for a, m in reg['anims'].items():
            if a.startswith('death_sever'):
                continue
            rows.append((k, a, m['frames']))
    cw = 130
    W_ = 160 + cw * 8
    H_ = 120 * len(rows) // 2 + 40
    can = bg(W_ * 2, H_)
    dr = ImageDraw.Draw(can)
    for r, (k, a, n) in enumerate(rows):
        col, rr = divmod(r, (len(rows) + 1) // 2)
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
    can = bg(1900, 760)
    dr = ImageDraw.Draw(can)
    x = 120
    for k in ORDER:
        reg = json.load(open(os.path.join(OUT, 'enemies_drawn.json')))['kinds'][k]
        if not reg['parts']:
            continue
        dr.text((x - 60, 12), NAMES[k], font=f, fill=(230, 220, 190))
        y = 230
        for s in ('idle_noarm', 'attack_noarm', 'idle_nohead', 'windup_nohead'):
            base = s.split('_')[0]
            if s.endswith('noarm') and 'arm' not in reg['parts'] or s.endswith('nohead') and 'head' not in reg['parts']:
                continue
            if 'no' + s.split('_no')[1] not in reg['anims'][base]['variants']:
                continue
            im, _ = frame(k, s, 2 if 'attack' in s or 'windup' in s else 0)
            ox, oy = reg['origin']
            sc = min(1.0, 160.0 / im.size[1])
            im = im.resize((int(im.size[0] * sc), int(im.size[1] * sc)), Image.LANCZOS)
            can.alpha_composite(im, (int(x - ox * sc), int(y - oy * sc)))
            dr.text((x - 60, y + 4), s, font=f, fill=(200, 190, 160))
            y += 130
        py = 700
        for limb, p in reg['parts'].items():
            pim = Image.open(os.path.join(OUT, k, p['file'])).rotate(25, expand=True, resample=Image.BICUBIC)
            can.alpha_composite(pim, (x - 70 + (0 if limb == 'arm' else 90), py - pim.size[1]))
        x += 260
    dr.text((10, 735), 'Без руки / без головы (кадры-варианты) и отлетающие части (_part_arm / _part_head)', font=f,
            fill=(200, 190, 160))
    can.convert('RGB').save(path)


def weapon_sheet(path):
    f = ImageFont.truetype(FONT, 18)
    reg = json.load(open(os.path.join(WOUT, 'weapons_drawn.json')))
    can = bg(1000, 560)
    dr = ImageDraw.Draw(can)
    names = {'stick': 'Дрын', 'blade': 'Меч', 'spear': 'Копьё', 'hammer': 'Молот', 'staff': 'Шест', 'sickles': 'Серпы'}
    y = 30
    for n in ('stick', 'blade', 'spear', 'hammer', 'staff', 'sickles'):
        im = Image.open(os.path.join(WOUT, reg[n]['file']))
        dr.text((20, y + im.size[1] / 2 - 10), names[n], font=f, fill=(230, 220, 190))
        can.alpha_composite(im, (int(260 - reg[n]['grip'][0]), y))
        dr.ellipse((256, y + reg[n]['grip'][1] - 4, 264, y + reg[n]['grip'][1] + 4), outline=(255, 200, 80))
        y += im.size[1] + 14
    can.convert('RGB').save(path)


def evidence():
    os.makedirs(EV, exist_ok=True)
    lineup(os.path.join(EV, 'enemies-drawn-swamp.png'))
    contact(os.path.join(EV, 'enemies-drawn-anims.png'))
    sever(os.path.join(EV, 'enemies-drawn-sever.png'))
    weapon_sheet(os.path.join(EV, 'weapons-drawn.png'))


if __name__ == '__main__':
    args = sys.argv[1:]
    if '--evidence-only' not in args:
        kinds = ORDER
        for a in args:
            if a.startswith('--kinds='):
                kinds = a.split('=')[1].split(',')
        build_kinds(kinds)
        if '--no-weapons' not in args:
            build_weapons()
    evidence()

"""Builds the hand-drawn Застава NPC sheets, portraits and the registry.

    python3 tools/asset-pipeline/npc2d/build.py                 # everything
    python3 tools/asset-pipeline/npc2d/build.py --npcs potap,sova
    python3 tools/asset-pipeline/npc2d/build.py --evidence-only # QA sheets from the built PNGs
    python3 tools/asset-pipeline/npc2d/build.py --preview DIR   # idle frame 0 + portraits, quick look

Output: assets/art/sprites/npc_drawn/<id>/<id>_<anim>.png (frames in a cols x rows
grid; anims idle / talk / react), <id>_portrait_<calm|warm>.png (512 px bust) and
the registry npc_drawn.json (cell, origin = the ground point under the NPC,
px_per_world, height_world, flip, anims, portraits) read by src/base/npc_sprite.gd.
QA sheets: production/qa/evidence/npcs-drawn.png, npcs-portraits.png.
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
from base import render, render_portrait, to_px, PX_PER_WORLD, SHEET_PX  # noqa: E402
from npcs import NPCS  # noqa: E402

REPO = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
OUT = os.path.join(REPO, 'assets', 'art', 'sprites', 'npc_drawn')
EV = os.path.join(REPO, 'production', 'qa', 'evidence')
FONT = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
NAMES = {'dolya': 'Пряха Доля', 'potap': 'Кузнец Потап', 'sova': 'Ведунья Сова', 'bayun': 'Кот Баюн',
         'chur': 'Чур', 'ofenya': 'Офеня', 'prorok': 'Пророк'}
HERO_WORLD_H = 160.0 / 1.5   # the drawn hero: 160 screen px at camera zoom 1.5


def seed_of(npc):
    return 7 + sum(map(ord, npc)) % 5


def job(args):
    npc, anim, i = args
    cls = NPCS[npc]
    poses = cls.anims()[anim][0]
    return npc, anim, i, render(cls, poses[i], seed=seed_of(npc))


def pjob(args):
    npc, var = args
    cls = NPCS[npc]
    return npc, var, render_portrait(cls, cls.PORTRAIT_POSES[var], seed=seed_of(npc))


def grid(n):
    cols = min(n, 8)
    return cols, (n + cols - 1) // cols


def build(npcs):
    reg_path = os.path.join(OUT, 'npc_drawn.json')
    os.makedirs(OUT, exist_ok=True)
    reg = json.load(open(reg_path)) if os.path.exists(reg_path) else {}
    reg['_note'] = ('Hand-drawn Застава NPCs (tools/asset-pipeline/npc2d/build.py). cell/origin in sheet px '
                    '(origin = the ground under the NPC); px_per_world sheet px per world px; height_world = top '
                    'of the idle frame above the ground; flip = mirror to face the hero; anims idle/talk loops, '
                    'react one-shot; portraits 512 px busts facing right.')
    reg['px_per_world'] = PX_PER_WORLD
    reg.setdefault('npcs', {})
    jobs, pjobs = [], []
    for n in npcs:
        for a, (poses, fps, loop) in NPCS[n].anims().items():
            jobs += [(n, a, i) for i in range(len(poses))]
        pjobs += [(n, v) for v in NPCS[n].PORTRAIT_POSES]
    res, por = {}, {}
    with Pool(os.cpu_count() or 2) as pool:
        for n, a, i, im in pool.imap_unordered(job, jobs, chunksize=1):
            res[(n, a, i)] = im
        for n, v, im in pool.imap_unordered(pjob, pjobs):
            por[(n, v)] = im
    for n in npcs:
        cls = NPCS[n]
        d = os.path.join(OUT, n)
        os.makedirs(d, exist_ok=True)
        x0, x1, y0, y1 = cls.BOUNDS
        cell = [int((x1 - x0) * SHEET_PX), int((y1 - y0) * SHEET_PX)]
        org = to_px(cls, (0.0, 0.0))
        row = {'cell': cell, 'origin': [round(org[0], 1), round(org[1], 1)], 'flip': cls.FLIP, 'anims': {},
               'portraits': {}}
        for a, (poses, fps, loop) in cls.anims().items():
            cols, rows = grid(len(poses))
            sheet = Image.new('RGBA', (cols * cell[0], rows * cell[1]), (0, 0, 0, 0))
            for i in range(len(poses)):
                im = res[(n, a, i)]
                sheet.paste(im, ((i % cols) * cell[0], (i // cols) * cell[1]))
            f = '%s_%s.png' % (n, a)
            sheet.save(os.path.join(d, f), optimize=True)
            row['anims'][a] = {'sheet': '%s/%s' % (n, f), 'frames': len(poses), 'fps': fps, 'loop': loop,
                               'cols': cols, 'rows': rows}
        al = np.asarray(res[(n, 'idle', 0)])[..., 3]
        ys = np.where(al.max(axis=1) > 64)[0]
        row['height_world'] = round((org[1] - ys.min()) / PX_PER_WORLD, 1)
        for v in cls.PORTRAIT_POSES:
            f = '%s_portrait_%s.png' % (n, v)
            por[(n, v)].save(os.path.join(d, f), optimize=True)
            row['portraits'][v] = '%s/%s' % (n, f)
        reg['npcs'][n] = row
        print('built', n, cell, 'h', row['height_world'])
    json.dump(reg, open(reg_path, 'w'), ensure_ascii=False, indent=1)


def frame(n, a, i):
    reg = json.load(open(os.path.join(OUT, 'npc_drawn.json')))
    r = reg['npcs'][n]
    an = r['anims'][a]
    sh = Image.open(os.path.join(OUT, an['sheet']))
    cw, ch = r['cell']
    i = i % an['frames']
    return sh.crop(((i % an['cols']) * cw, (i // an['cols']) * ch, (i % an['cols'] + 1) * cw, (i // an['cols'] + 1) * ch)), r


def hero_frame():
    d = os.path.join(REPO, 'assets', 'art', 'sprites', 'hero_drawn')
    meta = json.load(open(os.path.join(d, 'hero_drawn_sheets.json')))
    cw, ch = meta['cell']
    im = Image.open(os.path.join(d, 't1', 'hero_idle.png')).crop((0, 0, cw, ch))
    k = PX_PER_WORLD * HERO_WORLD_H / meta['height_px']
    im = im.resize((int(cw * k), int(ch * k)), Image.LANCZOS)
    return im, (meta['origin'][0] * k, meta['origin'][1] * k)


def bg(w, h):
    g = np.linspace(0, 1, h)[:, None]
    top, bot = np.array([0x22, 0x24, 0x30]), np.array([0x2A, 0x1E, 0x18])
    a = (top * (1 - g) + bot * g)[:, None, :].repeat(w, 1)[:, :, 0, :] if False else (top * (1 - g[..., None]) + bot * g[..., None])
    arr = np.broadcast_to(a, (h, w, 3)).astype(np.uint8)
    return Image.fromarray(arr.copy(), 'RGB').convert('RGBA')


def evidence():
    os.makedirs(EV, exist_ok=True)
    order = ['dolya', 'bayun', 'chur', 'sova', 'potap', 'ofenya']
    font = ImageFont.truetype(FONT, 22)
    small = ImageFont.truetype(FONT, 16)
    picks = [('стойка (idle)', 'idle', 0), ('жест (idle)', 'idle', 8), ('разговор (talk)', 'talk', 3),
             ('реакция (react)', 'react', 5)]
    W, rowh = 2200, 470
    img = bg(W, rowh * len(picks) + 20)
    dr = ImageDraw.Draw(img)
    hero, horg = hero_frame()
    for r, (label, a, i) in enumerate(picks):
        gy = 40 + r * rowh + 400
        dr.line([(0, gy), (W, gy)], fill=(90, 100, 95), width=2)
        dr.text((12, r * rowh + 14), label, font=font, fill=(233, 223, 201))
        img.alpha_composite(hero, (int(110 - horg[0]), int(gy - horg[1])))
        x = 330
        for n in order:
            fr, meta = frame(n, a, i)
            ox, oy = meta['origin']
            img.alpha_composite(fr, (int(x - ox), int(gy - oy)))
            if r == 0:
                dr.text((x - 70, gy + 8), NAMES[n], font=small, fill=(233, 223, 201))
            x += 330 if n != 'potap' else 380
    img.convert('RGB').save(os.path.join(EV, 'npcs-drawn.png'))
    # portraits
    P = 300
    pim = bg(P * 6 + 70, P * 2 + 110)
    dr = ImageDraw.Draw(pim)
    for c, n in enumerate(order):
        for r, v in enumerate(('calm', 'warm')):
            x, y = 10 + c * (P + 10), 40 + r * (P + 30)
            dr.rectangle([x, y, x + P, y + P], fill=(33, 23, 15), outline=(179, 38, 46), width=3)
            reg = json.load(open(os.path.join(OUT, 'npc_drawn.json')))
            p = Image.open(os.path.join(OUT, reg['npcs'][n]['portraits'][v])).resize((P - 8, P - 8), Image.LANCZOS)
            pim.alpha_composite(p, (x + 4, y + 4))
            if r == 0:
                dr.text((x + 6, 10), NAMES[n], font=font, fill=(255, 201, 74))
    dr.text((10, P * 2 + 80), 'портреты 512 px: спокойно / тепло (окно диалога)', font=small, fill=(169, 156, 134))
    pim.convert('RGB').save(os.path.join(EV, 'npcs-portraits.png'))
    print('evidence written')


def preview(out):
    os.makedirs(out, exist_ok=True)
    jobs = [(n, 'idle', 0) for n in NPCS]
    with Pool(os.cpu_count() or 2) as pool:
        ims = pool.map(job, jobs)
        pims = pool.map(pjob, [(n, 'calm') for n in NPCS])
    W = sum(im.size[0] for _, _, _, im in ims) + 20
    H = max(im.size[1] for _, _, _, im in ims) + 10
    img = bg(W, H + 260)
    x = 10
    for n, _, _, im in ims:
        img.alpha_composite(im, (x, H - im.size[1]))
        x += im.size[0]
    x = 10
    for n, _, im in pims:
        img.alpha_composite(im.resize((250, 250)), (x, H + 5))
        x += 255
    img.convert('RGB').save(os.path.join(out, 'preview.png'))


if __name__ == '__main__':
    args = sys.argv[1:]
    if '--preview' in args:
        preview(args[args.index('--preview') + 1])
        sys.exit(0)
    if '--evidence-only' not in args:
        sel = list(NPCS)
        if '--npcs' in args:
            sel = args[args.index('--npcs') + 1].split(',')
        build(sel)
    evidence()

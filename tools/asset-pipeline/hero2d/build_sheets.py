"""Builds the drawn hero sheets for the game and the QA contact sheets.

    python3 tools/asset-pipeline/hero2d/build_sheets.py            # all tiers -> assets/art/sprites/hero_drawn/
    python3 tools/asset-pipeline/hero2d/build_sheets.py --preview DIR [anim ...]   # tier 1 + 5 contact sheets only

Output per tier N: assets/art/sprites/hero_drawn/tN/hero_<anim>.png (frames in a
cols x rows grid, cell 320x288, like the 3D sheets), plus one
hero_drawn_sheets.json shared by all tiers: cell, origin (ground under the
pelvis), height_px, and per animation frames/fps/loop/cols/rows and per-frame
`hand` (near fist, the weapon pivot) and `amulet` points in cell px.
Deterministic: fixed seeds, no randomness at build time.
"""
import os
import sys
import json
from multiprocessing import Pool

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from rig import render, to_px  # noqa: E402
from poses import ANIMS  # noqa: E402

REPO = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
OUT = os.path.join(REPO, 'assets', 'art', 'sprites', 'hero_drawn')
CELL = (320, 288)
TIERS = (1, 2, 3, 4, 5)


def job(args):
    tier, anim, i = args
    im, hand, amu = render(tier, ANIMS[anim][0][i])
    return tier, anim, i, im, hand, amu


def grid(n):
    cols = min(n, 8)
    return cols, (n + cols - 1) // cols


def build(tiers, anims, out_dir):
    jobs = [(t, a, i) for t in tiers for a in anims for i in range(len(ANIMS[a][0]))]
    res = {}
    with Pool(os.cpu_count() or 2) as pool:
        for t, a, i, im, hand, amu in pool.imap_unordered(job, jobs, chunksize=2):
            res[(t, a, i)] = (im, hand, amu)
    meta = {'cell': list(CELL), 'origin': [round(v, 1) for v in to_px((0.0, 0.0))], 'tiers': len(TIERS), 'anims': {}}
    a0 = np.asarray(res[(tiers[0], 'idle', 0)][0])[..., 3] if 'idle' in anims else None
    if a0 is not None:
        ys = np.where(a0.max(axis=1) > 128)[0]
        meta['height_px'] = int(meta['origin'][1] - ys.min())
    for a in anims:
        poses, fps, loop = ANIMS[a]
        n = len(poses)
        cols, rows = grid(n)
        meta['anims'][a] = {'frames': n, 'fps': fps, 'loop': loop, 'cols': cols, 'rows': rows,
                            'hand': [res[(tiers[0], a, i)][1] for i in range(n)],
                            'amulet': [res[(tiers[0], a, i)][2] for i in range(n)]}
        for t in tiers:
            sheet = Image.new('RGBA', (CELL[0] * cols, CELL[1] * rows), (0, 0, 0, 0))
            for i in range(n):
                sheet.paste(res[(t, a, i)][0], ((i % cols) * CELL[0], (i // cols) * CELL[1]))
            d = os.path.join(out_dir, 't%d' % t)
            os.makedirs(d, exist_ok=True)
            sheet.save(os.path.join(d, 'hero_%s.png' % a), optimize=True)
    return meta, res


def contact(res, tier, anims, path, scale=0.5):
    """Every frame of every animation for one tier, hand point marked."""
    cw, ch = int(CELL[0] * scale), int(CELL[1] * scale)
    cols = max(len(ANIMS[a][0]) for a in anims)
    W, H = 150 + cw * cols, ch * len(anims)
    img = Image.new('RGBA', (W, H), (44, 52, 46, 255))
    dr = ImageDraw.Draw(img)
    try:
        font = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 18)
    except OSError:
        font = ImageFont.load_default()
    for r, a in enumerate(anims):
        dr.text((8, r * ch + ch // 2 - 10), a, fill=(230, 220, 200, 255), font=font)
        dr.line([(0, r * ch), (W, r * ch)], fill=(70, 80, 72, 255))
        for i in range(len(ANIMS[a][0])):
            im, hand, _ = res[(tier, a, i)]
            sm = im.resize((cw, ch), Image.LANCZOS)
            x, y = 150 + i * cw, r * ch
            img.alpha_composite(sm, (x, y))
            hx, hy = x + hand[0] * scale, y + hand[1] * scale
            dr.ellipse([hx - 3, hy - 3, hx + 3, hy + 3], outline=(80, 220, 255, 255), width=2)
            gy = y + to_px((0, 0))[1] * scale
            dr.line([(x + 4, gy), (x + cw - 4, gy)], fill=(120, 130, 110, 255))
    img.convert('RGB').save(path)


def tiers_sheet(res, path):
    """Tiers 1-5 idle side by side, plus 160 px and 48 px silhouette checks."""
    cw, ch = CELL
    img = Image.new('RGBA', (cw * 5 + 260, ch + 60), (44, 52, 46, 255))
    dr = ImageDraw.Draw(img)
    try:
        font = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 18)
    except OSError:
        font = ImageFont.load_default()
    names = {1: '1 Павший', 2: '2 Странник', 3: '3 Ополченец', 4: '4 Витязь', 5: '5 Богатырь'}
    for t in TIERS:
        img.alpha_composite(res[(t, 'idle', 0)][0], ((t - 1) * cw, 0))
        dr.text(((t - 1) * cw + 100, ch + 20), names[t], fill=(230, 220, 200, 255), font=font)
    im = res[(1, 'idle', 0)][0]
    a = np.asarray(im)[..., 3]
    ys = np.where(a.max(axis=1) > 128)[0]
    hpx = to_px((0, 0))[1] - ys.min()
    k = 160.0 / hpx
    sm = im.resize((int(cw * k), int(ch * k)), Image.LANCZOS)
    img.alpha_composite(sm, (cw * 5 + 10, ch - sm.size[1]))
    sil = Image.new('RGBA', im.size, (0, 0, 0, 0))
    sil.putalpha(im.getchannel('A').point(lambda v: 255 if v > 128 else 0))
    k2 = 48.0 / hpx
    s2 = sil.resize((int(cw * k2), int(ch * k2)), Image.LANCZOS)
    box = Image.new('RGBA', (s2.size[0] + 10, s2.size[1] + 10), (205, 200, 190, 255))
    box.alpha_composite(s2, (5, 5))
    img.alpha_composite(box, (cw * 5 + 150, 40))
    dr.text((cw * 5 + 20, ch + 20), '160 px / 48 px', fill=(230, 220, 200, 255), font=font)
    img.convert('RGB').save(path)


if __name__ == '__main__':
    args = sys.argv[1:]
    if args and args[0] == '--preview':
        d = args[1]
        anims = args[2:] or list(ANIMS)
        os.makedirs(d, exist_ok=True)
        meta, res = build((1, 5), anims, os.path.join(d, 'sheets'))
        contact(res, 1, anims, os.path.join(d, 'anims_t1.png'))
        contact(res, 5, anims, os.path.join(d, 'anims_t5.png'))
        print(json.dumps({k: v for k, v in meta.items() if k != 'anims'}))
        sys.exit(0)
    jp = os.path.join(OUT, 'hero_drawn_sheets.json')
    if args and args[0] == '--only':  # rebuild some animations, keep the rest of the json
        meta, res = build(TIERS, args[1:], OUT)
        old = json.load(open(jp))
        old['anims'].update(meta['anims'])
        with open(jp, 'w') as f:
            json.dump(old, f, indent=1)
        sys.exit(0)
    meta, res = build(TIERS, list(ANIMS), OUT)
    with open(jp, 'w') as f:
        json.dump(meta, f, indent=1)
    ev = os.path.join(REPO, 'production', 'qa', 'evidence')
    contact(res, 1, list(ANIMS), os.path.join(ev, 'hero-drawn-anims.png'))
    contact(res, 5, list(ANIMS), os.path.join(ev, 'hero-drawn-anims-t5.png'))
    tiers_sheet(res, os.path.join(ev, 'hero-drawn-tiers.png'))
    print(json.dumps({k: v for k, v in meta.items() if k != 'anims'}))

"""Застава NPC sheets and portraits from the approved «Навь» art: the painted
full figure as a whole-body puppet (idle breathing, talk nods, react
start-and-settle), written over assets/art/sprites/npc_drawn/<npc>/ keeping
npc_drawn.json (cell, origin, frame counts); portraits (512 px busts) are the
top of the figure, calm and a warmer "warm" one.

    python3 tools/asset-pipeline/navart/npcs.py

The Prophet (prorok) has no painted sheet and keeps the npc2d art. Deterministic.
"""
import json
import math
import os

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
SRC = os.path.join(REPO, 'assets', 'art', 'navart', 'chars')
OUT = os.path.join(REPO, 'assets', 'art', 'sprites', 'npc_drawn')
REG = os.path.join(OUT, 'npc_drawn.json')
# npc -> (sheet, bust share of the figure's height)
NPCS = {
    'sova': ('char_npc_sova', 0.42), 'potap': ('char_npc_potap', 0.42), 'ofenya': ('char_npc_ofenya', 0.42),
    'chur': ('char_npc_chur', 0.5), 'bayun': ('char_npc_kot_bayun', 0.7), 'dolya': ('char_npc_dolya', 0.38),
    'prorok': ('char_npc_prorok', 0.4, 3),
}
# a third value: the sheet's own painted portrait piece, used instead of a bust crop


def body_of(sheet):
    ps = json.load(open(os.path.join(SRC, sheet, 'sheet.json')))['pieces']
    i = max(ps, key=lambda p: p['area'])['i']
    im = Image.open(os.path.join(SRC, sheet, '%02d.webp' % i)).convert('RGBA')
    return im.crop(im.getchannel('A').point(lambda v: 255 if v > 40 else 0).getbbox())


def old_height(name, cell, origin):
    p = os.path.join(OUT, name, '%s_idle.png' % name)
    im = Image.open(p).convert('RGBA').crop((0, 0, cell[0], cell[1]))
    b = im.getchannel('A').point(lambda v: 255 if v > 100 else 0).getbbox()
    return origin[1] - b[1]


def motion(anim, i, n):
    t = i / max(n - 1, 1)
    ph = 2 * math.pi * i / max(n, 1)
    if anim == 'idle':
        s = math.sin(ph)
        return 0.0, 0.012 * s, 1 - 0.008 * s, 1 + 0.016 * s
    if anim == 'talk':
        s = math.sin(ph * 2)
        return -2 * abs(s), 0.03 * s, 1, 1 + 0.01 * s
    k = math.sin(math.pi * t) * (1 - 0.4 * t)  # react: rears back, settles
    return 0.0, -0.09 * k, 1 - 0.02 * k, 1 + 0.04 * k


def frame(body, cell, origin, anim, i, n):
    dy, r, sx, sy = motion(anim, i, n)
    im = body.resize((max(1, round(body.width * sx)), max(1, round(body.height * sy))), Image.BICUBIC)
    P = max(im.size)
    big = Image.new('RGBA', (im.width + 2 * P, im.height + 2 * P), (0, 0, 0, 0))
    big.paste(im, (P, P))
    piv = (P + im.width / 2, P + im.height)
    if r:
        big = big.rotate(math.degrees(-r), resample=Image.BICUBIC, center=piv)
    out = Image.new('RGBA', tuple(cell), (0, 0, 0, 0))
    out.paste(big, (int(round(origin[0] - piv[0])), int(round(origin[1] - piv[1] + dy))), big)
    return out


def portrait(fig, share, warm):
    bust = fig.crop((0, 0, fig.width, int(fig.height * share)))
    k = 480 / max(bust.size)
    bust = bust.resize((round(bust.width * k), round(bust.height * k)), Image.LANCZOS)
    if warm:
        a = np.asarray(bust).astype(np.float32)
        a[..., 0] = np.minimum(255, a[..., 0] * 1.08 + 6)
        a[..., 2] *= 0.92
        bust = Image.fromarray(a.astype(np.uint8), 'RGBA')
    out = Image.new('RGBA', (512, 512), (0, 0, 0, 0))
    out.paste(bust, ((512 - bust.width) // 2, 512 - bust.height), bust)
    return out


def main():
    reg = json.load(open(REG))
    for name, spec in NPCS.items():
        sheet, share = spec[0], spec[1]
        row = reg['npcs'].get(name)
        if not row:
            continue
        cell, origin = row['cell'], row['origin']
        fig = body_of(sheet)
        h = old_height(name, cell, origin)
        k = min(h / fig.height, cell[0] * 0.96 / fig.width, origin[1] * 0.97 / fig.height)
        body = fig.resize((round(fig.width * k), round(fig.height * k)), Image.LANCZOS)
        for anim, m in row['anims'].items():
            n, cols, rows = m['frames'], m['cols'], m['rows']
            sh = Image.new('RGBA', (cell[0] * cols, cell[1] * rows), (0, 0, 0, 0))
            for i in range(n):
                sh.alpha_composite(frame(body, cell, origin, anim, i, n), ((i % cols) * cell[0], (i // cols) * cell[1]))
            sh.save(os.path.join(OUT, m['sheet']), optimize=True)
        for mood, path in row.get('portraits', {}).items():
            src = fig
            if len(spec) > 2:
                pim = Image.open(os.path.join(SRC, sheet, '%02d.webp' % spec[2])).convert('RGBA')
                src, share = pim.crop(pim.getchannel('A').point(lambda v: 255 if v > 40 else 0).getbbox()), 1.0
            portrait(src, share, mood != 'calm').save(os.path.join(OUT, path), optimize=True)
        row['height_world'] = round(body.height / reg['px_per_world'], 1)
    if 'navart' not in reg['_note']:
        reg['_note'] += ' NPCs with approved art are rebuilt by tools/asset-pipeline/navart/npcs.py.'
    with open(REG, 'w') as f:
        json.dump(reg, f, indent=1, ensure_ascii=False)
    print('npcs:', ' '.join(NPCS))


if __name__ == '__main__':
    main()

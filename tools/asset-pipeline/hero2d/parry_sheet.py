"""QA sheet of the drawn hero's parry poses per strike body (tiers 1 and 5:
guard, caught, whiffed), with the weapon line Player._draw_blade() puts at the
hand point and the contact flash on the caught frame; optional in-game shots
appended on the right.

    python3 tools/asset-pipeline/hero2d/parry_sheet.py OUT.png [ingame1.png ingame2.png ...]
"""
import json
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
SHEETS = os.path.join(REPO, 'assets', 'art', 'sprites', 'hero_drawn')
W, H = 320, 288
# Player.PARRY_BLADE [guard, caught, whiffed] and weapon_bodies.json reach
ANG = {"blade": [-0.3, -0.65, 0.5], "hammer": [-1.45, -0.35, 1.0], "spear": [-1.15, -1.4, 0.35],
       "staff": [-1.05, -1.3, 0.4], "sickles": [-1.0, -1.3, 0.4]}
REACH = {"blade": 78, "spear": 128, "sickles": 64, "hammer": 100, "staff": 96}


def main(out_path, extra):
    meta = json.load(open(os.path.join(SHEETS, 'hero_drawn_sheets.json')))
    px = meta['height_px'] * 1.5 / 160.0  # sheet px per world unit (camera zoom 1.5, 160 px hero)
    font = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 22)
    bodies = list(ANG)
    out = Image.new('RGBA', (W * 6, H * len(bodies)), (44, 52, 46, 255))
    d = ImageDraw.Draw(out)
    for r, b in enumerate(bodies):
        for c, (t, f) in enumerate([(1, 2), (1, 3), (1, 4), (5, 2), (5, 3), (5, 4)]):
            sh = Image.open(os.path.join(SHEETS, 't%d' % t, 'hero_parry_%s.png' % b))
            x, y = c * W, r * H
            out.alpha_composite(sh.crop((f * W, 0, (f + 1) * W, H)), (x, y))
            hx, hy = meta['anims']['parry_' + b]['hand'][f]
            a = ANG[b][f - 2]
            L = REACH[b] * 0.72 * px
            dx, dy = math.cos(a), math.sin(a)
            s0 = -0.5 if b == 'staff' else (-0.2 if b == 'spear' else 0.0)
            d.line([(x + hx + dx * L * s0, y + hy + dy * L * s0), (x + hx + dx * L, y + hy + dy * L)],
                   fill=(225, 235, 240, 255), width=6)
            if f == 3:
                k = min(L * 0.55, 40 * px)
                cx, cy = x + hx + dx * k, y + hy + dy * k
                d.ellipse([cx - 22, cy - 22, cx + 22, cy + 22], fill=(255, 240, 200, 210))
        d.text((8, r * H + 8), b, fill=(255, 230, 180, 255), font=font)
    shots = [Image.open(p).convert('RGBA') for p in extra]
    sw = max([s.width for s in shots] + [0])
    fin = Image.new('RGBA', (out.width + sw, max(out.height, sum(s.height for s in shots))), (44, 52, 46, 255))
    fin.alpha_composite(out, (0, 0))
    y = 0
    for s in shots:
        fin.alpha_composite(s, (out.width, y))
        y += s.height
    fin.convert('RGB').save(out_path)
    print(fin.size)


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2:])

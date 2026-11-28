"""The hero's weapon bodies from the approved «Навь» weapon sheets, written
over assets/art/sprites/weapons_drawn/ (format of enemies2d/weapons.py: the
sprite lies along +x from the grip; grip px, tip_px / back_px):

    python3 tools/asset-pipeline/navart/weapons.py

Each family takes one painted piece, turned so its long axis is horizontal
(head / blade to the right), scaled to the old sprite's length; the grip sits
GRIP of the way from the butt. Deterministic.
"""
import json
import math
import os

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
SRC = os.path.join(REPO, 'assets', 'art', 'navart', 'weapons')
OUT = os.path.join(REPO, 'assets', 'art', 'sprites', 'weapons_drawn')
# family -> (sheet, piece, grip share from the butt, flip so the head is right)
FAMILY = {
    'stick': ('weapons_main_1', 0, 0.12, False),
    'blade': ('weapons_main_2', 0, 0.16, False),
    'spear': ('weapons_main_2', 6, 0.3, False),
    'hammer': ('weapons_main_2', 9, 0.1, False),
    'staff': ('../chars/hero_weapons', 7, 0.38, False),
    'sickles': ('weapons_main_2', 3, 0.14, False),
}


def level(im):
    """Turns the piece so its long axis (alpha PCA) is horizontal."""
    a = np.asarray(im)[..., 3] > 60
    ys, xs = np.nonzero(a)
    c = np.cov(np.vstack([xs - xs.mean(), ys - ys.mean()]))
    w, v = np.linalg.eigh(c)
    ax = v[:, np.argmax(w)]
    ang = math.degrees(math.atan2(ax[1], ax[0]))
    if ang > 90:
        ang -= 180
    if ang < -90:
        ang += 180
    if abs(ang) > 3:
        im = im.rotate(ang, resample=Image.BICUBIC, expand=True)
        # the head of a diagonal piece was top-right: keep it on the right
    return im.crop(im.getchannel('A').point(lambda q: 255 if q > 40 else 0).getbbox())


def main():
    meta = json.load(open(os.path.join(OUT, 'weapons_drawn.json')))
    for fam, (sheet, i, gs, flip) in FAMILY.items():
        im = Image.open(os.path.join(SRC, sheet, '%02d.webp' % i)).convert('RGBA')
        im = level(im)
        if flip:
            im = im.transpose(Image.FLIP_LEFT_RIGHT)
        row = meta[fam]
        old_len = float(row['tip_px']) + float(row['back_px'])
        k = old_len / im.width
        im = im.resize((round(im.width * k), max(1, round(im.height * k))), Image.LANCZOS)
        gx = round(im.width * gs, 1)
        row['grip'] = [gx, round(im.height / 2, 1)]
        row['back_px'] = gx
        row['tip_px'] = round(im.width - gx, 1)
        im.save(os.path.join(OUT, row['file']), optimize=True)
    if 'navart' not in meta['_note']:
        meta['_note'] += ' Painted bodies from the approved art: tools/asset-pipeline/navart/weapons.py.'
    with open(os.path.join(OUT, 'weapons_drawn.json'), 'w') as f:
        json.dump(meta, f, indent=1, ensure_ascii=False)
    print('weapons:', ' '.join(FAMILY))


if __name__ == '__main__':
    main()

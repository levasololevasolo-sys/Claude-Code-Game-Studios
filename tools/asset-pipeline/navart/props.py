"""Chests and enemy projectiles from the approved «Навь» art:

    python3 tools/asset-pipeline/navart/props.py

- assets/art/props/chest_<plain|iron|gold>_<closed|open>.webp (pickups sheet;
  the iron and gold pairs come as one piece and are cut in two);
- assets/art/fx/shots/<name>.webp, flying to the right, and
  assets/art/fx/shots.json {enemy kind: res path} read by EnemyShot.
Deterministic.
"""
import json
import os

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
SRC = os.path.join(REPO, 'assets', 'art', 'navart')
PROPS = os.path.join(REPO, 'assets', 'art', 'props')
SHOTS = os.path.join(REPO, 'assets', 'art', 'fx', 'shots')
SHOT_PIECES = {'mud': 5, 'ice_shard': 6, 'ice_needle': 7, 'glob': 8, 'fire': 12, 'dark': 14, 'wind': 15, 'arrow': 1}
KIND_SHOT = {'thrower': 'mud', 'bat': 'glob', 'suchkovik': 'arrow', 'snezhnitsa': 'ice_needle', 'karachun': 'ice_shard',
             'jelly': 'ice_shard', 'kikimora': 'glob', 'likho': 'dark', 'morena': 'wind', 'mara': 'dark',
             'vodyanitsa': 'wind'}


def load(group, sheet, i):
    im = Image.open(os.path.join(SRC, group, sheet, '%02d.webp' % i)).convert('RGBA')
    return im.crop(im.getchannel('A').point(lambda v: 255 if v > 30 else 0).getbbox())


def halves(im):
    a = np.asarray(im)[..., 3].astype(np.float32).sum(axis=0)
    w = im.width
    c = w // 3 + int(np.argmin(a[w // 3:2 * w // 3]))
    return [x.crop(x.getchannel('A').point(lambda v: 255 if v > 30 else 0).getbbox())
            for x in (im.crop((0, 0, c, im.height)), im.crop((c, 0, w, im.height)))]


def fit(im, side):
    k = side / max(im.size)
    return im.resize((round(im.width * k), round(im.height * k)), Image.LANCZOS)


def main():
    os.makedirs(PROPS, exist_ok=True)
    os.makedirs(SHOTS, exist_ok=True)
    chests = {'plain': [load('props', 'pickups', 11), load('props', 'pickups', 12)],
              'iron': halves(load('props', 'pickups', 13)), 'gold': halves(load('props', 'pickups', 14))}
    for k, (c, o) in chests.items():
        fit(c, 160).save(os.path.join(PROPS, 'chest_%s_closed.webp' % k), 'WEBP', quality=90)
        fit(o, 160).save(os.path.join(PROPS, 'chest_%s_open.webp' % k), 'WEBP', quality=90)
    for name, i in SHOT_PIECES.items():
        fit(load('fx', 'projectiles', i), 160).save(os.path.join(SHOTS, name + '.webp'), 'WEBP', quality=90)
    meta = {'_note': 'Enemy kind -> painted shot (tools/asset-pipeline/navart/props.py), flying to the right.'}
    meta.update({k: 'res://assets/art/fx/shots/%s.webp' % v for k, v in KIND_SHOT.items()})
    with open(os.path.join(REPO, 'assets', 'art', 'fx', 'shots.json'), 'w') as f:
        json.dump(meta, f, indent=1)
    print('chests 3 x 2, shots', len(SHOT_PIECES))


if __name__ == '__main__':
    main()

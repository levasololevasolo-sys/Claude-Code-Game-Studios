"""Makes the gods' art from the keyed «Навь» sheets (assets/art/navart, made by
prepare.py):

    python3 tools/asset-pipeline/navart/gods.py

- assets/art/gods/portrait_<god>.webp  the framed portrait (gods_portraits_1-3),
  long side PORTRAIT px;
- assets/art/gods/boon_<rune>.webp     a rune's card picture (boons_<god>,
  BOON px): strike / dash / flare / passive take the sheet's pictures RUNE_PICK;
- assets/art/gods/door_<god>.webp      the god's door (doors_gods_1-2), and
  door_<type>.webp for the plain / loot / shop / lair doors;
- assets/art/gods/door_svarog_<n>.webp the forge door closed / ajar / open,
  sign_svarog.webp the round forge sign.
Read by GodGlyph (src/ui/god_glyph.gd) and Door (src/run/door.gd); a missing
file falls back to the old drawn look. The art's Лада is the game's Жива.
Deterministic.
"""
import os

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
SRC = os.path.join(REPO, 'assets', 'art', 'navart')
OUT = os.path.join(REPO, 'assets', 'art', 'gods')
PORTRAIT = 512
BOON = 256
DOOR = 360
QUALITY = 90

ART_GOD = {'lada': 'zhiva'}
# Portrait sheets: (sheet, gods left to right / in piece order, split by columns?)
PORTRAITS = [
    ('gods_portraits_1', ['perun', 'veles', 'stribog', 'lada', 'mokosh'], True),
    ('gods_portraits_2', ['svarog', 'kupala', 'dazhbog', 'khors', 'yarilo'], False),
    ('gods_portraits_3', ['chernobog', 'semargl', 'svyatovit'], True),
]
BOON_GODS = ['perun', 'veles', 'stribog', 'lada', 'mokosh', 'svarog', 'kupala', 'dazhbog', 'khors', 'yarilo',
             'chernobog', 'semargl', 'svyatovit']
# Rune slot -> picture of the 8 on a boons sheet (0 the god strikes, 2 the leap,
# 3 the burst of power, 4 the ward).
RUNE_PICK = {'s': 0, 'd': 2, 'f': 3, 'p': 4}
DOORS = [
    ('doors_gods_1', ['perun', 'veles', 'stribog', 'lada', 'mokosh', 'kupala', 'dazhbog']),
    ('doors_gods_2', ['khors', 'yarilo', 'chernobog', 'semargl', 'svyatovit', 'plain', 'loot', 'shop', 'lair']),
]


def load(group, sheet, i):
    p = os.path.join(SRC, group, sheet, '%02d.webp' % i)
    return Image.open(p).convert('RGBA')


def count(group, sheet):
    d = os.path.join(SRC, group, sheet)
    return len([f for f in os.listdir(d) if f.endswith('.webp')])


def fit(im, side):
    k = side / max(im.size)
    return im.resize((max(1, round(im.width * k)), max(1, round(im.height * k))), Image.LANCZOS)


def trim(im):
    box = im.getchannel('A').point(lambda v: 255 if v > 20 else 0).getbbox()
    return im.crop(box) if box else im


def save(im, name):
    os.makedirs(OUT, exist_ok=True)
    im.save(os.path.join(OUT, name), 'WEBP', quality=QUALITY, method=6)


def split_columns(im, n):
    """Cuts a row of n touching pieces at the n-1 most transparent columns
    near the even split points."""
    a = np.asarray(im.getchannel('A')).astype(np.float32)
    col = a.sum(axis=0)
    w = im.width
    cuts = [0]
    for k in range(1, n):
        c = w * k // n
        lo, hi = c - w // (3 * n), c + w // (3 * n)
        cuts.append(lo + int(np.argmin(col[lo:hi])))
    cuts.append(w)
    return [trim(im.crop((cuts[k], 0, cuts[k + 1], im.height))) for k in range(n)]


def god(name):
    return ART_GOD.get(name, name)


def main():
    n = 0
    for sheet, gods, split in PORTRAITS:
        if split:
            parts = split_columns(load('gods', sheet, 0), len(gods))
        else:
            parts = [trim(load('gods', sheet, i)) for i in range(len(gods))]
        for g, im in zip(gods, parts):
            save(fit(im, PORTRAIT), 'portrait_%s.webp' % god(g))
            n += 1
    for g in BOON_GODS:
        sheet = 'boons_' + g
        pics = [trim(load('boons', sheet, i)) for i in range(count('boons', sheet))]
        if g == 'svarog':
            for i, im in enumerate(pics):
                save(fit(im, BOON), 'boon_svarog_%d.webp' % i)
                n += 1
            continue
        for slot, i in RUNE_PICK.items():
            save(fit(pics[i], BOON), 'boon_%s_%s.webp' % (god(g), slot))
            n += 1
    for sheet, ids in DOORS:
        for i, d in enumerate(ids):
            save(fit(trim(load('doors', sheet, i)), DOOR), 'door_%s.webp' % god(d))
            n += 1
    for i in range(3):
        save(fit(trim(load('doors', 'door_svarog', i)), DOOR), 'door_svarog_%d.webp' % i)
        n += 1
    sv = load('icons', 'icon_svarog_door', count('icons', 'icon_svarog_door') - 1)
    save(fit(trim(sv), BOON), 'sign_svarog.webp')
    n += 1
    print('wrote %d gods files to %s' % (n, OUT))


if __name__ == '__main__':
    main()

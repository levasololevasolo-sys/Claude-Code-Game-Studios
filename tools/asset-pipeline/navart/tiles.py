"""Makes the ground and platform textures of every location from the keyed tile
sheets (assets/art/navart/tiles, made by prepare.py):

    python3 tools/asset-pipeline/navart/tiles.py

Per location, into assets/art/backgrounds/<loc>/:
- earth.webp  the solid ground body: the stone / soil part of the wide ground
              block, made seamless in x and y (wrap crossfade);
- top.webp    the lit top edge (grass, moss, snow with drips): the block's top
              band, seamless in x; TOP_PAD px of air above the surface line;
- plat.webp   a one-way platform: the plank / beam piece, its middle made
              seamless in x (LevelArt draws caps + a tiled middle);
and assets/art/backgrounds/tiles.json with each file's surface line and caps,
read by LevelArt (src/world/level_art.gd).
Deterministic.
"""
import json
import os

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
SRC = os.path.join(REPO, 'assets', 'art', 'navart', 'tiles')
OUT = os.path.join(REPO, 'assets', 'art', 'backgrounds')
QUALITY = 92

# ground: wide ground block piece; top: share of its height that is the lit
# edge band; plat: platform piece; edge: px trimmed off the piece's outline.
LOCS = {
    'swamp': {'sheet': 'tiles_swamp', 'ground': 0, 'top': 0.34, 'plat': 13},
    'forest': {'sheet': 'tiles_forest', 'ground': 1, 'top': 0.34, 'plat': 14},
    'frost': {'sheet': 'tiles_frost', 'ground': 0, 'top': 0.40, 'plat': 13},
    'hub': {'sheet': 'tiles_hub', 'ground': 0, 'top': 0.36, 'plat': 13},
}
EDGE = 10


def load(sheet, i):
    p = os.path.join(SRC, sheet, '%02d.webp' % i)
    return np.asarray(Image.open(p).convert('RGBA')).astype(np.float32) / 255.0


def save(a, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    Image.fromarray((np.clip(a, 0, 1) * 255 + 0.5).astype(np.uint8), 'RGBA').save(path, 'WEBP', quality=QUALITY,
                                                                                    method=6)


def smooth(n):
    t = np.linspace(0, 1, n)
    return t * t * (3 - 2 * t)


def wrap(a, axis, k=0.25):
    """Seamless along `axis`: the last k share crossfades into the first, then is cut."""
    n = a.shape[axis]
    o = max(int(n * k), 8)
    a = np.moveaxis(a, axis, 0)
    t = smooth(o).reshape((o,) + (1,) * (a.ndim - 1))
    out = a[:n - o].copy()
    out[:o] = a[n - o:] * (1 - t) + a[:o] * t
    return np.moveaxis(out, 0, axis)


def surface_row(a):
    """First row (from the top) where most columns are opaque: the surface line."""
    cover = (a[..., 3] > 0.5).mean(axis=1)
    rows = np.nonzero(cover > 0.85)[0]
    return int(rows[0]) if len(rows) else 0


def main():
    meta = {}
    for loc, s in LOCS.items():
        g = load(s['sheet'], s['ground'])
        h, w = g.shape[:2]
        g = g[:, EDGE:w - EDGE]
        cut = int(h * s['top'])
        body = g[cut + 6:h - EDGE]
        body[..., 3] = 1.0
        earth = wrap(wrap(body, 1), 0)
        save(earth, os.path.join(OUT, loc, 'earth.webp'))
        top = g[:cut + 24].copy()
        # fade the band's bottom into the earth below
        fade = smooth(24)[::-1]
        top[-24:, :, 3] *= fade[:, None]
        top = wrap(top, 1, 0.2)
        surf = surface_row(top)
        save(top, os.path.join(OUT, loc, 'top.webp'))
        p = load(s['sheet'], s['plat'])
        ph, pw = p.shape[:2]
        cap = int(pw * 0.18)
        mid = wrap(p[:, cap:pw - cap], 1, 0.3)
        plat = np.concatenate([p[:, :cap], mid, p[:, pw - cap:]], axis=1)
        save(plat, os.path.join(OUT, loc, 'plat.webp'))
        meta[loc] = {'earth': [int(earth.shape[1]), int(earth.shape[0])],
                     'top': [int(top.shape[1]), int(top.shape[0])], 'top_surface': surf,
                     'plat': [int(plat.shape[1]), int(plat.shape[0])], 'plat_cap': cap,
                     'plat_surface': surface_row(plat)}
        print(loc, meta[loc])
    json.dump(meta, open(os.path.join(OUT, 'tiles.json'), 'w'), indent=1)


if __name__ == '__main__':
    main()

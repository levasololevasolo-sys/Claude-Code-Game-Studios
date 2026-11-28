"""Turns the keyed «Навь» backgrounds (assets/art/navart/bg, made by prepare.py)
into the game's background layers:

    python3 tools/asset-pipeline/navart/layout.py

- surface layers per location (far / mid / near, 2-3 variants each) go to
  assets/art/backgrounds/<loc>/<layer>_<n>.webp with a feathered left edge
  (FEATHER px, alpha ramp), so variants laid with an overlap blend into each
  other in any order (visuals.json "tex_overlap");
- cave layers (cave_1far opaque, cave_2mid transparent) go to
  assets/art/backgrounds/<loc>/cave_far.webp / cave_mid.webp, made seamless in
  x by a wrap crossfade (the cave shader repeats them along the level);
- the far layer's top rows are kept opaque (sky), the near and mid layers keep
  their transparency.
Deterministic.
"""
import os

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
SRC = os.path.join(REPO, 'assets', 'art', 'navart', 'bg')
OUT = os.path.join(REPO, 'assets', 'art', 'backgrounds')
FEATHER = 160
WRAP = 220
QUALITY = 92

LOCS = {
    'swamp': {'far': ['bg_swamp_1far', 'bg_swamp_1far_b'], 'mid': ['bg_swamp_2mid', 'bg_swamp_2mid_b', 'bg_swamp_2mid_c'],
              'near': ['bg_swamp_3near', 'bg_swamp_3near_b', 'bg_swamp_3near_c'],
              'cave_far': 'bg_swamp_cave_1far', 'cave_mid': 'bg_swamp_cave_2mid'},
    'forest': {'far': ['bg_forest_1far', 'bg_forest_1far_b'], 'mid': ['bg_forest_2mid', 'bg_forest_2mid_b', 'bg_forest_2mid_c'],
               'near': ['bg_forest_3near', 'bg_forest_3near_b', 'bg_forest_3near_c'],
               'cave_far': 'bg_forest_cave_1far', 'cave_mid': 'bg_forest_cave_2mid'},
    'frost': {'far': ['bg_frost_1far', 'bg_frost_1far_b'], 'mid': ['bg_frost_2mid', 'bg_frost_2mid_b', 'bg_frost_2mid_c'],
              'near': ['bg_frost_3near', 'bg_frost_3near_b', 'bg_frost_3near_c'],
              'cave_far': 'bg_frost_cave_1far', 'cave_mid': 'bg_frost_cave_2mid'},
    'hub': {'far': ['bg_hub_1far', 'bg_hub_1far_b'], 'mid': ['bg_hub_2mid', 'bg_hub_2mid_b', 'bg_hub_2mid_c'],
            'near': ['bg_hub_3near', 'bg_hub_3near_b', 'bg_hub_3near_c'],
            'cave_far': 'bg_hub_cave_1far', 'cave_mid': 'bg_hub_cave_2mid'},
}


def load(name):
    return np.asarray(Image.open(os.path.join(SRC, name + '.webp')).convert('RGBA')).astype(np.float32) / 255.0


def save(a, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    Image.fromarray((np.clip(a, 0, 1) * 255 + 0.5).astype(np.uint8), 'RGBA').save(path, 'WEBP', quality=QUALITY,
                                                                                    method=6)


def feather_left(a):
    """Alpha ramp 0 -> 1 over the first FEATHER columns (smoothstep)."""
    t = np.clip(np.arange(a.shape[1]) / FEATHER, 0, 1)
    t = t * t * (3 - 2 * t)
    out = a.copy()
    out[..., 3] *= t[None, :]
    return out


def wrap_x(a):
    """Seamless in x: the last WRAP columns crossfade into the first ones, then
    are cut off (width shrinks by WRAP)."""
    w = a.shape[1]
    head = a[:, :WRAP]
    tail = a[:, w - WRAP:]
    t = np.linspace(0, 1, WRAP)[None, :, None]
    t = t * t * (3 - 2 * t)
    blend = tail * (1 - t) + head * t
    out = a[:, :w - WRAP].copy()
    out[:, :WRAP] = blend
    return out


def opaque(a):
    out = a.copy()
    out[..., 3] = 1.0
    return out


def main():
    n = 0
    for loc, spec in LOCS.items():
        for layer in ('far', 'mid', 'near'):
            for i, name in enumerate(spec[layer]):
                a = load(name)
                if layer == 'far':
                    a = opaque(a)
                save(feather_left(a), os.path.join(OUT, loc, '%s_%d.webp' % (layer, i + 1)))
                n += 1
        save(opaque(wrap_x(load(spec['cave_far']))), os.path.join(OUT, loc, 'cave_far.webp'))
        save(wrap_x(load(spec['cave_mid'])), os.path.join(OUT, loc, 'cave_mid.webp'))
        n += 2
    print('wrote %d background layers to %s' % (n, OUT))


if __name__ == '__main__':
    main()

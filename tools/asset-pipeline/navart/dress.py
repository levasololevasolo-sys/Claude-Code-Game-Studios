"""Set dressing for the levels from the approved «Навь» dress sheets:

    python3 tools/asset-pipeline/navart/dress.py

Copies every usable piece of the location's dress sheets (big enough, not a
long strip) to assets/art/dress/<loc>/<surface|cave>_NN.webp at most MAX px
and writes assets/art/dress/dress.json: {loc: {surface: [{file, w, h}],
cave: [...]}}. LevelDecor (src/world/level_decor.gd) stands them on room
floors. Deterministic.
"""
import json
import os

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
SRC = os.path.join(REPO, 'assets', 'art', 'navart', 'dress')
OUT = os.path.join(REPO, 'assets', 'art', 'dress')
MAX = 360
MIN_AREA = 9000
SHEETS = {
    'swamp': {'surface': ['dress_swamp_fishing', 'dress_swamp_offerings', 'dress_swamp_traveller_remains',
                          'dress_swamp_bog_flora'], 'cave': ['dress_swamp_cave_drowned']},
    'forest': {'surface': ['dress_forest_hunters', 'dress_forest_shrine', 'dress_forest_undergrowth'],
               'cave': ['dress_forest_cave_roots']},
    'frost': {'surface': ['dress_frost_frozen_story', 'dress_frost_terrain_clutter', 'dress_frost_slavic_landmarks'],
              'cave': ['dress_frost_cave_crypt']},
    'hub': {'surface': ['dress_hub_village_life', 'dress_hub_crafts', 'dress_hub_animals_npcspots',
                        'dress_hub_protective'], 'cave': ['dress_hub_cave_cellars']},
}


def main():
    meta = {}
    n = 0
    for loc, kinds in SHEETS.items():
        meta[loc] = {}
        d = os.path.join(OUT, loc)
        os.makedirs(d, exist_ok=True)
        for kind, sheets in kinds.items():
            rows = []
            for sh in sheets:
                for p in json.load(open(os.path.join(SRC, sh, 'sheet.json')))['pieces']:
                    if p['area'] < MIN_AREA or p['w'] > 3.2 * p['h'] or p['h'] > 3.5 * p['w']:
                        continue
                    im = Image.open(os.path.join(SRC, sh, '%02d.webp' % p['i'])).convert('RGBA')
                    im = im.crop(im.getchannel('A').point(lambda v: 255 if v > 30 else 0).getbbox())
                    k = min(1.0, MAX / max(im.size))
                    im = im.resize((round(im.width * k), round(im.height * k)), Image.LANCZOS)
                    name = '%s_%02d.webp' % (kind, len(rows))
                    im.save(os.path.join(d, name), 'WEBP', quality=90, method=6)
                    rows.append({'file': 'res://assets/art/dress/%s/%s' % (loc, name), 'w': im.width, 'h': im.height})
                    n += 1
            meta[loc][kind] = rows
    meta['_note'] = 'Set dressing (tools/asset-pipeline/navart/dress.py): per location, pieces for surface and cave rooms; w/h in px.'
    with open(os.path.join(OUT, 'dress.json'), 'w') as f:
        json.dump(meta, f, indent=1)
    print('dress pieces:', n)


if __name__ == '__main__':
    main()

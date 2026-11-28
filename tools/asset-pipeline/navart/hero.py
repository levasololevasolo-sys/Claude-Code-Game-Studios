"""The drawn hero from the approved «Навь» art: Ждан and his 7 skins as cut-out
puppets (cutout.py) on the hero2d skeleton and poses, written in the
hero_drawn format (tools/asset-pipeline/hero2d/build_sheets.py):

    python3 tools/asset-pipeline/navart/hero.py              # all looks -> assets/art/sprites/hero_drawn/
    python3 tools/asset-pipeline/navart/hero.py --preview DIR  # one contact sheet per look

Armour tiers 1-5 (HeroSprite "t%d") are LOOKS[1..5]; the other skins go to
t6.. for the wardrobe (SKIN_DIRS). Deterministic.
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(REPO, 'tools', 'asset-pipeline', 'hero2d'))
import cutout  # noqa: E402
import build_sheets  # noqa: E402
from poses import ANIMS  # noqa: E402


def whole(i, split=0.48, top=(0.5, 0.08), bot=(0.5, 0.97)):
    return {'piece': i, 'top': top, 'bot': bot, 'split': split}


def seg(up, lo, up_top=(0.5, 0.1), up_bot=(0.5, 0.9), lo_top=(0.5, 0.06), lo_bot=(0.5, 0.94)):
    return {'pieces': ((up, up_top, up_bot), (lo, lo_top, lo_bot))}


def hand(i, y=0.15):
    return {'piece': i, 'pivot': (0.5, y)}


def foot(i):
    return {'piece': i, 'pivot': (0.38, 0.25)}


LOOKS = {
    'zhdan': {
        'sheet': ('chars', 'char_hero_zhdan'), 'head': {'piece': 0, 'pivot': (0.55, 0.86)},
        'torso': {'piece': 1, 'neck': (0.45, 0.04), 'hip': (0.5, 0.5)},
        'armN': whole(2, top=(0.5, 0.1)), 'armF': whole(3, top=(0.5, 0.1)), 'handN': hand(6, 0.12), 'handF': hand(7, 0.12),
        'legN': whole(8, 0.45, (0.5, 0.05), (0.45, 0.82)), 'legF': whole(9, 0.45, (0.5, 0.05), (0.45, 0.82)),
        'cape': {'piece': 4, 'anchor': (0.55, 0.27), 'at': (0.1, -0.9), 'front': 0.3},
    },
    'peasant': {
        'sheet': ('skins', 'skin_1_peasant'), 'head': {'piece': 0, 'pivot': (0.55, 0.88)},
        'torso': {'piece': 2, 'neck': (0.5, 0.03), 'hip': (0.5, 0.7)},
        'armN': whole(4, 0.45, bot=(0.5, 0.8)), 'armF': whole(5, 0.45, bot=(0.5, 0.8)),
        'legN': seg(6, 8, lo_bot=(0.5, 0.95)), 'legF': seg(7, 9, lo_bot=(0.5, 0.95)),
        'footN': foot(10), 'footF': foot(11),
    },
    'hunter': {
        'sheet': ('skins', 'skin_2_hunter'), 'head': {'piece': 0, 'pivot': (0.55, 0.9)},
        'torso': {'piece': 6, 'neck': (0.5, 0.03), 'hip': (0.5, 0.8)},
        'armN': seg(1, 7, lo_bot=(0.5, 0.72)), 'armF': seg(2, 8, lo_bot=(0.5, 0.72)),
        'legN': seg(11, 15, lo_bot=(0.45, 0.82)), 'legF': seg(12, 16, lo_bot=(0.45, 0.82)),
        'cape': {'piece': 3, 'anchor': (0.55, 0.45), 'at': (-0.1, 0.35)},
    },
    'druzhinnik': {
        'sheet': ('skins', 'skin_3_druzhinnik'), 'scale': 1.1, 'head': {'piece': 0, 'pivot': (0.55, 0.9)},
        'torso': {'piece': 3, 'neck': (0.5, 0.03), 'hip': (0.5, 0.75)},
        'armN': whole(2, bot=(0.5, 0.82)), 'armF': whole(4, bot=(0.5, 0.82)),
        'legN': seg(6, 8, lo_bot=(0.45, 0.82)), 'legF': seg(7, 9, lo_bot=(0.45, 0.82)),
    },
    'bogatyr': {
        'sheet': ('skins', 'skin_4_bogatyr'), 'head': {'piece': 0, 'pivot': (0.6, 0.9)},
        'torso': {'piece': 4, 'neck': (0.5, 0.03), 'hip': (0.5, 0.72)},
        'armN': seg(1, 5), 'armF': seg(2, 6), 'handN': hand(8), 'handF': hand(9),
        'legN': whole(12, 0.45, (0.5, 0.05), (0.45, 0.85)), 'legF': whole(13, 0.45, (0.5, 0.05), (0.45, 0.85)),
        'cape': {'piece': 7, 'anchor': (0.45, 0.04), 'at': (-0.15, 0.2)},
    },
    'volkhv': {
        'sheet': ('skins', 'skin_5_volkhv'), 'head': {'piece': 0, 'pivot': (0.55, 0.9)},
        'torso': {'piece': 6, 'neck': (0.5, 0.03), 'hip': (0.5, 0.62)},
        'armN': seg(1, 3), 'armF': seg(2, 4), 'handN': hand(7), 'handF': hand(8),
        'legN': seg(10, 13), 'legF': seg(11, 14), 'footN': foot(15), 'footF': foot(16),
        'cape': {'piece': 12, 'anchor': (0.5, 0.04), 'at': (-0.15, 0.2)},
    },
    'morena': {
        'sheet': ('skins', 'skin_6_morena'), 'head': {'piece': 0, 'pivot': (0.55, 0.9)},
        'torso': {'piece': 2, 'neck': (0.5, 0.03), 'hip': (0.5, 0.85)},
        'armN': seg(1, 5, lo_bot=(0.5, 0.72)), 'armF': seg(3, 6, lo_bot=(0.5, 0.72)),
        'legN': whole(8, 0.45, (0.5, 0.05), (0.45, 0.85)), 'legF': whole(9, 0.45, (0.5, 0.05), (0.45, 0.85)),
        'cape': {'piece': 7, 'anchor': (0.45, 0.04), 'at': (-0.15, 0.2)},
    },
    'navi': {
        'sheet': ('skins', 'skin_7_navi'), 'head': {'piece': 0, 'pivot': (0.55, 0.9)},
        'torso': {'piece': 2, 'neck': (0.5, 0.03), 'hip': (0.5, 0.82)},
        'armN': seg(1, 6, lo_bot=(0.5, 0.72)), 'armF': seg(3, 7, lo_bot=(0.5, 0.72)),
        'legN': whole(8, 0.45, (0.5, 0.05), (0.45, 0.85)), 'legF': seg(9, 10, lo_bot=(0.45, 0.85)),
        'cape': {'piece': 4, 'anchor': (0.3, 0.06), 'at': (-0.15, 0.2)},
    },
}
# armour tier -> look (1 Павший .. 5 Богатырь); the rest are wardrobe skins
TIER_LOOK = {1: 'zhdan', 2: 'hunter', 3: 'druzhinnik', 4: 'bogatyr', 5: 'morena', 6: 'peasant', 7: 'volkhv', 8: 'navi'}
_chars = {}


def char(tier):
    name = TIER_LOOK[tier]
    if name not in _chars:
        _chars[name] = cutout.Char(LOOKS[name])
    return _chars[name]


def render(tier, pose, seed=11):
    return cutout.render(char(tier), pose)


build_sheets.render = render
build_sheets.to_px = cutout.to_px


def main():
    args = sys.argv[1:]
    out = build_sheets.OUT
    if args and args[0] == '--preview':
        d = args[1]
        anims = args[2:] or ['idle', 'run', 'strike_1', 'jump', 'death']
        os.makedirs(d, exist_ok=True)
        tiers = tuple(TIER_LOOK)
        meta, res = build_sheets.build(tiers, anims, os.path.join(d, 'sheets'))
        for t in tiers:
            build_sheets.contact(res, t, anims, os.path.join(d, 'look_%d_%s.png' % (t, TIER_LOOK[t])))
        print(json.dumps({k: v for k, v in meta.items() if k != 'anims'}))
        return
    meta, res = build_sheets.build(build_sheets.TIERS, list(ANIMS), out)
    with open(os.path.join(out, 'hero_drawn_sheets.json'), 'w') as f:
        json.dump(meta, f, indent=1)
    build_sheets.build((6, 7, 8), list(ANIMS), out)
    ev = os.path.join(REPO, 'production', 'qa', 'evidence')
    build_sheets.contact(res, 1, list(ANIMS), os.path.join(ev, 'hero-drawn-anims.png'))
    build_sheets.contact(res, 5, list(ANIMS), os.path.join(ev, 'hero-drawn-anims-t5.png'))
    print(json.dumps({k: v for k, v in meta.items() if k != 'anims'}))


if __name__ == '__main__':
    main()

"""Joint animation for the two-legged enemies and bosses: their cut parts on the
hero skeleton (cutout.py) moved by the hero's poses (hero2d/poses.py), picked
per enemy animation by ANIM. enemies.py uses it for the kinds in RIGS; the
others (beasts, flyers, blobs) stay whole-body puppets. A severed arm or head
is simply left out of the frame. Deterministic.
"""
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, '..', 'hero2d'))
import cutout  # noqa: E402
import importlib.util  # noqa: E402
_spec = importlib.util.spec_from_file_location('navart_hero', os.path.join(HERE, 'hero.py'))
_hero = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_hero)
foot, hand, seg, whole = _hero.foot, _hero.hand, _hero.seg, _hero.whole
from poses import ANIMS  # noqa: E402


def S(sheet):
    return ('chars', sheet)


RIGS = {
    'balvan': {
        'sheet': S('char_en_swamp_balvan'), 'head': {'piece': 0, 'pivot': (0.55, 0.85)},
        'torso': {'piece': 3, 'neck': (0.5, 0.03), 'hip': (0.5, 0.8)},
        'armN': seg(2, 6, lo_bot=(0.5, 0.62)), 'armF': seg(4, 7, lo_bot=(0.5, 0.62)),
        'legN': seg(8, 11, lo_bot=(0.45, 0.72)), 'legF': seg(9, 12, lo_bot=(0.45, 0.72)),
        'cape': {'piece': 1, 'anchor': (0.5, 0.08), 'at': (-0.1, -0.3)},
        'heldN': {'piece': 10, 'pivot': (0.3, 0.85), 'turn': np.pi, 'scale': 0.65},
    },
    'thrower': {
        'sheet': S('char_en_swamp_upyr_thrower'), 'head': {'piece': 0, 'pivot': (0.5, 0.9)},
        'torso': {'piece': 5, 'neck': (0.5, 0.03), 'hip': (0.5, 0.62)},
        'armN': seg(1, 6), 'armF': seg(2, 7), 'handN': hand(8),
        'legN': whole(9, 0.47, (0.5, 0.05), (0.5, 0.88)), 'legF': whole(11, 0.47, (0.5, 0.05), (0.5, 0.88)),
    },
    'vodyanitsa': {
        'sheet': S('char_en_swamp_vodyanitsa'), 'head': {'piece': 0, 'pivot': (0.5, 0.45)},
        'torso': {'piece': 4, 'neck': (0.5, 0.03), 'hip': (0.5, 0.5)},
        'armN': seg(2, 5), 'armF': seg(3, 6),
        'legN': seg(8, 10), 'legF': seg(9, 11),
        'cape': {'piece': 1, 'anchor': (0.5, 0.08), 'at': (-0.15, -0.3)},
    },
    'shishiga': {
        'sheet': S('char_en_swamp_shishiga'), 'head': {'piece': 0, 'pivot': (0.5, 0.85)},
        'torso': {'piece': 2, 'neck': (0.5, 0.05), 'hip': (0.5, 0.75)},
        'armN': whole(3), 'armF': whole(4),
        'legN': whole(5, 0.5, (0.5, 0.05), (0.5, 0.9)), 'legF': whole(6, 0.5, (0.5, 0.05), (0.5, 0.9)),
    },
    'ringer': {
        'sheet': S('char_en_forest_auka'), 'head': {'piece': 0, 'pivot': (0.5, 0.85)},
        'torso': {'piece': 3, 'neck': (0.5, 0.03), 'hip': (0.5, 0.8)},
        'armN': whole(2), 'armF': whole(4),
        'legN': whole(5, 0.48, (0.5, 0.05), (0.5, 0.88)), 'legF': whole(6, 0.48, (0.5, 0.05), (0.5, 0.88)),
    },
    'rootling': {
        'sheet': S('char_en_forest_leshachonok'), 'head': {'piece': 0, 'pivot': (0.5, 0.92)},
        'torso': {'piece': 4, 'neck': (0.5, 0.05), 'hip': (0.5, 0.8)},
        'armN': whole(2), 'armF': whole(2),
        'legN': seg(6, 8), 'legF': seg(7, 9), 'footN': foot(10), 'footF': foot(11),
    },
    'sentry': {
        'sheet': S('char_en_forest_upyr_shield'), 'head': {'piece': 0, 'pivot': (0.5, 0.9)},
        'torso': {'piece': 4, 'neck': (0.5, 0.03), 'hip': (0.5, 0.75)},
        'armN': whole(2, bot=(0.5, 0.95)), 'armF': whole(1, bot=(0.5, 0.95)), 'handN': hand(5), 'handF': hand(6),
        'legN': whole(8, 0.48, (0.5, 0.05), (0.5, 0.86)), 'legF': whole(9, 0.48, (0.5, 0.05), (0.5, 0.86)),
        'heldF': {'piece': 7, 'pivot': (0.5, 0.45), 'fixed': 0.0, 'scale': 0.8},
    },
    'suchkovik': {
        'sheet': S('char_en_forest_suchkovik'), 'head': {'piece': 0, 'pivot': (0.5, 0.9)},
        'torso': {'piece': 3, 'neck': (0.5, 0.03), 'hip': (0.5, 0.8)},
        'armN': seg(1, 4), 'armF': seg(2, 5), 'handN': hand(7), 'handF': hand(8),
        'legN': seg(9, 11), 'legF': seg(10, 12), 'footN': foot(14), 'footF': foot(15),
    },
    'snezhnitsa': {
        'sheet': S('char_en_frost_snezhnitsa'), 'head': {'piece': 0, 'pivot': (0.5, 0.9)},
        'torso': {'piece': 3, 'neck': (0.5, 0.03), 'hip': (0.5, 0.45)},
        'armN': seg(4, 6), 'armF': seg(5, 7),
        'legN': whole(9, 0.5, (0.5, 0.05), (0.5, 0.95)), 'legF': whole(10, 0.5, (0.5, 0.05), (0.5, 0.95)),
        'footN': foot(12), 'footF': foot(13),
    },
    'mara': {
        'sheet': S('char_en_frost_mara'), 'head': {'piece': 0, 'pivot': (0.5, 0.9)},
        'torso': {'piece': 3, 'neck': (0.5, 0.03), 'hip': (0.5, 0.7)},
        'armN': seg(1, 5, lo_bot=(0.5, 0.8)), 'armF': seg(2, 6, lo_bot=(0.5, 0.8)),
        'legN': seg(9, 11), 'legF': seg(10, 12), 'footN': foot(15), 'footF': foot(16),
        'cape': {'piece': 7, 'anchor': (0.5, 0.05), 'at': (-0.1, 0.1)},
    },
    'kikimora': {
        'sheet': S('char_boss_kikimora'), 'head': {'piece': 0, 'pivot': (0.5, 0.88)},
        'torso': {'piece': 4, 'neck': (0.5, 0.04), 'hip': (0.5, 0.55)},
        'armN': whole(5, bot=(0.5, 0.95)), 'armF': whole(7, bot=(0.5, 0.95)),
        'legN': whole(8, 0.48, (0.5, 0.05), (0.5, 0.88)), 'legF': whole(9, 0.48, (0.5, 0.05), (0.5, 0.88)),
        'cape': {'piece': 1, 'anchor': (0.5, 0.2), 'at': (-0.1, -0.7)},
        'heldN': {'piece': 2, 'pivot': (0.5, 0.5)},
    },
    'likho': {
        'sheet': S('char_boss_likho'), 'head': {'piece': 0, 'pivot': (0.55, 0.6)},
        'torso': {'piece': 3, 'neck': (0.3, 0.32), 'hip': (0.55, 0.85)},
        'armN': whole(4, bot=(0.5, 0.95)), 'armF': whole(5, bot=(0.5, 0.95)),
        'legN': seg(7, 9, up_bot=(0.5, 0.7), lo_bot=(0.5, 0.9)), 'legF': seg(8, 10, up_bot=(0.5, 0.7), lo_bot=(0.5, 0.9)),
        'heldN': {'piece': 6, 'pivot': (0.5, 0.8), 'turn': np.pi},
    },
    'morena': {
        'sheet': S('char_boss_morena'), 'head': {'piece': 0, 'pivot': (0.5, 0.35)},
        'torso': {'piece': 1, 'neck': (0.5, 0.03), 'hip': (0.5, 0.55)},
        'armN': seg(2, 5), 'armF': seg(3, 6),
        'legN': seg(7, 12), 'legF': seg(8, 13),
        'heldN': {'piece': 16, 'pivot': (0.5, 0.7)},
    },
}

WIND = ('windup', 'aim', 'inflate', 'call', 'whistle', 'song', 'shake', 'summon', 'block', 'poke_wind', 'roar',
        'stuck')
STRIKE = ('attack', 'throw', 'lunge', 'charge', 'poke', 'spit', 'slam', 'leap', 'gaze', 'woe', 'wave', 'pend',
          'breath', 'spears', 'scythe', 'cling')


def pose_for(anim, i, n):
    """(hero pose dict, also_whole_motion) for frame i of n of an enemy anim."""
    base = anim.split('_sever')[0]
    w = base[:-2] if base.endswith('_w') else base

    def pick(a, k0=0.0, k1=1.0):
        ps = ANIMS[a][0]
        t = i / max(n - 1, 1) if not ANIMS[a][2] else i / max(n, 1)
        j = int(round((k0 + (k1 - k0) * t) * (len(ps) - 1)))
        return ps[min(max(j, 0), len(ps) - 1)]
    if base.endswith('_w') or w in WIND:
        return pick('strike_3', 0.0, 0.3), False
    if w in STRIKE:
        return pick('strike_3', 0.3, 1.0), False
    if w in ('move', 'flee', 'hop'):
        return pick('run'), False
    if w == 'hurt':
        return pick('hurt'), False
    if w == 'death':
        return pick('death'), False
    if w in ('land', 'slam_end'):
        return pick('strike_down', 0.6, 1.0), False
    return pick('idle'), True


class Rig:
    def __init__(self, name):
        self.char = cutout.Char(RIGS[name])
        im, _, _ = cutout.render(self.char, ANIMS['idle'][0][0])
        b = im.getchannel('A').point(lambda v: 255 if v > 100 else 0).getbbox()
        self.origin = cutout.to_px((0.0, 0.0))
        self.height = self.origin[1] - b[1]

    def frame(self, anim, i, n, cell, origin, target_h, skip=()):
        pose, whole_motion = pose_for(anim, i, n)
        im, _, _ = cutout.render(self.char, pose, skip)
        k = target_h / self.height
        im = im.resize((max(1, round(im.width * k)), max(1, round(im.height * k))), Image.LANCZOS)
        out = Image.new('RGBA', tuple(cell), (0, 0, 0, 0))
        out.paste(im, (int(round(origin[0] - self.origin[0] * k)), int(round(origin[1] - self.origin[1] * k))), im)
        return out, whole_motion


def strip_alpha(im, alpha):
    a = np.asarray(im).astype(np.float32)
    a[..., 3] *= alpha
    return Image.fromarray(a.astype(np.uint8), 'RGBA')

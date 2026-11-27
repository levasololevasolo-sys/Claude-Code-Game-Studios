"""Drawn weapon bodies of the hero (assets/data/weapon_bodies.json) + the starting club «дрын».

Each sprite lies along +x from the grip (the hero's fist, hand_point()) and is
drawn at the hero's 2x density. weapons_drawn.json records per sprite the grip
px, the tip px (forward length) and the back px (the staff's rear half), so
player.gd scales it to its reach-based length.
"""
import numpy as np

from base import hexc, INK, RUST, rot  # noqa: F401
from sdf2d import Canvas

S, DOWN = 100, 2   # hero density: 50 sheet px per unit
STEEL = hexc('B8C4CC')
STEEL_D = hexc('8E9AA3')
WOOD = hexc('8C6A44')
WOOD_D = hexc('6B4A2B')
LEATHER = hexc('5B3A24')
BRONZE = hexc('B07A3A')
GOLD = hexc('C8902E')
RED = hexc('B3262E')

# name: (x0, x1, y0, y1 in units, tip x, back x)
BOX = {
    'stick': (-0.5, 2.8, -0.5, 0.5, 2.6, -0.3),
    'blade': (-0.6, 3.2, -0.55, 0.55, 3.05, -0.45),
    'spear': (-1.3, 4.6, -0.45, 0.45, 4.45, -1.1),
    'hammer': (-0.5, 3.6, -0.9, 0.9, 3.4, -0.35),
    'staff': (-2.0, 3.6, -0.4, 0.4, 3.45, -1.85),
    'sickles': (-0.4, 2.4, -1.4, 0.5, 1.9, -0.25),
}


def grip(cv, a, b):
    wrap = 1 - 0.35 * np.clip(np.sin((cv.X - cv.Y * 0.4) * 55), 0, 1)
    cv.paint(cv.seg(a, b, 0.085), LEATHER, R=0.08, pattern=wrap, line=0.8)


def draw(name):
    x0, x1, y0, y1, _, _ = BOX[name]
    cv = Canvas(x0, x1, y0, y1, S, seed=5)
    grain = 1 - 0.2 * np.clip(np.sin(cv.Y * 70 + cv.n_mid * 10), 0, 1)
    if name == 'stick':
        d = cv.path([(-0.3, 0.02), (0.8, -0.02), (1.7, 0.03), (2.6, -0.02)], 0.1, 0.16)
        for x, s in ((0.9, -1), (1.8, 1)):
            d = cv.smin(d, cv.cone((x, 0.0), (x + 0.22, 0.2 * s), 0.06, 0.03), 0.03)
        cv.paint(d, WOOD, R=0.12, pattern=grain)
        cv.paint(cv.ellipse((2.6, -0.02), 0.07, 0.13), WOOD * 1.25, R=0.04, line=0.6, cast=False)
        cv.ink(cv.path([(0.4, 0.02), (1.1, 0.0), (1.4, 0.04)], 0.012), alpha=0.5)
    elif name == 'blade':
        bl = cv.poly([(0.32, -0.12), (2.6, -0.1), (3.05, 0.0), (2.6, 0.1), (0.32, 0.12)], 0.01)
        cv.paint(bl, STEEL, R=0.1, hl=1.4)
        cv.ink(cv.seg((0.4, 0.0), (2.5, 0.0), 0.012), alpha=0.55)  # fuller
        cv.paint(cv.cone((0.25, -0.38), (0.25, 0.38), 0.07, 0.07), BRONZE, R=0.06, hl=1.3)
        grip(cv, (-0.28, 0.0), (0.22, 0.0))
        cv.paint(cv.circle((-0.4, 0.0), 0.1), BRONZE, R=0.07, hl=1.3)
    elif name == 'spear':
        cv.paint(cv.seg((-1.1, 0.0), (3.6, 0.0), 0.07), WOOD, R=0.07, pattern=grain)
        head = cv.poly([(3.5, -0.09), (3.75, -0.24), (4.45, 0.0), (3.75, 0.24), (3.5, 0.09)], 0.01)
        cv.paint(head, STEEL, R=0.08, hl=1.4)
        cv.ink(cv.seg((3.62, 0.0), (4.3, 0.0), 0.01), alpha=0.5)
        cv.paint(cv.cone((3.35, 0.0), (3.55, 0.0), 0.11, 0.09), STEEL_D, R=0.05)
        cv.paint(cv.cone((3.2, 0.0), (3.32, 0.0), 0.1, 0.1), RED, R=0.04, line=0.6)  # a red binding
        for x in (-0.15, 0.15):
            cv.ink(cv.seg((x, -0.08), (x + 0.04, 0.08), 0.014), alpha=0.6)
    elif name == 'hammer':
        cv.paint(cv.seg((-0.35, 0.0), (3.0, 0.0), 0.075), WOOD_D, R=0.07, pattern=grain)
        grip(cv, (-0.3, 0.0), (0.35, 0.0))
        hd = cv.smin(cv.circle((3.05, 0.0), 0.42), cv.cone((2.6, 0.0), (3.3, 0.0), 0.16, 0.2), 0.08)
        cv.paint(hd, STEEL_D, R=0.35, hl=1.3)
        for a in np.linspace(0, 2 * np.pi, 7)[:-1]:  # flanges of a bulava
            q = np.array([3.05, 0.0]) + np.array([np.cos(a), np.sin(a)]) * 0.42
            cv.paint(cv.cone((3.05, 0.0) + (q - (3.05, 0.0)) * 0.6, q + (q - (3.05, 0.0)) * 0.35, 0.1, 0.04), STEEL,
                     R=0.06, hl=1.4, line=0.7, cast=False)
        cv.paint(cv.cone((2.45, 0.0), (2.62, 0.0), 0.11, 0.11), BRONZE, R=0.05, hl=1.3)
    elif name == 'staff':
        cv.paint(cv.seg((-1.75, 0.0), (3.35, 0.0), 0.08), WOOD, R=0.08, pattern=grain)
        for x in (-1.8, 3.4):
            cv.paint(cv.cone((x - 0.12 * np.sign(x), 0.0), (x, 0.0), 0.11, 0.1), BRONZE, R=0.06, hl=1.3)
        for x in (-0.3, 0.3, 1.6):
            cv.paint(cv.cone((x, 0.0), (x + 0.1, 0.0), 0.095, 0.095), RED, R=0.04, line=0.6, cast=False)
    elif name == 'sickles':
        grip(cv, (-0.25, 0.0), (0.45, 0.0))
        c = np.array([1.2, -0.3])
        ang = np.arctan2(cv.Y - c[1], cv.X - c[0])
        r = np.hypot(cv.X - c[0], cv.Y - c[1])
        u = np.mod(ang - 2.75, 2 * np.pi)
        span = 3.9
        thick = 0.03 + 0.11 * np.sin(np.pi * np.clip(u / span, 0, 1) * 0.85 + 0.25)
        arc = np.abs(r - 0.7) - thick
        arc = np.maximum(arc, u - span)
        cv.paint(arc, STEEL, R=0.08, hl=1.4)
        cv.paint(cv.cone((0.45, 0.0), (0.6, -0.02), 0.08, 0.08), BRONZE, R=0.04)
    cv.outer_outline(1.0)
    return cv.image(DOWN)


def meta(name):
    x0, x1, y0, y1, tip, back = BOX[name]
    k = S / DOWN
    return {'grip': [round(-x0 * k, 1), round(-y0 * k, 1)], 'tip_px': round(tip * k, 1), 'back_px': round(-back * k, 1)}

"""Animation poses for the drawn hero (rig.py). One function per animation,
returning a list of pose dicts; names match what HeroSprite /
HeroVisual.choose() ask for (src/player/hero_sprite.gd)."""
import numpy as np
from rig import SH_N, rot

TAU = 2 * np.pi


def ease(k):
    return 1 - (1 - k) ** 3


def shoulder_n(hip, lean):
    return np.asarray(hip) + rot(np.array(SH_N), lean)


def blade_hand(hip, lean, a, r=1.15):
    """Fist on the blade arc: Player._blade_angle() a (0 = forward, + = down).
    Above the shoulder the fist goes higher and further back, so the arm
    passes behind/over the head instead of across the face."""
    up = max(0.0, -np.sin(a))
    v = r * np.array([np.cos(a), np.sin(a)]) + np.array([0.0, -0.15 * up])
    return tuple(shoulder_n(hip, lean) + v)


def idle(n=12):
    out = []
    for i in range(n):
        ph = TAU * i / n
        s, c = np.sin(ph), np.cos(ph)
        out.append(dict(hip=(0.01 * s, -1.70 + 0.012 * c), lean=0.06 + 0.018 * s, breath=0.5 + 0.5 * s,
                        tilt=-0.03 * s, hN=(-0.02 + 0.01 * s, -1.74 - 0.035 * s), hF=(0.92 + 0.015 * s, -1.86 - 0.03 * s),
                        drag=(0.03 * c, 0.0)))
    return out


def run(n=8):
    out = []
    for i in range(n):
        p = TAU * i / n

        def foot(q):
            x = 0.15 + 0.78 * np.cos(q)
            lift = 0.55 * max(0.0, -np.sin(q)) ** 0.9
            return (x, -0.11 - lift), (0.5 * max(0.0, -np.sin(q)) - 0.1 * max(0.0, np.sin(q)))
        fN, pN = foot(p)
        fF, pF = foot(p + np.pi)
        hip = (0.12, -1.60 - 0.07 * abs(np.sin(p)))
        out.append(dict(hip=hip, lean=0.26, fN=fN, pN=pN, fF=fF, pF=pF, tilt=-0.12,
                        hN=(0.2 - 0.32 * np.cos(p), -1.95 + 0.06 * np.sin(p)), eN=(-0.7, 0.6),
                        hF=(0.75 + 0.55 * np.cos(p), -2.15 - 0.25 * np.cos(p)), eF=(-0.9, 0.3),
                        drag=(-0.7, -0.2 + 0.08 * np.sin(2 * p))))
    return out


def jump(n=4):
    out = []
    for i in range(n):
        k = i / (n - 1)
        out.append(dict(hip=(0.0, -1.85), lean=0.12 - 0.08 * k, tilt=-0.15, fN=(-0.45 - 0.1 * k, -0.45 - 0.2 * k), pN=0.6,
                        fF=(0.55, -0.6 - 0.25 * k), pF=0.3, hN=(0.25, -2.3 - 0.15 * k), hF=(1.0, -2.9 - 0.2 * k), eF=(0.2, 1.0),
                        drag=(-0.15, 0.35 + 0.15 * k)))
    return out


def fall(n=4):
    out = []
    for i in range(n):
        w = np.sin(TAU * i / n)
        out.append(dict(hip=(0.0, -1.78), lean=0.02, tilt=-0.1, fN=(-0.4, -0.08), pN=0.45, fF=(0.42, -0.3), pF=0.3,
                        hN=(-0.15, -2.55 + 0.05 * w), eN=(-1, 0.2), hF=(1.15, -3.15 + 0.06 * w), eF=(0.3, 1.0), handF='open',
                        drag=(-0.1 + 0.06 * w, -0.7 - 0.1 * w)))
    return out


def roll(n=8):
    out = []
    for i in range(n):
        k = (i + 0.5) / n
        out.append(dict(hip=(0.0, -1.15), lean=1.05, tilt=0.35, fN=(0.35, -0.2), pN=0.3, fF=(0.75, -0.35), pF=0.2,
                        hN=(0.85, -1.25), eN=(-0.3, 1.0), hF=(1.05, -1.55), eF=(-0.3, 1.0), face='shout',
                        drag=(-0.4, -0.6), rot=-360.0 * k, pivot=(0.35, -1.35), rest=True))
    return out


def dash(n=4):
    out = []
    for i in range(n):
        k = i / (n - 1)
        out.append(dict(hip=(0.25, -1.5), lean=0.55, tilt=-0.35, fN=(-1.0 - 0.1 * k, -0.25), pN=0.6, fF=(0.95, -0.12), pF=-0.1,
                        hN=(0.95, -2.05), eN=(-0.5, 0.9), hF=(-0.7, -2.0 + 0.1 * k), eF=(0.3, 1.0), handF='open',
                        drag=(-1.2, -0.45), face='shout'))
    return out


def strike(a0, a1, n=6, heavy=False):
    out = []
    for i in range(n):
        k = i / (n - 1)
        ke = ease(k)
        lean = -0.12 + (0.38 if heavy else 0.3) * ke
        hip = (0.25 * ke, -1.66 + (0.06 if heavy else 0.0) * np.sin(np.pi * k))
        a = a0 + (a1 - a0) * ke
        out.append(dict(hip=hip, lean=lean, fN=(-0.55, -0.11), fF=(0.55 + 0.35 * ke, -0.11), tilt=-0.05,
                        hN=blade_hand(hip, lean, a), eN=(-0.6, 0.8), hF=(0.95 - 1.1 * ke, -2.3 + 0.2 * ke), eF=(0.2, 1.0),
                        handF='open' if ke < 0.5 else 'fist', drag=(0.35 - 0.8 * ke, -0.1), face='shout'))
    return out


def strike_up(n=6):
    out = []
    for i in range(n):
        k = i / (n - 1); ke = ease(k)
        lean = 0.15 - 0.3 * ke
        hip = (0.05, -1.68 - 0.06 * ke)
        a = 0.4 + (-2.6 - 0.4) * ke
        out.append(dict(hip=hip, lean=lean, tilt=-0.35 * ke, fN=(-0.45, -0.11), fF=(0.5, -0.11 - 0.05 * ke),
                        hN=blade_hand(hip, lean, a), eN=(-0.3, 1.0), hF=(0.85, -2.0 - 0.3 * ke), eF=(0.0, 1.0),
                        drag=(-0.2, 0.2 * ke), face='shout'))
    return out


def strike_down(n=4):
    out = []
    for i in range(n):
        k = i / (n - 1); ke = ease(k)
        lean = 0.15 + 0.3 * ke
        hip = (0.0, -1.85)
        a = -0.6 + 3.0 * ke
        out.append(dict(hip=hip, lean=lean, tilt=0.25 * ke, fN=(-0.5, -0.5), pN=0.6, fF=(0.45, -0.7), pF=0.4,
                        hN=blade_hand(hip, lean, a), eN=(-0.6, 0.8), hF=(0.9, -2.9 + 0.4 * ke), eF=(0.2, 1.0), handF='open',
                        drag=(-0.1, -0.6), face='shout'))
    return out


def hurt(n=3):
    out = []
    for i in range(n):
        k = [0.6, 1.0, 0.7][i]
        out.append(dict(hip=(-0.15 * k, -1.68), lean=-0.3 * k, tilt=-0.25 * k, fN=(-0.55, -0.11), fF=(0.6, -0.11 - 0.2 * k), pF=0.3,
                        hN=(-0.25, -1.95 - 0.2 * k), eN=(-1.0, 0.4), hF=(1.0, -2.9 * k - 1.9 * (1 - k)), eF=(0.3, 1.0), handF='open',
                        drag=(0.45 * k, -0.1), face='pain'))
    return out


def death(n=10):
    out = []
    angs = [0, 0, 0, 0, 0, -8, -24, -50, -84, -80]
    for i in range(n):
        k = min(i / 4.0, 1.0)
        hipy = -1.62 + (1.62 - 0.98) * ease(k)
        out.append(dict(hip=(0.0, hipy), lean=0.1 + 0.4 * k, tilt=0.4 * k, fN=(-0.75 * k - 0.4 * (1 - k), -0.11), pN=0.9 * k,
                        fF=(0.55, -0.11), hN=(0.25 + 0.1 * k, hipy - 0.2 + 0.25 * k), eN=(-0.6, 0.8),
                        hF=(0.7 + 0.1 * k, hipy - 0.1 + 0.15 * k), eF=(-0.4, 0.9), handF='open',
                        drag=(0.0, -0.1 * k), face='pain', thread=min(1.0, max(0.0, (i - 3) / 3.0)),
                        rot=float(angs[i]), pivot=(-0.75, -0.05), rest=i >= 5))
    return out


def flare(n=8):
    out = []
    for i in range(n):
        k = i / (n - 1)
        g = k < 0.5
        kk = k / 0.5 if g else (k - 0.5) / 0.5
        if g:
            hip = (0.0, -1.70 + 0.12 * kk); lean = 0.06 + 0.25 * kk
            hN = (0.15 + 0.15 * kk, -2.35); hF = (0.75 - 0.1 * kk, -2.4)
            glow = 1.0 + 0.6 * kk; face = 'calm'; hand = 'fist'
        else:
            e = ease(kk)
            hip = (0.0, -1.58 - 0.16 * e); lean = 0.31 - 0.5 * e
            hN = (0.3 - 1.25 * e, -2.35 - 0.9 * e); hF = (0.65 + 0.7 * e, -2.4 - 0.9 * e)
            glow = 1.6 + 1.6 * e; face = 'shout'; hand = 'open'
        out.append(dict(hip=hip, lean=lean, tilt=-0.2 * (0 if g else kk), hN=hN, eN=(-0.3, 1.0), hF=hF, eF=(0.3, 1.0), handF=hand,
                        glow=glow, face=face, drag=(0.0, -0.2 if not g else 0.0), fN=(-0.5, -0.11), fF=(0.6, -0.11)))
    return out


# Parry guard per strike body (assets/data/weapon_bodies.json; the start stick
# is a blade body). Per frame: (hand angle from the near shoulder, reach,
# Player._blade_angle() in that frame, far-hand grip distance along the weapon
# in units or None = free hand). Frames 0-2 raise and hold the guard, 3 is the
# recoil after a caught blow, 4 the dropped guard after a whiff.
# PARRY_BLADE in player.gd must hold the same blade angles (guard, hit, open).
PARRY = {
    # blade: takes the blow on the flat, raised across the chest, palm on the flat
    'blade': [(0.55, 1.0, -0.6, 0.3), (0.05, 1.15, -0.3, 0.42), (0.0, 1.15, -0.3, 0.42), (-0.1, 1.05, -0.65, 0.4), (0.6, 1.1, 0.5, None)],
    # axe/hammer: knocks the blow aside, haft gripped with both hands
    'hammer': [(0.6, 0.95, 0.4, 0.22), (0.15, 1.0, -1.45, 0.25), (0.1, 1.0, -1.45, 0.25), (0.25, 1.1, -0.35, 0.25), (0.75, 1.0, 1.0, None)],
    # pole (spear, staff): two-handed block, shaft slanted across the body
    'spear': [(0.5, 0.95, -0.4, 0.45), (0.3, 1.0, -1.15, 0.5), (0.3, 1.0, -1.15, 0.5), (0.15, 0.9, -1.4, 0.5), (0.65, 1.1, 0.35, None)],
    'staff': [(0.5, 0.95, -0.4, 0.45), (0.3, 1.0, -1.05, 0.5), (0.3, 1.0, -1.05, 0.5), (0.15, 0.9, -1.3, 0.5), (0.65, 1.1, 0.4, None)],
    # sickles: crossed in an X before the chest, far fist with the second sickle
    'sickles': [(0.5, 0.95, -0.4, 'x'), (0.1, 1.05, -1.0, 'x'), (0.05, 1.05, -1.0, 'x'), (-0.05, 0.95, -1.3, 'x'), (0.65, 1.1, 0.4, None)],
}


def parry(body):
    out = []
    body_spec = [  # hip x, hip y, lean, tilt, face
        (0.0, -1.68, 0.02, -0.05, 'shout'), (0.05, -1.64, -0.04, -0.08, 'shout'), (0.05, -1.62, -0.06, -0.08, 'calm'),
        (-0.18, -1.66, -0.22, -0.2, 'pain'), (0.12, -1.6, 0.32, 0.2, 'pain')]
    for i, ((hx, hy, lean, tilt, face), (a, r, ba, grip)) in enumerate(zip(body_spec, PARRY[body])):
        hip = (hx, hy)
        hN = np.asarray(shoulder_n(hip, lean)) + r * np.array([np.cos(a), np.sin(a)])
        bd = np.array([np.cos(ba), np.sin(ba)])
        if grip is None:
            hF, handF = (0.85, -1.9), 'fist'
        elif grip == 'x':
            hF, handF = tuple(hN + np.array([0.3, -0.25])), 'fist'
        else:
            hF, handF = tuple(hN + bd * grip), ('open' if body == 'blade' else 'fist')
        out.append(dict(hip=hip, lean=lean, tilt=tilt, fN=(-0.6 - (0.15 if i == 3 else 0.0), -0.11), fF=(0.6, -0.11),
                        hN=tuple(hN), eN=(-0.6, 0.8), hF=hF, eF=(0.2, 1.0), handF=handF,
                        drag=(0.3 if i == 3 else 0.0, -0.05), face=face))
    return out


# name -> (poses, fps, loop)
ANIMS = {
    'idle': (idle(12), 10, True),
    'run': (run(8), 16, True),
    'jump': (jump(4), 12, False),
    'fall': (fall(4), 10, True),
    'roll': (roll(8), 24, False),
    'dash': (dash(4), 24, False),
    'strike_1': (strike(-2.0, 0.9, 8), 24, False),
    'strike_2': (strike(1.2, -1.6, 8), 24, False),
    'strike_3': (strike(-2.0, 0.9, 10, heavy=True), 24, False),
    'strike_up': (strike_up(8), 24, False),
    'strike_down': (strike_down(6), 24, False),
    'hurt': (hurt(3), 12, False),
    'death': (death(10), 12, False),
    'flare': (flare(8), 16, False),
    'parry_blade': (parry('blade'), 12, False),
    'parry_hammer': (parry('hammer'), 12, False),
    'parry_spear': (parry('spear'), 12, False),
    'parry_staff': (parry('staff'), 12, False),
    'parry_sickles': (parry('sickles'), 12, False),
}

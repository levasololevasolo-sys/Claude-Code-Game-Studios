"""The three location bosses, hand-drawn in the hero / enemy style (sdf2d ink and paint).

Кикимора Болотная (src/enemies/lair_boss.gd), Лихо Одноглазое (likho_boss.gd),
Морена (morena_boss.gd); looks after design/art/art-bible.md §3, §5.2-5.3 and
design/narrative/characters.md §4.1-4.3. Original designs from Slavic folklore.

Same renderer and units as kinds.py / kinds_forest.py (base.W: world px ->
units, 1 unit = 24 world px, y down, ground y = 0, the boss faces +x). The
anchors the boss code fires from are kept: Кикимора's throw hand
(throw_hand_y), Лихо's eye (gaze_eye_y), Морена's mouth (breath_mouth_y).

Every pose dict may carry rage (0..1): the phase-2 look (build_bosses.py
renders a `_rage` variant of each fighting sheet with rage = 1; the roar
sheet blends 0 -> 1, the death sheet 1 -> 0: «от ярости к узнаванию»).
Layers tagged 'fx' are painted after the outline (particles, threads, smears).
"""
import numpy as np

import base
from base import W, hexc, rot, lerp, ease, unit, INK  # noqa: F401
from kinds import limb, fingers, cyc, seq
from kinds_forest import ForestBody, twigs, clods, MOON

TAU = 2 * np.pi
ROT = hexc('B6E36B')
# Bosses are 4x the canvas area of an enemy: painted straight at the sheet
# density (SDF coverage is analytic, so the edges stay anti-aliased) instead of
# 2x supersampled, 4x faster. Same sheet px per unit (base.SHEET_PX).
base.S_RENDER = int(base.SHEET_PX)
base.DOWN = 1


def mix(a, b, k):
    return np.asarray(a, float) * (1 - k) + np.asarray(b, float) * k


def arc_pts(c, r, a0, a1, n=14):
    return [np.asarray(c) + r * np.array([np.cos(a), np.sin(a)]) for a in np.linspace(a0, a1, n)]


class BossBody(ForestBody):
    """Boss outline is 5 px at 1080p (art bible §5.2): thicker than the enemies' 3 px."""
    OUTLINE = 2.9
    MOON_K = 0.4

    def glowdot(self, c, r, col, k=1.0):
        cv = self.cv
        cv.paint(cv.circle(c, r), col, R=0.02, line=0, shade=False, rim=False, cast=False, union=False,
                 glow=(col, 0.05 * k, 0.45 * k))

    def ripple(self, c, rx, k, col=None, alpha=0.6):
        cv = self.cv
        d = np.abs(cv.ellipse(c, rx, rx * 0.14)) - 0.03
        cv.ink(d, alpha=alpha * k, col=col)


# =====================================================================
class Kikimora(BossBody):
    """Кикимора Болотная: tall hunched bog-spinner. Drop-shaped tina skirt, hair of
    tina to the ground, long hooked nose, a distaff (прялка) with a glowing tuft of
    tina, a spindle on a thread in the near hand. Phase 2: the hair lifts like weed
    in a current, the eyes and the tuft burn rust-orange."""
    BOUNDS = (-5.4, 5.8, -12.0, 0.7)
    MOON_K = 0.25
    SKIN = hexc('92A486')
    DRESS = hexc('3E5546')
    RAG = hexc('587456')
    HAIR = hexc('2D4433')
    HAIR_L = hexc('56794C')
    SCARF = hexc('5C4B3B')
    WOOD = hexc('8E734B')
    WOOD_D = hexc('5E4A30')
    KUDEL = hexc('7A9A58')
    EYE = hexc('C8F07A')
    RAGE = hexc('FF8A5A')
    MUD = hexc('4E3E28')
    BASE = dict(bob=0.0, lean=0.0, hunch=0.5, crouch=0.0, head=(0.0, 0.0), tilt=0.0, nearh=(2.3, -4.0),
                farh=(-0.7, -4.7), staff=0.06, sway=0.0, flare=0.0, mouth=0.1, eye=1.0, skirt=0.0, clod=0.0,
                up=0.0, rise=0.0, ripple=0.0, splash=0.0, rage=0.0, smear=0.0, spin=0.0, lie=0.0, spindle=1.0,
                dust=0.0, sink=0.0)

    def setup(self):
        p = self.p
        self.hip = np.array([-0.2 + p['lean'] * 0.5, -4.3 + p['crouch'] + p['bob']])
        a = 0.3 + 0.62 * p['hunch'] + p['lean'] * 0.35
        self.chest = self.hip + (np.sin(a) * 3.5, -np.cos(a) * 3.5)
        self.hump = lerp(self.hip, self.chest, 0.78) + rot(np.array([-0.62, -0.18]), a * 0.6)
        self.neck = self.chest + (0.42, -0.12)
        self.hc = self.neck + (0.5, -0.22) + np.asarray(p['head'])
        self.near_sh = self.chest + (0.08, 0.2)
        self.far_sh = self.chest + (-0.4, 0.1)
        s = p['staff']
        self.sd = np.array([np.sin(s), -np.cos(s)])
        self.grip = np.asarray(p['farh'], float)
        self.top = self.grip + self.sd * 2.4
        self.kudel = self.top + self.sd * 0.85
        self.eyec = mix(self.EYE, self.RAGE, p['rage'])

    def layers(self):
        L = [(None, self.hair_back), (None, self.staff), (None, self.far_arm), (None, self.skirt),
             (None, self.torso), (None, self.head), (None, self.near_arm), ('fx', self.fx)]
        if self.p['lie'] > 0:
            L.insert(0, ('fx', self.staff_lying))
        return L

    # ---- hair: a mass of tina from the scarf down the back to the ground
    def hair_back(self):
        cv, p = self.cv, self.p
        fl, sw = p['flare'] + 0.35 * p['rage'], p['sway']
        hc, hip = self.hc, self.hip
        base_x = hip[0] - 2.0 - fl * 0.6 + sw
        mass = cv.smin(cv.ellipse(hc + (-0.3, -0.05), 0.55, 0.6),
                       cv.cone(self.hump + (-0.3, 0.0), (hip[0] - 1.1 + sw * 0.5 - fl * 0.4, -0.5), 0.75, 1.15), 0.4)
        mass = cv.smin(mass, cv.ellipse((base_x + 0.6, -0.2), 1.0, 0.3), 0.3)
        streak = 1 - 0.22 * np.clip(np.sin(cv.X * 13 + cv.Y * 2.5 + cv.n_mid * 9), 0, 1)
        cv.paint(mass, self.HAIR, R=0.4, pattern=streak, dim=0.85)
        rng = np.random.default_rng(11)
        d = None
        for i in range(11):
            k = i / 10
            r = lerp(hc + (-0.35, -0.45), self.hump + (-0.55, 0.4), k)
            ln = -r[1] + 0.1 + 0.25 * rng.random()
            bx = -0.5 - 1.6 * k - 0.4 * rng.random()
            lift = fl * (0.7 + 0.9 * (1 - k))
            wv = 0.35 * fl * np.sin(i * 1.9)
            mid = r + (bx * 0.5 - lift * 0.8 + sw * 0.5, ln * 0.45 * (1 - 0.45 * fl) + wv)
            end = r + (bx - lift * 1.3 + sw, ln * (1 - 0.5 * fl) - wv)
            di = cv.path([r, mid, end], 0.1 + 0.04 * rng.random(), 0.035)
            d = di if d is None else np.minimum(d, di)
        cv.paint(d, self.HAIR_L * 0.9, R=0.08, line=0.55, cast=False)
        # rot-glow beads in the tina (гнилушки); more in the rage
        for i in range(4 + int(4 * p['rage'])):
            k = (i * 0.37) % 1
            q = lerp(hc + (-0.9, 0.4), (base_x + 0.6, -0.6), k) + (0.25 * np.sin(i * 2.3), -0.3 * np.cos(i * 1.7))
            self.glowdot(q, 0.045, mix(ROT, self.RAGE, p['rage'] * 0.6), 0.8)

    # ---- the distaff: shaft, carved blade, glowing tuft of tina
    def staff(self):
        cv, p = self.cv, self.p
        sd, g = self.sd, self.grip
        bot = g - sd * 2.3
        perp = np.array([-sd[1], sd[0]])
        d = cv.cone(bot, self.top, 0.075, 0.07)
        blade = cv.poly([self.top - perp * 0.16, self.top + perp * 0.16, self.top + sd * 1.25 + perp * 0.3,
                         self.top + sd * 1.45 + perp * 0.18, self.top + sd * 1.3, self.top + sd * 1.45 - perp * 0.18,
                         self.top + sd * 1.25 - perp * 0.3], 0.03)
        cv.paint(np.minimum(d, blade), self.WOOD, R=0.1, dim=0.95,
                 pattern=1 - 0.15 * np.clip(np.sin((cv.X * sd[0] + cv.Y * sd[1]) * 20), 0, 1))
        cv.ink(np.abs(cv.circle(self.top + sd * 0.35, 0.09)) - 0.012, alpha=0.7)
        cv.ink(cv.path([self.top + sd * 0.3 - perp * 0.1, self.top + sd * 0.45, self.top + sd * 0.3 + perp * 0.1], 0.012),
               alpha=0.6)
        kc = mix(self.KUDEL, self.KUDEL * 0.8 + self.RAGE * 0.35, p['rage'])
        tuft = cv.smin(cv.ellipse(self.kudel, 0.34, 0.5, rot=np.arctan2(sd[1], sd[0]) + np.pi / 2),
                       cv.ellipse(self.kudel - sd * 0.2 + perp * 0.12, 0.26, 0.3), 0.08)
        cv.paint(tuft, kc, R=0.2, line=0.7, pattern=1 - 0.25 * np.clip(np.sin(cv.X * 30 + cv.Y * 18), 0, 1),
                 glow=(mix(ROT, self.RAGE, p['rage']), 0.06, 0.18 + 0.2 * p['up'] + 0.15 * p['rage']))
        self.strands([self.kudel + perp * x - sd * 0.25 for x in (-0.22, 0.0, 0.2)], [0.6, 0.85, 0.5], kc * 0.85,
                     sway=-0.15 + p['sway'] * 0.3, w=0.035, line=0.4)

    def staff_lying(self):
        cv = self.cv
        k = self.p['lie']
        y = -0.12 - self.p['sink']
        a, b = np.array([0.6, y]), np.array([4.6, y - 0.05])
        d = cv.cone(a, b, 0.075, 0.07)
        cv.paint(d, self.WOOD * (1 - 0.3 * k), R=0.06, line=0.6, union=False, cast=False)
        cv.paint(cv.ellipse(b + (0.4, -0.1), 0.45, 0.25), self.KUDEL * 0.7, R=0.1, line=0.6, union=False, cast=False)

    def far_arm(self):
        cv, p = self.cv, self.p
        d, el, h = limb(cv, self.far_sh, self.grip + (0.0, 0.05), 1.7, 1.7, 0.16, 0.1, (-0.6, 1.0))
        d = np.minimum(d, fingers(cv, h, unit(np.asarray(h) - el) * 0.5 + self.sd * 0.5, n=4, ln=0.35, spread=0.9,
                                  r=0.04, curl=1.2))
        cv.paint(d, self.SKIN * 0.9, R=0.08, dim=0.72)
        cv.paint(cv.cone(self.far_sh, lerp(self.far_sh, el, 0.9), 0.28, 0.2), self.RAG, R=0.1, dim=0.7, line=0.6)

    # ---- the drop: a heavy tina skirt, ragged hem dragging in the bog
    def skirt(self):
        cv, p = self.cv, self.p
        hip, sk = self.hip, p['skirt']
        top_y = hip[1] - 0.3
        n = 11
        hem = []
        for i in range(n):
            k = i / (n - 1)
            x = hip[0] - 2.05 + 4.25 * k + sk * (0.6 + 0.4 * np.sin(k * 3))
            y = (0.08 if i % 2 else -0.22) + 0.06 * np.sin(i * 2.7)
            hem.append((x, y))
        pts = [(hip[0] - 0.8, top_y), (hip[0] - 1.55 + sk * 0.3, hip[1] * 0.45)] + hem + \
              [(hip[0] + 1.6 + sk * 0.3, hip[1] * 0.45), (hip[0] + 0.95, top_y)]
        d = cv.poly(pts, 0.08)
        streak = 1 - 0.22 * np.clip(np.sin(cv.X * 9 + cv.n_mid * 12), 0, 1) - 0.12 * (cv.Y > -0.9)
        cv.paint(d, self.RAG, R=0.5, pattern=streak)
        # tina strands over the skirt and a mud rim at the hem
        roots = [(hip[0] - 1.3 + 0.5 * i + sk * 0.2, hip[1] * 0.5 + 0.2 * np.sin(i)) for i in range(6)]
        self.strands(roots, [1.3, 1.6, 1.2, 1.5, 1.1, 1.4], self.HAIR_L * 0.8, sway=sk * 0.5 - 0.1, w=0.05, line=0.45)
        mud = cv.inter(d + 0.02, -(cv.Y + 0.45 + 0.1 * np.sin(cv.X * 7)))
        cv.paint(mud, self.MUD, R=0.1, line=0, cast=False, union=False, alpha=0.85)

    def torso(self):
        cv, p = self.cv, self.p
        d = cv.smin(cv.cone(self.hip + (0, -0.2), self.chest, 0.95, 0.55), cv.ellipse(self.hump, 0.72, 0.55, rot=0.4), 0.35)
        cv.paint(d, self.DRESS, R=0.35, pattern=1 - 0.08 * np.clip(np.sin(cv.X * 16 - cv.Y * 5), 0, 1))
        # a shawl of weed over the hump and the shoulders
        roots = [lerp(self.hump + (-0.5, 0.1), self.chest + (0.3, 0.1), k) for k in np.linspace(0, 1, 6)]
        self.strands(roots, [0.9, 1.2, 1.0, 1.3, 0.8, 0.7], self.HAIR_L, sway=-0.2 + p['sway'] * 0.5 - p['flare'] * 0.4,
                     w=0.06, line=0.5)

    def head(self):
        cv, p = self.cv, self.p
        c, t = self.hc, p['tilt']
        R = lambda v: c + rot(np.asarray(v, float), t)  # noqa: E731
        skull = cv.smin(cv.ellipse(c, 0.42, 0.5, rot=t), cv.ellipse(R((0.2, 0.38)), 0.17, 0.14), 0.08)
        nose = cv.cone(R((0.3, -0.05)), R((1.0, 0.32)), 0.12, 0.025)
        face = cv.smin(skull, nose, 0.05)
        skin = mix(self.SKIN, self.SKIN * np.array([0.85, 0.8, 0.75]), p['rage'])
        cv.paint(face, skin, R=0.25)
        cv.paint(cv.circle(R((0.62, 0.08)), 0.05), skin * 0.8, R=0.03, line=0.5, cast=False, union=False)  # wart
        # the scarf (повойник), tied at the nape, the tail hangs back
        line_y = c[1] - 0.12 + 0.75 * (c[0] - cv.X)
        scarf = cv.inter(skull - 0.08, cv.Y - line_y)
        tail = cv.path([R((-0.4, 0.1)), R((-0.75, 0.35 - p['flare'] * 0.3)), R((-0.95 - p['flare'] * 0.4, 0.75))], 0.12, 0.05)
        cv.paint(np.minimum(scarf, tail), self.SCARF, R=0.12, pattern=1 - 0.15 * np.clip(np.sin(cv.X * 40), 0, 1))
        # front locks of tina framing the face
        self.strands([R((0.05, -0.2)), R((-0.1, -0.1))], [0.9, 1.1], self.HAIR, sway=-0.1 - p['flare'] * 0.5, w=0.06,
                     line=0.5)
        # sunken sockets and two glowing eyes
        for q in (R((0.12, -0.04)), R((0.34, -0.02))):
            cv.paint(cv.ellipse(q, 0.1, 0.075, rot=t), INK * 1.4, R=0.02, line=0, shade=False, rim=False, cast=False,
                     union=False)
        g = p['eye'] * (1 + 0.5 * p['rage'])
        if g > 0.05:
            self.eyes([R((0.13, -0.04)), R((0.35, -0.02))], 0.055 + 0.012 * g, self.eyec, glow=g)
        m = p['mouth'] + 0.25 * p['rage']
        mc = R((0.32, 0.27))
        cv.paint(cv.ellipse(mc, 0.14, 0.02 + 0.11 * m, rot=t + 0.2), hexc('1A1012'), R=0.02, line=0.5, shade=False,
                 rim=False, cast=False, union=False)
        if m > 0.35:
            for dx in (-0.06, 0.06):
                tooth = cv.cone(mc + rot(np.array([dx, -0.06 * m]), t), mc + rot(np.array([dx, 0.02]), t), 0.025, 0.004)
                cv.paint(tooth, hexc('D9D2B8'), R=0.01, line=0.3, shade=False, rim=False, cast=False, union=False)
        if p['rage'] > 0:
            for v in ((0.0, 0.1, -0.2, 0.32), (0.4, 0.1, 0.55, 0.3)):
                cv.paint(cv.path([R(v[:2]), R(v[2:])], 0.012), self.RAGE, R=0.01, line=0, shade=False, rim=False,
                         cast=False, union=False, alpha=0.7 * p['rage'], glow=(self.RAGE, 0.02, 0.2 * p['rage']))

    def near_arm(self):
        cv, p = self.cv, self.p
        h0 = np.asarray(p['nearh'], float)
        d, el, h = limb(cv, self.near_sh, h0, 1.75, 1.7, 0.16, 0.1, (0.2, 1.0))
        fd = unit(np.asarray(h) - el)
        claw = fingers(cv, h, fd, n=4, ln=0.5, spread=0.9 + 0.4 * p['flare'], r=0.042, curl=0.5)
        cv.paint(np.minimum(d, claw), self.SKIN, R=0.08)
        cv.paint(cv.cone(self.near_sh, lerp(self.near_sh, el, 0.85), 0.3, 0.2), self.RAG, R=0.12, line=0.6)
        self.strands([el + (-0.05, 0.05), el + (0.1, 0.1)], [0.5, 0.65], self.HAIR_L, sway=-0.1, w=0.035, line=0.4)
        self.hand = h
        if p['spindle'] > 0 and p['clod'] <= 0:
            # the spindle hangs from the fingers on a thread from the tuft
            sp = h + (0.08, 0.55)
            a = p['spin'] * TAU
            sd = cv.cone(sp + (0.0, -0.4), sp + (0.0, 0.55), 0.035, 0.012)
            wh = cv.ellipse(sp + (0.0, 0.3), 0.15, 0.07)
            cv.paint(np.minimum(sd, wh), self.WOOD, R=0.04, line=0.5, cast=False,
                     pattern=1 - 0.3 * np.clip(np.sin(cv.X * 50 + a * 3), 0, 1))
            cv.ink(cv.path([self.kudel, lerp(self.kudel, sp, 0.5) + (0, 0.35), sp + (0, -0.4)], 0.012), col=self.KUDEL * 1.3,
                   alpha=0.75 * p['spindle'])
        if p['clod'] > 0:
            k = p['clod']
            c = h + (0.12, -0.28)
            cl = cv.smin(cv.circle(c, 0.36 * k), cv.ellipse(c + (0.05, 0.25 * k), 0.12 * k, 0.25 * k), 0.06)
            cv.paint(cl, self.MUD, R=0.15, line=0.8, union=False, glow=(mix(ROT, self.RAGE, p['rage']), 0.07, 0.35 * k))
            cv.paint(cv.ellipse(c + (-0.1, -0.12), 0.12 * k, 0.07 * k), self.HAIR_L, R=0.04, line=0.3, cast=False,
                     union=False)
        fg = fingers(cv, h, fd, n=2, ln=0.42, spread=0.5, r=0.04, curl=0.6)
        cv.paint(fg, self.SKIN, R=0.05, line=0.6, cast=False)

    def fx(self):
        cv, p = self.cv, self.p
        glow = mix(ROT, self.RAGE, p['rage'])
        if p['up'] > 0:
            # threads rising from the tuft to the ceiling: the pendulums' telegraph
            k = p['up']
            for i, dx in enumerate((-1.6, -0.5, 0.6, 1.7)):
                a = self.kudel + (dx * 0.15, -0.3)
                b = np.array([a[0] + dx * (0.6 + 0.8 * k), a[1] - 0.6 - 4.0 * k])
                d = cv.path([a, lerp(a, b, 0.5) + (0.25 * np.sin(i + k * 5), 0), b], 0.03, 0.012)
                cv.paint(d, glow, R=0.02, line=0, shade=False, rim=False, cast=False, union=False, alpha=0.8,
                         glow=(glow, 0.04, 0.35 * k))
        if p['rise'] > 0:
            # tina threads pulled up out of the bog around her (the summon)
            k = p['rise']
            for i, x in enumerate((-3.4, -2.6, 2.7, 3.6, 4.4)):
                h = 0.6 + 2.6 * k * (0.7 + 0.3 * np.sin(i * 1.9))
                pts = [(x, 0.0), (x + 0.2 * np.sin(i + k * 6), -h * 0.5), (x - 0.1, -h)]
                cv.paint(cv.path(pts, 0.06, 0.015), self.HAIR_L, R=0.03, line=0.5, cast=False, union=False)
                self.glowdot((x - 0.1, -h), 0.05, glow, 0.8)
                self.ripple((x, -0.03), 0.4 + 0.3 * k, 1.0, col=glow * 0.8)
        if p['ripple'] > 0:
            k = p['ripple']
            for j in range(3):
                r = 2.2 + (j * 0.9 + k * 1.6)
                self.ripple((self.hip[0] + 0.3, -0.04), r, (1 - j * 0.25) * min(1, k * 1.5), col=glow, alpha=0.75)
        if p['splash'] > 0:
            k = p['splash']
            wedge = cv.poly([(1.4, 0.05), (2.0 + 1.4 * k, -1.3 * np.sin(np.pi * min(1, k * 1.3))), (3.3 + 2.0 * k, 0.05)], 0.05)
            cv.paint(wedge, hexc('3C5E44'), R=0.2, line=0.7, union=False, cast=False, alpha=0.9,
                     glow=(glow, 0.04, 0.25))
            cv.paint(clods(cv, (2.6, -0.3), k, n=8, spread=1.4, size=0.1, up=1.8, seed=4), hexc('6F9A62'), R=0.03,
                     line=0.4, union=False, cast=False, alpha=1 - 0.6 * k)
        if p['smear'] > 0:
            k = p['smear']
            for i, y in enumerate((-6.2, -4.8, -3.2, -1.8)):
                x0 = self.hip[0] - 1.2 - 0.3 * i
                cv.paint(cv.cone((x0, y), (x0 - 1.8 - 1.2 * k, y + 0.1), 0.06, 0.01), self.HAIR_L * 1.2, R=0.01, line=0,
                         shade=False, rim=False, cast=False, union=False, alpha=0.6 * k)
        if p['dust'] > 0:
            k = p['dust']
            cv.paint(clods(cv, self.grip - self.sd * 2.3, k, n=7, spread=1.0, size=0.08, up=1.0, seed=7),
                     hexc('6F9A62'), R=0.03, line=0.4, union=False, cast=False, alpha=1 - 0.5 * k)
        if p['sink'] > 0:
            k = min(1.0, p['sink'] / 3.0)
            for j in range(3):
                self.ripple((self.hip[0] + 0.2, -0.06 - p['sink']), 1.6 + j * 0.8 + k * 1.2, 1 - j * 0.25,
                            col=hexc('7FA36A'), alpha=0.8)


def kikimora_anims():
    IDLE_N, IDLE_F = (2.0, -4.1), (-0.7, -4.7)

    def idle_pose(k):
        s = np.sin(k * TAU)
        return dict(bob=0.06 * s, sway=0.18 * np.sin(k * TAU + 1), skirt=0.06 * s, spin=k,
                    nearh=(IDLE_N[0] + 0.06 * np.cos(k * TAU), IDLE_N[1] + 0.05 * s), farh=IDLE_F,
                    head=(0.0, 0.04 * s), eye=1.0 + 0.15 * s)
    idle = cyc(6, idle_pose)

    def step(k):
        s = np.sin(k * TAU)
        return dict(bob=-0.1 * abs(np.cos(k * TAU)), lean=0.15, skirt=-0.3 * s, sway=0.25 * s - 0.2,
                    farh=(-0.2 + 0.5 * s, -4.6 + 0.12 * abs(s)), staff=0.1 + 0.18 * s, spin=k * 2,
                    nearh=(2.1 + 0.2 * s, -4.1 + 0.1 * np.cos(k * TAU)), head=(0.05, 0.05 * abs(s)))
    move = cyc(6, step)

    def throw_w(k):
        e = ease(k)
        if k < 0.45:
            h = lerp(IDLE_N, (1.4, -0.6), ease(k / 0.45))
        else:
            h = lerp((1.4, -0.6), (-0.2, -7.2), ease((k - 0.45) / 0.55))
        return dict(lean=-0.35 * e, hunch=0.5 - 0.25 * e, nearh=tuple(h), clod=float(np.clip((k - 0.3) / 0.4, 0, 1)),
                    head=(-0.1 * e, -0.15 * e), tilt=-0.25 * e, mouth=0.5 * e, eye=1 + e, spindle=0.0,
                    sway=-0.2 * e, skirt=-0.15 * e)
    throw_w_ = seq(6, throw_w)

    def throw(k):
        h = lerp((-0.2, -7.2), (3.8, -5.3), ease(min(1, k * 2))) if k < 0.5 else lerp((3.8, -5.3), (3.0, -3.6), ease((k - 0.5) * 2))
        return dict(lean=float(lerp(-0.35, 0.35, ease(min(1, k * 2)))), hunch=0.55, nearh=tuple(h), spindle=0.0,
                    mouth=0.6 * (1 - k), eye=2 - k, sway=0.3, skirt=0.2)
    throw_ = seq(4, throw)

    def pend_w(k):
        e = ease(k)
        return dict(hunch=0.5 - 0.45 * e, lean=-0.1 * e, farh=tuple(lerp(IDLE_F, (0.9, -7.4), e)),
                    nearh=tuple(lerp(IDLE_N, (1.55, -6.5), e)), staff=float(lerp(0.06, 0.05, e)), up=e,
                    tilt=-0.35 * e, head=(-0.1 * e, -0.1 * e), eye=1 + e, mouth=0.3 * e, spindle=0.0, sway=0.1)
    pend_w_ = seq(6, pend_w)

    def pend(k):
        e = ease(min(1, k * 1.8))
        return dict(hunch=float(lerp(0.05, 0.55, e)), farh=tuple(lerp((0.9, -7.4), (1.6, -4.4), e)),
                    nearh=tuple(lerp((1.55, -6.5), (2.0, -3.8), e)), staff=float(lerp(0.05, 0.2, e)),
                    up=float(max(0, 1 - k * 1.5)), dust=float(e * (1 - 0.3 * k)), spindle=0.0, eye=2 - k)
    pend_ = seq(4, pend)

    def lunge_w(k):
        e = ease(k)
        return dict(crouch=1.2 * e, hunch=0.5 + 0.5 * e, lean=-0.3 * e, flare=0.65 * e,
                    nearh=tuple(lerp(IDLE_N, (3.4, -2.2), e)), farh=tuple(lerp(IDLE_F, (-1.5, -2.6), e)),
                    staff=float(lerp(0.06, -1.0, e)), mouth=e, eye=1 + 1.2 * e, head=(0.15 * e, 0.25 * e), spindle=0.0,
                    skirt=-0.25 * e)
    lunge_w_ = seq(5, lunge_w)

    def lunge(k):
        s = np.sin(k * TAU * 2)
        return dict(crouch=1.0, hunch=1.0, lean=0.55, flare=1.0, head=(0.5, 0.35), nearh=(5.0, -3.4 + 0.15 * s),
                    farh=(-1.6, -3.0), staff=-1.3, mouth=1.0, eye=2.2, smear=1.0, skirt=-0.6 + 0.1 * s, spindle=0.0,
                    sway=-0.4)
    lunge_ = seq(4, lunge)

    def wave_w(k):
        e = ease(k)
        return dict(crouch=0.55 * e, hunch=0.5 + 0.2 * e, nearh=tuple(lerp(IDLE_N, (3.1, -2.0 + 0.4 * e), e)),
                    farh=tuple(lerp(IDLE_F, (-1.9, -3.4), e)), staff=float(lerp(0.06, -0.45, e)), ripple=e,
                    skirt=0.35 * np.sin(k * TAU * 1.5), sway=0.3 * e, mouth=0.4 * e, eye=1 + e, spindle=0.0,
                    flare=0.2 * e)
    wave_w_ = seq(6, wave_w)

    def wave(k):
        e = ease(min(1, k * 2))
        return dict(crouch=float(lerp(0.55, 0.9, e)), hunch=0.85, nearh=tuple(lerp((3.1, -1.6), (3.0, -0.35), e)),
                    farh=(-1.9, -3.4), staff=-0.45, splash=float(k), spindle=0.0, eye=2 - k, mouth=0.6)
    wave_ = seq(4, wave)

    def summon_w(k):
        e = ease(k)
        return dict(hunch=0.5 - 0.25 * e, nearh=tuple(lerp(IDLE_N, (2.4, -6.0), e)), spin=k * 4, rise=e,
                    eye=1 + 1.2 * e, mouth=0.35 + 0.25 * np.sin(k * TAU * 2), tilt=-0.2 * e, sway=0.2 * np.sin(k * TAU))
    summon_w_ = seq(6, summon_w)

    def summon(k):
        return dict(hunch=0.3, nearh=(3.5, -5.4), spin=4 + k, rise=1 - k, eye=2 - k, mouth=0.5, sway=0.3, spindle=0.0)
    summon_ = seq(4, summon)

    def roar(k):
        e = ease(min(1, k * 1.6))
        return dict(hunch=float(lerp(0.5, 0.15, e)), tilt=-0.6 * e, head=(-0.25 * e, -0.3 * e), mouth=e, flare=e,
                    nearh=tuple(lerp(IDLE_N, (3.2, -6.8), e)), farh=tuple(lerp(IDLE_F, (-0.4, -6.4), e)),
                    staff=float(lerp(0.06, -0.3, e)), eye=1 + 1.5 * e, rage=float(ease(min(1, k * 1.4))), spindle=0.0,
                    skirt=0.15 * np.sin(k * TAU * 3))
    roar_ = seq(8, roar)

    def hurt(k):
        s = np.sin(k * np.pi)
        return dict(lean=-0.35 * s, tilt=-0.35 * s, head=(-0.2 * s, -0.05), mouth=0.7 * s, eye=1 - 0.5 * s,
                    nearh=(1.5, -4.6), sway=0.3 * s, spindle=0.0)
    hurt_ = seq(3, hurt)

    def intro(k):
        # hunched over the spindle with her back to the room, then she rises and points the distaff
        a = ease(np.clip(k / 0.45, 0, 1))
        b = ease(np.clip((k - 0.45) / 0.35, 0, 1))
        c = ease(np.clip((k - 0.8) / 0.2, 0, 1))
        st = lerp(lerp(0.4, 0.4, a), 1.25, b)
        st = float(lerp(st, 0.06, c))
        return dict(hunch=float(lerp(lerp(1.0, 0.9, a), 0.25, b) * (1 - c) + 0.5 * c), head=(0.0, 0.45 * (1 - b)),
                    tilt=float(0.5 * (1 - b) - 0.2 * b * (1 - c)), eye=float(0.2 + 0.8 * a + 0.8 * b * (1 - c)),
                    spin=k * 6, nearh=tuple(lerp(lerp((1.6, -2.8), (2.0, -3.4), a), IDLE_N, c)),
                    farh=tuple(lerp(lerp((-0.4, -3.8), (0.2, -6.6), b), IDLE_F, c)), staff=st,
                    mouth=0.6 * b * (1 - c), sway=0.15 * np.sin(k * TAU), flare=0.3 * b * (1 - c))
    intro_ = seq(10, intro)

    def die(k):
        a = ease(np.clip(k / 0.25, 0, 1))
        b = ease(np.clip((k - 0.2) / 0.3, 0, 1))
        s = float(ease(np.clip((k - 0.45) / 0.55, 0, 1)) * 7.5)
        return dict(lean=-0.3 * a * (1 - b), tilt=-0.5 * a * (1 - b) + 0.4 * b, mouth=float(a * (1 - b) + 0.2 * b),
                    crouch=1.6 * b, hunch=float(lerp(0.5, 1.0, b)), eye=float(max(0.0, 1.6 * (1 - k * 1.4))),
                    rage=float(1 - ease(np.clip(k / 0.4, 0, 1))), flare=float(0.6 * (1 - b)), sway=0.4 * b,
                    nearh=tuple(lerp((1.2, -5.5), (2.4, -1.2), b)), farh=(-0.9, -3.5), staff=-0.25, spindle=0.0,
                    lie=float(b), dy=s, clip=0.0, sink=s)
    death = seq(12, die)
    return dict(idle=(idle, 6, True), move=(move, 8, True), throw_w=(throw_w_, 8, False), throw=(throw_, 14, False),
                pend_w=(pend_w_, 8, False), pend=(pend_, 12, False), lunge_w=(lunge_w_, 8, False),
                lunge=(lunge_, 10, False), wave_w=(wave_w_, 8, False), wave=(wave_, 12, False),
                summon_w=(summon_w_, 8, False), summon=(summon_, 10, False), roar=(roar_, 8, False),
                hurt=(hurt_, 12, False), intro=(intro_, 6, False), death=(death, 4, False))


# =====================================================================
class Likho(BossBody):
    """Лихо Одноглазое: gaunt, taller than the hero twice over, bark-grey skin, long
    broken legs, arms to the knees with twig fingers. One huge eye in a tall skull
    crowned with dry twigs; a faded red rag (the trophy «повязка Лиха») binds the
    empty side. Phase 2: the eye goes blood-red, ember cracks open in the bark."""
    BOUNDS = (-5.0, 5.6, -12.2, 0.5)
    MOON_K = 0.75
    SKIN = hexc('545A70')
    BARK = hexc('2C2F3C')
    RAG = hexc('625A4E')
    BAND = hexc('8C4030')
    TWIG = hexc('5E4C3A')
    SCLERA = hexc('F3E6C8')
    LID = hexc('20222E')
    EYE = hexc('FF8A3D')
    RAGE = hexc('FF4A2A')
    EMBER = hexc('FF7A2E')
    BASE = dict(bob=0.0, lean=0.0, crouch=0.0, fN=(0.75, 0.0), fF=(-0.7, 0.0), hN=(1.4, -3.4), hF=(-0.9, -3.6),
                head=(0.0, 0.0), tilt=0.0, open=0.6, look=(1.0, 0.0), mouth=0.0, rage=0.0, dust=0.0, smear=0.0,
                fing=0.0, beam=0.0, gather=0.0, sigil=0.0)

    def setup(self):
        p = self.p
        self.hip = np.array([-0.1 + p['lean'] * 0.6, -5.4 + p['crouch'] * 2.9 + p['bob']])
        self.chest = self.hip + (0.25 + p['lean'] * 1.6, -2.6 + abs(p['lean']) * 0.35)
        self.neck = self.chest + (0.15 + p['lean'] * 0.35, -0.25)
        self.hc = self.neck + (0.15 + p['lean'] * 0.25, -0.75) + np.asarray(p['head'])
        self.near_sh = self.chest + (0.25, 0.15)
        self.far_sh = self.chest + (-0.3, 0.1)
        t = p['tilt']
        self.eye_c = self.hc + rot(np.array([0.15, 0.53]), t)
        self.eyec = mix(self.EYE, self.RAGE, p['rage'])

    def layers(self):
        return [(None, self.far_arm), (None, self.far_leg), (None, self.near_leg), (None, self.body),
                (None, self.head), (None, self.near_arm), ('fx', self.fx)]

    def bark(self):
        cv = self.cv
        return 1 - 0.22 * np.clip(np.sin(cv.X * 21 + cv.n_mid * 11 + cv.Y * 1.5), 0, 1) - 0.08 * np.clip(cv.n_hi, 0, 1)

    def cracks(self, pts):
        """A bark crack; glows ember in the rage."""
        cv, r = self.cv, self.p['rage']
        d = cv.path(pts, 0.022, 0.008)
        if r > 0:
            cv.paint(d, self.EMBER, R=0.01, line=0, shade=False, rim=False, cast=False, union=False, alpha=0.9 * r,
                     glow=(self.EMBER, 0.04, 0.3 * r))
        else:
            cv.ink(d, alpha=0.6)

    def leg(self, root, foot, dim):
        cv = self.cv
        d, kn, an = limb(cv, root, np.asarray(foot) + (0, -0.12), 2.85, 2.85, 0.2, 0.09, (1, -0.25))
        d = cv.smin(d, cv.circle(kn, 0.17), 0.05)
        toes = fingers(cv, an, unit((1, 0.35)), n=3, ln=0.6, spread=0.7, r=0.045, curl=0.35)
        heel = cv.cone(an, an + (-0.35, 0.1), 0.06, 0.02)
        cv.paint(np.minimum(np.minimum(d, toes), heel), self.SKIN, R=0.1, dim=dim, pattern=self.bark())
        self.cracks([kn + (-0.05, -0.5), kn + (0.04, -0.15), kn + (-0.02, 0.3)])
        return kn

    def far_leg(self):
        self.leg(self.hip + (-0.12, 0.0), self.p['fF'], 0.72)

    def near_leg(self):
        self.leg(self.hip + (0.12, 0.05), self.p['fN'], 1.0)

    def arm(self, sh, h, dim):
        cv, p = self.cv, self.p
        d, el, hh = limb(cv, sh, h, 2.55, 2.55, 0.15, 0.085, (-0.4, 1.0))
        d = cv.smin(d, cv.circle(el, 0.13), 0.04)
        fd = unit(np.asarray(hh) - el)
        tw = fingers(cv, hh, fd, n=4, ln=0.75, spread=0.75 + p['fing'], r=0.045, curl=0.45)
        tw = np.minimum(tw, cv.cone(hh + fd * 0.35, hh + rot(fd, -1.1) * 0.75, 0.03, 0.01))
        cv.paint(np.minimum(d, tw), self.SKIN, R=0.08, dim=dim, pattern=self.bark())
        self.cracks([lerp(sh, el, 0.3), lerp(sh, el, 0.6) + (0.05, 0), lerp(sh, el, 0.85)])
        return el, hh

    def far_arm(self):
        self.arm(self.far_sh, self.p['hF'], 0.7)

    def near_arm(self):
        self.arm(self.near_sh, self.p['hN'], 1.0)

    def body(self):
        cv, p = self.cv, self.p
        d = cv.smin(cv.cone(self.hip, self.chest, 0.38, 0.5), cv.ellipse(lerp(self.hip, self.chest, 0.72), 0.55, 0.75,
                                                                       rot=np.arctan2(*(self.chest - self.hip)[::-1]) + np.pi / 2), 0.2)
        d = cv.smin(d, cv.cone(self.chest, self.neck + (0.05, -0.1), 0.3, 0.17), 0.12)
        ribs = 1 - 0.25 * np.clip(np.sin((cv.Y - cv.X * 0.3) * 16), 0, 1) * (cv.Y < self.chest[1] + 1.4) * (cv.Y > self.chest[1] - 0.1)
        cv.paint(d, self.SKIN, R=0.3, pattern=ribs * self.bark())
        c = self.chest
        self.cracks([c + (-0.1, 0.3), c + (0.05, 0.8), c + (-0.05, 1.3), c + (0.08, 1.7)])
        # spine knobs on the bent back
        for k in (0.35, 0.55, 0.75):
            q = lerp(self.hip, self.chest, k) + (-0.42, 0.0)
            cv.paint(cv.circle(q, 0.09), self.SKIN * 0.9, R=0.05, line=0.5, cast=False)
        # ragged loincloth
        hip = self.hip
        rag = cv.poly([hip + (-0.5, -0.35), hip + (0.55, -0.3), hip + (0.62, 0.55), hip + (0.3, 0.35), hip + (0.1, 0.8),
                       hip + (-0.15, 0.45), hip + (-0.45, 0.7), hip + (-0.6, 0.3)], 0.04)
        cv.paint(rag, self.RAG, R=0.12, pattern=1 - 0.2 * np.clip(np.sin(cv.X * 45), 0, 1))
        self.strands([hip + (x, 0.4) for x in (-0.4, -0.1, 0.25)], [0.4, 0.55, 0.35], self.RAG * 0.85, sway=-0.1 - p['smear'] * 0.4,
                     w=0.04, line=0.4)

    def head(self):
        cv, p = self.cv, self.p
        c, t = self.hc, p['tilt']
        R = lambda v: c + rot(np.asarray(v, float), t)  # noqa: E731
        # dry twigs crown the skull (broken shorter in the rage)
        r = p['rage']
        tw = None
        for (x, y, a, ln, s) in ((-0.3, -0.75, -1.95, 1.0, 0), (0.12, -0.92, -1.45, 1.15, 1), (-0.55, -0.45, -2.45, 0.8, 2),
                                 (0.38, -0.7, -1.05, 0.7, 3)):
            di = twigs(cv, R((x, y)), a + t, ln * (1 - 0.3 * r), 0.075, depth=2 if r < 0.5 else 1, spread=0.6, seed=s)
            tw = di if tw is None else np.minimum(tw, di)
        cv.paint(tw, self.TWIG, R=0.05, line=0.6)
        if r > 0:
            for (x, y) in ((-0.3, -1.6), (0.25, -1.85)):
                self.glowdot(R((x, y)), 0.05, self.EMBER, r)
        skull = cv.smin(cv.ellipse(c, 0.62, 0.95, rot=t), cv.ellipse(R((0.25, 0.55)), 0.48, 0.42, rot=t), 0.15)
        cv.paint(skull, self.SKIN * 1.05, R=0.3, pattern=self.bark())
        # the brow ridge, the socket and the one eye
        e = self.eye_c
        op = p['open']
        sock = cv.ellipse(e, 0.47, 0.42, rot=t)
        cv.paint(sock, self.LID, R=0.08, line=0.6, shade=False, cast=False, union=False)
        if op > 0.04:
            ry = 0.36 * min(op, 1.45) * 0.85
            scl = cv.ellipse(e, 0.38 + 0.04 * max(0, op - 1), ry, rot=t)
            cv.paint(scl, self.SCLERA * (0.92 + 0.08 * min(op, 1)), R=0.15, line=0.4, cast=False, union=False,
                     glow=(self.eyec, 0.04, 0.12 * op))
            look = np.asarray(p['look'], float)
            ic = e + rot(look * 0.08, t)
            iris = cv.inter(cv.circle(ic, 0.22 + 0.03 * max(0, op - 1)), scl)
            cv.paint(iris, self.eyec, R=0.05, line=0.3, shade=False, rim=False, cast=False, union=False,
                     glow=(self.eyec, 0.05 + 0.03 * op, 0.25 + 0.35 * op + 0.25 * r))
            pup = cv.inter(cv.ellipse(ic + rot(look * 0.03, t), 0.045 + 0.03 * max(0, 1 - op), 0.17, rot=t), scl)
            cv.paint(pup, INK, R=0.02, line=0, shade=False, rim=False, cast=False, union=False)
            cv.flat(cv.circle(ic + rot(np.array([-0.07, -0.08]), t), 0.045), np.array([1.0, 0.95, 0.85]), alpha=0.85)
            if r > 0:
                for a in (0.4, 2.6, 3.6):
                    v = rot(np.array([np.cos(a), np.sin(a)]), t)
                    cv.paint(cv.path([e + v * 0.36, e + v * 0.22], 0.012, 0.005), self.RAGE * 0.8, R=0.01, line=0,
                             shade=False, rim=False, cast=False, union=False, alpha=0.8 * r)
            # heavy upper lid
            lid = cv.inter(cv.ellipse(e, 0.46, 0.41, rot=t), -(cv.ellipse(e + rot(np.array([0, 0.1]), t), 0.44, ry + 0.08, rot=t)))
            lid = cv.inter(lid, cv.Y - e[1] - 0.05)
            cv.paint(lid, self.SKIN * 0.75, R=0.06, line=0.5, cast=False, union=False)
        else:
            cv.paint(cv.ellipse(e + rot(np.array([0, 0.02]), t), 0.4, 0.34, rot=t), self.SKIN * 0.8, R=0.1, line=0.5,
                     cast=False, union=False)
            cv.ink(cv.path([e + rot(np.array([-0.36, 0.04]), t), e + rot(np.array([0, 0.12]), t),
                            e + rot(np.array([0.36, 0.04]), t)], 0.022), alpha=0.9)
        brow = cv.path([R((-0.42, 0.05)), R((0.12, -0.08)), R((0.68, 0.18))], 0.13, 0.07)
        cv.paint(brow, self.SKIN * 0.95, R=0.08, line=0.6, cast=False, pattern=self.bark())
        # the bandage over the empty side: diagonal strip, knot at the back, tails
        band = cv.path([R((-0.66, 0.05)), R((-0.1, -0.35)), R((0.62, -0.55))], 0.13, 0.1)
        band = cv.inter(band, skull - 0.06)
        cv.paint(band, self.BAND * (1 - 0.15 * r), R=0.06, line=0.6, cast=False,
                 pattern=1 - 0.2 * np.clip(np.sin(cv.X * 36 + cv.Y * 20), 0, 1))
        k0 = R((-0.62, 0.02))
        sw = 0.2 * np.sin(p['bob'] * 30) - p['smear'] * 0.6 - 0.3 * r
        tails = np.minimum(cv.path([k0, k0 + (-0.4 + sw * 0.5, 0.35), k0 + (-0.55 + sw, 0.95)], 0.08, 0.04),
                           cv.path([k0, k0 + (-0.55 + sw * 0.7, 0.15), k0 + (-0.95 + sw, 0.5)], 0.07, 0.03))
        cv.paint(np.minimum(tails, cv.circle(k0, 0.12)), self.BAND * 0.9, R=0.05, line=0.6)
        # the crack of a mouth under the eye
        m = p['mouth'] + 0.25 * r
        mc = R((0.3, 0.86))
        mouth = cv.ellipse(mc, 0.3, 0.025 + 0.16 * m, rot=t + 0.15)
        cv.paint(mouth, hexc('170E10'), R=0.02, line=0.6, shade=False, rim=False, cast=False, union=False)
        if m > 0.3:
            for dx in (-0.16, -0.04, 0.08, 0.2):
                tth = cv.cone(mc + rot(np.array([dx, -0.16 * m]), t), mc + rot(np.array([dx + 0.02, -0.02]), t), 0.03, 0.004)
                cv.paint(tth, hexc('CFC3A0'), R=0.01, line=0.3, shade=False, rim=False, cast=False, union=False)

    def fx(self):
        cv, p = self.cv, self.p
        if p['dust'] > 0:
            k = p['dust']
            for x in (-1.2, 1.4):
                cv.paint(clods(cv, (x, -0.1), k, n=7, spread=1.4, size=0.1, up=1.5, seed=int(x * 10) + 20), hexc('6A5A46'),
                         R=0.03, line=0.4, union=False, cast=False, alpha=1 - 0.6 * k)
        if p['smear'] > 0:
            k = p['smear']
            for i, y in enumerate((-8.6, -7.0, -5.4, -3.6)):
                x0 = self.hip[0] - 0.9 - 0.25 * i
                cv.paint(cv.cone((x0, y), (x0 - 2.0 - k, y + 0.15), 0.06, 0.01), MOON, R=0.01, line=0, shade=False,
                         rim=False, cast=False, union=False, alpha=0.55 * k)
        if p['gather'] > 0:
            # embers drawn into the eye (the gaze wind-up)
            k = p['gather']
            for i in range(7):
                a = i / 7 * TAU + 0.4
                r = 1.6 * (1 - k) + 0.45
                self.glowdot(self.eye_c + r * np.array([np.cos(a), np.sin(a) * 0.8]), 0.045 + 0.02 * k, self.eyec, 0.6 + k)
        if p['beam'] > 0:
            e = self.eye_c
            cv.paint(cv.circle(e + (0.25, 0.0), 0.3 * p['beam']), np.array([1.0, 0.94, 0.82]), R=0.02, line=0,
                     shade=False, rim=False, cast=False, union=False, alpha=0.8, glow=(self.eyec, 0.12, 0.6 * p['beam']))
        if p['sigil'] > 0:
            # the woe sign drawn by the fingers in the air (fades into the floor marks)
            k = p['sigil']
            c = np.asarray(p['hN']) + (0.4, -0.9)
            ring = np.abs(cv.ellipse(c, 0.45 * k, 0.3 * k)) - 0.025
            cv.paint(ring, self.eyec, R=0.01, line=0, shade=False, rim=False, cast=False, union=False, alpha=0.8,
                     glow=(self.eyec, 0.05, 0.4 * k))
            cv.paint(cv.circle(c, 0.09 * k), INK, R=0.01, line=0, shade=False, rim=False, cast=False, union=False)


def likho_anims():
    IDLE_N, IDLE_F = (1.4, -3.4), (-0.9, -3.6)

    def idle_pose(k):
        s, c = np.sin(k * TAU), np.cos(k * TAU)
        return dict(bob=0.05 * s, hN=(IDLE_N[0] + 0.12 * c, IDLE_N[1] + 0.1 * s), hF=(IDLE_F[0] - 0.1 * c, IDLE_F[1]),
                    open=0.55 + 0.12 * s, look=(1.0, 0.25 * s), head=(0.04 * s, 0.03 * c), fing=0.15 * s)
    idle = cyc(6, idle_pose)

    def step(k):
        s, c = np.sin(k * TAU), np.cos(k * TAU)
        return dict(bob=-0.12 * abs(c), lean=0.16, fN=(0.5 + 1.1 * s, -0.4 * max(0, c)), fF=(-0.2 - 1.1 * s, -0.4 * max(0, -c)),
                    hN=(1.4 - 0.7 * s, -3.6 + 0.2 * abs(s)), hF=(-0.4 + 0.7 * s, -3.8), open=0.65, look=(1.0, 0.1))
    move = cyc(8, step)

    def leap_w(k):
        e = ease(k)
        return dict(crouch=0.95 * e, lean=0.35 * e, fN=(0.75 + 0.6 * e, 0.0), fF=(-0.7 - 0.6 * e, 0.0),
                    hN=tuple(lerp(IDLE_N, (2.6, -0.1), e)), hF=tuple(lerp(IDLE_F, (1.2, -0.1), e)), open=0.6 + 0.5 * e,
                    head=(0.25 * e, 0.3 * e), tilt=0.25 * e, look=(1.0, -0.3 * e), fing=0.3 * e)
    leap_w_ = seq(5, leap_w)

    def leap(k):
        if k < 0.2:
            return dict(crouch=-0.15, lean=0.25, fN=(0.3, 0.0), fF=(-0.9, 0.1), hN=(1.8, -10.4), hF=(-0.5, -10.0),
                        open=1.1, tilt=-0.2, fing=0.4)
        if k < 0.7:
            return dict(crouch=0.15, lean=0.2, fN=(1.4, -2.6), fF=(-0.3, -2.3), hN=(3.4, -7.6), hF=(-2.6, -7.4),
                        open=1.1, fing=0.6, mouth=0.4)
        return dict(crouch=0.05, lean=0.15, fN=(1.2, -0.6), fF=(-0.6, -0.4), hN=(2.8, -9.6), hF=(-1.6, -9.8), open=1.2,
                    mouth=0.6, tilt=0.15, fing=0.5)
    leap_ = seq(5, leap)

    def land(k):
        e = ease(k)
        return dict(crouch=float(lerp(0.9, 0.15, e)), lean=float(lerp(0.35, 0.05, e)), fN=(1.3, 0.0), fF=(-1.3, 0.0),
                    hN=tuple(lerp((2.6, -0.1), IDLE_N, e)), hF=tuple(lerp((1.0, -0.1), IDLE_F, e)), dust=float(0.2 + 0.8 * k),
                    open=1.0 - 0.3 * e, mouth=0.4 * (1 - e))
    land_ = seq(4, land)

    def gaze_w(k):
        e = ease(k)
        return dict(lean=-0.12 * e, hN=tuple(lerp(IDLE_N, (4.6, -7.4), e)), hF=tuple(lerp(IDLE_F, (-3.8, -7.2), e)),
                    fing=0.6 * e, open=0.55 + 0.9 * e, head=(0.2 * e, 0.15 * e), tilt=0.12 * e, gather=e,
                    look=(1.0, 0.0), fN=(1.0, 0.0), fF=(-1.0, 0.0))
    gaze_w_ = seq(6, gaze_w)

    def gaze(k):
        s = np.sin(k * TAU * 2)
        return dict(lean=-0.12, hN=(4.5, -7.3 + 0.12 * s), hF=(-3.7, -7.1 - 0.12 * s), fing=0.7 + 0.1 * s, open=1.45,
                    head=(0.2, 0.15), tilt=0.12, beam=1.0, mouth=0.25, fN=(1.0, 0.0), fF=(-1.0, 0.0))
    gaze_ = seq(4, gaze)

    def lunge_w(k):
        e = ease(k)
        return dict(crouch=0.4 * e, lean=-0.3 * e, head=(0.1 * e, 0.6 * e), tilt=0.55 * e,
                    hN=tuple(lerp(IDLE_N, (-2.2, -4.8), e)), hF=tuple(lerp(IDLE_F, (-2.8, -4.4), e)),
                    fN=(0.75 + 0.8 * e, 0.0), fF=(-0.7 - 0.9 * e, 0.0), open=0.6 + 0.5 * e, mouth=0.5 * e, look=(1, 0.3))
    lunge_w_ = seq(5, lunge_w)

    def lunge(k):
        s, c = np.sin(k * TAU), np.cos(k * TAU)
        return dict(crouch=0.35, lean=0.75, head=(0.4, 0.55), tilt=0.45, hN=(-1.9, -5.0 + 0.2 * s), hF=(-2.8, -4.5),
                    fN=(1.4 + 0.9 * s, -0.4 * max(0, c)), fF=(-0.8 - 0.9 * s, -0.4 * max(0, -c)), open=1.2, mouth=0.7,
                    smear=1.0)
    lunge_ = seq(4, lunge)

    def woe_w(k):
        e = ease(k)
        return dict(lean=-0.1 * e, hN=tuple(lerp(IDLE_N, (1.4, -11.4), e)), hF=tuple(lerp(IDLE_F, (-0.6, -11.3), e)),
                    fing=0.8 * e, tilt=-0.4 * e, open=0.6 + 0.4 * e, look=(0.3, -1.0), mouth=0.3 * e,
                    sigil=float(np.clip((k - 0.4) / 0.6, 0, 1)))
    woe_w_ = seq(6, woe_w)

    def woe(k):
        e = ease(min(1, k * 1.8))
        return dict(lean=float(lerp(-0.1, 0.3, e)), hN=tuple(lerp((1.4, -11.4), (4.0, -2.6), e)),
                    hF=tuple(lerp((-0.6, -11.3), (2.7, -2.3), e)), fing=0.6, tilt=float(lerp(-0.4, 0.35, e)), open=1.0,
                    look=(0.6, 0.8), mouth=0.3)
    woe_ = seq(4, woe)

    def summon_w(k):
        e = ease(k)
        s = np.sin(k * TAU * 2)
        return dict(crouch=0.45 * e, lean=0.3 * e, hN=tuple(lerp(IDLE_N, (2.9, -0.5 + 0.2 * s), e)), hF=(-1.0, -4.0),
                    fing=0.5 * s, open=float(lerp(0.6, 0.25, e)), mouth=0.3 + 0.2 * s, tilt=0.3 * e, look=(0.5, 1.0))
    summon_w_ = seq(6, summon_w)

    def summon(k):
        e = ease(k)
        return dict(crouch=float(0.45 * (1 - e)), lean=float(0.3 * (1 - e)), hN=tuple(lerp((2.9, -0.5), (2.2, -6.0), e)),
                    hF=(-1.0, -4.0), fing=0.8, open=0.9)
    summon_ = seq(3, summon)

    def roar(k):
        e = ease(min(1, k * 1.6))
        return dict(tilt=-0.55 * e, head=(-0.15 * e, -0.2 * e), mouth=e, hN=tuple(lerp(IDLE_N, (3.6, -9.6), e)),
                    hF=tuple(lerp(IDLE_F, (-2.8, -9.4), e)), fing=0.8 * e, open=0.6 + 0.8 * e,
                    rage=float(ease(min(1, k * 1.4))), fN=(1.1, 0.0), fF=(-1.1, 0.0), bob=0.05 * np.sin(k * TAU * 4))
    roar_ = seq(8, roar)

    def hurt(k):
        s = np.sin(k * np.pi)
        return dict(lean=-0.3 * s, tilt=-0.35 * s, head=(-0.2 * s, 0.0), open=0.6 - 0.5 * s, mouth=0.6 * s,
                    hN=(0.8, -4.2), hF=(-1.6, -4.4))
    hurt_ = seq(3, hurt)

    def intro(k):
        # asleep, slumped on its heels; the eye opens, it unfolds to full height
        a = ease(np.clip((k - 0.15) / 0.4, 0, 1))
        b = ease(np.clip((k - 0.5) / 0.5, 0, 1))
        return dict(crouch=float(lerp(0.85, 0.0, b)), lean=float(lerp(0.45, 0.0, b)), head=tuple(lerp((0.2, 0.9), (0.0, 0.0), b)),
                    tilt=float(lerp(0.75, 0.0, b)), open=float(0.75 * a - 0.15 * b), fing=0.2 * b,
                    hN=tuple(lerp((2.0, -0.05), IDLE_N, b)), hF=tuple(lerp((0.6, -0.05), IDLE_F, b)),
                    fN=tuple(lerp((1.1, 0.0), (0.75, 0.0), b)), fF=tuple(lerp((-0.9, 0.0), (-0.7, 0.0), b)),
                    look=(1.0, 0.4 * (1 - b)))
    intro_ = seq(10, intro)

    def die(k):
        # «засыпает с облегчением»: the rage ebbs, it sinks onto its heels, the eye
        # closes, the head bows, then it crumbles like a dead tree
        a = ease(np.clip(k / 0.25, 0, 1))
        b = ease(np.clip((k - 0.15) / 0.45, 0, 1))
        c = np.clip((k - 0.72) / 0.28, 0, 1)
        return dict(tilt=float(-0.4 * a * (1 - b) + 0.8 * b), mouth=float(0.8 * a * (1 - b)),
                    open=float(max(0.0, (0.9 + 0.3 * a) * (1 - b * 1.1))), rage=float(1 - ease(np.clip(k / 0.4, 0, 1))),
                    crouch=0.9 * b, lean=float(-0.25 * a * (1 - b) + 0.5 * b), head=(0.2 * b, 0.9 * b),
                    hN=tuple(lerp((2.4, -6.0), (2.2, -0.05), b)), hF=tuple(lerp((-1.8, -6.0), (0.7, -0.05), b)),
                    fN=(1.1, 0.0), fF=(-0.9, 0.0), dissolve=float(ease(c) * 1.05))
    death = seq(12, die)
    return dict(idle=(idle, 6, True), move=(move, 9, True), leap_w=(leap_w_, 8, False), leap=(leap_, 7, False),
                land=(land_, 12, False), gaze_w=(gaze_w_, 8, False), gaze=(gaze_, 10, False), lunge_w=(lunge_w_, 8, False),
                lunge=(lunge_, 10, False), woe_w=(woe_w_, 8, False), woe=(woe_, 12, False), summon_w=(summon_w_, 8, False),
                summon=(summon_, 10, False), roar=(roar_, 8, False), hurt=(hurt_, 12, False), intro=(intro_, 6, False),
                death=(death, 4, False))


# =====================================================================
class Morena(BossBody):
    """Морена: symmetric winter queen floating over the floor. A dark indigo robe
    that falls into a triangle of icicles, wide bell sleeves, two long frosted
    braids, a kokoshnik crown of icicles, a pale sickle. Phase 2: the crown grows
    jagged, the eyes burn magenta, frost veins on the face."""
    BOUNDS = (-5.0, 5.0, -12.2, 1.4)
    MOON_K = 0.55
    ROBE = hexc('3E3D68')
    ROBE_D = hexc('2B2A4A')
    EDGE = hexc('7C93AD')
    FACE = hexc('E8EEF5')
    HAIR = hexc('23264A')
    CROWN = hexc('8FD3F5')
    ICE = hexc('DDEFFA')
    BLADE = hexc('E3EEF6')
    HAFT = hexc('3A2C34')
    EYE = hexc('C02A82')
    RAGE = hexc('FF2F7A')
    BASE = dict(bob=0.0, lean=0.0, hN=(1.25, -5.1), hF=(-1.0, -5.5), sang=0.25, head=(0.0, 0.0), tilt=0.0, eye=1.0,
                open=1.0, mouth=0.0, swell=0.0, hem=0.0, veil=0.0, rage=0.0, puff=0.0, inhale=0.0, smear=0.0,
                icicle=0.0, snow=0.0, melt=0.0, mirror=0.0, sink=0.0, sickle=1.0)

    def setup(self):
        p = self.p
        self.waist = np.array([0.05 + p['lean'] * 0.5, -5.5 + p['bob']])
        self.chest = self.waist + (0.12 + p['lean'] * 1.1, -1.95)
        self.neck = self.chest + (0.1 + p['lean'] * 0.3, -0.5)
        self.hc = self.neck + (0.14, -0.45) + np.asarray(p['head'])
        self.near_sh = self.chest + (0.38, 0.0)
        self.far_sh = self.chest + (-0.38, 0.05)
        self.eyec = mix(self.EYE, self.RAGE, p['rage'])

    def layers(self):
        return [(None, self.veil), (None, self.far_arm), (None, self.robe), (None, self.head), (None, self.near_arm),
                ('fx', self.fx)]

    def veil(self):
        cv, p = self.cv, self.p
        c = self.hc
        v = p['veil'] - p['lean'] * 0.8
        d = cv.poly([c + (-0.1, -0.7), c + (-0.6, -0.3), (self.waist[0] - 1.7 + v, -2.6), (self.waist[0] - 2.2 + v * 1.4, -0.9),
                     (self.waist[0] - 0.8 + v * 0.5, -1.4), self.chest + (-0.2, 0.0)], 0.1)
        cv.paint(d, self.EDGE * 1.15, R=0.3, alpha=0.55, line=0.4, cast=False,
                 pattern=1 - 0.2 * np.clip(np.sin(cv.X * 10 - cv.Y * 4), 0, 1))

    def robe(self):
        cv, p = self.cv, self.p
        w, hem = self.waist, p['hem'] - p['lean'] * 1.0
        m = p['melt']
        n = 9
        pts = [w + (-0.45, 0.05), (w[0] - 1.25 + hem * 0.4, -2.6), (w[0] - 1.95 + hem, -0.35)]
        for i in range(n):
            k = i / (n - 1)
            x = w[0] - 1.95 + 3.9 * k + hem * (1 - 0.4 * k)
            ln = (0.75 if i % 2 == 0 else 0.25) * (1 + 0.6 * p['rage'] * (i % 2 == 0)) * (1 - m)
            if i % 2 == 0:
                pts.append((x, -0.35 + ln + 0.06 * np.sin(i * 3.1)))
            else:
                pts.append((x, -0.35 + ln))
        pts += [(w[0] + 1.95 + hem * 0.6, -0.35), (w[0] + 1.25 + hem * 0.3, -2.6), w + (0.45, 0.05)]
        d = cv.poly(pts, 0.05)
        body = cv.smin(cv.cone(w, self.chest, 0.42, 0.52 + 0.12 * p['swell']), cv.cone(self.chest, self.neck, 0.4, 0.18), 0.12)
        d = cv.smin(d, body, 0.15)
        cv.paint(d, self.ROBE, R=0.45, pattern=1 - 0.12 * np.clip(np.sin(cv.X * 7 + cv.n_mid * 6), 0, 1))
        # the light front panel with a snowflake ornament, symmetric
        cx = w[0] + 0.05
        panel = cv.inter(d + 0.08, np.abs(cv.X - cx - (cv.Y - w[1]) * 0.05) - (0.18 + np.clip((cv.Y - w[1]) * 0.12, 0, 1)))
        cv.paint(panel, self.EDGE, R=0.2, line=0.5, cast=False, union=False)
        for y in (-4.4, -3.1, -1.8):
            q = np.array([cx + (y - w[1]) * 0.05, y])
            dia = cv.poly([q + (0, -0.28), q + (0.2, 0), q + (0, 0.28), q + (-0.2, 0)])
            cv.paint(dia, self.ICE, R=0.05, line=0.5, cast=False, union=False, glow=(self.CROWN, 0.03, 0.08))
            cv.ink(np.abs(cv.circle(q, 0.07)) - 0.012, alpha=0.6)
        # frost along the hem and an ice collar of points over the shoulders
        frost = cv.inter(d + 0.01, -(cv.Y + 0.9 + 0.12 * np.sin(cv.X * 9)))
        cv.paint(frost, self.ICE * 0.9, R=0.1, line=0, cast=False, union=False, alpha=0.65)
        c = self.chest
        coll = None
        for i, a in enumerate(np.linspace(-0.6, 0.6, 7)):
            base = c + (np.sin(a) * 0.55, -0.15 + abs(np.sin(a)) * 0.1)
            tip = base + (np.sin(a) * 0.35, 0.45 + 0.1 * (i % 2))
            di = cv.cone(base, tip, 0.13, 0.01)
            coll = di if coll is None else np.minimum(coll, di)
        cv.paint(coll, self.ICE, R=0.06, line=0.6, glow=(self.CROWN, 0.03, 0.1))
        # the braids, down the front to the waist, frost-tipped
        for side, dim in ((-1, 0.85), (1, 1.0)):
            r0 = self.hc + (0.08 + 0.22 * side, 0.15)
            b1 = r0 + (0.25 * side * 0.3 + p['lean'] * 0.3, 1.3)
            b2 = b1 + (0.05 * side - p['hem'] * 0.2, 1.6)
            d = cv.path([r0, b1, b2], 0.13, 0.08)
            cv.paint(d, self.HAIR, R=0.08, dim=dim, line=0.6,
                     pattern=1 - 0.3 * np.clip(np.sin(np.hypot(cv.X - r0[0], cv.Y - r0[1]) * 22), 0, 1))
            cv.paint(cv.cone(b2, b2 + (0.0, 0.45), 0.08, 0.0), self.ICE, R=0.04, line=0.5, dim=dim)

    def head(self):
        cv, p = self.cv, self.p
        c, t = self.hc, p['tilt']
        R = lambda v: c + rot(np.asarray(v, float), t)  # noqa: E731
        r, m = p['rage'], p['melt']
        # the crown: a kokoshnik plate behind the head and icicles radiating, symmetric
        cc = R((-0.05, -0.2))
        plate = cv.ellipse(cc, 0.78, 0.88, rot=t)
        plate = cv.inter(plate, cv.Y - (cc[1] + 0.25))
        spikes = None
        for i in range(9):
            a = -np.pi + (i + 1) / 10 * np.pi + t
            ln = (0.6 + 0.9 * (1 - abs(i - 4) / 4)) * (1 + 0.55 * r) * (1 - 0.8 * m)
            if r > 0 and i % 2 == 1:
                ln *= 1 + 0.35 * r
            base = cc + 0.62 * np.array([np.cos(a), np.sin(a) * 1.1])
            tip = base + ln * np.array([np.cos(a), np.sin(a)])
            di = cv.cone(base, tip, 0.12, 0.0)
            if r > 0.3 and i in (2, 6):
                side = tip - (base - tip) * -0.0 + rot(np.array([np.cos(a), np.sin(a)]), 0.9 if i == 2 else -0.9) * 0.35 * ln
                di = np.minimum(di, cv.cone(lerp(base, tip, 0.45), side, 0.06, 0.0))
            spikes = di if spikes is None else np.minimum(spikes, di)
        crown = cv.smin(plate, spikes, 0.06)
        cc_col = mix(self.CROWN, self.CROWN * 0.7 + self.RAGE * 0.25, r * 0.5)
        cv.paint(crown, cc_col, R=0.15, line=0.7, glow=(cc_col, 0.05, 0.22 + 0.2 * r),
                 pattern=1 - 0.2 * np.clip(np.sin((cv.X - cc[0]) * 18) * np.sin((cv.Y - cc[1]) * 18), 0, 1))
        cv.paint(cv.inter(plate - 0.12, cv.Y - (cc[1] + 0.12)), self.ICE, R=0.1, line=0.4, cast=False, union=False, alpha=0.7)
        # dark hair parted under the crown, the pale face
        hair = cv.ellipse(R((-0.08, -0.05)), 0.46, 0.5, rot=t)
        cv.paint(hair, self.HAIR, R=0.15)
        face = cv.smin(cv.ellipse(R((0.06, 0.06)), 0.33, 0.43, rot=t), cv.ellipse(R((0.18, 0.3)), 0.16, 0.15, rot=t), 0.06)
        cv.paint(face, self.FACE, R=0.3, line=0.8)
        cv.paint(cv.inter(hair - 0.02, -(face + 0.04)), self.HAIR, R=0.1, line=0.5, cast=False, union=False)
        # eyes: long almond slits, magenta; shut = two ink arcs
        for q in (R((0.03, -0.02)), R((0.26, 0.0))):
            if p['open'] > 0.15:
                cv.paint(cv.ellipse(q, 0.085, 0.03 + 0.02 * p['open'], rot=t - 0.15), INK, R=0.01, line=0, shade=False,
                         rim=False, cast=False, union=False)
                g = p['eye'] * (1 + 0.6 * r)
                cv.paint(cv.ellipse(q, 0.06, 0.02 + 0.015 * p['open'], rot=t - 0.15), self.eyec, R=0.01, line=0,
                         shade=False, rim=False, cast=False, union=False, glow=(self.eyec, 0.03 + 0.01 * g, 0.3 * g))
            else:
                cv.ink(cv.path([q + rot(np.array([-0.08, 0.0]), t), q + rot(np.array([0.0, 0.03]), t),
                                q + rot(np.array([0.08, 0.0]), t)], 0.014), alpha=0.85)
        mo = p['mouth']
        cv.paint(cv.ellipse(R((0.2, 0.3)), 0.07 + 0.03 * mo, 0.018 + 0.07 * mo, rot=t), hexc('3A2448'), R=0.01, line=0.4,
                 shade=False, rim=False, cast=False, union=False)
        if r > 0:
            for v in ((-0.12, 0.05, -0.2, 0.35), (0.3, 0.06, 0.38, 0.3), (0.05, -0.2, 0.0, -0.36)):
                cv.paint(cv.path([R(v[:2]), R(v[2:])], 0.012), self.CROWN, R=0.01, line=0, shade=False, rim=False,
                         cast=False, union=False, alpha=0.8 * r, glow=(self.CROWN, 0.02, 0.15 * r))

    def arm(self, sh, h, dim, near):
        cv, p = self.cv, self.p
        d, el, hh = limb(cv, sh, h, 1.55, 1.5, 0.12, 0.07, (-0.3, 1.0) if near else (-1.0, 0.6))
        fd = unit(np.asarray(hh) - el)
        hand = np.minimum(cv.circle(hh, 0.1), fingers(cv, hh, fd, n=4, ln=0.3, spread=0.5, r=0.03, curl=0.3))
        cv.paint(hand, self.FACE * 0.92, R=0.05, dim=dim)
        # bell sleeve: narrow at the shoulder, opening at the wrist, hanging down
        cuff = lerp(el, hh, 0.78)
        sl = cv.smin(cv.cone(sh, el, 0.24, 0.26), cv.cone(el, cuff, 0.26, 0.46), 0.08)
        drape = cv.poly([el + (0.0, -0.05), cuff + rot(fd, np.pi / 2) * 0.45, cuff + (0.0, 0.95 - 0.2 * p['smear']),
                         lerp(el, cuff, 0.4) + (0.0, 0.55)], 0.05)
        sl = cv.smin(sl, drape, 0.1)
        cv.paint(sl, self.ROBE * (1.05 if near else 1.0), R=0.2, dim=dim, pattern=1 - 0.12 * np.clip(np.sin(cv.X * 12), 0, 1))
        return el, hh, fd

    def far_arm(self):
        cv, p = self.cv, self.p
        el, hh, fd = self.arm(self.far_sh, p['hF'], 0.72, False)
        self.hF = hh
        if p['icicle'] > 0:
            k = p['icicle']
            d = None
            for dx, ln in ((-0.35, 0.7), (0.0, 1.0), (0.35, 0.7)):
                b = hh + (dx, -0.55 - 0.35 * k)
                di = cv.cone(b, b + (0.0, 0.5 * ln * k + 0.05), 0.11 * k + 0.02, 0.0)
                d = di if d is None else np.minimum(d, di)
            cv.paint(d, self.ICE, R=0.05, line=0.6, union=False, glow=(self.CROWN, 0.05, 0.3 * k))

    def near_arm(self):
        cv, p = self.cv, self.p
        if p['sickle'] > 0:
            self.sickle(np.asarray(p['hN'], float), p['sang'])
        self.arm(self.near_sh, p['hN'], 1.0, True)

    def sickle(self, h, a):
        cv, p = self.cv, self.p
        sd = np.array([np.sin(a), -np.cos(a)])
        perp = np.array([-sd[1], sd[0]])
        bot = h - sd * 0.45
        top = h + sd * 0.55
        haft = cv.cone(bot, top, 0.075, 0.065)
        cv.paint(haft, self.HAFT, R=0.05, line=0.6, pattern=1 - 0.3 * np.clip(np.sin((cv.X * sd[0] + cv.Y * sd[1]) * 40), 0, 1))
        R = 0.95
        cc = top + perp * R
        a0 = np.arctan2(*(top - cc)[::-1])
        pts = arc_pts(cc, R, a0, a0 - 3.6, 16)
        blade = cv.path(pts, 0.17, 0.012)
        cv.paint(blade, self.BLADE, R=0.12, line=0.7, glow=(self.CROWN, 0.04, 0.15 + 0.15 * p['rage']),
                 pattern=1 - 0.18 * np.clip(np.sin(cv.n_streak * 8 + cv.X * 6), 0, 1))
        edge = cv.inter(cv.path(pts, 0.05, 0.005), -(cv.circle(cc, R - 0.04)))
        cv.paint(edge, np.array([1.0, 1.0, 1.0]), R=0.02, line=0, shade=False, rim=False, cast=False, union=False, alpha=0.8)

    def fx(self):
        cv, p = self.cv, self.p
        mo = self.hc + rot(np.array([0.22, 0.3]), p['tilt'])
        if p['inhale'] > 0:
            k = p['inhale']
            for i in range(8):
                a = -0.9 + i * 0.25
                r = 2.4 * (1 - k) + 0.35
                q = mo + r * np.array([np.cos(a), np.sin(a)])
                cv.paint(cv.cone(q, q + (mo - q) * 0.25, 0.05, 0.01), self.ICE, R=0.01, line=0, shade=False, rim=False,
                         cast=False, union=False, alpha=0.75, glow=(self.CROWN, 0.03, 0.25 * k))
        if p['puff'] > 0:
            k = p['puff']
            for i in range(4):
                q = mo + (0.4 + 0.45 * i, 0.08 * np.sin(i * 2) + 0.05 * i)
                cv.paint(cv.circle(q, 0.15 + 0.1 * i), self.ICE, R=0.1, line=0.3, cast=False, union=False,
                         alpha=0.75 * k * (1 - i * 0.18), glow=(self.CROWN, 0.05, 0.2 * k))
        if p['smear'] > 0:
            k = p['smear']
            c = self.waist + (0.6, -2.4)
            band = cv.inter(np.abs(cv.circle(c, 3.0)) - 0.18 * k, -(cv.X - c[0] - 0.2))
            band = cv.inter(band, cv.Y - c[1] - 2.9)
            cv.paint(band, self.ICE, R=0.05, line=0.3, shade=False, cast=False, union=False, alpha=0.7 * k,
                     glow=(self.CROWN, 0.05, 0.3 * k))
        if p['snow'] > 0:
            k = p['snow']
            rng = np.random.default_rng(5)
            for i in range(14):
                x = (rng.random() - 0.5) * 7.0
                y = -0.2 - k * (0.5 + 5.5 * rng.random())
                q = np.array([x + 0.3 * np.sin(k * 6 + i), y])
                s = 0.05 + 0.05 * rng.random()
                cv.paint(cv.poly([q + (0, -s * 2), q + (s, 0), q + (0, s * 2), q + (-s, 0)]), self.ICE, R=0.01, line=0.3,
                         shade=False, rim=False, cast=False, union=False, alpha=0.9, glow=(self.CROWN, 0.03, 0.2))
        if p['mirror'] > 0:
            k = p['mirror']
            q = (np.asarray(p['hN']) + np.asarray(p['hF'])) * 0.5 + (0.9, -0.2)
            dia = cv.poly([q + (0, -0.75 * k), q + (0.38 * k, 0), q + (0, 0.75 * k), q + (-0.38 * k, 0)])
            cv.paint(dia, self.ICE, R=0.15, line=0.7, union=False, alpha=0.85, glow=(self.CROWN, 0.08, 0.45 * k))
            cv.ink(cv.path([q + (-0.1, -0.4 * k), q + (0.1, 0.4 * k)], 0.01), alpha=0.5)
        if p['melt'] > 0:
            k = p['melt']
            pud = cv.ellipse((self.waist[0], -0.1 - p['sink']), 1.4 + 1.6 * k, 0.16 + 0.1 * k)
            cv.paint(pud, hexc('2C3B52'), R=0.1, line=0.6, union=False, cast=False, alpha=min(1.0, k * 1.6),
                     glow=(self.CROWN, 0.03, 0.12))
            rng = np.random.default_rng(9)
            for i in range(9):
                x = self.waist[0] + (rng.random() - 0.5) * 3.4 * (0.6 + k)
                b = np.array([x, -0.15 - p['sink']])
                h = 0.25 + 0.4 * rng.random()
                cv.paint(cv.cone(b, b + ((rng.random() - 0.5) * 0.3, -h), 0.09, 0.0), self.ICE, R=0.03, line=0.5,
                         union=False, cast=False, alpha=min(1.0, k * 2.0))
            for i in range(5):
                q = self.hc + (-0.6 + 0.3 * i, 0.4 + k * (1.2 + 0.4 * i))
                cv.paint(cv.ellipse(q, 0.04, 0.07), self.CROWN, R=0.01, line=0.3, union=False, cast=False,
                         alpha=0.8 * (1 - k))


def morena_anims():
    IDLE_N, IDLE_F = (1.25, -5.1), (-1.0, -5.5)

    def idle_pose(k):
        s, c = np.sin(k * TAU), np.cos(k * TAU)
        return dict(bob=0.08 * s, hem=0.12 * c, veil=0.15 * s, hN=(IDLE_N[0], IDLE_N[1] + 0.06 * s), hF=IDLE_F,
                    sang=0.25 + 0.04 * c, eye=1.0 + 0.15 * s, head=(0.0, 0.03 * s))
    idle = cyc(6, idle_pose)

    def glide(k):
        s = np.sin(k * TAU)
        return dict(bob=0.06 * s, lean=0.2, hem=-0.35 + 0.1 * s, veil=-0.45, hN=(1.5, -5.0), hF=(-1.4, -5.2), sang=0.6)
    move = cyc(6, glide)

    def breath_w(k):
        e = ease(k)
        return dict(lean=-0.28 * e, tilt=-0.35 * e, head=(-0.08 * e, -0.05 * e), swell=e, inhale=float(np.clip(k * 1.3, 0, 1)),
                    hF=tuple(lerp(IDLE_F, (0.5, -7.0), e)), hN=tuple(lerp(IDLE_N, (0.9, -4.9), e)), mouth=0.35 * e,
                    eye=1 + e, sang=0.3, veil=0.2 * e)
    breath_w_ = seq(6, breath_w)

    def breath(k):
        s = np.sin(k * TAU * 2)
        return dict(lean=0.3, tilt=0.15, head=(0.1, 0.05), mouth=1.0, puff=1.0, swell=0.3, hF=(-1.7, -6.4 + 0.1 * s),
                    hN=(1.0, -4.8), sang=0.5, eye=2.0, hem=-0.35, veil=-0.5 + 0.08 * s, smear=0.0)
    breath_ = seq(4, breath)

    def spears_w(k):
        e = ease(k)
        return dict(hF=tuple(lerp(IDLE_F, (-0.3, -10.3), e)), icicle=float(np.clip((k - 0.25) / 0.75, 0, 1)), tilt=-0.3 * e,
                    eye=1 + e, lean=-0.08 * e, hN=tuple(lerp(IDLE_N, (1.4, -4.7), e)), veil=0.1)
    spears_w_ = seq(5, spears_w)

    def spears(k):
        e = ease(min(1, k * 2))
        return dict(hF=tuple(lerp((-0.3, -10.3), (2.6, -5.0), e)), tilt=float(lerp(-0.3, 0.2, e)), lean=0.15 * e,
                    eye=2 - k, hN=(1.4, -4.7), snow=0.4 * (1 - k))
    spears_ = seq(4, spears)

    def scythe_w(k):
        e = ease(k)
        return dict(hN=tuple(lerp(IDLE_N, (-0.7, -9.5), e)), sang=float(lerp(0.25, -2.4, e)), lean=-0.25 * e,
                    hF=tuple(lerp(IDLE_F, (2.0, -6.7), e)), tilt=0.1 * e, eye=1 + e, hem=0.3 * e, veil=0.2 * e)
    scythe_w_ = seq(6, scythe_w)

    def scythe(k):
        e = ease(k)
        a = lerp(-2.4, 2.3, e)
        h = (-0.7 + 3.3 * np.sin(e * np.pi * 0.5) ** 1.2, -9.5 + 6.8 * e)
        return dict(hN=tuple(h), sang=float(a), lean=float(lerp(-0.25, 0.4, e)), hF=(-1.6, -6.0), smear=float(np.sin(np.pi * min(1, k * 1.2))),
                    hem=-0.4 * e, veil=-0.4 * e, eye=2.0)
    scythe_ = seq(4, scythe)

    def dive_w(k):
        e = ease(k)
        f = ease(np.clip((k - 0.55) / 0.45, 0, 1))
        return dict(hN=tuple(lerp(IDLE_N, (0.6, -6.6), e)), hF=tuple(lerp(IDLE_F, (0.1, -6.9), e)), sang=float(lerp(0.25, -0.1, e)),
                    hem=0.25 * np.sin(k * TAU), veil=0.35 * e, eye=1 + e, tilt=0.35 * e, rot=-45 * f, pivot=(0.0, -5.5))
    dive_w_ = seq(6, dive_w)

    def dive(k):
        return dict(hN=(1.0, -9.6), hF=(-0.2, -9.4), sang=0.15, lean=0.15, veil=-1.1, hem=-0.6, eye=2.0, smear=0.0,
                    rot=-105 - 5 * np.sin(k * TAU), pivot=(0.0, -5.5), dx=0.9, dy=0.6, tilt=-0.15)
    dive_ = seq(3, dive)

    def stuck(k):
        s = np.sin(k * TAU)
        return dict(lean=0.65 + 0.05 * s, hN=(2.5 + 0.1 * s, -1.3), hF=(2.1 + 0.1 * s, -1.6), sang=2.75 + 0.06 * s,
                    tilt=0.35, head=(0.15, 0.25), eye=0.7, mouth=0.3 + 0.2 * s, hem=0.2 * s, veil=0.3, bob=0.15)
    stuck_ = cyc(4, stuck)

    def unstick(k):
        e = ease(k)
        return dict(lean=float(lerp(0.65, 0.0, e)), hN=tuple(lerp((2.5, -1.3), IDLE_N, e)), hF=tuple(lerp((2.1, -1.6), IDLE_F, e)),
                    sang=float(lerp(2.75, 0.25, e)), tilt=float(0.35 * (1 - e)), head=(0.15 * (1 - e), 0.25 * (1 - e)),
                    snow=0.5 * (1 - k))
    unstick_ = seq(4, unstick)

    def mirror_w(k):
        e = ease(k)
        return dict(hN=tuple(lerp(IDLE_N, (2.4, -6.6), e)), hF=tuple(lerp(IDLE_F, (2.1, -7.4), e)), sang=float(lerp(0.25, -0.9, e)),
                    mirror=e, eye=1 + 1.3 * e, lean=0.1 * e, veil=0.3 * e)
    mirror_w_ = seq(6, mirror_w)

    def summon_w(k):
        e = ease(k)
        return dict(hN=tuple(lerp(IDLE_N, (2.6, -4.0), e)), hF=tuple(lerp(IDLE_F, (-2.6, -4.2), e)), snow=e, eye=1 + e,
                    tilt=-0.15 * e, hem=0.2 * np.sin(k * TAU), sang=float(lerp(0.25, 0.9, e)))
    summon_w_ = seq(6, summon_w)

    def summon(k):
        return dict(hN=(2.6, -5.4 - k), hF=(-2.6, -5.6 - k), snow=1.0 + k * 0.4, eye=2 - k, sang=0.9)
    summon_ = seq(3, summon)

    def roar(k):
        e = ease(min(1, k * 1.6))
        return dict(hN=tuple(lerp(IDLE_N, (2.9, -8.4), e)), hF=tuple(lerp(IDLE_F, (-2.7, -8.4), e)), tilt=-0.45 * e,
                    head=(-0.1 * e, -0.1 * e), mouth=e, eye=1 + 1.5 * e, rage=float(ease(min(1, k * 1.4))),
                    snow=float(k), sang=float(lerp(0.25, -0.5, e)), veil=0.4 * np.sin(k * TAU * 2))
    roar_ = seq(8, roar)

    def hurt(k):
        s = np.sin(k * np.pi)
        return dict(lean=-0.3 * s, tilt=-0.35 * s, head=(-0.15 * s, 0.0), eye=1 - 0.6 * s, mouth=0.5 * s, hem=0.3 * s,
                    hF=(-1.5, -6.0))
    hurt_ = seq(3, hurt)

    def intro(k):
        # still, eyes shut, the sickle held upright before her; she raises her head,
        # opens her eyes and holds out her hand: «Здравствуй, Ждан»
        a = ease(np.clip((k - 0.2) / 0.35, 0, 1))
        b = ease(np.clip((k - 0.5) / 0.3, 0, 1))
        c = ease(np.clip((k - 0.82) / 0.18, 0, 1))
        return dict(open=float(a), eye=float(a * (1 + 0.6 * b * (1 - c))), tilt=float(lerp(0.45, 0.0, a)),
                    head=tuple(lerp((0.05, 0.15), (0.0, 0.0), a)), hN=tuple(lerp((0.6, -6.3), IDLE_N, c)),
                    sang=float(lerp(0.0, 0.25, c)), hF=tuple(lerp(lerp((0.35, -6.6), (2.9, -6.4), b), IDLE_F, c)),
                    veil=0.15 * np.sin(k * TAU), bob=0.06 * np.sin(k * TAU))
    intro_ = seq(10, intro)

    def die(k):
        # «оттепель»: the rage thaws, the crown drips and melts, she sinks into a
        # puddle of dark water and ice shards
        a = ease(np.clip(k / 0.25, 0, 1))
        m = ease(np.clip((k - 0.25) / 0.6, 0, 1))
        s = float(ease(np.clip((k - 0.35) / 0.65, 0, 1)) * 8.5)
        return dict(lean=-0.25 * a * (1 - m), tilt=float(-0.4 * a * (1 - m) + 0.35 * m), mouth=float(0.6 * a * (1 - m)),
                    eye=float(max(0.0, 1.8 * (1 - k * 1.6))), open=float(max(0.0, 1 - m * 1.4)),
                    rage=float(1 - ease(np.clip(k / 0.4, 0, 1))), melt=float(m), hN=tuple(lerp((1.6, -6.2), (1.2, -4.4), m)),
                    hF=tuple(lerp((-1.6, -6.2), (-0.8, -4.6), m)), sang=float(lerp(0.0, 1.4, m)), sickle=float(k < 0.6),
                    dy=s, clip=0.0, sink=s, veil=0.3 * m)
    death = seq(12, die)
    return dict(idle=(idle, 6, True), move=(move, 8, True), breath_w=(breath_w_, 8, False), breath=(breath_, 10, False),
                spears_w=(spears_w_, 8, False), spears=(spears_, 12, False), scythe_w=(scythe_w_, 8, False),
                scythe=(scythe_, 16, False), dive_w=(dive_w_, 8, False), dive=(dive_, 10, True), stuck=(stuck_, 6, True),
                unstick=(unstick_, 10, False), mirror_w=(mirror_w_, 8, False), summon_w=(summon_w_, 8, False),
                summon=(summon_, 10, False), roar=(roar_, 8, False), hurt=(hurt_, 12, False), intro=(intro_, 6, False),
                death=(death, 4, False))


# boss id -> (class, anims, anims without a phase-2 `_rage` sheet: they carry rage in the poses)
KINDS = {
    'kikimora': (Kikimora, kikimora_anims, ['roar', 'intro', 'death']),
    'likho': (Likho, likho_anims, ['roar', 'intro', 'death']),
    'morena': (Morena, morena_anims, ['roar', 'intro', 'death']),
}

# boss state -> animation (drawn_enemy_visual.gd). k: stat driving the progress of
# the state (1 - t / stat); after: one-shot follow-through when the state ends.
STATES = {
    'kikimora': {'idle': {'anim': 'idle', 'moving': 'move'}, 'throw_w': {'anim': 'throw_w', 'k': 'throw_wind', 'after': 'throw'},
                 'pend_w': {'anim': 'pend_w', 'k': 'pend_wind', 'after': 'pend'},
                 'lunge_w': {'anim': 'lunge_w', 'k': 'lunge_wind'}, 'lunge': {'anim': 'lunge', 'k': 'lunge_time'},
                 'wave_w': {'anim': 'wave_w', 'k': 'wave_wind', 'after': 'wave'},
                 'summon_w': {'anim': 'summon_w', 'k': 'summon_wind', 'after': 'summon'},
                 'roar': {'anim': 'roar', 'k': 'roar_time'}},
    'likho': {'idle': {'anim': 'idle', 'moving': 'move'}, 'leap_w': {'anim': 'leap_w', 'k': 'leap_wind'},
              'leap': {'anim': 'leap', 'after': 'land'}, 'gaze_w': {'anim': 'gaze_w', 'k': 'gaze_wind'},
              'gaze': {'anim': 'gaze'}, 'lunge_w': {'anim': 'lunge_w', 'k': 'lunge_wind'},
              'lunge': {'anim': 'lunge', 'k': 'lunge_time'}, 'woe_w': {'anim': 'woe_w', 'k': 'woe_wind', 'after': 'woe'},
              'summon_w': {'anim': 'summon_w', 'k': 'summon_wind', 'after': 'summon'}, 'roar': {'anim': 'roar', 'k': 'roar_time'}},
    'morena': {'idle': {'anim': 'idle', 'moving': 'move'}, 'breath_w': {'anim': 'breath_w', 'k': 'breath_wind'},
               'breath': {'anim': 'breath'}, 'spears_w': {'anim': 'spears_w', 'k': 'spears_wind', 'after': 'spears'},
               'scythe_w': {'anim': 'scythe_w', 'k': 'scythe_wind'}, 'scythe': {'anim': 'scythe', 'k': 'scythe_time'},
               'dive_w': {'anim': 'dive_w', 'k': 'dive_wind'}, 'dive': {'anim': 'dive'},
               'stuck': {'anim': 'stuck', 'after': 'unstick'}, 'mirror_w': {'anim': 'mirror_w', 'k': 'mirror_wind'},
               'summon_w': {'anim': 'summon_w', 'k': 'summon_wind', 'after': 'summon'}, 'roar': {'anim': 'roar', 'k': 'roar_time'}},
}

"""The people of the Застава (design/narrative/characters.md §2-3), one rig each.

Looks after the character profiles and the art bible (§3 shapes, §4 palette,
§5.2: NPCs are warm, earthy, embroidered, alive). Original folk designs:
    dolya   Пряха Доля: seated spinner, pale scarf with red border, long grey braid,
            a painted distaff, GREY thread (the Недоля clue), spindle spinning
    potap   Потап: upright bear-smith, embroidered collar (he stitched it), leather
            apron, hammer on a stump anvil; looks away when he talks
    sova    Сова: ведунья in a feathered owl hood, amber night eyes, birch-bark notebook
            and quill, the amulet stand (her shop) behind her
    bayun   Кот Баюн: big grey cat on a whitewashed stove-bench, tail sways
    chur    Чур: carved post from the bridge's first beam, crack across the face,
            ember eyes, warm glow under the roots, the Капище fire
    ofenya  Офеня: thin peddler, korob on his back, felt hat, pale (he is dead), tosses a coin
Each has idle (loop, signature gesture), talk (loop) and react (one-shot nod / laugh).
"""
import numpy as np

from base import (Npc, Frame, V, hexc, INK, LINEN, RED, GOLD, GOLDL, EMBER, MOUTH, TAU,
                  lerp, ease, bump, cyc, seq, rot)

LAPTI = hexc('BFA36A')
ONUCHI = hexc('DCCFAE')


def hand(cv, c, r, ang=0.0):
    return cv.ellipse(c, r * 1.15, r * 0.85, rot=ang)


# =====================================================================
class Dolya(Npc):
    BOUNDS = (-2.3, 2.3, -4.6, 0.3)
    PORTRAIT = (0.05, -3.05, 0.95)
    SKIN = hexc('E2C1A0')
    SCARF = hexc('E6DDEB')
    SARAFAN = hexc('7A1E24')
    PONEVA = hexc('3E2A2E')
    WOOD = hexc('8A6240')
    TOW = hexc('BDB5A8')
    THREAD = hexc('A99C86')
    BRAID = hexc('CFCAD2')
    BASE = dict(breath=0.0, tilt=0.0, look=(0.4, 0.7), lid=0.4, mouth=0.0, smile=0.15, happy=False,
                pull=0.0, spin=0.0, braid=1.0, gest=0.0)

    def setup(self):
        p = self.p
        b = p['breath']
        self.hip = V(-0.4, -1.05)
        self.neck = V(-0.02, -2.78 - b * 0.03)
        self.sh_f = V(-0.4, -2.55 - b * 0.03)
        self.sh_n = V(0.06, -2.5 - b * 0.03)
        self.tow = V(1.12, -3.42)
        pull = p['pull']
        self.hand_n = V(0.98 - 0.22 * pull + p['gest'] * 0.1, -3.12 + 0.55 * pull - p['gest'] * 0.25)
        self.hand_f = V(0.28, -1.62)

    def layers(self):
        return [self.bench, self.distaff, self.braid, self.skirt, self.far_arm, self.torso, self.spindle,
                self.thread, self.near_arm, self.head]

    def bench(self):
        cv = self.cv
        d = cv.poly([(-1.5, -1.02), (0.5, -1.02), (0.5, -0.86), (-1.5, -0.86)], 0.03)
        for x in (-1.32, 0.32):
            d = np.minimum(d, cv.poly([(x - 0.08, -0.88), (x + 0.08, -0.88), (x + 0.1, 0), (x - 0.1, 0)], 0.02))
        self.P(d, self.WOOD * 0.85, R=0.08, pattern=self.grain(40, 0.15))

    def distaff(self):
        cv = self.cv
        x = 1.3
        d = cv.poly([(0.85, -0.14), (1.75, -0.14), (1.78, 0), (0.82, 0)], 0.02)
        d = np.minimum(d, cv.seg((x, -0.1), (x, -2.55), 0.07))
        d = np.minimum(d, cv.cone((x, -2.5), (x, -2.72), 0.07, 0.12))
        blade = cv.poly([(x - 0.16, -2.7), (x + 0.16, -2.7), (x + 0.2, -3.75), (x - 0.2, -3.75)], 0.04)
        teeth = None
        for k in range(4):
            tx = x - 0.15 + k * 0.1
            t = cv.circle((tx, -3.8), 0.055)
            teeth = t if teeth is None else np.minimum(teeth, t)
        d = np.minimum(d, cv.smin(blade, teeth, 0.03))
        self.P(d, self.WOOD, R=0.1, pattern=self.grain(34, 0.12))
        # painted rosette and red/gold border on the blade
        self.deco(cv.circle((x, -3.22), 0.12), RED, line=0.4)
        self.deco(cv.circle((x, -3.22), 0.05), GOLDL)
        self.deco(cv.inter(blade, np.abs(cv.Y + 2.85) - 0.025), GOLD)
        self.deco(cv.inter(blade, np.abs(cv.Y + 3.58) - 0.025), GOLD)
        # the tow (кудель) tied to the blade
        tw = cv.smin(cv.ellipse(self.tow, 0.3, 0.42), cv.ellipse(self.tow + (0.08, -0.25), 0.22, 0.26), 0.1)
        fib = 1 - 0.22 * np.clip(np.sin((cv.X * 0.6 + cv.Y * 3) * 30 + cv.n_mid * 10), 0, 1)
        self.P(tw, self.TOW, R=0.2, pattern=fib, line=0.7)
        self.deco(cv.inter(tw, np.abs(cv.Y - self.tow[1] - 0.05) - 0.025), RED)

    def braid(self):
        cv = self.cv
        n = int(5 + 5 * self.p['braid'])
        top = self.neck + (-0.3, -0.25)
        d = None
        for i in range(n):
            c = top + (-0.05 * i - 0.02 * np.sin(i), 0.17 * i)
            e = cv.ellipse(c, 0.085, 0.11, rot=0.5 if i % 2 else -0.5)
            d = e if d is None else np.minimum(d, e)
        self.P(d, self.BRAID, R=0.07, line=0.8)
        end = top + (-0.05 * n, 0.17 * n - 0.03)
        self.P(cv.ellipse(end, 0.06, 0.04), RED, R=0.03, line=0.6, cast=False)

    def skirt(self):
        cv = self.cv
        d = cv.poly([(-0.78, -1.9), (0.08, -1.95), (0.58, -1.22), (0.76, -0.95), (0.8, -0.06),
                     (-0.05, -0.06), (-0.15, -0.8), (-0.95, -0.95)], 0.06)
        check = 1 - 0.18 * ((np.sin(cv.X * 18) > 0.6) | (np.sin(cv.Y * 18) > 0.6))
        self.P(d, self.PONEVA, R=0.3, pattern=check)
        hem = cv.inter(d, np.abs(cv.Y + 0.2) - 0.07)
        self.deco(hem, RED * 0.9)
        self.embroidery(hem, -0.2, period=0.14, size=0.045, col=GOLDL, alpha=0.8)
        foot = cv.ellipse((0.78, -0.07), 0.17, 0.08)
        self.P(foot, LAPTI, R=0.05)

    def far_arm(self):
        cv = self.cv
        d, el, h = self.limb(self.sh_f, self.hand_f, 0.62, 0.6, 0.15, 0.12, (-0.3, 1))
        self.P(d, LINEN * 0.9, R=0.12, dim=0.85)
        self.P(hand(cv, h, 0.09, 0.4), self.SKIN, R=0.06, dim=0.88)

    def torso(self):
        cv = self.cv
        b = self.p['breath']
        ch = V(-0.18, -2.2 - b * 0.02)
        d = cv.smin(cv.ellipse(ch, 0.46, 0.58 + b * 0.02, rot=0.12), cv.ellipse((-0.3, -1.72), 0.5, 0.28), 0.15)
        d = cv.smin(d, cv.ellipse(self.neck + (0, 0.12), 0.16, 0.12), 0.05)
        self.P(d, LINEN, R=0.35)
        # sarafan over the shirt: from under the chest, straps over the shoulders
        sar = cv.inter(d - 0.005, cv.Y - (-2.25 + (cv.X + 0.2) * 0.1))
        straps = cv.inter(d - 0.005, np.minimum(np.abs(cv.X + 0.33 - (cv.Y + 2.2) * 0.25) - 0.06,
                                                np.abs(cv.X - 0.0 - (cv.Y + 2.2) * 0.2) - 0.06))
        self.P(np.minimum(sar, straps), self.SARAFAN, R=0.25, line=0.5, cast=False)
        band = cv.inter(d, np.abs(cv.Y + 2.26 - (cv.X + 0.2) * 0.1) - 0.05)
        self.deco(band, GOLD)
        # embroidered collar (shoulder polik)
        col = cv.inter(d, np.abs(cv.Y - self.neck[1] - 0.2) - 0.05)
        self.embroidery(col, self.neck[1] + 0.2, period=0.12, size=0.04)

    def spindle(self):
        cv = self.cv
        top = self.hand_f + (0.04, -0.05)
        bot = top + (0.02, 0.92)
        d = cv.smin(cv.cone(top, top + (0.01, 0.55), 0.025, 0.07), cv.cone(top + (0.01, 0.55), bot, 0.07, 0.02), 0.03)
        whorl = cv.ellipse(top + (0.015, 0.7), 0.11, 0.05)
        d = np.minimum(d, whorl)
        self.P(d, self.WOOD * 1.15, R=0.04, line=0.6)
        # spin: stripes that slide around the spindle
        ph = self.p['spin'] * TAU
        for k in range(3):
            off = np.sin(ph + k * TAU / 3) * 0.045
            vis = np.cos(ph + k * TAU / 3)
            if vis > -0.2:
                ln = cv.seg(top + (off * 0.5, 0.15), top + (off, 0.62), 0.008)
                cv.ink(cv.inter(ln, d), alpha=0.6 * (vis + 0.2))
        # thread wound on the spindle
        cop = cv.ellipse(top + (0.01, 0.38), 0.075, 0.18)
        self.P(cop, self.THREAD, R=0.05, line=0.5, cast=False,
               pattern=1 - 0.2 * np.clip(np.sin(cv.Y * 90), 0, 1))

    def thread(self):
        cv = self.cv
        a, b, c = self.tow + (-0.12, 0.25), self.hand_n + (0.03, 0.02), self.hand_f + (0.04, -0.06)
        d = np.minimum(cv.seg(a, b, 0.009), cv.seg(b, c, 0.009))
        cv.paint(d, self.THREAD * 1.1, R=0.01, line=0, shade=False, rim=False, cast=False, union=False)

    def near_arm(self):
        cv = self.cv
        d, el, h = self.limb(self.sh_n, self.hand_n, 0.62, 0.6, 0.16, 0.12, (0.2, 1))
        self.P(d, LINEN, R=0.12)
        cuff = cv.inter(d, cv.circle(h, 0.2) - 0.0) if False else None
        sleeve_band = cv.inter(d, cv.circle(h, 0.22))
        self.deco(cv.inter(sleeve_band, -cv.circle(h, 0.13)), RED)
        ang = np.arctan2(h[1] - el[1], h[0] - el[0])
        self.P(hand(cv, h + rot(V(0.05, 0), ang), 0.09, ang), self.SKIN, R=0.06)

    def head(self):
        cv, p = self.cv, self.p
        with Frame(cv, self.neck, p['tilt']):
            hc = V(0.06, -0.42)
            # scarf (back and top), tail behind the neck
            sc = cv.smin(cv.circle(hc + (-0.06, -0.04), 0.45),
                         cv.poly([(-0.42, -0.2), (-0.05, 0.05), (-0.25, 0.42), (-0.62, 0.3)], 0.05), 0.08)
            self.P(sc, self.SCARF, R=0.3, line=1.0)
            face = cv.smin(cv.ellipse(hc + (0.12, 0.06), 0.28, 0.34), cv.ellipse(hc + (0.18, 0.26), 0.18, 0.16), 0.08)
            self.P(face, self.SKIN, R=0.25)
            # scarf edge with red border round the face, knot under the chin
            edge = cv.inter(sc, np.abs(cv.ellipse(hc + (0.12, 0.04), 0.33, 0.39)) - 0.04)
            self.deco(edge, RED, line=0.3)
            self.embroidery(cv.inter(sc, np.abs(cv.ellipse(hc + (0.1, 0.02), 0.39, 0.45)) - 0.02),
                            hc[1] - 0.4, period=0.09, size=0.03, col=RED, alpha=0.5)
            self.P(cv.ellipse(hc + (0.1, 0.44), 0.09, 0.06), RED, R=0.04, line=0.6, cast=False)
            lk = p['look']
            for c, rx in ((hc + (0.25, 0.04), 0.06), (hc + (0.05, 0.03), 0.05)):
                self.eye(c, rx, 0.045, look=lk, lid=p['lid'], skin=self.SKIN * 0.92, happy=p['happy'])
                cv.ink(cv.path([c + (-rx, -0.07), c + (0, -0.09), c + (rx, -0.065)], 0.011), alpha=0.6)
            for c in (hc + (0.25, 0.13), hc + (0.05, 0.12)):
                cv.ink(cv.path([c + (-0.04, 0), c + (0.04, 0.01)], 0.006), alpha=0.35)
            self.P(cv.cone(hc + (0.33, 0.06), hc + (0.38, 0.17), 0.025, 0.04), self.SKIN, R=0.04, line=0.5)
            self.mouth(hc + (0.25, 0.27), 0.065, p['mouth'], p['smile'])

    @staticmethod
    def anims():
        def idle(t):
            ph = t * TAU
            pull = ease(t * 2) if t < 0.5 else ease((1 - t) * 2)
            return dict(breath=np.sin(ph), pull=pull, spin=t * 4, tilt=0.02 * np.sin(ph),
                        lid=1.0 if 0.75 <= t < 0.82 else 0.4, look=(0.55, 0.85))

        def talk(t):
            ph = t * TAU
            return dict(breath=np.sin(ph), pull=0.55, spin=t * 0.5, tilt=-0.08, look=(0.9, 0.1), lid=0.3,
                        mouth=[0.0, 0.6, 0.3, 0.75, 0.15, 0.55, 0.35, 0.0][int(round(t * 8)) % 8],
                        gest=0.35 + 0.25 * np.sin(ph * 2))

        def react(t):
            n = bump(t, 0.1, 0.75)
            return dict(pull=0.5, spin=t * 0.4, tilt=0.18 * n - 0.04, look=(0.8, 0.3), lid=0.4 + 0.6 * n,
                        happy=0.25 < t < 0.7, smile=0.6)
        return {'idle': (cyc(16, idle), 8, True), 'talk': (cyc(8, talk), 8, True),
                'react': (seq(10, react), 10, False)}

    PORTRAIT_POSES = {'calm': dict(look=(0.9, 0.15), lid=0.3, pull=0.4, tilt=-0.05),
                      'warm': dict(look=(0.9, 0.2), lid=0.55, smile=0.8, pull=0.4, tilt=0.03)}


# =====================================================================
class Potap(Npc):
    BOUNDS = (-2.4, 4.4, -7.0, 0.3)
    PORTRAIT = (0.55, -5.0, 1.45)
    FUR = hexc('6E4A30')
    FUR_L = hexc('A27B55')
    SHIRT = hexc('D9CCB0')
    APRON = hexc('4E3424')
    STEEL = hexc('4A4A52')
    STUMP = hexc('7A5232')
    BASE = dict(breath=0.0, tilt=0.0, look=(0.5, 0.1), lid=0.15, mouth=0.0, smile=0.0, happy=False,
                hand=(1.9, -2.55), hdir=0.9, sparks=0.0, glow=1.0, bob=0.0, farh=(2.05, -1.95))

    def setup(self):
        p = self.p
        b = p['breath']
        bob = p['bob']
        self.hip = V(-0.1, -2.0 + bob * 0.3)
        self.neck = V(0.4, -4.85 - b * 0.05 + bob)
        self.sh_n = V(0.8, -4.25 - b * 0.05 + bob)
        self.sh_f = V(-0.55, -4.3 - b * 0.05 + bob)
        self.iron = V(2.78, -1.84)

    def layers(self):
        return [self.anvil, self.far_arm, self.legs, self.torso, self.head, self.hammer_arm, self.sparks]

    def anvil(self):
        cv = self.cv
        st = cv.poly([(2.15, 0), (3.45, 0), (3.35, -1.3), (2.25, -1.3)], 0.06)
        self.P(st, self.STUMP, R=0.25, pattern=self.grain(30, 0.18))
        top = cv.inter(st, cv.Y + 1.2)
        self.deco(top, self.STUMP * 1.25)
        cv.ink(cv.inter(np.abs(cv.ellipse((2.8, -1.26), 0.3, 0.05)) - 0.008, st + 0.02), alpha=0.5)
        a = cv.poly([(2.4, -1.3), (3.2, -1.3), (3.1, -1.5), (3.3, -1.55), (3.35, -1.76), (2.25, -1.76),
                     (2.28, -1.55), (2.5, -1.5)], 0.02)
        a = np.minimum(a, cv.cone((3.3, -1.7), (3.95, -1.68), 0.07, 0.01))
        self.P(a, self.STEEL, R=0.12, hl=1.4)
        g = self.p['glow']
        self.cv.paint(cv.ellipse(self.iron, 0.32, 0.06), np.minimum(EMBER * (0.9 + 0.3 * g), 1), R=0.03, line=0.4,
                      shade=False, rim=False, cast=False, union=False, glow=(EMBER, 0.18, 0.4 * g))

    def far_arm(self):
        cv = self.cv
        d, el, h = self.limb(self.sh_f, self.p['farh'], 1.25, 1.15, 0.36, 0.27, (-0.2, 1))
        self.P(d, self.FUR, R=0.3, dim=0.75, pattern=self.fur())
        self.P(cv.circle(h, 0.27), self.FUR, R=0.2, dim=0.75)
        # tongs from the paw to the iron
        tg = np.minimum(cv.seg(h, self.iron + (-0.18, -0.01), 0.035), cv.seg(h + (0, 0.06), self.iron + (-0.18, 0.04), 0.03))
        self.P(tg, self.STEEL * 0.8, R=0.03, line=0.6, cast=False)

    def legs(self):
        cv = self.cv
        for f, dim, off in (((-0.65, 0.0), 0.78, -0.4), ((0.5, 0.0), 1.0, 0.35)):
            hip = self.hip + (off, 0)
            d, kn, an = self.limb(hip, V(*f) + (0, -0.2), 1.0, 0.85, 0.5, 0.36, (1, -0.1))
            d = cv.smin(d, cv.ellipse(V(*f) + (0.18, -0.13), 0.42, 0.16), 0.1)
            self.P(d, self.FUR, R=0.3, dim=dim, pattern=self.fur())
            for k in range(3):
                self.cv.ink(cv.ellipse(V(*f) + (0.48 + 0.0 * k, -0.08 - 0.07 * k), 0.06, 0.025), alpha=0.6 * dim)

    def torso(self):
        cv, p = self.cv, self.p
        b = p['breath']
        bob = p['bob']
        belly = cv.ellipse((0.05, -3.15 + bob * 0.6), 1.25, 1.45 + b * 0.03)
        chest = cv.ellipse((0.25, -4.15 - b * 0.04 + bob), 1.1, 0.82 + b * 0.03)
        d = cv.smin(belly, chest, 0.3)
        d = cv.smin(d, cv.ellipse(self.neck + (0, 0.15), 0.5, 0.3), 0.15)
        self.P(d, self.SHIRT, R=0.6)
        # embroidered collar (he stitched it himself)
        y0 = self.neck[1] + 0.32
        col = cv.inter(d, np.abs(cv.Y - y0 - (cv.X - 0.4) * 0.12) - 0.09)
        self.deco(col, LINEN * 0.95, line=0.3)
        self.embroidery(col, y0, period=0.17, size=0.06, col=RED)
        # leather apron with burn spots, neck strap
        ap = cv.poly([(-0.25, -4.35 + bob), (1.0, -4.4 + bob), (1.32, -3.0), (1.25, -0.95), (-0.62, -0.9),
                      (-0.72, -3.0)], 0.06)
        burns = 1 - 0.25 * np.clip((cv.n_mid + 0.25) * 4, 0, 1) * np.clip((cv.n_hi + 0.3) * 3, 0, 1)
        self.P(ap, self.APRON, R=0.5, pattern=burns)
        cv.ink(cv.inter(np.abs(cv.Y + 3.3) - 0.012, ap), alpha=0.35)
        # rope belt
        belt = cv.inter(d - 0.01, np.abs(cv.Y + 2.62 - cv.X * 0.06) - 0.07)
        self.deco(belt, hexc('8A6A42'), line=0.4)

    def head(self):
        cv, p = self.cv, self.p
        with Frame(cv, self.neck, p['tilt']):
            hc = V(0.3, -0.62)
            ears = np.minimum(cv.circle(hc + (-0.42, -0.6), 0.24), cv.circle(hc + (0.3, -0.7), 0.22))
            self.P(ears, self.FUR, R=0.15, pattern=self.fur())
            self.deco(np.minimum(cv.circle(hc + (-0.42, -0.6), 0.12), cv.circle(hc + (0.3, -0.7), 0.11)),
                      self.FUR_L * 0.85)
            hd = cv.smin(cv.circle(hc, 0.74), cv.ellipse(hc + (-0.1, 0.35), 0.75, 0.45), 0.2)
            self.P(hd, self.FUR, R=0.55, pattern=self.fur(16, 0.18))
            # cheek fur tufts
            mz = cv.smin(cv.ellipse(hc + (0.62, 0.2), 0.44, 0.3), cv.ellipse(hc + (0.5, 0.42), 0.3, 0.18), 0.1)
            self.P(mz, self.FUR_L, R=0.25)
            self.P(cv.ellipse(hc + (0.98, 0.06), 0.15, 0.1), hexc('2A1E1E'), R=0.06, line=0.5, cast=False, hl=1.6)
            cv.ink(cv.path([hc + (0.96, 0.15), hc + (0.92, 0.3)], 0.012), alpha=0.7)
            lk = p['look']
            for c, rx in ((hc + (0.43, -0.2), 0.09), (hc + (0.1, -0.22), 0.075)):
                self.eye(c, rx, 0.085, look=lk, lid=p['lid'], skin=self.FUR * 1.1, happy=p['happy'], lw=0.024)
                self.P(cv.path([c + (-rx * 1.3, -0.13), c + (0, -0.17), c + (rx * 1.3, -0.12)], 0.035, 0.02),
                       self.FUR * 0.7, R=0.03, line=0.4, cast=False, rim=False)
            m = p['mouth']
            if m > 0.08:
                self.mouth(hc + (0.72, 0.38), 0.2, m, p['smile'], teeth=True)
            else:
                cv.ink(cv.path([hc + (0.92, 0.32), hc + (0.75, 0.36 - p['smile'] * 0.04), hc + (0.55, 0.3)], 0.016))

    def hammer_arm(self):
        cv, p = self.cv, self.p
        h = V(*p['hand'])
        d, el, h = self.limb(self.sh_n, h, 1.2, 1.1, 0.4, 0.3, (-0.3, 1))
        sleeve = cv.cone(self.sh_n, self.sh_n + (el - self.sh_n) * 0.75, 0.44, 0.4)
        self.P(d, self.FUR, R=0.3, pattern=self.fur())
        self.P(sleeve, self.SHIRT, R=0.3, line=0.9)
        self.embroidery(cv.inter(sleeve, np.abs(cv.circle(self.sh_n + (el - self.sh_n) * 0.72, 0.42)) - 0.05),
                        0, period=0.12, size=0.8, col=RED, alpha=0.6)
        a = p['hdir']
        dr = V(np.cos(a), np.sin(a))
        hd = h + dr * 0.95
        hm = cv.seg(h - dr * 0.25, hd, 0.06)
        self.P(hm, hexc('A07A4E'), R=0.04, line=0.8)
        perp = V(-dr[1], dr[0])
        head = cv.poly([hd + perp * 0.28 - dr * 0.15, hd + perp * 0.28 + dr * 0.15,
                        hd - perp * 0.22 + dr * 0.15, hd - perp * 0.22 - dr * 0.15], 0.03)
        self.P(head, self.STEEL, R=0.08, hl=1.4)
        self.P(cv.circle(h, 0.3), self.FUR, R=0.2, pattern=self.fur())
        cv.ink(cv.path([h + (0.05, -0.2), h + (0.2, -0.05)], 0.012), alpha=0.6)

    def sparks(self):
        s = self.p['sparks']
        if s <= 0:
            return
        rng = np.random.default_rng(3)
        for i in range(9):
            a = -np.pi * (0.1 + 0.8 * rng.random())
            sp = 0.5 + rng.random() * 1.0
            c = self.iron + rot(V(sp * s, 0), a) + (0, 0.6 * s * s)
            self.spark(c, 0.035 * (1.2 - s * 0.6), GOLDL, k=1.2 - s * 0.6)

    @staticmethod
    def anims():
        up_h, up_a = V(1.2, -5.0), -1.9
        hit_h, hit_a = V(2.02, -2.42), 0.55

        def idle(t):
            ph = t * TAU
            if t < 0.5:
                k = ease(t / 0.5)
                h, a = lerp(hit_h, up_h, k), hit_a + (up_a - hit_a) * k
            elif t < 0.625:
                k = (t - 0.5) / 0.125
                k = k * k
                h, a = lerp(up_h, hit_h, k), up_a + (hit_a - up_a) * k
            else:
                h, a = hit_h, hit_a
            sp = (t - 0.625) / 0.3 if 0.625 <= t < 0.95 else 0.0
            return dict(hand=tuple(h), hdir=a, sparks=sp, breath=np.sin(ph), glow=1.0 + 0.5 * bump(t, 0.6, 0.9),
                        look=(0.7, 0.9), lid=0.35 if t < 0.85 else 0.6, mouth=0.0)

        def talk(t):
            ph = t * TAU
            return dict(hand=(1.95, -2.5 + 0.06 * np.sin(ph * 2)), hdir=0.9, breath=np.sin(ph),
                        look=(-0.7, 0.8), lid=0.35, tilt=0.06,
                        mouth=[0.0, 0.5, 0.2, 0.65, 0.1, 0.5, 0.25, 0.0][int(round(t * 8)) % 8])

        def react(t):
            n = bump(t, 0.05, 0.95)
            return dict(hand=(1.95, -2.5), hdir=0.9, tilt=-0.2 * n, mouth=0.75 * n, smile=0.8, happy=n > 0.3,
                        bob=0.05 * abs(np.sin(t * TAU * 3)) * n)
        return {'idle': (cyc(16, idle), 10, True), 'talk': (cyc(8, talk), 8, True),
                'react': (seq(12, react), 12, False)}

    PORTRAIT_POSES = {'calm': dict(hand=(1.95, -2.5), hdir=0.9, look=(-0.4, 0.6), lid=0.25, tilt=0.04),
                      'warm': dict(hand=(1.95, -2.5), hdir=0.9, tilt=-0.12, mouth=0.6, smile=0.8, happy=True)}


# =====================================================================
class Sova(Npc):
    BOUNDS = (-2.0, 2.8, -5.2, 0.3)
    PORTRAIT = (0.1, -3.55, 1.0)
    SKIN = hexc('E6CDB4')
    DRESS = hexc('6B5A7A')
    FEATHER = hexc('8C7A66')
    FEATHER_L = hexc('C9B9A0')
    IRIS = hexc('F0A830')
    BARK = hexc('D9C7A0')
    BASE = dict(breath=0.0, tilt=0.0, look=(0.5, 0.4), lid=0.0, mouth=0.0, smile=0.1, happy=False,
                write=0.0, quill_up=0.0, swing=0.0, puff=0.0)

    def setup(self):
        p = self.p
        b = p['breath']
        self.neck = V(0.05, -3.35 - b * 0.03)
        self.sh_n = V(0.25, -3.1 - b * 0.03)
        self.sh_f = V(-0.32, -3.12 - b * 0.03)
        self.book = V(0.62, -2.62)
        qu = p['quill_up']
        self.hand_n = lerp(V(0.55 + 0.12 * np.sin(p['write'] * TAU * 2), -2.78 + 0.03 * np.sin(p['write'] * TAU * 5)),
                           V(0.78, -3.45), qu)
        self.hand_f = V(0.42, -2.52)

    def layers(self):
        return [self.stand, self.dress, self.far_arm, self.torso, self.book_, self.head, self.near_arm]

    def stand(self):
        cv, p = self.cv, self.p
        st = cv.path([(1.7, 0.0), (1.78, -1.4), (1.68, -2.8), (1.82, -4.05)], 0.07, 0.05)
        st = np.minimum(st, cv.seg((1.22, -3.75), (2.4, -3.85), 0.04))
        self.P(st, hexc('5B3A24'), R=0.06, pattern=self.grain(40, 0.2))
        cols = [GOLDL, hexc('4F8FE0'), hexc('6FBF5A')]
        for k, (x, ln) in enumerate(((1.35, 0.7), (1.95, 0.95), (2.3, 0.6))):
            sw = np.sin(p['swing'] * TAU + k * 1.7) * 0.07
            top = V(x, -3.8 - (x - 1.22) * 0.08)
            c = top + (sw, ln)
            cv.ink(cv.seg(top, c, 0.008), alpha=0.8)
            self.P(cv.circle(c + (0, 0.08), 0.1), hexc('3A2A1E'), R=0.05, line=0.6, cast=False)
            cv.paint(cv.circle(c + (0, 0.08), 0.065), cols[k], R=0.04, line=0, shade=False, rim=False,
                     cast=False, union=False, glow=(cols[k], 0.06, 0.3))

    def dress(self):
        cv = self.cv
        d = cv.poly([(-0.48, -2.35), (0.42, -2.35), (0.95, -0.06), (-1.0, -0.06)], 0.06)
        folds = 1 - 0.14 * np.clip(np.sin(cv.X * 9 + cv.Y * 0.8 + cv.n_mid * 3), 0, 1)
        self.P(d, self.DRESS, R=0.5, pattern=folds)
        hem = cv.inter(d, np.abs(cv.Y + 0.22) - 0.08)
        self.deco(hem, hexc('3A2E44'))
        self.embroidery(hem, -0.22, period=0.18, size=0.05, col=GOLDL, alpha=0.7)
        self.P(cv.ellipse((0.88, -0.06), 0.16, 0.07), hexc('4A3A2E'), R=0.05)

    def far_arm(self):
        cv = self.cv
        d, el, h = self.limb(self.sh_f, self.hand_f, 0.62, 0.58, 0.14, 0.11, (-0.4, 1))
        self.P(d, self.DRESS, R=0.12, dim=0.8)
        self.P(hand(cv, h, 0.08), self.SKIN, R=0.05, dim=0.85)

    def torso(self):
        cv, p = self.cv, self.p
        b = p['breath']
        d = cv.smin(cv.ellipse((-0.05, -2.78 - b * 0.02), 0.45, 0.62), cv.ellipse((0.0, -2.35), 0.48, 0.2), 0.1)
        self.P(d, self.DRESS, R=0.4)
        # feathered shawl over the shoulders: rows of scallop feathers
        k = 1 + 0.06 * p['puff']
        sh = cv.smin(cv.ellipse((-0.08, -2.98), 0.68 * k, 0.5 * k), cv.ellipse((-0.05, -3.3), 0.42, 0.2), 0.1)
        sh = sh + 0.035 * np.abs(np.sin(cv.X * 14)) * (cv.Y > -2.8)
        v = cv.Y * 9.0
        row = np.floor(v)
        u = cv.X * 9.0 + (row % 2) * 0.5
        fu, fv = u - np.floor(u) - 0.5, v - row
        scal = np.clip((np.hypot(fu, fv * 0.9) - 0.42) * 12, 0, 1)
        self.P(sh, self.FEATHER, R=0.35, pattern=1 - 0.28 * scal)
        flecks = cv.inter(cv.ellipse((0, 0), 1e3, 1e3), 0.03 - np.hypot(fu, fv - 0.55) * 0.3)
        self.cv.flat(cv.inter(flecks, sh + 0.02), self.FEATHER_L, alpha=0.7)
        # bead string with a little owl-feather charm
        cv.ink(cv.path([self.neck + (-0.2, 0.2), self.neck + (0.08, 0.42), self.neck + (0.32, 0.25)], 0.01), alpha=0.7)
        self.P(cv.circle(self.neck + (0.08, 0.45), 0.05), GOLD, R=0.03, line=0.5, cast=False)

    def book_(self):
        cv = self.cv
        b = self.book
        d = cv.poly([b + (-0.3, -0.2), b + (0.28, -0.28), b + (0.32, 0.16), b + (-0.26, 0.22)], 0.02)
        self.P(d, self.BARK, R=0.08, pattern=1 - 0.15 * np.clip(np.sin(cv.Y * 40 + cv.X * 4), 0, 1))
        for k in range(4):
            y = -0.1 + k * 0.08
            cv.ink(cv.inter(cv.seg(b + (-0.18, y + 0.02), b + (0.18 * (0.6 + 0.4 * (k % 2)), y - 0.03), 0.006),
                            d), alpha=0.55)
        self.deco(cv.inter(d, np.abs(cv.X - b[0] + 0.0) - 0.012), hexc('6B4428'))

    def near_arm(self):
        cv = self.cv
        d, el, h = self.limb(self.sh_n, self.hand_n, 0.6, 0.56, 0.14, 0.11, (0.3, 1))
        self.P(d, self.DRESS * 1.05, R=0.12)
        cuff = cv.inter(d, cv.circle(el, 0.16))
        self.P(cuff, self.FEATHER, R=0.08, line=0.6, cast=False)
        self.P(hand(cv, h, 0.08), self.SKIN, R=0.05)
        # the quill (an owl feather)
        tip = h + (-0.12, -0.62)
        q = cv.smin(cv.cone(h + (0.02, 0.08), h + (-0.04, -0.22), 0.012, 0.05), cv.cone(h + (-0.04, -0.22), tip, 0.06, 0.012), 0.03)
        self.P(q, hexc('EDE6F2'), R=0.04, line=0.6, cast=False)
        cv.ink(cv.inter(cv.seg(h + (0.02, 0.08), tip, 0.006), q), alpha=0.6)
        for k in range(4):
            c = h + (-0.05 - k * 0.02, -0.25 - k * 0.09)
            cv.ink(cv.inter(cv.seg(c, c + (0.06, -0.03), 0.004), q + 0.01), alpha=0.4)

    def head(self):
        cv, p = self.cv, self.p
        with Frame(cv, self.neck, p['tilt']):
            hc = V(0.08, -0.38)
            k = 1 + 0.05 * p['puff']
            hood = cv.smin(cv.circle(hc + (-0.06, -0.02), 0.46 * k), cv.ellipse((-0.3, 0.15), 0.32, 0.3), 0.12)
            for sx, tip in ((-0.32, (-0.46, -0.6)), (0.1, (0.14, -0.62))):
                for j, dx in enumerate((-0.05, 0.0, 0.05)):
                    hood = cv.smin(hood, cv.cone(hc + (sx + dx, -0.3), hc + tip + (dx * 1.6, j * 0.03), 0.05, 0.012), 0.03)
            v = cv.Y * 11.0
            row = np.floor(v)
            u = cv.X * 11.0 + (row % 2) * 0.5
            scal = np.clip((np.hypot(u - np.floor(u) - 0.5, (v - row) * 0.9) - 0.42) * 12, 0, 1)
            self.P(hood, self.FEATHER, R=0.35, pattern=1 - 0.25 * scal)
            # facial disc: pale heart-shaped face like an owl's
            face = cv.smin(cv.ellipse(hc + (0.12, 0.04), 0.3, 0.33), cv.ellipse(hc + (0.16, 0.24), 0.17, 0.15), 0.08)
            self.P(cv.smin(cv.ellipse(hc + (-0.12, 0.12), 0.12, 0.26), cv.ellipse(hc + (0.3, 0.1), 0.06, 0.2), 0.02),
                   hexc('3A2A2A'), R=0.08, line=0.6, cast=False)
            self.P(face, self.SKIN, R=0.25)
            disc = cv.inter(face, np.abs(cv.ellipse(hc + (0.12, 0.03), 0.31, 0.34)) - 0.03)
            self.deco(disc, self.FEATHER_L, line=0.2)
            lk = p['look']
            for c, r in ((hc + (0.26, 0.0), 0.085), (hc + (0.03, -0.01), 0.075)):
                self.P(cv.circle(c, r * 1.35), self.SKIN * 0.86, R=0.05, line=0, cast=False, rim=False, union=False)
                self.eye(c, r, r, look=lk, lid=p['lid'], skin=self.SKIN * 0.9, iris=self.IRIS, glow=1.0,
                         happy=p['happy'])
            nose = cv.cone(hc + (0.25, 0.06), hc + (0.3, 0.17), 0.022, 0.035)
            self.P(nose, self.SKIN, R=0.03, line=0.5, cast=False)
            self.mouth(hc + (0.22, 0.27), 0.05, p['mouth'], p['smile'])

    @staticmethod
    def anims():
        def idle(t):
            ph = t * TAU
            turn = bump(t, 0.35, 0.6)
            lid = max(bump(t, 0.78, 0.92) * 1.2, 0)
            return dict(breath=np.sin(ph), write=t, swing=t, tilt=-0.32 * turn + 0.02 * np.sin(ph),
                        look=(0.5 - 1.2 * turn, 0.9 - 0.9 * turn), lid=min(lid, 1.0))

        def talk(t):
            ph = t * TAU
            return dict(breath=np.sin(ph), quill_up=0.8 + 0.15 * np.sin(ph * 2), swing=t * 0.5, tilt=-0.12,
                        look=(0.9, 0.0), mouth=[0.0, 0.5, 0.2, 0.6, 0.1, 0.45, 0.3, 0.0][int(round(t * 8)) % 8])

        def react(t):
            lid = max(bump(t, 0.05, 0.3), bump(t, 0.35, 0.6)) * 1.1
            return dict(quill_up=0.4, puff=bump(t, 0.0, 0.8), tilt=0.12 * bump(t, 0.2, 0.9), lid=min(lid, 1.0),
                        look=(0.9, 0.1), smile=0.5, swing=t * 0.3)
        return {'idle': (cyc(16, idle), 8, True), 'talk': (cyc(8, talk), 8, True),
                'react': (seq(10, react), 10, False)}

    PORTRAIT_POSES = {'calm': dict(quill_up=0.7, look=(0.9, 0.0), tilt=-0.08),
                      'warm': dict(quill_up=0.5, look=(0.9, 0.0), tilt=0.1, smile=0.7, lid=0.3)}


# =====================================================================
class Bayun(Npc):
    BOUNDS = (-2.3, 2.1, -4.3, 0.3)
    PORTRAIT = (0.35, -3.0, 0.95)
    FURC = hexc('6A6474')
    FUR_D = hexc('46404E')
    FUR_L = hexc('A59EAC')
    EYE = hexc('FFC94A')
    STOVE = hexc('CFC6B4')
    BASE = dict(breath=0.0, tilt=0.0, look=(0.4, 0.2), lid=0.3, mouth=0.0, smile=0.3, happy=False,
                tail=0.0, ear=0.0, paw=0.0, fire=0.0)

    def setup(self):
        b = self.p['breath']
        self.neck = V(0.3, -2.95 - b * 0.03)

    def layers(self):
        return [self.stove, self.tail, self.body, self.head, self.paws]

    def stove(self):
        cv = self.cv
        d = cv.poly([(-1.55, 0), (1.35, 0), (1.32, -1.15), (-1.52, -1.15)], 0.12)
        soot = 1 - 0.18 * np.clip((cv.n_lo + 0.1) * 3, 0, 1) - 0.06 * np.clip(cv.n_hi * 4, 0, 1)
        self.P(d, self.STOVE, R=0.35, pattern=soot)
        rim = cv.inter(d, np.abs(cv.Y + 1.05) - 0.07)
        self.deco(rim, self.STOVE * 0.78, line=0.3)
        self.embroidery(cv.inter(d, np.abs(cv.Y + 0.85) - 0.05), -0.85, period=0.22, size=0.05,
                        col=RED * 0.95, alpha=0.75)
        mouth = cv.inter(cv.ellipse((0.65, -0.32), 0.34, 0.34), cv.Y + 0.06)
        self.P(mouth, hexc('2A1A14'), R=0.1, line=0.8, cast=False, union=False)
        f = self.p['fire']
        for k, x in enumerate((0.52, 0.66, 0.8)):
            self.flame((x, -0.08), 0.22 + 0.08 * np.sin(f * TAU + k * 2), 0.07, 0.03 * np.sin(f * TAU * 2 + k))

    def tail(self):
        cv, p = self.cv, self.p
        s = p['tail']
        pts = [(-1.0, -1.45), (-1.45, -1.25), (-1.62 + s * 0.15, -0.8), (-1.5 + s * 0.35, -0.42),
               (-1.15 + s * 0.55, -0.3 - s * 0.15)]
        d = cv.path(pts, 0.16, 0.12)
        rings = 1 - 0.25 * np.clip(np.sin((cv.X * 0.8 - cv.Y) * 12), 0.2, 1)
        self.P(d, self.FURC, R=0.15, pattern=rings)

    def body(self):
        cv, p = self.cv, self.p
        b = p['breath']
        d = cv.smin(cv.ellipse((-0.45, -1.62), 0.85, 0.52), cv.ellipse((0.12, -2.3 - b * 0.02), 0.6, 0.78 + b * 0.02, rot=-0.25), 0.25)
        stripes = 1 - 0.25 * np.clip(np.sin((cv.X * 1.4 + cv.Y * 0.6) * 9 + cv.n_mid * 4), 0.3, 1)
        self.P(d, self.FURC, R=0.5, pattern=stripes)
        chest = cv.inter(d - 0.03, cv.ellipse((0.45, -2.25), 0.3, 0.6))
        self.P(chest, self.FUR_L, R=0.25, line=0, cast=False, union=False, pattern=self.fur(18, 0.2))
        # a red folk ribbon collar
        col = cv.inter(cv.ellipse(self.neck + (0.05, 0.12), 0.48, 0.2), -(cv.ellipse(self.neck + (0.05, 0.04), 0.46, 0.15)))
        self.P(col, RED, R=0.05, line=0.6, cast=False)
        self.P(cv.circle(self.neck + (0.35, 0.3), 0.07), GOLDL, R=0.04, line=0.5, cast=False)

    def paws(self):
        cv, p = self.cv, self.p
        for k, (x, dim) in enumerate(((0.3, 0.85), (0.62, 1.0))):
            lift = p['paw'] if k == 1 else 0.0
            top = V(x - 0.05, -2.05)
            end = V(x + 0.05 + lift * 0.35, -1.24 - lift * 0.9)
            d = cv.cone(top, end, 0.15, 0.13)
            d = cv.smin(d, cv.ellipse(end + (0.04, -0.02), 0.17, 0.11), 0.05)
            self.P(d, self.FURC if k == 0 else self.FUR_L * 0.92, R=0.12, dim=dim)
            for j in range(2):
                cv.ink(cv.seg(end + (0.0 + j * 0.08, 0.0), end + (0.04 + j * 0.08, 0.09), 0.008), alpha=0.6 * dim)

    def head(self):
        cv, p = self.cv, self.p
        with Frame(cv, self.neck, p['tilt']):
            hc = V(0.12, -0.35)
            e = p['ear']
            ears = np.minimum(cv.poly([hc + (-0.5, -0.12), hc + (-0.38, -0.72 + e * 0.12), hc + (-0.08, -0.36)], 0.04),
                              cv.poly([hc + (0.05, -0.38), hc + (0.36, -0.7), hc + (0.45, -0.12)], 0.04))
            self.P(ears, self.FURC, R=0.1)
            self.deco(np.minimum(cv.poly([hc + (-0.42, -0.2), hc + (-0.36, -0.58 + e * 0.12), hc + (-0.16, -0.36)]),
                                 cv.poly([hc + (0.1, -0.38), hc + (0.32, -0.6), hc + (0.38, -0.2)])), hexc('B8889A'))
            hd = cv.smin(cv.ellipse(hc, 0.56, 0.46), cv.ellipse(hc + (0.02, 0.18), 0.66, 0.3), 0.15)
            self.P(hd, self.FURC, R=0.4, pattern=1 - 0.2 * np.clip(np.sin((cv.X * 0.3 + cv.Y) * 30), 0.4, 1))
            mz = cv.smin(cv.ellipse(hc + (0.28, 0.2), 0.24, 0.17), cv.ellipse(hc + (0.1, 0.22), 0.2, 0.15), 0.06)
            self.P(mz, self.FUR_L, R=0.15, line=0.3, cast=False)
            lk = p['look']
            for c, r in ((hc + (0.3, -0.06), 0.11), (hc + (-0.02, -0.07), 0.095)):
                self.eye(c, r, r * 0.85, look=lk, lid=p['lid'], skin=self.FURC * 0.85, iris=self.EYE, glow=0.6,
                         slit=True, happy=p['happy'], lw=0.02)
            nose = cv.poly([hc + (0.3, 0.1), hc + (0.4, 0.1), hc + (0.36, 0.16)], 0.015)
            self.P(nose, hexc('8A4A58'), R=0.03, line=0.5, cast=False)
            m = p['mouth']
            if m > 0.08:
                self.mouth(hc + (0.32, 0.28), 0.1, m, p['smile'], col=hexc('5A1A24'), teeth=True)
            else:
                mc = hc + (0.36, 0.2)
                cv.ink(cv.path([mc + (-0.1, 0.05), mc + (-0.05, 0.08), mc + (0, 0.02), mc + (0.05, 0.07), mc + (0.09, 0.03)], 0.011))
            for k in range(3):
                a = -0.25 + k * 0.2
                o = hc + (0.38, 0.2)
                cv.ink(cv.path([o + (0.02, 0.0 + k * 0.03), o + rot(V(0.5, 0), a) + (0, k * 0.03)], 0.006, 0.003), alpha=0.75)

    @staticmethod
    def anims():
        def idle(t):
            ph = t * TAU
            blink = bump(t, 0.68, 0.86)
            return dict(breath=np.sin(ph), tail=np.sin(ph) * 0.9, ear=bump(t, 0.25, 0.36), fire=t * 2,
                        lid=0.3 + 0.7 * blink, tilt=0.03 * np.sin(ph), look=(0.3, 0.3))

        def talk(t):
            ph = t * TAU
            return dict(breath=np.sin(ph), tail=np.sin(ph) * 0.5, paw=0.6 + 0.2 * np.sin(ph * 2), fire=t * 2,
                        lid=0.0, look=(0.8, 0.0), tilt=-0.06,
                        mouth=[0.0, 0.55, 0.25, 0.7, 0.1, 0.5, 0.3, 0.0][int(round(t * 8)) % 8], smile=0.2)

        def react(t):
            n = bump(t, 0.05, 0.95)
            return dict(tail=-0.8 * n + 0.6 * np.sin(t * TAU * 2) * n, tilt=0.18 * n, happy=n > 0.25, smile=1.0,
                        fire=t, ear=0.5 * n)
        return {'idle': (cyc(16, idle), 8, True), 'talk': (cyc(8, talk), 8, True),
                'react': (seq(10, react), 10, False)}

    PORTRAIT_POSES = {'calm': dict(lid=0.25, look=(0.8, 0.1), tilt=-0.04),
                      'warm': dict(happy=True, smile=1.0, tilt=0.12)}


# =====================================================================
class Chur(Npc):
    BOUNDS = (-1.9, 2.9, -8.0, 0.35)
    PORTRAIT = (0.0, -6.75, 1.0)
    FLIP = False
    WOOD = hexc('7A5232')
    WOOD_L = hexc('9A6E44')
    STONE = hexc('6A6460')
    BASE = dict(tilt=0.0, eyes=1.0, mouth=0.0, glow=1.0, fire=0.0, motes=0.0, dust=0.0)

    def layers(self):
        return [self.roots, self.shaft, self.head, self.fire_bowl, self.motes]

    def roots(self):
        cv = self.cv
        d = None
        for sx, ex, ey in ((-1, -1.45, 0.05), (-1, -0.95, 0.12), (1, 1.0, 0.1), (1, 1.4, 0.04), (-1, -0.3, 0.16)):
            st = V(0.35 * np.sign(ex), -0.55)
            di = cv.path([st, st * 0.5 + (ex * 0.6, -0.2), (ex, ey)], 0.2, 0.05)
            d = di if d is None else np.minimum(d, di)
        self.P(d, self.WOOD * 0.9, R=0.15, pattern=self.grain(30, 0.15))
        g = self.p['glow']
        for k, x in enumerate((-1.15, -0.62, 0.55, 1.2)):
            self.spark((x, 0.02), 0.05 + 0.02 * np.sin(self.p['fire'] * TAU + k), EMBER, k=0.6 * g)

    def shaft(self):
        cv = self.cv
        d = cv.poly([(-0.52, -6.05), (0.52, -6.05), (0.62, 0.0), (-0.62, 0.0)], 0.06)
        self.P(d, self.WOOD, R=0.5, pattern=1 - 0.2 * np.clip(np.sin(cv.X * 34 + cv.n_mid * 7 + np.sin(cv.Y * 2) * 0.6), 0, 1))
        for y in (-1.4, -3.1):
            band = cv.inter(d - 0.0, np.abs(cv.Y - y) - 0.14)
            self.P(band + 0.0, self.WOOD_L, R=0.08, line=0.6, cast=False, union=False)
            self.embroidery(cv.inter(band, np.abs(cv.Y - y) - 0.08), y, period=0.2, size=0.07, col=GOLD, alpha=0.9)
        # carved sun ring (коло) with six dots
        c = V(0.0, -4.5)
        ring = np.abs(cv.circle(c, 0.3)) - 0.045
        cv.paint(ring, self.WOOD * 0.6, R=0.03, line=0.4, shade=False, rim=False, cast=False, union=False)
        for k in range(6):
            cv.flat(cv.circle(c + rot(V(0.18, 0), k * TAU / 6), 0.035), self.WOOD * 0.55)
        cv.flat(cv.circle(c, 0.06), GOLD)
        cv.ink(cv.path([(-0.2, -5.4), (-0.25, -4.9), (-0.18, -4.0)], 0.01), alpha=0.35)

    def head(self):
        cv, p = self.cv, self.p
        with Frame(cv, (0.0, -6.0), p['tilt']):
            blk = cv.poly([(-0.72, -1.5), (0.72, -1.5), (0.66, 0.05), (-0.66, 0.05)], 0.1)
            self.P(blk, self.WOOD, R=0.5, pattern=1 - 0.18 * np.clip(np.sin(cv.X * 30 + cv.n_mid * 7), 0, 1))
            cap = cv.smin(cv.ellipse((0, -1.6), 0.8, 0.42), cv.circle((0, -2.0), 0.12), 0.08)
            self.P(cap, self.WOOD_L, R=0.35, pattern=self.grain(30, 0.12))
            rim = cv.inter(cv.poly([(-0.85, -1.62), (0.85, -1.62), (0.85, -1.42), (-0.85, -1.42)], 0.03), 1.0 + 0 * cv.X)
            self.P(rim, self.WOOD * 0.85, R=0.06, line=0.8)
            self.embroidery(cv.inter(rim, np.abs(cv.Y + 1.52) - 0.07), -1.52, period=0.17, size=0.06, col=GOLD)
            brow = cv.poly([(-0.6, -1.08), (0.6, -1.08), (0.5, -0.9), (0.05, -0.95), (-0.05, -0.95), (-0.5, -0.9)], 0.04)
            self.P(brow, self.WOOD_L, R=0.08, line=0.8, cast=True, union=False)
            e = p['eyes']
            for sx in (-1, 1):
                c = V(0.28 * sx, -0.8)
                cv.paint(cv.ellipse(c, 0.15, 0.09), hexc('1E140E'), R=0.03, line=0.5, shade=False, rim=False,
                         cast=False, union=False)
                cv.paint(cv.circle(c + (0, 0.01), 0.04 + 0.015 * e), np.minimum(GOLDL * (0.8 + 0.3 * e), 1), R=0.02,
                         line=0, shade=False, rim=False, cast=False, union=False, glow=(EMBER, 0.06, 0.25 * e))
            nose = cv.poly([(-0.06, -0.9), (0.06, -0.9), (0.13, -0.42), (-0.13, -0.42)], 0.03)
            self.P(nose, self.WOOD_L, R=0.08, line=0.7, union=False)
            m = p['mouth']
            cv.paint(cv.ellipse((0, -0.18 + m * 0.03), 0.22, 0.035 + 0.08 * m), hexc('1E140E'), R=0.03, line=0.5,
                     shade=False, rim=False, cast=False, union=False,
                     glow=(EMBER, 0.04, 0.2 * m) if m > 0.1 else None)
            for sx in (-1, 1):
                mu = cv.path([(0.05 * sx, -0.36), (0.35 * sx, -0.33), (0.55 * sx, -0.18), (0.58 * sx, -0.02)], 0.06, 0.025)
                self.P(mu, self.WOOD_L * 0.92, R=0.05, line=0.6, union=False)
            for k in range(4):
                x = -0.24 + k * 0.16
                cv.ink(cv.seg((x, -0.05), (x * 1.1, 0.04), 0.008), alpha=0.4)
            cv.ink(cv.path([(-0.66, -1.25), (-0.38, -1.02), (-0.2, -0.95), (-0.05, -0.62), (0.18, -0.48),
                            (0.32, -0.2), (0.5, -0.05)], 0.022, 0.012), alpha=0.9)
            d = p['dust']
            if d > 0:
                for k in range(5):
                    cv.flat(cv.circle((-0.5 + k * 0.25, 0.1 + d * (0.3 + 0.15 * k)), 0.025), self.WOOD_L, alpha=1 - d)

    def fire_bowl(self):
        cv, p = self.cv, self.p
        f = p['fire']
        c = V(1.95, -0.1)
        pit = cv.ellipse(c + (0, -0.05), 0.62, 0.16)
        self.P(pit, hexc('2A1A14'), R=0.05, line=0.6, cast=False)
        for k, sw in enumerate((-0.04, 0.05, -0.02, 0.03)):
            x = c[0] - 0.36 + k * 0.24
            h = 0.55 + 0.25 * np.sin(f * TAU + k * 1.9) + (0.15 if k in (1, 2) else 0.0)
            self.flame((x, c[1] - 0.04), h, 0.1, sw + 0.05 * np.sin(f * TAU * 2 + k))
        st = None
        for k in range(7):
            sc = c + (-0.6 + k * 0.2, 0.02 + 0.03 * np.sin(k * 2.3))
            s = cv.ellipse(sc, 0.12, 0.09)
            st = s if st is None else np.minimum(st, s)
        self.P(st, self.STONE, R=0.08)

    def motes(self):
        m = self.p['motes']
        for k in range(3):
            ph = (m + k / 3) % 1.0
            c = V(1.95 + 0.25 * np.sin((ph + k) * 5), -0.8 - ph * 2.4)
            self.spark(c, 0.03 * (1 - ph * 0.6), EMBER, k=1 - ph)

    @staticmethod
    def anims():
        def idle(t):
            return dict(fire=t * 2, motes=t, eyes=0.8 + 0.25 * np.sin(t * TAU), glow=0.8 + 0.3 * np.sin(t * TAU))

        def talk(t):
            return dict(fire=t * 2, motes=t, eyes=1.4, glow=1.2,
                        mouth=[0.0, 0.6, 0.3, 0.8, 0.15, 0.55, 0.35, 0.0][int(round(t * 8)) % 8])

        def react(t):
            n = bump(t, 0.05, 0.95)
            return dict(fire=t, motes=t * 0.5, eyes=1.0 + 0.4 * n, tilt=0.09 * n, dust=t if t > 0.2 else 0.0)
        return {'idle': (cyc(16, idle), 8, True), 'talk': (cyc(8, talk), 8, True),
                'react': (seq(12, react), 10, False)}

    PORTRAIT_POSES = {'calm': dict(eyes=1.0), 'warm': dict(eyes=1.5, mouth=0.25)}


# =====================================================================
class Ofenya(Npc):
    BOUNDS = (-2.0, 2.2, -5.4, 0.3)
    PORTRAIT = (0.1, -3.8, 0.95)
    SKIN = hexc('D2C8B4')
    CAFTAN = hexc('3E4A5A')
    HAT = hexc('3A3232')
    KOROB = hexc('B08A5A')
    PANTS = hexc('6A5A4A')
    BEARD = hexc('4A3A2E')
    BASE = dict(breath=0.0, tilt=0.0, look=(0.6, 0.0), lid=0.0, mouth=0.0, smile=0.8, happy=False,
                coin=(0.82, -2.75), coin_sp=0.0, hn=(0.72, -2.55), hf=(-0.08, -2.3), lean=0.0, brow=0.0)

    def setup(self):
        p = self.p
        b = p['breath']
        ln = p['lean']
        self.hip = V(-0.02 - ln * 0.3, -1.85)
        self.neck = V(0.05 - ln * 0.8, -3.42 - b * 0.03)
        self.sh_n = V(0.22 - ln * 0.7, -3.18 - b * 0.03)
        self.sh_f = V(-0.32 - ln * 0.7, -3.2 - b * 0.03)

    def layers(self):
        return [self.korob, self.far_arm, self.legs, self.caftan, self.head, self.near_arm, self.coin]

    def korob(self):
        cv = self.cv
        ln = self.p['lean']
        o = V(-0.82 - ln * 0.8, -3.0)
        d = cv.poly([o + (-0.5, -1.05), o + (0.42, -1.05), o + (0.46, 1.0), o + (-0.48, 1.0)], 0.06)
        lat = 1 - 0.22 * (np.clip(np.sin((cv.X + cv.Y) * 22), 0.6, 1) - 0.6) / 0.4 \
            - 0.22 * (np.clip(np.sin((cv.X - cv.Y) * 22), 0.6, 1) - 0.6) / 0.4
        self.P(d, self.KOROB, R=0.3, pattern=lat)
        lid = cv.poly([o + (-0.55, -1.15), o + (0.47, -1.15), o + (0.47, -0.95), o + (-0.55, -0.95)], 0.04)
        self.P(lid, self.KOROB * 0.75, R=0.06, line=0.8)
        for x in (-0.25, 0.2):
            self.deco(cv.inter(d, np.abs(cv.X - o[0] - x) - 0.04), hexc('5A3E28'))
        # a red rag and a bundle of ribbons peeking out
        self.P(cv.ellipse(o + (0.2, -1.25), 0.18, 0.1), RED, R=0.05, line=0.6, cast=False)
        self.P(cv.ellipse(o + (-0.25, -1.22), 0.12, 0.08), hexc('4F8FE0'), R=0.05, line=0.6, cast=False)

    def far_arm(self):
        cv = self.cv
        d, el, h = self.limb(self.sh_f, self.p['hf'], 0.6, 0.56, 0.13, 0.1, (-0.4, 1))
        self.P(d, self.CAFTAN, R=0.12, dim=0.78)
        self.P(hand(cv, h, 0.08), self.SKIN, R=0.05, dim=0.85)

    def legs(self):
        cv = self.cv
        for f, dim, off in (((-0.32, 0.0), 0.8, -0.15), ((0.38, 0.0), 1.0, 0.15)):
            hip = self.hip + (off, 0)
            d, kn, an = self.limb(hip, V(*f) + (0, -0.12), 0.95, 0.85, 0.15, 0.11, (1, -0.1))
            self.P(d, self.PANTS, R=0.12, dim=dim, pattern=1 - 0.15 * np.clip(np.sin(cv.X * 40), 0.5, 1))
            wrap = cv.inter(d - 0.0, cv.Y - (kn[1] + 0.12))
            self.P(cv.inter(cv.cone(kn + (0, 0.1), an, 0.14, 0.12), wrap + 1), ONUCHI, R=0.08, dim=dim, line=0.6)
            for k in range(3):
                y = kn[1] + 0.25 + k * 0.17
                cv.ink(cv.inter(cv.seg((kn[0] - 0.15, y), (kn[0] + 0.15, y + 0.1), 0.007), cv.cone(kn, an, 0.15, 0.13)), alpha=0.6 * dim)
            ft = cv.ellipse(V(*f) + (0.12, -0.08), 0.22, 0.09)
            self.P(ft, LAPTI, R=0.05, dim=dim, pattern=1 - 0.2 * np.clip(np.sin((cv.X + cv.Y) * 50), 0.4, 1))

    def caftan(self):
        cv, p = self.cv, self.p
        ln = p['lean']
        n = self.neck
        d = cv.poly([n + (-0.48, 0.15), n + (0.38, 0.12), (0.62 - ln * 0.3, -1.05), (-0.6 - ln * 0.3, -1.0)], 0.07)
        self.P(d, self.CAFTAN, R=0.4, pattern=1 - 0.12 * np.clip(np.sin(cv.X * 10 + cv.n_mid * 3), 0, 1))
        cv.ink(cv.inter(cv.path([n + (0.12, 0.2), (0.15 - ln * 0.3, -2.2), (0.1 - ln * 0.3, -1.05)], 0.01), d), alpha=0.6)
        for k in range(3):
            self.P(cv.circle(n + (0.17 - ln * 0.1 * k, 0.45 + k * 0.3), 0.035), GOLDL, R=0.02, line=0.4, cast=False)
        sash = cv.inter(d - 0.01, np.abs(cv.Y + 2.22 + cv.X * 0.05) - 0.09)
        self.P(sash, RED, R=0.06, line=0.5, cast=False)
        self.P(cv.path([(-0.4 - ln * 0.3, -2.2), (-0.5 - ln * 0.3, -1.7), (-0.45 - ln * 0.3, -1.5)], 0.05, 0.035),
               RED * 0.9, R=0.04, line=0.5, cast=False)
        # korob straps over the shoulders
        for x in (-0.25, 0.12):
            self.deco(cv.inter(d, np.abs(cv.X - x + ln * 0.6 - (cv.Y + 3.0) * 0.15) - 0.04) + 0.0 * cv.X,
                      hexc('5A3E28'), line=0.3)
        # the pouch with silent coins
        self.P(cv.ellipse((-0.42 - ln * 0.3, -1.95), 0.13, 0.17), hexc('7A5A3A'), R=0.06, line=0.6)

    def head(self):
        cv, p = self.cv, self.p
        with Frame(cv, self.neck, p['tilt']):
            hc = V(0.08, -0.42)
            self.P(cv.ellipse(hc + (-0.2, 0.0), 0.22, 0.28), self.BEARD, R=0.15)
            face = cv.smin(cv.ellipse(hc + (0.05, 0.0), 0.3, 0.36), cv.ellipse(hc + (0.12, 0.22), 0.2, 0.18), 0.08)
            self.P(face, self.SKIN, R=0.25)
            br = cv.poly([hc + (-0.05, 0.22), hc + (0.3, 0.24), hc + (0.2, 0.62), hc + (0.12, 0.66)], 0.04)
            self.P(br, self.BEARD, R=0.1, pattern=1 - 0.2 * np.clip(np.sin(cv.X * 50), 0.3, 1))
            self.P(cv.path([hc + (0.04, 0.2), hc + (0.2, 0.16), hc + (0.35, 0.21)], 0.03, 0.02), self.BEARD, R=0.03,
                   line=0.5, cast=False)
            self.P(cv.ellipse(hc + (-0.2, 0.02), 0.06, 0.09), self.SKIN * 0.95, R=0.05, line=0.5, cast=False)
            lk = p['look']
            bu = p['brow'] * 0.05
            for c, rx in ((hc + (0.22, -0.04), 0.06), (hc + (0.02, -0.05), 0.05)):
                self.eye(c, rx, 0.05, look=lk, lid=p['lid'], skin=self.SKIN * 0.9, happy=p['happy'])
                self.P(cv.path([c + (-rx, -0.08 - bu), c + (0, -0.11 - bu * 1.5), c + (rx, -0.08 - bu)], 0.018, 0.012),
                       self.BEARD, R=0.02, line=0.3, cast=False, rim=False)
            self.P(cv.cone(hc + (0.3, -0.02), hc + (0.36, 0.13), 0.03, 0.05), self.SKIN, R=0.04, line=0.5)
            self.mouth(hc + (0.22, 0.3), 0.07, p['mouth'], p['smile'], teeth=p['mouth'] > 0.3)
            hat = cv.poly([hc + (-0.27, -0.25), hc + (0.35, -0.25), hc + (0.22, -0.88), hc + (-0.12, -0.88)], 0.11)
            self.P(hat, self.HAT, R=0.3, pattern=1 - 0.1 * np.clip(cv.n_hi * 5, 0, 1))
            band = cv.inter(hat, np.abs(cv.Y - hc[1] + 0.38) - 0.06)
            self.deco(band, RED * 0.85, line=0.3)
            brim = cv.ellipse(hc + (0.04, -0.27), 0.38, 0.07)
            self.P(brim, self.HAT * 1.1, R=0.05, line=0.8)
            self.P(cv.ellipse(hc + (-0.2, -0.42), 0.06, 0.08), hexc('6FBF5A'), R=0.03, line=0.5, cast=False)

    def near_arm(self):
        cv = self.cv
        d, el, h = self.limb(self.sh_n, self.p['hn'], 0.6, 0.56, 0.14, 0.11, (0.1, 1))
        self.P(d, self.CAFTAN * 1.08, R=0.12)
        self.P(cv.inter(d, cv.circle(h, 0.2)), self.CAFTAN * 0.8, R=0.05, line=0.6, cast=False)
        self.P(hand(cv, h + (0.04, -0.02), 0.085), self.SKIN, R=0.05)

    def coin(self):
        cv, p = self.cv, self.p
        c = V(*p['coin'])
        w = 0.09 * max(abs(np.cos(p['coin_sp'] * TAU)), 0.15)
        self.cv.paint(cv.ellipse(c, w, 0.09), GOLDL, R=0.03, line=0.6, cast=False, union=False, hl=1.5,
                      glow=(GOLDL, 0.03, 0.15))

    @staticmethod
    def anims():
        def idle(t):
            ph = t * TAU
            if t < 0.55:
                k = t / 0.55
                y = -2.75 - 1.0 * 4 * k * (1 - k)
            else:
                y = -2.75
            dip = bump(t, 0.5, 0.7)
            return dict(breath=np.sin(ph), coin=(0.82, y), coin_sp=t * 3 if t < 0.55 else 0.0,
                        hn=(0.74, -2.6 + 0.12 * dip + (0.08 if t < 0.08 else 0)), tilt=-0.08 * bump(t, 0.05, 0.5),
                        look=(0.5, -0.8 * bump(t, 0.1, 0.5)), brow=bump(t, 0.1, 0.5),
                        lid=1.0 if 0.84 <= t < 0.9 else 0.0)

        def talk(t):
            ph = t * TAU
            return dict(breath=np.sin(ph), hn=(0.82 + 0.1 * np.sin(ph * 2), -2.95 - 0.2 * np.sin(ph * 2)),
                        hf=(0.5 + 0.08 * np.cos(ph * 2), -2.55 + 0.15 * np.cos(ph * 2)), coin=(0.9, -2.95 - 0.2 * np.sin(ph * 2) - 0.02),
                        brow=0.6 + 0.4 * np.sin(ph * 2), look=(0.9, 0.0), tilt=0.04 * np.sin(ph * 2),
                        mouth=[0.0, 0.6, 0.3, 0.7, 0.2, 0.65, 0.4, 0.1][int(round(t * 8)) % 8], smile=0.6)

        def react(t):
            n = bump(t, 0.05, 0.95)
            sh = 0.03 * np.sin(t * TAU * 4) * n
            return dict(lean=0.12 * n, tilt=-0.2 * n + sh, happy=n > 0.3, mouth=0.8 * n, smile=1.0,
                        hf=(0.05, -2.2), hn=(0.5, -2.35), coin=(0.56, -2.4))
        return {'idle': (cyc(16, idle), 8, True), 'talk': (cyc(8, talk), 10, True),
                'react': (seq(10, react), 10, False)}

    PORTRAIT_POSES = {'calm': dict(look=(0.9, 0.0), brow=0.4, hn=(0.8, -3.0), coin=(0.88, -3.02)),
                      'warm': dict(happy=True, mouth=0.7, smile=1.0, tilt=-0.1, hn=(0.8, -3.0), coin=(0.88, -3.02))}


NPCS = {'dolya': Dolya, 'potap': Potap, 'sova': Sova, 'bayun': Bayun, 'chur': Chur, 'ofenya': Ofenya}

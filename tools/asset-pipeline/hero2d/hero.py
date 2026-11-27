"""Parametric hero (Ждан) builder: tier 1 and tier 5, 10 design variants."""
import numpy as np
from sdf2d import Canvas, hexc, INK

SKIN = hexc('E0A07A')
CANVAS = hexc('CDBB98')
WRAP = hexc('9A8A72')
STICK = hexc('8C6A44')
RED = hexc('B3262E')
STEEL = hexc('B8C4CC')
MAIL = hexc('8E9AA3')
GOLD = hexc('C8902E')
GOLDL = hexc('FFC94A')
BEARD = hexc('8A5A34')
LEATHER = hexc('6B4428')
WOOD = hexc('A07A4E')
SILVER = hexc('EDE6F2')

BASE = dict(
    sw=1.0,  # shoulder half width
    T=1.45,  # hip->shoulder
    Lg=1.72,  # hip height
    hr=0.44,  # head radius
    armk=1.0,  # arm thickness
    handk=1.0,
    armlen=1.0,
    legk=1.0,
    belly=1.0,
    skin=SKIN, hair=BEARD, beard=BEARD, brow=None,
    hair_style='shaggy', beard_style='full',
    eye=INK, eye_glow=None,
    stick='stick', weapon='sword',
    extras=(), seed=3,
)


def P(cfg, **kw):
    c = dict(BASE); c.update(cfg); c.update(kw)
    return c


class Hero:
    def __init__(self, cfg, tier, S=180):
        self.c = cfg
        self.t = tier
        self.cv = Canvas(-2.25, 2.25, -5.15, 0.35, S, seed=cfg['seed'])
        c = cfg
        self.hip_y = -c['Lg']
        self.waist_y = self.hip_y - 0.22
        self.sh_y = self.hip_y - c['T']
        self.head = (0.1, self.sh_y - 0.5 - c['hr'] * 0.55)

    def has(self, e):
        return e in self.c['extras']

    # ------------------------------------------------------------------
    def build(self):
        cv, c, t = self.cv, self.c, self.t
        sw = c['sw']
        # ground shadow
        cv.flat(cv.ellipse((0.05, 0.02), 1.15 * max(1, sw), 0.13), np.array([0, 0, 0]), alpha=0.35, soft=0.12)
        cv.a *= 1  # keep
        if t >= 5:
            self.cape()
        if self.has('bear'):
            self.bear_pelt_back()
        if self.has('wolf'):
            self.wolf_back()
        if self.has('braid'):
            self.braid()
        if self.has('ribbons'):
            self.ribbons_back()
        self.legs()
        self.arm(far=True)
        self.torso()
        self.amulet()
        self.head_()
        if self.has('bear'):
            self.bear_pelt_front()
        if self.has('wolf'):
            self.wolf_front()
        self.weapon()
        self.arm(far=False)
        if self.has('shield'):
            self.shield()
        cv.outer_outline(1.0)
        self.post_glow()
        return cv

    # ------------------------------------------------------------------
    def cape(self):
        cv, c = self.cv, self.c
        sw, sy = c['sw'], self.sh_y
        bot = -0.5
        pts = [(-sw * 0.75, sy - 0.05), (sw * 0.8, sy - 0.05), (sw + 0.75, sy + 1.2), (sw + 1.1, bot + 0.05),
               (sw + 0.6, bot - 0.08), (0.35, bot + 0.08), (-0.2, bot - 0.06), (-sw - 0.25, bot + 0.02), (-sw - 0.1, sy + 1.0)]
        d = cv.poly(pts, 0.06)
        folds = 1 - 0.18 * np.clip(np.sin((cv.X * 1.0 - cv.Y * 0.35) * 7.0), 0, 1) ** 2
        cv.paint(d, RED * 0.92, R=0.6, pattern=folds, dim=0.9)
        band = cv.inter(d, -(d + 0.085))
        band = cv.inter(band, -(cv.Y - (bot - 0.32)))
        orn = 1 - 0.35 * (np.abs(((cv.X * 9) % 2) - 1) > 0.6)
        cv.paint(band, GOLD, R=0.05, line=0.6, cast=False, pattern=orn, rim=False)

    def legs(self):
        cv, c, t = self.cv, self.c, self.t
        hy = self.hip_y
        lk = c['legk']
        for far in (True, False):
            sx = 1 if far else -1
            dim = 0.86 if far else 1.0
            hip = (0.3 * sx * c['sw'] ** 0.5, hy + 0.1)
            knee = (0.42 * sx * c['sw'] ** 0.5 + 0.02, hy * 0.5 - 0.02)
            ank = (0.48 * sx * c['sw'] ** 0.5 + (0.04 if far else -0.06), -0.2)
            foot_c = (ank[0] + 0.12, -0.1)
            r_th = 0.27 * lk; r_kn = 0.2 * lk; r_an = 0.13 * lk
            if t <= 1:
                # bare calf + wraps
                d_calf = cv.cone(knee, ank, r_kn * 0.95, r_an)
                cv.paint(d_calf, c['skin'], R=0.18, dim=dim)
                wr = np.clip(np.sin((cv.Y * 1.0 + cv.X * 0.45) * 38), 0, 1)
                d_wr = cv.cone((knee[0], knee[1] + 0.35), ank, r_kn * 0.98, r_an * 1.08)
                cv.paint(d_wr, WRAP, R=0.18, dim=dim, pattern=1 - 0.25 * wr, line=0.7)
                d_ft = cv.smin(cv.ellipse(foot_c, 0.27 * lk, 0.12), cv.circle((ank[0], -0.18), 0.12), 0.06)
                cv.paint(d_ft, WRAP * 0.95, R=0.1, dim=dim, pattern=1 - 0.2 * wr)
                # trousers: ragged canvas to below knee
                hem_y = knee[1] + 0.22
                d_p = cv.cone(hip, knee, r_th * 1.12, r_kn * 1.2)
                d_p = cv.smin(d_p, cv.cone(knee, (knee[0], hem_y), r_kn * 1.2, r_kn * 1.28), 0.05)
                teeth = 0.06 * np.abs(np.sin(cv.X * 26 + sx))
                d_p = cv.inter(d_p, cv.Y - (hem_y + teeth))
                cv.paint(d_p, c.get('pants', CANVAS), R=0.3, dim=dim)
            else:
                d_th = cv.cone(hip, knee, r_th * 1.1, r_kn * 1.15)
                cv.paint(d_th, hexc('5A3A40'), R=0.3, dim=dim)
                d_boot = cv.cone((knee[0], knee[1] + 0.05), ank, r_kn * 1.25, r_an * 1.3)
                cv.paint(d_boot, LEATHER, R=0.2, dim=dim)
                d_ft = cv.smin(cv.ellipse((foot_c[0] + 0.02, -0.11), 0.3 * lk, 0.13), cv.circle((ank[0], -0.2), 0.15), 0.06)
                cv.paint(d_ft, LEATHER * 0.9, R=0.12, dim=dim)
                d_gr = cv.cone((knee[0] + 0.03, knee[1] + 0.12), (ank[0] + 0.03, ank[1] - 0.12), r_kn * 1.12, r_an * 1.15)
                cv.paint(d_gr, STEEL, R=0.15, dim=dim, hl=1.3)
                d_kn = cv.circle((knee[0] + 0.04, knee[1] + 0.06), r_kn * 0.95)
                cv.paint(d_kn, STEEL, R=0.15, dim=dim, hl=1.3)

    def arm(self, far):
        cv, c, t = self.cv, self.c, self.t
        sw, sy = c['sw'], self.sh_y
        ak, hk, al = c['armk'], c['handk'], c['armlen']
        if far:
            sh = (sw * 0.78, sy + 0.16)
            el = (sw + 0.14 * ak, sy + 0.78 * al)
            wr = (sw + 0.12 * ak, sy + 1.3 * al)
            fist = (wr[0] - 0.02, wr[1] + 0.17 * hk)
            dim = 0.84
        else:
            sh = (-sw * 0.78, sy + 0.16)
            el = (-sw - 0.2 * ak, sy + 0.76 * al)
            wr = self.grip_hand_wrist()
            fist = self.grip()
            dim = 1.0
        skin = c['skin']
        d_up = cv.cone(sh, el, 0.25 * ak, 0.19 * ak)
        d_up = cv.smin(d_up, cv.ellipse((sh[0] + (0.04 if far else -0.04), sh[1] + 0.05), 0.3 * ak, 0.27 * ak, rot=0.5 if far else -0.5), 0.1)
        d_fa = cv.cone(el, wr, 0.25 * ak, 0.18 * ak)
        d_fa = cv.smin(d_fa, cv.ellipse(((el[0] * 0.6 + wr[0] * 0.4), (el[1] * 0.6 + wr[1] * 0.4)), 0.3 * ak, 0.22 * ak,
                                         rot=np.arctan2(wr[1] - el[1], wr[0] - el[0])), 0.08)
        if t >= 5:
            cv.paint(d_up, MAIL, R=0.25, dim=dim, pattern=self.mail_pat())
            d_pl = cv.ellipse((sh[0] * 1.02, sh[1] + 0.02), 0.36 * ak, 0.28 * ak, rot=0.3 if far else -0.3)
            cv.paint(d_pl, STEEL, R=0.3, dim=dim, hl=1.3)
            cv.paint(cv.inter(d_pl, -(d_pl + 0.05)), GOLD, R=0.04, line=0.4, cast=False, rim=False, dim=dim)
            cv.paint(d_fa, LEATHER, R=0.2, dim=dim)
            d_br = cv.cone((el[0] * 0.75 + wr[0] * 0.25, el[1] * 0.75 + wr[1] * 0.25), wr, 0.25 * ak, 0.2 * ak)
            cv.paint(d_br, STEEL, R=0.2, dim=dim, hl=1.3)
            cv.paint(cv.inter(cv.seg((wr[0] - 0.25, wr[1]), (wr[0] + 0.25, wr[1]), 0.04), d_br - 0.01), GOLD, R=0.03, line=0.4, cast=False, rim=False, dim=dim)
        else:
            cv.paint(d_up, skin, R=0.25, dim=dim)
            cv.paint(d_fa, skin, R=0.25, dim=dim)
            self.skin_marks(d_up, d_fa, dim)
            if self.has('ribbons'):
                self.wrap_bands(cv.cone(el, wr, 0.25 * ak, 0.17 * ak), dim)
        # fist
        r = 0.25 * hk
        d_f = cv.smin(cv.ellipse(fist, r * 1.05, r * 0.95), cv.circle((fist[0] + (0.12 if far else -0.1) * hk, fist[1] - 0.05), r * 0.45), 0.05)
        cv.paint(d_f, skin if not (t >= 5 and self.has('gauntlet')) else LEATHER, R=0.18, dim=dim)
        # knuckle line
        cv.ink(cv.seg((fist[0] - r * 0.5, fist[1] - r * 0.1), (fist[0] + r * 0.5, fist[1] - r * 0.15), 0.012), alpha=0.8)
        if not far:
            # Mokosh red thread on the near wrist (over bracer)
            wy = wr[1] - 0.02
            dt = cv.ellipse((wr[0], wy), 0.2 * ak + 0.02, 0.045, rot=0.1)
            dt = cv.inter(dt, -cv.ellipse((wr[0], wy - 0.01), 0.2 * ak - 0.04, 0.02, rot=0.1))
            cv.paint(dt, RED * 1.15, R=0.03, line=0.5, cast=False, rim=False, hl=1.5)
            ends = cv.path([(wr[0] + 0.12, wy + 0.02), (wr[0] + 0.2, wy + 0.13), (wr[0] + 0.17, wy + 0.24)], 0.022, 0.012)
            ends = np.minimum(ends, cv.path([(wr[0] + 0.1, wy + 0.03), (wr[0] + 0.1, wy + 0.16), (wr[0] + 0.04, wy + 0.25)], 0.02, 0.01))
            cv.paint(ends, RED * 1.15, R=0.03, line=0.45, cast=False, rim=False)

    def grip(self):
        c = self.c
        return (-c['sw'] - 0.14 * c['armk'], self.sh_y + 1.32 * c['armlen'])

    def grip_hand_wrist(self):
        g = self.grip()
        return (g[0] + 0.03, g[1] - 0.18 * self.c['handk'])

    def mail_pat(self):
        cv = self.cv
        u = cv.X * 24; v = cv.Y * 24
        ring = np.abs(np.sin(u + np.sin(v) * 0.6)) * np.abs(np.sin(v * 1.1))
        return 0.86 + 0.18 * ring

    def scale_pat(self):
        cv = self.cv
        rowh, cw = 0.13, 0.17
        r = np.floor(cv.Y / rowh)
        off = (r % 2) * 0.5
        u = cv.X / cw + off
        fu = u - np.floor(u) - 0.5
        v = cv.Y / rowh - r
        edge = 1 - 3.2 * fu * fu
        inside = v < edge
        sh = np.where(inside, 1.08 - 0.42 * (v / np.maximum(edge, 0.1)), 0.62 + 0.25 * v)
        line = np.abs(v - edge) < 0.09
        sh = np.where(line, 0.35, sh)
        return sh

    def torso(self):
        cv, c, t = self.cv, self.c, self.t
        sw, sy, wy, hy = c['sw'], self.sh_y, self.waist_y, self.hip_y
        bk = c['belly']
        d = cv.ellipse((0.02, sy + 0.38), sw * 0.84, 0.5)
        d = cv.smin(d, cv.ellipse((0.05, wy - 0.33), sw * 0.6 * bk, 0.48 * min(bk, 1.15)), 0.2)
        d = cv.smin(d, cv.ellipse((0.02, sy + 0.12), sw * 0.8, 0.22), 0.15)
        d = cv.smin(d, cv.ellipse((0.04, hy - 0.08), 0.52 * sw ** 0.5 * max(1, bk * 0.95), 0.3), 0.15)
        neck = cv.cone((0.08, sy - 0.32), (0.05, sy + 0.1), 0.2 * sw ** 0.3, 0.26 * sw ** 0.3)
        if t <= 1:
            cv.paint(neck, c['skin'], R=0.15, dim=0.92)
            cv.paint(d, c['skin'], R=0.55)
            # anatomy strokes
            cv.ink(cv.path([(-sw * 0.55, sy + 0.62), (-0.2, sy + 0.72), (0.02, sy + 0.6)], 0.012), alpha=0.75)
            cv.ink(cv.path([(0.08, sy + 0.6), (0.3, sy + 0.72), (sw * 0.6, sy + 0.6)], 0.011), alpha=0.6)
            cv.ink(cv.circle((0.06, wy - 0.25), 0.025), alpha=0.7)
            self.skin_marks_torso(d)
            # pants top + rope belt
            k = sw ** 0.5 * max(1, bk * 0.95)
            dp = cv.poly([(-0.55 * k, wy + 0.02), (0.6 * k, wy + 0.02), (0.64 * k + 0.04, hy + 0.32), (-0.6 * k - 0.02, hy + 0.32)], 0.03)
            cv.paint(dp, c.get('pants', CANVAS), R=0.3)
            belt = cv.path([(-0.55 * sw ** 0.5 * bk, wy + 0.03), (0.04, wy + 0.08), (0.62 * sw ** 0.5 * bk, wy + 0.02)], 0.045)
            cv.paint(belt, hexc('B49A6A'), R=0.04, line=0.6, cast=True)
            knot = cv.path([(0.2, wy + 0.08), (0.24, wy + 0.3), (0.2, wy + 0.42)], 0.03, 0.018)
            cv.paint(knot, hexc('B49A6A'), R=0.03, line=0.5)
            if self.has('ribbons'):
                self.wrap_bands(d, 1.0, torso=True)
        else:
            cv.paint(neck, c['skin'], R=0.15, dim=0.9)
            # mail skirt
            ms = cv.poly([(-sw * 0.6, wy - 0.4), (sw * 0.64, wy - 0.4), (0.66 * sw ** 0.5 + 0.12, hy + 0.62), (-0.6 * sw ** 0.5 - 0.1, hy + 0.6)], 0.05)
            ms = cv.inter(ms, cv.Y - (hy + 0.6 + 0.04 * np.sin(cv.X * 30)))
            cv.paint(ms, MAIL, R=0.4, pattern=self.mail_pat())
            dd = d - 0.06
            cv.paint(dd, c.get('steel', STEEL), R=0.55, pattern=self.scale_pat(), hl=1.3)
            if self.has('embers'):
                self.ember_cracks(dd + 0.08)
            belt = cv.inter(cv.ellipse((0.04, wy + 0.02), 0.66 * sw ** 0.5 * max(1, bk), 0.5), np.abs(cv.Y - (wy + 0.02)) - 0.08)
            cv.paint(belt, LEATHER, R=0.08, line=0.7)
            cv.paint(cv.ellipse((0.12, wy + 0.02), 0.11, 0.09), GOLD, R=0.06, line=0.6, hl=1.6)
            # barmitsa (mail over shoulders, under chin)
            hx, hy = self.head; hr = c['hr']
            bm = cv.poly([(hx - hr * 1.0, hy - hr * 0.3), (hx + hr * 1.05, hy - hr * 0.3), (hx + hr * 1.25, sy + 0.05),
                          (hx + hr * 0.9, sy + 0.3), (hx - hr * 0.2, sy + 0.38), (hx - hr * 1.3, sy + 0.28), (hx - hr * 1.4, sy + 0.02)], 0.06)
            bm = cv.inter(bm, cv.Y - (sy + 0.3 + 0.035 * np.abs(np.sin(cv.X * 22))))
            cv.paint(bm, MAIL, R=0.4, pattern=self.mail_pat())

    def skin_marks(self, d_up, d_fa, dim):
        cv = self.cv
        if self.has('embers'):
            self.ember_cracks(np.minimum(d_up, d_fa))
        if self.has('ghost'):
            self.ghost_lines(np.minimum(d_up, d_fa))

    def skin_marks_torso(self, d):
        cv, c = self.cv, self.c
        sw, sy = c['sw'], self.sh_y
        # bruises / scrapes on shoulders
        for sx in (-1, 1):
            for k in range(3):
                x0 = sx * sw * 0.7 + 0.05 * k
                cv.ink(cv.seg((x0, sy + 0.02 + 0.05 * k), (x0 + 0.12 * sx, sy + 0.1 + 0.05 * k), 0.008), col=hexc('8C3A2E'), alpha=0.6)
        if self.has('scar'):
            cv.ink(cv.path([(-sw * 0.5, sy + 0.3), (-0.1, sy + 0.55), (0.3, sy + 0.95)], 0.02), col=hexc('A04A3A'), alpha=0.9)
            for k in range(5):
                x = -sw * 0.45 + k * 0.17
                y = sy + 0.32 + k * 0.13
                cv.ink(cv.seg((x - 0.03, y + 0.05), (x + 0.03, y - 0.05), 0.008), col=hexc('A04A3A'), alpha=0.8)
        if self.has('embers'):
            self.ember_cracks(d)
        if self.has('ghost'):
            self.ghost_lines(d)

    def ember_cracks(self, d):
        cv = self.cv
        rng = np.random.default_rng(7)
        pts = np.stack([rng.uniform(-2.2, 2.2, 70), rng.uniform(-5, 0.3, 70)], 1)
        d1 = np.full(cv.X.shape, 9.0, np.float32); d2 = d1.copy()
        for px, py in pts:
            dd = np.hypot(cv.X - px, cv.Y - py)
            d2 = np.where(dd < d1, d1, np.minimum(d2, dd))
            d1 = np.minimum(d1, dd)
        e = (d2 - d1) + cv.n_mid * 0.03
        core = np.clip(1 - e / 0.022, 0, 1) * (d < -0.03) * (cv.n_lo > -0.18)
        halo = np.clip(1 - e / 0.07, 0, 1) * (d < -0.02) * (cv.n_lo > -0.18)
        cv.rgb = cv.rgb * (1 - 0.35 * halo[..., None]) + np.array([0.55, 0.18, 0.05]) * 0.35 * halo[..., None]
        col = np.array([1.0, 0.62, 0.18])
        cv.rgb = cv.rgb * (1 - core[..., None]) + col * core[..., None]
        cv.glow += core[..., None] * np.array([1.0, 0.45, 0.1]) * 0.3

    def ghost_lines(self, d):
        cv = self.cv
        n = cv.n_mid
        cr = np.abs(np.sin(cv.Y * 9 + n * 8)) < 0.05
        m = (cr & (d < -0.06) & (np.abs(cv.n_lo) < 0.12)).astype(np.float32) * 0.9
        cv.rgb = cv.rgb * (1 - m[..., None]) + SILVER * m[..., None]
        cv.glow += m[..., None] * np.array([0.6, 0.65, 0.9]) * 0.25

    def wrap_bands(self, d, dim, torso=False):
        cv = self.cv
        if torso:
            sy = self.sh_y
            bands = [cv.inter(d + 0.01, np.abs(cv.Y - (sy + 0.95) + (cv.X) * 0.45) - 0.08),
                     cv.inter(d + 0.01, np.abs(cv.Y - (sy + 1.3) - (cv.X) * 0.3) - 0.07),
                     cv.inter(d + 0.01, np.abs(cv.Y - (sy + 0.45) - (cv.X) * 0.5) - 0.06)]
        else:
            bands = [cv.inter(d + 0.01, np.abs(np.sin((cv.Y + cv.X * 0.4) * 11)) - 0.55)]
        for b in bands:
            emb = 1 - 0.5 * ((np.abs(((cv.X + cv.Y) * 18) % 2 - 1) < 0.25) & (np.abs(((cv.X - cv.Y) * 18) % 2 - 1) < 0.25))
            cv.paint(b, hexc('E6DCC4'), R=0.06, line=0.5, dim=dim, cast=False, pattern=emb)
            cv.paint(cv.inter(b, -(b + 0.022)), RED, R=0.02, line=0.0, dim=dim, cast=False, rim=False)

    def amulet(self):
        cv, c, t = self.cv, self.c, self.t
        sy = self.sh_y
        a = (0.12, sy + 0.62)
        if t <= 1:
            cord = np.minimum(cv.path([(-0.12, sy - 0.12), (-0.02, sy + 0.35), (a[0] - 0.03, a[1] - 0.08)], 0.012),
                              cv.path([(0.3, sy - 0.12), (0.26, sy + 0.35), (a[0] + 0.03, a[1] - 0.08)], 0.012))
            cv.ink(cord, col=hexc('3A2418'))
            cv.paint(cv.circle(a, 0.11), WOOD, R=0.08, line=0.7, cast=True)
            cv.paint(cv.circle(a, 0.055), GOLDL, R=0.05, line=0.4, cast=False, flat=True, glow=(np.array([1.0, 0.75, 0.3]), 0.12, 0.8))
            for k in range(6):
                ang = k * np.pi / 3
                cv.ink(cv.seg((a[0] + 0.07 * np.cos(ang), a[1] + 0.07 * np.sin(ang)), (a[0] + 0.095 * np.cos(ang), a[1] + 0.095 * np.sin(ang)), 0.008), col=hexc('5A3A22'))
        else:
            a = (0.12, sy + 0.5)
            cv.paint(cv.circle(a, 0.16), GOLD, R=0.1, line=0.8, hl=1.5)
            cv.paint(cv.circle(a, 0.09), GOLDL, R=0.05, line=0.4, cast=False, flat=True, glow=(np.array([1.0, 0.78, 0.3]), 0.2, 1.0))
            cv.ink(cv.path([(a[0] - 0.05, a[1]), (a[0], a[1] - 0.05), (a[0] + 0.05, a[1]), (a[0], a[1] + 0.05), (a[0] - 0.05, a[1])], 0.008), col=hexc('8A5A10'))
        self.amulet_pos = a

    # ------------------------------------------------------------------
    def head_(self):
        cv, c, t = self.cv, self.c, self.t
        hx, hy = self.head
        hr = c['hr']
        skin = c['skin']
        dh = cv.smin(cv.circle((hx, hy), hr), cv.ellipse((hx + 0.05, hy + hr * 0.5), hr * 0.82, hr * 0.62), 0.1)
        # back hair (behind head)
        if c['hair_style'] in ('shaggy', 'long', 'braid') and t <= 1:
            dbh = cv.poly([(hx - hr * 1.05, hy - hr * 0.3), (hx - hr * 0.3, hy - hr * 1.0), (hx + hr * 0.4, hy - hr * 0.9),
                           (hx - hr * 0.2, hy + hr * 0.6), (hx - hr * 1.05, hy + hr * (1.0 if c['hair_style'] == 'long' else 0.6))], 0.08)
            cv.paint(dbh, c['hair'], R=0.25, dim=0.85)
        cv.paint(dh, skin, R=0.45)
        # ear
        ear = cv.ellipse((hx - hr * 0.62, hy + 0.04), 0.09, 0.13, rot=0.2)
        cv.paint(ear, skin, R=0.08, dim=0.95)
        cv.ink(cv.path([(hx - hr * 0.62, hy - 0.04), (hx - hr * 0.66, hy + 0.05), (hx - hr * 0.6, hy + 0.1)], 0.008), alpha=0.7)
        # eyes
        ex1 = (hx + hr * 0.08, hy + 0.02)
        ex2 = (hx + hr * 0.66, hy + 0.01)
        glow = c['eye_glow']
        for ex, sc in ((ex1, 1.0), (ex2, 0.82)):
            if glow is None:
                cv.paint(cv.ellipse(ex, 0.075 * sc, 0.06), hexc('F2E6D6'), R=0.03, line=0.55, cast=False, rim=False, shade=False)
                cv.flat(cv.ellipse((ex[0] + 0.02, ex[1] + 0.005), 0.038 * sc, 0.048), c['eye'])
                cv.flat(cv.circle((ex[0] + 0.03, ex[1] - 0.018), 0.012), hexc('FFFFFF'))
            else:
                cv.paint(cv.ellipse(ex, 0.07 * sc, 0.05), hexc('20182A'), R=0.03, line=0.5, cast=False, rim=False, shade=False)
                cv.paint(cv.ellipse((ex[0] + 0.015, ex[1]), 0.04 * sc, 0.03), glow, R=0.03, line=0.0, flat=True, cast=False,
                         glow=(glow, 0.06, 0.9))
        # brows
        bc = c['brow'] if c['brow'] is not None else c['hair'] * 0.6
        bw = 0.032 * (1.5 if self.has('bushy') else 1.0)
        cv.paint(cv.path([(ex1[0] - 0.09, ex1[1] - 0.09), (ex1[0] + 0.02, ex1[1] - 0.12), (ex1[0] + 0.1, ex1[1] - 0.08)], bw, bw * 0.6), bc, R=0.03, line=0.4, cast=False, rim=False)
        cv.paint(cv.path([(ex2[0] - 0.08, ex2[1] - 0.09), (ex2[0] + 0.0, ex2[1] - 0.12), (ex2[0] + 0.07, ex2[1] - 0.1)], bw * 0.8, bw * 0.5), bc, R=0.03, line=0.4, cast=False, rim=False)
        if self.has('scar'):
            cv.paint(cv.seg((ex1[0] - 0.08, ex1[1] - 0.2), (ex1[0] + 0.1, ex1[1] + 0.22), 0.016), hexc('C46A5A'), R=0.02, line=0.35, cast=False, rim=False)
        if self.has('embers'):
            cv.ink(cv.path([(hx - 0.25, hy - 0.2), (hx - 0.15, hy - 0.1), (hx - 0.18, hy + 0.05)], 0.012), col=np.array([1.0, 0.55, 0.12]))
        # beard
        self.beard()
        # nose
        nose = cv.cone((hx + hr * 0.42, hy + 0.02), (hx + hr * 0.52, hy + 0.17), 0.05, 0.085)
        cv.paint(nose, skin, R=0.07, line=0.6)
        # hair top / helmet
        if t >= 5:
            self.helmet()
        else:
            self.hair_top()

    def beard(self):
        cv, c = self.cv, self.c
        hx, hy = self.head
        hr = c['hr']
        st = c['beard_style']
        col = c['beard']
        if st == 'short':
            pts = [(hx - hr * 0.55, hy + 0.08), (hx - hr * 0.3, hy + hr * 0.95), (hx + hr * 0.25, hy + hr * 1.18), (hx + hr * 0.85, hy + hr * 0.75),
                   (hx + hr * 0.75, hy + 0.2), (hx + hr * 0.45, hy + 0.32), (hx + hr * 0.1, hy + 0.3), (hx - hr * 0.3, hy + 0.2)]
            r = 0.04
        elif st == 'long':
            pts = [(hx - hr * 0.6, hy + 0.05), (hx - hr * 0.55, hy + hr * 1.2), (hx - hr * 0.1, hy + hr * 2.4), (hx + hr * 0.15, hy + hr * 2.9),
                   (hx + hr * 0.45, hy + hr * 2.3), (hx + hr * 0.95, hy + hr * 1.0), (hx + hr * 0.78, hy + 0.2), (hx + hr * 0.4, hy + 0.3), (hx - hr * 0.3, hy + 0.2)]
            r = 0.06
        else:  # full
            pts = [(hx - hr * 0.6, hy + 0.05), (hx - hr * 0.5, hy + hr * 1.1), (hx - hr * 0.05, hy + hr * 1.65), (hx + hr * 0.25, hy + hr * 1.75),
                   (hx + hr * 0.55, hy + hr * 1.45), (hx + hr * 0.95, hy + hr * 0.85), (hx + hr * 0.78, hy + 0.2), (hx + hr * 0.4, hy + 0.32), (hx - hr * 0.3, hy + 0.2)]
            r = 0.05
        d = cv.poly(pts, r)
        strands = 1 - 0.16 * np.clip(np.sin((cv.X * 3 - cv.Y * 0.4) * 22 + cv.n_mid * 6), 0, 1)
        cv.paint(d, col, R=0.25, pattern=strands)
        # moustache
        mx, my = hx + hr * 0.45, hy + hr * 0.62
        mu = cv.path([(mx - 0.22, my + 0.08), (mx - 0.05, my - 0.02), (mx + 0.04, my - 0.02), (mx + 0.2, my + 0.06)], 0.035, 0.03)
        cv.paint(mu, col * 1.08, R=0.04, line=0.55, cast=True)
        cv.ink(cv.seg((mx - 0.05, my + 0.07), (mx + 0.06, my + 0.07), 0.012), col=hexc('5A2A24'))
        if self.has('braid_beard'):
            for k in range(4):
                yy = hy + hr * (1.7 + 0.25 * k)
                cv.ink(cv.seg((hx + hr * 0.0, yy), (hx + hr * 0.35, yy + 0.04), 0.01), alpha=0.6)

    def hair_top(self):
        cv, c = self.cv, self.c
        hx, hy = self.head
        hr = c['hr']
        st = c['hair_style']
        col = c['hair']
        if self.has('wolf') or self.has('hood'):
            return
        if st == 'bald':
            pts = [(hx - hr * 0.98, hy - hr * 0.05), (hx - hr * 1.12, hy - hr * 0.35), (hx - hr * 0.95, hy - hr * 0.45), (hx - hr * 1.05, hy - hr * 0.7),
                   (hx - hr * 0.7, hy - hr * 0.5), (hx - hr * 0.45, hy - hr * 0.1), (hx - hr * 0.55, hy + hr * 0.45), (hx - hr * 0.95, hy + hr * 0.5)]
            strands = 1 - 0.14 * np.clip(np.sin((cv.X * 2 + cv.Y) * 26 + cv.n_mid * 5), 0, 1)
            cv.paint(cv.poly(pts, 0.03), col, R=0.15, pattern=strands)
            cv.flat(cv.ellipse((hx + 0.02, hy - hr * 0.72), 0.13, 0.05, rot=-0.3), hexc('FFF0E0'), alpha=0.4)
            for k in range(3):
                cv.ink(cv.path([(hx + 0.05 + 0.02 * k, hy - hr * (0.55 - 0.1 * k)), (hx + 0.2, hy - hr * (0.6 - 0.1 * k)), (hx + 0.32, hy - hr * (0.52 - 0.1 * k))], 0.007), alpha=0.45)
            return
        if st == 'cropped':
            d = cv.inter(cv.circle((hx - 0.03, hy - 0.04), hr * 1.04), -(cv.Y - (hy - hr * 0.35 + (cv.X - hx) * 0.35)))
            d = cv.inter(d, -(cv.X - (hx + hr * 0.75)))
            cv.paint(d, col, R=0.2)
            return
        # shaggy tufts
        tufts = []
        n = 9
        for i in range(n + 1):
            a = np.pi * (1.05 + 0.95 * i / n)
            rr = hr * (1.12 if i % 2 == 0 else 1.32)
            tufts.append((hx + np.cos(a) * rr, hy - 0.05 + np.sin(a) * rr))
        tufts += [(hx + hr * 0.95, hy - hr * 0.2), (hx + hr * 0.55, hy - hr * 0.48), (hx + hr * 0.25, hy - hr * 0.3),
                  (hx - hr * 0.05, hy - hr * 0.5), (hx - hr * 0.4, hy - hr * 0.2), (hx - hr * 0.65, hy + hr * 0.35), (hx - hr * 1.0, hy + hr * 0.5)]
        d = cv.poly(tufts, 0.04)
        strands = 1 - 0.14 * np.clip(np.sin((cv.X * 2 + cv.Y) * 26 + cv.n_mid * 5), 0, 1)
        cv.paint(d, col, R=0.3, pattern=strands)

    def helmet(self):
        cv, c = self.cv, self.c
        hx, hy = self.head
        hr = c['hr']
        top = hy - hr * 2.15
        dome = cv.poly([(hx - hr * 1.1, hy - hr * 0.25), (hx - hr * 0.95, hy - hr * 0.95), (hx - hr * 0.45, hy - hr * 1.45), (hx + 0.02, top),
                        (hx + hr * 0.5, hy - hr * 1.45), (hx + hr * 1.0, hy - hr * 0.95), (hx + hr * 1.12, hy - hr * 0.25)], 0.05)
        cv.paint(dome, STEEL, R=0.45, hl=1.4)
        cv.ink(cv.path([(hx + 0.02, top + 0.05), (hx + 0.06, hy - hr * 0.9), (hx + 0.08, hy - hr * 0.35)], 0.012), alpha=0.5)
        rim = cv.inter(dome, np.abs(cv.Y - (hy - hr * 0.34)) - 0.075)
        orn = 1 - 0.3 * (np.abs(((cv.X * 11) % 2) - 1) > 0.55)
        cv.paint(rim, GOLD, R=0.07, line=0.7, pattern=orn, hl=1.5)
        cv.paint(cv.circle((hx + 0.02, top - 0.04), 0.06), GOLD, R=0.05, line=0.6)
        if self.has('helm_plume'):
            pl = cv.path([(hx + 0.02, top - 0.05), (hx - 0.2, top - 0.25), (hx - 0.55, top - 0.15), (hx - 0.8, top + 0.15)], 0.05, 0.02)
            cv.paint(pl, RED, R=0.04)

    # ------------------------------------------------------------------
    def weapon(self):
        cv, c, t = self.cv, self.c, self.t
        g = self.grip()
        x = g[0] + 0.01
        if t <= 1:
            kind = c['stick']
            if kind == 'log':
                d = cv.cone((x - 0.05, -0.02), (x + 0.12, g[1] - 1.25), 0.15, 0.2)
                d = np.minimum(d, cv.circle((x + 0.13, g[1] - 1.3), 0.21))
                cv.paint(d, STICK, R=0.15)
                cv.ink(cv.circle((x + 0.13, g[1] - 1.3), 0.08), alpha=0.5)
            else:
                pts = [(x - 0.05, -0.02), (x - 0.02, g[1] * 0.5), (x + 0.02, g[1]), (x + 0.04, g[1] - 0.9), (x + 0.1, g[1] - 1.35)]
                d = cv.path(pts, 0.065, 0.05)
                d = np.minimum(d, cv.seg((x + 0.03, g[1] - 0.95), (x + 0.22, g[1] - 1.18), 0.03))
                cv.paint(d, STICK, R=0.07)
                for yy in (g[1] * 0.35, g[1] * 0.75, g[1] - 0.6):
                    cv.paint(cv.ellipse((x - 0.02, yy), 0.075, 0.035), STICK * 0.8, R=0.03, line=0.4, cast=False)
            return
        kind = c['weapon']
        if kind == 'sword':
            blade = cv.poly([(x - 0.07, g[1] + 0.22), (x + 0.07, g[1] + 0.22), (x + 0.055, -0.15), (x, 0.0), (x - 0.055, -0.15)], 0.0)
            cv.paint(blade, hexc('D4DCE2'), R=0.06, hl=1.6)
            cv.ink(cv.seg((x, g[1] + 0.3), (x, -0.18), 0.008), alpha=0.5)
            cv.paint(cv.cone((x - 0.3, g[1] + 0.2), (x + 0.3, g[1] + 0.2), 0.05, 0.05), GOLD, R=0.04)
            cv.paint(cv.seg((x, g[1] + 0.2), (x, g[1] - 0.3), 0.045), LEATHER, R=0.04)
            cv.paint(cv.circle((x, g[1] - 0.35), 0.07), GOLD, R=0.05)
        elif kind == 'axe':
            cv.paint(cv.path([(x - 0.03, -0.05), (x, g[1]), (x + 0.03, g[1] - 1.15)], 0.05), STICK * 0.9, R=0.05)
            hd = cv.poly([(x + 0.02, g[1] - 1.12), (x + 0.48, g[1] - 1.42), (x + 0.6, g[1] - 0.95), (x + 0.45, g[1] - 0.6), (x + 0.02, g[1] - 0.8)], 0.02)
            cv.paint(hd, STEEL, R=0.15, hl=1.5)
            cv.paint(cv.inter(hd, -(cv.X - (x + 0.45))), hexc('E8EEF2'), R=0.04, line=0.3, cast=False)
        elif kind == 'spear':
            cv.paint(cv.path([(x - 0.03, -0.05), (x, g[1]), (x + 0.05, g[1] - 1.9)], 0.04), STICK * 0.9, R=0.04)
            tip = cv.poly([(x + 0.05, g[1] - 2.45), (x + 0.15, g[1] - 2.0), (x + 0.05, g[1] - 1.85), (x - 0.05, g[1] - 2.0)], 0.01)
            cv.paint(tip, STEEL, R=0.06, hl=1.5)
            cv.paint(cv.path([(x + 0.05, g[1] - 1.88), (x + 0.2, g[1] - 1.6), (x + 0.15, g[1] - 1.35)], 0.03, 0.015), RED, R=0.03)
        elif kind == 'mace':
            cv.paint(cv.path([(x - 0.02, g[1] + 0.35), (x + 0.03, g[1] - 1.0)], 0.06), LEATHER, R=0.05)
            hd = cv.circle((x + 0.04, g[1] - 1.2), 0.3)
            for k in range(8):
                a = k * np.pi / 4
                hd = np.minimum(hd, cv.poly([(x + 0.04 + 0.42 * np.cos(a), g[1] - 1.2 + 0.42 * np.sin(a)),
                                             (x + 0.04 + 0.2 * np.cos(a + 0.4), g[1] - 1.2 + 0.2 * np.sin(a + 0.4)),
                                             (x + 0.04 + 0.2 * np.cos(a - 0.4), g[1] - 1.2 + 0.2 * np.sin(a - 0.4))]))
            cv.paint(hd, STEEL * 0.9, R=0.3, hl=1.5)
            cv.paint(cv.circle((x + 0.04, g[1] - 1.2), 0.1), GOLD, R=0.06, line=0.5, cast=False)
        elif kind == 'hammer':
            cv.paint(cv.path([(x - 0.03, -0.05), (x, g[1]), (x + 0.02, g[1] - 1.1)], 0.05), STICK * 0.9, R=0.05)
            hd = cv.poly([(x - 0.32, g[1] - 1.35), (x + 0.38, g[1] - 1.38), (x + 0.36, g[1] - 0.95), (x - 0.3, g[1] - 0.95)], 0.05)
            cv.paint(hd, STEEL * 0.92, R=0.2, hl=1.5)
            cv.paint(cv.inter(hd, np.abs(cv.X - x) - 0.06), GOLD, R=0.04, line=0.4, cast=False)
        elif kind == 'flail':
            cv.paint(cv.path([(x - 0.02, g[1] + 0.3), (x, g[1] - 0.45)], 0.05), STICK, R=0.05)
            ch = cv.path([(x, g[1] - 0.45), (x + 0.15, g[1] - 0.2), (x + 0.3, g[1] + 0.15), (x + 0.35, g[1] + 0.5)], 0.018)
            cv.paint(ch, MAIL, R=0.02, line=0.5)
            cv.paint(cv.circle((x + 0.36, g[1] + 0.65), 0.18), STEEL * 0.9, R=0.15, hl=1.5)

    def shield(self):
        cv, c = self.cv, self.c
        if self.t < 5:
            return
        sw, sy = c['sw'], self.sh_y
        cc = (sw + 0.35, sy + 1.25)
        d = cv.circle(cc, 0.62)
        cv.paint(d, RED * 0.95, R=0.5)
        cv.paint(cv.inter(d, -(d + 0.08)), GOLD, R=0.06, line=0.6, cast=False)
        cv.paint(cv.circle(cc, 0.16), STEEL, R=0.15, hl=1.5)
        for k in range(8):
            a = k * np.pi / 4 + 0.2
            cv.ink(cv.seg((cc[0] + 0.2 * np.cos(a), cc[1] + 0.2 * np.sin(a)), (cc[0] + 0.5 * np.cos(a), cc[1] + 0.5 * np.sin(a)), 0.012), alpha=0.55)

    # ---------------- variant extras --------------------------------
    def bear_pelt_back(self):
        cv, c = self.cv, self.c
        sw, sy = c['sw'], self.sh_y
        pts = [(-sw * 1.05, sy - 0.15), (sw * 1.0, sy - 0.15), (sw * 1.25, sy + 0.9), (sw * 1.1, sy + 1.6), (sw * 0.6, sy + 1.3), (0.1, sy + 1.75),
               (-sw * 0.6, sy + 1.4), (-sw * 1.2, sy + 1.7), (-sw * 1.3, sy + 0.8)]
        d = cv.poly(pts, 0.08) + 0.04 * np.sin(cv.X * 30) * (cv.Y > sy + 1.0)
        fur = self.fur()
        cv.paint(d, hexc('5E3E2A'), R=0.5, pattern=fur, dim=0.85)

    def bear_pelt_front(self):
        cv, c = self.cv, self.c
        sw, sy = c['sw'], self.sh_y
        fur = self.fur()
        # mantle over shoulders
        m = cv.poly([(-sw * 1.15, sy - 0.05), (-sw * 0.3, sy - 0.22), (sw * 0.4, sy - 0.22), (sw * 1.15, sy - 0.02),
                     (sw * 1.1, sy + 0.4), (sw * 0.75, sy + 0.32), (sw * 0.55, sy + 0.42), (-sw * 0.55, sy + 0.35), (-sw * 0.85, sy + 0.45), (-sw * 1.2, sy + 0.35)], 0.07)
        m = cv.sub(m, cv.ellipse((0.1, sy - 0.05), 0.42, 0.3))
        m = m + 0.03 * np.sin(cv.X * 40) * (cv.Y > sy + 0.25)
        cv.paint(m, hexc('6E4A30'), R=0.3, pattern=fur)
        # bear head on near shoulder
        bh = (-sw * 0.95, sy - 0.3)
        hd = cv.smin(cv.ellipse(bh, 0.36, 0.3), cv.ellipse((bh[0] - 0.12, bh[1] + 0.22), 0.2, 0.15), 0.08)
        for ex in (-0.28, 0.24):
            cv.paint(cv.circle((bh[0] + ex, bh[1] - 0.24), 0.1), hexc('6E4A30'), R=0.08)
        cv.paint(hd, hexc('7A5236'), R=0.3, pattern=fur)
        cv.paint(cv.ellipse((bh[0] - 0.18, bh[1] + 0.27), 0.08, 0.06), hexc('2A1A14'), R=0.05, line=0.4)
        cv.flat(cv.ellipse((bh[0] - 0.02, bh[1] + 0.02), 0.05, 0.025, rot=0.3), hexc('1A1010'))
        cv.flat(cv.ellipse((bh[0] + 0.18, bh[1] + 0.0), 0.045, 0.022, rot=-0.3), hexc('1A1010'))
        # claws dangling on chest
        for k, xx in enumerate((-0.35, -0.2)):
            cv.paint(cv.poly([(xx, sy + 0.4), (xx + 0.06, sy + 0.42), (xx + 0.02, sy + 0.58)], 0.01), hexc('E8DCC0'), R=0.03, line=0.5)

    def wolf_back(self):
        cv, c = self.cv, self.c
        sw, sy = c['sw'], self.sh_y
        hx, hy = self.head
        pts = [(hx - 0.5, hy - 0.3), (hx + 0.3, hy - 0.45), (sw * 0.9, sy + 0.1), (sw * 0.95, sy + 1.3), (sw * 0.5, sy + 2.0), (0.0, sy + 1.7),
               (-sw * 0.5, sy + 2.1), (-sw * 1.0, sy + 1.3), (-sw * 1.0, sy + 0.2)]
        d = cv.poly(pts, 0.06) + 0.035 * np.sin(cv.X * 36) * (cv.Y > sy + 1.2)
        fur = self.fur()
        cv.paint(d, hexc('6C6A70'), R=0.5, pattern=fur, dim=0.85)

    def wolf_front(self):
        cv, c = self.cv, self.c
        hx, hy = self.head
        hr = c['hr']
        sw, sy = c['sw'], self.sh_y
        fur = self.fur()
        grey = hexc('8A8890')
        if self.t >= 5:
            # wolf pelt mantle over the barmitsa
            m = cv.poly([(-sw * 1.05, sy + 0.0), (sw * 1.0, sy + 0.0), (sw * 1.05, sy + 0.4), (-sw * 1.1, sy + 0.42)], 0.08)
            m = m + 0.03 * np.sin(cv.X * 40) * (cv.Y > sy + 0.3)
            cv.paint(m, grey, R=0.3, pattern=fur)
            return
        # hood around face
        hood = cv.smin(cv.circle((hx - 0.05, hy - 0.05), hr * 1.28), cv.ellipse((hx - 0.25, hy + 0.45), hr * 0.9, hr * 1.0), 0.1)
        face_hole = cv.ellipse((hx + 0.18, hy + 0.12), hr * 0.78, hr * 0.95)
        hood = cv.sub(hood, face_hole)
        hood = cv.smin(hood, cv.ellipse((-sw * 0.72, sy + 0.12), 0.36, 0.22, rot=-0.3), 0.08)
        hood = cv.smin(hood, cv.ellipse((sw * 0.7, sy + 0.1), 0.34, 0.2, rot=0.3), 0.08)
        hood = np.minimum(hood, cv.path([(-0.45, sy + 0.05), (-0.42, sy + 0.4), (-0.35, sy + 0.62)], 0.09, 0.07))
        hood = np.minimum(hood, cv.path([(0.55, sy + 0.05), (0.52, sy + 0.38), (0.45, sy + 0.58)], 0.085, 0.065))
        cv.paint(hood, grey, R=0.35, pattern=fur)
        # wolf muzzle above the forehead + ears
        for ex, ey in ((-0.42, -0.78), (0.02, -0.82)):
            ear = cv.poly([(hx + ex - 0.14, hy + ey + 0.3), (hx + ex + 0.02, hy + ey - 0.05), (hx + ex + 0.16, hy + ey + 0.32)], 0.03)
            cv.paint(ear, grey * 0.9, R=0.1)
            cv.flat(cv.poly([(hx + ex - 0.06, hy + ey + 0.28), (hx + ex + 0.02, hy + ey + 0.1), (hx + ex + 0.08, hy + ey + 0.28)]), hexc('4A3A40'))
        snout = cv.smin(cv.ellipse((hx + 0.3, hy - hr * 0.98), 0.3, 0.12, rot=0.2), cv.circle((hx + 0.02, hy - hr * 1.08), 0.2), 0.1)
        cv.paint(snout, grey * 1.05, R=0.2, pattern=fur)
        cv.paint(cv.circle((hx + 0.58, hy - hr * 0.86), 0.05), hexc('1A1418'), R=0.04, line=0.4)
        cv.flat(cv.ellipse((hx + 0.15, hy - hr * 1.1), 0.05, 0.022, rot=0.2), hexc('1A1418'))
        for k in range(3):
            xx = hx + 0.25 + k * 0.09
            cv.paint(cv.poly([(xx, hy - hr * 0.82), (xx + 0.04, hy - hr * 0.82), (xx + 0.02, hy - hr * 0.7)]), hexc('EDE6D8'), R=0.02, line=0.4, cast=False)

    def braid(self):
        cv, c = self.cv, self.c
        hx, hy = self.head
        pts = [(hx - 0.35, hy - 0.05), (hx - 0.55, hy + 0.5), (hx - 0.6, hy + 1.1), (hx - 0.5, hy + 1.6)]
        d = cv.path(pts, 0.11, 0.06)
        pat = 1 - 0.3 * np.clip(np.sin((cv.Y - cv.X * 0.6) * 28), 0, 1)
        cv.paint(d, c['hair'], R=0.12, pattern=pat)
        cv.paint(cv.ellipse((hx - 0.5, hy + 1.62), 0.07, 0.05), RED, R=0.04, line=0.5)
        tip = cv.poly([(hx - 0.57, hy + 1.66), (hx - 0.43, hy + 1.66), (hx - 0.45, hy + 1.9), (hx - 0.55, hy + 1.88)], 0.02)
        cv.paint(tip, c['hair'], R=0.05)

    def ribbons_back(self):
        cv, c = self.cv, self.c
        sw, sy = c['sw'], self.sh_y
        specs = [((sw * 0.7, sy + 0.35), 1.0, 0.0), ((-sw * 0.85, sy + 0.9), -1.0, 0.6), ((sw * 0.45, self.waist_y + 0.05), 1.0, 1.3)]
        for (x0, y0), dirx, ph in specs:
            pts = [(x0 + dirx * 0.15 * k + dirx * 0.05 * k * k, y0 + 0.22 * k + 0.07 * np.sin(k * 1.7 + ph)) for k in range(6)]
            d = cv.path(pts, 0.085, 0.06)
            d = d + 0.02 * np.sin(cv.Y * 30)
            emb = 1 - 0.35 * ((np.abs(((cv.X + cv.Y) * 16) % 2 - 1) < 0.3) & (np.abs(((cv.X - cv.Y) * 16) % 2 - 1) < 0.3))
            cv.paint(d, hexc('E6DCC4'), R=0.06, line=0.7, dim=0.85, pattern=emb)
            tail = cv.inter(d, -(cv.circle(pts[-1], 0.2)))
            cv.paint(tail, RED, R=0.04, line=0.5, dim=0.85, cast=False)

    def fur(self):
        cv = self.cv
        s = np.sin(cv.X * 46 + cv.n_mid * 14 + np.sin(cv.Y * 7) * 1.5)
        return 1 - 0.22 * np.clip(s, 0, 1) ** 2 + 0.06 * np.clip(-s, 0, 1)

    def post_glow(self):
        pass


def render(cfg, tier, S=180, down=2):
    h = Hero(cfg, tier, S)
    cv = h.build()
    return cv.image(down)

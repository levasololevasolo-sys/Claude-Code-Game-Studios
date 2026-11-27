"""Tiny SDF-based 2D 'ink and paint' renderer (numpy + PIL).
Units: 1 unit ~ head height. y grows downward, ground at y=0."""
import numpy as np
from PIL import Image, ImageFilter

INK = np.array([0x12, 0x0D, 0x12]) / 255.0


def hexc(h):
    h = h.lstrip('#')
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)]) / 255.0


def value_noise(h, w, cells, seed):
    rng = np.random.default_rng(seed)
    g = rng.random((max(2, int(h / w * cells)) + 2, cells + 2)).astype(np.float32)
    im = Image.fromarray((g * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)
    return np.asarray(im).astype(np.float32) / 255.0


class Canvas:
    def __init__(self, x0, x1, y0, y1, S, seed=1):
        self.S = S
        self.W = int((x1 - x0) * S)
        self.H = int((y1 - y0) * S)
        xs = x0 + (np.arange(self.W) + 0.5) / S
        ys = y0 + (np.arange(self.H) + 0.5) / S
        self.X, self.Y = np.meshgrid(xs.astype(np.float32), ys.astype(np.float32))
        self.rgb = np.zeros((self.H, self.W, 3), np.float32)
        self.a = np.zeros((self.H, self.W), np.float32)
        self.glow = np.zeros((self.H, self.W, 3), np.float32)
        self.union = np.full((self.H, self.W), 1e3, np.float32)
        self.n_lo = value_noise(self.H, self.W, 9, seed) - 0.5
        self.n_mid = value_noise(self.H, self.W, 40, seed + 1) - 0.5
        self.n_hi = value_noise(self.H, self.W, 140, seed + 2) - 0.5
        # brush streak noise: stretched diagonally
        st = value_noise(self.H, self.W // 6 + 2, 60, seed + 3)
        st = np.asarray(Image.fromarray((st * 255).astype(np.uint8)).resize((self.W, self.H), Image.BICUBIC)).astype(np.float32) / 255
        self.n_streak = np.roll(st, 0, 0) - 0.5
        self.L = np.array([-0.55, -0.7, 0.62], np.float32)
        self.L /= np.linalg.norm(self.L)

    # ---------------- primitives -----------------
    def circle(self, c, r):
        return np.hypot(self.X - c[0], self.Y - c[1]) - r

    def ellipse(self, c, rx, ry, rot=0.0):
        x = self.X - c[0]; y = self.Y - c[1]
        if rot:
            cs, sn = np.cos(rot), np.sin(rot)
            x, y = cs * x + sn * y, -sn * x + cs * y
        k = np.hypot(x / rx, y / ry)
        return (k - 1.0) * min(rx, ry) * np.minimum(1.0, 0.5 + 0.5 * k)

    def cone(self, a, b, r1, r2):
        """iq round cone (tapered capsule)."""
        X, Y = self.X, self.Y
        ax, ay = a; bx, by = b
        bax, bay = bx - ax, by - ay
        l2 = bax * bax + bay * bay
        rr = r1 - r2
        a2 = l2 - rr * rr
        il2 = 1.0 / l2
        pax, pay = X - ax, Y - ay
        y = pax * bax + pay * bay
        z = y - l2
        qx = pax * l2 - bax * y; qy = pay * l2 - bay * y
        x2 = qx * qx + qy * qy
        y2 = y * y * l2
        z2 = z * z * l2
        k = np.sign(rr) * rr * rr * x2
        d3 = (np.sqrt(np.maximum(x2 * a2 * il2, 0)) + y * rr) * il2 - r1
        d1 = np.sqrt(x2 + z2) * il2 - r2
        d2 = np.sqrt(x2 + y2) * il2 - r1
        return np.where(np.sign(z) * a2 * z2 > k, d1, np.where(np.sign(y) * a2 * y2 < k, d2, d3))

    def seg(self, a, b, r):
        return self.cone(a, b, r, r)

    def path(self, pts, r1, r2=None):
        if r2 is None:
            r2 = r1
        n = len(pts) - 1
        d = None
        for i in range(n):
            ra = r1 + (r2 - r1) * i / n
            rb = r1 + (r2 - r1) * (i + 1) / n
            di = self.cone(pts[i], pts[i + 1], ra, rb)
            d = di if d is None else np.minimum(d, di)
        return d

    def poly(self, pts, r=0.0):
        X, Y = self.X, self.Y
        pts = [tuple(p) for p in pts]
        n = len(pts)
        d = (X - pts[0][0]) ** 2 + (Y - pts[0][1]) ** 2
        s = np.ones_like(X)
        j = n - 1
        for i in range(n):
            vix, viy = pts[i]; vjx, vjy = pts[j]
            ex, ey = vjx - vix, vjy - viy
            wx, wy = X - vix, Y - viy
            t = np.clip((wx * ex + wy * ey) / (ex * ex + ey * ey + 1e-9), 0, 1)
            bx, by = wx - ex * t, wy - ey * t
            d = np.minimum(d, bx * bx + by * by)
            c1 = Y >= viy; c2 = Y < vjy; c3 = ex * wy > ey * wx
            flip = (c1 & c2 & c3) | (~c1 & ~c2 & ~c3)
            s = np.where(flip, -s, s)
            j = i
        return s * np.sqrt(d) - r

    @staticmethod
    def smin(a, b, k):
        h = np.clip(0.5 + 0.5 * (b - a) / k, 0, 1)
        return b * (1 - h) + a * h - k * h * (1 - h)

    @staticmethod
    def inter(a, b):
        return np.maximum(a, b)

    @staticmethod
    def sub(a, b):
        return np.maximum(a, -b)

    # ---------------- painting -----------------
    def paint(self, d, col, R=0.3, line=1.0, shade=True, rim=True, cast=True,
              dim=1.0, tex=1.0, pattern=None, wobble=1.0, glow=None, flat=False,
              alpha=1.0, hl=1.0, union=True):
        S = self.S
        col = np.asarray(col, np.float32)
        d = d + self.n_hi * 0.005 * wobble + self.n_mid * 0.012 * wobble
        cov = np.clip(0.5 - d * S, 0, 1) * alpha
        if cov.max() <= 0:
            return
        gy, gx = np.gradient(d, 1.0 / S)
        gn = np.hypot(gx, gy) + 1e-6
        gx = gx / gn; gy = gy / gn
        # cast shadow onto what is already painted
        if cast:
            sh = np.roll(cov, (int(0.05 * S), int(0.035 * S)), (0, 1))
            sh = np.asarray(Image.fromarray((sh * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(S * 0.02))).astype(np.float32) / 255
            self.rgb *= (1 - 0.32 * sh * (1 - cov))[..., None]
        c = np.broadcast_to(col, self.rgb.shape).copy()
        if shade and not flat:
            t = np.clip(-d / R, 0, 1)
            h = np.sqrt(1 - (1 - t) ** 2)
            nx, ny, nz = gx * (1 - h), gy * (1 - h), h + 0.05
            nn = np.sqrt(nx * nx + ny * ny + nz * nz)
            lam = (nx * self.L[0] + ny * self.L[1] + nz * self.L[2]) / nn
            lam = lam + self.n_mid * 0.08 + self.n_streak * 0.06
            def step(v, e, w=0.05):
                return np.clip((v - e) / w + 0.5, 0, 1)
            s_mid = step(lam, 0.34)
            s_hi = step(lam, 0.86) * hl
            s_deep = 1 - step(lam, -0.05)
            shadow = col * np.array([0.70, 0.54, 0.60]) + np.array([0.02, 0.0, 0.04])
            deep = col * np.array([0.46, 0.34, 0.44]) + np.array([0.02, 0.0, 0.04])
            hi = np.minimum(col * 1.10 + np.array([0.07, 0.05, 0.0]), 1)
            c = shadow[None, None, :] * np.ones_like(c)
            c = c * (1 - s_mid[..., None]) + col * s_mid[..., None]
            c = c * (1 - s_hi[..., None]) + hi * s_hi[..., None]
            c = c * (1 - s_deep[..., None] * 0.85) + deep * (s_deep[..., None] * 0.85)
        if pattern is not None:
            c = c * pattern[..., None] if pattern.ndim == 2 else c * pattern
        # painterly texture
        c = c * (1 + (self.n_lo * 0.09 + self.n_mid * 0.05 + self.n_streak * 0.05) * tex)[..., None]
        if rim and not flat:
            band = np.clip(1 - (-d * S) / (0.05 * S), 0, 1) * (d < 0)
            rimk = np.clip(gx * 0.9 - gy * 0.2 - 0.25, 0, 1) * band
            c = c + rimk[..., None] * np.array([1.0, 0.72, 0.32]) * 0.55
        c = c * dim
        if line > 0:
            wpx = line * S * 0.03 * (0.7 + 0.6 * np.clip(gx * 0.55 + gy * 0.75 + 0.35, 0, 1.4))
            inside_line = np.clip((wpx + d * S) + 0.5, 0, 1)  # 1 where -d*S < wpx
            c = c * (1 - inside_line[..., None]) + INK * inside_line[..., None]
        c = np.clip(c, 0, 1)
        self.rgb = self.rgb * (1 - cov[..., None]) + c * cov[..., None]
        self.a = np.maximum(self.a, cov)
        if union:
            self.union = np.minimum(self.union, d)
        if glow is not None:
            gcol, rad, strength = glow
            g = np.exp(-np.maximum(d, 0) / rad) * strength
            self.glow += g[..., None] * np.asarray(gcol)

    def ink(self, d, w=1.0, col=None, alpha=1.0):
        """stroke-only (d is a thin shape): paint flat ink."""
        col = INK if col is None else np.asarray(col)
        d = d + self.n_hi * 0.002
        cov = np.clip(0.5 - d * self.S, 0, 1) * alpha
        self.rgb = self.rgb * (1 - cov[..., None]) + col * cov[..., None]
        self.a = np.maximum(self.a, cov)

    def flat(self, d, col, alpha=1.0, soft=0.0):
        d = d + self.n_hi * 0.002
        if soft:
            cov = np.clip(0.5 - d / soft, 0, 1) * alpha
        else:
            cov = np.clip(0.5 - d * self.S, 0, 1) * alpha
        self.rgb = self.rgb * (1 - cov[..., None]) + np.asarray(col) * cov[..., None]
        self.a = np.maximum(self.a, cov)

    def outer_outline(self, w=1.0):
        S = self.S
        d = self.union
        gy, gx = np.gradient(d, 1.0 / S)
        gn = np.hypot(gx, gy) + 1e-6
        gx, gy = gx / gn, gy / gn
        wpx = w * S * 0.04 * (0.65 + 0.7 * np.clip(gx * 0.55 + gy * 0.75 + 0.35, 0, 1.4))
        wpx = wpx * (1 + self.n_lo * 0.6)
        cov = np.clip(wpx - d * S + 0.5, 0, 1) * (d > -0.5 / S)
        cov = np.clip(cov, 0, 1)
        self.rgb = self.rgb * (1 - cov[..., None]) + INK * cov[..., None]
        self.a = np.maximum(self.a, cov)

    def image(self, down=2):
        rgb = np.clip(self.rgb + self.glow * (1.0), 0, 1)
        # glow also outside the figure: add alpha
        ga = np.clip(self.glow.max(axis=2), 0, 1) * 0.85
        a = np.maximum(self.a, ga)
        # premultiplied composite of glow outside the figure
        out_rgb = np.where(self.a[..., None] > 1e-3, rgb, np.clip(self.glow / (ga[..., None] + 1e-6), 0, 1))
        im = np.dstack([out_rgb, a])
        img = Image.fromarray((np.clip(im, 0, 1) * 255).astype(np.uint8), 'RGBA')
        if down > 1:
            img = img.resize((self.W // down, self.H // down), Image.LANCZOS)
        return img

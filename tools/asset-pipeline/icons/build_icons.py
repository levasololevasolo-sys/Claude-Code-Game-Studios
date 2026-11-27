#!/usr/bin/env python3
"""Builds the god signs, rune icons and door icons of «Навь» as SVG (art bible
§4.3 colours, §7 UI icons, §8 naming). Standard library only; vector art
authored as code. Output: assets/art/icons/ui_icon_{god,rune,door}_<id>.svg.

Run from the repo root:  python3 tools/asset-pipeline/icons/build_icons.py

Every icon is a 256x256 canvas. Shared look ("carved emblem"):
  * metal rim: gold linear gradient, dark contour, light bevel line on top,
    dark bevel line below, small beads (ornament);
  * enamel field: radial gradient from the light god colour to a deep tint;
  * pictogram: soft glow (wide translucent strokes, no SVG filters because
    Godot's ThorVG importer ignores most of them), dark contour, gradient
    fill, thin light highlight.
God signs use only folk shapes without hooks: the six-petal rosette
(громовик-«Перунов цвет»), horns and bear paw (Велес), three open wind curls
(Стрибог), three flame tongues over a hammer (Сварог), the ear of grain
(Жива), the rhomb «засеянное поле» (Род). No swastika-like forms.
"""
import json
import math
import os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
OUT = os.path.join(ROOT, "assets", "art", "icons")
DATA = os.path.join(ROOT, "assets", "data")

INK = "#140c07"
GOLD = ("#fff4c4", "#f0c25a", "#a8711f", "#4a2a0c")  # light, mid, deep, shadow
STONE = ("#8c8174", "#5d544a", "#332c25", "#16120e")
WOOD = ("#9a6a3e", "#6b4425", "#3e2614", "#1b0f07")


# ---------------------------------------------------------------- colour
def hex2rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def rgb2hex(c):
    return "#%02x%02x%02x" % tuple(max(0, min(255, round(v * 255))) for v in c)


def mix(a, b, t):
    ca, cb = hex2rgb(a), hex2rgb(b)
    return rgb2hex(tuple(x + (y - x) * t for x, y in zip(ca, cb)))


def tones(col):
    """light, base, deep, darkest of a god colour."""
    return (mix(col, "#ffffff", 0.6), col, mix(col, "#000000", 0.55), mix(col, "#05040a", 0.85))


# ---------------------------------------------------------------- svg helpers
class Svg:
    def __init__(self, prefix):
        self.defs = []
        self.body = []
        self.n = 0
        self.prefix = prefix

    def uid(self, k):
        self.n += 1
        return "%s_%s%d" % (self.prefix, k, self.n)

    def lin(self, stops, x1=0, y1=0, x2=0, y2=1):
        i = self.uid("l")
        s = "".join('<stop offset="%g" stop-color="%s" stop-opacity="%g"/>' % (o, c, a) for o, c, a in stops)
        self.defs.append('<linearGradient id="%s" x1="%g" y1="%g" x2="%g" y2="%g">%s</linearGradient>' % (i, x1, y1, x2, y2, s))
        return "url(#%s)" % i

    def rad(self, stops, cx=0.5, cy=0.5, r=0.5, fx=None, fy=None):
        i = self.uid("r")
        s = "".join('<stop offset="%g" stop-color="%s" stop-opacity="%g"/>' % (o, c, a) for o, c, a in stops)
        f = "" if fx is None else ' fx="%g" fy="%g"' % (fx, fy)
        self.defs.append('<radialGradient id="%s" cx="%g" cy="%g" r="%g"%s>%s</radialGradient>' % (i, cx, cy, r, f, s))
        return "url(#%s)" % i

    def clip(self, d):
        i = self.uid("c")
        self.defs.append('<clipPath id="%s"><path d="%s"/></clipPath>' % (i, d))
        return "url(#%s)" % i

    def add(self, s):
        self.body.append(s)

    def path(self, d, fill="none", stroke="none", w=0, op=1.0, extra=""):
        self.add('<path d="%s" fill="%s" stroke="%s" stroke-width="%g" stroke-linecap="round" stroke-linejoin="round" opacity="%g"%s/>' % (d, fill, stroke, w, op, extra))

    def text(self):
        return ('<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256">'
                "<defs>%s</defs>%s</svg>\n" % ("".join(self.defs), "".join(self.body)))


def circle_d(cx, cy, r):
    return "M%g %gA%g %g 0 1 0 %g %gA%g %g 0 1 0 %g %gZ" % (cx - r, cy, r, r, cx + r, cy, r, r, cx - r, cy)


def poly_d(pts):
    return "M" + " L".join("%.1f %.1f" % p for p in pts) + "Z"


def ngon(cx, cy, r, n, rot=-90.0):
    return [(cx + r * math.cos(math.radians(rot + k * 360.0 / n)), cy + r * math.sin(math.radians(rot + k * 360.0 / n))) for k in range(n)]


def transform_d(d, s, dx, dy):
    """Scales a path made by this file (absolute M/L/C/Q/A/Z commands) around 0,0 then moves it."""
    out, toks, i = [], d.replace(",", " ").replace("M", " M ").replace("L", " L ").replace("C", " C ").replace("Q", " Q ").replace("A", " A ").replace("Z", " Z ").split(), 0
    cmd = None
    while i < len(toks):
        t = toks[i]
        if t in "MLCQAZ":
            cmd = t
            out.append(t)
            i += 1
            continue
        if cmd == "A":
            rx, ry, rot, la, sw, x, y = toks[i:i + 7]
            out.append("%g %g %s %s %s %.1f %.1f" % (float(rx) * s, float(ry) * s, rot, la, sw, float(x) * s + dx, float(y) * s + dy))
            i += 7
        else:
            out.append("%.1f %.1f" % (float(toks[i]) * s + dx, float(toks[i + 1]) * s + dy))
            i += 2
    return " ".join(out)


# ---------------------------------------------------------------- pictogram renderer
# A pictogram = list of parts: ("f", d) filled shape, ("l", d, width) line,
# ("k", d) dark detail cut into the fill (eye pupil, notches).
def draw_picto(svg, parts, col, glow=True, metal=False):
    lt, base, deep, dark = tones(col)
    if metal:
        lt, base, deep = GOLD[0], GOLD[1], GOLD[2]
        fill = svg.lin([(0, lt, 1), (0.45, base, 1), (1, deep, 1)])
    else:  # bright on the dark enamel: near-white top, god colour below
        fill = svg.lin([(0, mix(lt, "#ffffff", 0.6), 1), (0.4, lt, 1), (1, base, 1)])
    if glow:
        for w, op in ((26, 0.10), (16, 0.16), (9, 0.22)):
            for p in parts:
                if p[0] in "kh":
                    continue
                pw = p[2] if p[0] == "l" else 0
                svg.path(p[1], fill="none", stroke=lt, w=pw + w, op=op)
    for p in parts:  # dark contour
        if p[0] == "f":
            svg.path(p[1], fill=INK, stroke=INK, w=7)
        elif p[0] == "l":
            svg.path(p[1], stroke=INK, w=p[2] + 7)
    for p in parts:  # body
        if p[0] == "f":
            svg.path(p[1], fill=fill)
        elif p[0] == "l":
            svg.path(p[1], stroke=fill, w=p[2])
    for p in parts:  # highlight and cut details
        if p[0] == "f":
            svg.path(p[1], stroke="#ffffff", w=1.6, op=0.55, extra=' transform="translate(-0.8 -1.2)"')
        elif p[0] == "l":
            svg.path(p[1], stroke="#ffffff", w=max(1.2, p[2] * 0.22), op=0.6, extra=' transform="translate(-0.6 -%g)"' % (p[2] * 0.2))
        elif p[0] == "k":
            svg.path(p[1], fill=INK, stroke=INK, w=1)
        elif p[0] == "h":  # glowing inner core (flame heart, glint)
            svg.path(p[1], fill=svg.lin([(0, "#ffffff", 1), (1, "#fff1c8", 0.85)]))


# ---------------------------------------------------------------- god sign shapes (centre 128,128, fit r~64)
def sign_perun():
    R, cx, cy = 34.0, 128.0, 128.0
    parts = [("l", circle_d(cx, cy, 2 * R + 2), 5)]
    for k in range(6):
        a = math.radians(-90 + k * 60)
        px, py = cx + 2 * R * math.cos(a) * 0.98, cy + 2 * R * math.sin(a) * 0.98
        r = R * 1.22
        parts.append(("f", "M%g %g A%g %g 0 0 1 %.1f %.1f A%g %g 0 0 1 %g %gZ" % (cx, cy, r, r, px, py, r, r, cx, cy)))
    parts.append(("k", circle_d(cx, cy, 5)))
    return parts


def sign_veles():
    horns = ("M128 132 C104 132 80 118 74 88 C72 76 76 64 84 56 C84 74 92 98 128 106 "
             "C164 98 172 74 172 56 C180 64 184 76 182 88 C176 118 152 132 128 132Z")
    pad = "M128 196 C104 196 98 178 104 166 C110 154 120 150 128 150 C136 150 146 154 152 166 C158 178 152 196 128 196Z"
    parts = [("f", horns), ("f", pad)]
    for x, y, r in ((101, 146, 8), (115, 136, 8.5), (141, 136, 8.5), (155, 146, 8)):
        parts.append(("f", circle_d(x, y, r)))
    return parts


def wind_curl(x0, y, x1, r):
    """Straight wind line from x0 that ends in an open (unhooked) curl at x1."""
    return "M%g %g L%g %g A%g %g 0 1 0 %g %g A%g %g 0 0 0 %g %g" % (
        x0, y, x1, y, r, r, x1, y - 2 * r, r * 0.55, r * 0.55, x1 - r * 0.9, y - r * 1.3)


def sign_stribog():
    return [("l", wind_curl(66, 104, 140, 16), 9), ("l", wind_curl(80, 140, 162, 18), 9), ("l", wind_curl(62, 176, 130, 14), 9)]


def flame(cx, by, h, w, lean=0.0):
    t = by - h
    return ("M%g %g C%g %g %g %g %g %g C%g %g %g %g %g %g C%g %g %g %g %g %gZ" % (
        cx, by, cx - w, by - 2, cx - w * 1.1, by - h * 0.5, cx - w * 0.3, by - h * 0.62,
        cx - w * 0.1 + lean * 0.5, t + h * 0.3, cx + lean - w * 0.2, t + h * 0.12, cx + lean, t,
        cx + w * 1.2, by - h * 0.45, cx + w, by - 2, cx, by))


def sign_svarog():
    parts = [("f", flame(128, 132, 78, 20)), ("f", flame(96, 136, 52, 15, -8)), ("f", flame(160, 136, 52, 15, 8))]
    parts.append(("f", "M78 146 L100 150 L156 150 L178 142 L182 172 L156 166 L100 166 L78 170Z"))  # hammer head
    parts.append(("f", "M121 166 L135 166 L136 206 C136 212 120 212 120 206Z"))  # handle
    parts.append(("k", "M104 156 L152 156 L152 160 L104 160Z"))
    return parts


def sign_zhiva():
    parts = [("l", "M128 204 C126 170 130 130 128 80", 6)]
    for k, y in enumerate((150, 126, 102)):
        for s in (-1, 1):
            x = 128 + s * 13
            parts.append(("f", "M128 %g C%g %g %g %g %g %g C%g %g %g %g 128 %gZ" % (
                y + 8, x - s * 2, y + 6, x + s * 8, y - 6, x + s * 4, y - 20, x - s * 10, y - 14, x - s * 12, y - 4, y + 8)))
    parts.append(("f", "M128 84 C120 70 122 56 128 44 C134 56 136 70 128 84Z"))
    for s in (-1, 1):
        parts.append(("f", "M128 200 C%g 200 %g 186 %g 158 C%g 168 %g 190 128 206Z" % (128 + s * 30, 128 + s * 52, 128 + s * 62, 128 + s * 66, 128 + s * 40)))
    return parts


def sign_rod():
    cx, cy = 128.0, 128.0
    big = [(cx, cy - 66), (cx + 66, cy), (cx, cy + 66), (cx - 66, cy)]
    inner = [(cx, cy - 50), (cx + 50, cy), (cx, cy + 50), (cx - 50, cy)]
    parts = [("l", poly_d(big), 6), ("l", poly_d(inner), 4), ("l", "M%g %g L%g %g M%g %g L%g %g" % (cx - 25, cy - 25, cx + 25, cy + 25, cx + 25, cy - 25, cx - 25, cy + 25), 4)]
    for dx, dy in ((0, -25), (25, 0), (0, 25), (-25, 0)):
        x, y = cx + dx, cy + dy
        parts.append(("f", poly_d([(x, y - 9), (x + 9, y), (x, y + 9), (x - 9, y)])))
    for dx, dy in ((0, -84), (84, 0), (0, 84), (-84, 0)):
        x, y = cx + dx * 0.95, cy + dy * 0.95
        parts.append(("f", circle_d(x, y, 5)))
    return parts


SIGNS = {"perun": sign_perun, "veles": sign_veles, "stribog": sign_stribog, "svarog": sign_svarog, "zhiva": sign_zhiva, "rod": sign_rod}


# ---------------------------------------------------------------- medallion (god sign + door icons)
def medallion(svg, col, rim=GOLD, beads=24):
    lt, base, deep, dark = tones(col)
    svg.path(circle_d(128, 128, 127), fill=svg.rad([(0.62, lt, 0.55), (0.8, base, 0.22), (1, base, 0)]))
    svg.path(circle_d(128, 128, 114), fill=INK)
    svg.path(circle_d(128, 128, 111), fill=svg.lin([(0, rim[0], 1), (0.35, rim[1], 1), (0.75, rim[2], 1), (1, rim[3], 1)]))
    svg.path(circle_d(128, 128, 109), stroke="#ffffff", w=1.5, op=0.45, extra=' transform="translate(0 -1)"')
    for k in range(beads):
        a = math.radians(k * 360.0 / beads)
        x, y = 128 + 102 * math.cos(a), 128 + 102 * math.sin(a)
        svg.path(circle_d(x, y, 3.6), fill=svg.rad([(0, rim[0], 1), (1, rim[2], 1)], fx=0.35, fy=0.3), stroke=INK, w=1)
    svg.path(circle_d(128, 128, 94), fill=INK)
    svg.path(circle_d(128, 128, 92), fill=svg.lin([(0, rim[3], 1), (1, rim[0], 1)]))
    svg.path(circle_d(128, 128, 88), fill=svg.rad([(0, mix(base, lt, 0.3), 1), (0.55, deep, 1), (1, dark, 1)], cy=0.42, r=0.6))
    for k in range(12):  # thin enamel rays (cloisonné wires)
        a = math.radians(k * 30 + 15)
        svg.path("M%.1f %.1f L%.1f %.1f" % (128 + 60 * math.cos(a), 128 + 60 * math.sin(a), 128 + 86 * math.cos(a), 128 + 86 * math.sin(a)), stroke=rim[1], w=1.4, op=0.35)
    svg.path(circle_d(128, 128, 88), stroke=rim[1], w=1.2, op=0.6)


def gloss(svg, d="M60 100 C70 58 186 58 196 100 C170 82 86 82 60 100Z"):
    svg.path(d, fill=svg.lin([(0, "#ffffff", 0.32), (1, "#ffffff", 0)]))


def god_sign(svg, g, col):
    medallion(svg, col)
    draw_picto(svg, SIGNS[g](), col, glow=True, metal=True)
    gloss(svg)


# ---------------------------------------------------------------- rune pictograms (centre ~128,132)
def p_flame():
    return [("f", flame(128, 190, 120, 36)), ("k", flame(128, 186, 64, 16)), ("h", flame(128, 182, 44, 9))]


def p_bolt(dx=0.0, s=1.0):
    pts = [(146, 56), (100, 134), (128, 134), (106, 206), (162, 116), (132, 116), (152, 56)]
    return [("f", poly_d([(128 + (x - 128) * s + dx, 130 + (y - 130) * s) for x, y in pts]))]


def p_chain():
    nodes = [(72, 92), (126, 150), (184, 96)]
    parts = [("l", "M%g %g L98 136 L92 116 L126 150 L150 112 L156 132 L184 96" % nodes[0], 6)]
    for x, y in nodes:
        parts.append(("f", circle_d(x, y, 13)))
        parts.append(("k", circle_d(x, y, 4)))
    return parts


def p_burst():
    parts = p_bolt(0, 0.72)
    for k in range(8):
        a = math.radians(k * 45 + 22)
        parts.append(("l", "M%.1f %.1f L%.1f %.1f" % (128 + 64 * math.cos(a), 130 + 64 * math.sin(a), 128 + 84 * math.cos(a), 130 + 84 * math.sin(a)), 6))
    return parts


def p_cuts():
    return [("l", "M70 176 C110 150 150 110 182 64", 8), ("l", "M86 196 C126 168 162 132 192 92", 6), ("l", "M64 148 C96 128 128 96 150 62", 5)]


def p_whirl():
    return [("l", "M128 132 A12 12 0 0 1 152 132 A24 24 0 0 1 104 132 A36 36 0 0 1 176 132 A48 48 0 0 1 80 132", 8)]


def p_gust():
    return [("l", wind_curl(62, 112, 150, 18), 8), ("l", wind_curl(80, 156, 168, 20), 8), ("l", "M70 196 L150 196", 6)]


def p_eye(cy=130, s=1.0):
    def q(x, y):
        return "%.1f %.1f" % (128 + (x - 128) * s, cy + (y - 130) * s)
    eye = "M%s C%s %s %s C%s %s %sZ" % (q(52, 130), q(84, 90), q(172, 90), q(204, 130), q(172, 170), q(84, 170), q(52, 130))
    r = 26 * s
    slit = "M%s C%s %s %s C%s %s %sZ" % (q(128, 108), q(136, 120), q(136, 140), q(128, 152), q(120, 140), q(120, 120), q(128, 108))
    lash = "M%s L%s M%s L%s M%s L%s" % (q(128, 92), q(128, 74), q(96, 98), q(86, 82), q(160, 98), q(170, 82))
    return [("l", lash, 6 * s), ("f", eye), ("k", circle_d(128, cy, r)), ("f", circle_d(128, cy, r - 5 * s)), ("k", slit), ("h", circle_d(128 - 10 * s, cy - 10 * s, 4.5 * s))]


def p_roots():
    return [("l", "M128 60 L128 128", 9), ("l", "M128 120 C110 140 84 150 66 186", 7), ("l", "M128 120 C146 140 172 150 190 186", 7),
            ("l", "M128 124 C126 150 132 172 126 204", 7), ("l", "M100 152 C92 170 98 186 86 202", 5), ("l", "M158 152 C166 170 160 186 172 202", 5),
            ("f", "M128 66 C112 54 106 40 110 28 C124 36 130 48 128 66Z")]


def p_shield(leaf=True):
    parts = [("f", "M128 58 C150 70 170 72 188 70 C190 130 170 172 128 204 C86 172 66 130 68 70 C86 72 106 70 128 58Z")]
    if leaf:
        parts.append(("k", "M128 170 C104 150 104 118 128 92 C152 118 152 150 128 170Z"))
    return parts


def p_drop():
    return [("f", "M128 52 C150 92 178 120 178 152 C178 182 156 202 128 202 C100 202 78 182 78 152 C78 120 106 92 128 52Z"),
            ("k", "M106 150 C104 166 112 178 124 182 C112 172 110 162 112 150Z")]


def p_rings():
    return [("l", circle_d(128, 132, 22), 7), ("l", "M80 132 A48 48 0 0 1 176 132", 6), ("l", "M54 132 A74 74 0 0 1 202 132", 5), ("f", circle_d(128, 132, 10))]


def p_wisps():
    return [("f", flame(96, 180, 66, 18, -6)), ("f", flame(160, 168, 74, 20, 6)), ("f", flame(128, 120, 50, 13))]


def p_steps():
    parts = []
    for x, y in ((86, 186), (128, 140), (170, 94)):
        parts.append(("f", "M%g %g C%g %g %g %g %g %g C%g %g %g %g %g %gZ" % (x, y - 14, x - 16, y - 12, x - 14, y + 22, x, y + 22, x + 14, y + 22, x + 16, y - 12, x, y - 14)))
        for dx, dy, r in ((-10, -24, 4.5), (0, -28, 5), (10, -24, 4.5)):
            parts.append(("f", circle_d(x + dx, y + dy, r)))
    return parts


def p_sword():
    return [("f", "M128 44 L142 70 L140 158 L116 158 L114 70Z"), ("f", "M88 158 L168 158 L168 170 L88 170Z"), ("l", "M128 172 L128 200", 9), ("f", circle_d(128, 208, 8)), ("k", "M127 68 L129 68 L129 152 L127 152Z")]


def p_arc():
    return [("l", "M60 170 A80 80 0 0 1 196 110", 10), ("f", "M196 88 L214 122 L178 120Z")] + [("f", "M100 196 L112 120 L124 196Z")]


def p_cup():
    return [("f", "M76 72 L180 72 C180 120 160 140 128 144 C96 140 76 120 76 72Z"), ("f", "M120 144 L136 144 L134 180 L122 180Z"), ("f", "M94 182 L162 182 L166 196 L90 196Z"), ("k", "M86 84 L170 84 C168 96 166 104 162 110 L94 110 C90 104 88 96 86 84Z")]


def p_heart():
    return [("f", "M128 196 C78 160 60 132 60 104 C60 80 78 64 98 64 C112 64 122 72 128 84 C134 72 144 64 158 64 C178 64 196 80 196 104 C196 132 178 160 128 196Z")]


def p_amulet_spark():
    return [("l", "M90 58 C100 88 156 88 166 58", 5), ("f", circle_d(128, 136, 44)), ("k", circle_d(128, 136, 22)), ("f", poly_d([(128, 116), (134, 130), (148, 136), (134, 142), (128, 156), (122, 142), (108, 136), (122, 130)]))]


def p_ember():
    return [("f", flame(128, 172, 112, 34)), ("h", flame(128, 166, 46, 11)), ("f", "M62 178 C90 160 166 160 194 178 C184 202 72 202 62 178Z"),
            ("k", circle_d(100, 182, 4)), ("k", circle_d(128, 186, 4)), ("k", circle_d(156, 182, 4))]


def p_boot():
    return [("f", "M100 60 L140 60 L140 140 C164 142 186 152 190 176 L190 190 L92 190 L92 140Z"), ("l", "M54 120 L84 120 M62 146 L86 146 M50 172 L82 172", 6)]


def p_wings():
    w = []
    for s in (-1, 1):
        w.append(("f", "M128 120 C%g 92 %g 76 %g 66 C%g 100 %g 132 %g 160 C%g 156 %g 150 128 140Z" % (128 + s * 30, 128 + s * 60, 128 + s * 84, 128 + s * 86, 128 + s * 70, 128 + s * 40, 128 + s * 24, 128 + s * 10)))
    w.append(("f", "M128 92 C138 92 142 104 138 130 L128 190 L118 130 C114 104 118 92 128 92Z"))
    return w


def p_coins():
    parts = []
    for i in range(4):  # stack of grivnas, then one coin standing on top
        y = 196 - i * 18
        parts.append(("f", "M76 %g C76 %g 156 %g 156 %g L156 %g C156 %g 76 %g 76 %gZ" % (y - 8, y - 24, y - 24, y - 8, y, y + 16, y + 16, y)))
    parts.append(("f", circle_d(164, 104, 34)))
    parts.append(("k", circle_d(164, 104, 24)))
    parts.append(("f", poly_d([(164, 86), (176, 104), (164, 122), (152, 104)])))
    return parts


def p_sickle():
    return [("f", "M150 52 C96 52 62 92 66 140 C80 106 108 84 150 82 C176 82 192 96 196 112 C200 84 184 52 150 52Z"), ("l", "M70 142 L104 204", 10)]


def p_crown():
    return [("f", "M66 176 L58 92 L96 128 L128 72 L160 128 L198 92 L190 176Z"), ("f", "M64 182 L192 182 L192 200 L64 200Z"),
            ("k", circle_d(128, 150, 9)), ("k", circle_d(92, 156, 6)), ("k", circle_d(164, 156, 6))]


def p_lair():
    return [("f", "M128 58 C176 58 196 92 192 128 C190 148 178 158 172 170 L168 196 L88 196 L84 170 C78 158 66 148 64 128 C60 92 80 58 128 58Z"),
            ("k", "M88 120 C96 108 114 110 118 128 C108 140 94 138 88 120Z"), ("k", "M168 120 C160 108 142 110 138 128 C148 140 162 138 168 120Z"),
            ("k", "M120 150 L128 138 L136 150Z"), ("k", "M100 178 L104 196 L112 178 L120 196 L128 178 L136 196 L144 178 L152 196 L156 178Z")]


def p_gate():
    return [("f", "M70 204 L70 110 C70 70 186 70 186 110 L186 204 L162 204 L162 116 C162 92 94 92 94 116 L94 204Z"), ("f", "M112 168 L144 168 L144 156 L170 182 L144 208 L144 196 L112 196Z")]


def p_house():
    return [("f", "M128 52 L204 120 L184 120 L184 200 L72 200 L72 120 L52 120Z"), ("k", "M112 200 L112 158 L144 158 L144 200Z"), ("k", "M120 108 L136 108 L136 124 L120 124Z")]


def p_fire():
    return p_wisps()[:2] + [("f", flame(128, 172, 96, 26)), ("l", "M72 196 L184 180 M72 180 L184 196", 8)]


def p_pouch():
    return [("f", "M100 80 L156 80 L148 98 C188 116 200 160 184 186 C170 206 86 206 72 186 C56 160 68 116 108 98Z"), ("l", "M98 92 C116 100 140 100 158 92", 5), ("k", poly_d([(128, 130), (140, 150), (128, 170), (116, 150)]))]


def combine(a, b, sa=0.72, sb=0.72, da=(-26, -14), db=(26, 18)):
    out = []
    for parts, s, (dx, dy) in ((a, sa, da), (b, sb, db)):
        for p in parts:
            d = transform_d(p[1], s, 128 * (1 - s) + dx, 130 * (1 - s) + dy)
            out.append((p[0], d, p[2] * s) if p[0] == "l" else (p[0], d))
    return out


STATUS_PICTO = {"burn": p_flame, "shock": p_bolt, "cuts": p_cuts, "curse": p_eye, "root": p_roots, "discharge": p_burst}
RUNE_PICTO = {
    "svarog_f": lambda: combine(p_flame(), p_rings(), 0.75, 0.9, (0, -10), (0, 12)),
    "svarog_p": p_ember, "svarog_d": lambda: combine(p_steps(), p_flame(), 0.8, 0.6, (-18, 10), (34, -26)),
    "perun_d": lambda: combine(p_steps(), p_bolt(), 0.8, 0.62, (-18, 10), (34, -24)), "perun_p": p_chain,
    "stribog_d": p_whirl, "stribog_f": p_gust, "stribog_p": lambda: combine(p_boot(), p_gust(), 0.8, 0.55, (-10, 6), (44, -40)),
    "veles_d": p_steps, "veles_f": lambda: p_eye(130, 1.1), "veles_p": p_wisps,
    "zhiva_s": p_shield, "zhiva_d": p_rings, "zhiva_f": p_drop, "zhiva_p": p_roots,
    "edge": p_sword, "arc": p_arc, "thirst": lambda: combine(p_sword(), p_drop(), 0.85, 0.42, (-18, 0), (40, 34)),
    "kindling": p_amulet_spark, "linger": p_ember, "echo": p_rings, "swift": p_boot, "moth": p_wings, "magnet": p_coins,
    "reaper": p_sickle, "rest": p_heart, "wrath": p_crown,
    "duo_firestorm": lambda: combine(p_flame(), p_bolt()), "duo_firewind": lambda: combine(p_whirl(), p_flame(), 0.9, 0.6, (0, 0), (0, -6)),
    "duo_pyre": lambda: combine(p_flame(), p_eye(), 0.9, 0.5, (0, -4), (0, 24)), "duo_cleanse": lambda: combine(p_roots(), p_flame(), 0.85, 0.55, (0, 8), (0, -30)),
    "duo_storm": lambda: combine(p_gust(), p_bolt()), "duo_black": lambda: combine(p_eye(), p_bolt(), 0.8, 0.7, (0, 18), (0, -16)),
    "duo_lifebolt": lambda: combine(p_bolt(), p_roots()), "duo_naviwind": lambda: combine(p_cuts(), p_eye(), 0.8, 0.6, (-18, 10), (30, -28)),
    "duo_spring": lambda: combine(p_cuts(), p_roots()), "duo_cycle": lambda: combine(p_eye(), p_roots(), 0.6, 0.7, (-26, -30), (24, 20)),
}


def rune_picto(rid, row):
    if rid in RUNE_PICTO:
        return RUNE_PICTO[rid]()
    return STATUS_PICTO.get(row.get("status", ""), p_flame)()


# ---------------------------------------------------------------- plaque frames per slot
def frame_shape(slot):
    if slot == "strike":   # heater shield
        return "M128 12 C160 26 196 28 226 24 C232 120 196 196 128 244 C60 196 24 120 30 24 C60 28 96 26 128 12Z", 0.86
    if slot == "dash":     # arrow-chevron pointing right
        return poly_d([(14, 40), (176, 40), (244, 128), (176, 216), (14, 216), (58, 128)]), 0.82
    if slot == "flare":
        return circle_d(128, 128, 118), 0.84
    if slot == "duo":
        return poly_d(ngon(128, 128, 122, 6, -90)), 0.84
    if slot == "legend":
        a = ngon(128, 128, 122, 8, -90)
        b = ngon(128, 128, 96, 8, -67.5)
        return poly_d([p for pair in zip(a, b) for p in pair]), 0.8
    if slot == "rest":     # arch
        return "M30 236 L30 110 C30 48 76 14 128 14 C180 14 226 48 226 110 L226 236Z", 0.84
    c = 34                 # passive: cut-corner plaque (UI panel shape, art bible §3)
    return poly_d([(16 + c, 16), (240 - c, 16), (240, 16 + c), (240, 240 - c), (240 - c, 240), (16 + c, 240), (16, 240 - c), (16, 16 + c)]), 0.84


def scaled(d, k):
    return transform_d(d, k, 128 * (1 - k), 128 * (1 - k))


def rune_icon(rid, row, gods):
    svg = Svg("r_" + rid)
    slot = row.get("slot", "passive")
    gs = row.get("gods") or [row.get("god", "rod")]
    cols = [gods.get(g, {}).get("colour", "#e0c080") for g in gs]
    col = cols[0]
    d, k = frame_shape(slot)
    mat = WOOD if gs[0] == "rod" or slot in ("passive", "rest") else STONE
    if slot == "legend":
        mat = GOLD
    lt = tones(col)[0]
    svg.path(scaled(d, 1.04), stroke=lt, w=14, op=0.18)  # outer halo
    svg.path(d, fill=INK, stroke=INK, w=8)
    svg.path(d, fill=svg.lin([(0, mat[0], 1), (0.4, mat[1], 1), (0.85, mat[2], 1), (1, mat[3], 1)]))
    # carved grain / stone speckle
    for i in range(14):
        y = 30 + i * 15
        svg.path("M%g %g C%g %g %g %g %g %g" % (20, y, 90, y + (i % 3 - 1) * 6, 160, y - (i % 2) * 8, 236, y + 3), stroke=mat[3], w=1.2, op=0.35, extra=' clip-path="%s"' % svg.clip(d))
    svg.path(scaled(d, 0.985), stroke="#ffffff", w=2, op=0.35, extra=' transform="translate(0 -1.5)"')
    # gold inlay line
    svg.path(scaled(d, 0.92), stroke=INK, w=6)
    svg.path(scaled(d, 0.92), stroke=svg.lin([(0, GOLD[0], 1), (0.5, GOLD[1], 1), (1, GOLD[2], 1)]), w=3.2)
    # enamel field (split for unions)
    inner = scaled(d, k)
    svg.path(inner, fill=INK, stroke=INK, w=5)
    if len(cols) == 2:
        for side, c in enumerate(cols):
            t = tones(c)
            half = "M0 0 L128 0 L128 256 L0 256Z" if side == 0 else "M128 0 L256 0 L256 256 L128 256Z"
            svg.path(inner, fill=svg.rad([(0, mix(t[1], t[2], 0.25), 1), (0.6, t[2], 1), (1, t[3], 1)], cx=0.25 if side == 0 else 0.75, cy=0.45, r=0.65), extra=' clip-path="%s"' % svg.clip(half))
        svg.path("M128 20 L128 236", stroke=INK, w=5, extra=' clip-path="%s"' % svg.clip(inner))
        svg.path("M128 20 L128 236", stroke=GOLD[1], w=2, extra=' clip-path="%s"' % svg.clip(inner))
    else:
        t = tones(col)
        svg.path(inner, fill=svg.rad([(0, mix(t[1], t[2], 0.35), 1), (0.6, t[2], 1), (1, t[3], 1)], cy=0.45, r=0.62))
    svg.path(inner, stroke=GOLD[0], w=1.2, op=0.5)
    # pictogram: unions get a gold-white pictogram so both halves read; others in god colour
    picto = rune_picto(rid, row)
    pcol = mix(cols[0], cols[1], 0.5) if len(cols) == 2 else col
    mark = len(svg.body)
    draw_picto(svg, picto, pcol if len(cols) == 1 else mix(pcol, "#fff6dc", 0.45), glow=True, metal=(slot == "legend"))
    k2 = 1.16 if slot not in ("dash", "legend") else 1.05
    cx = 136 if slot == "dash" else 128
    svg.body[mark:] = ['<g transform="translate(%g %g) scale(%g)">%s</g>' % (cx - 128 * k2, 132 - 132 * k2, k2, "".join(svg.body[mark:]))]
    svg.path(inner, fill=svg.lin([(0, "#ffffff", 0.18), (0.4, "#ffffff", 0)]))  # gloss
    # god sign(s) small in the corner(s)
    corners = [(44, 44), (212, 44)] if len(gs) == 2 else [(44, 44)]
    if slot == "dash":
        corners = [(48, 64)]
    if slot == "strike" and len(gs) == 1:
        corners = [(52, 52)]
    for g, (x, y) in zip(gs, corners):
        if slot in ("legend",):
            break
        s = 0.31
        sub = Svg(svg.prefix + "_g" + g)
        god_sign(sub, g, gods.get(g, {}).get("colour", "#e0c080"))
        svg.defs.extend(sub.defs)
        svg.add('<g transform="translate(%g %g) scale(%g)">%s</g>' % (x - 128 * s, y - 128 * s, s, "".join(sub.body)))
    return svg.text()


# ---------------------------------------------------------------- door icons
DOOR_PICTO = {"loot": p_pouch, "heal": p_drop, "arms": p_sword, "surica": p_cup, "lair": p_lair, "haven": p_fire, "next_loc": p_gate, "base": p_house}


def door_icon(t, col):
    svg = Svg("d_" + t)
    medallion(svg, col, rim=GOLD if t not in ("lair",) else STONE, beads=16)
    draw_picto(svg, DOOR_PICTO[t](), col, glow=True)
    gloss(svg)
    return svg.text()


def main():
    os.makedirs(OUT, exist_ok=True)
    gods = {k: v for k, v in json.load(open(os.path.join(DATA, "gods.json"), encoding="utf-8")).items() if not k.startswith("_")}
    runes = {k: v for k, v in json.load(open(os.path.join(DATA, "runes.json"), encoding="utf-8")).items() if not k.startswith("_")}
    doors = {k: v for k, v in json.load(open(os.path.join(DATA, "doors.json"), encoding="utf-8")).items() if not k.startswith("_")}
    n = 0
    for g, row in gods.items():
        svg = Svg("g_" + g)
        god_sign(svg, g, row["colour"])
        open(os.path.join(OUT, "ui_icon_god_%s.svg" % g), "w", encoding="utf-8").write(svg.text())
        n += 1
    for rid, row in runes.items():
        open(os.path.join(OUT, "ui_icon_rune_%s.svg" % rid), "w", encoding="utf-8").write(rune_icon(rid, row, gods))
        n += 1
    for t, row in doors.items():
        if t in ("god", "rod"):
            continue  # drawn with the god sign
        open(os.path.join(OUT, "ui_icon_door_%s.svg" % t), "w", encoding="utf-8").write(door_icon(t, row.get("colour") or "#e0c080"))
        n += 1
    print("wrote %d icons to %s" % (n, OUT))


if __name__ == "__main__":
    main()

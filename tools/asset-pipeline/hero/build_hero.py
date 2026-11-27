#!/usr/bin/env python3
"""Builds the hero cutout rig of «Навь» (ADR-0005, art bible §5.5-5.7).

Writes, from the tables in this file:
  * assets/art/hero/char_hero_<part>[_t<tier>]_01.svg  -- the slot parts, all drawn
    on ONE mannequin: every part lives in the local frame of its bone (joint at
    0,0; limbs point down +y, torso and head point up -y), source scale 2x
    (hero 320 px tall in the source, 160 px on a 1080p screen).
  * a .import next to each SVG (linear filter is set on the node; mipmaps on).
  * scenes/hero/hero_visual.tscn -- Skeleton2D + Bone2D rig, flat slot sprites in
    the art bible's z order driven by RemoteTransform2D, CanvasGroup with the hit
    flash shader, and the AnimationPlayer library (all poses are tables below).

Re-run after editing a shape or a pose:  python3 tools/asset-pipeline/hero/build_hero.py
Standard library only. Original art, authored here as vector shapes (no AI, no
third-party sources) -- see assets/provenance.yaml.
"""
from __future__ import annotations

import math
import os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
ART_DIR = os.path.join(ROOT, "assets", "art", "hero")
SCENE = os.path.join(ROOT, "scenes", "hero", "hero_visual.tscn")
RES_ART = "res://assets/art/hero/"

# ------------------------------------------------------------------ palette
# Art bible §4.1, §5.1, §5.6. Light / base / shade triples; light comes from
# above-front (one light for every part, §5.6 "правило смешения").
OUT = "#120D12"
SW = 8  # outline stroke in source px = 4 px on screen at 1080p (source is 2x)
SKIN = ("#F0BC94", "#E0A07A", "#A8664A")
HAIR = ("#A8764A", "#8A5A34", "#5E3B20")
CANVAS = ("#DDCDAE", "#CDBB98", "#9C8866")
WRAPS = ("#B0A088", "#9A8A72", "#6E604E")
STICK = ("#B08A5C", "#8C6A44", "#5E4428")
RED = ("#CC3A40", "#B3262E", "#7A1820")
STEEL = ("#DCE4EA", "#B8C4CC", "#7E8C96")
MAIL = ("#A8B2BA", "#8E9AA3", "#626E77")
GOLD = ("#E6B458", "#C8902E", "#8A6020")
GOLD_HI = ("#FFE08A", "#FFC94A", "#C8902E")
LEATHER = ("#7A5232", "#5A3A22", "#3A2416")
TROUSER5 = ("#86603C", "#6B4428", "#462C1A")  # bible tier-3 leather tone, see report
WOOD = ("#C49A64", "#A07A4E", "#6E5034")
THREAD = "#B3262E"
SILVER = "#EDE6F2"
LINE_DARK = "#3A2414"
# tiers 2-4 (bible §5.6 «Силуэт и палитра по ярусам»)
LINEN = ("#F6EFE0", "#E9DFC9", "#B4A88E")          # t2 shirt, the lightest patch after the amulet
WRAP_LEATHER = ("#94603A", "#7A4A2A", "#4E2E1A")   # t2 forearm wraps
BAST = ("#D8BE84", "#BFA36A", "#86703F")           # t2 lapti
ONUCHI = ("#CFC4AC", "#B8AC92", "#857A64")         # t2 foot cloths
QUILT = ("#B68E5E", "#9A7448", "#664A2A")          # t3 tegilyai
LEATHER3 = TROUSER5                                # t3 leather #6B4428
BRONZE = ("#D49C5A", "#B07A3A", "#74501F")         # t3 bronze, darker than loot gold
WOOL = ("#8C826E", "#706654", "#4A4336")           # t3-t4 homespun trousers (under the boots)
IRON = MAIL                                        # t4 iron splints and fittings
TROUSERS = {1: CANVAS, 2: CANVAS, 3: WOOL, 4: WOOL, 5: TROUSER5}


def shade_hex(c: str, k: float) -> str:
    """Darkens a #rrggbb colour by factor k (far limbs sit in shadow)."""
    r, g, b = (int(c[i:i + 2], 16) for i in (1, 3, 5))
    return "#%02X%02X%02X" % (int(r * k), int(g * k), int(b * k))


def dark(p: tuple, k: float) -> tuple:
    return tuple(shade_hex(c, k) for c in p)


# ------------------------------------------------------------------ svg helpers
class Svg:
    """One part: a canvas rect in bone-local source px and its elements."""

    def __init__(self, rect: tuple):
        self.x0, self.y0, self.w, self.h = rect
        self.defs: list[str] = []
        self.body: list[str] = []
        self._n = 0
        self.sx = 1.0  # horizontal widening of the whole drawing (broad shoulders)

    def grad(self, pal: tuple, vertical: bool = False) -> str:
        self._n += 1
        gid = "g%d" % self._n
        x1, y1, x2, y2 = ("0.5", "0", "0.5", "1") if vertical else ("0.9", "0.05", "0.1", "0.95")
        self.defs.append(
            f'<linearGradient id="{gid}" x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}">'
            f'<stop offset="0" stop-color="{pal[0]}"/><stop offset="0.5" stop-color="{pal[1]}"/>'
            f'<stop offset="1" stop-color="{pal[2]}"/></linearGradient>')
        return f"url(#{gid})"

    def shape(self, d: str, pal: tuple | str, sw: float = SW, vertical: bool = False, clip: str = "") -> None:
        fill = pal if isinstance(pal, str) else self.grad(pal, vertical)
        stroke = f' stroke="{OUT}" stroke-width="{sw}" stroke-linejoin="round" stroke-linecap="round"' if sw > 0 else ""
        cl = f' clip-path="url(#{clip})"' if clip else ""
        self.body.append(f'<path d="{d}" fill="{fill}"{stroke}{cl}/>')

    def line(self, d: str, color: str, sw: float, opacity: float = 1.0, clip: str = "") -> None:
        cl = f' clip-path="url(#{clip})"' if clip else ""
        self.body.append(f'<path d="{d}" fill="none" stroke="{color}" stroke-width="{sw}" '
                         f'stroke-linecap="round" stroke-linejoin="round" opacity="{opacity}"{cl}/>')

    def soft(self, d: str, color: str, opacity: float, clip: str = "") -> None:
        cl = f' clip-path="url(#{clip})"' if clip else ""
        self.body.append(f'<path d="{d}" fill="{color}" opacity="{opacity}"{cl}/>')

    def circle(self, cx, cy, r, pal, sw: float = SW) -> None:
        fill = pal if isinstance(pal, str) else self.grad(pal)
        stroke = f' stroke="{OUT}" stroke-width="{sw}"' if sw > 0 else ""
        self.body.append(f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{fill}"{stroke}/>')

    def ellipse(self, cx, cy, rx, ry, color: str, opacity: float = 1.0) -> None:
        self.body.append(f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" fill="{color}" opacity="{opacity}"/>')

    def clip(self, d: str) -> str:
        self._n += 1
        cid = "c%d" % self._n
        self.defs.append(f'<clipPath id="{cid}"><path d="{d}"/></clipPath>')
        return cid

    def raw(self, s: str) -> None:
        self.body.append(s)

    def text(self) -> str:
        return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{self.w}" height="{self.h}" '
                f'viewBox="{self.x0} {self.y0} {self.w} {self.h}">\n<defs>{"".join(self.defs)}</defs>\n'
                + (f'<g transform="scale({self.sx} 1)">' if self.sx != 1.0 else "<g>")
                + "\n".join(self.body) + "\n</g></svg>\n")


def scales(x0: int, x1: int, y0: int, y1: int, step_x: int = 12, step_y: int = 10) -> str:
    """Rows of overlapping scale arcs (scale armour, bible §5.4: no rivets)."""
    d = []
    row = 0
    y = y0
    while y < y1:
        off = (step_x // 2) if row % 2 else 0
        x = x0 - off
        while x < x1:
            d.append(f"M{x} {y} q{step_x / 2} {step_y + 2} {step_x} 0")
            x += step_x
        y += step_y
        row += 1
    return " ".join(d)


def mail_rows(x0: int, x1: int, y0: int, y1: int, step: int = 7) -> str:
    """Even mail texture: shallow scallop rows, no single rings (bible §5.4)."""
    d = []
    y = y0
    while y < y1:
        x = x0
        while x < x1:
            d.append(f"M{x} {y} q3 4 6 0")
            x += 6
        y += step
    return " ".join(d)


# ------------------------------------------------------------------ parts
# Every part: (rect x0, y0, w, h) in bone-local source px and a drawing function.
PARTS: dict[str, tuple] = {}


def part(name: str, rect: tuple):
    def deco(fn):
        PARTS[name] = (rect, fn)
        return fn
    return deco


WIDE_TORSO = 1.18
TORSO_D = ("M-22 8 C-30 -10 -38 -40 -38 -62 C-38 -78 -30 -88 -16 -92 C-8 -95 -2 -100 0 -108 "
           "L16 -106 C16 -98 22 -94 32 -90 C42 -86 47 -74 45 -60 C43 -44 37 -34 33 -24 C31 -12 30 0 28 8 Z")


@part("body_base_torso", (-58, -120, 120, 136))
def _torso(s: Svg, tier: int) -> None:
    s.sx = WIDE_TORSO
    s.shape(TORSO_D, SKIN)
    c = s.clip(TORSO_D)
    # soft form shadows: under the chest, the back, the far side of the belly
    s.soft("M8 -58 C20 -48 34 -46 46 -56 L46 -20 C36 -30 20 -38 8 -44 Z", SKIN[2], 0.35, c)
    s.soft("M-40 -70 C-34 -40 -28 -10 -24 10 L-44 10 L-44 -70 Z", SKIN[2], 0.4, c)
    s.line("M12 -60 C22 -50 34 -49 43 -56", SKIN[2], 4)           # chest line
    s.line("M24 -34 C27 -24 27 -12 25 0", SKIN[2], 3.5, 0.8)       # belly
    s.line("M6 -92 C14 -88 24 -88 32 -88", SKIN[2], 3, 0.7)        # collarbone
    # scrapes on the shoulder (tier 1 «ссадины на плечах»; the mannequin keeps them)
    s.line("M32 -84 L40 -78 M35 -88 L43 -82", "#B5523E", 3, 0.9)
    s.line("M28 -72 L33 -68", "#B5523E", 2.5, 0.8)


@part("body_base_pelvis", (-36, -24, 74, 56))
def _pelvis(s: Svg, tier: int) -> None:
    s.shape("M-26 -14 L28 -14 C32 0 30 14 22 24 L-18 24 C-28 12 -30 0 -26 -14 Z", SKIN)


HEAD_D = ("M-6 -6 C-24 -10 -32 -26 -32 -42 C-32 -64 -14 -78 6 -78 C22 -78 32 -68 32 -54 "
          "C32 -50 33 -47 34 -45 L41 -35 C43 -32 40 -29 35 -29 L33 -26 C34 -20 32 -14 28 -10 "
          "C20 -4 8 -2 -6 -6 Z")
BEARD_D = ("M-4 -32 C2 -26 10 -24 16 -27 C22 -31 28 -32 35 -30 C39 -26 39 -20 35 -16 "
           "C37 -8 34 2 28 8 L24 15 L19 9 L13 16 L8 9 L2 13 L-1 5 C-6 -2 -8 -12 -9 -20 "
           "C-9 -26 -7 -30 -4 -32 Z")


@part("head_base", (-44, -90, 92, 112))
def _head(s: Svg, tier: int) -> None:
    s.shape(HEAD_D, SKIN)
    c = s.clip(HEAD_D)
    s.soft("M-34 -60 C-26 -40 -20 -20 -8 -4 L-40 0 Z", SKIN[2], 0.35, c)  # back of skull in shade
    s.ellipse(24, -36, 7, 5, "#D9786A", 0.35)                              # warm cheek
    # ear
    s.shape("M-6 -48 C1 -51 5 -42 3 -35 C1 -30 -4 -30 -7 -34 C-9 -39 -9 -45 -6 -48 Z", SKIN, 4)
    s.line("M-3 -44 C0 -42 0 -38 -2 -36", SKIN[2], 2.5)
    # beard and moustache, russet (bible §5.1)
    s.shape(BEARD_D, HAIR, 6)
    s.line("M6 -18 C10 -10 12 -2 12 8 M20 -20 C22 -10 22 0 20 8 M0 -16 C2 -8 4 0 4 6", HAIR[2], 2.5, 0.9)
    s.line("M27 -22 L34 -21", LINE_DARK, 3)                                # mouth in the beard
    # eye, brow, nose line
    s.ellipse(21, -44, 3.8, 4.8, "#24160F")
    s.ellipse(22.4, -45.8, 1.3, 1.3, "#FFF4E6")
    s.line("M13 -52 Q21 -56 30 -51", "#5E3B20", 4.5)
    s.line("M33 -45 C36 -40 38 -36 36 -32", SKIN[2], 2.5, 0.8)


@part("hair_t1", (-50, -100, 92, 96))
def _hair(s: Svg, tier: int) -> None:
    d = ("M33 -57 L26 -59 C22 -60 12 -60 4 -56 C-6 -50 -12 -40 -12 -26 L-17 -13 L-22 -21 L-30 -15 "
         "L-32 -26 L-39 -28 L-36 -38 L-43 -43 L-36 -49 C-36 -63 -30 -75 -20 -79 L-18 -87 L-8 -83 "
         "L-5 -92 L2 -85 C16 -86 28 -78 31 -68 L37 -64 L30 -62 Z")
    s.shape(d, HAIR, 7)
    s.line("M-4 -76 C-14 -70 -22 -60 -26 -44 M8 -74 C0 -68 -8 -58 -12 -46 M20 -70 C14 -66 8 -62 4 -58",
           HAIR[2], 3, 0.9)
    s.line("M-10 -82 C-2 -84 8 -82 14 -78", HAIR[0], 3, 0.8)


@part("helmet_t5", (-44, -136, 90, 90))
def _helmet(s: Svg, tier: int) -> None:
    dome = "M-32 -57 C-33 -80 -16 -98 0 -114 C16 -98 33 -80 34 -57 Z"
    s.shape("M-2 -112 L0 -128 L2 -112 Z", STEEL, 5)                        # spire
    s.shape(dome, STEEL)
    c = s.clip(dome)
    s.soft("M-34 -60 C-30 -80 -16 -98 -2 -112 L-8 -60 Z", STEEL[2], 0.45, c)
    s.line("M3 -108 C9 -96 14 -80 16 -62", STEEL[0], 4, 0.9)               # highlight
    s.line("M-4 -110 C-10 -96 -16 -80 -18 -62", STEEL[2], 2.5, 0.8)        # ridge
    # gold band on the brim (bible tier 5: «по ободу полоса золота»)
    s.shape("M-35 -61 C-18 -66 18 -66 37 -60 L37 -50 C18 -56 -18 -56 -35 -51 Z", GOLD, 6, vertical=True)
    s.line("M-30 -56 C-14 -60 14 -60 32 -55", GOLD_HI[1], 2.5, 0.9)


@part("aventail_t5", (-52, -64, 70, 90))
def _aventail(s: Svg, tier: int) -> None:
    d = ("M-33 -57 L9 -57 C11 -49 9 -41 3 -35 C-3 -27 -3 -11 3 6 L-3 12 L-9 7 L-15 13 L-21 8 "
         "L-27 14 L-33 9 L-39 14 L-45 8 C-44 -12 -41 -38 -33 -57 Z")
    s.shape(d, MAIL, 7)
    c = s.clip(d)
    s.line(mail_rows(-48, 12, -52, 16), MAIL[2], 2, 0.9, c)
    s.soft("M-46 -50 L-30 -50 C-34 -20 -34 0 -30 16 L-46 16 Z", MAIL[2], 0.4, c)


ARMOR_D = ("M-27 16 C-35 -8 -43 -40 -43 -62 C-43 -80 -33 -93 -17 -97 L-2 -101 C4 -95 12 -93 18 -98 "
           "C26 -96 37 -93 41 -89 C49 -81 51 -68 49 -56 C47 -40 41 -28 37 -18 C35 -6 35 4 33 16 Z")


@part("torso_armor_t5", (-62, -112, 128, 134))
def _armor(s: Svg, tier: int) -> None:
    s.sx = WIDE_TORSO
    s.shape(ARMOR_D, STEEL)
    c = s.clip(ARMOR_D)
    s.line(scales(-46, 54, -92, 18), STEEL[2], 2.5, 0.95, c)
    s.line(scales(-46, 54, -90, 18), STEEL[0], 1.5, 0.6, c)
    s.soft("M-46 -70 C-38 -40 -32 -10 -28 18 L-50 18 L-50 -70 Z", STEEL[2], 0.45, c)
    s.soft("M10 -56 C22 -46 36 -44 50 -54 L50 -16 C38 -26 22 -36 10 -42 Z", STEEL[2], 0.3, c)
    # mail collar showing at the neck opening
    s.shape("M-4 -101 C4 -94 12 -92 19 -98 L21 -90 C12 -84 2 -86 -6 -92 Z", MAIL, 5)


@part("skirt_t5", (-44, -16, 90, 72))
def _skirt(s: Svg, tier: int) -> None:
    d = ("M-32 -10 L35 -10 C39 8 41 26 41 42 L33 48 L25 42 L17 49 L9 42 L1 49 L-7 42 L-15 49 "
         "L-23 42 L-31 47 L-37 41 C-37 24 -36 8 -32 -10 Z")
    s.shape(d, STEEL)
    c = s.clip(d)
    s.line(scales(-40, 44, -6, 48), STEEL[2], 2.5, 0.95, c)
    s.soft("M-40 -10 L-20 -10 L-24 50 L-40 50 Z", STEEL[2], 0.4, c)
    s.line("M12 -6 L14 44", OUT, 3, 0.8)                                  # front slit


@part("belt_t1", (-40, -24, 82, 44))
def _belt1(s: Svg, tier: int) -> None:
    rope = "M-31 -12 C-10 -8 12 -8 33 -12"
    ends = "M24 -10 L21 6 M27 -10 L32 4"
    for d in (rope, ends):
        s.line(d, OUT, 10)
    s.line(rope, "#B39668", 5)
    s.line(ends, "#B39668", 4.5)
    s.line("M-24 -10 l4 0 M-12 -9 l4 0 M0 -9 l4 0 M12 -10 l4 0", "#7A6440", 2, 0.9)
    s.circle(25, -10, 5, "#B39668", 4)


@part("belt_t5", (-40, -24, 82, 36))
def _belt5(s: Svg, tier: int) -> None:
    s.shape("M-35 -17 C-10 -14 12 -14 37 -17 L37 -4 C12 -1 -10 -1 -35 -4 Z", LEATHER, 6, vertical=True)
    s.shape("M18 -20 L32 -20 L32 0 L18 0 Z", GOLD_HI, 5)                  # gold buckle
    s.shape("M22 -15 L28 -15 L28 -5 L22 -5 Z", LEATHER[2], 0)
    s.line("M-28 -10 L14 -10", LEATHER[0], 2, 0.6)


# ---- legs (near = legs_cloth + boots; far = leg_far, one composite per segment)
PELVIS_D = ("M-30 -16 L32 -16 C36 2 32 20 22 30 C10 34 -2 32 -10 30 C-22 28 -32 14 -30 -16 Z")
THIGH_D = "M-20 -10 C-24 20 -22 46 -18 74 L18 76 C22 50 24 20 20 -12 C8 -18 -10 -18 -20 -10 Z"
SHIN_RAG_D = ("M-18 -12 C-20 10 -19 24 -17 34 L-11 41 L-6 33 L0 42 L6 33 L12 40 L16 32 "
              "C18 20 19 6 17 -12 C6 -16 -8 -16 -18 -12 Z")
SHIN_TUCK_D = "M-18 -12 C-20 10 -19 26 -17 44 L16 44 C18 26 19 6 17 -12 C6 -16 -8 -16 -18 -12 Z"
CALF_D = "M-15 18 C-16 30 -15 42 -13 56 L12 56 C14 42 15 30 14 18 Z"
WRAP_SHIN_D = "M-17 33 C-18 45 -16 56 -14 67 L14 67 C16 56 17 45 16 31 C6 29 -6 29 -17 33 Z"
WRAP_FOOT_D = "M-14 -9 C-18 4 -16 14 -12 18 L30 18 C38 18 40 10 34 6 C26 2 16 -2 12 -11 C4 -15 -8 -15 -14 -9 Z"
BOOT_SHIN_D = "M-19 18 C-20 34 -18 50 -16 68 L16 68 C18 50 19 34 18 16 C6 13 -8 13 -19 18 Z"
GREAVE_D = "M-1 -8 C12 -10 20 -2 20 10 L18 56 C10 60 3 60 -1 56 Z"
BOOT_FOOT_D = "M-16 -11 C-20 4 -18 14 -16 18 L36 18 C42 16 42 8 36 4 C26 0 16 -4 14 -12 C4 -16 -8 -16 -16 -11 Z"


def draw_pelvis_cloth(s: Svg, tier: int) -> None:
    pal = TROUSERS[tier]
    s.shape(PELVIS_D, pal)
    c = s.clip(PELVIS_D)
    s.soft("M-34 -16 L-14 -16 C-18 6 -14 22 -8 34 L-34 34 Z", pal[2], 0.4, c)
    s.line("M2 4 C6 14 8 22 6 30 M-12 8 C-10 16 -10 22 -12 28", pal[2], 3, 0.8)


def draw_thigh(s: Svg, tier: int, k: float = 1.0) -> None:
    pal = dark(TROUSERS[tier], k)
    s.shape(THIGH_D, pal)
    c = s.clip(THIGH_D)
    s.soft("M-24 -14 L-10 -14 C-12 20 -10 50 -6 78 L-24 78 Z", pal[2], 0.4, c)
    s.line("M-4 18 C0 32 4 44 2 58 M10 4 C12 14 12 22 10 30", pal[2], 3, 0.8)
    if tier == 1:  # patch with stitches on the canvas, and a tear
        s.shape("M4 36 L16 34 L17 48 L5 50 Z", dark(("#C4AE86", "#B49E78", "#8C7656"), k), 3)
        s.line("M6 38 l2 2 M8 46 l2 2 M14 37 l2 2 M14 45 l2 2", "#5A4A36", 1.8)
        s.shape("M-14 56 L-8 62 L-13 66 Z", "#3A2C22", 0)


def draw_shin_cloth(s: Svg, tier: int, k: float = 1.0) -> None:
    if tier == 1:
        s.shape(CALF_D, dark(SKIN, k), 6)
        pal = dark(CANVAS, k)
        s.shape(SHIN_RAG_D, pal)
        c = s.clip(SHIN_RAG_D)
        s.soft("M-22 -14 L-10 -14 C-12 10 -10 26 -8 42 L-22 42 Z", pal[2], 0.4, c)
        s.line("M2 0 C4 10 4 18 2 26", pal[2], 3, 0.8)
    else:
        pal = dark(TROUSERS[tier], k)
        s.shape(SHIN_TUCK_D, pal)
        c = s.clip(SHIN_TUCK_D)
        s.soft("M-22 -14 L-10 -14 C-12 10 -10 26 -8 46 L-22 46 Z", pal[2], 0.4, c)


ONUCHI_D = "M-19 -10 C-21 14 -19 42 -16 67 L15 67 C18 42 20 14 18 -12 C6 -16 -8 -16 -19 -10 Z"
HIGH_BOOT_D = "M-21 -8 C-22 18 -20 46 -17 68 L16 68 C19 46 21 18 20 -10 C6 -14 -8 -14 -21 -8 Z"
SPLINT_D = "M2 -4 C12 -6 18 0 18 8 L16 54 C10 57 5 57 2 54 Z"


def draw_boot_shin_mid(s: Svg, tier: int, k: float) -> None:
    """Tiers 2-4: onuchi with lapti cords (2), knee boots (3), boots with iron splints (4)."""
    if tier == 2:
        pal = dark(ONUCHI, k)
        s.shape(ONUCHI_D, pal)
        c = s.clip(ONUCHI_D)
        s.soft("M-24 -14 L-10 -14 L-8 70 L-24 70 Z", pal[2], 0.4, c)
        s.line("M-20 2 L18 -4 M-20 16 L19 10 M-19 30 L18 24 M-18 44 L17 38 M-17 58 L16 52", pal[2], 2, 0.7, c)
        cord = "M-18 66 L16 46 L-18 26 L17 6 M16 66 L-18 46 L17 26 L-19 6"  # lapti cords (оборы), criss-cross
        s.line(cord, OUT, 6, 1.0, c)
        s.line(cord, dark(BAST, k)[1], 3, 1.0, c)
        return
    pal = dark(LEATHER3, k)
    s.shape(HIGH_BOOT_D, pal)
    c = s.clip(HIGH_BOOT_D)
    s.soft("M-24 -12 L-10 -12 L-8 70 L-24 70 Z", pal[2], 0.45, c)
    s.shape("M-22 -10 C-8 -15 8 -15 21 -12 L21 0 C8 -3 -8 -3 -22 2 Z", dark(LEATHER3, k * 1.12), 5)  # cuff
    s.line("M-14 20 C-12 36 -12 50 -10 64", pal[2], 2.5, 0.8, c)
    if tier == 4:  # iron splints on the shin, strapped, no gold (that is tier 5)
        g = dark(IRON, k)
        s.shape(SPLINT_D, g, 6)
        s.line("M9 2 C12 16 12 36 10 50", g[0], 2.5, 0.9)
        s.line("M-20 14 L3 12 M-18 44 L3 42", dark(LEATHER, k)[2], 4)


def draw_boot_shin(s: Svg, tier: int, k: float = 1.0) -> None:
    if 2 <= tier <= 4:
        draw_boot_shin_mid(s, tier, k)
        return
    if tier < 5:
        pal = dark(WRAPS, k)
        s.shape(WRAP_SHIN_D, pal)
        c = s.clip(WRAP_SHIN_D)
        s.line("M-18 41 L16 35 M-17 49 L16 43 M-16 57 L16 51 M-15 65 L15 59", pal[2], 3, 0.95, c)
        s.line("M-18 39 L16 33", pal[0], 1.5, 0.7, c)
    else:
        pal = dark(LEATHER, k)
        s.shape(BOOT_SHIN_D, pal)
        c = s.clip(BOOT_SHIN_D)
        s.soft("M-22 14 L-10 14 L-8 70 L-22 70 Z", pal[2], 0.45, c)
        s.line("M-18 22 C-6 18 6 18 18 20", pal[0], 2.5, 0.7, c)
        g = dark(STEEL, k)
        s.shape(GREAVE_D, g, 6)
        s.line("M8 -4 C12 10 12 34 10 54", g[0], 3, 0.9)
        s.line("M-1 -8 C12 -10 20 -2 20 10", dark(GOLD, k)[1], 3)


LAPTI_D = ("M-16 -9 C-20 4 -18 14 -14 19 L30 19 C40 19 43 11 37 6 C28 1 18 -3 13 -11 "
           "C4 -15 -10 -15 -16 -9 Z")


def draw_boot_foot(s: Svg, tier: int, k: float = 1.0) -> None:
    if tier == 2:  # lapti: woven bast, lattice, cords up the shin
        pal = dark(BAST, k)
        s.shape(LAPTI_D, pal)
        c = s.clip(LAPTI_D)
        s.line(" ".join(f"M{x} -16 l24 36" for x in range(-30, 44, 9)), pal[2], 2.2, 0.85, c)
        s.line(" ".join(f"M{x} -16 l-24 36" for x in range(-8, 66, 9)), pal[2], 2.2, 0.85, c)
        s.soft("M-20 13 L46 13 L46 24 L-20 24 Z", pal[2], 0.55, c)
        return
    if tier in (3, 4):
        pal = dark(LEATHER3, k)
        s.shape(BOOT_FOOT_D, pal)
        c = s.clip(BOOT_FOOT_D)
        s.soft("M-20 10 L44 10 L44 22 L-20 22 Z", "#1E120A", 0.6, c)
        s.line("M14 -8 C20 0 28 2 36 4", pal[0], 2.5, 0.7, c)
        return
    if tier < 5:
        pal = dark(WRAPS, k)
        s.shape(WRAP_FOOT_D, pal)
        c = s.clip(WRAP_FOOT_D)
        s.line("M-10 -6 L4 14 M0 -6 L14 14 M10 0 L22 16", pal[2], 3, 0.95, c)
        # bare toes out of the wraps (bible tier 1: «босые ноги в обмотках»)
        s.shape("M26 5 C33 3 40 8 38 14 C37 18 31 18 26 18 Z", dark(SKIN, k), 5)
    else:
        pal = dark(LEATHER, k)
        s.shape(BOOT_FOOT_D, pal)
        c = s.clip(BOOT_FOOT_D)
        s.soft("M-20 10 L44 10 L44 22 L-20 22 Z", "#1E120A", 0.6, c)      # sole
        s.line("M14 -8 C20 0 28 2 36 4", pal[0], 2.5, 0.7, c)


@part("legs_cloth_pelvis", (-40, -24, 82, 64))
def _lp(s, t): draw_pelvis_cloth(s, t)


@part("legs_cloth_thigh", (-30, -24, 60, 108))
def _lt(s, t): draw_thigh(s, t)


@part("legs_cloth_shin", (-28, -24, 56, 76))
def _ls(s, t): draw_shin_cloth(s, t)


@part("boots_shin", (-28, -16, 56, 92))
def _bs(s, t): draw_boot_shin(s, t)


@part("boots_foot", (-26, -22, 74, 48))
def _bf(s, t): draw_boot_foot(s, t)


FAR = 0.78  # the far limbs are a step darker (same light, further from it)


@part("leg_far_thigh", (-30, -24, 60, 108))
def _ft(s, t): draw_thigh(s, t, FAR)


@part("leg_far_shin", (-28, -24, 56, 100))
def _fs(s, t):
    draw_shin_cloth(s, t, FAR)
    draw_boot_shin(s, t, FAR)


@part("leg_far_foot", (-26, -22, 74, 48))
def _ff(s, t): draw_boot_foot(s, t, FAR)


# ---- arms (same drawing for near and far; far is darker)
UPPER_D = "M-16 -12 C-20 10 -16 36 -12 62 L12 62 C17 38 19 14 15 -12 C6 -20 -8 -20 -16 -12 Z"
FORE_D = "M-12 -8 C-14 14 -11 34 -9 54 L9 54 C11 34 14 12 12 -8 C4 -14 -6 -14 -12 -8 Z"
FIST_D = "M-14 2 C-14 -4 -8 -6 0 -6 C8 -6 15 -3 15 4 L15 22 C15 28 10 30 2 30 C-8 30 -14 28 -14 22 Z"


SLEEVE_D = "M-18 -12 C-22 12 -19 36 -16 58 C-6 62 6 62 16 58 C19 36 21 14 17 -12 C6 -20 -8 -20 -18 -12 Z"
QSLEEVE_D = "M-21 -12 C-25 12 -21 36 -18 56 C-6 61 7 61 18 56 C22 36 24 12 19 -12 C7 -22 -9 -22 -21 -12 Z"
MSLEEVE_D = "M-17 -10 C-21 12 -18 34 -15 54 L-9 58 L-3 53 L3 58 L9 53 L15 57 C18 36 20 14 16 -10 Z"


def draw_upper_mid(s: Svg, tier: int, k: float) -> None:
    """Tiers 2-4 sleeve: linen shirt (2), quilted tegilyai (3), mail over tegilyai (4)."""
    s.shape(UPPER_D, dark(SKIN, k))
    if tier == 2:
        pal = dark(LINEN, k)
        s.shape(SLEEVE_D, pal)
        c = s.clip(SLEEVE_D)
        s.soft("M-24 -16 L-10 -16 C-12 10 -10 36 -8 64 L-24 64 Z", pal[2], 0.4, c)
        s.line("M-8 4 C-6 20 -6 34 -4 48 M6 2 C8 18 8 34 7 50", pal[2], 2.5, 0.6, c)
        s.line("M-16 52 C-6 56 6 56 16 52", dark(RED, k)[1], 4, 1.0, c)          # embroidered cuff
        return
    pal = dark(QUILT, k)
    s.shape(QSLEEVE_D, pal)
    c = s.clip(QSLEEVE_D)
    s.soft("M-26 -16 L-12 -16 C-14 10 -12 36 -10 64 L-26 64 Z", pal[2], 0.45, c)
    s.line("M-22 6 C-8 10 8 10 22 4 M-22 22 C-8 26 8 26 22 20 M-20 38 C-8 42 8 42 20 36", pal[2], 2.5, 0.9, c)
    if tier == 4:
        m = dark(MAIL, k)
        s.shape(MSLEEVE_D, m, 7)
        c2 = s.clip(MSLEEVE_D)
        s.line(mail_rows(-22, 22, -4, 60), m[2], 2, 0.9, c2)
        s.soft("M-22 -12 L-10 -12 L-8 60 L-22 60 Z", m[2], 0.4, c2)


def draw_upper(s: Svg, tier: int, k: float) -> None:
    if 2 <= tier <= 4:
        draw_upper_mid(s, tier, k)
        return
    if tier < 5:
        pal = dark(SKIN, k)
        s.shape(UPPER_D, pal)
        c = s.clip(UPPER_D)
        s.soft("M-20 -16 L-8 -16 C-10 10 -8 36 -6 64 L-20 64 Z", pal[2], 0.4, c)
        s.line("M-12 12 C-4 18 6 18 15 10", pal[2], 3, 0.8)
    else:
        sleeve = "M-17 -10 C-21 12 -18 34 -15 54 L-9 58 L-3 53 L3 58 L9 53 L15 57 C18 36 20 14 16 -10 Z"
        s.shape(UPPER_D, dark(SKIN, k))
        m = dark(MAIL, k)
        s.shape(sleeve, m, 7)
        c = s.clip(sleeve)
        s.line(mail_rows(-22, 22, -4, 60), m[2], 2, 0.9, c)
        cap = "M-20 -6 C-22 -20 -10 -26 0 -26 C12 -26 22 -20 20 -4 C14 4 -14 4 -20 -6 Z"
        st = dark(STEEL, k)
        s.shape(cap, st, 7)
        c2 = s.clip(cap)
        s.line(scales(-22, 24, -24, 6, 10, 8), st[2], 2.2, 0.95, c2)
        s.line("M-18 -4 C-10 2 12 2 19 -3", dark(GOLD, k)[1], 3)


def draw_fore(s: Svg, tier: int, k: float) -> None:
    pal = dark(SKIN, k)
    s.shape(FORE_D, pal)
    c = s.clip(FORE_D)
    s.soft("M-16 -12 L-6 -12 C-8 14 -6 34 -4 56 L-16 56 Z", pal[2], 0.4, c)
    if tier == 2:  # leather wraps, diagonal turns
        w = "M-14 4 C-15 18 -14 34 -12 50 L12 50 C14 34 15 18 14 4 C6 1 -6 1 -14 4 Z"
        lw = dark(WRAP_LEATHER, k)
        s.shape(w, lw, 6)
        c2 = s.clip(w)
        s.line("M-16 14 L16 6 M-16 24 L16 16 M-16 34 L16 26 M-16 44 L16 36", lw[2], 2.5, 0.95, c2)
        s.line("M-16 12 L16 4 M-16 32 L16 24", lw[0], 1.5, 0.7, c2)
    elif tier == 3:  # leather bracer with bronze studs
        b = "M-15 6 C-16 20 -15 36 -13 50 L13 50 C15 36 16 20 15 6 C6 3 -6 3 -15 6 Z"
        lb = dark(LEATHER3, k)
        s.shape(b, lb, 7)
        s.line("M-13 11 C-4 9 6 9 13 11 M-12 45 C-4 46 6 46 12 45", lb[0], 2, 0.6)
        for y in (18, 28, 38):
            s.circle(4, y, 3.4, dark(BRONZE, k), 2.5)
    elif tier == 4:  # plain steel bracer
        b = "M-15 6 C-16 20 -15 36 -13 50 L13 50 C15 36 16 20 15 6 C6 3 -6 3 -15 6 Z"
        st = dark(STEEL, k)
        s.shape(b, st, 7)
        s.line("M6 12 C8 24 8 34 6 42", st[0], 2.5, 0.9)
        s.line("M-13 11 C-4 9 6 9 13 11 M-12 45 C-4 46 6 46 12 45", st[2], 2.5, 0.9)
    elif tier >= 5:
        b = "M-15 6 C-16 20 -15 36 -13 50 L13 50 C15 36 16 20 15 6 C6 3 -6 3 -15 6 Z"
        st = dark(STEEL, k)
        s.shape(b, st, 7)
        s.line("M-13 11 C-4 9 6 9 13 11", dark(GOLD, k)[1], 3.5)            # gold edge, bible t5
        s.line("M-12 45 C-4 46 6 46 12 45", dark(GOLD, k)[1], 3.5)
        s.line("M6 12 C8 24 8 34 6 42", st[0], 2.5, 0.9)
    else:
        s.line("M4 6 C7 16 7 26 4 36", pal[2], 3, 0.7)


def draw_hand(s: Svg, tier: int, k: float, grip: bool) -> None:
    pal = dark(SKIN, k)
    s.shape(FIST_D, pal)
    c = s.clip(FIST_D)
    s.soft("M-18 -8 L-6 -8 L-4 32 L-18 32 Z", pal[2], 0.4, c)
    s.line("M15 8 L5 9 M15 15 L5 16 M15 22 L6 23", pal[2], 2.5, 0.9)     # fingers wrapped
    s.line("M2 -4 C10 -2 12 6 9 12", OUT, 3)                               # thumb


@part("arm_near_upper", (-28, -34, 58, 104))
def _au(s, t): draw_upper(s, t, 1.0)


@part("arm_near_fore", (-24, -20, 48, 82))
def _af(s, t): draw_fore(s, t, 1.0)


@part("arm_near_hand", (-22, -14, 46, 52))
def _ah(s, t): draw_hand(s, t, 1.0, True)


@part("arm_far_upper", (-28, -34, 58, 104))
def _bu(s, t): draw_upper(s, t, FAR)


@part("arm_far_fore", (-24, -20, 48, 82))
def _bfo(s, t): draw_fore(s, t, FAR)


@part("arm_far_hand", (-22, -14, 46, 52))
def _bh(s, t): draw_hand(s, t, FAR, False)


def draw_thread(s: Svg, color: str) -> None:
    s.shape("M-17 41 C-6 39 6 39 17 41 L17 48 C6 46 -6 46 -17 48 Z", color, 3.5)
    for d in ("M16 44 L24 51", "M16 44 L25 41"):
        s.line(d, OUT, 7.5)
        s.line(d, color, 3.5)
    s.circle(16, 44, 4, color, 3)


@part("thread", (-24, 30, 56, 30))
def _thread(s, t): draw_thread(s, THREAD)


@part("thread_silver", (-24, 30, 56, 30))
def _thread_s(s, t): draw_thread(s, SILVER)


# ---- amulet (slot belongs to the Owl, bible §5.7; the art follows the hero tier for now)
@part("amulet_t1", (-22, -42, 46, 66))
def _am1(s: Svg, tier: int) -> None:
    s.line("M-12 -38 Q-10 -12 -2 -6 M4 -38 Q7 -16 3 -6", "#3E2A1C", 3.5)
    s.circle(0, 4, 12, WOOD, 6)
    s.circle(0, 4, 6, "none", 0)
    s.line("M0 -4 L0 12 M-8 4 L8 4 M-5 -2 L5 10 M5 -2 L-5 10", "#5A3E26", 2.2)
    s.raw('<circle cx="0" cy="4" r="6.5" fill="none" stroke="#5A3E26" stroke-width="2.2"/>')
    s.ellipse(-3, 0, 3, 2, "#E2C08C", 0.7)


@part("amulet_t5", (-24, -42, 50, 70))
def _am5(s: Svg, tier: int) -> None:
    s.line("M-12 -38 Q-10 -12 -2 -8 M4 -38 Q7 -16 3 -8", GOLD[2], 4)
    s.line("M-12 -38 Q-10 -12 -2 -8 M4 -38 Q7 -16 3 -8", GOLD[1], 2)
    s.circle(0, 5, 15, GOLD_HI, 6)
    for i in range(8):
        a = i * math.pi / 4
        s.raw(f'<circle cx="{11 * math.cos(a):.1f}" cy="{5 + 11 * math.sin(a):.1f}" r="1.8" fill="{GOLD[2]}"/>')
    s.circle(0, 5, 6.5, ("#FFFFFF", "#FFF2C0", "#FFC94A"), 3)


@part("amulet_glow", (-64, -64, 128, 128))
def _glow(s: Svg, tier: int) -> None:
    s.defs.append('<radialGradient id="rg"><stop offset="0" stop-color="#FFFFFF" stop-opacity="1"/>'
                  '<stop offset="0.25" stop-color="#FFFFFF" stop-opacity="0.55"/>'
                  '<stop offset="1" stop-color="#FFFFFF" stop-opacity="0"/></radialGradient>')
    s.raw('<circle cx="0" cy="0" r="64" fill="url(#rg)"/>')


# ---- cape (корзно, tier 5)
@part("cape_back_1_t5", (-40, -22, 80, 92))
def _c1(s: Svg, tier: int) -> None:
    d = "M-26 -12 C-10 -18 12 -18 24 -12 L31 62 L-33 62 Z"
    s.shape(d, RED)
    s.line("M-4 0 C-6 20 -8 40 -10 60 M12 2 C14 22 16 42 18 60", RED[2], 3.5, 0.8)


@part("cape_back_2_t5", (-48, -16, 94, 88))
def _c2(s: Svg, tier: int) -> None:
    d = "M-33 -8 L31 -8 L37 64 L-39 64 Z"
    s.shape(d, RED)
    s.line("M-8 -4 C-10 20 -12 40 -14 62 M14 -4 C16 20 18 40 20 62", RED[2], 3.5, 0.8)


@part("cape_back_3_t5", (-54, -16, 106, 84))
def _c3(s: Svg, tier: int) -> None:
    d = "M-39 -8 L37 -8 L42 50 C22 58 -20 58 -46 50 Z"
    s.shape(d, RED)
    c = s.clip(d)
    s.line("M-12 -4 C-14 16 -16 34 -18 52 M16 -4 C18 16 20 34 22 52", RED[2], 3.5, 0.8, c)
    # one gold ornament band on the hem (bible §5.4, §5.6)
    band = "M-45 38 C-20 46 20 46 41 38 L42 50 C22 58 -20 58 -46 50 Z"
    s.shape(band, GOLD, 5, vertical=True)
    zz = " ".join(f"M{x} {44 + (2 if abs(x) < 20 else 0)} l4 -4 l4 4 l-4 4 Z" for x in range(-40, 38, 10))
    s.soft(zz, GOLD[2], 0.9, s.clip(band))


@part("cape_front_t5", (-50, -114, 76, 52))
def _cf(s: Svg, tier: int) -> None:
    s.sx = WIDE_TORSO
    d = "M-35 -82 C-27 -101 -7 -106 5 -101 C13 -96 15 -89 11 -83 C1 -78 -17 -74 -31 -68 Z"
    s.shape(d, RED)
    s.line("M-31 -70 C-17 -76 1 -80 10 -85", GOLD[1], 4)
    s.line("M-24 -92 C-14 -96 -4 -98 4 -96", RED[0], 2.5, 0.8)
    s.circle(5, -88, 7, GOLD_HI, 4.5)                                       # fibula
    s.line("M-3 -94 L13 -82", GOLD[2], 2.5)


# ---- tiers 2-4 (bible §5.6 «Пять ярусов»): Странник, Ополченец, Витязь.
# Rects equal the rect the scene already uses for that sprite (EMPTY_RECT / tier-5 part).
TORSO_RECT = (-62, -112, 128, 134)
SKIRT_RECT = (-44, -16, 90, 72)
HELMET_RECT = (-44, -136, 90, 90)
CAPE_FRONT_RECT = (-50, -114, 76, 52)
AMULET_RECT = (-22, -42, 46, 66)
QUILT_WIDE = 1.22  # tegilyai: the shoulders get wider (bible t3 silhouette)


@part("torso_cloth_t2", TORSO_RECT)
def _shirt(s: Svg, tier: int) -> None:
    s.sx = WIDE_TORSO
    s.shape(ARMOR_D, LINEN)
    c = s.clip(ARMOR_D)
    s.soft("M-46 -70 C-38 -40 -32 -10 -28 18 L-50 18 L-50 -70 Z", LINEN[2], 0.45, c)
    s.soft("M10 -56 C22 -46 36 -44 50 -54 L50 -16 C38 -26 22 -36 10 -42 Z", LINEN[2], 0.35, c)
    s.line("M-30 -60 C-28 -40 -24 -20 -22 10 M30 -40 C32 -20 30 0 28 14", LINEN[2], 2.5, 0.7, c)
    # kosovorotka collar and placket, red embroidery (bible t2)
    s.shape("M-6 -100 C2 -92 12 -91 20 -98 L23 -89 C13 -82 0 -84 -9 -92 Z", RED, 5)
    s.line("M20 -92 L26 -66", RED[1], 5, 1.0, c)
    s.line("M-2 -94 l4 3 l4 -3 l4 3 l4 -3", "#F2D6A0", 1.6, 0.9)


@part("skirt_t2", SKIRT_RECT)
def _shirt_hem(s: Svg, tier: int) -> None:
    d = "M-34 -12 L37 -12 C40 2 41 12 41 22 C14 27 -14 27 -38 22 C-38 12 -37 2 -34 -12 Z"
    s.shape(d, LINEN)
    c = s.clip(d)
    s.soft("M-42 -12 L-22 -12 L-24 30 L-42 30 Z", LINEN[2], 0.45, c)
    band = "M-40 12 C-14 17 14 17 42 12 L42 24 C14 29 -14 29 -40 24 Z"
    s.shape(band, RED, 0, clip=c)
    zz = " ".join(f"M{x} 19 l3 -3 l3 3 l-3 3 Z" for x in range(-36, 38, 8))
    s.soft(zz, "#F2D6A0", 0.9, c)


@part("torso_cloth_t3", TORSO_RECT)
def _tegilyai(s: Svg, tier: int) -> None:
    s.sx = QUILT_WIDE
    s.shape(ARMOR_D, QUILT)
    c = s.clip(ARMOR_D)
    s.soft("M-46 -70 C-38 -40 -32 -10 -28 18 L-50 18 L-50 -70 Z", QUILT[2], 0.45, c)
    s.soft("M10 -56 C22 -46 36 -44 50 -54 L50 -16 C38 -26 22 -36 10 -42 Z", QUILT[2], 0.3, c)
    # quilting: vertical channels, puffed between (bible t3: «простёганная куртка»)
    s.line(" ".join(f"M{x} -96 C{x - 2} -50 {x - 3} -10 {x - 4} 20" for x in range(-36, 52, 11)), QUILT[2], 2.8, 0.95, c)
    s.line(" ".join(f"M{x + 4} -94 C{x + 2} -50 {x + 1} -10 {x} 20" for x in range(-36, 52, 11)), QUILT[0], 1.6, 0.6, c)
    s.shape("M-6 -101 C2 -93 12 -91 20 -98 L22 -86 C12 -80 0 -82 -9 -90 Z", QUILT, 5)    # standing collar
    s.line("M21 -88 L27 -60 L30 -30", QUILT[2], 3.5, 1.0, c)                           # front closure


@part("skirt_t3", SKIRT_RECT)
def _tegilyai_hem(s: Svg, tier: int) -> None:
    d = "M-36 -12 L39 -12 C42 4 43 18 43 32 C14 37 -14 37 -40 32 C-40 18 -39 4 -36 -12 Z"
    s.shape(d, QUILT)
    c = s.clip(d)
    s.soft("M-44 -12 L-22 -12 L-24 40 L-44 40 Z", QUILT[2], 0.45, c)
    s.line(" ".join(f"M{x} -10 L{x - 1} 36" for x in range(-30, 42, 11)), QUILT[2], 2.8, 0.95, c)
    s.line("M14 -8 L16 34", OUT, 3, 0.8)


@part("belt_t3", (-40, -24, 82, 44))
def _belt3(s: Svg, tier: int) -> None:
    s.shape("M-37 -17 C-10 -14 12 -14 39 -17 L39 -4 C12 -1 -10 -1 -37 -4 Z", LEATHER3, 6, vertical=True)
    s.shape("M18 -21 L33 -21 L33 1 L18 1 Z", BRONZE, 5)                     # bronze buckle
    s.shape("M22 -15 L29 -15 L29 -5 L22 -5 Z", LEATHER3[2], 0)
    s.line("M26 -2 L24 14", OUT, 8)
    s.line("M26 -2 L24 14", LEATHER3[1], 4)                                 # strap end
    s.line("M-30 -10 L14 -10", LEATHER3[0], 2, 0.6)


@part("belt_t4", (-40, -24, 82, 44))
def _belt4(s: Svg, tier: int) -> None:
    s.shape("M-37 -17 C-10 -14 12 -14 39 -17 L39 -4 C12 -1 -10 -1 -37 -4 Z", LEATHER, 6, vertical=True)
    s.shape("M18 -21 L33 -21 L33 1 L18 1 Z", IRON, 5)                       # iron buckle
    s.shape("M22 -15 L29 -15 L29 -5 L22 -5 Z", LEATHER[2], 0)
    for x in (-26, -12, 2):
        s.circle(x, -10, 2.6, IRON, 2)
    s.line("M26 -2 L24 14", OUT, 8)
    s.line("M26 -2 L24 14", LEATHER[1], 4)


@part("torso_armor_t4", TORSO_RECT)
def _mail(s: Svg, tier: int) -> None:
    s.sx = WIDE_TORSO
    s.shape(ARMOR_D, MAIL)
    c = s.clip(ARMOR_D)
    s.line(mail_rows(-46, 54, -94, 18), MAIL[2], 2, 0.9, c)
    s.soft("M-46 -70 C-38 -40 -32 -10 -28 18 L-50 18 L-50 -70 Z", MAIL[2], 0.45, c)
    s.soft("M10 -56 C22 -46 36 -44 50 -54 L50 -16 C38 -26 22 -36 10 -42 Z", MAIL[2], 0.3, c)
    s.line("M30 -90 C42 -84 46 -70 44 -56", MAIL[0], 3, 0.8, c)               # sheen on the chest
    # tegilyai collar shows at the neck (mail worn over it)
    s.shape("M-6 -101 C2 -93 12 -91 20 -98 L22 -88 C12 -82 0 -84 -9 -92 Z", QUILT, 5)


@part("skirt_t4", SKIRT_RECT)
def _mail_hem(s: Svg, tier: int) -> None:
    d = ("M-34 -12 L37 -12 C41 6 42 22 42 40 L36 44 L30 40 L24 44 L18 40 L12 44 L6 40 L0 44 L-6 40 "
         "L-12 44 L-18 40 L-24 44 L-30 40 L-38 42 C-39 22 -38 6 -34 -12 Z")
    s.shape(d, MAIL)
    c = s.clip(d)
    s.line(mail_rows(-42, 44, -8, 46), MAIL[2], 2, 0.9, c)
    s.soft("M-42 -12 L-22 -12 L-24 48 L-42 48 Z", MAIL[2], 0.45, c)
    s.line("M12 -6 L14 40", OUT, 3, 0.8)                                  # front slit


@part("helmet_t2", HELMET_RECT)
def _ochelye(s: Svg, tier: int) -> None:
    # tie ends hang at the back of the head
    for d in ("M-36 -60 L-42 -48", "M-35 -60 L-37 -47"):
        s.line(d, OUT, 8)
        s.line(d, LINEN[1], 4)
    band = "M-38 -68 C-12 -74 14 -74 34 -68 L34 -57 C14 -63 -12 -63 -38 -57 Z"
    s.shape(band, LINEN, 5, vertical=True)
    c = s.clip(band)
    zz = " ".join(f"M{x} -65 l3 -3 l3 3 l-3 3 Z" for x in range(-32, 32, 8))
    s.soft(zz, RED[1], 1.0, c)


@part("helmet_t3", HELMET_RECT)
def _cap(s: Svg, tier: int) -> None:
    dome = "M-37 -54 C-39 -78 -20 -94 0 -94 C20 -94 37 -82 36 -56 Z"
    s.shape(dome, LEATHER3)
    c = s.clip(dome)
    s.soft("M-40 -56 C-36 -80 -20 -92 -4 -94 L-14 -56 Z", LEATHER3[2], 0.45, c)
    s.line("M0 -93 C-2 -80 -3 -66 -4 -56 M18 -90 C20 -78 20 -66 19 -56", LEATHER3[2], 2.5, 0.9, c)  # seams
    s.line("M6 -90 C16 -86 24 -78 28 -66", LEATHER3[0], 3, 0.8, c)
    # rolled brim, a step lighter: the cap stays round (no point until tier 4)
    s.shape("M-39 -62 C-16 -66 16 -66 38 -62 L38 -51 C16 -55 -16 -55 -39 -51 Z", dark(LEATHER3, 1.2), 6, vertical=True)


@part("helmet_t4", HELMET_RECT)
def _cone(s: Svg, tier: int) -> None:
    dome = "M-33 -57 C-34 -76 -16 -92 0 -106 C16 -92 34 -76 35 -57 Z"
    s.shape(dome, STEEL)
    c = s.clip(dome)
    s.soft("M-34 -60 C-30 -78 -16 -92 -2 -104 L-8 -60 Z", STEEL[2], 0.45, c)
    s.line("M3 -100 C9 -90 14 -76 16 -62", STEEL[0], 4, 0.9)
    s.line("M0 -104 C-2 -88 -2 -72 0 -60", STEEL[2], 2.5, 0.8, c)          # ridge, plain
    s.shape("M-35 -61 C-18 -65 18 -65 37 -60 L37 -51 C18 -56 -18 -56 -35 -52 Z", IRON, 6, vertical=True)


def _cape_short(s: Svg, tier: int) -> None:
    # short накидка: ends at the waist and flares back past the wide tegilyai, so the
    # red reads in profile (bible t3: the first «хвост»; a cape to the shoulder blades
    # hides completely behind the quilted torso at 160 px)
    d = ("M-33 -8 L31 -8 L33 22 L26 28 L18 22 L10 29 L2 22 L-6 29 L-14 22 L-22 29 L-30 22 "
         "L-38 30 L-46 24 C-44 12 -38 2 -33 -8 Z")
    s.shape(d, RED)
    c = s.clip(d)
    s.line("M-8 -4 C-10 6 -12 14 -14 22 M14 -4 C15 6 16 14 17 20", RED[2], 3.5, 0.8, c)


part("cape_back_1_t3", (-40, -22, 80, 92))(PARTS["cape_back_1_t5"][1])  # t4 falls back to it
part("cape_back_2_t3", (-48, -16, 94, 88))(_cape_short)
part("cape_back_2_t4", (-48, -16, 94, 88))(PARTS["cape_back_2_t5"][1])


@part("cape_back_3_t4", (-54, -16, 106, 84))
def _c3_knee(s: Svg, tier: int) -> None:
    d = "M-39 -8 L37 -8 L40 22 C20 30 -20 30 -44 22 Z"   # to the knee, no border (bible t4)
    s.shape(d, RED)
    c = s.clip(d)
    s.line("M-12 -4 C-13 6 -14 14 -15 24 M16 -4 C17 6 18 14 19 24", RED[2], 3.5, 0.8, c)


def _cape_front_plain(s: Svg, tier: int) -> None:
    s.sx = WIDE_TORSO
    d = "M-35 -82 C-27 -101 -7 -106 5 -101 C13 -96 15 -89 11 -83 C1 -78 -17 -74 -31 -68 Z"
    s.shape(d, RED)
    s.line("M-24 -92 C-14 -96 -4 -98 4 -96", RED[0], 2.5, 0.8)
    if tier == 3:   # tied with a leather cord
        s.line("M3 -92 L12 -82 M5 -92 L0 -80", OUT, 7)
        s.line("M3 -92 L12 -82 M5 -92 L0 -80", LEATHER3[0], 3)
        s.circle(4, -92, 4.5, LEATHER3, 3.5)
    else:           # plain iron ring, the fibula is tier 5
        s.circle(5, -88, 6, IRON, 4)
        s.circle(5, -88, 2.2, RED[2], 0)


part("cape_front_t3", CAPE_FRONT_RECT)(_cape_front_plain)
part("cape_front_t4", CAPE_FRONT_RECT)(_cape_front_plain)


def _amulet_mid(s: Svg, tier: int) -> None:
    cord = "M-12 -38 Q-10 -12 -2 -6 M4 -38 Q7 -16 3 -6"
    s.line(cord, LEATHER[2], 4)
    s.line(cord, LEATHER[0], 2)
    r = {2: 12, 3: 13, 4: 14}[tier]
    rim = BRONZE if tier < 4 else GOLD
    s.circle(0, 4, r, rim, 5.5)
    centre = {2: ("#C08A4A", "#9A6A30", "#6E4A20"), 3: ("#F0C078", "#D49C5A", "#A06A2E"),
              4: ("#F6D48A", "#E0A858", "#B07A3A")}[tier]
    s.circle(0, 4, r - 5, centre, 2.5)
    s.raw(f'<circle cx="0" cy="4" r="{r - 8}" fill="none" stroke="{BRONZE[2]}" stroke-width="1.8"/>')
    s.ellipse(-3, -1, 3, 2, "#FFF0C8", 0.75)


for _t in (2, 3, 4):
    part(f"amulet_t{_t}", AMULET_RECT)(_amulet_mid)


# ---- weapon in hand: the starting stick (grip at 0,0, points along +x)
@part("weapon_stick", (-52, -26, 236, 46))
def _stick(s: Svg, tier: int) -> None:
    d = ("M-42 -7 C-20 -9 40 -10 98 -9 L104 -19 L111 -17 L108 -8 C134 -7 160 -6 173 -4 "
         "C180 -2 180 4 173 6 C150 8 110 9 60 10 C20 10 -20 9 -42 8 C-48 6 -48 -5 -42 -7 Z")
    s.shape(d, STICK, vertical=True)
    c = s.clip(d)
    s.soft("M-50 3 L180 1 L180 14 L-50 14 Z", STICK[2], 0.45, c)
    s.line("M-30 -3 L40 -4 M60 -4 L150 -3", STICK[0], 2.5, 0.7, c)         # bark sheen
    s.ellipse(68, 1, 5, 3, STICK[2])                                         # knots
    s.ellipse(136, 0, 4, 2.5, STICK[2])
    s.line("M16 -8 L16 9 M23 -8 L23 9 M30 -8 L30 9", "#C9A676", 2.5, 0.9)  # carved rings
    s.line("M-40 -5 L-40 6", "#C9A676", 3, 0.8)                            # cut end


# ------------------------------------------------------------------ which files exist
TIERED: dict[str, list[int]] = {
    "hair_t": [1], "helmet_t": [5], "aventail_t": [5], "torso_armor_t": [5], "skirt_t": [5],
}
# part name -> list of (file stem, tier)
FILES: list[tuple[str, str, int]] = []
# multi-tier parts: which tiers get their own file (others fall back to the lower one)
PART_TIERS: dict[str, tuple] = {
    "legs_cloth_pelvis": (1, 3, 5), "legs_cloth_thigh": (1, 2, 3, 5), "legs_cloth_shin": (1, 2, 3, 5),
    "boots_shin": (1, 2, 3, 4, 5), "boots_foot": (1, 2, 3, 5),
    "leg_far_thigh": (1, 2, 3, 5), "leg_far_shin": (1, 2, 3, 4, 5), "leg_far_foot": (1, 2, 3, 5),
    "arm_near_upper": (1, 2, 3, 4, 5), "arm_near_fore": (1, 2, 3, 4, 5),
    "arm_far_upper": (1, 2, 3, 4, 5), "arm_far_fore": (1, 2, 3, 4, 5),
}
for name in PARTS:
    if name[-3:-1] == "_t" and name[-1].isdigit():
        FILES.append((name, name, int(name[-1])))
    elif name.startswith(("legs_cloth_", "boots_", "leg_far_", "arm_near_", "arm_far_")):
        for t in PART_TIERS.get(name, (1, 5)):
            FILES.append((name, f"{name}_t{t}", t))
    else:
        FILES.append((name, name, 0))


IMPORT = """[remap]

importer="texture"
type="CompressedTexture2D"

[deps]

source_file="{src}"

[params]

compress/mode=0
compress/high_quality=false
compress/lossy_quality=0.7
mipmaps/generate=true
mipmaps/limit=-1
process/fix_alpha_border=true
process/premult_alpha=false
detect_3d/compress_to=0
svg/scale=1.0
editor/scale_with_editor_scale=false
editor/convert_colors_with_editor_theme=false
"""


def write_art() -> None:
    os.makedirs(ART_DIR, exist_ok=True)
    for name, stem, tier in FILES:
        rect, fn = PARTS[name]
        s = Svg(rect)
        fn(s, tier if tier else 1)
        path = os.path.join(ART_DIR, f"char_hero_{stem}_01.svg")
        with open(path, "w", encoding="utf-8") as f:
            f.write(s.text())
        imp = path + ".import"
        if not os.path.exists(imp):
            with open(imp, "w", encoding="utf-8") as f:
                f.write(IMPORT.format(src=RES_ART + os.path.basename(path)))


# ------------------------------------------------------------------ rig
# Bone: name -> (parent, rest position in parent space, source px)
BONES: list[tuple[str, str, tuple]] = [
    ("Hip", "", (0, -150)),
    ("Torso", "Hip", (0, -6)),
    ("Head", "Torso", (6, -92)),
    ("Amulet", "Torso", (17, -66)),
    ("ArmB", "Torso", (27, -82)), ("ForeB", "ArmB", (0, 56)), ("HandB", "ForeB", (0, 50)),
    ("WeaponB", "HandB", (0, 14)),
    ("ArmF", "Torso", (-17, -80)), ("ForeF", "ArmF", (0, 56)), ("HandF", "ForeF", (0, 50)),
    ("WeaponF", "HandF", (0, 14)),
    ("Cape1", "Torso", (-24, -80)), ("Cape2", "Cape1", (0, 52)), ("Cape3", "Cape2", (0, 54)),
    ("LegB", "Hip", (12, 2)), ("ShinB", "LegB", (0, 66)), ("FootB", "ShinB", (0, 62)),
    ("LegF", "Hip", (-8, 4)), ("ShinF", "LegF", (0, 66)), ("FootF", "ShinF", (0, 62)),
]
PARENT = {b: p for b, p, _ in BONES}
REST = {b: pos for b, _, pos in BONES}
THIGH_L, SHIN_L = 66.0, 62.0

# Slot sprites in draw order (art bible §5.7 z column, far to near): (sprite, slot, bone, default file)
SPRITES: list[tuple[str, str, str, str]] = [
    ("cape_back_1", "cape_back", "Cape1", "cape_back_1_t5"),
    ("cape_back_2", "cape_back", "Cape2", "cape_back_2_t5"),
    ("cape_back_3", "cape_back", "Cape3", "cape_back_3_t5"),
    ("weapon_off", "weapon_off", "WeaponB", ""),
    ("arm_far_upper", "arm_far", "ArmB", "arm_far_upper_t1"),
    ("arm_far_fore", "arm_far", "ForeB", "arm_far_fore_t1"),
    ("arm_far_hand", "arm_far", "HandB", "arm_far_hand_t1"),
    ("leg_far_foot", "leg_far", "FootB", "leg_far_foot_t1"),
    ("leg_far_shin", "leg_far", "ShinB", "leg_far_shin_t1"),
    ("leg_far_thigh", "leg_far", "LegB", "leg_far_thigh_t1"),
    ("body_base_pelvis", "body_base", "Hip", "body_base_pelvis"),
    ("body_base_torso", "body_base", "Torso", "body_base_torso"),
    ("legs_cloth_shin", "legs_cloth", "ShinF", "legs_cloth_shin_t1"),
    ("legs_cloth_thigh", "legs_cloth", "LegF", "legs_cloth_thigh_t1"),
    ("legs_cloth_pelvis", "legs_cloth", "Hip", "legs_cloth_pelvis_t1"),
    ("boots_shin", "boots", "ShinF", "boots_shin_t1"),
    ("boots_foot", "boots", "FootF", "boots_foot_t1"),
    ("torso_cloth", "torso_cloth", "Torso", ""),
    ("torso_armor", "torso_armor", "Torso", ""),
    ("skirt", "skirt", "Hip", ""),
    ("belt", "belt", "Hip", "belt_t1"),
    ("aventail", "aventail", "Head", ""),
    ("head_base", "head_base", "Head", "head_base"),
    ("hair", "hair", "Head", "hair_t1"),
    ("helmet", "helmet", "Head", ""),
    ("cape_front", "cape_front", "Torso", ""),
    ("amulet", "amulet", "Amulet", "amulet_t1"),
    ("weapon_main", "weapon_main", "WeaponF", "weapon_stick"),
    ("arm_near_upper", "arm_near", "ArmF", "arm_near_upper_t1"),
    ("arm_near_fore", "arm_near", "ForeF", "arm_near_fore_t1"),
    ("arm_near_hand", "arm_near", "HandF", "arm_near_hand_t1"),
    ("thread", "thread", "ForeF", "thread"),
]
# The aventail hangs BEHIND the head (it is mail at the back of the neck), so it is
# drawn under head_base here although the bible lists z 22; see the report.
# Rects for slots empty at tier 1 come from their tier-5 drawing (same canvas on every tier).
EMPTY_RECT = {"torso_armor": "torso_armor_t5", "skirt": "skirt_t5", "aventail": "aventail_t5",
              "helmet": "helmet_t5", "cape_front": "cape_front_t5", "torso_cloth": "torso_armor_t5",
              "weapon_off": "weapon_stick"}

# ------------------------------------------------------------------ poses
ANIM_BONES = ["Hip", "Torso", "Head", "ArmF", "ForeF", "HandF", "WeaponF", "ArmB", "ForeB", "HandB",
              "WeaponB", "LegF", "ShinF", "FootF", "LegB", "ShinB", "FootB"]


def pose(**kw) -> dict:
    """A key pose. Angles in radians, bone-local (limbs point down at 0; + is
    clockwise on screen = backwards for a limb, forwards for the torso).
    stick=<a> sets WeaponF so the stick points at screen angle a (0 = forward,
    -pi/2 = up). ground=True drops the hip so the lower sole touches y = 0;
    flat=True keeps both feet level. dy adds to the hip height afterwards."""
    p = {b: 0.0 for b in ANIM_BONES}
    p.update({"hip_x": 0.0, "hip_y": -150.0, "ground": False, "flat": True, "dy": 0.0})
    p.update({"Torso": 0.05, "Head": -0.05})
    p.update(kw)
    hip = p["Hip"]
    if p.get("stick") is not None:
        p["WeaponF"] = p["stick"] - (hip + p["Torso"] + p["ArmF"] + p["ForeF"] + p["HandF"])
    if "stickB" in p:
        p["WeaponB"] = p["stickB"] - (hip + p["Torso"] + p["ArmB"] + p["ForeB"] + p["HandB"])
    if p["flat"]:
        for leg, shin, foot in (("LegF", "ShinF", "FootF"), ("LegB", "ShinB", "FootB")):
            p[foot] = p.get(foot + "_add", 0.0) - (hip + p[leg] + p[shin])
    if p["ground"]:
        low = 0.0
        for leg, shin, oy in (("LegF", "ShinF", 4), ("LegB", "ShinB", 2)):
            a1 = hip + p[leg]
            low = max(low, oy + THIGH_L * math.cos(a1) + SHIN_L * math.cos(a1 + p[shin]))
        p["hip_y"] = -(low + 18.0)
    p["hip_y"] += p["dy"]
    return p


STANCE = dict(LegF=-0.16, ShinF=0.18, LegB=0.2, ShinB=0.1, ground=True)
IDLE_ARMS = dict(ArmF=-0.25, ForeF=-0.95, stick=-1.62, ArmB=0.16, ForeB=-0.35, HandB=0.1)


def idle() -> list:
    ks = []
    for i, (br, kn) in enumerate([(0.0, 0.0), (0.5, 0.6), (1.0, 1.0), (0.5, 0.4)]):
        kw = dict(STANCE)
        kw.update(IDLE_ARMS)
        kw.update(LegF=-0.16 - 0.04 * kn, ShinF=0.18 + 0.09 * kn, LegB=0.2 + 0.02 * kn, ShinB=0.1 + 0.06 * kn,
                  Torso=0.05 - 0.03 * br, Head=-0.05 + 0.02 * br, ArmB=0.16 + 0.05 * br,
                  ForeB=-0.35 - 0.06 * br, ArmF=-0.25 - 0.02 * br)
        ks.append((i * 0.3, pose(**kw)))
    ks.append((1.2, ks[0][1]))
    return ks


RUN_LEG = [(-0.6, 0.2), (-0.35, 0.5), (0.0, 0.4), (0.4, 0.3), (0.75, 0.85), (0.45, 1.55), (-0.25, 1.6),
           (-0.75, 0.8)]
RUN_FOOT = [0.0, 0.0, 0.0, 0.35, 0.8, 0.6, 0.25, -0.15]
RUN_DY = [2, 8, 2, -6, 2, 8, 2, -6]


def run() -> list:
    ks = []
    for i in range(8):
        tf, sf = RUN_LEG[i]
        tb, sb = RUN_LEG[(i + 4) % 8]
        kw = dict(LegF=tf, ShinF=sf, FootF_add=RUN_FOOT[i], LegB=tb, ShinB=sb, FootB_add=RUN_FOOT[(i + 4) % 8],
                  Torso=0.26 + (0.03 if RUN_DY[i] > 4 else 0.0), Head=-0.18,
                  ArmF=-0.85 * tf + 0.1, ForeF=-1.25 - 0.25 * max(0.0, -tf), stick=-0.45 + 0.15 * tf,
                  ArmB=-0.85 * tb + 0.1, ForeB=-1.2 - 0.25 * max(0.0, -tb), HandB=0.2,
                  ground=False)
        p = pose(**kw)
        # stance-leg contact: the lower foot touches the ground, then the bob
        low = 0.0
        for leg, shin, oy in ((tf, sf, 4), (tb, sb, 2)):
            low = max(low, oy + THIGH_L * math.cos(leg) + SHIN_L * math.cos(leg + shin))
        p["hip_y"] = -(low + 18.0) - RUN_DY[i] + 8
        ks.append((i * 0.0625, p))
    ks.append((0.5, ks[0][1]))
    return ks


def jump() -> list:
    a = pose(LegF=-1.0, ShinF=1.5, LegB=-0.25, ShinB=1.0, Torso=0.12, Head=-0.1, ArmF=-0.9, ForeF=-0.9,
             stick=-1.2, ArmB=-1.6, ForeB=-0.5, flat=False, FootF=-0.2, FootB=0.3)
    b = pose(LegF=-0.7, ShinF=1.1, LegB=0.05, ShinB=0.8, Torso=0.08, Head=-0.06, ArmF=-1.1, ForeF=-0.8,
             stick=-1.4, ArmB=-1.9, ForeB=-0.4, flat=False, FootF=-0.1, FootB=0.4)
    return [(0.0, a), (0.25, b)]


def fall() -> list:
    a = pose(LegF=-0.4, ShinF=0.55, LegB=0.25, ShinB=0.5, Torso=0.02, Head=0.0, ArmF=-1.5, ForeF=-0.6,
             stick=-1.0, ArmB=-2.3, ForeB=-0.3, flat=False, FootF=0.15, FootB=0.35)
    b = pose(LegF=-0.32, ShinF=0.45, LegB=0.3, ShinB=0.58, Torso=0.0, Head=0.02, ArmF=-1.6, ForeF=-0.5,
             stick=-1.1, ArmB=-2.45, ForeB=-0.25, flat=False, FootF=0.2, FootB=0.3)
    return [(0.0, a), (0.2, b), (0.4, a)]


def roll() -> list:
    tuck = dict(LegF=-1.75, ShinF=2.35, LegB=-1.4, ShinB=2.3, ArmF=-0.9, ForeF=-1.5, ArmB=-1.0, ForeB=-1.5,
                Head=-0.3, flat=False, FootF=-0.4, FootB=-0.4)
    ks = [(0.0, pose(**dict(tuck, Torso=0.7, hip_y=-104, Hip=0.0, stick=0.4)))]
    for i, r in enumerate([1.25, 2.55, 3.85, 5.1]):
        ks.append((0.05 + i * 0.05, pose(**dict(tuck, Torso=1.05, hip_y=-94, Hip=r, stick=r + 0.4))))
    ks.append((0.3, pose(**dict(STANCE, ArmF=-0.6, ForeF=-1.2, stick=-0.4 + math.tau, ArmB=-0.4,
                               ForeB=-1.0, Torso=0.35, Head=-0.2, Hip=math.tau, LegF=-0.7, ShinF=1.2,
                               LegB=0.1, ShinB=1.0, dy=0))))
    return ks


def dash() -> list:
    a = dict(Hip=0.18, Torso=0.5, Head=-0.55, LegF=0.45, ShinF=1.1, LegB=0.95, ShinB=0.75, ArmF=-1.5, ForeF=-0.1,
             stick=0.05, ArmB=1.1, ForeB=-0.3, flat=False, FootF=0.5, FootB=0.6)
    b = dict(a, LegF=0.55, ShinF=1.2, LegB=1.05, ArmB=1.25, stick=0.0)
    c = dict(a, Hip=0.08, Torso=0.3, LegF=0.0, ShinF=0.9, LegB=0.5, ShinB=0.8, ArmF=-1.2, ForeF=-0.4, stick=-0.2)
    return [(0.0, pose(**a)), (0.09, pose(**b)), (0.17, pose(**c))]


WIDE = dict(LegF=-0.42, ShinF=0.4, LegB=0.42, ShinB=0.3, ground=True)


def strike(keys: list, length: float, base: dict) -> list:
    return [(k * length, pose(**dict(base, **kw))) for k, kw in keys]


def strike_1() -> list:
    return strike([
        (0.0, dict(ArmF=-2.4, ForeF=-0.5, stick=-2.3, ArmB=0.2, ForeB=-0.6, Torso=0.0)),
        (0.2, dict(ArmF=-3.55, ForeF=-0.5, stick=-3.1, ArmB=0.5, ForeB=-0.4, Torso=-0.12, Head=0.0)),
        (0.4, dict(ArmF=-1.45, ForeF=-0.1, stick=0.05, ArmB=0.95, ForeB=-0.3, Torso=0.3, Head=-0.2, hip_x=10)),
        (0.65, dict(ArmF=-0.75, ForeF=-0.15, stick=0.95, ArmB=0.9, ForeB=-0.4, Torso=0.36, Head=-0.25, hip_x=12)),
        (1.0, dict(ArmF=-0.4, ForeF=-0.8, stick=0.5, ArmB=0.35, ForeB=-0.6, Torso=0.2, Head=-0.12, hip_x=6)),
    ], 0.22, WIDE)


def strike_2() -> list:
    return strike([
        (0.0, dict(ArmF=0.6, ForeF=-0.2, stick=2.1, ArmB=-0.6, ForeB=-0.8, Torso=0.32, Head=-0.25)),
        (0.2, dict(ArmF=1.0, ForeF=-0.1, stick=2.6, ArmB=-0.8, ForeB=-0.8, Torso=0.38, Head=-0.28)),
        (0.4, dict(ArmF=-1.5, ForeF=-0.2, stick=-0.55, ArmB=0.5, ForeB=-0.5, Torso=0.05, Head=-0.1, hip_x=10)),
        (0.65, dict(ArmF=-2.4, ForeF=-0.4, stick=-1.5, ArmB=0.8, ForeB=-0.4, Torso=-0.08, Head=0.0, hip_x=12)),
        (1.0, dict(ArmF=-1.5, ForeF=-0.8, stick=-1.2, ArmB=0.3, ForeB=-0.5, Torso=0.05, hip_x=6)),
    ], 0.22, WIDE)


def strike_3() -> list:
    low = dict(LegF=-0.75, ShinF=0.95, LegB=0.65, ShinB=0.55, ground=True)
    return strike([
        (0.0, dict(ArmF=-2.2, ForeF=-0.5, stick=-2.0, ArmB=0.0, ForeB=-0.5)),
        (0.12, dict(ArmF=-3.3, ForeF=-0.5, stick=-2.8, ArmB=0.5, ForeB=-0.4, Torso=-0.18, LegF=-0.3,
                    ShinF=0.2, LegB=0.3, ShinB=0.15)),
        (0.25, dict(ArmF=-3.9, ForeF=-0.65, stick=-3.5, ArmB=0.8, ForeB=-0.3, Torso=-0.3, Head=0.05, LegF=-0.3,
                    ShinF=0.2, LegB=0.3, ShinB=0.15)),
        (0.38, dict(ArmF=-2.1, ForeF=-0.2, stick=-1.1, ArmB=1.0, ForeB=-0.3, Torso=0.15, hip_x=8)),
        (0.48, dict(low, ArmF=-0.55, ForeF=-0.1, stick=1.15, ArmB=1.2, ForeB=-0.2, Torso=0.55, Head=-0.35,
                    hip_x=16)),
        (0.65, dict(low, ArmF=-0.45, ForeF=-0.1, stick=1.25, ArmB=1.15, ForeB=-0.3, Torso=0.58, Head=-0.38,
                    hip_x=16)),
        (0.82, dict(low, ArmF=-0.4, ForeF=-0.5, stick=0.9, ArmB=0.7, ForeB=-0.5, Torso=0.45, Head=-0.3, hip_x=12)),
        (1.0, dict(ArmF=-0.35, ForeF=-0.8, stick=0.5, ArmB=0.35, ForeB=-0.6, Torso=0.2, Head=-0.12, hip_x=6)),
    ], 0.40, WIDE)


def strike_up() -> list:
    crouch = dict(LegF=-0.5, ShinF=0.8, LegB=0.4, ShinB=0.7, ground=True)
    tall = dict(LegF=-0.12, ShinF=0.08, LegB=0.15, ShinB=0.05, ground=True)
    return strike([
        (0.0, dict(crouch, ArmF=-0.3, ForeF=-0.3, stick=0.9, ArmB=-0.3, ForeB=-0.8, Torso=0.22)),
        (0.2, dict(crouch, ArmF=0.25, ForeF=-0.2, stick=1.7, ArmB=-0.4, ForeB=-0.8, Torso=0.28, Head=-0.2)),
        (0.4, dict(tall, ArmF=-2.3, ForeF=-0.25, stick=-1.15, ArmB=0.4, ForeB=-0.5, Torso=-0.05, Head=0.1)),
        (0.6, dict(tall, ArmF=-3.05, ForeF=-0.15, stick=-1.95, ArmB=0.6, ForeB=-0.4, Torso=-0.15, Head=0.18)),
        (1.0, dict(tall, ArmF=-2.6, ForeF=-0.5, stick=-1.6, ArmB=0.3, ForeB=-0.5, Torso=-0.05, Head=0.05)),
    ], 0.24, {})


def strike_down() -> list:
    base = dict(flat=False)
    return strike([
        (0.0, dict(ArmF=-2.5, ForeF=-0.4, stick=-1.65, LegF=-1.2, ShinF=1.7, LegB=-0.6, ShinB=1.5, Torso=0.12,
                   ArmB=-1.4, ForeB=-0.5, FootF=-0.3, FootB=0.1)),
        (0.2, dict(ArmF=-0.25, ForeF=0.05, stick=1.57, LegF=-1.45, ShinF=2.0, LegB=-0.35, ShinB=1.3, Torso=0.28,
                   Head=0.15, ArmB=-1.9, ForeB=-0.4, FootF=-0.2, FootB=0.3)),
        (0.6, dict(ArmF=-0.22, ForeF=0.02, stick=1.6, LegF=-1.5, ShinF=2.05, LegB=-0.38, ShinB=1.35, Torso=0.3,
                   Head=0.18, ArmB=-2.0, ForeB=-0.35, FootF=-0.2, FootB=0.3)),
        (1.0, dict(ArmF=-0.25, ForeF=0.05, stick=1.57, LegF=-1.45, ShinF=2.0, LegB=-0.35, ShinB=1.3, Torso=0.28,
                   Head=0.15, ArmB=-1.9, ForeB=-0.4, FootF=-0.2, FootB=0.3)),
    ], 0.30, base)


def hurt() -> list:
    air = dict(flat=False, LegF=-0.5, ShinF=0.8, LegB=0.3, ShinB=0.6, FootF=0.1, FootB=0.2)
    return [
        (0.0, pose(**dict(air, Hip=-0.18, Torso=-0.38, Head=-0.45, ArmF=-1.2, ForeF=-0.7, stick=-1.9,
                          ArmB=-1.8, ForeB=-0.5))),
        (0.1, pose(**dict(air, Hip=-0.12, Torso=-0.28, Head=-0.3, ArmF=-1.0, ForeF=-0.8, stick=-1.8,
                          ArmB=-1.5, ForeB=-0.6))),
        (0.2, pose(**dict(air, Hip=-0.05, Torso=-0.1, Head=-0.12, ArmF=-0.7, ForeF=-0.9, stick=-1.6,
                          ArmB=-0.9, ForeB=-0.6))),
    ]


def death() -> list:
    kneel = dict(LegF=-1.45, ShinF=2.5, LegB=0.55, ShinB=1.65, ground=True)
    ks = [
        (0.0, dict(STANCE, Torso=-0.35, Head=-0.45, ArmF=-1.1, ForeF=-0.7, stick=-1.9, ArmB=-1.6, ForeB=-0.5)),
        (0.1, dict(STANCE, Torso=-0.42, Head=-0.5, ArmF=-0.8, ForeF=-0.6, stick=-1.2, ArmB=-1.2, ForeB=-0.5)),
        (0.2, dict(LegF=-0.6, ShinF=1.0, LegB=0.4, ShinB=0.9, ground=True, Torso=-0.1, Head=-0.2, ArmF=-0.3,
                   ForeF=-0.4, stick=0.3, ArmB=-0.5, ForeB=-0.5)),
        (0.32, dict(kneel, Torso=0.45, Head=0.5, ArmF=0.1, ForeF=-0.2, stick=1.4, ArmB=0.1, ForeB=-0.2)),
        (0.45, dict(kneel, Torso=0.6, Head=0.7, ArmF=0.2, ForeF=-0.1, stick=1.5, ArmB=0.2, ForeB=-0.1)),
        (0.55, dict(kneel, Torso=0.62, Head=0.72, ArmF=0.15, ForeF=-0.1, stick=1.5, ArmB=0.2, ForeB=-0.1)),
        (0.68, dict(kneel, Torso=0.4, Head=0.6, ArmF=-1.4, ForeF=0.0, stick=0.2, ArmB=0.2, ForeB=-0.1, dy=-4)),
        (0.8, dict(kneel, Torso=0.15, Head=0.5, ArmF=-2.6, ForeF=0.05, stick=-1.0, ArmB=0.25, ForeB=0.0, dy=-10)),
        (0.9, dict(kneel, Torso=0.05, Head=0.45, ArmF=-2.95, ForeF=0.05, stick=-1.4, ArmB=0.3, ForeB=0.0, dy=-16)),
        (1.0, dict(kneel, Torso=0.0, Head=0.42, ArmF=-3.05, ForeF=0.05, stick=-1.5, ArmB=0.3, ForeB=0.0, dy=-20)),
    ]
    return [(t, pose(**kw)) for t, kw in ks]


def flare() -> list:
    a = dict(STANCE, Torso=-0.05, Head=-0.1, ArmF=-0.6, ForeF=-0.5, stick=-1.2, ArmB=-0.6, ForeB=-0.5)
    b = dict(STANCE, Torso=-0.18, Head=-0.25, ArmF=-1.1, ForeF=-0.2, stick=-1.6, ArmB=-1.2, ForeB=-0.2)
    return [(0.0, pose(**a)), (0.12, pose(**b))]


# name -> (keys, length, loop, interp) ; interp 1 = linear, 2 = cubic
ANIMS = {
    "idle": (idle(), 1.2, True, 2),
    "run": (run(), 0.5, True, 2),
    "jump": (jump(), 0.25, False, 2),
    "fall": (fall(), 0.4, True, 2),
    "roll": (roll(), 0.3, False, 1),
    "dash": (dash(), 0.17, False, 2),
    "strike_1": (strike_1(), 0.22, False, 1),
    "strike_2": (strike_2(), 0.22, False, 1),
    "strike_3": (strike_3(), 0.40, False, 1),
    "strike_up": (strike_up(), 0.24, False, 1),
    "strike_down": (strike_down(), 0.30, False, 1),
    "hurt": (hurt(), 0.2, False, 2),
    "death": (death(), 1.0, False, 2),
    "flare": (flare(), 0.12, False, 2),
}


# ------------------------------------------------------------------ scene
def bone_path(b: str) -> str:
    chain = []
    while b:
        chain.append(b)
        b = PARENT[b]
    return "/".join(reversed(chain))


def f(x: float) -> str:
    s = ("%.4f" % x).rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


def anim_res(name: str, keys: list, length: float, loop: bool, interp: int) -> str:
    out = [f'[sub_resource type="Animation" id="Animation_{name}"]', f'resource_name = &"{name}"',
           f"length = {f(length)}"]
    if loop:
        out.append("loop_mode = 1")
    times = ", ".join(f(t) for t, _ in keys)
    trans = ", ".join("1" for _ in keys)
    tracks = [("Hip:position", lambda p: f"Vector2({f(p['hip_x'])}, {f(p['hip_y'])})")]
    for b in ANIM_BONES:
        tracks.append((f"{b}:rotation", (lambda bb: (lambda p: f(p[bb])))(b)))
    for i, (prop, val) in enumerate(tracks):
        bone = prop.split(":")[0]
        path = "Body/Skeleton2D/" + bone_path(bone) + ":" + prop.split(":")[1]
        vals = ", ".join(val(p) for _, p in keys)
        out += [f'tracks/{i}/type = "value"', f"tracks/{i}/imported = false", f"tracks/{i}/enabled = true",
                f'tracks/{i}/path = NodePath("{path}")', f"tracks/{i}/interp = {interp}",
                f"tracks/{i}/loop_wrap = true",
                f'tracks/{i}/keys = {{\n"times": PackedFloat32Array({times}),\n'
                f'"transitions": PackedFloat32Array({trans}),\n"update": 0,\n"values": [{vals}]\n}}']
    return "\n".join(out) + "\n"


def file_for(sp_default: str) -> str:
    return f"char_hero_{sp_default}_01.svg"


def rect_of(sprite: str, default: str) -> tuple:
    key = default if default else EMPTY_RECT[sprite]
    base = key if key in PARTS else key.rsplit("_t", 1)[0]
    return PARTS[base][0]


def write_scene() -> None:
    os.makedirs(os.path.dirname(SCENE), exist_ok=True)
    ext = ['[ext_resource type="Script" path="res://src/player/hero_visual.gd" id="1_script"]',
           '[ext_resource type="Shader" path="res://assets/shaders/canvas_fx_hit_flash.gdshader" id="2_flash"]',
           f'[ext_resource type="Texture2D" path="{RES_ART}char_hero_amulet_glow_01.svg" id="3_glow"]']
    tex_id = {}
    for sp, _, _, default in SPRITES:
        if default and default not in tex_id:
            tex_id[default] = f"t_{len(tex_id)}"
            ext.append(f'[ext_resource type="Texture2D" path="{RES_ART}{file_for(default)}" id="{tex_id[default]}"]')
    subs = ['[sub_resource type="ShaderMaterial" id="Mat_flash"]\nshader = ExtResource("2_flash")\n'
            'shader_parameter/flash = 0.0\nshader_parameter/flash_color = Color(1, 1, 1, 1)\n',
            '[sub_resource type="CanvasItemMaterial" id="Mat_add"]\nblend_mode = 1\n']
    for name, (keys, length, loop, interp) in ANIMS.items():
        subs.append(anim_res(name, keys, length, loop, interp))
    lib = ",\n".join(f'&"{n}": SubResource("Animation_{n}")' for n in ANIMS)
    subs.append(f'[sub_resource type="AnimationLibrary" id="AnimationLibrary_hero"]\n_data = {{\n{lib}\n}}\n')

    nodes = ['[node name="HeroVisual" type="Node2D"]\ntexture_filter = 4\nscript = ExtResource("1_script")\n',
             '[node name="Body" type="CanvasGroup" parent="."]\nmaterial = SubResource("Mat_flash")\n'
             'fit_margin = 16.0\nclear_margin = 16.0\n',
             '[node name="Skeleton2D" type="Skeleton2D" parent="Body"]\nscale = Vector2(0.3333, 0.3333)\n']
    for b, parent, pos in BONES:
        par = "Body/Skeleton2D" + ("/" + bone_path(parent) if parent else "")
        nodes.append(f'[node name="{b}" type="Bone2D" parent="{par}"]\nposition = Vector2({pos[0]}, {pos[1]})\n'
                     f'rest = Transform2D(1, 0, 0, 1, {pos[0]}, {pos[1]})\nauto_calculate_length_and_angle = false\n'
                     f'length = 16.0\nbone_angle = 90.0\n')
    nodes.append('[node name="Parts" type="Node2D" parent="Body"]\n')
    for sp, slot, bone, default in SPRITES:
        x0, y0, _, _ = rect_of(sp, default)
        tex = f'texture = ExtResource("{tex_id[default]}")\n' if default else "visible = false\n"
        nodes.append(f'[node name="{sp}" type="Sprite2D" parent="Body/Parts"]\n{tex}centered = false\n'
                     f'offset = Vector2({x0}, {y0})\nmetadata/slot = "{slot}"\nmetadata/bone = "{bone}"\n')
    for sp, slot, bone, default in SPRITES:
        depth = len(bone_path(bone).split("/")) + 2  # RT -> bones... -> Skeleton2D -> Body
        rel = "../" * depth + "Parts/" + sp
        nodes.append(f'[node name="RT_{sp}" type="RemoteTransform2D" parent="Body/Skeleton2D/{bone_path(bone)}"]\n'
                     f'remote_path = NodePath("{rel}")\n')
    depth = len(bone_path("Amulet").split("/")) + 3
    nodes.append(f'[node name="RT_glow" type="RemoteTransform2D" parent="Body/Skeleton2D/{bone_path("Amulet")}"]\n'
                 f'position = Vector2(0, 4)\nremote_path = NodePath("{"../" * depth}Glow")\nupdate_rotation = false\n')
    nodes.append('[node name="Glow" type="Sprite2D" parent="."]\nmaterial = SubResource("Mat_add")\n'
                 'modulate = Color(1, 0.788, 0.29, 0.6)\ntexture = ExtResource("3_glow")\n')
    nodes.append('[node name="Smear" type="Node2D" parent="."]\n')
    nodes.append('[node name="Fx" type="Node2D" parent="."]\ntop_level = true\n')
    nodes.append('[node name="AnimationPlayer" type="AnimationPlayer" parent="."]\ncallback_mode_process = 2\n'
                 'libraries = {\n&"": SubResource("AnimationLibrary_hero")\n}\n')
    head = f"[gd_scene load_steps={len(ext) + len(subs) + 1} format=3]\n"
    body = "\n".join([head] + ["\n".join(ext) + "\n"] + subs + nodes)
    with open(SCENE, "w", encoding="utf-8") as fh:
        fh.write("; GENERATED by tools/asset-pipeline/hero/build_hero.py -- edit the tables there.\n" + body)


if __name__ == "__main__":
    write_art()
    write_scene()
    print("parts:", len(FILES), "anims:", len(ANIMS), "->", ART_DIR, SCENE)

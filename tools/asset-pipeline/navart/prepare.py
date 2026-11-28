"""Prepares the approved «Навь» art drop (D:\\NavArt\\final, 157 numbered PNGs on a
magenta #FF00FF key) for Godot.

    python3 tools/asset-pipeline/navart/prepare.py SRC_DIR            # everything
    python3 tools/asset-pipeline/navart/prepare.py SRC_DIR --only 1,17 # some numbers
    python3 tools/asset-pipeline/navart/prepare.py SRC_DIR --preview DIR

Per source file (index.json number -> file):
- keys the magenta out: alpha from the distance to the key colour, then a
  despill of the pink fringe on the edge band only (inner purples stay);
- backgrounds (bg_*) are saved whole: assets/art/navart/bg/<name>.webp;
- every other sheet is cut into its pieces (connected opaque regions, near
  pieces merged), each piece saved as assets/art/navart/<group>/<name>/NN.webp,
  with assets/art/navart/<group>/<name>/sheet.json: [{i, x, y, w, h, cx, cy, area}]
  in reading order (rows top to bottom, then left to right).
- --preview also writes <name>_labels.png with the piece numbers drawn, for
  mapping pieces to rig parts by eye.
Deterministic. Needs numpy, scipy, Pillow (pip install numpy scipy pillow).
"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
OUT = os.path.join(REPO, 'assets', 'art', 'navart')
FONT = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'

KEY = np.array([246.0, 6.0, 247.0])
# Distance to the key: below T0 fully transparent, above T1 fully opaque.
T0, T1 = 70.0, 150.0
# Pieces closer than MERGE px are one piece; smaller than MIN_AREA px are dust.
MERGE = 6
MIN_AREA = 260
QUALITY = 92


def group_of(name):
    """Output folder of a source file name (without the number)."""
    for pre, g in (('bg_', 'bg'), ('tiles_', 'tiles'), ('char_', 'chars'), ('skin_', 'skins'), ('hero_', 'chars'),
                   ('icons_', 'icons'), ('icon_', 'icons'), ('boons_', 'boons'), ('gods_', 'gods'), ('doors_', 'doors'),
                   ('door_', 'doors'), ('ui_', 'ui'), ('weapons_', 'weapons'), ('projectiles', 'fx'), ('vfx_', 'fx'),
                   ('pickups', 'props'), ('props_', 'props'), ('dress_', 'dress'), ('ambient_', 'ambient')):
        if name.startswith(pre):
            return g
    return 'misc'


def key(rgb):
    """RGBA float image (0..1) from an RGB uint8 array keyed on magenta, despilled."""
    f = rgb.astype(np.float32)
    d = np.sqrt(((f - KEY) ** 2).sum(-1))
    # magenta-ness: how much R and B stand above G (key blends on the edges)
    mag = np.minimum(f[..., 0], f[..., 2]) - f[..., 1]
    a = np.clip((d - T0) / (T1 - T0), 0.0, 1.0)
    bg = a <= 0.0
    # the edge band: pixels within 3 px of the keyed background
    band = ndimage.binary_dilation(bg, iterations=3) & ~bg
    spill = np.clip(mag, 0, None)
    # on the band, take the magenta that bled in out of R and B
    k = np.where(band, 0.85, 0.0)
    out = f.copy()
    out[..., 0] -= spill * k
    out[..., 2] -= spill * k
    # strongly magenta band pixels are mostly key: thin them out
    a = np.where(band & (mag > 120), a * 0.5, a)
    out = np.clip(out, 0, 255)
    return np.dstack([out / 255.0, a])


# Groups whose leftover magenta inside the art is a mistake to paint over
# (ручные_правки.md: "перекрасить магенту"); glows and boons keep their pinks.
DEMAGENTA = {'chars', 'skins', 'tiles', 'dress', 'props', 'weapons', 'bg'}


def demagenta(img):
    """Paints leftover key-coloured patches inside the art with the colours around
    them (diffusion fill). A patch pixel: R and B close to each other and far
    above G (hue ~300, the key's hue), not part of the keyed background."""
    f = img[..., :3] * 255.0
    r, g, b = f[..., 0], f[..., 1], f[..., 2]
    hi = np.maximum(r, b)
    patch = (img[..., 3] > 0.05) & (np.minimum(r, b) - g > 45) & (np.abs(r - b) < 0.3 * hi) & (g < 0.6 * hi)
    patch = ndimage.binary_dilation(patch, iterations=1) & (img[..., 3] > 0.05)
    if not patch.any():
        return img, 0
    valid = (~patch & (img[..., 3] > 0.5)).astype(np.float32)
    col = img[..., :3] * valid[..., None]
    w = valid.copy()
    k = np.ones((3, 3), np.float32)
    acc_c, acc_w = col.copy(), w.copy()
    for _ in range(60):
        acc_c = np.dstack([ndimage.convolve(acc_c[..., i], k, mode='nearest') for i in range(3)])
        acc_w = ndimage.convolve(acc_w, k, mode='nearest')
        acc_c = np.where(patch[..., None], acc_c, col)
        acc_w = np.where(patch, acc_w, w)
        # renormalise so values do not blow up
        nz = np.maximum(acc_w, 1e-6)
        acc_c = np.where(patch[..., None], acc_c / nz[..., None], acc_c)
        acc_w = np.where(patch, (acc_w > 1e-6).astype(np.float32), acc_w)
    out = img.copy()
    filled = patch & (acc_w > 0)
    out[..., :3] = np.where(filled[..., None], acc_c, img[..., :3])
    return out, int(patch.sum())


def save(img_f, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    im = Image.fromarray((np.clip(img_f, 0, 1) * 255 + 0.5).astype(np.uint8), 'RGBA')
    im.save(path, 'WEBP', quality=QUALITY, method=6, exact=False)
    return im


def pieces(alpha, merge=MERGE):
    """Pieces of an alpha map: list of (slice_y, slice_x, mask) in reading order."""
    solid = alpha > 0.12
    grown = ndimage.binary_dilation(solid, iterations=merge)
    lab, n = ndimage.label(grown)
    out = []
    for i, sl in enumerate(ndimage.find_objects(lab), 1):
        if sl is None:
            continue
        m = (lab[sl] == i) & solid[sl]
        area = int(m.sum())
        if area < MIN_AREA:
            continue
        out.append((sl, m, area))
    if not out:
        return []
    # reading order: group into rows by vertical centre overlap
    hs = np.median([s[0].stop - s[0].start for s, _, _ in out])
    out.sort(key=lambda p: (p[0][0].start + p[0][0].stop) / 2)
    rows, cur, cy = [], [], None
    for p in out:
        c = (p[0][0].start + p[0][0].stop) / 2
        if cy is not None and c - cy > hs * 0.6:
            rows.append(cur)
            cur = []
        cur.append(p)
        cy = c if len(cur) == 1 else cy
    rows.append(cur)
    res = []
    for r in rows:
        res.extend(sorted(r, key=lambda p: p[0][1].start))
    return res


def run(src, entries, preview=None):
    report = []
    for e in entries:
        no, file = int(e['no']), e['file']
        name = os.path.splitext(file)[0][4:]
        g = group_of(name)
        rgb = np.array(Image.open(os.path.join(src, file)).convert('RGB'))
        img = key(rgb)
        fixed = 0
        if g in DEMAGENTA:
            img, fixed = demagenta(img)
        if g == 'bg':
            save(img, os.path.join(OUT, 'bg', name + '.webp'))
            report.append('%03d %s -> bg/%s.webp (repainted %d px)' % (no, file, name, fixed))
            continue
        # rig sheets: limb segments sit a few px apart and must stay separate
        ps = pieces(img[..., 3], 2 if g in ('chars', 'skins') else MERGE)
        d = os.path.join(OUT, g, name)
        os.makedirs(d, exist_ok=True)
        for old in os.listdir(d):
            if old.endswith('.webp'):
                os.remove(os.path.join(d, old))
        meta = []
        pad = 2
        H, W = img.shape[:2]
        for j, (sl, m, area) in enumerate(ps):
            y0, y1 = max(sl[0].start - pad, 0), min(sl[0].stop + pad, H)
            x0, x1 = max(sl[1].start - pad, 0), min(sl[1].stop + pad, W)
            crop = img[y0:y1, x0:x1].copy()
            # keep only this piece (neighbours' corners cut away)
            keep = np.zeros(crop.shape[:2], bool)
            keep[sl[0].start - y0:sl[0].start - y0 + m.shape[0], sl[1].start - x0:sl[1].start - x0 + m.shape[1]] = \
                ndimage.binary_dilation(m, iterations=2)
            crop[..., 3] *= keep
            save(crop, os.path.join(d, '%02d.webp' % j))
            meta.append({'i': j, 'x': x0, 'y': y0, 'w': x1 - x0, 'h': y1 - y0,
                         'cx': (x0 + x1) / 2, 'cy': (y0 + y1) / 2, 'area': area})
        json.dump({'no': no, 'file': file, 'size': [W, H], 'pieces': meta}, open(os.path.join(d, 'sheet.json'), 'w'),
                  indent=1)
        report.append('%03d %s -> %s/%s: %d pieces (repainted %d px)' % (no, file, g, name, len(meta), fixed))
        if preview:
            os.makedirs(preview, exist_ok=True)
            bgc = np.zeros_like(img)
            bgc[..., :3] = 0.12
            bgc[..., 3] = 1
            comp = img[..., :3] * img[..., 3:4] + bgc[..., :3] * (1 - img[..., 3:4])
            im = Image.fromarray((comp * 255).astype(np.uint8))
            dr = ImageDraw.Draw(im)
            ft = ImageFont.truetype(FONT, 22)
            for p in meta:
                dr.rectangle([p['x'], p['y'], p['x'] + p['w'], p['y'] + p['h']], outline=(255, 220, 0), width=1)
                dr.text((p['x'] + 3, p['y'] + 1), str(p['i']), fill=(255, 255, 0), font=ft, stroke_width=3,
                        stroke_fill=(0, 0, 0))
            im.save(os.path.join(preview, '%03d_%s_labels.png' % (no, name)))
    return report


def main():
    args = sys.argv[1:]
    src = args[0]
    only = None
    preview = None
    if '--only' in args:
        only = {int(x) for x in args[args.index('--only') + 1].split(',')}
    if '--preview' in args:
        preview = args[args.index('--preview') + 1]
    entries = json.load(open(os.path.join(src, 'index.json'), encoding='utf-8'))
    if only:
        entries = [e for e in entries if int(e['no']) in only]
    for line in run(src, entries, preview):
        print(line)


if __name__ == '__main__':
    main()

"""Packs the raw Blender frames into Godot sprite sheets (system Python + Pillow + numpy).

    python3 tools/asset-pipeline/blender/pack_sheets.py <raw_dir> <out_dir> <prefix> <cell_w> <cell_h> <origin_x> <origin_y> <height_px>

Per animation: <prefix>_<anim>.png (colour) and <prefix>_<anim>_n.png (normal map),
a grid of at most 8 columns, cells downsampled from the supersampled renders with
Lanczos (anti-aliased, no pixelation). Normal maps get the flat normal under the
outline pixels (the normal pass has no hull) and the colour alpha. Writes
<prefix>_sheets.json for scenes/hero/hero_sprite.gd and the enemy sprite.
"""
import json, os, sys
import numpy as np
from PIL import Image

raw, out, prefix = sys.argv[1], sys.argv[2], sys.argv[3]
cw, ch, ox, oy, hpx = (int(v) for v in sys.argv[4:9])
os.makedirs(out, exist_ok=True)
meta = json.load(open(os.path.join(raw, "meta.json")))
res = {"cell": [cw, ch], "origin": [ox, oy], "height_px": hpx, "anims": {}}
for anim, a in meta["anims"].items():
    n = a["frames"]
    cols = min(n, 8)
    rows = (n + cols - 1) // cols
    sc = Image.new("RGBA", (cols * cw, rows * ch), (0, 0, 0, 0))
    sn = Image.new("RGBA", (cols * cw, rows * ch), (128, 128, 255, 0))
    for i in range(n):
        c = Image.open(os.path.join(raw, "%s_%02d_c.png" % (anim, i))).convert("RGBA").resize((cw, ch), Image.LANCZOS)
        nm = Image.open(os.path.join(raw, "%s_%02d_n.png" % (anim, i))).convert("RGBA").resize((cw, ch), Image.LANCZOS)
        ca = np.asarray(c).astype(np.float32)
        na = np.asarray(nm).astype(np.float32)
        k = (na[..., 3:4] / 255.0)
        flat = np.array([128, 128, 255], np.float32)
        rgb = na[..., :3] * k + flat * (1 - k)  # un-premultiplied edge -> flat
        nrm = np.concatenate([rgb, ca[..., 3:4]], axis=-1).clip(0, 255).astype(np.uint8)
        x, y = (i % cols) * cw, (i // cols) * ch
        sc.paste(c, (x, y))
        sn.paste(Image.fromarray(nrm, "RGBA"), (x, y))
    sc.save(os.path.join(out, "%s_%s.png" % (prefix, anim)), optimize=True)
    sn.save(os.path.join(out, "%s_%s_n.png" % (prefix, anim)), optimize=True)
    res["anims"][anim] = dict(a, cols=cols, rows=rows)
json.dump(res, open(os.path.join(out, "%s_sheets.json" % prefix), "w"), indent=1)
print("packed", len(res["anims"]), "anims into", out)

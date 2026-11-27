"""Converts the backdrop PNGs of a folder to WebP (lossy, quality 90, alpha kept;
bg_far is opaque and saved as RGB) and removes the PNGs and their .import files.
Run with the system Python (Pillow): python3 tools/asset-pipeline/blender/to_webp.py <dir> [quality]
"""
import os, sys
from PIL import Image

d = sys.argv[1]
q = int(sys.argv[2]) if len(sys.argv) > 2 else 90
for f in sorted(os.listdir(d)):
    if not f.endswith(".png"):
        continue
    p = os.path.join(d, f)
    im = Image.open(p)
    if f.startswith("bg_far"):
        im = im.convert("RGB")
    out = p[:-4] + ".webp"
    im.save(out, "WEBP", quality=q, method=6, alpha_quality=90)
    os.remove(p)
    if os.path.exists(p + ".import"):
        os.remove(p + ".import")
    print(out, round(os.path.getsize(out) / 1e6, 2), "MB")

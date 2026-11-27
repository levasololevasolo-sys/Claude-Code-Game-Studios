"""QA evidence images for the art slice (system Python + Pillow).

    python3 tools/asset-pipeline/blender/make_evidence.py sheets <sprite_dir> <prefix> <out.png> anim1,anim2,...
    python3 tools/asset-pipeline/blender/make_evidence.py compare <old.png> <new.png> <out.png>

`sheets`: every frame of the listed animations on a dark backdrop, one labelled row each.
`compare`: two 1920x1080 screenshots side by side (each scaled to 960x540) plus a 2x
crop of each around the hero below, labelled BEFORE / AFTER.
"""
import json, os, sys
from PIL import Image, ImageDraw, ImageFont

BG = (30, 38, 40, 255)


def font(size):
    try:
        return ImageFont.load_default(size=size)
    except TypeError:
        return ImageFont.load_default()


def sheets(d, prefix, out, names):
    meta = json.load(open(os.path.join(d, "%s_sheets.json" % prefix)))
    cw, ch = meta["cell"]
    s = 0.5
    cols = max(meta["anims"][n]["frames"] for n in names)
    W, rowh = int(140 + cols * cw * s), int(ch * s)
    img = Image.new("RGBA", (W, rowh * len(names)), BG)
    dr = ImageDraw.Draw(img)
    for r, n in enumerate(names):
        a = meta["anims"][n]
        sh = Image.open(os.path.join(d, "%s_%s.png" % (prefix, n))).convert("RGBA")
        for i in range(a["frames"]):
            x, y = (i % a["cols"]) * cw, (i // a["cols"]) * ch
            fr = sh.crop((x, y, x + cw, y + ch)).resize((int(cw * s), int(ch * s)), Image.LANCZOS)
            img.alpha_composite(fr, (int(140 + i * cw * s), r * rowh))
        dr.text((10, r * rowh + 10), "%s\n%d fr\n%d fps" % (n, a["frames"], a["fps"]), fill=(230, 220, 200, 255), font=font(22))
        dr.line((0, (r + 1) * rowh - 1, W, (r + 1) * rowh - 1), fill=(60, 70, 72, 255))
    img.save(out)


def compare(old, new, out, crop_c=None):
    a, b = Image.open(old).convert("RGBA"), Image.open(new).convert("RGBA")
    img = Image.new("RGBA", (1920, 1080), BG)
    img.paste(a.resize((960, 540), Image.LANCZOS), (0, 0))
    img.paste(b.resize((960, 540), Image.LANCZOS), (960, 0))
    cx, cy = crop_c or (480, 760)
    box = (cx - 240, cy - 135 - 60, cx + 240, cy + 135 - 60)
    img.paste(a.crop(box).resize((960, 540), Image.LANCZOS), (0, 540))
    img.paste(b.crop(box).resize((960, 540), Image.LANCZOS), (960, 540))
    dr = ImageDraw.Draw(img)
    for x, t in ((20, "BEFORE: code-drawn vector cutout"), (980, "AFTER: Blender 3D -> 2D sprites + normal maps")):
        dr.rectangle((x - 8, 470, x + 470, 520), fill=(0, 0, 0, 180))
        dr.text((x, 478), t, fill=(255, 230, 180, 255), font=font(30))
    dr.line((960, 0, 960, 1080), fill=(255, 201, 74, 255), width=3)
    dr.line((0, 540, 1920, 540), fill=(255, 201, 74, 255), width=3)
    img.convert("RGB").save(out)


if __name__ == "__main__":
    if sys.argv[1] == "sheets":
        sheets(sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5].split(","))
    else:
        c = tuple(int(v) for v in sys.argv[5].split(",")) if len(sys.argv) > 5 else None
        compare(sys.argv[2], sys.argv[3], sys.argv[4], c)

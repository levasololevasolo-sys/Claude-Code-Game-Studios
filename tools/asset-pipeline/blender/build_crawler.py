"""Трясинник (crawler, GDD enemies-and-elites §3.2; art bible §5.3 «болотник-ползун»):
heavy, low swamp brute that knuckle-walks on long arms with rust claws, moss and
weed on its back, two rust-glowing eyes. Same pipeline and world scale as the hero.

Run:  xvfb-run -a blender -b --python tools/asset-pipeline/blender/build_crawler.py -- <raw_dir> [--only=idle] [--still]
Then: python3 tools/asset-pipeline/blender/pack_sheets.py <raw_dir> assets/art/sprites/crawler crawler 640 400 300 372 230
"""
import bpy, sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import navi_common as nc
import navi_rig as nr

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
RAW = ARGS[0] if ARGS else "/tmp/navi_crawler_raw"
ONLY = next((a[7:].split(",") for a in ARGS if a.startswith("--only=")), None)
STILL = "--still" in ARGS

CELL = (640, 400)
ORIGIN = (300, 372)
PPM = 173.0
SS = 2
YAW = 30.0
OUT_T = 0.026   # 3 px class outline (bible §5.2: enemies thinner than the hero)

sc = nc.reset(transparent=True, samples=16)
nc.sun((-0.35, -0.9, 1.0), 2.5, "#E8F0DA")
nc.sun((0.8, 0.6, 0.3), 0.7, "#6FA0A0", shadow=False)
nc.ortho_camera(CELL[0], CELL[1], PPM, ORIGIN, SS)

m_hide = nc.toon("hide", "#56664A", shadow_tint="#4A5A80", rim="#B6E36B", rim_k=0.35)
m_belly = nc.toon("belly", "#7A7656", shadow_tint="#4A5A80")
m_moss = nc.toon("moss", "#3E5A34", shadow_tint="#3A4A70", rim="#B6E36B", rim_k=0.5)
m_weed = nc.toon("weed", "#2C4630", shadow_tint="#3A4A70", rim_k=0.2)
m_claw = nc.toon("claw", "#C2502A", shadow_tint="#603040", rim_k=0.2)
m_tooth = nc.toon("tooth", "#D8CDB0", rim_k=0.1)
m_mouth = nc.toon("mouth", "#3A1418", rim_k=0.0)
m_eye = nc.glow("eye", "#FF7A3A", 4.0)

BONES = [
    ("root", (0, 0, 0.7), (0, 0, 0.9), None),
    ("body", (-0.45, 0, 0.72), (0.35, 0, 0.9), "root"),
    ("head", (0.38, 0, 0.88), (0.75, 0, 0.82), "body"),
    ("jaw", (0.45, 0, 0.8), (0.75, 0, 0.7), "head"),
    ("armR", (0.25, -0.34, 1.0), (0.36, -0.38, 0.52), "body"),
    ("foreR", (0.36, -0.38, 0.52), (0.42, -0.38, 0.1), "armR"),
    ("clawR", (0.42, -0.38, 0.1), (0.62, -0.38, 0.03), "foreR"),
    ("armL", (0.25, 0.34, 1.0), (0.36, 0.38, 0.52), "body"),
    ("foreL", (0.36, 0.38, 0.52), (0.42, 0.38, 0.1), "armL"),
    ("clawL", (0.42, 0.38, 0.1), (0.62, 0.38, 0.03), "foreL"),
    ("legR", (-0.42, -0.22, 0.68), (-0.3, -0.24, 0.36), "body"),
    ("shinR", (-0.3, -0.24, 0.36), (-0.44, -0.24, 0.07), "legR"),
    ("legL", (-0.42, 0.22, 0.68), (-0.3, 0.24, 0.36), "body"),
    ("shinL", (-0.3, 0.24, 0.36), (-0.44, 0.24, 0.07), "legL"),
]
rig = nr.Rig("CrawlerRig", BONES)
parts = []


def part(o, bone, outline=True):
    rig.attach(o, bone)
    if outline:
        nc.add_outline(o, OUT_T)
        parts.append(o)
    return o


random.seed(11)
part(nc.ellip("body", (-0.05, 0, 0.82), (0.62, 0.42, 0.36), m_hide, rot=(0, -0.18, 0)), "body")
part(nc.ellip("belly", (0.02, 0, 0.66), (0.48, 0.34, 0.2), m_belly, rot=(0, -0.1, 0)), "body")
part(nc.ellip("hump", (-0.12, 0, 1.07), (0.46, 0.34, 0.2), m_moss, rot=(0, -0.2, 0)), "body")
for i in range(9):
    x = -0.5 + i * 0.11
    part(nc.ellip("lump%d" % i, (x, random.uniform(-0.2, 0.2), 1.1 + 0.08 * math.sin(i * 1.7)),
                  (0.09, 0.09, 0.07), m_moss, seg=12), "body")
for i in range(7):   # hanging weed strands
    x = -0.55 + i * 0.15
    z0 = 0.8 + 0.25 * math.sin(i)
    part(nc.capsule("weed%d" % i, (x, -0.36 + 0.02 * i, z0), (x - 0.06, -0.38, z0 - 0.3 - 0.12 * (i % 3)), 0.03, 0.012, m_weed, seg=8), "body")
part(nc.ellip("head", (0.55, 0, 0.86), (0.24, 0.22, 0.17), m_hide), "head")
part(nc.ellip("brow", (0.66, 0, 0.95), (0.13, 0.2, 0.06), m_moss), "head")
for s in (-1, 1):
    rig.attach(nc.ellip("eye", (0.74, 0.085 * s, 0.9), (0.028, 0.035, 0.024), m_eye, seg=12), "head")
part(nc.ellip("jaw", (0.6, 0, 0.74), (0.2, 0.19, 0.08), m_hide), "jaw")
rig.attach(nc.ellip("mouth", (0.64, 0, 0.79), (0.17, 0.17, 0.05), m_mouth, seg=16), "head")
for i in range(5):
    x = 0.5 + i * 0.055
    rig.attach(nc.cone("tooth%d" % i, (x, -0.15, 0.78), (x + 0.01, -0.16, 0.85), 0.018, m_tooth, seg=6), "jaw")
for s, y in (("R", -0.36), ("L", 0.36)):
    part(nc.ellip("shoulder" + s, (0.26, y * 0.95, 0.98), (0.15, 0.13, 0.14), m_hide), "arm" + s)
    part(nc.capsule("arm" + s, (0.25, y, 1.0), (0.36, y - 0.03 * (1 if y < 0 else -1), 0.52), 0.12, 0.095, m_hide), "arm" + s)
    part(nc.capsule("fore" + s, (0.36, y, 0.52), (0.42, y, 0.12), 0.1, 0.085, m_hide), "fore" + s)
    part(nc.ellip("fist" + s, (0.45, y, 0.09), (0.1, 0.09, 0.075), m_hide), "claw" + s)
    for k in range(3):
        part(nc.cone("claw%s%d" % (s, k), (0.5, y + (k - 1) * 0.045, 0.07), (0.68, y + (k - 1) * 0.055, 0.01), 0.025, m_claw, seg=8), "claw" + s)
for s, y in (("R", -0.22), ("L", 0.22)):
    part(nc.capsule("leg" + s, (-0.42, y, 0.68), (-0.3, y, 0.38), 0.12, 0.09, m_hide), "leg" + s)
    part(nc.capsule("shin" + s, (-0.3, y, 0.36), (-0.44, y, 0.1), 0.08, 0.065, m_hide), "shin" + s)
    part(nc.ellip("foot" + s, (-0.38, y, 0.05), (0.13, 0.07, 0.05), m_hide), "shin" + s)
rig.arm.rotation_euler = (0, 0, math.radians(-YAW))

BASE = dict(rx=0, rz=0, root=0, body=0, head=0, jaw=0, armR=0, foreR=0, clawR=0, armL=0, foreL=0, clawL=0,
            legR=0, shinR=0, legL=0, shinL=0)
anims = {}
BR = dict(BASE, rz=-0.03, body=-2, head=4, jaw=-6)
anims["idle"] = dict(frames=8, fps=10, loop=True, keys=[(0, BASE, "io"), (4, BR, "io"), (8, BASE, "io")])
WK = []
for i in range(9):
    p = 2 * math.pi * i / 8
    WK.append((i, dict(BASE, rx=0.0, rz=-0.02 + 0.03 * abs(math.sin(p)), body=-3 + 3 * math.sin(2 * p), head=4 * math.sin(p),
                       armR=24 * math.sin(p), foreR=-10 + 12 * math.sin(p + 0.8), clawR=-8 * math.sin(p),
                       armL=24 * math.sin(p + math.pi), foreL=-10 + 12 * math.sin(p + math.pi + 0.8), clawL=-8 * math.sin(p + math.pi),
                       legR=18 * math.sin(p + math.pi), shinR=-6 + 8 * math.sin(p + math.pi + 0.8),
                       legL=18 * math.sin(p), shinL=-6 + 8 * math.sin(p + 0.8), jaw=-4), "lin"))
anims["walk"] = dict(frames=8, fps=12, loop=True, keys=WK)
REAR = dict(BASE, rx=-0.16, rz=0.08, body=22, head=-12, jaw=-30, armR=70, foreR=40, clawR=40, armL=55, foreL=50, clawL=30,
            legR=-22, shinR=10, legL=-15, shinL=8)
REAR2 = dict(REAR, rx=-0.2, rz=0.12, body=27, head=-16, jaw=-38, armR=85, armL=70)
anims["windup"] = dict(frames=6, fps=12, keys=[(0, BASE, "io"), (3, REAR, "out"), (5, REAR2, "io"), (6, REAR2, "hold")])
SLAM = dict(BASE, rx=0.22, rz=-0.08, body=-16, head=10, jaw=-26, armR=-40, foreR=-30, clawR=-20, armL=-25, foreL=-20,
            legR=30, shinR=-10, legL=10, shinL=-5)
anims["attack"] = dict(frames=6, fps=16, keys=[(0, REAR2, "io"), (1, SLAM, "snap"), (3, dict(SLAM, rx=0.26, body=-18, armR=-30, armL=-38), "out"),
                                               (6, dict(SLAM, rx=0.24, armR=-20, armL=-24, jaw=-18), "io")])
HURT = dict(BASE, rx=-0.12, rz=0.03, body=14, head=-24, jaw=-20, armR=30, armL=20, foreR=20)
anims["hurt"] = dict(frames=3, fps=12, keys=[(0, HURT, "out"), (1, dict(HURT, head=-28), "io"), (3, BASE, "io")])
SLUMP = dict(BASE, rz=-0.18, body=-10, head=14, jaw=-25, armR=-70, foreR=60, armL=-60, foreL=70, legR=-60, shinR=80, legL=-55, shinL=75)
FLAT = dict(SLUMP, rz=-0.24, root=-8, body=-6, head=20)
anims["death"] = dict(frames=10, fps=12, keys=[(0, HURT, "out"), (2, dict(HURT, body=20, head=-30, rz=0.06), "out"),
                                               (6, SLUMP, "in"), (7, dict(SLUMP, rz=-0.22), "out"), (9, FLAT, "io"), (10, FLAT, "hold")])
if ONLY:
    anims = {k: v for k, v in anims.items() if k in ONLY}
if STILL:
    for k in anims:
        anims[k]["frames"] = 1
nr.render_anims(rig, anims, RAW, {}, parts, "crawler")

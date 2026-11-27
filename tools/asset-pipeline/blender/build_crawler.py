"""Трясинник v2 (crawler, GDD enemies-and-elites §3.2; art bible §5.3 «болотник-ползун»):
heavy, low swamp brute that knuckle-walks on long arms with rust claws, warty hide,
a moss cap on the hump, weeds hanging from the back, two hot rust-glowing eyes.
v2: one sculpt-like metaball body (navi_sculpt) skinned to the rig by distance
weights, warts and knuckles as surface balls, painted procedural hide, weeds on
spring bones (follow-through). Same pipeline, cell and world scale as v1.

Run:  xvfb-run -a blender -b --python tools/asset-pipeline/blender/build_crawler.py -- <raw_dir> [--only=idle] [--still]
Then: python3 tools/asset-pipeline/blender/pack_sheets.py <raw_dir> assets/art/sprites/crawler crawler 640 400 300 372 230
"""
import bpy, sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import navi_common as nc
import navi_rig as nr
import navi_sculpt as ns

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
RAW = ARGS[0] if ARGS else "/tmp/navi_crawler_raw"
ONLY = next((a[7:].split(",") for a in ARGS if a.startswith("--only=")), None)
STILL = "--still" in ARGS

CELL = (640, 400)
ORIGIN = (300, 372)
PPM = 173.0
SS = 2
YAW = 30.0
OUT_T = 0.024   # 3 px class outline (bible §5.2: enemies thinner than the hero)

sc = nc.reset(transparent=True, samples=16)
nc.sun((-0.35, -0.9, 1.0), 2.5, "#E8F0DA")
nc.sun((0.8, 0.6, 0.3), 0.7, "#6FA0A0", shadow=False)
nc.ortho_camera(CELL[0], CELL[1], PPM, ORIGIN, SS)

m_hide = nc.toon("hide", "#58684A", shadow_tint="#4A5A80", rim="#B6E36B", rim_k=0.35,
                 paint=dict(kind="skin", c2="#3E4A36", amt=0.7, scale=5.0, patch=0.8, jit=0.09))
m_belly = nc.toon("belly", "#857C58", shadow_tint="#4A5A80", paint=dict(kind="skin", c2="#6E6648", amt=0.5, scale=8.0))
m_moss = nc.toon("moss", "#3E5A34", shadow_tint="#3A4A70", rim="#B6E36B", rim_k=0.5,
                 paint=dict(kind="skin", c2="#6E8A3A", amt=0.85, scale=14.0, patch=1.2, jit=0.12))
m_weed = nc.toon("weed", "#3E6034", shadow_tint="#3A4A70", rim="#9ED36B", rim_k=0.3,
                 paint=dict(kind="hair", c2="#1E3424", c3="#4E6A3A", amt=0.6, scale=40.0))
m_claw = nc.toon("claw", "#C2502A", shadow_tint="#603040", rim_k=0.2, paint=dict(kind="wood", c2="#8A3420", c3="#3A1810", amt=0.5, scale=10.0))
m_tooth = nc.toon("tooth", "#C8B888", rim_k=0.1)
m_mouth = nc.toon("mouth", "#3A1418", rim_k=0.0)
m_eye = nc.glow("eye", "#FF6A2A", 6.0)
m_eye_core = nc.glow("eye_core", "#FFE6A0", 8.0)

WEEDS = [(-0.5, 0.95), (-0.25, 1.05), (0.0, 1.05), (0.22, 1.0)]
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
] + [("wd%d" % k, (x, -0.3, z), (x - 0.06, -0.33, z - 0.36), "body") for k, (x, z) in enumerate(WEEDS)]
rig = nr.Rig("CrawlerRig", BONES)
SPRINGS = [dict(bone="wd%d" % k, k=150.0, damp=0.86, g=0.85) for k in range(len(WEEDS))]
parts = []
DEFORM = [b[0] for b in BONES if not b[0].startswith("wd") and b[0] not in ("root", "jaw")]


def part(o, bone, outline=True):
    rig.attach(o, bone)
    nc.add_rest(o)
    if outline:
        nc.add_outline(o, OUT_T)
        parts.append(o)
    return o


# ---- body: one clay mass (torso, hump, shoulders, neck, head, arms, legs)
B = ns.Blob("crawler_body", res=0.02)
B.ellip((-0.05, 0, 0.82), (0.64, 0.42, 0.37), rot=(0, -0.18, 0))
B.ellip((0.02, 0, 0.67), (0.44, 0.3, 0.19), rot=(0, -0.1, 0))
B.ellip((-0.12, 0, 1.0), (0.42, 0.3, 0.2), rot=(0, -0.2, 0))
B.ellip((0.36, 0, 0.9), (0.18, 0.2, 0.14))                       # neck/scruff
B.ellip((0.55, 0, 0.87), (0.21, 0.2, 0.14))                      # skull
B.ellip((0.66, 0, 0.95), (0.11, 0.2, 0.05), rot=(0, 0.2, 0))     # brow ridge
B.ellip((0.74, 0, 0.86), (0.07, 0.08, 0.06))                     # snout
for s, y in (("R", -0.35), ("L", 0.35)):
    B.ellip((0.24, y * 0.92, 0.98), (0.17, 0.14, 0.15))         # shoulder mass
    B.limb([(0.25, y, 1.0), (0.36, y, 0.52), (0.42, y, 0.13)], [0.12, 0.095, 0.08])
    B.ellip((0.31, y * 1.02, 0.36), (0.1, 0.09, 0.14), rot=(0, 0.15, 0))   # forearm bulge
    B.ellip((0.46, y, 0.09), (0.1, 0.09, 0.07))                  # fist
    for k in range(3):
        B.ball((0.53, y + (k - 1) * 0.045, 0.1), 0.035)        # knuckles
    B.limb([(-0.42, y * 0.63, 0.68), (-0.3, y * 0.68, 0.37), (-0.44, y * 0.68, 0.09)], [0.13, 0.09, 0.07])
    B.ellip((-0.38, y * 0.68, 0.05), (0.13, 0.07, 0.05))
B.warts((-0.05, 0, 0.84), (0.6, 0.38, 0.33), 46, 0.02, 0.042, 3, filt=lambda p, u: u.z > -0.1)
B.warts((0.3, 0, 0.6), (0.14, 0.42, 0.4), 18, 0.016, 0.03, 4, filt=lambda p, u: abs(u.y) > 0.6)
body = B.bake(m_hide)
ns.bump(body, 0.008, 22.0, 1)
ns.skin(body, rig, allow=DEFORM)
ns.finish(body, OUT_T, parts)
# belly plate (paler, sits under the torso)
Bb = ns.Blob("crawler_belly", res=0.02)
Bb.ellip((0.06, 0, 0.64), (0.4, 0.27, 0.15), rot=(0, -0.1, 0))
belly = Bb.bake(m_belly)
ns.skin(belly, rig, allow=["body", "hips", "armR", "armL"] if False else ["body", "armR", "armL"])
ns.finish(belly, OUT_T * 0.7, parts)
# moss cap on the hump: lumpy clumps
Bm = ns.Blob("crawler_moss", res=0.018)
Bm.ellip((-0.14, 0, 1.08), (0.4, 0.28, 0.12), rot=(0, -0.2, 0))
Bm.warts((-0.14, 0, 1.08), (0.4, 0.28, 0.12), 26, 0.05, 0.08, 7, filt=lambda p, u: u.z > 0.1)
Bm.ellip((0.4, 0, 1.0), (0.12, 0.16, 0.05))
moss = Bm.bake(m_moss)
ns.bump(moss, 0.012, 30.0, 2)
ns.skin(moss, rig, allow=["body", "head"])
ns.finish(moss, OUT_T, parts)
# jaw: its own mass so the mouth opens
Bj = ns.Blob("crawler_jaw", res=0.016)
Bj.ellip((0.6, 0, 0.75), (0.19, 0.17, 0.065))
Bj.ellip((0.74, 0, 0.73), (0.06, 0.1, 0.05))
jaw = Bj.bake(m_hide)
ns.skin(jaw, rig, fixed="jaw")
ns.finish(jaw, OUT_T, parts)
rig.attach(nc.ellip("mouth", (0.64, 0, 0.79), (0.16, 0.16, 0.05), m_mouth, seg=16), "head")
for i in range(6):
    x = 0.5 + i * 0.05
    if i in (1, 4):
        continue
    part(nc.cone("tooth%d" % i, (x, -0.15, 0.77), (x + 0.02 * (i % 2), -0.16, 0.85 + 0.035 * (i % 3 == 0)), 0.02, m_tooth, seg=6), "jaw", False)
    if i % 2:
        continue
    part(nc.cone("utooth%d" % i, (x + 0.02, -0.15, 0.82), (x + 0.025, -0.155, 0.76), 0.013, m_tooth, seg=6), "head", False)
for s in (-1, 1):   # hot eyes deep under the brow: glowing iris + white-hot core
    rig.attach(nc.ellip("eye", (0.745, 0.09 * s, 0.905), (0.03, 0.042, 0.028), m_eye, seg=14), "head")
    rig.attach(nc.ellip("eye_core", (0.768, 0.092 * s, 0.906), (0.012, 0.018, 0.012), m_eye_core, seg=10), "head")
for s, y in (("R", -0.35), ("L", 0.35)):
    for k in range(3):   # long hooked rust claws
        a = (0.53, y + (k - 1) * 0.05, 0.07)
        part(nc.cone("claw%s%d" % (s, k), a, (0.72, y + (k - 1) * 0.06, 0.0), 0.028, m_claw, seg=8), "claw" + s)
    for k in range(2):
        part(nc.cone("toe%s%d" % (s, k), (-0.28, y * 0.68 + (k - 0.5) * 0.05, 0.04), (-0.18, y * 0.68 + (k - 0.5) * 0.06, 0.0), 0.02, m_claw, seg=6), "shin" + s)
# weeds hanging from the back and flanks, on spring bones
rnd = random.Random(5)
roots = []
for k in range(34):
    x = rnd.uniform(-0.55, 0.3)
    side = -1 if rnd.random() < 0.6 else 1
    z = 1.0 + 0.06 * math.cos((x + 0.12) * 3.0)
    roots.append(((x, side * rnd.uniform(0.12, 0.3), z), (rnd.uniform(-0.25, 0.05), side * 0.35, -1.0), rnd.uniform(0.28, 0.55), rnd.uniform(0.3, 0.8)))
nearest = lambda i: "wd%d" % min(range(len(WEEDS)), key=lambda k: abs(WEEDS[k][0] - roots[i][0][0]))
weeds = ns.ribbon_strands("weeds", roots, m_weed, rig, "body", nearest, width=0.042, thick=0.008)
ns.finish(weeds, 0.01, parts)
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
nr.render_anims(rig, anims, RAW, {}, parts, "crawler", springs=SPRINGS)

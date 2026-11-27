"""Hero tier 1 «Павший» (art bible §5.1, §5.6): half-naked bearded man with a knotted
stick, wooden amulet on a cord, red thread of Mokosh on the near wrist. Built from
primitives on a planar puppet rig, turned three-quarter to the camera, animated by
script with Dead Cells-style timing (long anticipation, one-frame snap, held
follow-through, baked smear crescents), rendered to colour + normal frames.

Run:  xvfb-run -a blender -b --python tools/asset-pipeline/blender/build_hero.py -- <raw_dir> [--only=idle,run] [--still]
Then: python3 tools/asset-pipeline/blender/pack_sheets.py <raw_dir> assets/art/sprites/hero hero
"""
import bpy, sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import navi_common as nc
import navi_rig as nr

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
RAW = ARGS[0] if ARGS else "/tmp/navi_hero_raw"
ONLY = next((a[7:].split(",") for a in ARGS if a.startswith("--only=")), None)
STILL = "--still" in ARGS

# Sheet geometry (2x of the 1080p on-screen size, bible §8): hero ~320 px tall.
CELL = (560, 480)
ORIGIN = (230, 452)    # feet in the cell, px from top-left
PPM = 173.0            # px per metre at 2x
SS = 2                 # supersampling factor (render at 4x, downsample)
YAW = 40.0             # three-quarter turn toward the camera, degrees
OUT_T = 0.032          # outline hull thickness, m (~2.8 px at 1x; bible asks 4)

SKIN, SKIN_SH = "#E0A07A", "#A8664A"
LINEN, WRAP, STICK = "#CDBB98", "#9A8A72", "#8C6A44"
HAIR, HAIR_D = "#8A5A34", "#6A4226"
THREAD, GLOW = "#B3262E", "#FFC94A"

sc = nc.reset(transparent=True, samples=16)
nc.sun((-0.35, -0.9, 1.0), 2.7, "#FFF0DA")
nc.sun((0.8, 0.6, 0.3), 0.6, "#7FA3C8", shadow=False)
nc.ortho_camera(CELL[0], CELL[1], PPM, ORIGIN, SS)

m_skin = nc.toon("skin", SKIN, shadow_tint="#7A5A7A", rim="#FFD9A8")
m_lin = nc.toon("linen", LINEN, shadow_tint="#6A6E8E")
m_wrap = nc.toon("wrap", WRAP, shadow_tint="#6A6E8E")
m_stick = nc.toon("stick", STICK, shadow_tint="#6A5A7A")
m_hair = nc.toon("hair", HAIR, shadow_tint="#6A5070", rim="#E8B070")
m_hair_d = nc.toon("hair_d", HAIR_D, shadow_tint="#6A5070")
m_eye = nc.toon("eye", "#1E1410", rim_k=0.0)
m_thread = nc.toon("thread", THREAD, emit=0.35, rim_k=0.2)
m_wood = nc.toon("amulet_wood", "#9C7448")
m_glow = nc.glow("amulet_glow", GLOW, 3.0)
m_cord = nc.toon("cord", "#3A2A20", rim_k=0.1)

L, R = 0.25, -0.25   # far / near shoulder y
BONES = [
    ("root", (0, 0, 0.62), (0, 0, 0.8), None),
    ("hips", (0, 0, 0.95), (0, 0, 1.05), "root"),
    ("spine", (0, 0, 1.05), (0, 0, 1.42), "hips"),
    ("head", (0, 0, 1.45), (0, 0, 1.75), "spine"),
    ("upR", (0, R, 1.36), (0, R, 1.09), "spine"),
    ("foR", (0, R, 1.09), (0, R, 0.84), "upR"),
    ("haR", (0, R, 0.84), (0, R, 0.77), "foR"),
    ("stick", (0, R, 0.77), (0.3, R, 0.77), "haR"),
    ("upL", (0, L, 1.36), (0, L, 1.09), "spine"),
    ("foL", (0, L, 1.09), (0, L, 0.84), "upL"),
    ("haL", (0, L, 0.84), (0, L, 0.77), "foL"),
    ("thR", (0, -0.1, 0.95), (0, -0.1, 0.53), "hips"),
    ("shR", (0, -0.1, 0.53), (0, -0.1, 0.1), "thR"),
    ("ftR", (0, -0.1, 0.1), (0.14, -0.1, 0.06), "shR"),
    ("thL", (0, 0.1, 0.95), (0, 0.1, 0.53), "hips"),
    ("shL", (0, 0.1, 0.53), (0, 0.1, 0.1), "thL"),
    ("ftL", (0, 0.1, 0.1), (0.14, 0.1, 0.06), "shL"),
]
rig = nr.Rig("HeroRig", BONES)
rig.legs = {"R": ("thR", "shR", 0.42, 0.43), "L": ("thL", "shL", 0.42, 0.43)}
parts = []


def part(o, bone, outline=True):
    rig.attach(o, bone)
    if outline:
        nc.add_outline(o, OUT_T)
        parts.append(o)
    return o


# torso
part(nc.ellip("pelvis", (0, 0, 0.97), (0.16, 0.2, 0.13), m_lin), "hips")
part(nc.torus("belt", (0, 0, 1.03), 0.17, 0.028, m_wrap, scale=(0.9, 1.12, 1)), "hips")
part(nc.capsule("torso", (0, 0, 1.0), (0, 0, 1.3), 0.15, 0.2, m_skin, squash=(0.72, 1.28)), "spine")
part(nc.ellip("chest", (0.05, 0, 1.29), (0.15, 0.25, 0.13), m_skin), "spine")
part(nc.ellip("belly", (0.05, 0, 1.12), (0.13, 0.17, 0.13), m_skin), "spine")
part(nc.capsule("neck", (0, 0, 1.36), (0.01, 0, 1.5), 0.075, 0.07, m_skin), "spine")
# head: round, shaggy hair, visible face, beard
part(nc.ellip("head", (0.01, 0, 1.61), (0.145, 0.135, 0.16), m_skin), "head")
part(nc.ellip("nose", (0.155, 0, 1.6), (0.045, 0.033, 0.05), m_skin), "head")
part(nc.ellip("ear", (-0.01, -0.13, 1.61), (0.035, 0.02, 0.05), m_skin), "head")
for side in (-1, 1):
    o = nc.ellip("eye", (0.138, 0.052 * side, 1.645), (0.018, 0.016, 0.022), m_eye, seg=12)
    rig.attach(o, "head")
    o = nc.ellip("brow", (0.142, 0.055 * side, 1.678), (0.022, 0.042, 0.013), m_hair_d, seg=12)
    rig.attach(o, "head")
part(nc.ellip("hair", (-0.035, 0, 1.69), (0.165, 0.155, 0.13), m_hair), "head")
part(nc.ellip("hair_back", (-0.09, 0, 1.56), (0.1, 0.14, 0.15), m_hair), "head")
for i, (x, z, s) in enumerate(((0.06, 1.79, 0.06), (-0.06, 1.8, 0.07), (-0.15, 1.72, 0.06), (0.11, 1.74, 0.05))):
    rig.attach(nc.ellip("tuft%d" % i, (x, 0, z), (s, s * 1.3, s * 0.8), m_hair, rot=(0.3 * i, 0.5, 0)), "head")
part(nc.ellip("beard", (0.085, 0, 1.5), (0.11, 0.125, 0.13), m_hair), "head")
part(nc.ellip("beard_tip", (0.12, 0, 1.42), (0.07, 0.08, 0.08), m_hair, rot=(0, -0.4, 0)), "head")
rig.attach(nc.ellip("moustache", (0.155, 0, 1.56), (0.03, 0.075, 0.022), m_hair_d, seg=12), "head")
# amulet on a cord (wooden carved circle, glowing core)
rig.attach(nc.torus("cord", (0.035, 0, 1.4), 0.15, 0.007, m_cord, rot=(0, math.radians(-38), 0), scale=(1, 1.1, 1)), "spine")
part(nc.torus("amulet", (0.19, 0, 1.27), 0.042, 0.014, m_wood, rot=(0, math.radians(90), 0)), "spine")
rig.attach(nc.ellip("amulet_core", (0.195, 0, 1.27), (0.012, 0.032, 0.032), m_glow, seg=12), "spine")
# arms (big hands), red thread on the near wrist
for s, y in (("R", R), ("L", L)):
    part(nc.ellip("delt" + s, (0, y * 0.97, 1.34), (0.1, 0.095, 0.1), m_skin), "up" + s)
    part(nc.capsule("up" + s, (0, y, 1.35), (0, y, 1.1), 0.08, 0.068, m_skin), "up" + s)
    part(nc.capsule("fo" + s, (0, y, 1.08), (0, y, 0.85), 0.072, 0.058, m_skin), "fo" + s)
    part(nc.ellip("hand" + s, (0.0, y, 0.77), (0.07, 0.062, 0.08), m_skin), "ha" + s)
rig.attach(nc.torus("thread", (0, R, 0.87), 0.061, 0.013, m_thread), "foR")
# legs: torn linen trousers, foot wraps
for s, y in (("R", -0.1), ("L", 0.1)):
    part(nc.capsule("th" + s, (0, y, 0.95), (0, y, 0.55), 0.11, 0.085, m_lin), "th" + s)
    part(nc.capsule("sh" + s, (0, y, 0.53), (0, y, 0.13), 0.075, 0.058, m_wrap), "sh" + s)
    part(nc.ellip("hem" + s, (0, y, 0.54), (0.092, 0.092, 0.05), m_lin, rot=(0.15, 0, 0)), "th" + s)
    part(nc.ellip("ft" + s, (0.06, y, 0.055), (0.12, 0.062, 0.052), m_wrap), "ft" + s)
# knotted stick (grip in the near hand, points along +X at rest)
part(nc.capsule("stick", (-0.16, R, 0.77), (0.98, R, 0.77), 0.03, 0.022, m_stick, bend=0.015), "stick")
for i, x in enumerate((0.3, 0.62, 0.86)):
    part(nc.ellip("knot%d" % i, (x, R, 0.775 + 0.01 * (i % 2)), (0.03, 0.03, 0.026), m_stick, seg=12), "stick")

# smear crescents (pale gold, alpha grows toward the leading edge); armature space
SH = (0.05, 1.3)   # near shoulder (x, z) in the strike poses
smears = {}
m_smear = nc.fade_mat("smear", "#FFE9B8", strength=1.6, alpha=0.9, power=1.3)
for nm, c, ri, ro, a0, a1 in (
        ("s1", (0.12, 1.22), 0.55, 1.2, 150, -15),
        ("s1b", (0.12, 1.22), 0.65, 1.2, 60, -40),
        ("s2", (0.12, 1.12), 0.6, 1.18, 245, 425),
        ("s2b", (0.12, 1.12), 0.7, 1.18, 330, 450),
        ("s3", (0.2, 1.05), 0.55, 1.35, 160, -70),
        ("s3b", (0.2, 1.05), 0.75, 1.35, 40, -75),
        ("su", (0.0, 1.3), 0.55, 1.15, -10, 160),
        ("sd", (0.1, 0.9), 0.3, 1.0, -60, -120)):
    o = nc.arc_mesh("smear_" + nm, c, ri, ro, a0, a1, m_smear)
    o.parent = rig.arm
    smears[nm] = o

rig.arm.rotation_euler = (0, 0, math.radians(-YAW))

# ---------------- poses ----------------
FEET = {"ik:R": (0.24, 0.1), "ik:L": (-0.2, 0.1)}
IDLE_A = dict(FEET, rx=0.0, rz=-0.06, hips=0, spine=-7, head=5, upR=18, foR=62, haR=0, upL=-10, foL=30,
              **{"w:stick": -28, "w:ftR": -12, "w:ftL": -12})
IDLE_B = dict(IDLE_A, rx=0.012, rz=-0.085, spine=-4, head=2, upR=22, foR=66, upL=-6, foL=34, **{"w:stick": -22})
anims = {}
anims["idle"] = dict(frames=16, fps=12, loop=True, keys=[(0, IDLE_A, "io"), (8, IDLE_B, "io"), (16, IDLE_A, "io")])


def run_keys():
    keys = []
    n = 12
    for i in range(n + 1):
        p = 2 * math.pi * i / n
        def foot(ph):
            x = 0.4 * math.cos(ph)
            z = 0.1 + (0.26 * math.sin(ph - math.pi) if math.sin(ph) < 0 else 0.0)
            return (x, z)
        pose = {"ik:R": foot(p), "ik:L": foot(p + math.pi), "rx": 0.05,
                "rz": -0.07 + 0.05 * abs(math.sin(p)), "hips": 0, "spine": -20 + 3 * math.cos(2 * p),
                "head": 12, "upR": -35 + 22 * math.cos(p + math.pi), "foR": 55,
                "upL": 45 * math.cos(p), "foL": 50 + 20 * math.cos(p), "w:stick": 192,
                "w:ftR": -15 + 25 * math.sin(p), "w:ftL": -15 + 25 * math.sin(p + math.pi)}
        keys.append((i, pose, "lin"))
    return keys


anims["run"] = dict(frames=12, fps=24, loop=True, keys=run_keys())
JUMP0 = dict(IDLE_A, rz=-0.16, spine=-22, upR=-30, foR=40, upL=-40, **{"ik:R": (0.18, 0.1), "ik:L": (-0.18, 0.1), "w:stick": 200})
JUMP1 = dict(rz=0.05, spine=-6, head=8, upR=110, foR=30, upL=70, foL=20, **{"ik:R": (0.1, -0.05), "ik:L": (-0.15, -0.02), "w:stick": 70, "w:ftR": -50, "w:ftL": -60})
JUMP2 = dict(JUMP1, rz=0.08, upR=95, upL=40, **{"ik:R": (0.25, 0.4), "ik:L": (-0.05, 0.22), "w:ftR": -20, "w:ftL": -40})
anims["jump"] = dict(frames=4, fps=12, keys=[(0, JUMP0, "io"), (1, JUMP1, "snap"), (3, JUMP2, "out")])
FALL0 = dict(rx=0, rz=0.0, hips=0, spine=-4, head=12, upR=120, foR=35, upL=105, foL=30,
             **{"ik:R": (0.22, 0.2), "ik:L": (-0.1, 0.05), "w:stick": 80, "w:ftR": -35, "w:ftL": -55})
FALL1 = dict(FALL0, upR=130, upL=118, spine=-2, **{"ik:R": (0.24, 0.24), "ik:L": (-0.12, 0.02)})
anims["fall"] = dict(frames=4, fps=12, loop=True, keys=[(0, FALL0, "io"), (2, FALL1, "io"), (4, FALL0, "io")])
TUCK = dict(hips=0, spine=-55, head=-20, thR=110, shR=-140, thL=95, shL=-135, upR=70, foR=80, upL=60, foL=90,
            **{"w:ftR": 0, "w:ftL": 0, "ik:R": None, "ik:L": None})
ROLL = []
for i, a in enumerate((0, -20, -75, -140, -205, -270, -330, -360)):
    p = dict(TUCK, root=a, rz=0.0 if 0 < i < 7 else -0.1, rx=0.04 * i, **{"w:stick": 215 + a})
    ROLL.append((i, p, "lin"))
ROLL[0] = (0, dict(JUMP0, rx=0.0, spine=-40, upR=40, foR=60, **{"w:stick": 170}), "lin")
anims["roll"] = dict(frames=8, fps=24, keys=ROLL)
DASH = dict(IDLE_A, rx=0.08, rz=-0.14, spine=-38, head=20, upR=-55, foR=25, upL=-60, foL=20,
            **{"ik:R": (0.42, 0.1), "ik:L": (-0.45, 0.16), "w:stick": 185, "w:ftL": 30})
anims["dash"] = dict(frames=4, fps=24, keys=[(0, dict(DASH, rx=0.0, spine=-28), "io"), (1, DASH, "snap"), (4, dict(DASH, spine=-34), "lin")])

STANCE = {"ik:R": (0.36, 0.1), "ik:L": (-0.3, 0.1), "w:ftR": -5, "w:ftL": 0}
S1_W = dict(STANCE, rx=-0.04, rz=-0.07, spine=10, head=-4, upR=150, foR=35, upL=40, foL=40, smear=None, **{"w:stick": 150})
S1_W2 = dict(S1_W, rx=-0.06, spine=14, upR=165, foR=30, **{"w:stick": 170})
S1_H = dict(STANCE, rx=0.08, rz=-0.1, spine=-22, head=10, upR=62, foR=8, upL=-35, foL=30, smear="s1", **{"w:stick": -8, "ik:L": (-0.38, 0.12)})
S1_F = dict(S1_H, rx=0.1, spine=-26, upR=28, foR=4, smear="s1b", **{"w:stick": -42})
S1_R = dict(IDLE_A, rx=0.06, spine=-14, upR=26, foR=45, smear=None, **{"w:stick": -35})
anims["strike_1"] = dict(frames=6, fps=24, keys=[(0, S1_W, "io"), (1, S1_W2, "out"), (2, S1_H, "snap"), (3, S1_F, "out"),
                                                 (4, S1_R, "io"), (6, dict(IDLE_A, smear=None), "io")])
S2_W = dict(STANCE, rx=0.02, rz=-0.13, spine=-24, head=8, upR=-30, foR=70, upL=30, foL=50, smear=None, **{"w:stick": 215})
S2_W2 = dict(S2_W, rz=-0.15, upR=-42, **{"w:stick": 232})
S2_H = dict(STANCE, rx=0.1, rz=-0.04, spine=6, head=-6, upR=128, foR=22, upL=-30, foL=20, smear="s2", **{"w:stick": 72})
S2_F = dict(S2_H, spine=9, upR=150, foR=18, smear="s2b", **{"w:stick": 100})
S2_R = dict(IDLE_A, rx=0.06, spine=-4, upR=60, foR=60, smear=None, **{"w:stick": 30})
anims["strike_2"] = dict(frames=6, fps=24, keys=[(0, S2_W, "io"), (1, S2_W2, "out"), (2, S2_H, "snap"), (3, S2_F, "out"),
                                                 (4, S2_R, "io"), (6, dict(IDLE_A, smear=None), "io")])
S3_W = dict(STANCE, rx=-0.05, rz=-0.02, spine=14, head=-10, upR=165, foR=25, upL=150, foL=30, smear=None,
            **{"w:stick": 130, "ik:R": (0.3, 0.16)})
S3_W3 = dict(S3_W, rz=0.06, spine=22, upR=178, upL=170, **{"w:stick": 158, "ik:R": (0.32, 0.3)})
S3_H = dict(STANCE, rx=0.14, rz=-0.22, spine=-42, head=18, upR=50, foR=6, upL=20, foL=30, smear="s3",
            **{"w:stick": -62, "ik:R": (0.5, 0.1), "ik:L": (-0.42, 0.12)})
S3_H2 = dict(S3_H, rz=-0.24, spine=-45, upR=40, smear="s3b", **{"w:stick": -72})
S3_R = dict(IDLE_A, rx=0.08, spine=-20, upR=30, foR=50, smear=None, **{"w:stick": -40})
anims["strike_3"] = dict(frames=10, fps=24, keys=[(0, dict(S3_W, spine=6, upR=120), "io"), (2, S3_W, "out"), (3, S3_W3, "out"),
                                                  (4, S3_H, "snap"), (5, S3_H2, "out"), (7, dict(S3_H2, smear=None), "hold"),
                                                  (8, S3_R, "io"), (10, dict(IDLE_A, smear=None), "io")])
SU_W = dict(STANCE, rz=-0.1, spine=-10, upR=10, foR=60, upL=20, smear=None, **{"w:stick": -20})
SU_H = dict(STANCE, rz=-0.02, spine=12, head=-20, upR=175, foR=15, upL=-20, smear="su", **{"w:stick": 110})
anims["strike_up"] = dict(frames=6, fps=24, keys=[(0, SU_W, "io"), (2, SU_H, "snap"), (3, dict(SU_H, smear=None, **{"w:stick": 135}), "out"),
                                                  (6, dict(IDLE_A, smear=None), "io")])
SD = dict(FALL0, spine=-30, head=20, upR=20, foR=10, upL=60, smear="sd", **{"w:stick": -88, "ik:R": (0.15, 0.35), "ik:L": (-0.15, 0.3)})
anims["strike_down"] = dict(frames=4, fps=24, keys=[(0, dict(SD, smear=None, upR=100, **{"w:stick": 40}), "io"), (1, SD, "snap"), (4, dict(SD, smear=None), "lin")])
HURT = dict(IDLE_A, rx=-0.08, rz=-0.08, spine=20, head=18, upR=-20, foR=40, upL=50, foL=60, **{"w:stick": 220})
anims["hurt"] = dict(frames=3, fps=12, keys=[(0, HURT, "io"), (1, dict(HURT, spine=24, head=24), "out"), (3, IDLE_A, "io")])
KNEEL = dict(rx=0.05, rz=-0.38, hips=0, spine=-30, head=-25, thR=85, shR=-95, thL=-10, shL=-120, upR=-5, foR=10, upL=-5, foL=10,
             **{"w:stick": 250, "w:ftR": 0, "w:ftL": -10, "ik:R": None, "ik:L": None})
DOWN = dict(KNEEL, root=-75, rx=0.45, rz=-0.22, spine=-10, head=10, upR=150, upL=140, thR=40, shR=-40, thL=20, shL=-30, **{"w:stick": -10})
anims["death"] = dict(frames=10, fps=12, keys=[(0, HURT, "io"), (2, dict(HURT, spine=28, head=30, rz=-0.12), "out"),
                                               (5, KNEEL, "io"), (6, dict(KNEEL, spine=-34), "io"), (8, DOWN, "in"), (10, DOWN, "hold")])
FLARE = dict(IDLE_A, rz=-0.1, spine=8, head=-12, upL=150, foL=40, upR=20, foR=40, **{"w:stick": -60})
anims["flare"] = dict(frames=8, fps=16, keys=[(0, IDLE_A, "io"), (3, FLARE, "out"), (8, dict(FLARE, spine=10), "lin")])

if ONLY:
    anims = {k: v for k, v in anims.items() if k in ONLY}
if STILL:
    for k in anims:
        anims[k]["frames"] = 1
nr.render_anims(rig, anims, RAW, smears, parts, "hero")

"""Swamp enemies (GDD enemies-and-elites §3.2; art bible §5.3) on navi_sculpt:
  bat     Нетопырь: furry body, huge ears, pink-glowing eyes, membrane wings
          (front view, wings spread across the screen, so the planar rig flaps them);
  sentry  Упырь-щитник: gaunt grey-blue ghoul, ribs and knobby joints, sunken
          green-glowing eyes, wooden shield with iron rim, crossbow, rags and hair
          on spring bones;
  bloat   Утопленник: drowned swollen corpse floating, weed hair, purple eyes,
          a 'swell' shape key for the fuse.
Same cel/rim/outline look and world scale as the hero (173 px per metre at 2x).

Run:  xvfb-run -a blender -b --python tools/asset-pipeline/blender/build_swamp_enemies.py -- <kind> <raw_dir> [--still]
Then: python3 tools/asset-pipeline/blender/pack_sheets.py <raw_dir> assets/art/sprites/<kind> <kind> <cell_w> <cell_h> <ox> <oy> 230
      (cells: see CELLS below; the packer arguments are printed at the end)
"""
import bpy, sys, os, math, random
from mathutils import Vector, Matrix
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import navi_common as nc
import navi_rig as nr
import navi_sculpt as ns

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
KIND = ARGS[0] if ARGS else "bat"
RAW = ARGS[1] if len(ARGS) > 1 else "/tmp/navi_%s_raw" % KIND
STILL = "--still" in ARGS
ONLY = next((a[7:].split(",") for a in ARGS if a.startswith("--only=")), None)
CELLS = {"bat": ((520, 420), (260, 330)), "sentry": ((560, 480), (250, 456)), "bloat": ((480, 480), (240, 400))}
CELL, ORIGIN = CELLS[KIND]
PPM, SS, OUT_T = 173.0, 2, 0.022

sc = nc.reset(transparent=True, samples=16)
nc.sun((-0.35, -0.9, 1.0), 2.5, "#E8F0DA")
nc.sun((0.8, 0.6, 0.3), 0.7, "#6FA0A0", shadow=False)
nc.ortho_camera(CELL[0], CELL[1], PPM, ORIGIN, SS)
parts = []


def part(rig, o, bone, outline=True):
    rig.attach(o, bone)
    nc.add_rest(o)
    if outline:
        nc.add_outline(o, OUT_T if outline is True else outline)
        parts.append(o)
    return o


def mirror(p, pairs):
    """Copy angles of the + side onto the - side, negated (front-view wings)."""
    q = dict(p)
    for a, b in pairs:
        if a in p:
            q[b] = -p[a]
    return q


# ======================================================================= bat
def build_bat():
    fur = nc.toon("fur", "#4A3A58", shadow_tint="#4A4A80", rim="#FF9AD8", rim_k=0.45,
                  paint=dict(kind="hair", c2="#2E2238", c3="#6E5A80", amt=0.7, scale=50.0))
    memb = nc.toon("membrane", "#5A4060", shadow_tint="#4A3A70", rim="#FF7AC8", rim_k=0.55,
                   paint=dict(kind="skin", c2="#3A2840", amt=0.6, scale=9.0, patch=1.0))
    bone_m = nc.toon("finger", "#2A1E30", rim_k=0.2)
    fang = nc.toon("fang", "#E8DCC0", rim_k=0.1)
    eye = nc.glow("eye", "#FF6BD0", 6.0)
    core = nc.glow("eye_core", "#FFE0F4", 8.0)
    BON = [("root", (0, 0, 0.12), (0, 0, 0.2), None), ("body", (0, 0, 0.2), (0, 0, 0.42), "root"),
           ("head", (0, 0, 0.42), (0, 0, 0.58), "body"), ("feet", (0, 0, 0.22), (0, 0, 0.06), "body"),
           ("earA", (0.04, 0, 0.55), (0.08, 0, 0.7), "head"), ("earB", (-0.04, 0, 0.55), (-0.08, 0, 0.7), "head")]
    for s, sx in (("A", 1), ("B", -1)):
        BON += [("w%s1" % s, (0.07 * sx, 0, 0.38), (0.3 * sx, 0, 0.45), "body"),
                ("w%s2" % s, (0.3 * sx, 0, 0.45), (0.52 * sx, 0, 0.37), "w%s1" % s),
                ("w%s3" % s, (0.52 * sx, 0, 0.37), (0.68 * sx, 0, 0.18), "w%s2" % s)]
    rig = nr.Rig("BatRig", BON)
    B = ns.Blob("bat_body", res=0.012)
    B.ellip((0, 0, 0.3), (0.1, 0.085, 0.14))
    B.ellip((0, -0.01, 0.2), (0.07, 0.06, 0.06))
    B.ellip((0.012, -0.015, 0.47), (0.085, 0.08, 0.075))
    B.ellip((0.03, -0.075, 0.45), (0.04, 0.035, 0.03))          # snout
    B.ball((0.03, -0.1, 0.455), 0.022)                          # pig nose
    B.warts((0, 0, 0.3), (0.1, 0.085, 0.14), 30, 0.012, 0.02, 2)  # fur tufts
    for sx in (1, -1):
        B.capsule((0.07 * sx, 0, 0.38), (0.3 * sx, 0, 0.45), 0.03)   # arm
    body = B.bake(fur)
    ns.bump(body, 0.004, 60.0, 3)
    ns.skin(body, rig, allow=["body", "head", "feet", "wA1", "wB1"])
    ns.finish(body, OUT_T, parts)
    for s, sx in (("A", 1), ("B", -1)):
        Be = ns.Blob("ear" + s, res=0.01)
        Be.ellip((0.06 * sx, -0.005, 0.57), (0.045, 0.022, 0.1), rot=(0, -0.35 * sx, 0))
        Be.ball((0.045 * sx, -0.005, 0.5), 0.04)
        ear = Be.bake(memb)
        ns.skin(ear, rig, fixed="ear" + s)
        ns.finish(ear, OUT_T * 0.8, parts)
        # wing membrane: leading edge shoulder-elbow-wrist-tip, scalloped trailing edge
        S, E, W, T = (Vector((0.07 * sx, 0, 0.38)), Vector((0.3 * sx, 0, 0.45)), Vector((0.52 * sx, 0, 0.37)), Vector((0.68 * sx, 0, 0.18)))
        lead = []
        for a, b, n in ((S, E, 5), (E, W, 5), (W, T, 4)):
            for k in range(n):
                lead.append(a.lerp(b, k / n))
        lead.append(T)
        Bt = Vector((0.03 * sx, 0, 0.17))
        rows = 6
        vs, fs = [], []
        nu = len(lead)
        for i, L in enumerate(lead):
            u = i / (nu - 1)
            tr = Bt.lerp(T, u ** 0.9) + Vector((0, 0, 0.07 * abs(math.sin(u * 3 * math.pi)) + 0.04 * u))
            for r in range(rows + 1):
                v = r / rows
                p = L.lerp(tr, v)
                p.y = 0.015 * math.sin(v * math.pi)
                vs.append(p)
        for i in range(nu - 1):
            for r in range(rows):
                a = i * (rows + 1) + r
                fs.append([a, a + rows + 1, a + rows + 2, a + 1])
        me = bpy.data.meshes.new("wing" + s)
        me.from_pydata([tuple(v) for v in vs], [], fs)
        for pl in me.polygons:
            pl.use_smooth = True
        me.materials.append(memb)
        wo = bpy.data.objects.new("wing" + s, me)
        bpy.context.scene.collection.objects.link(wo)
        ns.skin(wo, rig, allow=["body", "w%s1" % s, "w%s2" % s, "w%s3" % s], power=3.0)
        so = wo.modifiers.new("thick", "SOLIDIFY"); so.thickness = 0.012; so.offset = 0.0
        ns.finish(wo, OUT_T * 0.8, parts)
        for k, tip in enumerate((Vector((0.62 * sx, 0, 0.12)), Vector((0.45 * sx, 0, 0.12)), Vector((0.3 * sx, 0, 0.2)))):
            part(rig, nc.capsule("finger%s%d" % (s, k), tuple(W), tuple(tip), 0.009, 0.004, bone_m, seg=6), "w%s3" % s if k == 0 else "w%s2" % s, OUT_T * 0.5)
        part(rig, nc.cone("thumb" + s, tuple(W), tuple(W + Vector((0.03 * sx, 0, 0.05))), 0.012, bone_m, seg=6), "w%s2" % s, OUT_T * 0.5)
        part(rig, nc.cone("foot" + s, (0.03 * sx, 0, 0.12), (0.04 * sx, -0.02, 0.05), 0.016, bone_m, seg=6), "feet", OUT_T * 0.5)
    for sx in (1, -1):
        rig.attach(nc.ellip("eye", (0.012 + 0.035 * sx + 0.012, -0.07, 0.49), (0.018, 0.012, 0.016), eye, seg=12), "head")
        rig.attach(nc.ellip("eyec", (0.012 + 0.035 * sx + 0.014, -0.082, 0.492), (0.007, 0.005, 0.007), core, seg=8), "head")
        part(rig, nc.cone("fang", (0.03 + 0.016 * sx, -0.09, 0.43), (0.03 + 0.016 * sx, -0.095, 0.395), 0.007, fang, seg=6), "head", False)
    rig.arm.rotation_euler = (0, 0, math.radians(-12))   # head turned a little toward +X
    W = [("wA1", "wB1"), ("wA2", "wB2"), ("wA3", "wB3"), ("earA", "earB")]
    an = {}
    fk = []
    for i in range(9):
        p = 2 * math.pi * i / 8
        fk.append((i, mirror(dict(rz=0.03 * math.sin(p + 0.8), body=3 * math.sin(p), head=-4 * math.sin(p), feet=8 * math.sin(p + 1.0),
                                  wA1=38 * math.cos(p), wA2=24 * math.cos(p - 0.7), wA3=18 * math.cos(p - 1.3), earA=6 * math.sin(p + 2)), W), "lin"))
    an["fly"] = dict(frames=8, fps=16, loop=True, keys=fk)
    UP = mirror(dict(rz=0.1, body=0, head=10, feet=20, wA1=62, wA2=45, wA3=38, earA=-12), W)
    UP2 = mirror(dict(UP, rz=0.13, head=14, wA1=70, wA2=55, wA3=48), W)
    an["wind"] = dict(frames=6, fps=12, keys=[(0, fk[0][1], "io"), (3, UP, "out"), (5, UP2, "io"), (6, UP2, "hold")])
    SW = mirror(dict(rz=0.0, root=-38, body=-8, head=-12, feet=-30, wA1=-25, wA2=-95, wA3=-55, earA=25), W)
    SW2 = mirror(dict(SW, wA1=-30, wA2=-105, wA3=-62, earA=32), W)
    an["swoop"] = dict(frames=4, fps=16, loop=True, keys=[(0, SW, "io"), (2, SW2, "io"), (4, SW, "io")])
    SP0 = mirror(dict(rz=0.04, head=22, body=8, wA1=20, wA2=10, wA3=5, earA=-10), W)
    SP1 = mirror(dict(SP0, head=-18, body=-6, wA1=48, wA2=30, wA3=25), W)
    an["spit"] = dict(frames=6, fps=12, keys=[(0, fk[0][1], "io"), (3, SP0, "out"), (4, SP1, "snap"), (6, SP1, "hold")])
    HU = mirror(dict(rz=0.05, root=14, head=25, wA1=-30, wA2=-50, wA3=-30, earA=30), W)
    an["hurt"] = dict(frames=3, fps=12, keys=[(0, HU, "out"), (1, mirror(dict(HU, head=30), W), "io"), (3, fk[0][1], "io")])
    D1 = mirror(dict(rz=-0.05, root=60, head=30, wA1=-60, wA2=-110, wA3=-60, earA=30), W)
    D2 = mirror(dict(D1, rz=-0.22, root=150), W)
    an["death"] = dict(frames=8, fps=12, keys=[(0, HU, "out"), (3, D1, "in"), (7, D2, "in"), (8, D2, "hold")])
    return rig, an, []


# ==================================================================== sentry
def build_sentry():
    skin = nc.toon("ghoul", "#7E8E9A", shadow_tint="#4A4A7A", rim="#B8FFD0", rim_k=0.4,
                   paint=dict(kind="skin", c2="#56606C", amt=0.65, scale=7.0, patch=0.9, jit=0.08))
    rag = nc.toon("rag", "#4A443A", shadow_tint="#3A3A6A", rim_k=0.25,
                  paint=dict(kind="cloth", c2="#3A342C", c3="#2A2620", amt=0.6, scale=8.0, weave=120.0, dirt="#2A2A20", dirt_z=(0.3, 0.9)))
    hair = nc.toon("ghair", "#22262A", shadow_tint="#3A3A6A", rim="#9FC8B0", rim_k=0.3,
                   paint=dict(kind="hair", c2="#14181C", c3="#3A4248", amt=0.6, scale=50.0))
    wood = nc.toon("shield", "#8D7A55", shadow_tint="#5A4A6A", rim_k=0.3,
                   paint=dict(kind="wood", c2="#6E5C3E", c3="#4A3A26", amt=0.6, scale=4.0, grain=3.0))
    iron = nc.toon("iron", "#4A4C54", shadow_tint="#3A3A5A", rim="#D0E0E8", rim_k=0.6)
    bow = nc.toon("bow", "#5A4630", shadow_tint="#4A3A5A", paint=dict(kind="wood", c2="#46361E", c3="#2A2010", amt=0.5, scale=8.0))
    claw = nc.toon("gclaw", "#2A2622", rim_k=0.2)
    eye = nc.glow("geye", "#9FFFB0", 6.0)
    core = nc.glow("geye_c", "#F0FFF0", 8.0)
    L_, R_ = 0.2, -0.2
    BON = [("root", (0, 0, 0.6), (0, 0, 0.8), None), ("hips", (0, 0, 0.98), (0, 0, 1.08), "root"),
           ("spine", (0, 0, 1.05), (0.12, 0, 1.6), "hips"), ("head", (0.14, 0, 1.62), (0.2, 0, 1.92), "spine"),
           ("hair", (0.06, 0, 1.78), (0.0, 0, 1.5), "head"),
           ("rag0", (0.1, -0.05, 0.98), (0.12, -0.06, 0.58), "hips"), ("rag1", (-0.08, 0.0, 0.98), (-0.12, 0, 0.6), "hips")]
    for s, y in (("R", R_), ("L", L_)):
        BON += [("up" + s, (0.08, y, 1.52), (0.1, y, 1.17), "spine"), ("fo" + s, (0.1, y, 1.17), (0.12, y, 0.86), "up" + s),
                ("ha" + s, (0.12, y, 0.86), (0.12, y, 0.72), "fo" + s),
                ("th" + s, (0, y * 0.5, 0.98), (0.03, y * 0.5, 0.55), "hips"), ("sh" + s, (0.03, y * 0.5, 0.55), (0, y * 0.5, 0.1), "th" + s),
                ("ft" + s, (0, y * 0.5, 0.1), (0.17, y * 0.5, 0.04), "sh" + s)]
    rig = nr.Rig("SentryRig", BON)
    for pb in rig.arm.pose.bones:
        pb.rotation_mode = "QUATERNION"
    rig.legs = {s: ("th" + s, "sh" + s, math.hypot(0.03, 0.43), math.hypot(0.03, 0.45)) for s in "RL"}
    B = ns.Blob("ghoul", res=0.016)
    B.ellip((0.0, 0, 1.0), (0.14, 0.16, 0.1))                        # pelvis
    B.capsule((0.0, 0, 1.06), (0.06, 0, 1.25), 0.14)                  # waist (thin)
    B.ellip((0.08, 0, 1.38), (0.17, 0.22, 0.22), rot=(0, -0.3, 0))     # ribcage
    for k in range(5):                                               # ribs
        z = 1.24 + k * 0.05
        for sy in (1, -1):
            B.capsule((0.12 + 0.01 * k, 0.05 * sy, z), (0.03, 0.17 * sy, z + 0.03), 0.018)
    for k in range(7):                                               # spine knobs
        B.ball((-0.09 + 0.03 * k, 0, 1.12 + k * 0.07), 0.03)
    B.capsule((0.1, 0, 1.52), (0.15, 0, 1.66), 0.06)                 # neck
    B.ellip((0.17, 0, 1.75), (0.1, 0.085, 0.1))                      # skull
    B.ellip((0.24, 0, 1.68), (0.06, 0.06, 0.04))                     # jutting jaw
    B.ellip((0.26, 0, 1.74), (0.03, 0.025, 0.035))                   # nose stub
    for sy in (1, -1):
        B.ball((0.24, 0.035 * sy, 1.775), 0.028, neg=True)          # sunken sockets
        B.ellip((0.06, 0.17 * sy, 1.48), (0.08, 0.06, 0.06))         # shoulder knobs
    for s, y in (("R", R_), ("L", L_)):
        B.limb([(0.08, y, 1.5), (0.1, y, 1.17), (0.12, y, 0.86)], [0.085, 0.07, 0.055])
        B.ball((0.1, y, 1.17), 0.05)                                 # elbow knob
        B.ellip((0.12, y, 0.8), (0.04, 0.03, 0.06))                  # hand
        B.limb([(0, y * 0.5, 0.98), (0.03, y * 0.5, 0.55), (0, y * 0.5, 0.1)], [0.11, 0.075, 0.06])
        B.ball((0.04, y * 0.5, 0.55), 0.055)                         # knee knob
        B.ellip((0.07, y * 0.5, 0.05), (0.1, 0.04, 0.04))            # foot
    body = B.bake(skin)
    ns.bump(body, 0.004, 35.0, 5)
    ns.skin(body, rig, allow=[b[0] for b in BON if not b[0].startswith("rag") and b[0] not in ("hair", "root")])
    ns.finish(body, OUT_T, parts)
    for sy in (1, -1):
        rig.attach(nc.ellip("eye", (0.245, 0.035 * sy, 1.775), (0.014, 0.016, 0.012), eye, seg=10), "head")
        rig.attach(nc.ellip("eyec", (0.255, 0.035 * sy, 1.776), (0.005, 0.006, 0.005), core, seg=8), "head")
    for s, y in (("R", R_), ("L", L_)):
        for k in range(3):
            part(rig, nc.cone("claw%s%d" % (s, k), (0.14, y + (k - 1) * 0.02, 0.76), (0.16, y + (k - 1) * 0.025, 0.66), 0.01, claw, seg=6), "ha" + s, OUT_T * 0.5)
    # rags (loincloth + belt) and stringy hair on spring bones
    rnd = random.Random(9)
    roots = [((rnd.uniform(-0.12, 0.14), rnd.uniform(-0.16, 0.16), 1.04), (rnd.uniform(-0.1, 0.1), 0, -1), rnd.uniform(0.25, 0.45), 0.4) for _ in range(14)]
    rags = ns.ribbon_strands("rags", roots, rag, rig, "hips", lambda i: "rag0" if roots[i][0][0] > 0 else "rag1", width=0.07, thick=0.01)
    ns.finish(rags, OUT_T * 0.6, parts)
    hroots = [((0.12 + rnd.uniform(-0.08, 0.04), rnd.uniform(-0.08, 0.08), 1.82 + rnd.uniform(-0.03, 0.02)), (-0.4, rnd.uniform(-0.3, 0.3), -1), rnd.uniform(0.25, 0.4), 0.3) for _ in range(12)]
    hr = ns.ribbon_strands("ghair", hroots, hair, rig, "head", lambda i: "hair", width=0.025, thick=0.008)
    ns.finish(hr, OUT_T * 0.5, parts)
    # shield on the near forearm (faces +X), iron rim and boss; crossbow in the far hand
    # the shield is placed upright in the idle pose and bound to the posed forearm
    rig.apply(dict(IDLE_POSE))
    bpy.context.view_layer.update()
    SX, SY, SZ = 0.36, R_ - 0.1, 1.08
    shp = [nc.ellip("shield", (SX, SY, SZ), (0.045, 0.25, 0.36), wood, seg=24),
           nc.torus("rim", (SX + 0.02, SY, SZ), 0.3, 0.02, iron, rot=(0, math.radians(90), 0), scale=(1.2, 0.83, 1)),
           nc.ellip("boss", (SX + 0.045, SY, SZ), (0.04, 0.07, 0.07), iron)]
    for k, z in enumerate((SZ - 0.18, SZ + 0.18)):
        shp.append(nc.capsule("band%d" % k, (SX + 0.03, SY - 0.24, z), (SX + 0.03, SY + 0.24, z), 0.012, 0.012, iron))
    pb = rig.arm.pose.bones["foR"]
    M = (rig.arm.matrix_world @ pb.matrix @ Matrix.Translation((0, pb.bone.length, 0))).inverted()
    for k, o in enumerate(shp):
        o.parent = rig.arm; o.parent_type = "BONE"; o.parent_bone = "foR"; o.matrix_parent_inverse = M
        nc.add_rest(o)
        if k < 3:
            nc.add_outline(o, OUT_T if k == 0 else OUT_T * 0.6); parts.append(o)
    hx = (0.12, L_, 0.78)
    part(rig, nc.capsule("stock", (0.0, L_, 0.78), (0.55, L_, 0.78), 0.025, 0.02, bow), "haL", OUT_T * 0.6)
    part(rig, nc.capsule("prod", (0.5, L_ - 0.16, 0.78), (0.5, L_ + 0.16, 0.78), 0.014, 0.014, bow, bend=0.04), "haL", OUT_T * 0.6)
    part(rig, nc.cone("bolt", (0.3, L_, 0.81), (0.66, L_, 0.81), 0.012, iron, seg=6), "haL", 0)
    rig.arm.rotation_euler = (0, 0, math.radians(-30))
    SPR = [dict(bone="hair", k=200.0, damp=0.85, g=0.6), dict(bone="rag0", k=180.0, damp=0.86, g=0.85), dict(bone="rag1", k=180.0, damp=0.86, g=0.85)]
    IDLE = IDLE_POSE
    an = {}
    an["idle"] = dict(frames=8, fps=8, loop=True, keys=[(0, IDLE, "io"), (4, dict(IDLE, rz=-0.07, spine=-9, head=12, upR=52), "io"), (8, IDLE, "io")])
    wk = []
    for i in range(9):
        p = 2 * math.pi * i / 8

        def foot(ph):
            return (0.2 * math.cos(ph), 0.1 + (0.12 * math.sin(ph - math.pi) if math.sin(ph) < 0 else 0.0))
        wk.append((i, dict(IDLE, **{"ik:R": foot(p), "ik:L": foot(p + math.pi)}, rz=-0.06 + 0.03 * abs(math.sin(p)), spine=-10 + 2 * math.cos(2 * p),
                           head=10 + 3 * math.sin(2 * p), upL=18 + 10 * math.cos(p)), "lin"))
    an["walk"] = dict(frames=8, fps=10, loop=True, keys=wk)
    AIM = dict(IDLE, spine=-2, head=-6, upL=80, foL=12, haL=0, upR=48, foR=62)
    an["aim"] = dict(frames=6, fps=12, keys=[(0, IDLE, "io"), (3, AIM, "out"), (5, dict(AIM, spine=-4, head=-8), "io"), (6, AIM, "hold")])
    B0 = dict(IDLE, rx=-0.06, spine=12, head=0, upR=25, foR=100, upL=-10, foL=60)
    B1 = dict(FE, rx=0.12, rz=-0.1, spine=-28, head=18, upR=88, foR=8, upL=-25, foL=50, **{"ik:R": (0.42, 0.1), "ik:L": (-0.2, 0.1)})
    an["bash"] = dict(frames=6, fps=12, keys=[(0, IDLE, "io"), (3, B0, "out"), (4, dict(B0, rx=-0.08, spine=15), "io"), (5, B1, "snap"), (6, B1, "hold")])
    HU = dict(IDLE, rx=-0.07, spine=16, head=22, upR=30, foR=70, upL=40, foL=60)
    an["hurt"] = dict(frames=3, fps=12, keys=[(0, HU, "out"), (1, dict(HU, head=26), "io"), (3, IDLE, "io")])
    KN = dict(rx=0.05, rz=-0.4, hips=0, spine=-35, head=-20, thR=85, shR=-95, thL=-10, shL=-120, upR=40, foR=60, upL=-5, foL=20,
              **{"ik:R": None, "ik:L": None, "w:ftR": 0, "w:ftL": -10})
    DN = dict(KN, root=-80, rx=0.5, rz=-0.3, spine=-5, head=10, upR=150, upL=140, thR=30, shR=-30, thL=20, shL=-20)
    an["death"] = dict(frames=10, fps=12, keys=[(0, HU, "out"), (2, dict(HU, spine=24, rz=-0.1), "out"), (5, KN, "io"), (8, DN, "in"), (10, DN, "hold")])
    return rig, an, SPR


FE = {"ik:R": (0.22, 0.1), "ik:L": (-0.18, 0.1), "w:ftR": -12, "w:ftL": -12}
IDLE_POSE = dict(FE, rz=-0.05, spine=-6, head=8, upR=55, foR=55, haR=0, upL=18, foL=70, haL=-10)


# ===================================================================== bloat
SWELL = {}


def build_bloat():
    skin = nc.toon("drowned", "#7E9A78", shadow_tint="#4A4A7A", rim="#E8A8F0", rim_k=0.45,
                   paint=dict(kind="skin", c2="#6A5878", amt=0.8, scale=6.0, patch=0.8, jit=0.08))
    weed = nc.toon("bweed", "#3E5A34", shadow_tint="#3A4A70", rim="#9ED36B", rim_k=0.3,
                   paint=dict(kind="hair", c2="#26381E", c3="#5E7A40", amt=0.6, scale=40.0))
    stitch = nc.toon("stitch", "#2A1A22", rim_k=0.0)
    eye = nc.glow("beye", "#D36BD0", 6.0)
    core = nc.glow("beye_c", "#FFE0FA", 8.0)
    BON = [("root", (0, 0, 0.3), (0, 0, 0.5), None), ("body", (0, 0, 0.5), (0.1, 0, 0.8), "root"),
           ("head", (0.16, 0, 0.8), (0.26, 0, 1.02), "body"), ("hair", (0.08, 0, 0.98), (-0.05, 0, 0.7), "head"),
           ("wd0", (-0.25, 0, 0.75), (-0.32, 0, 0.35), "body"), ("wd1", (0.0, 0, 0.9), (-0.05, 0, 0.5), "body")]
    for s, y in (("R", -0.36), ("L", 0.36)):
        BON += [("arm" + s, (0.08, y, 0.64), (0.18, y * 1.15, 0.4), "body"), ("fore" + s, (0.18, y * 1.15, 0.4), (0.22, y * 1.15, 0.22), "arm" + s),
                ("leg" + s, (-0.05, y * 0.4, 0.18), (-0.02, y * 0.45, -0.04), "body")]
    rig = nr.Rig("BloatRig", BON)
    B = ns.Blob("bloat", res=0.016)
    B.ellip((0, 0, 0.5), (0.4, 0.38, 0.38))
    B.ellip((0.05, 0, 0.36), (0.32, 0.3, 0.22))                      # sagging belly
    B.warts((0, 0, 0.5), (0.36, 0.34, 0.34), 18, 0.04, 0.07, 6)      # blisters
    B.ball((0.39, 0, 0.42), 0.03, neg=True)                         # navel
    B.ellip((0.17, 0, 0.86), (0.17, 0.17, 0.14))                     # head sunk on the body
    B.ellip((0.24, 0, 0.82), (0.08, 0.13, 0.07))                     # puffy cheeks
    for s, y in (("R", -0.36), ("L", 0.36)):
        B.limb([(0.06, y * 0.9, 0.66), (0.18, y * 1.12, 0.4), (0.22, y * 1.15, 0.22)], [0.1, 0.075, 0.06])
        B.ellip((0.23, y * 1.15, 0.18), (0.05, 0.045, 0.05))
        B.limb([(-0.05, y * 0.4, 0.26), (-0.02, y * 0.45, -0.04)], [0.1, 0.065])
    body = B.bake(skin)
    ns.bump(body, 0.006, 26.0, 8)
    # 'swell' shape key: push the trunk outward from its centre, limbs and head less
    body.shape_key_add(name="Basis")
    k = body.shape_key_add(name="swell")
    c = Vector((0, 0, 0.5))
    for i, v in enumerate(body.data.vertices):
        d = v.co - c
        trunk = max(0.0, 1.0 - max(0.0, d.length - 0.45) / 0.2)
        k.data[i].co = v.co + d * 0.38 * trunk
    SWELL["key"] = k
    ns.skin(body, rig, allow=[b[0] for b in BON if b[0] not in ("root", "hair", "wd0", "wd1")])
    ns.finish(body, OUT_T, parts)
    for sy in (1, -1):
        rig.attach(nc.ellip("eye", (0.3, 0.05 * sy, 0.9), (0.016, 0.022, 0.016), eye, seg=10), "head")
        rig.attach(nc.ellip("eyec", (0.312, 0.05 * sy, 0.902), (0.006, 0.008, 0.006), core, seg=8), "head")
    part(rig, nc.capsule("mouth", (0.3, -0.05, 0.81), (0.3, 0.05, 0.81), 0.008, 0.008, stitch), "head", 0)
    for k2 in range(4):
        y = -0.04 + k2 * 0.027
        part(rig, nc.capsule("st%d" % k2, (0.305, y, 0.79), (0.305, y, 0.83), 0.004, 0.004, stitch), "head", 0)
    rnd = random.Random(12)
    roots = [((0.1 + rnd.uniform(-0.1, 0.06), rnd.uniform(-0.12, 0.12), 0.97), (-0.5, rnd.uniform(-0.4, 0.4), -1), rnd.uniform(0.2, 0.42), 0.5) for _ in range(14)]
    hr = ns.ribbon_strands("bhair", roots, weed, rig, "head", lambda i: "hair", width=0.03, thick=0.008)
    ns.finish(hr, OUT_T * 0.5, parts)
    wroots = [((rnd.uniform(-0.3, 0.1), rnd.choice((-1, 1)) * rnd.uniform(0.2, 0.34), rnd.uniform(0.6, 0.8)), (rnd.uniform(-0.2, 0.1), 0, -1), rnd.uniform(0.25, 0.45), 0.6) for _ in range(10)]
    wd = ns.ribbon_strands("bweeds", wroots, weed, rig, "body", lambda i: "wd0" if wroots[i][0][0] < -0.1 else "wd1", width=0.035, thick=0.008)
    ns.finish(wd, OUT_T * 0.5, parts)
    rig.arm.rotation_euler = (0, 0, math.radians(-30))
    SPR = [dict(bone="hair", k=160.0, damp=0.87, g=0.7), dict(bone="wd0", k=140.0, damp=0.87, g=0.85), dict(bone="wd1", k=140.0, damp=0.87, g=0.85)]
    an = {}
    ik = []
    for i in range(9):
        p = 2 * math.pi * i / 8
        ik.append((i, dict(rz=0.04 * math.sin(p), root=3 * math.sin(p + 0.5), head=5 * math.sin(p + 1.2), armR=20 + 18 * math.sin(p), foreR=-20 + 15 * math.sin(p + 0.8),
                           armL=-20 + 18 * math.sin(p + math.pi), foreL=20 + 15 * math.sin(p + math.pi + 0.8), legR=10 * math.sin(p + 2), legL=10 * math.sin(p + 2 + math.pi), sk=0.0), "lin"))
    an["idle"] = dict(frames=8, fps=10, loop=True, keys=ik)
    sw = []
    for i in range(9):
        k2 = i / 8
        sw.append((i, dict(rz=0.02 * k2, root=-6 * k2 + (3 if i % 2 else -3) * k2, head=18 * k2, armR=-40 * k2 + 20, foreR=-30 * k2, armL=40 * k2 - 20, foreL=30 * k2,
                           legR=-25 * k2, legL=25 * k2, sk=min(1.0, k2 * 1.05) + (0.04 if i % 2 else 0.0) * k2), "lin"))
    an["swell"] = dict(frames=8, fps=10, keys=sw)
    HU = dict(rz=0.03, root=14, head=-20, armR=60, armL=-60, sk=0.1)
    an["hurt"] = dict(frames=3, fps=12, keys=[(0, HU, "out"), (1, dict(HU, root=18), "io"), (3, ik[0][1], "io")])
    return rig, an, SPR


def bloat_frame(p):
    if "key" in SWELL:
        SWELL["key"].value = max(0.0, min(1.0, p.get("sk", 0.0)))


rig, anims, springs = {"bat": build_bat, "sentry": build_sentry, "bloat": build_bloat}[KIND]()
if ONLY:
    anims = {k: v for k, v in anims.items() if k in ONLY}
if STILL:
    for k in anims:
        anims[k]["frames"] = 1
nr.render_anims(rig, anims, RAW, {}, parts, KIND, springs=springs, on_frame=bloat_frame if KIND == "bloat" else None)
print("PACK: python3 tools/asset-pipeline/blender/pack_sheets.py %s assets/art/sprites/%s %s %d %d %d %d 230" % (RAW, KIND, KIND, CELL[0], CELL[1], ORIGIN[0], ORIGIN[1]))

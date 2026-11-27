"""Hero tier 1 «Павший» v2 (art bible §5.1, §5.6): half-naked bearded man with a knotted
stick, wooden amulet on a cord, red thread of Mokosh on the near wrist.

v2 body: the CC0 MakeHuman base mesh (real anatomy, hands with fingers, a face),
re-posed and stylised by mh_base.py into data/hero_base.json.gz, skinned to the
planar rig with MakeHuman's own smooth weights (one deforming mesh, no tube
limbs). Trousers, foot wraps, rope belt, hair, beard and brows are shells grown
from the body surface (they inherit its weights, so they deform with it), plus
tapered strands for a shaggy silhouette. Hair, beard, belt end and amulet hang
on spring bones (navi_rig.Rig.secondary: follow-through). Painted albedo is
procedural (navi_common.paint_nodes) under the same cel ramp, rim and outline.

Run:  xvfb-run -a blender -b --python tools/asset-pipeline/blender/build_hero.py -- <raw_dir> [--only=idle,run] [--still]
Then: python3 tools/asset-pipeline/blender/pack_sheets.py <raw_dir> assets/art/sprites/hero hero 560 480 230 452 320
"""
import bpy, bmesh, sys, os, math, gzip, json, heapq, random
from mathutils import Vector
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import navi_common as nc
import navi_rig as nr

HERE = os.path.dirname(os.path.abspath(__file__))
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
RAW = ARGS[0] if ARGS else "/tmp/navi_hero_raw"
ONLY = next((a[7:].split(",") for a in ARGS if a.startswith("--only=")), None)
STILL = "--still" in ARGS
CLOSE = "--closeup" in ARGS   # 2x close camera on the head and chest (look-dev)

CELL = (560, 480)
ORIGIN = (230, 452)    # feet in the cell, px from top-left
PPM = 173.0            # px per metre at 2x
SS = 2                 # supersampling factor (render at 4x, downsample)
YAW = 40.0             # three-quarter turn toward the camera, degrees
OUT_T = 0.024          # outline hull of the body, m
OUT_S = 0.016          # outline of shells (clothes, hair)

SKIN, SKIN_2 = "#DE9C74", "#C2705A"
LINEN, WRAP, STICK = "#CDBB98", "#9A8A72", "#8C6A44"
HAIR, HAIR_D = "#7E5230", "#5A3820"
THREAD, GLOW = "#B3262E", "#FFC94A"

sc = nc.reset(transparent=True, samples=16)
nc.sun((-0.35, -0.9, 1.0), 2.7, "#FFF0DA")
nc.sun((0.8, 0.6, 0.3), 0.6, "#7FA3C8", shadow=False)
if CLOSE:
    nc.ortho_camera(CELL[0], CELL[1], PPM * 3.0, (235, 1010), SS)
else:
    nc.ortho_camera(CELL[0], CELL[1], PPM, ORIGIN, SS)

m_skin = nc.toon("skin", SKIN, shadow_tint="#7A5A7A", rim="#FFD9A8",
                 paint=dict(kind="skin", c2=SKIN_2, amt=0.45, scale=9.0, patch=0.6, jit=0.06))
m_lin = nc.toon("linen", LINEN, shadow_tint="#4E527E", rim="#FFE8C0", rim_k=0.5, levels=(0.2, 0.5),
                paint=dict(kind="cloth", c2="#B7A27E", c3="#8E7F64", amt=0.6, scale=7.0, weave=160.0,
                           dirt="#6A5A44", dirt_z=(0.3, 0.75)))
m_wrap = nc.toon("wrap", WRAP, shadow_tint="#6A6E8E",
                 paint=dict(kind="wrap", c2="#857660", c3="#5E5244", amt=0.5, scale=10.0, pitch=0.03, twist=0.5, cord="#2E2018"))
m_rope = nc.toon("rope", "#7A6044", shadow_tint="#6A5A7A",
                 paint=dict(kind="rope", c2="#6A4E34", c3="#3E2C1E", amt=0.4, scale=20.0, pitch=0.012, twist=1.0))
m_stick = nc.toon("stick", STICK, shadow_tint="#6A5A7A",
                  paint=dict(kind="wood", c2="#755434", c3="#4A3020", amt=0.5, scale=6.0, grain=2.5))
m_hair = nc.toon("hair", HAIR, shadow_tint="#6A5070", rim="#E8B070",
                 paint=dict(kind="hair", c2=HAIR_D, c3="#A87448", amt=0.7, scale=60.0, patch=0.15))
m_brow = nc.toon("brow", HAIR_D, shadow_tint="#6A5070", rim_k=0.1)
m_thread = nc.toon("thread", THREAD, emit=0.35, rim_k=0.2)
m_wood = nc.toon("amulet_wood", "#9C7448", paint=dict(kind="wood", c2="#80603A", c3="#5A3E24", amt=0.4, scale=30.0, grain=4.0))
m_glow = nc.glow("amulet_glow", GLOW, 3.0)
m_cord = nc.toon("cord", "#3A2A20", rim_k=0.1)


def eye_mat():
    m = bpy.data.materials.new("eye")
    m.use_nodes = True
    nt = m.node_tree; n = nt.nodes; n.clear()
    out = n.new("ShaderNodeOutputMaterial")
    at = n.new("ShaderNodeAttribute"); at.attribute_name = "iris"
    col = nc._mix(nt, nc._remap(nt, at.outputs["Fac"], 0.90, 0.92), "#CDBDA4", "#4A3020")
    col = nc._mix(nt, nc._remap(nt, at.outputs["Fac"], 0.965, 0.975), col, "#0C0806")
    col = nc._mix(nt, nc._remap(nt, at.outputs["Fac"], 0.985, 0.99), col, "#FFF4DA")
    em = n.new("ShaderNodeEmission"); nt.links.new(col, em.inputs[0]); em.inputs[1].default_value = 0.9
    nt.links.new(em.outputs[0], out.inputs[0])
    return m


m_eye = eye_mat()

# ---------------- base body ----------------
D = json.load(gzip.open(os.path.join(HERE, "data", "hero_base.json.gz"), "rt"))
J = {k: Vector(v) for k, v in D["joints"].items()}
VB = [Vector(v) for v in D["verts"]]
FB = D["faces"]
WB = {b: dict((i, w) for i, w in lst) for b, lst in D["weights"].items()}
NV = len(VB)


def w(b, i):
    return WB.get(b, {}).get(i, 0.0)


def arm_w(i):
    return sum(w(b + s, i) for b in ("up", "fo", "ha") for s in "LR")


def leg_side(i):
    return "R" if VB[i].y < 0 else "L"


eyeR, eyeL = J["eye.R"], J["eye.L"]
EYE_Z = eyeR.z
HEAD_CX = J["head"].x
headv = [i for i in range(NV) if w("head", i) > 0.9]
nose = max((VB[i] for i in headv if abs(VB[i].y) < 0.012 and EYE_Z - 0.08 < VB[i].z < EYE_Z - 0.01), key=lambda v: v.x)
NOSE_Z = nose.z
CHIN_Z = min(VB[i].z for i in headv if VB[i].x > HEAD_CX + 0.02 and abs(VB[i].y) < 0.02)
WAIST_Z = J["spine04"].z + 0.035
ANK = {s: J["foot." + s] for s in "LR"}
KNEE = {s: J["lowerleg01." + s] for s in "LR"}
TROUSER_BOT = ANK["R"].z + 0.42 * (KNEE["R"].z - ANK["R"].z)
WRAP_TOP = TROUSER_BOT + 0.07
print("landmarks: eye %.3f nose %.3f/%.3f chin %.3f waist %.3f trouser_bot %.3f" % (EYE_Z, nose.x, NOSE_Z, CHIN_Z, WAIST_Z, TROUSER_BOT))


def ss(x):
    x = max(0.0, min(1.0, x))
    return x * x * (3 - 2 * x)


def hnoise(v, f=40.0):
    """Cheap smooth 3D value noise (sum of sines), -1..1."""
    return (math.sin(v.x * f + 1.3 * math.sin(v.z * f * 0.7)) * math.sin(v.y * f * 1.3 + 0.7) +
            math.sin(v.z * f * 1.7 + v.x * f * 0.5)) * 0.5


# rig from the model's joints (planar: x forward, z up; y only offsets the sides)
def P(v):
    return (v.x, v.y, v.z)


k_mean = sum((J["finger%d-1.R" % f] for f in range(2, 6)), Vector()) / 4
m_mean = sum((J["finger%d-2.R@tail" % f] for f in range(2, 6)), Vector()) / 4
GRIP = (k_mean * 0.45 + m_mean * 0.55)
sd = J["finger2-1.R"] - J["finger5-1.R"]
SDIR = Vector((sd.x, 0, sd.z)).normalized()
NECK = J["neck01"]
CHEST_Z = NECK.z - 0.21
chest_x = max(VB[i].x for i in range(NV) if abs(VB[i].y) < 0.03 and abs(VB[i].z - CHEST_Z) < 0.015 and arm_w(i) < 0.05)
AMULET = Vector((chest_x + 0.022, -0.01, CHEST_Z))
BELT_END = Vector((0.0, 0.0, WAIST_Z - 0.01))
bx = max(VB[i].x for i in range(NV) if abs(VB[i].z - BELT_END.z) < 0.012 and abs(VB[i].y + 0.07) < 0.02 and arm_w(i) < 0.05)
BELT_END = Vector((bx + 0.02, -0.075, WAIST_Z - 0.015))
BEARD_P = Vector((nose.x - 0.025, 0, CHIN_Z + 0.02))
HAIR_P = Vector((HEAD_CX - 0.07, 0, EYE_Z + 0.03))

BONES = [
    ("root", (0, 0, J["root"].z - 0.3), (0, 0, J["root"].z - 0.12), None),
    ("hips", P(J["root"]), (J["root"].x, 0, J["root"].z + 0.09), "root"),
    ("spine", P(J["spine04"]), (J["spine04"].x, 0, NECK.z), "hips"),
    ("head", P(J["neck02"]), (J["neck02"].x, 0, J["neck02"].z + 0.3), "spine"),
    ("hair", P(HAIR_P), P(HAIR_P + Vector((-0.05, 0, -0.17))), "head"),
    ("beard", P(BEARD_P), P(BEARD_P + Vector((0.02, 0, -0.12))), "head"),
    ("amul", (NECK.x + 0.03, 0, NECK.z - 0.02), P(AMULET), "spine"),
    ("belt", P(BELT_END), P(BELT_END + Vector((0.01, 0, -0.17))), "hips"),
]
for s in "RL":
    BONES += [
        ("up" + s, P(J["upperarm01." + s]), P(J["lowerarm01." + s]), "spine"),
        ("fo" + s, P(J["lowerarm01." + s]), P(J["wrist." + s]), "up" + s),
        ("ha" + s, P(J["wrist." + s]), P(J["wrist." + s] - Vector((0, 0, 0.08))), "fo" + s),
        ("th" + s, P(J["upperleg01." + s]), P(KNEE[s]), "hips"),
        ("sh" + s, P(KNEE[s]), P(ANK[s]), "th" + s),
        ("ft" + s, P(ANK[s]), P(J["toe3-1." + s]), "sh" + s),
    ]
gR = GRIP
BONES.append(("stick", P(gR), P(gR + SDIR * 0.3), "haR"))
rig = nr.Rig("HeroRig", BONES)


def xzlen(a, b):
    return math.hypot(a.x - b.x, a.z - b.z)


rig.legs = {s: ("th" + s, "sh" + s, xzlen(J["upperleg01." + s], KNEE[s]), xzlen(KNEE[s], ANK[s])) for s in "RL"}
rig.ik_dz = ANK["R"].z - 0.1
SPRINGS = [dict(bone="hair", k=220.0, damp=0.84, g=0.25), dict(bone="beard", k=300.0, damp=0.84, g=0.2),
           dict(bone="belt", k=160.0, damp=0.88, g=0.85), dict(bone="amul", k=240.0, damp=0.85, g=0.6)]
parts = []


def finish(o, outline, groups=None, ol_w=None):
    """Weights + armature modifier + rest attribute + outline; parent to the rig."""
    if groups:
        for b, lst in groups.items():
            vg = o.vertex_groups.get(b) or o.vertex_groups.new(name=b)
            for i, wt in lst:
                vg.add([i], wt, "REPLACE")
        mod = o.modifiers.new("arm", "ARMATURE")
        mod.object = rig.arm
        o.parent = rig.arm
    nc.add_rest(o)
    if outline:
        nc.add_outline(o, outline)
        parts.append(o)
        if ol_w:   # per-vertex outline width (thin on the face and hands, none at the eyes)
            vg = o.vertex_groups.new(name="ol")
            for i, x in enumerate(ol_w):
                vg.add([i], max(0.0, min(1.0, x)), "REPLACE")
            md = o.modifiers["outline"]
            md.vertex_group = "ol"
            md.thickness_vertex_group = 0.0
    return o


def mesh_obj(name, verts, faces, mat, uvs=None, subsurf=0):
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in verts], [], faces)
    me.update()
    for p in me.polygons:
        p.use_smooth = True
    if uvs:
        uvl = me.uv_layers.new(name="UVMap")
        k = 0
        for p, fu in zip(me.polygons, uvs):
            for li, uv in zip(p.loop_indices, fu):
                uvl.data[li].uv = uv
    me.materials.append(mat)
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    if subsurf:
        sm = o.modifiers.new("sub", "SUBSURF"); sm.levels = subsurf; sm.render_levels = subsurf
    return o


def body_groups(idx_map):
    g = {}
    for b, d in WB.items():
        lst = [(idx_map[i], wt) for i, wt in d.items() if i in idx_map]
        if lst:
            g[b] = lst
    return g


body = mesh_obj("body", VB, FB, m_skin, D["uvs"])
NB = [v.normal.copy() for v in body.data.vertices]
def body_ol(i):
    v = VB[i]
    e = min((v - eyeR).length, (v - eyeL).length)
    face = w("head", i) * (0.55 + 0.45 * ss((v.x - HEAD_CX) / 0.04))
    hand = w("haR", i) + w("haL", i)
    return min(1.0 - 0.6 * face - 0.45 * hand, ss((e - 0.022) / 0.02) * 0.9 + 0.1)


finish(body, OUT_T, body_groups({i: i for i in range(NV)}), [body_ol(i) for i in range(NV)])
# sockets/arm order: armature then outline (finish adds them in that order)

# eyes (MakeHuman eyeball helpers), with an 'iris' attribute: how frontal the point is
eye_v = sorted({i for f in D["eye_faces"] for i in f})
emap = {i: k for k, i in enumerate(eye_v)}
eyes = mesh_obj("eyes", [VB[i] for i in eye_v], [[emap[i] for i in f] for f in D["eye_faces"]], m_eye)
fw = {}
for s, c in (("R", eyeR), ("L", eyeL)):
    fw[s] = Vector((1.0, 0.12 * (1 if s == "L" else -1), -0.04)).normalized()
nc.set_point_attr(eyes, "iris", [max(0.0, (VB[i] - (eyeR if VB[i].y < 0 else eyeL)).normalized().dot(fw["R" if VB[i].y < 0 else "L"])) for i in eye_v], "FLOAT")
finish(eyes, 0, {"head": [(k, 1.0) for k in range(len(eye_v))]})


# ---------------- shells grown from the body ----------------
def shell(name, mask, disp, mat, out=OUT_S, subsurf=1, weight_fn=None, attrs=None):
    fidx = [f for f in FB if all(mask[i] for i in f)]
    vids = sorted({i for f in fidx for i in f})
    idx = {i: k for k, i in enumerate(vids)}
    ecount = {}
    adj = {i: set() for i in vids}
    for f in fidx:
        for a, b in zip(f, f[1:] + f[:1]):
            e = (min(a, b), max(a, b))
            ecount[e] = ecount.get(e, 0) + 1
            adj[a].add(b); adj[b].add(a)
    dist = {i: 1e9 for i in vids}
    pq = []
    for (a, b), c in ecount.items():
        if c == 1:
            for v in (a, b):
                dist[v] = 0.0
    for v in vids:
        if dist[v] == 0.0:
            heapq.heappush(pq, (0.0, v))
    while pq:
        d, v = heapq.heappop(pq)
        if d > dist[v]:
            continue
        for u in adj[v]:
            nd = d + (VB[u] - VB[v]).length
            if nd < dist[u]:
                dist[u] = nd; heapq.heappush(pq, (nd, u))
    verts = [VB[i] + disp(i, min(dist[i], 1.0)) for i in vids]
    uv_map = {}
    o = mesh_obj(name, verts, [[idx[i] for i in f] for f in fidx], mat, subsurf=subsurf)
    g = body_groups(idx)
    if weight_fn:
        g = weight_fn(vids, verts, g)
    if attrs:
        for an, fn in attrs.items():
            nc.set_point_attr(o, an, [fn(i, verts[k]) for k, i in enumerate(vids)])
    finish(o, out, g)
    return o, vids, verts, dist


def reweight(vids, verts, g, bone, t_fn):
    """Move a share t_fn(new position) of each vertex's weight onto a spring bone."""
    t = [t_fn(v) for v in verts]
    new = {}
    for b, lst in g.items():
        new[b] = [(k, wt * (1 - t[k])) for k, wt in lst]
    new[bone] = [(k, t[k]) for k in range(len(verts)) if t[k] > 0]
    return new


def leg_ang(i):
    s = leg_side(i)
    c = ANK[s].lerp(KNEE[s], 0.5)
    return math.atan2(VB[i].y - c.y, VB[i].x - c.x)


# trousers: loose linen, baggy at the knee, horizontal folds, tucked into the wraps
legs = [VB[i].z < WAIST_Z and VB[i].z > TROUSER_BOT and arm_w(i) < 0.02 and w("head", i) < 0.01 for i in range(NV)]


def trouser_disp(i, d):
    v = VB[i]
    z = v.z
    s = leg_side(i)
    bag = math.exp(-((z - KNEE[s].z + 0.05) / 0.16) ** 2)
    hem = ss((z - TROUSER_BOT) / 0.1)
    fold = math.sin(z * 48.0 + 2.5 * math.sin(leg_ang(i) * 2.0) + 3.0 * hnoise(v, 9)) * (0.4 + 0.6 * bag)
    off = 0.010 + (0.02 * bag + 0.009 * fold) * hem + 0.004 * hnoise(v, 25)
    return NB[i] * off


trousers = shell("trousers", legs, trouser_disp, m_lin)

# foot wraps (onuchi): bands spiralling up the shin, criss-cross cords above the ankle
wr_mask = [VB[i].z < WRAP_TOP and arm_w(i) < 0.02 for i in range(NV)]


def wrap_disp(i, d):
    v = VB[i]
    s = leg_side(i)
    top = ss((v.z - ANK[s].z) / (WRAP_TOP - ANK[s].z))
    ph = v.z / 0.03 + 0.5 * leg_ang(i) / (2 * math.pi)
    return NB[i] * (0.011 + 0.016 * top + 0.0025 * math.cos(ph * 2 * math.pi) + 0.002 * hnoise(v, 30))


def wrapuv(i, v):
    s = leg_side(i)
    above = 1.0 if VB[i].z > ANK[s].z + 0.03 else 0.0
    if VB[i].z < ANK[s].z - 0.01:   # foot: bands across the foot
        return (0.0, VB[i].x - ANK[s].x + VB[i].z * 0.5, 0.0)
    return (leg_ang(i) / (2 * math.pi), VB[i].z, above)


wraps = shell("wraps", wr_mask, wrap_disp, m_wrap, attrs={"wrapuv": wrapuv})

# rope belt: twisted rope band at the waist
belt_mask = [abs(VB[i].z - (WAIST_Z - 0.005)) < 0.026 and arm_w(i) < 0.02 for i in range(NV)]


def body_ang(i):
    return math.atan2(VB[i].y, VB[i].x - 0.02)


belt, *_ = shell("belt", belt_mask, lambda i, d: NB[i] * (0.016 + 0.012 * ss(d / 0.01)), m_rope,
                 attrs={"wrapuv": lambda i, v: (body_ang(i) * 4.0, VB[i].z, 0.0)})

# beard: grown from the jaw, cheeks and upper lip, pointed and pushed forward at the chin
beard_mask = [w("head", i) + w("spine", i) * 0.0 > 0.45 and VB[i].z < NOSE_Z - 0.012 and VB[i].z > CHIN_Z - 0.06
              and VB[i].x > HEAD_CX - 0.012 for i in range(NV)]


def beard_disp(i, d):
    v = VB[i]
    front = ss((v.x - (HEAD_CX + 0.03)) / 0.06) * math.exp(-(v.y / 0.055) ** 2)
    g = ss(d / 0.025)
    low = ss((NOSE_Z - 0.03 - v.z) / 0.04)
    off = NB[i] * (0.004 + 0.02 * g * (0.5 + 0.5 * low)) + Vector((0.025, 0, -0.085)) * g * front * low
    off += NB[i] * 0.005 * g * hnoise(v, 28)
    return off


beard, bvids, bverts, _ = shell("beard", beard_mask, beard_disp, m_hair, subsurf=2,
                               weight_fn=lambda vids, verts, g: reweight(vids, verts, g, "beard", lambda p: ss((CHIN_Z + 0.01 - p.z) / 0.09)))


# hair: shell over the scalp + shaggy strands, longer at the back
def hairline(x):
    if x > HEAD_CX + 0.045:
        return EYE_Z + 0.058
    if x > HEAD_CX - 0.015:
        return EYE_Z + 0.058 - (HEAD_CX + 0.045 - x) / 0.06 * 0.045
    return EYE_Z + 0.013 - min(1.0, (HEAD_CX - 0.015 - x) / 0.05) * 0.095


hair_mask = [w("head", i) > 0.6 and VB[i].z > hairline(VB[i].x) and not beard_mask[i] for i in range(NV)]


def hair_disp(i, d):
    v = VB[i]
    g = ss(d / 0.025)
    top = ss((v.z - EYE_Z - 0.02) / 0.08)
    return NB[i] * (0.006 + (0.024 + 0.016 * top) * g + 0.008 * g * hnoise(v, 24)) + Vector((-0.012, 0, -0.004)) * g


hair, hvids, hverts, hdist = shell("hair", hair_mask, hair_disp, m_hair, subsurf=2,
                                  weight_fn=lambda vids, verts, g: reweight(vids, verts, g, "hair", lambda p: 0.6 * ss((EYE_Z + 0.03 - p.z) / 0.1)))

# brows: heavy, inner ends low (stern)
def brow_m(i):
    v = VB[i]
    for c in (eyeR, eyeL):
        dy = (abs(v.y) - abs(c.y))
        zc = c.z + 0.026 + 0.004 * (dy / 0.02)
        if v.x > c.x - 0.012 and (dy / 0.027) ** 2 + ((v.z - zc) / 0.0085) ** 2 < 1.0 and w("head", i) > 0.9:
            return True
    return False


brows, *_ = shell("brows", [brow_m(i) for i in range(NV)], lambda i, d: NB[i] * (0.002 + 0.006 * ss(d / 0.006)), m_brow, out=0, subsurf=1)


# strands: tapered curved tubes (silhouette), weights blend head -> spring bone
def strands(name, roots, mat, bone, t_fn, seg=6, rings=6, r0=0.012, out=0):
    vs, fs, gw = [], [], []
    for (p, d, L, curl) in roots:
        base = len(vs)
        d = d.normalized()
        side = d.cross(Vector((0, 1, 0)))
        if side.length < 1e-3:
            side = Vector((1, 0, 0))
        side.normalize()
        up = side.cross(d).normalized()
        for r in range(rings + 1):
            t = r / rings
            c = p + d * L * t + Vector((0, 0, -1)) * curl * (L * t) ** 2
            rad = r0 * (1 - t) ** 0.8 + 0.0008
            for k in range(seg):
                a = 2 * math.pi * k / seg
                vs.append(c + (side * math.cos(a) + up * math.sin(a)) * rad)
                gw.append(t_fn(c))
        for r in range(rings):
            for k in range(seg):
                a, b = base + r * seg + k, base + r * seg + (k + 1) % seg
                fs.append([a, b, b + seg, a + seg])
    o = mesh_obj(name, vs, fs, mat, subsurf=1)
    finish(o, out, {"head": [(k, 1 - t) for k, t in enumerate(gw)], bone: [(k, t) for k, t in enumerate(gw) if t > 0]})
    return o


rnd = random.Random(11)
hroots = []
for k in range(0, len(hvids), 1):
    i = hvids[k]
    v = hverts[k]
    if hdist[i] > 0.012 and rnd.random() < 0.05:
        back = ss((HEAD_CX - v.x) / 0.08)
        d = NB[i] * 0.55 + Vector((-0.55, 0, -0.5 - 0.6 * back))
        hroots.append((v - NB[i] * 0.006, d, 0.05 + 0.07 * back + 0.03 * rnd.random(), 4.0))
# a few forelocks falling on the brow
for y in (-0.03, 0.0, 0.035):
    p = Vector((HEAD_CX + 0.06, y, EYE_Z + 0.07))
    hroots.append((p, Vector((0.6, y * 3, -0.8)), 0.055, 3.0))
strands("hair_strands", hroots, m_hair, "hair", lambda c: 0.6 * ss((EYE_Z + 0.03 - c.z) / 0.1), r0=0.022)
broots = []
for k, i in enumerate(bvids):
    v = bverts[k]
    if v.z < CHIN_Z + 0.0 and rnd.random() < 0.2:
        broots.append((v + Vector((0, 0, 0.012)), Vector((0.15, v.y * 2.0, -1.0)), 0.035 + 0.03 * rnd.random(), 2.0))
strands("beard_strands", broots, m_hair, "beard", lambda c: ss((CHIN_Z + 0.01 - c.z) / 0.09), r0=0.018)


# ---------------- props ----------------
def part(o, bone, outline=OUT_S):
    rig.attach(o, bone)
    nc.add_rest(o)
    if outline:
        nc.add_outline(o, outline)
        parts.append(o)
    return o


# amulet on a cord (wooden carved ring, glowing core) on the swinging 'amul' bone
cd = (AMULET - Vector((NECK.x + 0.075, 0, NECK.z - 0.075)))
part(nc.capsule("cord_f", P(Vector((NECK.x + 0.075, 0.03, NECK.z - 0.075))), P(AMULET + Vector((0, 0.01, 0.04))), 0.005, 0.005, m_cord), "amul", 0)
part(nc.capsule("cord_f2", P(Vector((NECK.x + 0.075, -0.035, NECK.z - 0.075))), P(AMULET + Vector((0, -0.01, 0.04))), 0.005, 0.005, m_cord), "amul", 0)
part(nc.torus("amulet", P(AMULET), 0.04, 0.014, m_wood, rot=(0, math.radians(90), 0)), "amul")
part(nc.ellip("amulet_core", P(AMULET + Vector((0.006, 0, 0))), (0.012, 0.03, 0.03), m_glow, seg=12), "amul", 0)
for k in range(6):   # carved notches
    a = 2 * math.pi * k / 6
    part(nc.ellip("notch%d" % k, P(AMULET + Vector((0.012, 0.04 * math.cos(a), 0.04 * math.sin(a)))), (0.006, 0.008, 0.008), m_cord, seg=8), "amul", 0)
# red thread of Mokosh on the near wrist
wc = J["lowerarm01.R"].lerp(J["wrist.R"], 0.9)
wrad = sum(math.hypot(VB[i].x - wc.x, VB[i].y - wc.y) for i in range(NV) if abs(VB[i].z - wc.z) < 0.008 and w("foR", i) + w("haR", i) > 0.8)
cnt = sum(1 for i in range(NV) if abs(VB[i].z - wc.z) < 0.008 and w("foR", i) + w("haR", i) > 0.8)
wrad = wrad / max(1, cnt)
part(nc.torus("thread", P(wc), wrad + 0.004, 0.006, m_thread, seg=20, segr=6), "foR", 0.006)
part(nc.torus("thread2", P(wc - Vector((0, 0, 0.012))), wrad + 0.002, 0.005, m_thread, seg=20, segr=6), "foR", 0.005)
# rope belt end with a knot, hanging (spring bone 'belt')
part(nc.ellip("belt_knot", P(BELT_END), (0.03, 0.026, 0.026), m_rope), "belt")
part(nc.capsule("belt_end1", P(BELT_END), P(BELT_END + Vector((0.012, -0.012, -0.17))), 0.012, 0.006, m_rope, bend=0.01), "belt")
part(nc.capsule("belt_end2", P(BELT_END), P(BELT_END + Vector((0.025, 0.01, -0.13))), 0.011, 0.006, m_rope, bend=-0.01), "belt")
# knotted stick through the fist
S0 = gR - SDIR * 0.16
S1 = gR + SDIR * 0.98
part(nc.capsule("stick", P(S0), P(S1), 0.026, 0.019, m_stick, bend=0.015), "stick", 0.02)
for i, t in enumerate((0.3, 0.62, 0.86)):
    q = gR + SDIR * t + Vector((0, 0, 0.008 * (i % 2)))
    part(nc.ellip("knot%d" % i, P(q), (0.03, 0.028, 0.026), m_stick, seg=12), "stick", 0.02)

# smear crescents (pale gold, alpha grows toward the leading edge); armature space
smears = {}
m_smear = nc.fade_mat("smear", "#FFE9B8", strength=1.6, alpha=0.9, power=1.3)
DZS = J["upperarm01.R"].z - 1.36
for nm, c, ri, ro, a0, a1 in (
        ("s1", (0.12, 1.22), 0.55, 1.2, 150, -15),
        ("s1b", (0.12, 1.22), 0.65, 1.2, 60, -40),
        ("s2", (0.12, 1.12), 0.6, 1.18, 245, 425),
        ("s2b", (0.12, 1.12), 0.7, 1.18, 330, 450),
        ("s3", (0.2, 1.05), 0.55, 1.35, 160, -70),
        ("s3b", (0.2, 1.05), 0.75, 1.35, 40, -75),
        ("su", (0.0, 1.3), 0.55, 1.15, -10, 160),
        ("sd", (0.1, 0.9), 0.3, 1.0, -60, -120)):
    o = nc.arc_mesh("smear_" + nm, (c[0], c[1] + DZS), ri, ro, a0, a1, m_smear)
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
        # Dead Cells run: deep lean, big counter-swing, the stick rides the near
        # arm (local angle, so it swings with it) held forward-diagonal.
        pose = {"ik:R": foot(p), "ik:L": foot(p + math.pi), "rx": 0.08,
                "rz": -0.1 + 0.07 * abs(math.sin(p)), "hips": 4 * math.cos(p), "spine": -30 + 4 * math.cos(2 * p),
                "head": 18, "upR": -5 + 48 * math.cos(p + math.pi), "foR": 72 + 12 * math.sin(p),
                "upL": 58 * math.cos(p), "foL": 62 + 25 * math.cos(p), "w:stick": None, "stick": -8 - 10 * math.cos(p),
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
nr.render_anims(rig, anims, RAW, smears, parts, "hero", springs=SPRINGS)

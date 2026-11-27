"""Топь Кикиморы backdrop for the art slice (art bible §4.2, §6): three parallax layers
(far: sky, moon, misty tree line; mid: dead trees, carved wooden idols (чуры),
stakes; near: dark trunks, reeds, hanging moss) with water reflections and fog
bands, plus a ground strip and a mossy-log platform texture. Same cel shading
as the characters but no outline (backgrounds stay softer than actors).

Run: xvfb-run -a blender -b --python tools/asset-pipeline/blender/build_swamp_bg.py -- <out_dir> [--small]
Writes bg_far.png (opaque), bg_mid.png, bg_near.png, ground.png, plat.png.
"""
import bpy, sys, os, math, random, time
from mathutils import Matrix
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import navi_common as nc

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = ARGS[0] if ARGS else "/tmp/navi_swamp"
SMALL = "--small" in ARGS
os.makedirs(OUT, exist_ok=True)
PPM = 120.0
SKY_T, SKY_H = "#142220", "#6F9179"
FAR, MID, NEAR = "#3E5A4A", "#24392F", "#121E19"
PLAT, ACCENT = "#4D5F3A", "#B6E36B"


def grad_mat(name, top, bottom):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree; n, l = nt.nodes, nt.links
    n.clear()
    out = n.new("ShaderNodeOutputMaterial")
    uv = n.new("ShaderNodeUVMap")
    sep = n.new("ShaderNodeSeparateXYZ"); l.new(uv.outputs[0], sep.inputs[0])
    mx = n.new("ShaderNodeMixRGB"); l.new(sep.outputs["Y"], mx.inputs[0])
    mx.inputs[1].default_value = nc.hexc(bottom); mx.inputs[2].default_value = nc.hexc(top)
    em = n.new("ShaderNodeEmission"); l.new(mx.outputs[0], em.inputs[0])
    l.new(em.outputs[0], out.inputs[0])
    return m


def setup(w_px, h_px, transparent, center=(0.0, 4.5)):
    sc = nc.reset(transparent=transparent, samples=24)
    sc.world.node_tree.nodes["Background"].inputs[0].default_value = nc.hexc("#40604F")
    sc.world.node_tree.nodes["Background"].inputs[1].default_value = 0.5
    nc.sun((0.3, 1.0, 0.9), 2.4, "#CFE3D0")          # moon, behind: rims
    nc.sun((-0.4, -1.0, 0.6), 1.1, "#B7C9A0", shadow=False)
    cd = bpy.data.cameras.new("Cam"); cd.type = "ORTHO"
    cd.ortho_scale = max(w_px, h_px) / PPM; cd.clip_end = 400
    cam = bpy.data.objects.new("Cam", cd); sc.collection.objects.link(cam)
    cam.location = (center[0], -60, center[1]); cam.rotation_euler = (math.pi / 2, 0, 0)
    sc.camera = cam
    k = 0.5 if SMALL else 1.0
    sc.render.resolution_x, sc.render.resolution_y = int(w_px * k), int(h_px * k)
    return sc


def tree(x, y, z, h, mat, rng, lean=0.0):
    r0 = 0.05 * h + 0.08
    top = (x + lean * h, y, z + h)
    nc.capsule("trunk", (x, y, z - 0.6), top, r0, r0 * 0.25, mat, seg=12, bend=0.15 * h * rng.uniform(-1, 1))
    nc.ellip("roots", (x, y, z - 0.1), (r0 * 2.6, r0 * 1.6, r0 * 1.0), mat, seg=12)
    for i in range(rng.randint(3, 6)):
        t = rng.uniform(0.35, 0.92)
        px, pz = x + lean * h * t, z + h * t
        side = rng.choice((-1, 1))
        L = h * rng.uniform(0.18, 0.38) * (1.1 - t * 0.5)
        a = math.radians(rng.uniform(15, 65))
        ex, ez = px + side * math.cos(a) * L, pz + math.sin(a) * L
        rb = r0 * (1 - t) * 0.6 + 0.02
        nc.capsule("br", (px, y, pz), (ex, y + rng.uniform(-0.3, 0.3), ez), rb, rb * 0.3, mat, seg=8)
        if rng.random() < 0.7:
            a2 = a + math.radians(rng.uniform(-50, 40))
            L2 = L * 0.5
            nc.capsule("tw", (ex, y, ez), (ex + side * math.cos(a2) * L2, y, ez + math.sin(a2) * L2), rb * 0.5, rb * 0.3, mat, seg=6)


def idol(x, y, z, h, wood, dark, tilt=0.0, glow=None):
    r = 0.26
    tx = math.sin(tilt) * h
    nc.capsule("pillar", (x, y, z - 0.5), (x + tx, y, z + h * 0.72), r, r * 0.95, wood, seg=14, squash=(1, 1.05))
    for k in (0.15, 0.32, 0.62):
        nc.torus("ring", (x + tx * k, y, z + h * 0.72 * k), r * 1.02, 0.035, dark, rot=(0, tilt, 0))
    hx, hz = x + tx * 1.05, z + h * 0.8
    nc.ellip("headblock", (hx, y, hz), (r * 1.25, r * 1.2, h * 0.16), wood, rot=(0, tilt, 0), seg=16)
    nc.cone("cap", (hx, y, hz + h * 0.12), (hx + tx * 0.08, y, hz + h * 0.32), r * 1.35, dark, seg=14)
    for s in (-1, 1):
        o = nc.ellip("eye", (hx + s * 0.1, y - r * 1.12, hz + 0.05), (0.05, 0.03, 0.035), glow or dark, seg=10)
    nc.ellip("nose", (hx, y - r * 1.18, hz - 0.04), (0.035, 0.05, 0.08), wood, seg=10)
    nc.ellip("mouth", (hx, y - r * 1.12, hz - 0.17), (0.11, 0.03, 0.022), dark, seg=10)


def reflect(objs, wl):
    M = Matrix.Translation((0, 0, 2 * wl)) @ Matrix.Diagonal((1, 1, -1, 1))
    for o in objs:
        if o.type != "MESH":
            continue
        r = o.copy()
        r.matrix_world = M @ o.matrix_world
        bpy.context.scene.collection.objects.link(r)


def meshes():
    return [o for o in bpy.context.scene.objects if o.type == "MESH"]


def water(x0, x1, wl, col, alpha, y):
    m = nc.fade_mat("water", col, 1.0, alpha=alpha, axis="v", power=0.6, invert=True)
    nc.plane("water", x0, x1, wl - 6, wl + 0.02, y, m)
    hl = nc.fade_mat("waterline", "#9FC2A8", 1.0, alpha=0.35, axis="v", power=3.0)
    nc.plane("shine", x0, x1, wl - 0.12, wl + 0.01, y - 0.5, hl)


def fog(x0, x1, z0, z1, col, alpha, y, power=1.6):
    m = nc.fade_mat("fog", col, 1.0, alpha=alpha, axis="v", power=power, invert=True)
    nc.plane("fog", x0, x1, z0, z1, y, m)


def render(name):
    sc = bpy.context.scene
    sc.render.filepath = os.path.join(OUT, name)
    t = time.time()
    bpy.ops.render.render(write_still=True)
    print("LAYER", name, round(time.time() - t, 1), "s")


rng = random.Random(5)
# ---------- far ----------
W = 2560
setup(W, 1080, False)
hw = W / PPM / 2
nc.plane("sky", -hw - 1, hw + 1, -1, 10, 80, grad_mat("sky", SKY_T, SKY_H))
moon = nc.glow("moon", "#C9D8B8", 0.95)
nc.ellip("moon", (4.5, 70, 7.0), (0.75, 0.1, 0.75), moon)
for i, (r, a) in enumerate(((1.4, 0.18), (2.4, 0.09), (4.0, 0.05))):
    nc.ellip("halo%d" % i, (4.5, 72 + i, 7.0), (r, 0.05, r), nc.fade_mat("halo", "#CFE3C0", 1.0, alpha=a, axis="v", power=0.0))
farm = nc.toon("far_tree", "#2E4A3E", fog="#6A8C76", fog_k=0.62, rim="#DDEED0", rim_k=0.4)
hill = nc.toon("far_hill", "#2A4236", fog="#6A8C76", fog_k=0.55, rim_k=0.0)
nc.ellip("hill", (-6, 50, 3.4), (9, 2, 1.0), hill); nc.ellip("hill2", (7, 50, 3.4), (8, 2, 0.8), hill)
x = -hw
while x < hw:
    tree(x, 45 + rng.uniform(-2, 2), 3.6, rng.uniform(2.4, 4.6), farm, rng, lean=rng.uniform(-0.1, 0.1))
    x += rng.uniform(0.7, 1.8)
reflect(meshes()[1:], 3.5)
water(-hw - 1, hw + 1, 3.5, "#28433A", 0.78, 30)
fog(-hw - 1, hw + 1, 2.6, 5.4, "#8FB09A", 0.55, 25)
render("bg_far.png")

# ---------- mid ----------
W = 3200
setup(W, 1080, True)
hw = W / PPM / 2
midm = nc.toon("mid_tree", "#2F4A3A", fog="#3E5A4A", fog_k=0.38, rim="#CFE8C0", rim_k=0.55)
wood = nc.toon("idol_wood", "#5A5040", fog="#3E5A4A", fog_k=0.3, rim="#E8D8A8", rim_k=0.5)
dark = nc.toon("idol_dark", "#1E2A24", fog="#3E5A4A", fog_k=0.25, rim_k=0.1)
bank = nc.toon("mid_bank", "#30482F", fog="#3E5A4A", fog_k=0.3, rim="#B6E36B", rim_k=0.35)
gl = nc.glow("rot_glow", ACCENT, 2.2)
for i in range(7):
    tree(-hw + 1.5 + i * (2 * hw - 3) / 6 + rng.uniform(-0.8, 0.8), 20, 3.2, rng.uniform(4.0, 6.5), midm, rng, lean=rng.uniform(-0.12, 0.12))
for x, h, t, g in ((-8.5, 2.6, 0.08, False), (-1.2, 3.1, -0.05, True), (6.0, 2.3, 0.18, False), (10.5, 2.8, -0.1, True)):
    idol(x, 16, 3.15, h, wood, dark, tilt=t, glow=gl if g else None)
for i in range(14):
    sx = -hw + rng.uniform(0, 2 * hw)
    nc.capsule("stake", (sx, 17, 2.9), (sx + rng.uniform(-0.25, 0.25), 17, 3.3 + rng.uniform(0.3, 1.2)), 0.07, 0.04, dark, seg=8)
x = -hw - 1
while x < hw + 1:
    nc.ellip("mound", (x, 18, 3.05), (rng.uniform(1.2, 2.4), 1.0, rng.uniform(0.25, 0.45)), bank, seg=16)
    if rng.random() < 0.5:
        nc.ellip("rot", (x + rng.uniform(-0.6, 0.6), 17, 3.25), (0.06, 0.06, 0.05), gl, seg=8)
    x += rng.uniform(1.2, 2.2)
reflect(meshes(), 3.0)
water(-hw - 1, hw + 1, 3.0, "#1D3029", 0.72, 10)
fog(-hw - 1, hw + 1, 2.4, 4.6, "#7FA08A", 0.4, 8)
render("bg_mid.png")

# ---------- near ----------
W = 3840
setup(W, 1080, True)
hw = W / PPM / 2
nearm = nc.toon("near", "#1C2C24", fog="#121E19", fog_k=0.15, rim="#B6E36B", rim_k=0.45)
reed = nc.toon("reed", "#2A3A26", fog="#121E19", fog_k=0.1, rim="#C8E890", rim_k=0.5)
for x, h, ln in ((-14.5, 9.5, 0.05), (-5.5, 8.0, -0.06), (8.0, 10.0, 0.04), (14.5, 7.5, -0.1)):
    tree(x, 4, 2.6, h, nearm, rng, lean=ln)
for i in range(46):
    cx = -hw + rng.uniform(0, 2 * hw)
    for k in range(rng.randint(3, 7)):
        bx = cx + rng.uniform(-0.3, 0.3)
        nc.capsule("reed", (bx, 3, 2.4), (bx + rng.uniform(-0.4, 0.4), 3, 2.9 + rng.uniform(0.4, 1.6)), 0.03, 0.006, reed, seg=6)
for i in range(10):   # hanging moss from the top edge
    mx = -hw + rng.uniform(0, 2 * hw)
    nc.capsule("moss", (mx, 5, 9.6), (mx + rng.uniform(-0.2, 0.2), 5, 9.6 - rng.uniform(0.8, 2.2)), 0.08, 0.015, nearm, seg=8)
nc.ellip("bankn", (0, 4, 2.2), (hw + 2, 1.5, 0.6), nearm, seg=32)
render("bg_near.png")

# ---------- ground strip + platform ----------
setup(3072, 420, True, center=(0.0, -0.75))
gm = nc.toon("ground", "#2A3826", rim="#B6E36B", rim_k=0.4, shadow_tint="#4A5A70")
mossm = nc.toon("moss_top", PLAT, rim="#D8F0A0", rim_k=0.5)
mud = nc.toon("mud", "#1A241D", rim_k=0.0)
hw = 3072 / PPM / 2
nc.plane("mudplane", -hw - 1, hw + 1, -4, -0.1, 2, grad_mat("mudg", "#22301F", "#101712"))
x = -hw - 0.5
while x < hw + 0.5:
    nc.ellip("lip", (x, 0.5, -0.12), (rng.uniform(0.6, 1.2), 0.6, 0.18), mossm, seg=14)
    if rng.random() < 0.6:
        nc.ellip("stone", (x + 0.3, 0, -0.6 - rng.uniform(0, 0.9)), (rng.uniform(0.15, 0.35),) * 2 + (rng.uniform(0.1, 0.22),), gm, seg=12)
    if rng.random() < 0.5:
        for k in range(4):
            gx = x + rng.uniform(-0.4, 0.4)
            nc.capsule("grass", (gx, 0.2, -0.05), (gx + rng.uniform(-0.15, 0.15), 0.2, 0.12 + rng.uniform(0, 0.2)), 0.025, 0.005, mossm, seg=6)
    if rng.random() < 0.35:
        nc.capsule("root", (x, -0.1, -0.15), (x + rng.uniform(-0.8, 0.8), -0.1, -1.2), 0.06, 0.02, mud, seg=8, bend=0.2)
    x += rng.uniform(0.5, 0.9)
render("ground.png")
setup(512, 96, True, center=(0.0, 0.0))
log = nc.toon("log", "#5A4632", rim="#E8C890", rim_k=0.4)
mossm = nc.toon("moss_top", PLAT, rim="#D8F0A0", rim_k=0.5)
nc.capsule("log", (-2.2, 0, -0.05), (2.2, 0, -0.05), 0.16, 0.15, log, seg=16, squash=(1, 1))
for i in range(9):
    lx = -2 + i * 0.5
    nc.ellip("lmoss", (lx, -0.02, 0.09), (rng.uniform(0.2, 0.35), 0.15, 0.06), mossm, seg=12)
render("plat.png")

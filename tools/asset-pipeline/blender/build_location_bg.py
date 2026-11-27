"""Backdrops of the other places (art bible §4.2, §6), in the style of build_swamp_bg.py:
three parallax layers per place (far: opaque sky and distant silhouettes with the
broken Калинов мост; mid: trees / houses with details in the place's colour;
near: darkest silhouettes at the frame edges), soft cel shading, no outline.
Every layer tiles horizontally: objects crossing the tile edge are repeated on
the other side, so Parallax2D's repeat has no seam.

  forest  Тёмный бор: huge spruces, mossy trunks, hollows with Лихо's eyes, fog, light shafts
  frost   Царство Морены: birches under snow, ice crags, frozen river, ice-bound idols
  base    Застава: log houses with lit windows, palisade, chimney smoke, Капище, torches, stars

Run (one Blender call renders the three layers of one place):
  xvfb-run -a blender -b --python tools/asset-pipeline/blender/build_location_bg.py -- <place> <out_dir> [--small]
Writes bg_far.png (opaque), bg_mid.png, bg_near.png at 2560/3200/3840 x 1080 (1.5x of
the on-screen size, so visuals.json tex_scale 0.6667, tex_y -485: z=2.95 m is the floor line).
Convert to WebP with tools/asset-pipeline/blender/to_webp.py.
"""
import bpy, bmesh, sys, os, math, random, time
from mathutils import Matrix, Vector, Euler
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import navi_common as nc

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
PLACE = ARGS[0] if ARGS else "forest"
OUT = ARGS[1] if len(ARGS) > 1 else "/tmp/navi_" + PLACE
SMALL = "--small" in ARGS
os.makedirs(OUT, exist_ok=True)
PPM = 120.0
G = 2.95          # floor line in the image (ground_y in game)


# ---------------- helpers ----------------
def grad_mat(name, top, bottom, power=1.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree; n, l = nt.nodes, nt.links
    n.clear()
    out = n.new("ShaderNodeOutputMaterial")
    uv = n.new("ShaderNodeUVMap")
    sep = n.new("ShaderNodeSeparateXYZ"); l.new(uv.outputs[0], sep.inputs[0])
    pw = n.new("ShaderNodeMath"); pw.operation = "POWER"
    l.new(sep.outputs["Y"], pw.inputs[0]); pw.inputs[1].default_value = power
    mx = n.new("ShaderNodeMixRGB"); l.new(pw.outputs[0], mx.inputs[0])
    mx.inputs[1].default_value = nc.hexc(bottom); mx.inputs[2].default_value = nc.hexc(top)
    em = n.new("ShaderNodeEmission"); l.new(mx.outputs[0], em.inputs[0])
    l.new(em.outputs[0], out.inputs[0])
    return m


def setup(w_px, transparent, world_col, lights):
    sc = nc.reset(transparent=transparent, samples=24)
    sc.world.node_tree.nodes["Background"].inputs[0].default_value = nc.hexc(world_col)
    sc.world.node_tree.nodes["Background"].inputs[1].default_value = 0.5
    for d, s, c, sh in lights:
        nc.sun(d, s, c, shadow=sh)
    cd = bpy.data.cameras.new("Cam"); cd.type = "ORTHO"
    cd.ortho_scale = w_px / PPM; cd.clip_end = 400
    cam = bpy.data.objects.new("Cam", cd); sc.collection.objects.link(cam)
    cam.location = (0.0, -60, 4.5); cam.rotation_euler = (math.pi / 2, 0, 0)
    sc.camera = cam
    k = 0.5 if SMALL else 1.0
    sc.render.resolution_x, sc.render.resolution_y = int(w_px * k), int(1080 * k)
    return w_px / PPM / 2


def alpha_mat(name, col, alpha, strength=1.0):
    return nc.fade_mat(name, col, strength, alpha=alpha, axis="v", power=0.0)


def quad(name, pts, y, mat):
    """Quad through 4 (x, z) points: bottom-left, bottom-right, top-right, top-left.
    UV u runs bottom (0) to top (1), v across: fade_mat axis u gives a soft shaft."""
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new("UVMap")
    vs = [bm.verts.new((p[0], y, p[1])) for p in pts]
    f = bm.faces.new(vs)
    for loop, uv in zip(f.loops, ((0, 0), (0, 1), (1, 1), (1, 0))):
        loop[uvl].uv = uv
    f.normal_update()
    if f.normal.y > 0:
        f.normal_flip()
    return nc._obj(name, bm, mat)


def box(name, c, size, mat, rot_y=0.0):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    M = Matrix.Translation(Vector(c)) @ Matrix.Rotation(rot_y, 4, "Y") @ Matrix.Diagonal((size[0], size[1], size[2], 1))
    bmesh.ops.transform(bm, matrix=M, verts=bm.verts)
    o = nc._obj(name, bm, mat)
    for p in o.data.polygons:
        p.use_smooth = False
    return o


def flat(o):
    for p in o.data.polygons:
        p.use_smooth = False
    return o


def fog(hw, z0, z1, col, alpha, y, power=1.6):
    nc.plane("fog", -hw - 1, hw + 1, z0, z1, y, nc.fade_mat("fog", col, 1.0, alpha=alpha, axis="v", power=power, invert=True))


def band(hw, z0, z1, col, alpha, y):
    """Soft horizontal band, densest in the middle (two stacked fades)."""
    zm = (z0 + z1) / 2
    nc.plane("bandlo", -hw - 1, hw + 1, z0, zm, y, nc.fade_mat("band", col, 1.0, alpha=alpha, axis="v", power=1.2))
    nc.plane("bandhi", -hw - 1, hw + 1, zm, z1, y, nc.fade_mat("band", col, 1.0, alpha=alpha, axis="v", power=1.2, invert=True))


def radial_mat(col, alpha, power=1.8):
    """Emission whose alpha falls off radially from the quad's UV centre (soft glow)."""
    m = bpy.data.materials.new("radial")
    m.use_nodes = True
    m.blend_method = "BLEND"; m.shadow_method = "NONE"; m.show_transparent_back = True
    nt = m.node_tree; n, l = nt.nodes, nt.links
    n.clear()
    out = n.new("ShaderNodeOutputMaterial")
    uv = n.new("ShaderNodeUVMap")
    d = n.new("ShaderNodeVectorMath"); d.operation = "DISTANCE"
    l.new(uv.outputs[0], d.inputs[0]); d.inputs[1].default_value = (0.5, 0.5, 0.0)
    a = n.new("ShaderNodeMath"); a.operation = "MULTIPLY_ADD"
    l.new(d.outputs["Value"], a.inputs[0]); a.inputs[1].default_value = -2.0; a.inputs[2].default_value = 1.0
    a.use_clamp = True
    pw = n.new("ShaderNodeMath"); pw.operation = "POWER"
    l.new(a.outputs[0], pw.inputs[0]); pw.inputs[1].default_value = power
    k = n.new("ShaderNodeMath"); k.operation = "MULTIPLY"
    l.new(pw.outputs[0], k.inputs[0]); k.inputs[1].default_value = alpha
    em = n.new("ShaderNodeEmission"); em.inputs[0].default_value = nc.hexc(col)
    tr = n.new("ShaderNodeBsdfTransparent")
    ms = n.new("ShaderNodeMixShader")
    l.new(k.outputs[0], ms.inputs[0]); l.new(tr.outputs[0], ms.inputs[1]); l.new(em.outputs[0], ms.inputs[2])
    l.new(ms.outputs[0], out.inputs[0])
    return m


def halo(x, y, z, r, col, a, power=1.8):
    quad("halo", ((x - r, z - r), (x + r, z - r), (x + r, z + r), (x - r, z + r)), y, radial_mat(col, a, power))


def stars(hw, rng, n, z0, z1, y=90, col="#EDE6F2"):
    for i in range(n):
        s = rng.uniform(0.012, 0.035) * (2.2 if rng.random() < 0.06 else 1.0)
        nc.ellip("star", (rng.uniform(-hw, hw), y, rng.uniform(z0, z1)), (s, 0.01, s), nc.glow("star", col, rng.uniform(0.4, 1.0)), seg=6)


def rays(hw, rng, n, col, alpha, y, x_list=None):
    for i in range(n):
        x = x_list[i] if x_list else rng.uniform(-hw + 2, hw - 2)
        w0, w1, sl = rng.uniform(0.5, 0.9), rng.uniform(1.6, 2.6), rng.uniform(1.8, 3.2)
        quad("ray", ((x + sl - w1 / 2, G - 0.4), (x + sl + w1 / 2, G - 0.4), (x + w0 / 2, 9.5), (x - w0 / 2, 9.5)), y,
             nc.fade_mat("ray", col, 1.0, alpha=alpha, axis="u", power=0.8))


def spruce(x, y, z, h, mat, rng, trunk=None, r=None, droop=True):
    r = r or h * 0.24
    if trunk:
        nc.capsule("trunk", (x, y, z - 0.6), (x, y, z + h * 0.92), h * 0.035 + 0.05, 0.03, trunk, seg=10)
    n = max(5, int(h * 1.5))
    zb = z + h * 0.18
    for i in range(n):
        t = i / n
        rr = r * (1.0 - t) ** 0.85 + 0.12
        th = (h * 0.85) / n * 1.9
        z0 = zb + t * h * 0.78
        dx = rng.uniform(-0.06, 0.06) * h * 0.1
        flat(nc.cone("tier", (x + dx, y + 0.02 * i, z0), (x + dx * 0.5, y + 0.02 * i, z0 + th), rr, mat, seg=rng.choice((7, 8, 9))))
        if droop and rr > 0.35:
            for s in (-1, 1):
                ex = x + s * rr * rng.uniform(1.0, 1.25)
                flat(nc.cone("tip", (x + s * rr * 0.4, y - 0.05, z0 + th * 0.35), (ex, y - 0.05, z0 - th * 0.12), th * 0.22, mat, seg=5))
    nc.cone("top", (x, y, zb + h * 0.78), (x, y, z + h * 1.02), r * 0.12 + 0.06, mat, seg=6)


def bare_tree(x, y, z, h, mat, rng, lean=0.0, r0=None, nbr=(4, 7), snow=None, marks=None):
    r0 = r0 or 0.045 * h + 0.06
    nc.capsule("trunk", (x, y, z - 0.6), (x + lean * h, y, z + h), r0, r0 * 0.2, mat, seg=12, bend=0.1 * h * rng.uniform(-1, 1))
    if marks:
        for k in range(int(h * 3)):
            mz = z + rng.uniform(0.1, 0.85) * h
            mx = x + lean * (mz - z)
            nc.ellip("mark", (mx + rng.uniform(-0.3, 0.3) * r0, y - r0 * 0.9, mz), (r0 * rng.uniform(0.3, 0.7), 0.03, rng.uniform(0.02, 0.05)), marks, seg=8)
    for i in range(rng.randint(*nbr)):
        t = rng.uniform(0.35, 0.9)
        px, pz = x + lean * h * t, z + h * t
        side = rng.choice((-1, 1))
        L = h * rng.uniform(0.15, 0.32) * (1.1 - t * 0.5)
        a = math.radians(rng.uniform(10, 55))
        ex, ez = px + side * math.cos(a) * L, pz + math.sin(a) * L
        rb = r0 * (1 - t) * 0.55 + 0.02
        nc.capsule("br", (px, y, pz), (ex, y + rng.uniform(-0.2, 0.2), ez), rb, rb * 0.3, mat, seg=8)
        for k in range(2):
            a2 = a + math.radians(rng.uniform(-60, 30))
            L2 = L * rng.uniform(0.3, 0.55)
            tx, tz = px + side * math.cos(a) * L * (0.5 + 0.4 * k), pz + math.sin(a) * L * (0.5 + 0.4 * k)
            nc.capsule("tw", (tx, y, tz), (tx + side * math.cos(a2) * L2, y, tz + math.sin(a2) * L2), rb * 0.5, rb * 0.2, mat, seg=6)
        if snow is not None:
            mxp, mzp = (px + ex) / 2, (pz + ez) / 2
            nc.capsule("snowbr", (px + side * 0.1 * L, y - 0.04, pz + rb * 0.9), (px + side * 0.85 * L * math.cos(a), y - 0.04, pz + 0.85 * L * math.sin(a) + rb * 0.6), rb * 1.1 + 0.03, 0.02, snow, seg=8, squash=(1, 0.8))


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
        nc.ellip("eye", (hx + s * 0.1, y - r * 1.12, hz + 0.05), (0.05, 0.03, 0.035), glow or dark, seg=10)
    nc.ellip("nose", (hx, y - r * 1.18, hz - 0.04), (0.035, 0.05, 0.08), wood, seg=10)
    nc.ellip("mouth", (hx, y - r * 1.12, hz - 0.17), (0.11, 0.03, 0.022), dark, seg=10)


def bridge(x0, x1, gap0, gap1, zd, y, mat, rng):
    """Калинов мост: arched stone-and-timber bridge, broken between gap0 and gap1."""
    for a, b in ((x0, gap0), (gap1, x1)):
        nc.capsule("deck", (a, y, zd), (b, y, zd), 0.16, 0.16, mat, seg=8, squash=(1, 0.6))
        for px in [a + (b - a) * k / 6 for k in range(7)]:
            nc.capsule("rail", (px, y, zd), (px, y, zd + 0.35), 0.035, 0.03, mat, seg=6)
        nc.capsule("hand", (a, y, zd + 0.33), (b, y, zd + 0.33), 0.025, 0.025, mat, seg=6)
    span = (x1 - x0) / 4
    for k in range(4):
        cx = x0 + span * (k + 0.5)
        if gap0 - 0.2 < cx < gap1 + 0.2:
            continue
        R = span * 0.48
        for j in range(10):              # semicircular arch under the deck
            a0, a1 = math.pi * j / 10, math.pi * (j + 1) / 10
            nc.capsule("arch", (cx + R * math.cos(a0), y, zd - 0.05 - R + R * math.sin(a0) * 0.9),
                       (cx + R * math.cos(a1), y, zd - 0.05 - R + R * math.sin(a1) * 0.9), 0.09, 0.09, mat, seg=6)
        nc.capsule("pier", (x0 + span * k, y, zd - 3.5), (x0 + span * k, y, zd), 0.16, 0.14, mat, seg=8)
    nc.capsule("pier", (x1, y, zd - 3.5), (x1, y, zd), 0.16, 0.14, mat, seg=8)
    for gx, s in ((gap0, 1), (gap1, -1)):     # splintered ends
        for k in range(3):
            nc.cone("splinter", (gx, y, zd + rng.uniform(-0.1, 0.1)), (gx + s * rng.uniform(0.15, 0.4), y, zd - rng.uniform(0.2, 0.7)), 0.05, mat, seg=5)


def meshes():
    return [o for o in bpy.context.scene.objects if o.type == "MESH"]


def wrap(hw):
    """Repeat objects that cross a tile edge on the other side (seamless tiling)."""
    for o in meshes():
        xs = [(o.matrix_world @ Vector(c)).x for c in o.bound_box]
        lo, hi = min(xs), max(xs)
        if hi - lo >= 2 * hw:
            continue
        for crosses, sh in ((lo < -hw, 2 * hw), (hi > hw, -2 * hw)):
            if crosses:
                c = o.copy()
                c.location.x += sh
                bpy.context.scene.collection.objects.link(c)


def render(name, hw):
    wrap(hw)
    sc = bpy.context.scene
    sc.render.filepath = os.path.join(OUT, name)
    t = time.time()
    bpy.ops.render.render(write_still=True)
    print("LAYER", PLACE, name, round(time.time() - t, 1), "s", len(meshes()), "meshes")


# ---------------- Тёмный бор ----------------
def forest():
    rng = random.Random(21)
    MOON = ((0.3, 1.0, 0.9), 2.2, "#B8CCEE", True)
    FILL = ((-0.4, -1.0, 0.5), 0.9, "#8C9CC0", False)
    # far
    hw = setup(2560, False, "#2E4466", [MOON, FILL])
    nc.plane("sky", -hw - 1, hw + 1, -1, 10, 80, grad_mat("sky", "#0E1628", "#4A6690", 0.8))
    stars(hw, rng, 70, 5.8, 8.8)
    nc.ellip("moon", (5.5, 70, 7.3), (0.62, 0.1, 0.62), nc.glow("moon", "#DCE6F4", 1.0))
    halo(5.5, 72, 7.3, 3.6, "#AFC4E8", 0.4)
    hill = nc.toon("hill", "#2A3D5C", fog="#4A6690", fog_k=0.5, rim_k=0.0)
    for hx, hr, hz in ((-8, 7, 0.9), (2, 6, 0.7), (10, 7, 1.1)):
        nc.ellip("hill", (hx, 60, 3.6), (hr, 2, hz), hill, seg=24)
    brm = nc.toon("bridge", "#23365A", fog="#4A6690", fog_k=0.45, rim="#AFC4E8", rim_k=0.3)
    bridge(-7.5, 1.5, -3.6, -2.2, 5.0, 55, brm, rng)
    halo(-2.9, 57, 4.1, 1.5, "#FF8A3D", 0.3)      # the fire river glows through the gap
    farm = nc.toon("far_spr", "#22365A", fog="#4A6690", fog_k=0.55, rim="#AFC4E8", rim_k=0.25)
    x = -hw
    while x < hw:
        spruce(x, 45 + rng.uniform(-2, 2), 3.3, rng.uniform(1.4, 3.2), farm, rng, droop=False)
        x += rng.uniform(0.45, 1.0)
    fog(hw, 2.4, 4.6, "#5A7AA0", 0.6, 42)
    farm2 = nc.toon("far_spr2", "#1B2A44", fog="#3E5878", fog_k=0.4, rim="#AFC4E8", rim_k=0.3)
    x = -hw + 0.3
    while x < hw:
        spruce(x, 35, 3.0, rng.uniform(2.4, 4.2), farm2, rng, droop=False)
        x += rng.uniform(1.0, 2.2)
    fog(hw, 2.2, 3.8, "#4A6690", 0.55, 30)
    render("bg_far.png", hw)

    # mid
    hw = setup(3200, True, "#2E4466", [MOON, FILL])
    sprm = nc.toon("mid_spr", "#16233A", fog="#2E4466", fog_k=0.3, rim="#9FB8E0", rim_k=0.45)
    trm = nc.toon("mid_trunk", "#2A2630", fog="#2E4466", fog_k=0.3, rim="#9FB8E0", rim_k=0.4)
    moss = nc.toon("mid_moss", "#4A5A34", fog="#2E4466", fog_k=0.3, rim="#A8B868", rim_k=0.6)
    dark = nc.toon("hollow", "#07090F", rim_k=0.0)
    eye = nc.glow("eye", "#FF8A3D", 3.0)
    xs = [-hw + 1.2 + i * (2 * hw - 2.4) / 6 + rng.uniform(-0.7, 0.7) for i in range(7)]
    for i, x in enumerate(xs):
        if i in (2, 5):
            continue
        spruce(x, 20, G, rng.uniform(4.6, 5.6), sprm, rng, trunk=trm)
    rays(hw, rng, 4, "#9FB8E0", 0.16, 22, x_list=[xs[0] + 1.5, xs[2] - 0.5, xs[4] + 1.0, xs[6] - 1.0])
    for x in (xs[2], xs[5]):          # old broad trunks with hollows and Лихо's eyes
        r0 = 0.55
        nc.capsule("old", (x, 18, G - 0.6), (x + 0.2, 18, 9.8), r0, r0 * 0.7, trm, seg=16, bend=0.25)
        for k in range(5):
            nc.capsule("root", (x, 18, G + 0.2), (x + rng.choice((-1, 1)) * rng.uniform(0.9, 1.6), 17.6, G - 0.2), 0.18, 0.05, trm, seg=8, bend=0.15)
        for k in range(14):
            mz = G + rng.uniform(0.0, 1.0) ** 2.2 * 3.0
            nc.ellip("moss", (x - 0.3 + rng.uniform(-0.2, 0.15), 17.5, mz), (rng.uniform(0.06, 0.14), 0.2, rng.uniform(0.04, 0.08)), moss, seg=8)
        hz = G + rng.uniform(1.6, 2.6)
        nc.ellip("hollow", (x + 0.05, 17.42, hz), (0.24, 0.1, 0.36), dark, seg=14)
        for s in (-1, 1):
            nc.ellip("eye", (x + 0.05 + s * 0.075, 17.3, hz + 0.06), (0.04, 0.02, 0.022), eye, seg=8)
        halo(x + 0.05, 17.35, hz + 0.05, 0.6, "#FF8A3D", 0.35)
        nc.capsule("limb", (x + 0.1, 18, 6.8), (x + 1.8, 18.2, 7.6), 0.16, 0.05, trm, seg=8, bend=0.2)
    for i in range(3):               # eyes in the dark between trees
        ex = rng.uniform(-hw, hw); ez = G + rng.uniform(0.6, 1.4)
        for s in (-1, 1):
            nc.ellip("eye2", (ex + s * 0.07, 16.5, ez), (0.03, 0.02, 0.018), nc.glow("eye2", "#FF8A3D", 1.6), seg=8)
    bank = nc.toon("mid_bank", "#1A2438", fog="#2E4466", fog_k=0.25, rim="#8A9A52", rim_k=0.35)
    x = -hw - 1
    while x < hw + 1:
        nc.ellip("mound", (x, 19, G - 0.1), (rng.uniform(1.2, 2.4), 1.0, rng.uniform(0.25, 0.5)), bank, seg=16)
        for k in range(rng.randint(0, 4)):   # ferns
            fx = x + rng.uniform(-0.8, 0.8)
            for a in (-55, -25, 0, 25, 55):
                aa = math.radians(a + rng.uniform(-10, 10))
                L = rng.uniform(0.35, 0.6)
                nc.capsule("fern", (fx, 17, G), (fx + math.sin(aa) * L, 17, G + math.cos(aa) * L * 0.8), 0.04, 0.008, bank, seg=5, bend=0.05)
        x += rng.uniform(1.0, 2.0)
    band(hw, G - 0.6, G + 1.6, "#4A6690", 0.35, 15)
    render("bg_mid.png", hw)

    # near
    hw = setup(3840, True, "#2E4466", [MOON, FILL])
    nm = nc.toon("near", "#141C2C", fog="#0F1626", fog_k=0.2, rim="#5A6E92", rim_k=0.5)
    mossn = nc.toon("near_moss", "#33422A", fog="#0F1626", fog_k=0.15, rim="#A8B868", rim_k=0.3)
    needle = nc.toon("near_needle", "#0F1626", rim="#5A6E92", rim_k=0.35)
    for x, r0, ln in ((-14.0, 0.85, 0.02), (-4.8, 0.6, -0.03), (6.5, 0.95, 0.02), (14.6, 0.55, -0.04)):
        nc.capsule("trunk", (x, 4, G - 0.8), (x + ln * 8, 4, 10.5), r0, r0 * 0.75, nm, seg=18, bend=0.2)
        for k in range(6):
            s = rng.choice((-1, 1))
            nc.capsule("root", (x, 4, G + 0.3), (x + s * rng.uniform(1.0, 2.2), 3.6, G - 0.3), r0 * 0.35, 0.05, nm, seg=8, bend=0.2)
        for k in range(14):           # moss at the roots, on the shaded side
            mz = G - 0.2 + rng.uniform(0.0, 1.0) ** 2.0 * 1.4
            nc.ellip("moss", (x - r0 * rng.uniform(0.3, 0.9), 3.2, mz), (rng.uniform(0.1, 0.2), 0.3, rng.uniform(0.05, 0.1)), mossn, seg=8)
        for k in range(2):            # bark ridges
            bx = x + rng.uniform(-0.5, 0.5) * r0
            nc.capsule("ridge", (bx, 3.15, G + 0.5), (bx + ln * 6, 3.15, 9.8), 0.05, 0.03, needle, seg=6)
    # no hanging boughs: the image's top edge sits mid-screen in game (tex_y), above it
    # Backdrop stretches the top row, so only trunks may touch it.
    for i in range(30):               # ferns and grass at the bottom
        fx = rng.uniform(-hw, hw)
        for a in (-60, -30, 0, 30, 60):
            aa = math.radians(a + rng.uniform(-12, 12))
            L = rng.uniform(0.5, 1.0)
            nc.capsule("fern", (fx, 3, G - 0.3), (fx + math.sin(aa) * L, 3, G - 0.3 + math.cos(aa) * L * 0.8), 0.05, 0.01, nm, seg=5, bend=0.08)
    render("bg_near.png", hw)


# ---------------- Царство Морены ----------------
def frost():
    rng = random.Random(33)
    SUN = ((0.4, 1.0, 0.8), 2.4, "#F4F8FF", True)
    FILL = ((-0.4, -1.0, 0.5), 1.2, "#A8C0E0", False)
    hw = setup(2560, False, "#C9D8E6", [SUN, FILL])
    nc.plane("sky", -hw - 1, hw + 1, -1, 10, 80, grad_mat("sky", "#7E98B6", "#E4EDF5", 0.9))
    nc.ellip("sun", (-5.0, 70, 7.0), (0.55, 0.1, 0.55), nc.glow("sun", "#FFFFFF", 1.0))
    halo(-5.0, 72, 7.0, 4.0, "#FFFFFF", 0.7)
    crag = nc.toon("crag", "#A8BCD2", shadow_tint="#7088B8", fog="#DCE6F0", fog_k=0.45, rim="#FFFFFF", rim_k=0.5)
    for i in range(9):
        cx = -hw + i * 2 * hw / 9 + rng.uniform(-0.6, 0.6)
        ch = rng.uniform(1.6, 3.8)
        flat(nc.cone("crag", (cx, 60, 3.6), (cx + rng.uniform(-0.6, 0.6), 60, 3.6 + ch), rng.uniform(0.8, 1.6), crag, seg=rng.choice((4, 5, 6))))
    brm = nc.toon("bridge", "#94A9C0", fog="#DCE6F0", fog_k=0.4, rim="#FFFFFF", rim_k=0.4)
    bridge(2.0, 10.5, 5.6, 7.0, 5.3, 55, brm, rng)
    farb = nc.toon("far_birch", "#B4C6D8", fog="#DCE6F0", fog_k=0.5, rim="#FFFFFF", rim_k=0.3)
    x = -hw
    while x < hw:
        if rng.random() < 0.6:
            spruce(x, 45, 3.7, rng.uniform(1.2, 2.6), farb, rng, droop=False)
        else:
            bare_tree(x, 45, 3.7, rng.uniform(1.6, 3.0), farb, rng, nbr=(3, 5))
        x += rng.uniform(0.4, 1.0)
    fog(hw, 3.4, 5.2, "#F0F5FA", 0.7, 42)
    river = grad_mat("river", "#D6E6F2", "#9DBBD4", 1.4)
    nc.plane("river", -hw - 1, hw + 1, 1.0, 3.75, 30, river)
    shine = alpha_mat("shine", "#FFFFFF", 0.55)
    for i in range(18):
        sx = rng.uniform(-hw, hw); sz = rng.uniform(2.9, 3.7)
        nc.ellip("shine", (sx, 29, sz), (rng.uniform(0.4, 1.6), 0.02, 0.012), shine, seg=8)
    for i in range(8):                  # cracks in the ice
        sx = rng.uniform(-hw, hw)
        nc.capsule("crack", (sx, 29, rng.uniform(2.9, 3.7)), (sx + rng.uniform(-1.2, 1.2), 29, rng.uniform(2.9, 3.7)), 0.012, 0.006, nc.glow("crack", "#7FA4C8", 1.0), seg=4)
    render("bg_far.png", hw)

    # mid
    hw = setup(3200, True, "#C9D8E6", [SUN, FILL])
    birch = nc.toon("birch", "#DCE4EA", shadow_tint="#6E86B4", fog="#C9D8E6", fog_k=0.25, rim="#FFFFFF", rim_k=0.4)
    mark = nc.toon("birch_mark", "#38445A", fog="#C9D8E6", fog_k=0.25, rim_k=0.0)
    twig = nc.toon("twig", "#5E6E86", fog="#C9D8E6", fog_k=0.3, rim="#FFFFFF", rim_k=0.3)
    snow = nc.toon("snow", "#F2F6FA", shadow_tint="#8CA8D8", rim="#FFFFFF", rim_k=0.3)
    icem = nc.toon("ice", "#7C93AD", shadow_tint="#5070A8", fog="#C9D8E6", fog_k=0.2, rim="#E8F6FF", rim_k=0.6)
    wood = nc.toon("idol_wood", "#5A5A66", fog="#C9D8E6", fog_k=0.25, rim="#E8F6FF", rim_k=0.4)
    dk = nc.toon("idol_dark", "#2C3B52", fog="#C9D8E6", fog_k=0.2, rim_k=0.1)
    gl = nc.glow("ice_glow", "#8FD3F5", 2.4)
    for i in range(8):
        x = -hw + 1 + i * (2 * hw - 2) / 7 + rng.uniform(-0.6, 0.6)
        if i in (2, 6):
            continue
        h = rng.uniform(4.5, 6.8)
        r0 = 0.12 + h * 0.018
        nc.capsule("birch", (x, 20, G - 0.6), (x, 20, G + h), r0, r0 * 0.3, birch, seg=12)
        for k in range(int(h * 4)):
            mz = G + rng.uniform(0.0, 0.9) * h
            nc.ellip("mark", (x + rng.uniform(-0.6, 0.6) * r0, 20 - r0 * 0.92, mz), (r0 * rng.uniform(0.25, 0.6), 0.03, rng.uniform(0.012, 0.035)), mark, seg=8)
        for k in range(rng.randint(4, 7)):
            t = rng.uniform(0.4, 0.92); s = rng.choice((-1, 1))
            px, pz = x, G + h * t
            L = rng.uniform(0.8, 1.6) * (1.1 - t * 0.4)
            ex, ez = px + s * L, pz + rng.uniform(-0.3, 0.5)
            nc.capsule("br", (px, 20, pz), (ex, 20, ez), 0.05, 0.012, twig, seg=6, bend=0.1)
            for j in range(2):          # forked twigs
                tx = px + s * L * (0.45 + 0.25 * j)
                tz = pz + (ez - pz) * (0.45 + 0.25 * j)
                nc.capsule("tw", (tx, 20.1, tz), (tx + s * rng.uniform(0.2, 0.45), 20.1, tz + rng.uniform(0.15, 0.4)), 0.02, 0.006, twig, seg=4)
            nc.capsule("snowbr", (px + s * 0.1, 19.95, pz + 0.05), (px + (ex - px) * 0.85, 19.95, pz + (ez - pz) * 0.85 + 0.04), 0.07, 0.025, snow, seg=8, squash=(1, 0.8))
    for x, h, t in ((-hw + 1 + 2 * (2 * hw - 2) / 7, 2.7, 0.06), (-hw + 1 + 6 * (2 * hw - 2) / 7, 3.0, -0.08)):
        idol(x, 18, G, h, wood, dk, tilt=t, glow=gl)
        shell = alpha_mat("shell", "#BEE6FA", 0.32, 1.0)
        nc.ellip("shell", (x, 17.2, G + h * 0.5), (0.75, 0.5, h * 0.62), shell, seg=10)
        for k in range(7):          # ice spikes around the frozen idol
            a = math.radians(rng.uniform(-70, 70))
            L = rng.uniform(0.6, 1.4)
            flat(nc.cone("spike", (x + rng.uniform(-0.4, 0.4), 17.0, G - 0.1), (x + math.sin(a) * L, 17.0, G + math.cos(a) * L * 1.3), rng.uniform(0.1, 0.2), icem, seg=4))
        halo(x, 16.8, G + h * 0.8, 1.0, "#8FD3F5", 0.4)
    for i in range(9):              # ice crags between the trees
        cx = rng.uniform(-hw, hw)
        flat(nc.cone("crag", (cx, 22, G - 0.3), (cx + rng.uniform(-0.5, 0.5), 22, G + rng.uniform(1.0, 2.6)), rng.uniform(0.5, 1.0), icem, seg=rng.choice((4, 5))))
    x = -hw - 1
    while x < hw + 1:
        nc.ellip("drift", (x, 18.5, G - 0.05), (rng.uniform(1.4, 2.6), 1.0, rng.uniform(0.22, 0.42)), snow, seg=16)
        x += rng.uniform(1.2, 2.2)
    rays(hw, rng, 3, "#FFFFFF", 0.10, 23)
    band(hw, G - 0.4, G + 1.4, "#F0F5FA", 0.35, 15)
    render("bg_mid.png", hw)

    # near
    hw = setup(3840, True, "#C9D8E6", [SUN, FILL])
    nm = nc.toon("near", "#2C3B52", shadow_tint="#40507A", rim="#DDE8F0", rim_k=0.5)
    snow = nc.toon("snow_n", "#E4ECF4", shadow_tint="#7C98C8", rim="#FFFFFF", rim_k=0.35)
    ice = nc.toon("ice_n", "#8FD3F5", shadow_tint="#4070B0", rim="#FFFFFF", rim_k=0.7, emit=0.25)
    for x, h, ln in ((-14.2, 10.5, 0.03), (-5.2, 9.5, -0.04), (7.0, 10.5, 0.03), (14.8, 9.0, -0.05)):
        bare_tree(x, 4, G - 0.4, h, nm, rng, lean=ln, r0=0.5, nbr=(4, 6), snow=snow)
        nc.ellip("cap", (x, 3.9, G - 0.1), (1.6, 0.8, 0.35), snow, seg=14)
    for o in [o for o in meshes() if o.name.startswith("snowbr")]:   # icicles under the snowy branches
        bb = [o.matrix_world @ Vector(c) for c in o.bound_box]
        x0, x1 = min(v.x for v in bb), max(v.x for v in bb)
        zb = min(v.z for v in bb)
        if zb > 8.6:
            continue
        for k in range(rng.randint(2, 5)):
            px = rng.uniform(x0 + 0.1, x1 - 0.1)
            flat(nc.cone("icicle", (px, 3.9, zb + 0.08), (px, 3.9, zb - rng.uniform(0.2, 0.6)), rng.uniform(0.03, 0.06), ice, seg=5))
    for i in range(16):             # crystal clusters and drifts at the bottom
        cx = rng.uniform(-hw, hw)
        nc.ellip("drift", (cx, 3.2, G - 0.35), (rng.uniform(1.0, 2.2), 0.8, rng.uniform(0.3, 0.6)), snow, seg=14)
        if rng.random() < 0.5:
            for k in range(rng.randint(2, 4)):
                a = math.radians(rng.uniform(-40, 40))
                L = rng.uniform(0.4, 1.0)
                flat(nc.cone("crystal", (cx, 3.0, G - 0.3), (cx + math.sin(a) * L, 3.0, G - 0.3 + math.cos(a) * L), rng.uniform(0.08, 0.16), ice, seg=4))
    render("bg_near.png", hw)


# ---------------- Застава ----------------
def log_house(x, y, w, h, logm, endm, roofm, carvm, winm, frame, rng, smoke=None):
    z0 = G - 0.2
    n = int(h / 0.24)
    for k in range(n):               # stacked logs with protruding ends
        z = z0 + 0.12 + k * 0.24
        nc.capsule("log", (x - w / 2 - 0.18, y, z), (x + w / 2 + 0.18, y, z), 0.13, 0.13, logm, seg=10, squash=(1, 0.9))
        for s in (-1, 1):
            nc.ellip("end", (x + s * (w / 2 + 0.2), y - 0.12, z), (0.1, 0.03, 0.1), endm, seg=10)
    zt = z0 + n * 0.24
    rh = w * 0.42
    for s in (-1, 1):                # roof slopes (planks)
        cx = x + s * w * 0.27
        ang = math.atan2(rh, w / 2 + 0.5) * s
        box("roof", (cx, y - 0.05, zt + rh / 2 - 0.05), (w / 2 + 0.75, 0.9, 0.16), roofm, rot_y=ang)
        box("prichelina", (cx, y - 0.55, zt + rh / 2 - 0.12), (w / 2 + 0.75, 0.06, 0.2), carvm, rot_y=ang)
        for k in range(5):           # carved drops on the barge boards
            t = (k + 0.5) / 5
            px = x + s * (w / 2 + 0.55) * (1 - t)
            pz = zt - 0.05 + rh * t - 0.3
            nc.ellip("drop", (px, y - 0.58, pz), (0.05, 0.03, 0.08), carvm, seg=8)
    # gable wall
    quad("gable", ((x - w / 2, zt), (x + w / 2, zt), (x, zt + rh * 0.9), (x, zt + rh * 0.9)), y - 0.14, logm)
    nc.torus("sun", (x, y - 0.6, zt + rh * 0.45), 0.18, 0.04, carvm, rot=(math.pi / 2, 0, 0))
    nc.ellip("konyok", (x, y - 0.3, zt + rh + 0.12), (0.18, 0.12, 0.14), carvm, seg=10)
    for wx in (x - w * 0.26, x + w * 0.26):     # lit windows with carved frames
        wz = z0 + h * 0.45
        box("win", (wx, y - 0.16, wz), (0.5, 0.05, 0.55), winm)
        box("frame", (wx, y - 0.2, wz), (0.62, 0.03, 0.06), frame)
        box("framev", (wx, y - 0.2, wz), (0.06, 0.03, 0.62), frame)
        box("nal_top", (wx, y - 0.22, wz + 0.36), (0.78, 0.05, 0.14), carvm)
        box("nal_bot", (wx, y - 0.22, wz - 0.34), (0.7, 0.05, 0.08), carvm)
        halo(wx, y - 0.3, wz, 1.1, "#FF9A3C", 0.28)
    if smoke:
        cx, cz = x + w * 0.22, zt + rh * 0.55
        box("chimney", (cx, y - 0.1, cz + 0.2), (0.32, 0.3, 0.8), endm)
        for k in range(6):
            t = k / 6
            halo(cx + t * t * 1.6 + rng.uniform(-0.1, 0.1), y - 0.2 - k * 0.01, cz + 0.8 + t * 2.2,
                 0.45 + t * 1.0, smoke, 0.22 * (1 - t) + 0.05, power=1.2)


def torch(x, y, z, h, pole, rng):
    nc.capsule("pole", (x, y, z - 0.4), (x, y, z + h), 0.06, 0.05, pole, seg=8)
    nc.cone("bowl", (x, y, z + h + 0.12), (x, y, z + h - 0.12), 0.16, pole, seg=10)
    nc.cone("flame", (x, y - 0.05, z + h + 0.05), (x + 0.04, y - 0.05, z + h + 0.55), 0.14, nc.glow("flame", "#FF9A3C", 3.0), seg=10)
    nc.cone("core", (x, y - 0.1, z + h + 0.05), (x + 0.02, y - 0.1, z + h + 0.32), 0.07, nc.glow("core", "#FFE08A", 3.0), seg=8)
    halo(x, y - 0.2, z + h + 0.3, 1.8, "#FF9A3C", 0.45)


def base():
    rng = random.Random(44)
    MOON = ((0.3, 1.0, 0.9), 1.6, "#A8B8E0", True)
    WARM = ((-0.3, -1.0, 0.3), 1.3, "#FFB070", False)
    hw = setup(2560, False, "#1D2433", [MOON, WARM])
    nc.plane("sky", -hw - 1, hw + 1, -1, 10, 80, grad_mat("sky", "#080B14", "#2A3450", 0.7))
    stars(hw, rng, 220, 3.8, 8.8)
    nc.ellip("moon", (-6.5, 70, 7.6), (0.5, 0.1, 0.5), nc.glow("moon", "#F0EEDC", 1.0))
    halo(-6.5, 72, 7.6, 2.8, "#C8D0F0", 0.3)
    hill = nc.toon("hill", "#1A2236", fog="#2A3450", fog_k=0.45, rim_k=0.0)
    for hx, hr, hz in ((-9, 6, 1.0), (0, 7, 0.8), (9, 6, 1.2)):
        nc.ellip("hill", (hx, 60, 3.5), (hr, 2, hz), hill, seg=24)
    brm = nc.toon("bridge", "#1C2540", fog="#2A3450", fog_k=0.35, rim="#A8B8E0", rim_k=0.3)
    bridge(3.0, 10.5, 6.2, 7.4, 4.6, 55, brm, rng)
    halo(6.8, 57, 4.0, 1.3, "#FF8A3D", 0.2)
    farm = nc.toon("far_spr", "#141B2C", fog="#2A3450", fog_k=0.35, rim="#A8B8E0", rim_k=0.25)
    x = -hw
    while x < hw:
        spruce(x, 45, 3.1, rng.uniform(1.2, 2.8), farm, rng, droop=False)
        x += rng.uniform(0.45, 1.0)
    fog(hw, 2.4, 4.0, "#3A4460", 0.5, 40)
    render("bg_far.png", hw)

    # mid: palisade, watchtowers, log houses
    hw = setup(3200, True, "#1D2433", [MOON, WARM])
    stake = nc.toon("stake", "#3A2618", shadow_tint="#40486A", rim="#8AA0C8", rim_k=0.45)
    logm = nc.toon("log", "#5B3A24", shadow_tint="#40486A", rim="#FFC070", rim_k=0.35)
    endm = nc.toon("logend", "#7A5232", shadow_tint="#40486A", rim="#FFC070", rim_k=0.3)
    roofm = nc.toon("roof", "#3A2A22", shadow_tint="#40486A", rim="#A8B8E0", rim_k=0.45)
    carvm = nc.toon("carve", "#C8902E", shadow_tint="#605070", rim="#FFE0A0", rim_k=0.4)
    winm = nc.glow("window", "#FFB050", 2.2)
    frame = nc.toon("wframe", "#2A1A12", rim_k=0.0)
    x = -hw - 0.3
    while x < hw + 0.3:
        ph = rng.uniform(2.3, 2.7)
        nc.capsule("stake", (x, 26, G - 0.5), (x, 26, G + ph), 0.17, 0.16, stake, seg=8)
        nc.cone("point", (x, 26, G + ph - 0.05), (x, 26, G + ph + 0.45), 0.17, stake, seg=8)
        x += 0.36
    nc.capsule("rail", (-hw - 1, 25.8, G + 1.9), (hw + 1, 25.8, G + 1.9), 0.06, 0.06, stake, seg=6)
    for tx in (-10.5, 5.5):            # watchtowers
        for s in (-1, 1):
            nc.capsule("leg", (tx + s * 0.7, 24, G - 0.5), (tx + s * 0.55, 24, G + 3.5), 0.12, 0.1, stake, seg=8)
        box("cabin", (tx, 24, G + 3.9), (1.8, 1.0, 0.9), logm)
        box("troof", (tx, 23.9, G + 4.65), (2.2, 1.2, 0.12), roofm)
        nc.cone("tspire", (tx, 24, G + 4.7), (tx, 24, G + 5.5), 1.15, roofm, seg=4)
        box("twin", (tx, 23.45, G + 3.95), (0.7, 0.05, 0.32), winm)
        halo(tx, 23.3, G + 3.95, 1.0, "#FF9A3C", 0.3)
    for hx, w, h in ((-6.8, 4.2, 2.6), (1.2, 3.6, 2.3), (10.0, 4.6, 2.8)):
        log_house(hx, 20, w, h, logm, endm, roofm, carvm, winm, frame, rng, smoke="#B8AC98")
    band(hw, G - 0.4, G + 0.9, "#3A4460", 0.3, 16)
    render("bg_mid.png", hw)

    # near: Капище idols and torches, wattle fence, edge posts
    hw = setup(3840, True, "#1D2433", [MOON, WARM])
    nm = nc.toon("near", "#2A1A12", shadow_tint="#40486A", rim="#FFB070", rim_k=0.45)
    wood = nc.toon("idol_wood", "#6A4A30", shadow_tint="#40486A", rim="#FFC070", rim_k=0.5)
    dk = nc.toon("idol_dark", "#2A1A12", rim_k=0.1)
    eye = nc.glow("idol_eye", "#FF9A3C", 2.0)
    for k, (ix, ih) in enumerate(((-11.6, 3.0), (-10.4, 3.6), (-9.2, 2.8))):
        idol(ix, 5, G, ih, wood, dk, tilt=(k - 1) * 0.05, glow=eye)
    for tx in (-12.6, -8.2, 3.5, 12.0):
        torch(tx, 4.5, G, 1.9, nm, rng)
    halo(-10.4, 4.4, G + 1.2, 2.8, "#FF9A3C", 0.25)
    for x0, x1 in ((-6.5, 1.5), (5.0, 10.0)):     # плетень (wattle fence)
        x = x0
        while x <= x1:
            nc.capsule("fpost", (x, 3.8, G - 0.5), (x, 3.8, G + 1.15), 0.06, 0.05, nm, seg=6)
            x += 0.75
        for k in range(4):
            z = G + 0.2 + k * 0.24
            nc.capsule("withe", (x0 - 0.1, 3.75, z), (x1 + 0.1, 3.75, z + rng.uniform(-0.04, 0.04)), 0.05, 0.05, nm, seg=6, bend=0.03)
    for x in (-hw + 0.4, -hw + 1.0, hw - 0.9):    # dark gate posts at the tile edges
        nc.capsule("post", (x, 3, G - 0.8), (x, 3, 9.8), 0.4, 0.36, nm, seg=12)
    for i in range(14):                # grass tufts
        gx = rng.uniform(-hw, hw)
        for a in (-35, -12, 10, 30):
            aa = math.radians(a + rng.uniform(-8, 8))
            L = rng.uniform(0.3, 0.6)
            nc.capsule("grass", (gx, 3.5, G - 0.2), (gx + math.sin(aa) * L, 3.5, G - 0.2 + math.cos(aa) * L), 0.035, 0.006, nm, seg=4)
    render("bg_near.png", hw)


{"forest": forest, "frost": frost, "base": base}[PLACE]()

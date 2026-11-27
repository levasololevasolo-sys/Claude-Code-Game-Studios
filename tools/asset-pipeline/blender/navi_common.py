"""Shared Blender helpers for the Навь 3D-to-2D sprite pipeline (Blender 4.0, EEVEE legacy).

Look: soft three-tone cel shading (Shader to RGB + eased colour ramp), a cool
shadow tint, a back rim, a thick warm-black inverted-hull outline. Every mesh is
built with bmesh (no bpy.ops), so the scripts run headless and reproducibly.
Camera-space normals are rendered as a second pass (OpenGL convention: R=right,
G=up, B=toward the viewer) for Godot CanvasTexture normal maps.
"""
import bpy, bmesh, math, random
from mathutils import Vector, Matrix, Euler

OUTLINE_HEX = "#120D12"


def srgb_to_lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def hexc(h, a=1.0):
    h = h.lstrip("#")
    return tuple(srgb_to_lin(int(h[i:i + 2], 16) / 255.0) for i in (0, 2, 4)) + (a,)


def reset(transparent=True, samples=16):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE"
    sc.eevee.taa_render_samples = samples
    sc.eevee.use_soft_shadows = True
    sc.eevee.shadow_cascade_size = "2048"
    sc.render.film_transparent = transparent
    sc.view_settings.view_transform = "Standard"
    sc.view_settings.look = "None"
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    sc.render.image_settings.color_depth = "8"
    sc.render.resolution_percentage = 100
    w = bpy.data.worlds.new("World")
    sc.world = w
    w.use_nodes = True
    bg = w.node_tree.nodes["Background"]
    bg.inputs[0].default_value = hexc("#2a3a44")
    bg.inputs[1].default_value = 0.35
    random.seed(7)
    _cache.clear()
    return sc


def sun(direction_to_light, strength, color="#FFF1DC", shadow=True, angle=6.0):
    d = bpy.data.lights.new("Sun", "SUN")
    d.energy = strength
    d.color = hexc(color)[:3]
    d.use_shadow = shadow
    d.angle = math.radians(angle)
    o = bpy.data.objects.new("Sun", d)
    bpy.context.scene.collection.objects.link(o)
    L = Vector(direction_to_light).normalized()
    o.rotation_mode = "QUATERNION"
    o.rotation_quaternion = (-L).to_track_quat("-Z", "Y")
    return o


def ortho_camera(cell_w, cell_h, ppm, origin_px, ss=2, y=-30.0):
    """Ortho camera looking +Y. origin_px = pixel (x, y-from-top) of world (0,0,0) in the cell."""
    sc = bpy.context.scene
    cd = bpy.data.cameras.new("Cam")
    cd.type = "ORTHO"
    cd.ortho_scale = max(cell_w, cell_h) / ppm
    cd.clip_start = 0.1
    cd.clip_end = 300.0
    cam = bpy.data.objects.new("Cam", cd)
    sc.collection.objects.link(cam)
    ox, oy = origin_px
    cam.location = ((cell_w / 2 - ox) / ppm, y, (oy - cell_h / 2) / ppm)
    cam.rotation_euler = (math.pi / 2, 0, 0)
    sc.camera = cam
    sc.render.resolution_x = int(cell_w * ss)
    sc.render.resolution_y = int(cell_h * ss)
    return cam


# ---------------- materials ----------------
_cache = {}


def toon(name, base, shadow_tint="#5B5F8A", rim="#FFE2B0", rim_k=0.45, emit=0.0,
         fog=None, fog_k=0.0, soft=0.07, levels=(0.16, 0.42), paint=None):
    """Three-tone cel material. base/shadow_tint/rim are hex; emit adds base*emit glow;
    fog_k blends toward the fog colour (background layers). paint: dict for a
    procedural painted albedo (see paint_nodes); the cel ramp, cool shadow tint and
    rim stay the same, only the base colour varies over the surface."""
    key = (name, base, fog_k, repr(paint))
    if key in _cache:
        return _cache[key]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    n, l = nt.nodes, nt.links
    n.clear()
    out = n.new("ShaderNodeOutputMaterial")
    dif = n.new("ShaderNodeBsdfDiffuse")
    dif.inputs[0].default_value = (1, 1, 1, 1)
    s2r = n.new("ShaderNodeShaderToRGB")
    l.new(dif.outputs[0], s2r.inputs[0])
    bw = n.new("ShaderNodeRGBToBW")
    l.new(s2r.outputs[0], bw.inputs[0])
    ramp = n.new("ShaderNodeValToRGB")
    l.new(bw.outputs[0], ramp.inputs[0])
    cr = ramp.color_ramp
    cr.interpolation = "EASE"
    e = cr.elements
    e[0].position, e[0].color = levels[0], (0, 0, 0, 1)
    e[1].position, e[1].color = levels[0] + soft, (0.5, 0.5, 0.5, 1)
    e2 = e.new(levels[1]); e2.color = (0.5, 0.5, 0.5, 1)
    e3 = e.new(levels[1] + soft); e3.color = (1, 1, 1, 1)
    bc = hexc(base)
    st = hexc(shadow_tint)
    sh = tuple(min(1.0, bc[i] * st[i] * 2.2) for i in range(3)) + (1,)
    mx = n.new("ShaderNodeMixRGB")
    l.new(ramp.outputs[0], mx.inputs[0])
    if paint:
        bsock = paint_nodes(nt, base, paint)
        shm = n.new("ShaderNodeVectorMath"); shm.operation = "MULTIPLY"
        l.new(bsock, shm.inputs[0])
        shm.inputs[1].default_value = tuple(st[i] * 2.2 for i in range(3))
        l.new(shm.outputs[0], mx.inputs[1])
        l.new(bsock, mx.inputs[2])
    else:
        mx.inputs[1].default_value = sh
        mx.inputs[2].default_value = bc
    col = mx.outputs[0]
    # rim: grazing angle on the side away from the key light (camera-space +x/+y)
    lw = n.new("ShaderNodeLayerWeight")
    lw.inputs[0].default_value = 0.3
    rr = n.new("ShaderNodeMapRange")
    rr.inputs[1].default_value = 0.55
    rr.inputs[2].default_value = 0.8
    l.new(lw.outputs["Facing"], rr.inputs[0])
    geo = n.new("ShaderNodeNewGeometry")
    vt = n.new("ShaderNodeVectorTransform")
    vt.vector_type = "NORMAL"; vt.convert_from = "WORLD"; vt.convert_to = "CAMERA"
    l.new(geo.outputs["Normal"], vt.inputs[0])
    dot = n.new("ShaderNodeVectorMath"); dot.operation = "DOT_PRODUCT"
    l.new(vt.outputs[0], dot.inputs[0])
    dot.inputs[1].default_value = (0.75, 0.45, 0.0)
    dm = n.new("ShaderNodeMapRange")
    dm.inputs[1].default_value = 0.05; dm.inputs[2].default_value = 0.5
    l.new(dot.outputs["Value"], dm.inputs[0])
    rm = n.new("ShaderNodeMath"); rm.operation = "MULTIPLY"
    l.new(rr.outputs[0], rm.inputs[0]); l.new(dm.outputs[0], rm.inputs[1])
    rm2 = n.new("ShaderNodeMath"); rm2.operation = "MULTIPLY"
    l.new(rm.outputs[0], rm2.inputs[0]); rm2.inputs[1].default_value = rim_k
    add = n.new("ShaderNodeMixRGB"); add.blend_type = "ADD"
    l.new(rm2.outputs[0], add.inputs[0])
    l.new(col, add.inputs[1])
    add.inputs[2].default_value = hexc(rim)
    col = add.outputs[0]
    if emit > 0:
        ea = n.new("ShaderNodeMixRGB"); ea.blend_type = "ADD"
        ea.inputs[0].default_value = 1.0
        l.new(col, ea.inputs[1])
        ea.inputs[2].default_value = tuple(c * emit for c in bc[:3]) + (1,)
        col = ea.outputs[0]
    if fog is not None and fog_k > 0:
        fm = n.new("ShaderNodeMixRGB")
        fm.inputs[0].default_value = fog_k
        l.new(col, fm.inputs[1])
        fm.inputs[2].default_value = hexc(fog)
        col = fm.outputs[0]
    em = n.new("ShaderNodeEmission")
    l.new(col, em.inputs[0])
    l.new(em.outputs[0], out.inputs[0])
    _cache[key] = m
    return m


def _mix(nt, fac, a, b, blend="MIX"):
    m = nt.nodes.new("ShaderNodeMixRGB"); m.blend_type = blend
    for sock, v in ((m.inputs[0], fac), (m.inputs[1], a), (m.inputs[2], b)):
        if isinstance(v, str):
            sock.default_value = hexc(v)
        elif isinstance(v, (int, float)):
            sock.default_value = v
        else:
            nt.links.new(v, sock)
    return m.outputs[0]


def _math(nt, op, a, b=None, clamp=False):
    m = nt.nodes.new("ShaderNodeMath"); m.operation = op; m.use_clamp = clamp
    for sock, v in ((m.inputs[0], a), (m.inputs[1], b)):
        if v is None:
            continue
        if isinstance(v, (int, float)):
            sock.default_value = v
        else:
            nt.links.new(v, sock)
    return m.outputs[0]


def _remap(nt, v, a, b, c=0.0, d=1.0):
    m = nt.nodes.new("ShaderNodeMapRange")
    nt.links.new(v, m.inputs[0])
    m.inputs[1].default_value, m.inputs[2].default_value = a, b
    m.inputs[3].default_value, m.inputs[4].default_value = c, d
    return m.outputs[0]


def paint_nodes(nt, base, p):
    """Procedural painted albedo on the mesh's 'rest' point attribute (undeformed
    metres, so the pattern sticks to the skinned surface and does not swim).
    p: kind (skin, cloth, wood, hair, wrap, rope, plain), c2 (blotch colour),
    c3 (detail colour), amt, scale, dirt (hex, cloth: darker toward the ground)."""
    n, l = nt.nodes, nt.links
    at = n.new("ShaderNodeAttribute"); at.attribute_name = "rest"
    kind = p.get("kind", "plain")
    sc = p.get("scale", 12.0)
    vm = n.new("ShaderNodeVectorMath"); vm.operation = "MULTIPLY"
    l.new(at.outputs["Vector"], vm.inputs[0])
    vm.inputs[1].default_value = (sc, sc, sc * (0.12 if kind == "hair" else 1.0))
    vec = vm.outputs[0]
    nz = n.new("ShaderNodeTexNoise"); nz.inputs["Detail"].default_value = 4.0
    nz.inputs["Roughness"].default_value = 0.62
    l.new(vec, nz.inputs["Vector"])
    f = _remap(nt, nz.outputs["Fac"], 0.32, 0.68, 0.0, p.get("amt", 0.4))
    col = _mix(nt, f, base, p.get("c2", base))
    # flat 'brush patches': cellular value jitter, the hand-painted look
    vo = n.new("ShaderNodeTexVoronoi"); vo.inputs["Scale"].default_value = 1.0
    vm2 = n.new("ShaderNodeVectorMath"); vm2.operation = "SCALE"
    l.new(vec, vm2.inputs[0]); vm2.inputs["Scale"].default_value = p.get("patch", 0.7)
    l.new(vm2.outputs[0], vo.inputs["Vector"])
    bw = n.new("ShaderNodeRGBToBW"); l.new(vo.outputs["Color"], bw.inputs[0])
    jit = _remap(nt, bw.outputs[0], 0.0, 1.0, 1.0 - p.get("jit", 0.07), 1.0 + p.get("jit", 0.07))
    col = _mul(nt, col, jit)
    sep = n.new("ShaderNodeSeparateXYZ"); l.new(at.outputs["Vector"], sep.inputs[0])
    if kind == "cloth":
        for axis, s2 in (("X", 1.0), ("Z", 1.0)):
            wv = n.new("ShaderNodeTexWave"); wv.bands_direction = axis
            wv.inputs["Scale"].default_value = p.get("weave", 9.0) * s2
            wv.inputs["Distortion"].default_value = 1.5
            l.new(at.outputs["Vector"], wv.inputs["Vector"])
            col = _mix(nt, _remap(nt, wv.outputs["Fac"], 0.6, 1.0, 0.0, 0.1), col, p.get("c3", "#6E6250"))
        if p.get("dirt"):
            dz = _remap(nt, sep.outputs["Z"], p.get("dirt_z", (0.25, 0.75))[0], p.get("dirt_z", (0.25, 0.75))[1], 0.55, 0.0)
            col = _mix(nt, _math(nt, "MULTIPLY", dz, nz.outputs["Fac"]), col, p["dirt"])
    elif kind == "wood":
        wv = n.new("ShaderNodeTexWave"); wv.bands_direction = "Y"
        wv.inputs["Scale"].default_value = p.get("grain", 3.0)
        wv.inputs["Distortion"].default_value = 6.0; wv.inputs["Detail"].default_value = 3.0
        gm = n.new("ShaderNodeVectorMath"); gm.operation = "MULTIPLY"
        l.new(at.outputs["Vector"], gm.inputs[0]); gm.inputs[1].default_value = (1.5, 14.0, 14.0)
        l.new(gm.outputs[0], wv.inputs["Vector"])
        col = _mix(nt, _remap(nt, wv.outputs["Fac"], 0.4, 1.0, 0.0, 0.55), col, p.get("c3", "#4A3020"))
    elif kind == "hair":
        col = _mix(nt, _remap(nt, nz.outputs["Fac"], 0.55, 0.75, 0.0, 0.6), col, p.get("c3", "#E0A060"))
    elif kind in ("wrap", "rope"):
        aw = n.new("ShaderNodeAttribute"); aw.attribute_name = "wrapuv"
        sw = n.new("ShaderNodeSeparateXYZ"); l.new(aw.outputs["Vector"], sw.inputs[0])
        pitch = p.get("pitch", 0.035)
        ph = _math(nt, "ADD", _math(nt, "DIVIDE", sw.outputs["Y"], pitch), _math(nt, "MULTIPLY", sw.outputs["X"], p.get("twist", 0.35)))
        band = _math(nt, "COSINE", _math(nt, "MULTIPLY", ph, 6.2832))
        col = _mix(nt, _remap(nt, band, 0.45, 0.95, 0.0, 0.6), col, p.get("c3", "#4E4234"))
        if kind == "wrap":   # criss-cross binding cords above the ankle
            for sgn in (1, -1):
                q = _math(nt, "FRACT", _math(nt, "ADD", _math(nt, "DIVIDE", sw.outputs["Y"], 0.09), _math(nt, "MULTIPLY", sw.outputs["X"], 2.0 * sgn)))
                dq = _math(nt, "ABSOLUTE", _math(nt, "SUBTRACT", q, 0.5))
                cm = _math(nt, "MULTIPLY", _remap(nt, dq, 0.075, 0.05, 0.0, 1.0), sw.outputs["Z"])
                col = _mix(nt, cm, col, p.get("cord", "#3A2A20"))
    return col


def _mul(nt, col, k):
    m = nt.nodes.new("ShaderNodeVectorMath"); m.operation = "SCALE"
    nt.links.new(col, m.inputs[0]); nt.links.new(k, m.inputs["Scale"])
    return m.outputs[0]


def set_point_attr(o, name, values, kind="FLOAT_VECTOR"):
    """values: per-vertex tuples (FLOAT_VECTOR) or floats."""
    me = o.data
    a = me.attributes.get(name) or me.attributes.new(name, kind, "POINT")
    flat = [c for v in values for c in v] if kind == "FLOAT_VECTOR" else list(values)
    a.data.foreach_set("vector" if kind == "FLOAT_VECTOR" else "value", flat)


def add_rest(o):
    """Store the undeformed local vertex positions as the 'rest' attribute (paint_nodes)."""
    set_point_attr(o, "rest", [tuple(v.co) for v in o.data.vertices])


def glow(name, hexcol, strength=2.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    n = nt.nodes
    n.clear()
    out = n.new("ShaderNodeOutputMaterial")
    em = n.new("ShaderNodeEmission")
    em.inputs[0].default_value = hexc(hexcol)
    em.inputs[1].default_value = strength
    nt.links.new(em.outputs[0], out.inputs[0])
    return m


def fade_mat(name, hexcol, strength=1.0, alpha=1.0, axis="u", power=1.5, invert=False):
    """Emission with alpha from the mesh UV. axis u: smear (u along the arc, soft
    across v). axis v: vertical band (alpha = v^power, or (1-v)^power if invert)."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    m.blend_method = "BLEND"
    m.shadow_method = "NONE"
    m.show_transparent_back = True
    nt = m.node_tree; n, l = nt.nodes, nt.links
    n.clear()
    out = n.new("ShaderNodeOutputMaterial")
    uv = n.new("ShaderNodeUVMap")
    sep = n.new("ShaderNodeSeparateXYZ")
    l.new(uv.outputs[0], sep.inputs[0])
    src = sep.outputs["X" if axis == "u" else "Y"]
    if invert:
        iv = n.new("ShaderNodeMath"); iv.operation = "SUBTRACT"
        iv.inputs[0].default_value = 1.0
        l.new(src, iv.inputs[1]); src = iv.outputs[0]
    p = n.new("ShaderNodeMath"); p.operation = "POWER"
    l.new(src, p.inputs[0]); p.inputs[1].default_value = power
    a = n.new("ShaderNodeMath"); a.operation = "MULTIPLY"
    l.new(p.outputs[0], a.inputs[0]); a.inputs[1].default_value = alpha
    a_out = a.outputs[0]
    if axis == "u":
        vv = n.new("ShaderNodeMath"); vv.operation = "MULTIPLY"
        l.new(sep.outputs["Y"], vv.inputs[0]); vv.inputs[1].default_value = math.pi
        v = n.new("ShaderNodeMath"); v.operation = "SINE"
        l.new(vv.outputs[0], v.inputs[0])
        vp = n.new("ShaderNodeMath"); vp.operation = "POWER"
        l.new(v.outputs[0], vp.inputs[0]); vp.inputs[1].default_value = 0.5
        a2 = n.new("ShaderNodeMath"); a2.operation = "MULTIPLY"
        l.new(a_out, a2.inputs[0]); l.new(vp.outputs[0], a2.inputs[1])
        a_out = a2.outputs[0]
    em = n.new("ShaderNodeEmission")
    em.inputs[0].default_value = hexc(hexcol); em.inputs[1].default_value = strength
    tr = n.new("ShaderNodeBsdfTransparent")
    ms = n.new("ShaderNodeMixShader")
    l.new(a_out, ms.inputs[0]); l.new(tr.outputs[0], ms.inputs[1]); l.new(em.outputs[0], ms.inputs[2])
    l.new(ms.outputs[0], out.inputs[0])
    return m


def outline_mat():
    if "Outline" in bpy.data.materials:
        return bpy.data.materials["Outline"]
    m = glow("Outline", OUTLINE_HEX, 1.0)
    m.use_backface_culling = True
    m.shadow_method = "NONE"
    return m


def normal_mat():
    m = bpy.data.materials.new("NormalPass")
    m.use_nodes = True
    nt = m.node_tree; n, l = nt.nodes, nt.links
    n.clear()
    out = n.new("ShaderNodeOutputMaterial")
    geo = n.new("ShaderNodeNewGeometry")
    vt = n.new("ShaderNodeVectorTransform")
    vt.vector_type = "NORMAL"; vt.convert_from = "WORLD"; vt.convert_to = "CAMERA"
    l.new(geo.outputs["Normal"], vt.inputs[0])
    ma = n.new("ShaderNodeVectorMath"); ma.operation = "MULTIPLY_ADD"
    l.new(vt.outputs[0], ma.inputs[0])
    ma.inputs[1].default_value = (0.5, 0.5, 0.5); ma.inputs[2].default_value = (0.5, 0.5, 0.5)
    em = n.new("ShaderNodeEmission")
    l.new(ma.outputs[0], em.inputs[0])
    l.new(em.outputs[0], out.inputs[0])
    return m


# ---------------- meshes ----------------
def _obj(name, bm, mat):
    me = bpy.data.meshes.new(name)
    for f in bm.faces:
        f.smooth = True
    bm.to_mesh(me); bm.free()
    if mat is not None:
        me.materials.append(mat)
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    return o


def ellip(name, loc, size, mat, rot=(0, 0, 0), seg=24):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=max(8, seg // 2), radius=1.0)
    M = Matrix.Translation(Vector(loc)) @ Euler(rot).to_matrix().to_4x4() @ Matrix.Diagonal(Vector(size)).to_4x4()
    bmesh.ops.transform(bm, matrix=M, verts=bm.verts)
    return _obj(name, bm, mat)


def capsule(name, p0, p1, r0, r1, mat, seg=18, rings=8, squash=(1.0, 1.0), bend=0.0):
    """Tapered capsule from p0 (radius r0) to p1 (radius r1); squash scales the cross-section."""
    p0, p1 = Vector(p0), Vector(p1)
    d = p1 - p0
    L = d.length
    prof = []
    n = 5
    for i in range(n + 1):
        a = -math.pi / 2 + (math.pi / 2) * i / n
        prof.append((r0 * math.sin(a), r0 * math.cos(a)))
    for i in range(1, rings):
        t = i / rings
        prof.append((L * t, r0 + (r1 - r0) * t))
    for i in range(n + 1):
        a = (math.pi / 2) * i / n
        prof.append((L + r1 * math.sin(a), r1 * math.cos(a)))
    q = Vector((0, 0, 1)).rotation_difference(d.normalized())
    bm = bmesh.new()
    ringsv = []
    for z, r in prof:
        rv = []
        off = bend * math.sin(math.pi * max(0.0, min(1.0, z / L))) if L > 0 else 0
        for s in range(seg):
            a = 2 * math.pi * s / seg
            v = Vector((math.cos(a) * r * squash[0] + off, math.sin(a) * r * squash[1], z))
            rv.append(bm.verts.new(p0 + q @ v))
        ringsv.append(rv)
    for i in range(len(ringsv) - 1):
        for s in range(seg):
            a, b = ringsv[i][s], ringsv[i][(s + 1) % seg]
            c, e = ringsv[i + 1][(s + 1) % seg], ringsv[i + 1][s]
            bm.faces.new((a, b, c, e))
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.dissolve_degenerate(bm, edges=bm.edges, dist=1e-6)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _obj(name, bm, mat)


def torus(name, loc, R, r, mat, rot=(0, 0, 0), seg=24, segr=8, scale=(1, 1, 1)):
    bm = bmesh.new()
    vs = []
    for i in range(seg):
        a = 2 * math.pi * i / seg
        row = []
        for j in range(segr):
            b = 2 * math.pi * j / segr
            x = (R + r * math.cos(b)) * math.cos(a)
            y = (R + r * math.cos(b)) * math.sin(a)
            z = r * math.sin(b)
            row.append(bm.verts.new((x * scale[0], y * scale[1], z * scale[2])))
        vs.append(row)
    for i in range(seg):
        for j in range(segr):
            bm.faces.new((vs[i][j], vs[(i + 1) % seg][j], vs[(i + 1) % seg][(j + 1) % segr], vs[i][(j + 1) % segr]))
    M = Matrix.Translation(Vector(loc)) @ Euler(rot).to_matrix().to_4x4()
    bmesh.ops.transform(bm, matrix=M, verts=bm.verts)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _obj(name, bm, mat)


def cone(name, p0, p1, r, mat, seg=10):
    p0, p1 = Vector(p0), Vector(p1)
    d = p1 - p0
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=seg, radius1=r, radius2=0.0, depth=d.length)
    q = Vector((0, 0, 1)).rotation_difference(d.normalized())
    M = Matrix.Translation(p0 + d / 2) @ q.to_matrix().to_4x4()
    bmesh.ops.transform(bm, matrix=M, verts=bm.verts)
    return _obj(name, bm, mat)


def plane(name, x0, x1, z0, z1, y, mat):
    """Vertical quad in the XZ plane facing the camera (-Y), UV 0..1."""
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new("UVMap")
    vs = [bm.verts.new(p) for p in ((x0, y, z0), (x1, y, z0), (x1, y, z1), (x0, y, z1))]
    f = bm.faces.new(vs)
    for loop, uv in zip(f.loops, ((0, 0), (1, 0), (1, 1), (0, 1))):
        loop[uvl].uv = uv
    f.normal_update()
    if f.normal.y > 0:
        f.normal_flip()
    return _obj(name, bm, mat)


def add_outline(o, t):
    """Inverted hull: a flipped, back-face-culled shell t metres thick."""
    o.data.materials.append(outline_mat())
    mod = o.modifiers.new("outline", "SOLIDIFY")
    mod.thickness = t
    mod.offset = 1.0
    mod.use_flip_normals = True
    mod.use_rim = False
    mod.material_offset = len(o.data.materials) - 1
    mod.use_quality_normals = True


def arc_mesh(name, center, r_in, r_out, a0, a1, mat, seg=28, y=-0.45):
    """Smear crescent in the XZ plane, from angle a0 to a1 (deg, CCW seen from -Y).
    UV u: 0 at the tail .. 1 at the leading edge; v: 0 inner .. 1 outer."""
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new("UVMap")
    cx, cz = center
    rows = []
    for i in range(seg + 1):
        t = i / seg
        a = math.radians(a0 + (a1 - a0) * t)
        w = max(0.12, math.sin(math.pi * (0.1 + 0.85 * t)) ** 0.7)
        ri = r_out - (r_out - r_in) * w
        p_in = bm.verts.new((cx + math.cos(a) * ri, y, cz + math.sin(a) * ri))
        p_out = bm.verts.new((cx + math.cos(a) * r_out, y, cz + math.sin(a) * r_out))
        rows.append((p_in, p_out, t))
    for i in range(seg):
        a, b, ta = rows[i]
        c, d, tb = rows[i + 1]
        f = bm.faces.new((a, c, d, b))
        for loop, uv in zip(f.loops, ((ta, 0), (tb, 0), (tb, 1), (ta, 1))):
            loop[uvl].uv = uv
    return _obj(name, bm, mat)

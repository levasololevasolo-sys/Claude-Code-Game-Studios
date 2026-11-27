"""Sculpt-like creature bodies for the Навь sprite pipeline (Blender 4.0, headless).

Bodies are metaball fields (balls, ellipsoids, capsules, negative carvers)
converted to one smooth mesh: masses melt into each other like clay, warts and
knuckles are small balls on the surface. The mesh is then skinned to a planar
navi_rig.Rig by distance-to-bone weights (inverse 4th power, best 3 bones,
optionally restricted per blob), so it bends smoothly instead of hinging rigid
parts. Painted look and outline come from navi_common (paint_nodes, add_outline).
"""
import bpy, math, random
from mathutils import Vector, Quaternion
import navi_common as nc


class Blob:
    """Collects metaball elements, then bakes them into a mesh object."""

    def __init__(self, name, res=0.018, threshold=0.6):
        self.mb = bpy.data.metaballs.new(name)
        self.mb.resolution = res
        self.mb.render_resolution = res
        self.mb.threshold = threshold
        self.obj = bpy.data.objects.new(name + "_mb", self.mb)
        bpy.context.scene.collection.objects.link(self.obj)
        self.name = name

    def ball(self, co, r, stiff=2.0, neg=False):
        e = self.mb.elements.new(type="BALL")
        e.co, e.radius, e.stiffness, e.use_negative = Vector(co), r, stiff, neg
        return e

    def ellip(self, co, size, r=1.0, rot=(0, 0, 0), stiff=2.0, neg=False):
        """size: half extents (x, y, z) in metres; rot: Euler radians."""
        from mathutils import Euler
        e = self.mb.elements.new(type="ELLIPSOID")
        e.co, e.radius, e.stiffness, e.use_negative = Vector(co), r, stiff, neg
        e.size_x, e.size_y, e.size_z = (s / r for s in size)
        e.rotation = Euler(rot).to_quaternion()
        return e

    def capsule(self, p0, p1, r, stiff=2.0, neg=False):
        p0, p1 = Vector(p0), Vector(p1)
        d = p1 - p0
        e = self.mb.elements.new(type="CAPSULE")
        e.co, e.radius, e.stiffness, e.use_negative = (p0 + p1) / 2, r, stiff, neg
        e.size_x = d.length / 2
        e.rotation = Vector((1, 0, 0)).rotation_difference(d.normalized())
        return e

    def limb(self, pts, radii, stiff=2.0, step=None):
        """Tapered limb through points: overlapping balls along the polyline."""
        pts = [Vector(p) for p in pts]
        for i in range(len(pts) - 1):
            a, b = pts[i], pts[i + 1]
            ra, rb = radii[i], radii[i + 1]
            n = max(2, int((b - a).length / (step or min(ra, rb) * 0.5)))
            for k in range(n + (1 if i == len(pts) - 2 else 0)):
                t = k / n
                self.ball(a.lerp(b, t), ra + (rb - ra) * t, stiff)

    def warts(self, center, size, n, rmin, rmax, seed, filt=None, surface=None):
        """n small balls scattered on an ellipsoid shell (centre, half size)."""
        rnd = random.Random(seed)
        c = Vector(center)
        k = 0
        tries = 0
        while k < n and tries < n * 40:
            tries += 1
            u = Vector((rnd.gauss(0, 1), rnd.gauss(0, 1), rnd.gauss(0, 1))).normalized()
            p = c + Vector((u.x * size[0], u.y * size[1], u.z * size[2]))
            if filt and not filt(p, u):
                continue
            self.ball(p, rnd.uniform(rmin, rmax), 2.5)
            k += 1

    def bake(self, mat, smooth=True):
        dg = bpy.context.evaluated_depsgraph_get()
        dg.update()
        ev = self.obj.evaluated_get(dg)
        me = bpy.data.meshes.new_from_object(ev)
        me.name = self.name
        for p in me.polygons:
            p.use_smooth = smooth
        me.materials.clear()
        me.materials.append(mat)
        o = bpy.data.objects.new(self.name, me)
        bpy.context.scene.collection.objects.link(o)
        bpy.data.objects.remove(self.obj)
        return o


def bump(o, amp, freq, seed=0):
    """Sculpt-like surface noise: push vertices along the normal by smooth noise."""
    me = o.data
    me.update()
    rnd = random.Random(seed)
    ph = [rnd.uniform(0, 6.28) for _ in range(6)]
    for v in me.vertices:
        p = v.co
        n = (math.sin(p.x * freq + ph[0] + 1.7 * math.sin(p.z * freq * 0.6 + ph[1])) *
             math.sin(p.y * freq * 1.3 + ph[2]) + math.sin(p.z * freq * 1.6 + p.x * freq * 0.4 + ph[3])) * 0.5
        v.co = p + v.normal * amp * n
    me.update()


def skin(o, rig, allow=None, power=4.0, top=3, fixed=None):
    """Distance-to-bone weights. allow: bone names this mesh may use (default all
    deforming bones); fixed: one bone name for a rigid part. Adds the armature
    modifier and parents to the rig (call before the rig is rotated)."""
    bones = [b for b in rig.arm.data.bones if (allow is None or b.name in allow)]
    segs = [(b.name, b.head_local.copy(), b.tail_local.copy()) for b in bones]
    groups = {}
    for v in o.data.vertices:
        p = o.matrix_world @ v.co
        if fixed:
            groups.setdefault(fixed, []).append((v.index, 1.0))
            continue
        ws = []
        for nm, h, t in segs:
            d = t - h
            k = max(0.0, min(1.0, (p - h).dot(d) / max(1e-9, d.length_squared)))
            dist = (p - (h + d * k)).length
            ws.append((1.0 / (dist + 0.03) ** power, nm))
        ws.sort(reverse=True)
        ws = ws[:top]
        s = sum(w for w, _ in ws)
        for w, nm in ws:
            groups.setdefault(nm, []).append((v.index, w / s))
    for nm, lst in groups.items():
        vg = o.vertex_groups.new(name=nm)
        for i, w in lst:
            vg.add([i], w, "REPLACE")
    m = o.modifiers.new("arm", "ARMATURE")
    m.object = rig.arm
    o.parent = rig.arm
    return o


def ribbon_strands(name, roots, mat, rig, root_bone, tip_bone_fn, seg=5, rings=6, width=0.03, thick=0.008):
    """Flat tapered ribbons (weeds, moss hair). roots: [(p, dir, length, sway)].
    Weights blend root_bone -> tip_bone_fn(index) along each ribbon."""
    vs, fs, gw = [], [], []
    for si, (p, d, L, sway) in enumerate(roots):
        p, d = Vector(p), Vector(d).normalized()
        side = d.cross(Vector((0, 1, 0)))
        if side.length < 1e-3:
            side = Vector((1, 0, 0))
        side.normalize()
        nrm = side.cross(d).normalized()
        base = len(vs)
        for r in range(rings + 1):
            t = r / rings
            c = p + d * L * t + side * sway * math.sin(t * 3.0 + si) * L * 0.2
            wdt = width * (1 - t) ** 0.7 + 0.002
            for k in range(seg):
                a = 2 * math.pi * k / seg
                vs.append(c + side * math.cos(a) * wdt + nrm * math.sin(a) * thick)
                gw.append((si, t))
        for r in range(rings):
            for k in range(seg):
                a, b = base + r * seg + k, base + r * seg + (k + 1) % seg
                fs.append([a, b, b + seg, a + seg])
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in vs], [], fs)
    for pl in me.polygons:
        pl.use_smooth = True
    me.materials.append(mat)
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    groups = {}
    for i, (si, t) in enumerate(gw):
        tb = tip_bone_fn(si)
        k = min(1.0, t * 1.3)
        groups.setdefault(root_bone, []).append((i, 1 - k))
        groups.setdefault(tb, []).append((i, k))
    for nm, lst in groups.items():
        vg = o.vertex_groups.new(name=nm)
        for i, w in lst:
            vg.add([i], w, "REPLACE")
    m = o.modifiers.new("arm", "ARMATURE")
    m.object = rig.arm
    o.parent = rig.arm
    return o


def finish(o, outline, parts):
    nc.add_rest(o)
    if outline:
        nc.add_outline(o, outline)
        parts.append(o)
    return o

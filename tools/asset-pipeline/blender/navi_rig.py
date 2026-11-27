"""Planar puppet rig + pose sampler + sprite renderer for the Навь sprite pipeline.

Angles are degrees, counter-clockwise as seen from the camera, with the
character facing +X (screen right); each bone's angle is relative to its parent
and to its rest direction. Channels of a pose dict:
  <bone>: angle            relative angle
  "w:<bone>": angle        world angle (0 = +X, CCW); the local angle is solved
  "ik:<side>": (x, z)      ankle target for the two-bone leg chain of that side
  "rx", "rz": metres       root (centre of gravity) offset
  "smear": name or None    which smear crescent is visible on this frame
Keys are (frame, pose, ease); channels missing from a key carry over from the
previous key. Ease names the curve INTO the key: lin, in, out, io, snap, hold.
"""
import bpy, math, json, os, time
from mathutils import Vector, Matrix, Quaternion
import navi_common as nc


def ease(k, kind):
    if kind == "lin":
        return k
    if kind == "in":
        return k * k
    if kind == "out":
        return 1 - (1 - k) * (1 - k)
    if kind == "snap":      # Dead Cells strike: almost all the motion in the first instant
        return 1 - (1 - k) ** 4
    if kind == "hold":
        return 0.0 if k < 1 else 1.0
    return k * k * (3 - 2 * k)  # io


def _lerp(a, b, k):
    if isinstance(a, (tuple, list)):
        return tuple(x + (y - x) * k for x, y in zip(a, b))
    return a + (b - a) * k


def sample(keys, n):
    """keys: [(frame, pose, ease)], returns n full pose dicts for frames 0..n-1."""
    full = []
    cur = {}
    for f, p, e in keys:
        cur = dict(cur)
        cur.update(p)
        full.append((f, cur, e))
    allch = set()
    for _, p, _ in full:
        allch.update(p.keys())
    out = []
    for i in range(n):
        j = 0
        while j + 1 < len(full) and full[j + 1][0] <= i:
            j += 1
        f0, p0, _ = full[j]
        if j + 1 < len(full):
            f1, p1, e1 = full[j + 1]
            k = ease((i - f0) / max(1e-6, f1 - f0), e1)
        else:
            p1, k = p0, 0.0
        q = {}
        for ch in allch:
            a = p0.get(ch, p1.get(ch))
            b = p1.get(ch, a)
            if b is None:
                b = a
            if ch == "smear":
                q[ch] = p0.get("smear")
            elif a is None:
                continue
            else:
                q[ch] = _lerp(a, b, k)
        out.append(q)
    return out


def rot2(v, a_deg):
    a = math.radians(a_deg)
    return Vector((v.x * math.cos(a) - v.y * math.sin(a), v.x * math.sin(a) + v.y * math.cos(a)))


class Rig:
    def __init__(self, name, bones, root="root"):
        """bones: [(name, head, tail, parent)] in metres, character facing +X."""
        arm_d = bpy.data.armatures.new(name)
        self.arm = bpy.data.objects.new(name, arm_d)
        bpy.context.scene.collection.objects.link(self.arm)
        bpy.context.view_layer.objects.active = self.arm
        bpy.ops.object.mode_set(mode="EDIT")
        for bn, h, t, par in bones:
            eb = arm_d.edit_bones.new(bn)
            eb.head, eb.tail = Vector(h), Vector(t)
            eb.roll = 0.0
            if par:
                eb.parent = arm_d.edit_bones[par]
        bpy.ops.object.mode_set(mode="OBJECT")
        self.parent = {bn: par for bn, _, _, par in bones}
        self.head = {bn: Vector((h[0], h[2])) for bn, h, _, _ in bones}
        self.length = {bn: (Vector(t) - Vector(h)).length for bn, h, t, _ in bones}
        self.rest_dir = {}
        for bn, h, t, _ in bones:
            d = Vector(t) - Vector(h)
            self.rest_dir[bn] = math.degrees(math.atan2(d.z, d.x))
        self.root = root
        self.legs = {}
        self.ik_dz = 0.0      # added to every ik target height (ankle height of the model - 0.1)
        for pb in self.arm.pose.bones:
            pb.rotation_mode = "QUATERNION"

    def attach(self, o, bone):
        b = self.arm.data.bones[bone]
        M = self.arm.matrix_world @ b.matrix_local @ Matrix.Translation((0, b.length, 0))
        o.parent = self.arm
        o.parent_type = "BONE"
        o.parent_bone = bone
        o.matrix_parent_inverse = M.inverted()

    def chain(self, bone):
        out = []
        b = self.parent.get(bone)
        while b:
            out.append(b)
            b = self.parent.get(b)
        return out

    def cum(self, bone, ang):
        return sum(ang.get(b, 0.0) for b in self.chain(bone))

    def joint(self, bone, ang, off):
        """2D (x,z) posed position of a bone's head."""
        ch = list(reversed(self.chain(bone))) + [bone]
        pos = self.head[ch[0]] + off
        acc = 0.0
        for i in range(1, len(ch)):
            par = ch[i - 1]
            acc += ang.get(par, 0.0)
            pos = pos + rot2(self.head[ch[i]] - self.head[par], acc)
        return pos

    def solve_ik(self, side, target, ang, off):
        th, sh, l1, l2 = self.legs[side]
        hip = self.joint(th, ang, off)
        D = Vector(target) - hip
        d = max(0.05, min(D.length, l1 + l2 - 1e-3))
        phi = math.degrees(math.atan2(D.x, -D.y))
        al = math.degrees(math.acos(max(-1, min(1, (l1 * l1 + d * d - l2 * l2) / (2 * l1 * d)))))
        kn = math.degrees(math.acos(max(-1, min(1, (l1 * l1 + l2 * l2 - d * d) / (2 * l1 * l2)))))
        rest = self.rest_dir[th] + 90.0  # rest direction measured from straight down
        ang[th] = phi + al - rest - self.cum(th, ang)
        ang[sh] = -(180.0 - kn) - (self.rest_dir[sh] - self.rest_dir[th])

    def solve(self, pose):
        """Local angles (after IK and world-angle channels) and root offset of a pose."""
        ang = {k: v for k, v in pose.items() if isinstance(v, (int, float)) and k in self.parent}
        off = Vector((pose.get("rx", 0.0), pose.get("rz", 0.0)))
        for k, v in pose.items():
            if k.startswith("ik:") and v is not None:
                v = (v[0], v[1] + self.ik_dz)
                self.solve_ik(k[3:], v, ang, off)
        for k, v in pose.items():
            if k.startswith("w:") and v is not None:
                b = k[2:]
                # world angle of the bone = rest_dir + cumulative parents + local
                ang[b] = v - self.rest_dir[b] - self.cum(b, ang)
        return ang, off

    def secondary(self, poses, springs, fps, loop):
        """Follow-through for hanging parts (hair, beard, belt end, amulet): each
        spring bone's tip is a damped point mass pulled toward the bone's rigid
        direction blended toward gravity, constrained to the bone length, simulated
        over the sampled poses (loops: three cycles, the last one kept so the cycle
        closes). Returns per-frame {bone: local angle}."""
        n = len(poses)
        out = [{} for _ in range(n)]
        if not springs or n == 0:
            return out
        sols = [self.solve(p) for p in poses]
        sub = 6
        dt = 1.0 / fps / sub
        for sp in springs:
            b = sp["bone"]
            L = max(0.02, self.length[b])
            heads = [self.joint(b, a, o) for a, o in sols]
            wr = [self.rest_dir[b] + self.cum(b, a) for a, o in sols]

            def tgt(a):
                d = ((-90.0 - a + 180.0) % 360.0) - 180.0
                return a + sp.get("g", 0.3) * d

            def tip(h, a):
                r = math.radians(a)
                return h + Vector((math.cos(r), math.sin(r))) * L
            p = tip(heads[0], tgt(wr[0]))
            pv = p.copy()
            k, damp = sp.get("k", 260.0), sp.get("damp", 0.86)
            for c in range(3 if loop else 1):
                for i in range(n):
                    if c == (2 if loop else 0):
                        d = p - heads[i]
                        a = math.degrees(math.atan2(d.y, d.x)) - wr[i]
                        out[i][b] = ((a + 180.0) % 360.0) - 180.0
                    j = (i + 1) % n if loop else min(i + 1, n - 1)
                    da = ((wr[j] - wr[i] + 180.0) % 360.0) - 180.0
                    for s in range(sub):
                        t = (s + 1) / sub
                        h = heads[i].lerp(heads[j], t)
                        q = tip(h, tgt(wr[i] + da * t))
                        npos = p + (p - pv) * damp + (q - p) * k * dt * dt
                        dd = npos - h
                        npos = h + dd.normalized() * L
                        pv, p = p, npos
        return out

    def apply(self, pose, extra=None):
        ang, off = self.solve(pose)
        if extra:
            ang.update(extra)
        for pb in self.arm.pose.bones:
            q_rest = pb.bone.matrix_local.to_quaternion()
            R = Quaternion((0, -1, 0), math.radians(ang.get(pb.name, 0.0)))
            pb.rotation_quaternion = q_rest.inverted() @ R @ q_rest
            if pb.name == self.root:
                pb.location = q_rest.inverted() @ Vector((off.x, 0.0, off.y))


_saved = {}


def _swap_materials(mat):
    """mat: put `mat` in every material slot of every mesh; None: restore the originals."""
    for me in bpy.data.meshes:
        if mat is not None:
            _saved.setdefault(me.name, [m for m in me.materials])
            for i in range(len(me.materials)):
                me.materials[i] = mat
        elif me.name in _saved:
            for i, m in enumerate(_saved[me.name]):
                me.materials[i] = m
    if mat is None:
        _saved.clear()


def render_anims(rig, anims, raw_dir, smears, outlined, prefix, springs=None, on_frame=None):
    """anims: {name: dict(keys=[...], frames=n, fps=f, loop=bool)}. Renders colour and
    normal passes of every frame to raw_dir/<anim>_<i>_c.png / _n.png; returns meta + timings."""
    os.makedirs(raw_dir, exist_ok=True)
    sc = bpy.context.scene
    nm = nc.normal_mat()
    meta = {}
    t_total = time.time()
    n_frames = 0
    for name, spec in anims.items():
        poses = sample(spec["keys"], spec["frames"])
        extra = rig.secondary(poses, springs, spec["fps"], spec.get("loop", False))
        for pass_ in ("c", "n"):
            normal = pass_ == "n"
            _swap_materials(nm if normal else None)
            sc.view_settings.view_transform = "Raw" if normal else "Standard"
            for o in outlined:
                if "outline" in o.modifiers:
                    o.modifiers["outline"].show_render = not normal
            for i, p in enumerate(poses):
                rig.apply(p, extra[i])
                if on_frame:   # non-bone channels (shape keys, emission) per frame
                    on_frame(p)
                for sn, so in smears.items():
                    so.hide_render = normal or p.get("smear") != sn
                sc.render.filepath = os.path.join(raw_dir, "%s_%02d_%s.png" % (name, i, pass_))
                bpy.ops.render.render(write_still=True)
                n_frames += 1 if normal else 0
        _swap_materials(None)
        meta[name] = {"frames": spec["frames"], "fps": spec["fps"], "loop": spec.get("loop", False)}
    dt = time.time() - t_total
    mp = os.path.join(raw_dir, "meta.json")
    if os.path.exists(mp):   # partial re-render (--only): keep the other animations
        old = json.load(open(mp)).get("anims", {})
        old.update(meta)
        meta = old
    meta_all = {"prefix": prefix, "anims": meta, "render_s": round(dt, 1), "frames": n_frames,
                "s_per_frame_both_passes": round(dt / max(1, n_frames), 2),
                "render_px": [sc.render.resolution_x, sc.render.resolution_y]}
    with open(os.path.join(raw_dir, "meta.json"), "w") as f:
        json.dump(meta_all, f, indent=1)
    print("RENDERED", n_frames, "frames in", round(dt, 1), "s")
    return meta_all

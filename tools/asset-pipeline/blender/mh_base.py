"""Hero base body from the CC0 MakeHuman base mesh (system Python + numpy).

    python3 tools/asset-pipeline/blender/mh_base.py <makehuman_data_dir> <out.json.gz>

<makehuman_data_dir> is `makehuman/data` of github.com/makehumancommunity/makehuman
(assets CC0 since September 2020, see LICENSE.ASSETS.md there; fetch with
tools/asset-pipeline/blender/fetch_makehuman.sh). Steps:
  1. base.obj (hm08) + macro targets (young caucasian male, lean muscular build);
  2. stylisation: slightly bigger head, hands and feet (game read at 160 px);
  3. FK re-pose with the MakeHuman default skeleton and its CC0 skin weights:
     A-pose -> arms hanging, near hand closed in a grip (for the stick), far hand
     relaxed; linear-blend skinning;
  4. converted to Blender metres, character facing +X, character's left = +Y;
  5. the 163 MakeHuman bones' weights folded onto the 14 bones of our planar rig.
Writes verts, faces + UVs of the body, the eye meshes, rig weights and joints.
Only this derived file is used by build_hero.py; the MakeHuman repo is not shipped.
"""
import gzip, json, math, os, sys
import numpy as np

TARGETS = [("macrodetails/caucasian-male-young.target", 1.0),
           ("macrodetails/universal-male-young-maxmuscle-minweight.target", 0.55),
           ("macrodetails/height/male-young-maxmuscle-averageweight-maxheight.target", 0.25)]
STYLE = {"head": 1.05, "ha": 1.3, "ft": 1.12}
# heroic build (fallen bogatyr at 160 px): chest/shoulder width, limb and neck girth, leg length
HERO = {"chest_w": 1.3, "chest_d": 1.15, "upper_arm": 1.28, "forearm": 1.25, "neck": 1.4, "thigh": 1.12, "leg_len": 0.9}
HEIGHT_M = 1.72          # crown height after stylisation (hair adds ~6 cm)
# MakeHuman bone -> rig bone; bones not listed inherit their parent's rig bone.
MAP = {"root": "hips", "spine05": "hips", "pelvis.L": "hips", "pelvis.R": "hips",
       "spine04": "spine", "neck01": "spine", "neck02": "head",
       "shoulder01": "up", "upperarm01": "up", "lowerarm01": "fo", "wrist": "ha",
       "upperleg01": "th", "lowerleg01": "sh", "foot": "ft"}


def load_obj(p):
    V, VT, F, g = [], [], [], None
    for line in open(p):
        if line.startswith("v "):
            V.append([float(x) for x in line.split()[1:4]])
        elif line.startswith("vt "):
            VT.append([float(x) for x in line.split()[1:3]])
        elif line.startswith("g "):
            g = line.split()[1]
        elif line.startswith("f "):
            c = []
            for t in line.split()[1:]:
                a = t.split("/")
                c.append((int(a[0]) - 1, int(a[1]) - 1 if len(a) > 1 and a[1] else -1))
            F.append((g, c))
    return np.array(V), np.array(VT), F


def load_target(p):
    idx, d = [], []
    for line in open(p):
        if line[:1].isdigit():
            a = line.split()
            idx.append(int(a[0])); d.append([float(x) for x in a[1:4]])
    return np.array(idx), np.array(d)


def rodrigues(axis, ang):
    a = np.asarray(axis, float); a = a / (np.linalg.norm(a) + 1e-12)
    K = np.array([[0, -a[2], a[1]], [a[2], 0, -a[0]], [-a[1], a[0], 0]])
    return np.eye(3) + math.sin(ang) * K + (1 - math.cos(ang)) * K @ K


def rot_between(a, b):
    a = a / np.linalg.norm(a); b = b / np.linalg.norm(b)
    ax = np.cross(a, b)
    s = np.linalg.norm(ax)
    if s < 1e-9:
        return np.eye(3)
    return rodrigues(ax, math.atan2(s, float(a @ b)))


def T(R, h):
    M = np.eye(4); M[:3, :3] = R; M[:3, 3] = h - R @ h
    return M


def _bone_w(wt, names, nv):
    a = np.zeros(nv)
    for b in names:
        for vi, x in wt.get(b, []):
            a[vi] += x
    return np.clip(a, 0, 1)


def _radial(V, w, h, t, s):
    """Scale the girth around the bone axis h->t by s, weighted per vertex."""
    d = (t - h) / np.linalg.norm(t - h)
    p = V - h
    along = (p @ d)[:, None] * d
    return V + w[:, None] * (s - 1) * (p - along)


def heroic(V, RW, sk, bones, wt, joint):
    """Bulky, heroic proportions in MakeHuman space (X left, Y up, Z front)."""
    nv = len(V)
    V = V.copy()
    J = lambda n: joint(n)
    # shorter legs: compress the legs toward the ankles, drop everything above
    hip_y = (J("upperleg01.L____head")[1] + J("upperleg01.R____head")[1]) / 2
    ank_y = (J("foot.L____head")[1] + J("foot.R____head")[1]) / 2
    k = HERO["leg_len"]
    drop = (1 - k) * (hip_y - ank_y)
    wl = np.clip(RW["thL"] + RW["thR"] + RW["shL"] + RW["shR"] + RW["ftL"] + RW["ftR"], 0, 1)
    y = V[:, 1]
    fl = np.where(y < ank_y, y - drop * 0 + 0 * y, ank_y + (y - ank_y) * k)
    fl = np.where(y < ank_y, y, fl)
    V[:, 1] = wl * fl + (1 - wl) * (y - drop)
    # chest and shoulders: widen the upper torso, arms move out with it
    waist = J("spine04____head")[1]; chest = J("neck01____head")[1]
    ramp = np.clip((V[:, 1] - waist) / (chest - waist), 0, 1) ** 1.2
    ws = RW["spine"] * ramp
    V[:, 0] *= 1 + ws * (HERO["chest_w"] - 1)
    zc = J("spine02____head")[2] - 0.2
    V[:, 2] = zc + (V[:, 2] - zc) * (1 + ws * (HERO["chest_d"] - 1))
    wa = {s: np.clip(RW["up" + s] + RW["fo" + s] + RW["ha" + s], 0, 1) for s in "LR"}
    for s, sx in (("L", 1), ("R", -1)):
        sh = J("upperarm01.%s____head" % s)
        V[:, 0] += wa[s] * sx * abs(sh[0]) * (HERO["chest_w"] - 1) * 0.85
    def jn(n):   # joint of the current (already reshaped) mesh
        return V[sk["joints"][n]].mean(axis=0)
    for s in "LR":
        V = _radial(V, _bone_w(wt, ["upperarm01." + s, "upperarm02." + s, "shoulder01." + s], nv), jn("upperarm01.%s____head" % s), jn("lowerarm01.%s____head" % s), HERO["upper_arm"])
        V = _radial(V, _bone_w(wt, ["lowerarm01." + s, "lowerarm02." + s], nv), jn("lowerarm01.%s____head" % s), jn("wrist.%s____head" % s), HERO["forearm"])
        V = _radial(V, _bone_w(wt, ["upperleg01." + s, "upperleg02." + s], nv), jn("upperleg01.%s____head" % s), jn("lowerleg01.%s____head" % s), HERO["thigh"])
    V = _radial(V, _bone_w(wt, ["neck01", "neck02", "neck03"], nv), jn("neck01____head"), jn("head____head"), HERO["neck"])
    return V


def main(data, out):
    V, VT, F = load_obj(os.path.join(data, "3dobjs/base.obj"))
    for t, w in TARGETS:
        i, d = load_target(os.path.join(data, "targets", t))
        V[i] += w * d
    sk = json.load(open(os.path.join(data, "rigs/default.mhskel")))
    wt = json.load(open(os.path.join(data, "rigs/default_weights.mhw")))["weights"]
    bones = sk["bones"]
    order, seen = [], set()

    def visit(b):
        if b in seen:
            return
        p = bones[b]["parent"]
        if p:
            visit(p)
        seen.add(b); order.append(b)
    for b in bones:
        visit(b)

    def rigname(b):
        while b:
            base, _, side = b.partition(".")
            if base in MAP or b in MAP:
                n = MAP.get(b, MAP.get(base))
                return n + ({"R": "R", "L": "L"}[side] if n in ("up", "fo", "ha", "th", "sh", "ft") else "")
            b = bones[b]["parent"]
        return "hips"
    rmap = {b: rigname(b) for b in bones}
    nv = len(V)
    RW = {}
    for b, lst in wt.items():
        rb = rmap.get(b, "hips")
        arr = RW.setdefault(rb, np.zeros(nv))
        for vi, w in lst:
            arr[vi] += w
    tot = sum(RW.values()); tot[tot == 0] = 1
    for k in RW:
        RW[k] /= tot

    def joint(name):
        return V[sk["joints"][name]].mean(axis=0)
    # stylisation: weighted scale about the bone's pivot
    for key, s in STYLE.items():
        for side in (["L", "R"] if key != "head" else [""]):
            rb = key + side
            piv = {"head": "neck02____head", "ha": "wrist.%s____head" % side, "ft": "foot.%s____head" % side}[key]
            c = joint(piv)
            w = RW[rb][:, None]
            V = V + w * (s - 1) * (V - c)

    V = heroic(V, RW, sk, bones, wt, joint)
    H = {b: joint(bones[b]["head"]) for b in bones}
    Tl = {b: joint(bones[b]["tail"]) for b in bones}
    R = {b: np.eye(3) for b in bones}
    # arms down (slightly away from the hips), forearms straight
    for s, sx in (("L", 1), ("R", -1)):
        sh, el, wr = H["upperarm01." + s], H["lowerarm01." + s], H["wrist." + s]
        R["upperarm01." + s] = rot_between(el - sh, np.array([0.1 * sx, -1, 0.02]))
        Ru = R["upperarm01." + s]
        R["lowerarm01." + s] = rot_between(wr - el, Ru.T @ np.array([0.06 * sx, -1, 0.0]))
    # legs straight under the hips (no A-stance splay), feet forward
    for s in ("L", "R"):
        hp, kn, an = H["upperleg01." + s], H["lowerleg01." + s], H["foot." + s]
        d = an - hp
        R["upperleg01." + s] = rot_between(kn - hp, np.array([0.0, d[1], d[2]]) * 0 + np.array([0.0, -(hp - kn)[1], (kn - hp)[2]]))
        Ru = R["upperleg01." + s]
        R["lowerleg01." + s] = rot_between(an - kn, Ru.T @ np.array([0.0, (an - kn)[1], (an - kn)[2]]))
    # fingers: palm normal signed toward the thumb base, curl toward it
    for s, curl, thumb in (("R", (78, 92, 60), (18, 30, 25)), ("L", (22, 30, 18), (8, 12, 10))):
        k2, k5, wr = H["finger2-1." + s], H["finger5-1." + s], H["wrist." + s]
        n = np.cross(k2 - wr, k5 - wr); n /= np.linalg.norm(n)
        if (H["finger1-2." + s] - (k2 + k5 + wr) / 3) @ n < 0:
            n = -n
        for f in range(2, 6):
            for seg in range(1, 4):
                b = "finger%d-%d.%s" % (f, seg, s)
                d = Tl[b] - H[b]
                R[b] = rodrigues(np.cross(d, n), math.radians(curl[seg - 1] * (1.0 - 0.06 * (f - 2))))
        for seg in range(1, 4):
            b = "finger1-%d.%s" % (seg, s)
            d = Tl[b] - H[b]
            R[b] = rodrigues(np.cross(d, n), math.radians(thumb[seg - 1]))
    G = {}
    for b in order:
        L = T(R[b], H[b])
        p = bones[b]["parent"]
        G[b] = G[p] @ L if p else L
    # skin with the original 163-bone weights
    acc = np.zeros((nv, 3)); wsum = np.zeros(nv)
    Vh = np.c_[V, np.ones(nv)]
    for b, lst in wt.items():
        if b not in G:
            continue
        idx = np.array([i for i, _ in lst]); w = np.array([x for _, x in lst])
        acc[idx] += w[:, None] * (Vh[idx] @ G[b].T)[:, :3]
        wsum[idx] += w
    P = V.copy()
    m = wsum > 0
    P[m] = acc[m] / wsum[m][:, None]
    PH = {b: (G[b] @ np.r_[H[b], 1])[:3] for b in bones}
    PT = {b: (G[b] @ np.r_[Tl[b], 1])[:3] for b in bones}

    body_f = [c for g, c in F if g == "body"]
    eye_f = [c for g, c in F if g in ("helper-l-eye", "helper-r-eye")]
    used = sorted({vi for c in body_f + eye_f for vi, _ in c})
    remap = {vi: k for k, vi in enumerate(used)}
    body_v = np.array([vi for vi in used])
    ys = P[body_v, 1]
    s = HEIGHT_M / (ys.max() - ys.min())
    y0 = ys.min()
    cx = PH["root"][2]

    def conv(p):   # MH (X left, Y up, Z front) -> Blender (x front, y left, z up), metres
        return [round((p[2] - cx) * s, 5), round(p[0] * s, 5), round((p[1] - y0) * s, 5)]
    out_v = [conv(P[vi]) for vi in used]
    joints = {}
    for b in bones:
        joints[b] = conv(PH[b]); joints[b + "@tail"] = conv(PT[b])
    rw = {}
    for k, arr in RW.items():
        lst = [[remap[vi], round(float(arr[vi]), 4)] for vi in used if arr[vi] > 1e-3]
        if lst:
            rw[k] = lst
    res = {"source": "MakeHuman hm08 base.obj + targets + default skeleton/weights (CC0)",
           "verts": out_v,
           "faces": [[remap[vi] for vi, _ in c] for c in body_f],
           "uvs": [[[round(VT[ti][0], 5), round(VT[ti][1], 5)] for _, ti in c] for c in body_f],
           "eye_faces": [[remap[vi] for vi, _ in c] for c in eye_f],
           "weights": rw, "joints": joints}
    with gzip.open(out, "wt") as f:
        json.dump(res, f, separators=(",", ":"))
    print("base: %d verts, %d faces, %d eye faces, height %.2f m -> %s" % (len(out_v), len(body_f), len(eye_f), HEIGHT_M, out))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])

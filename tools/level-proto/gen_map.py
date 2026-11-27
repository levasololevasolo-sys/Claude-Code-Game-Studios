#!/usr/bin/env python3
"""Throwaway prototype of the location layout generator (design/gdd/level-structure.md).

Not game code. It does three things:
  1. holds the draft Swamp room templates as ASCII grids, checks them against the hero
     jump metrics (single jump only, as the Godot port has today) and writes
     assets/data/room_templates_swamp_draft.json;
  2. lays out one Swamp level per seed with the GDD algorithm (main path, forks with
     2-3 trails, trails reconverging in a junction, side branches, descent by depth bands);
  3. draws schematic maps and a sheet of sample rooms with PIL.

Usage: python3 gen_map.py <repo_root> <out_dir>
"""
import json
import random
import sys
from collections import deque

from PIL import Image, ImageDraw, ImageFont

# ---------------------------------------------------------------- grid constants
CELL_PX = 40          # tuning.json "cell"
MOD_W, MOD_H = 16, 9  # tuning.json "module_w" / "module_h"
# Jump metrics from tuning.json: jump_speed 860, gravity 2300, run_speed 360, dash 980 x 0.17 s.
# Rise = 860^2 / (2*2300) = 160.8 px = 4.0 cells. Safe authoring rise = 3 cells.
# Flat jump air time = 2*860/2300 = 0.748 s -> 269 px = 6.7 cells. Safe gap = 5 cells, 8 with air dash.
RISE_MAX = 3
GAP_MAX = 5
LINK_MAX = 6   # max 1x1 links on one trail between its shrine and the junction
WATER_RISE = 2

SOLID = set("#S")
ONEWAY = set("=B")
HAZARD = set("^")

# ---------------------------------------------------------------- templates
# kind: entry corr bridge arena hall shaft climb nook secret gauntlet fork altar junction lairgate
T = []


def tpl(tid, name, kind, w, h, rows, weight=1.0, tier_min=1, notes=""):
    W, H = w * MOD_W, h * MOD_H
    assert len(rows) == H, (tid, len(rows), H)
    fixed = []
    for i, r in enumerate(rows):
        if len(r) < W:  # authoring helper: pad interior before the last char
            r = r[:-1] + "." * (W - len(r)) + r[-1]
        assert len(r) == W, (tid, i, len(r), W, r)
        fixed.append(r)
    T.append(dict(id=tid, name=name, kind=kind, w=w, h=h, grid=fixed, weight=weight,
                  tier_min=tier_min, notes=notes))


tpl("sw_entry_01", "Вход: поваленный дуб", "entry", 2, 1, [
    "################################",
    "####...........................#",
    "##.............................#",
    "#..............................#",
    "#..............................D",
    "#...........=====..............D",
    "#..P...........................D",
    "#..............................D",
    "################################",
], notes="без врагов, тихий старт")

tpl("sw_corr_01", "Гнилые мостки", "corr", 2, 1, [
    "################################",
    "#..............................#",
    "#..............................#",
    "#..............................#",
    "D..............................D",
    "D.........=====......B.........D",
    "D..............................D",
    "D.....E.....~~~~~~~~~~~...E....D",
    "################################",
], notes="первая стая, кочка Болотницы над водой")

tpl("sw_corr_02", "Сухая гать", "corr", 2, 1, [
    "################################",
    "########..............#########",
    "####.......................#####",
    "#..............................#",
    "D..............................D",
    "D....====..........====........D",
    "D..............................D",
    "D....~~~~.E.........~~~~E......D",
    "################################",
], notes="низкий потолок, тесная драка; в полу две бочажины")

tpl("sw_bridge_01", "Мост над чёрной водой", "bridge", 3, 2, [
    "################################################",
    "#..............................................#",
    "#..............................................#",
    "#..............................................#",
    "D..............................................D",
    "D..............................................D",
    "D...................F..........................D",
    "D..............................................D",
    "#####====....=====....====....=====....========#",
    "#..............................................#",
    "#..............................................#",
    "#==.....................................==.....#",
    "#..............................................#",
    "#..............................................#",
    "#...===.............................===........#",
    "#..............................................#",
    "#~~~~~~~~~^^^^~~~~~~~..~~~~~~~~~~^^^^~~~~~~~~~~#",
    "######################DDDD######################",
], notes="мостки с дырами по 4 клетки; упал: вылезай по уступам у стен или ныряй в сток вниз")

tpl("sw_shaft_01", "Колодец корней", "shaft", 1, 3, [
    "######DDDD######",
    "#..............#",
    "#...===........#",
    "#..............#",
    "#..............#",
    "#.=====........#",
    "#..............#",
    "#..............#",
    "#.........=====#",
    "#..............#",
    "#.......F......#",
    "#=====.........#",
    "#..............#",
    "D..............#",
    "D.........=====#",
    "D..............#",
    "D..............#",
    "######.........#",
    "#..............#",
    "#..............#",
    "#.........=====#",
    "#..............#",
    "#..............#",
    "#=====.........#",
    "#..............#",
    "#..............#",
    "######DDDD######",
], notes="середина свободна: можно упасть сразу на дно; уступы зигзагом дают подъём назад")

tpl("sw_arena_01", "Кочкарник", "arena", 3, 2, [
    "######################DDDD######################",
    "#..............................................#",
    "#..............................................#",
    "#..............................................#",
    "#..............................................#",
    "#..............................................#",
    "#..............................................#",
    "#..............................................#",
    "#.........=====...................=====........#",
    "#..............................................#",
    "#..............................................#",
    "#.....====..........======...........====.....#",
    "#..............................................#",
    "D..............................................D",
    "D..........B.B..........F.........B.B..........D",
    "D..............................................D",
    "D....E.......~~~~~~~~.......E.....~~~~~~.......D",
    "################################################",
], weight=1.2, notes="главная арена Топи: две стаи, летун, кочки")

tpl("sw_hall_01", "Пещера под корнями", "hall", 2, 2, [
    "######DDDD######################",
    "####...........................#",
    "##.............................#",
    "#..............................#",
    "#..............................D",
    "#..............................D",
    "#......................C.......D",
    "#..............................D",
    "#==...............=============#",
    "#..............................#",
    "#..............................#",
    "#.............=====............#",
    "#..............................#",
    "D..............................D",
    "D...=====..........====........D",
    "D..............................D",
    "D....E.................E.......D",
    "################################",
], notes="сундук на верхней полке у бокового выхода")

tpl("sw_climb_01", "Подъём по корням", "climb", 1, 2, [
    "################",
    "#..............#",
    "#..............#",
    "#..............#",
    "D..............D",
    "D..............D",
    "D..............D",
    "D..............D",
    "####........####",
    "#..............#",
    "#..............#",
    "#..====........#",
    "#..............#",
    "D..............D",
    "D.........====.D",
    "D..............D",
    "D..............D",
    "######DDDD######",
], notes="двусторонний подъём на модуль вверх, ступени по 3 клетки")

tpl("sw_nook_01", "Закуток с сундуком", "nook", 1, 1, [
    "################",
    "#######........#",
    "####...........#",
    "#..............#",
    "D..............#",
    "D.......===....#",
    "D..............#",
    "D...........C..#",
    "################",
], notes="тупик ветки; зеркалится")

tpl("sw_secret_01", "Тайник за корнями", "secret", 1, 1, [
    "################",
    "################",
    "####........####",
    "###.........S..#",
    "#...........S..D",
    "#...........S..D",
    "#...........S..D",
    "#..C...^^...S..D",
    "################",
], notes="ломкая стена S видна трещиной со стороны комнаты; 3 удара")

tpl("sw_gauntlet_01", "Клюквенная гать", "gauntlet", 3, 1, [
    "################################################",
    "#..............................................#",
    "#..............................................#",
    "#.................===..........===.............#",
    "D..............................................D",
    "D......===....==........==...==.....==..===....D",
    "D..............................................D",
    "D....^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^....D",
    "################################################",
], notes="испытание: пол из шипов, прыжки по кочкам; награда в конце ветки")

tpl("sw_fork_01", "Распутье у идола", "fork", 3, 2, [
    "######################DDDD######################",
    "#..............................................#",
    "#..............................................#",
    "#..............................................#",
    "D..............................................#",
    "D..............................................#",
    "D......................H.......................#",
    "D..............................................#",
    "########....=========================....#######",
    "#..............................................#",
    "#..............................................#",
    "#...........====................====...........#",
    "#..............................................#",
    "D..............................................D",
    "D...................=====......................D",
    "D..............................................D",
    "D.G..G...............................G.......G.D",
    "######DDDD############################DDDD######",
], weight=1.0, notes="идол-ориентир; G = врата тропы со знаком награды; войдёшь в одни, прочие зарастают корнями")

tpl("sw_altar_01", "Капище в трясине", "altar", 2, 1, [
    "################################",
    "#..............................#",
    "#..............................#",
    "#..............................#",
    "D..............................D",
    "D..............................D",
    "D..............H...............D",
    "D..........##########..........D",
    "######################DDDD######",
], notes="конец тропы: здесь награда, обещанная вратами")

tpl("sw_junction_01", "Затопленный зал", "junction", 4, 1, [
    "######DDDD############DDDD############DDDD############DDDD######",
    "#..............................................................#",
    "#..............................................................#",
    "#..............................................................#",
    "D..............................................................D",
    "D..............................................................D",
    "D..............................................................D",
    "D.....~~~~~~~~~..........~~~~~~~~~~~~...........~~~~~~~~.......D",
    "######################DDDD############DDDD######################",
], notes="узел: сюда падают все тропы развилки; без боя, вздох перед спуском")

tpl("sw_lairgate_01", "Спуск к логову", "lairgate", 2, 2, [
    "######DDDD######################",
    "#..............................#",
    "#..............................#",
    "#..............................#",
    "D..............................#",
    "D..............................#",
    "D..............................#",
    "D..............................#",
    "########.......................#",
    "#..............................#",
    "#..............................#",
    "#.........=====................#",
    "#..............................#",
    "#..............................#",
    "#.................=====........#",
    "#..............................#",
    "#......H................L......#",
    "################################",
], notes="самая глубокая точка; L = дверь логова; H = последний родник/алтарь перед боссом")

KIND_RU = {
    "entry": "вход", "corr": "проход", "bridge": "мост над ямой", "arena": "арена",
    "hall": "пещерный зал", "shaft": "шахта вниз", "climb": "подъём", "nook": "закуток",
    "secret": "тайник", "gauntlet": "испытание", "fork": "распутье", "altar": "капище (награда)",
    "junction": "узел", "lairgate": "спуск к логову", "link": "связка",
}


# ---------------------------------------------------------------- template analysis
def sockets_of(g, w, h):
    """Read sockets from D cells on the border; check they sit at the standard spots."""
    W, H = w * MOD_W, h * MOD_H
    socks = []
    for m in range(h):
        rows = range(m * MOD_H + 4, m * MOD_H + 8)
        for side, col in (("L", 0), ("R", W - 1)):
            ds = [r for r in rows if g[r][col] == "D"]
            if ds:
                assert len(ds) == 4, ("side socket must be 4 tall", side, m)
                socks.append((side, m))
    for c in range(w):
        cols = range(c * MOD_W + 6, c * MOD_W + 10)
        for side, row in (("T", 0), ("B", H - 1)):
            ds = [x for x in cols if g[row][x] == "D"]
            if ds:
                assert len(ds) == 4, ("vertical socket must be 4 wide", side, c)
                socks.append((side, c))
    # no stray D on the border
    nd = sum(1 for r in range(H) for x in range(W) if g[r][x] == "D")
    assert nd == 4 * len(socks), "stray D"
    return socks


def passable(ch):
    return ch not in SOLID and ch not in HAZARD


def standable(g, r, x):
    H, W = len(g), len(g[0])
    if not (0 <= r < H - 1 and 0 <= x < W):
        return False
    ch = g[r][x]
    if not passable(ch) or ch in ONEWAY:
        return False
    below = g[r + 1][x]
    if below in SOLID or below in ONEWAY:
        return r == 0 or g[r - 1][x] not in SOLID  # headroom: hero is 1.6 cells
    return False


def clear_col(g, x, r0, r1):
    lo, hi = min(r0, r1), max(r0, r1)
    return all(g[r][x] not in SOLID for r in range(max(lo, 0), hi + 1))


def clear_row(g, r, x0, x1):
    lo, hi = min(x0, x1), max(x0, x1)
    if r < 0:
        return True
    return all(g[r][x] not in SOLID for x in range(lo, hi + 1))


def neighbours(g, r, x):
    """Coarse jump model: walk, jump up <= RISE_MAX, gap <= GAP_MAX, fall with drift."""
    H, W = len(g), len(g[0])
    rise = WATER_RISE if g[r][x] == "~" else RISE_MAX
    out = []
    for dx in range(-GAP_MAX - 4, GAP_MAX + 5):
        for dr in range(-rise, H):
            r2, x2 = r + dr, x + dx
            if (dx, dr) == (0, 0) or not standable(g, r2, x2):
                continue
            if dr <= 0:  # jump up or level
                if abs(dx) > GAP_MAX:
                    continue
                apex = min(r, r2) - 1
                if clear_col(g, x, r, apex) and clear_row(g, apex, x, x2) and clear_row(g, apex + 1, x, x2):
                    out.append((r2, x2))
            else:  # drop down, drift grows with fall height
                if abs(dx) > GAP_MAX + dr // 2:
                    continue
                if clear_row(g, r - 1, x, x2) and clear_col(g, x2, r, r2):
                    out.append((r2, x2))
    return out


def socket_cells(g, w, h, s):
    side, m = s
    W, H = w * MOD_W, h * MOD_H
    if side == "L":
        return [(m * MOD_H + 7, 0), (m * MOD_H + 7, 1)]
    if side == "R":
        return [(m * MOD_H + 7, W - 1), (m * MOD_H + 7, W - 2)]
    if side == "T":  # standing spots from which a hop up through the hole works
        return [(r, x) for r in range(0, 2) for x in range(m * MOD_W + 2, m * MOD_W + 14)]
    return [(r, x) for r in range(H - 3, H - 1) for x in range(m * MOD_W + 6, m * MOD_W + 10)]


def analyse(t):
    g = [list(r) for r in t["grid"]]
    # sockets count as floor-level walkable openings: give side sockets a temporary floor
    w, h = t["w"], t["h"]
    socks = sockets_of(t["grid"], w, h)
    for r in range(len(g)):
        for x in range(len(g[0])):
            if g[r][x] in "DS":  # socket = opening; breakable wall = open after 3 hits
                g[r][x] = "."
    H = len(g)
    stands = {(r, x) for r in range(H) for x in range(len(g[0])) if standable(g, r, x)}
    adj = {p: neighbours(g, *p) for p in stands}

    def reach(starts):
        seen = set(p for p in starts if p in stands)
        dq = deque(seen)
        while dq:
            p = dq.popleft()
            for q in adj[p]:
                if q not in seen:
                    seen.add(q)
                    dq.append(q)
        return seen

    def entry_spots(s):
        side, m = s
        if side == "T":  # falling in from the top hole: land where the column ends
            spots = set()
            for x in range(m * MOD_W + 2, m * MOD_W + 14):
                for r in range(H):
                    if (r, x) in stands:
                        spots.add((r, x))
                        break
            return spots
        if side == "B":  # climbing in from below: needs the room below to throw the hero up
            return {p for p in stands if p[0] >= H - 1 - RISE_MAX - 1 and m * MOD_W + 2 <= p[1] < m * MOD_W + 14}
        return set(p for p in socket_cells(g, w, h, s) if p in stands)

    def exit_ok(s, region):
        side, m = s
        if side in "LR":
            return bool(region & set(socket_cells(g, w, h, s)))
        if side == "B":  # walk to the hole and fall in
            return any(p[0] >= H - 1 - RISE_MAX - 1 and m * MOD_W + 2 <= p[1] < m * MOD_W + 14 for p in region)
        return any(p[0] <= 1 for p in region if m * MOD_W + 2 <= p[1] < m * MOD_W + 14)

    info = []
    for s in socks:
        reg = reach(entry_spots(s))
        info.append(dict(side=s[0], module=s[1], reaches=[f"{o[0]}{o[1]}" for o in socks if o != s and exit_ok(o, reg)]))
    marks = {}
    for r in range(H):
        for x in range(len(g[0])):
            ch = t["grid"][r][x]
            if ch in "EFCHPGLBS":
                marks.setdefault(ch, []).append([x, r])
    # every floor marker must be reachable from at least one socket (or P)
    all_reg = set()
    for s in socks:
        all_reg |= reach(entry_spots(s))
    if "P" in marks:
        all_reg |= reach({(r, x) for x, r in marks["P"]})
    unreachable = []
    for ch in "ECHGL":
        for x, r in marks.get(ch, []):
            if not any((r + dr, x + dx) in all_reg for dr in (0, 1) for dx in range(-1, 2)):
                unreachable.append(f"{ch}@{x},{r}")
    for x, r in marks.get("S", []):
        pass  # wall: hit from the side
    return socks, info, marks, unreachable


def export_templates(path):
    out = {
        "_note": ("Черновик библиотеки комнат-заготовок Топи, design/gdd/level-structure.md §3.2. "
                  "Клетка 40 px, модуль 16x9 клеток. grid: строка 0 сверху. "
                  "# твердь, . пусто, = мостки (сквозь снизу), ^ шипы, ~ трясина (медленно, прыжок ниже), "
                  "D гнездо, E стая, F летун, B кочка Болотницы, C сундук, S ломкая стена, H капище/родник/идол, "
                  "P старт героя, G врата тропы, L дверь логова. "
                  "Проверено прототипом tools/level-proto/gen_map.py: подъём <= 3 клетки, прыжок через яму <= 5."),
        "cell": CELL_PX, "module_w": MOD_W, "module_h": MOD_H,
        "jump": {"rise_cells": RISE_MAX, "gap_cells": GAP_MAX, "water_rise_cells": WATER_RISE,
                 "source": "tuning.json jump_speed 860, gravity 2300, run_speed 360, dash_speed 980 x dash_time 0.17"},
        "templates": [],
    }
    report = []
    for t in T:
        socks, info, marks, bad = analyse(t)
        t["sockets"] = socks
        t["socket_info"] = info
        out["templates"].append({
            "id": t["id"], "name": t["name"], "kind": t["kind"], "w": t["w"], "h": t["h"],
            "weight": t["weight"], "tier_min": t["tier_min"], "mirror": True,
            "sockets": [{"side": s, "module": m} for s, m in socks],
            "reach": {f"{i['side']}{i['module']}": i["reaches"] for i in info},
            "notes": t["notes"], "grid": t["grid"],
        })
        report.append((t["id"], [f"{i['side']}{i['module']}->{','.join(i['reaches']) or '-'}" for i in info], bad))
    with open(path, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=1)
    return report


# ---------------------------------------------------------------- layout generator
OPP = {"L": "R", "R": "L", "T": "B", "B": "T"}
STEP = {"L": (-1, 0), "R": (1, 0), "T": (0, -1), "B": (0, 1)}


def mirrored(t):
    g = [r[::-1] for r in t["grid"]]
    m = dict(t)
    m["grid"] = g
    m["id"] = t["id"] + "~m"
    m["sockets"] = [({"L": "R", "R": "L"}.get(s, s), (t["w"] - 1 - k) if s in "TB" else k) for s, k in t["sockets"]]
    sw = {"L": "R", "R": "L"}
    m["socket_info"] = [dict(side=sw.get(i["side"], i["side"]),
                             module=(t["w"] - 1 - i["module"]) if i["side"] in "TB" else i["module"],
                             reaches=[sw.get(x[0], x[0]) + (str(t["w"] - 1 - int(x[1:])) if x[0] in "TB" else x[1:]) for x in i["reaches"]])
                        for i in t["socket_info"]]
    return m


class Room:
    def __init__(self, t, x, y, role, sec, path):
        self.t, self.x, self.y, self.role, self.sec, self.path = t, x, y, role, sec, path
        self.used = set()   # sockets used (side, k)
        self.trail = None
        self.links = []

    def cells(self):
        return [(self.x + i, self.y + j) for i in range(self.t["w"]) for j in range(self.t["h"])]

    def sock_cell(self, s):
        side, k = s
        if side == "L":
            return (self.x, self.y + k)
        if side == "R":
            return (self.x + self.t["w"] - 1, self.y + k)
        if side == "T":
            return (self.x + k, self.y)
        return (self.x + k, self.y + self.t["h"] - 1)

    def free(self):
        return [s for s in self.t["sockets"] if s not in self.used]


class Level:
    def __init__(self, seed, lib):
        self.rng = random.Random(seed)
        self.seed = seed
        self.lib = lib + [mirrored(t) for t in lib if t["kind"] not in ("junction",)]
        self.occ = {}
        self.rooms = []
        self.edges = []  # (roomA, roomB, kind) kind main/trail/branch/link

    def by_kind(self, kinds):
        return [t for t in self.lib if t["kind"] in kinds]

    def fits(self, t, x, y, ymin=None):
        for i in range(t["w"]):
            for j in range(t["h"]):
                if (x + i, y + j) in self.occ:
                    return False
        if ymin is not None and y < ymin:
            return False
        return True

    def put(self, room):
        for c in room.cells():
            self.occ[c] = room
        self.rooms.append(room)
        return room

    def remove(self, room):
        for c in room.cells():
            del self.occ[c]
        self.rooms.remove(room)

    def attach_options(self, room, s, kinds, ymin=None):
        """All (template, x, y, socket) that dock onto free socket s of room."""
        cx, cy = room.sock_cell(s)
        dx, dy = STEP[s[0]]
        nx, ny = cx + dx, cy + dy
        want = OPP[s[0]]
        opts = []
        for t in self.by_kind(kinds):
            for ts in t["sockets"]:
                if ts[0] != want:
                    continue
                if want in "LR":
                    x, y = (nx if want == "L" else nx - t["w"] + 1), ny - ts[1]
                else:
                    x, y = nx - ts[1], (ny if want == "T" else ny - t["h"] + 1)
                if self.fits(t, x, y, ymin):
                    opts.append((t, x, y, ts))
        return opts

    def dock(self, room, s, t, x, y, ts, role, sec, path, kind):
        r = self.put(Room(t, x, y, role, sec, path))
        room.used.add(s)
        r.used.add(ts)
        r.entry = ts
        self.edges.append((room, r, kind))
        return r

    def undock(self, parent, s, r):
        parent.used.discard(s)
        self.edges = [e for e in self.edges if e[1] is not r]
        self.remove(r)

    def exit_ok(self, t, ts, s):
        """Can a hero who came in through ts leave through s? (one-way drops allowed)."""
        for i in t["socket_info"]:
            if (i["side"], i["module"]) == ts:
                return f"{s[0]}{s[1]}" in i["reaches"]
        return False

    def grow(self, room, roles, sec, path, dirs, ymin=None, depth=0):
        """DFS: dock roles one by one onto room. dirs = preferred exit sides in order."""
        if not roles:
            return [room]
        kinds = roles[0]
        frees = [s for s in room.free() if s[0] in dirs and (not hasattr(room, "entry") or self.exit_ok(room.t, room.entry, s))]
        self.rng.shuffle(frees)
        frees.sort(key=lambda s: dirs.index(s[0]))
        for s in frees[:3]:
            opts = self.attach_options(room, s, kinds, ymin)
            used_ids = {r.t["id"].split("~")[0] for r in self.rooms if r.sec == sec and path == "main" and r.path == "main"}
            opts = [o for o in opts if o[0]["id"].split("~")[0] not in used_ids or o[0]["kind"] in ("shaft", "climb")]
            self.rng.shuffle(opts)
            opts.sort(key=lambda o: -o[0]["weight"] * self.rng.random())
            for (t, x, y, ts) in opts[:6]:
                r = self.dock(room, s, t, x, y, ts, kinds[0], sec, path, "main" if path == "main" else path)
                tail = self.grow(r, roles[1:], sec, path, dirs, ymin, depth + 1)
                if tail:
                    return [room] + tail
                self.undock(room, s, r)
        return None

    def route(self, start_cell, start_side, goal_cell, blocked):
        """BFS on free module cells, moves L/R/down only (forward trails never need climbing)."""
        sx, sy = start_cell
        dx, dy = STEP[start_side]
        first = (sx + dx, sy + dy)
        if first in self.occ or first in blocked:
            return None
        prev = {first: None}
        dq = deque([first])
        while dq:
            c = dq.popleft()
            if c == goal_cell:
                path = []
                while c:
                    path.append(c)
                    c = prev[c]
                return path[::-1]
            moves = [(1, 0), (-1, 0), (0, 1)]
            self.rng.shuffle(moves)
            for mx, my in moves:
                n = (c[0] + mx, c[1] + my)
                if n in prev or n in self.occ or n in blocked:
                    continue
                if abs(n[0] - goal_cell[0]) > 14 or n[1] > goal_cell[1]:
                    continue
                prev[n] = c
                dq.append(n)
        return None

    def add_links(self, path, a_room, a_sock, b_room, b_sock, kind):
        """Turn a routed cell path into 1x1 'link' rooms with derived sockets."""
        rooms = []
        cells = [a_room.sock_cell(a_sock)] + path + [b_room.sock_cell(b_sock)]
        for i in range(1, len(cells) - 1):
            p, c, n = cells[i - 1], cells[i], cells[i + 1]
            socks = []
            for o in (p, n):
                d = (o[0] - c[0], o[1] - c[1])
                side = {v: k for k, v in STEP.items()}[d]
                socks.append((side, 0))
            t = link_template(socks)
            r = self.put(Room(t, c[0], c[1], "link", a_room.sec, kind))
            r.trail = getattr(a_room, "trail", None)
            r.used = set(socks)
            rooms.append(r)
        chain = [a_room] + rooms + [b_room]
        for u, v in zip(chain, chain[1:]):
            self.edges.append((u, v, kind))
        a_room.used.add(a_sock)
        b_room.used.add(b_sock)
        return rooms


def link_template(socks):
    """1x1 connector grid: tunnel, drop shaft or bend; generated, never authored."""
    g = [["#"] * MOD_W for _ in range(MOD_H)]
    sides = {s for s, _ in socks}
    for r in range(1, MOD_H - 1):
        for x in range(1, MOD_W - 1):
            g[r][x] = "."
    for s in sides:
        if s == "L":
            for r in range(4, 8):
                g[r][0] = "D"
        if s == "R":
            for r in range(4, 8):
                g[r][MOD_W - 1] = "D"
        if s == "T":
            for x in range(6, 10):
                g[0][x] = "D"
        if s == "B":
            for x in range(6, 10):
                g[MOD_H - 1][x] = "D"
    if sides == {"T", "B"}:
        g[4][2:5] = list("===")
    return dict(id="link", name="связка", kind="link", w=1, h=1, grid=["".join(r) for r in g],
                sockets=list(socks), weight=0, socket_info=[])


def build_level(seed, lib, stages=3, max_tries=200):
    for attempt in range(max_tries):
        lv = Level(seed * 1000 + attempt, lib)
        ok = _build(lv, stages)
        if ok:
            lv.attempts = attempt + 1
            return lv
    raise RuntimeError("fallback chain would be used here")


def _build(lv, stages):
    rng = lv.rng
    entry = lv.put(Room(rng.choice([t for t in lv.by_kind(["entry"]) if "~" not in t["id"]]), 0, 0, "entry", 0, "main"))
    # section 0: surface, heads east
    sec0 = [["corr"], ["arena", "bridge"], ["corr", "hall"], ["altar"], ["fork"]]
    chain = lv.grow(entry, sec0, 0, "main", ["R", "B"])
    if not chain:
        return False
    lv.reward_rooms = [chain[-2]]
    fork = chain[-1]
    lv.forks = []
    for st in range(1, stages + 1):
        trails = []
        outs = [s for s in fork.free() if s[0] in "RBL" and lv.exit_ok(fork.t, fork.entry, s)]
        rng.shuffle(outs)
        want = 3 if rng.random() < 0.45 else 2   # fork_three
        for s in outs:
            if len(trails) == want:
                break
            roles = [[rng.choice(["arena", "hall", "bridge"])], ["altar"]]
            got = None
            for t, x, y, ts in sorted(lv.attach_options(fork, s, ["shaft", "climb", "hall"] if s[0] in "LR" else ["shaft", "hall", "arena", "bridge"]),
                                      key=lambda o: rng.random()):
                r = lv.dock(fork, s, t, x, y, ts, "trail", st, "trail", "trail")
                tail = lv.grow(r, roles, st, "trail", ["B", "R", "L"] if s[0] != "L" else ["B", "L", "R"])
                if tail:
                    got = [r] + tail[1:]
                    break
                lv.undock(fork, s, r)
            if got:
                for q in got:
                    q.trail = (st, len(trails))
                trails.append(got)
        if len(trails) < 2:
            lv.why = f"trails st{st} {len(trails)}"
            return False
        lv.forks.append((fork, trails))
        # junction below all trails
        bottom = max(r.y + r.t["h"] for tr in trails for r in tr)
        xs = [tr[-1].x for tr in trails]
        placed = False
        cands = []
        for jt in lv.by_kind(["junction"]):
            for dy in (1, 2, 3, 4):
                for jx in range(min(xs) - 6, max(xs) + 4):
                    jy = bottom + dy
                    if not lv.fits(jt, jx, jy):
                        continue
                    j = lv.put(Room(jt, jx, jy, "junction", st, "main"))
                    tops = [s for s in jt["sockets"] if s[0] == "T"]
                    blocked = set()
                    plan = []
                    okj = True
                    for tr in trails:
                        alt = tr[-1]
                        exits = [s for s in alt.free() if s[0] in "BRL" and lv.exit_ok(alt.t, alt.entry, s)]
                        best = None
                        for e in exits:
                            for ts in tops:
                                if ts in [p[3] for p in plan]:
                                    continue
                                gc = j.sock_cell(ts)
                                goal = (gc[0], gc[1] - 1)
                                p = lv.route(alt.sock_cell(e), e[0], goal, blocked | set(j.cells()))
                                if p and len(p) <= LINK_MAX and (best is None or len(p) < len(best[0])):
                                    best = (p, alt, e, ts)
                        if not best:
                            okj = False
                            break
                        plan.append(best)
                        blocked |= set(best[0])
                    lv.remove(j)
                    if okj:
                        cost = sum(len(p[0]) for p in plan) + dy + rng.random()
                        cands.append((cost, jt, jx, jy, plan))
        if cands:
            cost, jt, jx, jy, plan = min(cands, key=lambda c: c[0])
            j = lv.put(Room(jt, jx, jy, "junction", st, "main"))
            for p, alt, e, ts in plan:
                lv.add_links(p, alt, e, j, ts, "trail")
            placed = True
        if not placed:
            lv.why = f"junction st{st}"
            return False
        for tr in trails:
            lv.reward_rooms.append(tr[-1])
        # common stretch after the junction: descend, then next fork or the lair gate
        if st < stages:
            roles = [["shaft", "climb"], ["corr", "hall", "arena"], ["fork"]]
        else:
            roles = [["shaft"], ["arena", "hall"], ["lairgate"]]
        nxt = lv.grow(j, roles, st, "main", ["B"] + rng.sample(["R", "L"], 2))
        if not nxt:
            lv.why = f"after st{st}"
            return False
        fork = nxt[-1]
    lv.lairgate = fork
    # side branches: one per stage, two-way rooms only
    for sec in range(0, stages + 1):
        hosts = [r for r in lv.rooms if r.sec == sec and r.path == "main" and r.role not in ("fork", "junction", "lairgate")]
        rng.shuffle(hosts)
        done = False
        for h in hosts:
            for s in [s for s in h.free() if s[0] in "LRT"]:
                kind = rng.choice([["nook"], ["secret"], ["gauntlet", "nook"], ["climb", "nook"]])
                tail = lv.grow_branch(h, s, kind, sec)
                if tail:
                    done = True
                    break
            if done:
                break
    return True


def grow_branch(self, host, s, kinds, sec):
    opts = self.attach_options(host, s, kinds[0])
    self.rng.shuffle(opts)
    for t, x, y, ts in opts[:6]:
        r = self.dock(host, s, t, x, y, ts, kinds[0], sec, "branch", "branch")
        if len(kinds) == 1:
            return [r]
        tail = self.grow(r, [kinds[1:]], sec, "branch", ["R", "L", "T", "B"])
        if tail:
            for q in tail[1:]:
                q.path = "branch"
            self.edges = [(a, b, "branch" if b in tail else k) for a, b, k in self.edges]
            return [r] + tail[1:]
        self.undock(host, s, r)
    return None


Level.grow_branch = grow_branch

# ---------------------------------------------------------------- drawing
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
FONTB = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"


def font(sz, bold=False):
    return ImageFont.truetype(FONTB if bold else FONT, sz)


BG = (14, 22, 24)
CH_COL = {
    "#": (58, 74, 62), "S": (150, 96, 52), "=": (154, 128, 86), "B": (125, 154, 90),
    "~": (40, 96, 104), "^": (210, 70, 50), "E": (226, 80, 52), "F": (210, 58, 154),
    "C": (255, 201, 74), "H": (255, 236, 140), "G": (120, 220, 230), "P": (240, 240, 240),
    "L": (220, 40, 60), "D": None, ".": None,
}
ROOM_BG = {
    "main": (26, 40, 38), "trail": (30, 34, 50), "branch": (44, 36, 28), "link": (22, 30, 30),
}
PATH_COL = {"main": (182, 227, 107), "trail": (120, 170, 255), "branch": (230, 170, 80)}


def draw_grid(d, t, ox, oy, cs, room_bg=None):
    g = t["grid"]
    if room_bg:
        d.rectangle([ox, oy, ox + len(g[0]) * cs - 1, oy + len(g) * cs - 1], fill=room_bg)
    for r, row in enumerate(g):
        for x, ch in enumerate(row):
            col = CH_COL.get(ch)
            if col is None:
                continue
            x0, y0 = ox + x * cs, oy + r * cs
            if ch in "EFCHGLP" and cs >= 3:
                rr = max(cs, 3)
                d.ellipse([x0 - rr // 2, y0 - rr // 2, x0 + cs + rr // 2, y0 + cs + rr // 2], fill=col)
            elif ch == "=":
                d.rectangle([x0, y0, x0 + cs - 1, y0 + max(1, cs // 2) - 1], fill=col)
            else:
                d.rectangle([x0, y0, x0 + cs - 1, y0 + cs - 1], fill=col)


def room_center(r, mpx, mpy, ox, oy):
    return (ox + (r.x + r.t["w"] / 2) * mpx, oy + (r.y + r.t["h"] / 2) * mpy)


def draw_level(lv, path, title, minimap=False):
    xs = [c[0] for c in lv.occ]
    ys = [c[1] for c in lv.occ]
    lgx = lv.lairgate.x
    minx, maxx, miny, maxy = min(xs + [lgx - 1]), max(xs + [lgx + 4]), min(ys), max(ys) + 3  # room for the lair box
    cols, rows = maxx - minx + 1, maxy - miny + 1
    cs = 4
    mpx, mpy = MOD_W * cs, MOD_H * cs
    left, top = 250, 110
    legend_w = 470
    W = left + cols * mpx + 40 + legend_w
    Hh = max(top + rows * mpy + 60, 1150 if minimap else 900)
    img = Image.new("RGB", (W, Hh), BG)
    d = ImageDraw.Draw(img)
    ox, oy = left - minx * mpx, top - miny * mpy

    # depth bands
    j1 = lv.forks[0][1]
    band_rows = []
    junctions = [r for r in lv.rooms if r.role == "junction"]
    b1 = junctions[0].y
    b2 = junctions[1].y if len(junctions) > 1 else b1 + 6
    bands = [("поверхность", miny, b1, (30, 46, 40)), ("под корнями", b1, b2, (24, 32, 34)),
             ("глубь", b2, maxy + 1, (24, 18, 30))]
    for name, a, b, col in bands:
        y0, y1 = oy + a * mpy, oy + b * mpy
        d.rectangle([left - 240, y0, left + cols * mpx + 20, y1 - 2], fill=col)
        d.text((left - 236, y0 + 44), name, font=font(22, True), fill=(220, 225, 200))
        d.line([left - 240, y0, left + cols * mpx + 20, y0], fill=(80, 96, 90), width=1)

    # rooms
    for r in lv.rooms:
        x0, y0 = ox + r.x * mpx, oy + r.y * mpy
        bgc = ROOM_BG["link"] if r.role == "link" else ROOM_BG.get(r.path, ROOM_BG["main"])
        draw_grid(d, r.t, x0, y0, cs, bgc)
    # unused sockets are sealed: paint them as rock
    for r in lv.rooms:
        for s in r.t["sockets"]:
            if s in r.used:
                continue
            side, k = s
            x0, y0 = ox + r.x * mpx, oy + r.y * mpy
            if side in "LR":
                xx = x0 + (0 if side == "L" else (r.t["w"] * MOD_W - 1) * cs)
                d.rectangle([xx, y0 + (k * MOD_H + 4) * cs, xx + cs - 1, y0 + (k * MOD_H + 8) * cs - 1], fill=CH_COL["#"])
            else:
                yy = y0 + (0 if side == "T" else (r.t["h"] * MOD_H - 1) * cs)
                d.rectangle([x0 + (k * MOD_W + 6) * cs, yy, x0 + (k * MOD_W + 10) * cs - 1, yy + cs - 1], fill=CH_COL["#"])

    # path lines
    for a, b, kind in lv.edges:
        pa, pb = room_center(a, mpx, mpy, ox, oy), room_center(b, mpx, mpy, ox, oy)
        col = PATH_COL.get(kind, PATH_COL["main"])
        d.line([pa, pb], fill=col, width=4 if kind == "main" else 3)
    # room outlines and labels
    for r in lv.rooms:
        x0, y0 = ox + r.x * mpx, oy + r.y * mpy
        x1, y1 = x0 + r.t["w"] * mpx - 1, y0 + r.t["h"] * mpy - 1
        if r.role != "link":
            col = PATH_COL.get(r.path, PATH_COL["main"])
            d.rectangle([x0, y0, x1, y1], outline=col, width=2)
        if r.role in ("fork",):
            d.text((x0 + 6, y0 + 4), "развилка", font=font(15, True), fill=(120, 220, 230))
        if r in lv.reward_rooms:
            d.text((x0 + 6, y0 + 4), "награда", font=font(15, True), fill=(255, 236, 140))
        if r.role == "junction":
            d.text((x0 + 6, y0 + 4), "узел", font=font(15, True), fill=(220, 220, 220))
        if r.path == "branch" and r.role in ("nook", "secret"):
            d.text((x0 + 4, y0 + 4), "тайник" if r.role == "secret" else "сундук", font=font(13, True), fill=(230, 170, 80))
        if r.role == "gauntlet":
            d.text((x0 + 6, y0 + 4), "испытание", font=font(14, True), fill=(230, 170, 80))
    # start and lair
    e = lv.rooms[0]
    ex, ey = room_center(e, mpx, mpy, ox, oy)
    d.text((ox + e.x * mpx, oy + e.y * mpy - 26), "вход (с привала)", font=font(18, True), fill=(240, 240, 240))
    lg = lv.lairgate
    lx0 = ox + (lg.x - 1) * mpx
    ly0 = oy + (lg.y + lg.t["h"]) * mpy + 14
    lx1, ly1 = lx0 + 4 * mpx, ly0 + int(2.2 * mpy)
    d.rectangle([lx0, ly0, lx1, ly1], fill=(60, 16, 26), outline=(220, 40, 60), width=3)
    d.text((lx0 + 12, ly0 + 10), "ЛОГОВО КИКИМОРЫ", font=font(20, True), fill=(255, 200, 200))
    d.text((lx0 + 12, ly0 + 38), "отдельная сцена босса", font=font(15), fill=(230, 180, 180))
    lc = room_center(lg, mpx, mpy, ox, oy)
    d.line([lc, ((lx0 + lx1) / 2, ly0)], fill=(220, 40, 60), width=4)

    # title
    d.text((24, 22), title, font=font(30, True), fill=(235, 240, 220))
    walked = sum(1 for r in lv.rooms if r.path == "main" and r.role != "link")
    d.text((24, 62), f"seed {lv.seed}  ·  комнат: {len([r for r in lv.rooms if r.role != 'link'])} заготовок + "
                     f"{len([r for r in lv.rooms if r.role == 'link'])} связок  ·  развилок: {len(lv.forks)}  ·  "
                     f"попыток сборки: {lv.attempts}", font=font(17), fill=(170, 185, 170))

    # legend
    lx = left + cols * mpx + 50
    ly = top
    d.text((lx, ly), "Условные знаки", font=font(22, True), fill=(235, 240, 220))
    ly += 38
    items = [
        ("line", PATH_COL["main"], "главный путь"),
        ("line", PATH_COL["trail"], "тропы развилки (идёшь по одной)"),
        ("line", PATH_COL["branch"], "боковая ветка: сундук, тайник, испытание"),
        ("box", (58, 74, 62), "твердь"), ("plat", (154, 128, 86), "мостки (сквозь снизу)"),
        ("box", (40, 96, 104), "трясина"), ("box", (210, 70, 50), "шипы"),
        ("box", (125, 154, 90), "кочка (Болотница)"), ("box", (150, 96, 52), "ломкая стена"),
        ("dot", (226, 80, 52), "стая врагов"), ("dot", (210, 58, 154), "летун"),
        ("dot", (255, 201, 74), "сундук"), ("dot", (255, 236, 140), "капище: награда, идол"),
        ("dot", (120, 220, 230), "врата тропы со знаком награды"), ("dot", (220, 40, 60), "дверь логова"),
    ]
    for kind, col, text in items:
        if kind == "line":
            d.line([lx, ly + 10, lx + 34, ly + 10], fill=col, width=4)
        elif kind == "box":
            d.rectangle([lx + 8, ly + 2, lx + 26, ly + 18], fill=col)
        elif kind == "plat":
            d.rectangle([lx + 4, ly + 6, lx + 30, ly + 12], fill=col)
        else:
            d.ellipse([lx + 9, ly + 2, lx + 25, ly + 18], fill=col)
        d.text((lx + 46, ly), text, font=font(17), fill=(210, 215, 200))
        ly += 30
    ly += 10
    for line in ["Каждая развилка: 2-3 тропы, у каждой в", "конце капище с наградой. Войдёшь в одни",
                 "врата, остальные зарастают корнями.", "Тропы сходятся в узле, дальше спуск.",
                 "Закрытые гнёзда заделываются твердью."]:
        d.text((lx, ly), line, font=font(15), fill=(170, 185, 170))
        ly += 22

    if minimap:
        draw_minimap(img, d, lv, lx, ly + 30)
    img.save(path)
    return img.size


def draw_minimap(img, d, lv, lx, ly):
    """HUD sketch: 320x180 minimap under the resources block, fog of war, icons."""
    d.text((lx, ly), "Миникарта в HUD (набросок, 1:1)", font=font(20, True), fill=(235, 240, 220))
    ly += 32
    W, H = 320, 180
    box = [lx, ly, lx + W, ly + H]
    d.rounded_rectangle(box, radius=10, fill=(12, 16, 18), outline=(122, 108, 80), width=3)
    # visited = everything above the second junction, minus the trails not taken (trail index 0 = taken)
    junctions = [r for r in lv.rooms if r.role == "junction"]
    stop_y = junctions[1].y
    visited = [r for r in lv.rooms if r.y + r.t["h"] <= stop_y + 1 and (r.trail is None or r.trail[1] == 0)
               and r.path != "branch"]
    chosen = set()
    hero = [r for r in lv.rooms if r.trail == (2, 0) and r.role == "altar"][0]
    visited = [r for r in visited if not (r.trail == (2, 0) and r.role == "link")]
    scale = 10  # px per module
    cx = hero.x + hero.t["w"] / 2
    cy = hero.y + hero.t["h"] / 2
    mx0 = lx + W / 2 - cx * scale
    my0 = ly + H / 2 - cy * scale
    clip = Image.new("RGB", (W, H), (12, 16, 18))
    cd = ImageDraw.Draw(clip)
    for r in lv.rooms:
        x0 = mx0 + r.x * scale - lx
        y0 = my0 + r.y * scale - ly
        x1 = x0 + r.t["w"] * scale - 2
        y1 = y0 + r.t["h"] * scale - 2
        if r in visited:
            cd.rectangle([x0, y0, x1, y1], fill=(70, 92, 78) if r.role != "link" else (52, 66, 60))
    # seen-but-not-entered: rooms next to visited ones, outline only with a "?"
    for a, b, k in lv.edges:
        for u, v in ((a, b), (b, a)):
            if u in visited and v not in visited and not (v.trail and v.trail[1] != 0 and k == "trail" and u.role != "fork"):
                x0 = mx0 + v.x * scale - lx
                y0 = my0 + v.y * scale - ly
                cd.rectangle([x0, y0, x0 + v.t["w"] * scale - 2, y0 + v.t["h"] * scale - 2], outline=(110, 120, 110), width=1)
                cd.text((x0 + v.t["w"] * scale / 2 - 4, y0 + v.t["h"] * scale / 2 - 8), "?", font=font(13, True), fill=(220, 220, 200))
    for r in visited:
        c = ((r.x + r.t["w"] / 2) * scale + mx0 - lx, (r.y + r.t["h"] / 2) * scale + my0 - ly)
        if r.role == "fork":
            cd.polygon([(c[0], c[1] - 6), (c[0] + 6, c[1]), (c[0], c[1] + 6), (c[0] - 6, c[1])], fill=(120, 220, 230))
        if r in lv.reward_rooms:
            cd.ellipse([c[0] - 5, c[1] - 5, c[0] + 5, c[1] + 5], fill=(255, 236, 140))
        if any(ch == "C" for row in r.t["grid"] for ch in row) and r.role != "fork":
            cd.rectangle([c[0] + 6, c[1] - 3, c[0] + 12, c[1] + 3], fill=(255, 201, 74))
    # lair: shown as a red skull mark from the start (direction is known, not the way)
    lg = lv.lairgate
    lc = ((lg.x + lg.t["w"] / 2) * scale + mx0 - lx, (lg.y + lg.t["h"] + 1.5) * scale + my0 - ly)
    lc = (min(max(lc[0], 12), W - 12), min(max(lc[1], 12), H - 12))
    cd.ellipse([lc[0] - 7, lc[1] - 7, lc[0] + 7, lc[1] + 7], outline=(220, 40, 60), width=3)
    # hero
    hc = (W / 2, H / 2)
    cd.polygon([(hc[0], hc[1] - 7), (hc[0] + 6, hc[1] + 5), (hc[0] - 6, hc[1] + 5)], fill=(255, 255, 255))
    img.paste(clip, (lx + 3, ly + 3), mask=None) if False else img.paste(clip.crop((3, 3, W - 3, H - 3)), (lx + 3, ly + 3))
    d.rounded_rectangle(box, radius=10, outline=(122, 108, 80), width=3)
    ly += H + 12
    notes = [("белый треугольник", "герой (карта крутится за ним)"),
             ("заливка", "пройденные комнаты; остальное туман"),
             ("контур с «?»", "проход замечен, но не пройден"),
             ("голубой ромб", "развилка, жёлтый круг: капище"),
             ("жёлтый квадрат", "сундук, ещё не открыт"),
             ("красный круг у края", "логово: видно направление сразу")]
    for a, b in notes:
        d.text((lx, ly), f"{a}: {b}", font=font(14), fill=(190, 200, 185))
        ly += 21


def draw_samples(path, ids):
    ts = [t for t in T if t["id"] in ids]
    cs = 12
    pad = 50
    # layout: 2 columns
    colw = max(t["w"] for t in ts) * MOD_W * cs
    cells = []
    x, y = pad, 230
    rowh = 0
    W = pad * 3 + colw * 2
    placed = []
    col = 0
    for t in ts:
        w, h = t["w"] * MOD_W * cs, t["h"] * MOD_H * cs
        if col == 2:
            col = 0
            x = pad
            y += rowh + 130
            rowh = 0
        placed.append((t, x, y))
        rowh = max(rowh, h)
        x += colw + pad
        col += 1
    Hh = y + rowh + 150
    img = Image.new("RGB", (W, Hh), BG)
    d = ImageDraw.Draw(img)
    d.text((pad, 24), "Комнаты-заготовки Топи: 6 образцов", font=font(32, True), fill=(235, 240, 220))
    d.text((pad, 72), "Клетка 40 px, модуль 16x9 клеток (полэкрана). Подъём не выше 3 клеток, яма не шире 5 (прыжок героя из tuning.json).",
           font=font(18), fill=(170, 185, 170))
    d.text((pad, 98), "Бирюзовые проёмы: гнёзда. Неиспользованные при сборке заделываются твердью. «L0→R0»: войдя слева, можно выйти справа.",
           font=font(18), fill=(170, 185, 170))
    for t, x, y in placed:
        d.text((x, y - 84), f"{t['name']}", font=font(24, True), fill=(235, 240, 220))
        socks = ", ".join(f"{i['side']}{i['module']}→{('/'.join(i['reaches']) or 'тупик')}" for i in t["socket_info"])
        line = f"{KIND_RU[t['kind']]} · {t['w']}x{t['h']} модуля · гнёзда: {socks}"
        f15 = font(15)
        words, lines, cur = line.split(" "), [], ""
        for wd in words:
            if d.textlength(cur + " " + wd, font=f15) > colw:
                lines.append(cur)
                cur = wd
            else:
                cur = (cur + " " + wd).strip()
        lines.append(cur)
        for li, ln in enumerate(lines[:2]):
            d.text((x, y - 50 + li * 20), ln, font=f15, fill=(170, 185, 170))
        draw_grid(d, t, x, y, cs, (26, 40, 38))
        # sockets highlighted
        for r, row in enumerate(t["grid"]):
            for xx, ch in enumerate(row):
                if ch == "D":
                    d.rectangle([x + xx * cs, y + r * cs, x + xx * cs + cs - 1, y + r * cs + cs - 1], fill=(60, 200, 190))
        # module grid
        for m in range(1, t["w"]):
            d.line([x + m * MOD_W * cs, y, x + m * MOD_W * cs, y + t["h"] * MOD_H * cs], fill=(70, 80, 80), width=1)
        for m in range(1, t["h"]):
            d.line([x, y + m * MOD_H * cs, x + t["w"] * MOD_W * cs, y + m * MOD_H * cs], fill=(70, 80, 80), width=1)
        # hero scale: 28x64 px = 0.7 x 1.6 cells
        hx, hy = None, None
        for r, row in enumerate(t["grid"]):
            if "P" in row:
                hx, hy = row.index("P"), r
        if hx is None:  # stand the hero by the first side socket
            for i in t["socket_info"]:
                if i["side"] in "LR":
                    hy = i["module"] * MOD_H + 7
                    hx = 2 if i["side"] == "L" else t["w"] * MOD_W - 3
                    break
        if hx is not None:
            px, py = x + hx * cs, y + (hy + 1) * cs
            d.rectangle([px, py - int(1.6 * cs), px + int(0.7 * cs), py], fill=(240, 240, 240))
    # legend row
    ly = Hh - 100
    lx = pad
    for col, text in [((58, 74, 62), "твердь"), ((154, 128, 86), "мостки"), ((40, 96, 104), "трясина"),
                      ((210, 70, 50), "шипы"), ((125, 154, 90), "кочка"), ((150, 96, 52), "ломкая стена"),
                      ((226, 80, 52), "стая"), ((210, 58, 154), "летун"), ((255, 201, 74), "сундук"),
                      ((255, 236, 140), "капище"), ((120, 220, 230), "врата"), ((60, 200, 190), "гнездо"),
                      ((240, 240, 240), "герой в масштабе")]:
        tw = 34 + int(d.textlength(text, font=font(17)))
        if lx + tw > W - pad:
            lx = pad
            ly += 30
        d.rectangle([lx, ly + 3, lx + 18, ly + 21], fill=col)
        d.text((lx + 24, ly), text, font=font(17), fill=(210, 215, 200))
        lx += tw
    img.save(path)
    return img.size


def main():
    repo = sys.argv[1] if len(sys.argv) > 1 else "."
    out = sys.argv[2] if len(sys.argv) > 2 else "."
    report = export_templates(f"{repo}/assets/data/room_templates_swamp_draft.json")
    for tid, socks, bad in report:
        print(tid, socks, "UNREACHABLE:" + ",".join(bad) if bad else "")
    seeds = [int(s) for s in (sys.argv[3].split(",") if len(sys.argv) > 3 else ["7", "21"])]
    for n, seed in enumerate(seeds, 1):
        lv = build_level(seed, T)
        size = draw_level(lv, f"{out}/level-map-swamp-{n}.png",
                          f"Топь Кикиморы: схема уровня, вариант {n}", minimap=(n == 1))
        print("map", n, size, "rooms", len(lv.rooms), "attempts", lv.attempts)
    # build-rate check (acceptance criterion: fallback < 1%)
    fails = 0
    tries = []
    for s in range(200):
        try:
            lv = build_level(1000 + s, T, max_tries=50)
            tries.append(lv.attempts)
        except RuntimeError:
            fails += 1
    print("200 seeds: fallback", fails, "mean attempts", sum(tries) / max(1, len(tries)))
    print("samples", draw_samples(f"{out}/level-room-samples.png",
                                  ["sw_corr_01", "sw_bridge_01", "sw_shaft_01", "sw_arena_01", "sw_fork_01", "sw_hall_01"]))


if __name__ == "__main__":
    main()

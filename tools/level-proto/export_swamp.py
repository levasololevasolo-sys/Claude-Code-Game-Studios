#!/usr/bin/env python3
"""Writes the stage-1 Swamp template library assets/data/room_templates_swamp.json
(design/gdd/level-structure.md §3.2, §3.9 stage 1).

Takes the 15 draft templates of gen_map.py, adds the stage-1 extras below, checks
every template with the prototype's jump model (rise <= 3, gap <= 5, all markers
reachable) and computes the `reach` table. The game's level generator
(src/world/level_gen.gd) reads the result; edit the grids here or in the JSON and
re-run.

Usage: python3 tools/level-proto/export_swamp.py <repo_root>
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_map as gm  # noqa: E402

LEGEND = {
    "#": "твердь", ".": "пусто", "=": "мостки (ловят сверху, вниз+прыжок сквозь)",
    "^": "шипы", "~": "трясина (медленно, прыжок не выше 2 клеток)", "D": "гнездо (проём на краю)",
    "E": "стая (центр на полу)", "F": "летун", "B": "кочка Болотницы (держит как мостки)",
    "I": "потолок Сосульника", "C": "сундук", "S": "ломкая стена", "H": "капище / родник / идол",
    "G": "врата тропы (только fork)", "K": "место витязя", "P": "старт героя (только entry)",
    "L": "дверь логова (только lairgate)",
}

# Stage-1 extras: a fork with widely spaced exits (open question 4: the draft fork
# rarely fits a third trail), a third corridor and a second hall.
gm.tpl("sw_fork_02", "Распутье у Велесова столба", "fork", 3, 2, [
    "######################DDDD######################",
    "#..............................................#",
    "#..............................................#",
    "#..............................................#",
    "D..............................................D",
    "D..............................................D",
    "D..............................................D",
    "D......................H.......................D",
    "######.....=====################=====.....######",
    "#..............................................#",
    "#..............................................#",
    "#..............................................#",
    "#..............................................#",
    "D..............................................D",
    "D..............................................D",
    "D..............................................D",
    "D..G...............G.......................G...D",
    "######################DDDD######################",
], notes="выходы врозь: влево, вниз, вправо; вход сверху или с верхнего бока")

gm.tpl("sw_corr_03", "Кочкарник", "corr", 2, 1, [
    "################################",
    "#..............................#",
    "#..............................#",
    "#.............F................#",
    "D..............................D",
    "D..........######..............D",
    "D.........########.............D",
    "D...E....##########.....~~~~E..D",
    "################################",
], notes="бугор посреди прохода, летун над ним")

gm.tpl("sw_hall_02", "Корневой грот", "hall", 2, 2, [
    "######################DDDD######",
    "#..............................#",
    "#..............................#",
    "#.........................C....#",
    "D......................=====...#",
    "D..............................#",
    "D..............................#",
    "D.......E......................#",
    "############....========########",
    "#..............................#",
    "#..............................#",
    "#...............======.........#",
    "#..............................#",
    "#..............................D",
    "#.........=====................D",
    "#..............................D",
    "#.....E.....~~~~~~.......E.....D",
    "######DDDD######################",
], notes="два яруса: сверху полка с сундуком, снизу стоячая вода")


def main():
    repo = sys.argv[1] if len(sys.argv) > 1 else "."
    out = {
        "_note": ("Библиотека заготовок Топи, срез этапа 1 (design/gdd/level-structure.md §3.2, §3.9). "
                  "Пишется tools/level-proto/export_swamp.py из черновика gen_map.py; reach посчитан моделью прыжка "
                  "(подъём <= 3 клетки, яма <= 5). Клетка 40 px, модуль 16x9 клеток, grid: строка 0 сверху."),
        "cell": gm.CELL_PX, "module_w": gm.MOD_W, "module_h": gm.MOD_H,
        "jump": {"rise_cells": gm.RISE_MAX, "gap_cells": gm.GAP_MAX, "water_rise_cells": gm.WATER_RISE,
                 "source": "tuning.json jump_speed 860, gravity 2300, run_speed 360, dash_speed 980 x dash_time 0.17"},
        "legend": LEGEND,
        "templates": [],
    }
    bad_any = False
    for t in gm.T:
        socks, info, marks, bad = gm.analyse(t)
        out["templates"].append({
            "id": t["id"], "name": t["name"], "kind": t["kind"], "w": t["w"], "h": t["h"],
            "weight": t["weight"], "tier_min": t["tier_min"], "mirror": t["kind"] != "junction",
            "sockets": [{"side": s, "module": m} for s, m in socks],
            "reach": {f"{i['side']}{i['module']}": i["reaches"] for i in info},
            "notes": t["notes"], "grid": t["grid"],
        })
        print(t["id"], " ".join(f"{i['side']}{i['module']}->{','.join(i['reaches']) or '-'}" for i in info),
              ("UNREACHABLE " + ",".join(bad)) if bad else "")
        bad_any = bad_any or bool(bad)
    # Seal rooms (artifacts-and-secrets) are hand-written in the JSON, not in
    # gen_map.py: keep them and their legend letters (Z seal, X barrier, W bridge, O hook, V vault).
    path = os.path.join(repo, "assets/data/room_templates_swamp.json")
    if os.path.exists(path):
        old = json.load(open(path, encoding="utf-8"))
        out["templates"] += [t for t in old.get("templates", []) if t.get("kind") == "seal"]
        for k in ("Z", "X", "W", "O", "V"):
            if k in old.get("legend", {}):
                out["legend"][k] = old["legend"][k]
    with open(path, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=1)
        f.write("\n")
    print(len(gm.T), "templates", "WITH UNREACHABLE MARKERS" if bad_any else "ok")


if __name__ == "__main__":
    main()

#!/bin/sh
# Fetch only the CC0 MakeHuman assets mh_base.py needs (~6 MB, sparse; not shipped).
# Usage: sh tools/asset-pipeline/blender/fetch_makehuman.sh <dir>
# Then:  python3 tools/asset-pipeline/blender/mh_base.py <dir>/makehuman/data tools/asset-pipeline/blender/data/hero_base.json.gz
# Used: commit a8bc2d54ff0ac92e78ff71431b1023eda42bf482 (2026-11-27).
set -e
D=${1:-/tmp/makehuman}
git clone --depth 1 --filter=blob:none --sparse https://github.com/makehumancommunity/makehuman.git "$D"
cd "$D"
git sparse-checkout set --no-cone '/LICENSE*' '/makehuman/data/3dobjs/base.obj' \
  '/makehuman/data/rigs/default.mhskel' '/makehuman/data/rigs/default_weights.mhw' \
  '/makehuman/data/targets/macrodetails/caucasian-male-young.target' \
  '/makehuman/data/targets/macrodetails/universal-male-young-maxmuscle-minweight.target' \
  '/makehuman/data/targets/macrodetails/height/male-young-maxmuscle-averageweight-maxheight.target'
head -1 LICENSE.ASSETS.md   # must read: Creative Commons CC0 1.0 Universal

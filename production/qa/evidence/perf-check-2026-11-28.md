# Fix pass after the developer's playtest (2026-11-28)

Reported on the developer's PC (RTX 3050, Godot 4.7.1): ~15 FPS, the game starts
straight in location 1, broken attack animations, grass floating in the air or
under the ground.

## FPS

Probe: `tests/integration/perf/perf_check_driver.gd` (`-- --perf-check=<dir>`):
the normal run flow, the start rune taken, the hero standing in the first Swamp
level while its enemies fight him; averages over 45 frames. Same cloud machine
(4 cores, no GPU: Mesa llvmpipe) for before (commit 52a48d2) and after.

| Measure | Before | After |
|---|---|---|
| CPU per frame, no rendering (`--headless`) | 39 ms | 7 ms |
| Draw calls, start offer open (Forward+, Vulkan llvmpipe) | 26 073 | ~1 300 |
| Draw calls, in the fight (Forward+) | ~3 050 | ~250-340 |
| Whole frame in the fight, software GPU (Forward+) | 300 ms | 130 ms |

Cause: the VFX grass (src/vfx/vfx_grass.gd) drew every blade with two
`draw_line` calls every frame over the whole level width (culled by x only, and
not at all while the tree was paused): tens of thousands of GDScript draw calls
per frame. Now one triangle soup per layer (`canvas_item_add_triangle_array`)
culled to the camera rect in x and y. The software-GPU frame time is mostly
fill rate of the backdrop and cannot be compared with a real GPU; the CPU and
draw-call numbers are the ones that carry over. F3 now shows an FPS counter.

## Start

New: main menu (src/ui/main_menu.gd) with 5 save slots (src/core/save_slots.gd;
the old save.json moves to slot 1), and a normal launch begins in the base
«Застава», not in a run. `--menu-check` plays it: menu-*.png, menu-check-log.txt.

## Attack animations

The weapon angle was eased (cubic) while the drawn sheet's arm moves linearly,
so the weapon left the fist mid-swing; the up and down strikes ended pointing
behind the hero; long weapons rested with their tip in the floor. Fixed in
Player._blade_angle; frame strips at 6 % game speed: perf-attack-*.png.

## Grass

The grass was laid on a ground line at ground_y across the whole level and on
the tops of merged rock rectangles, which in the graph levels are inside rock or
mid-air. It now stands only on open floor tops from the level grid
(LevelRoom.surfaces): perf-grass-on-ground.png. Regression tests:
tests/unit/vfx/vfx_grass_placement_test.gd, tests/unit/hero/hero_weapon_angle_test.gd
(both seen failing on the old code), tests/unit/core/launch_flow_test.gd.

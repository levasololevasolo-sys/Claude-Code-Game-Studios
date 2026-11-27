# Art slice: 3D -> 2D sprite pipeline (Blender, free tools only)

Design: `design/art/visual-upgrade-plan.md`. Branch `art-3d-slice`. Date 2026-11-27.

## What it is

The Dead Cells technique: characters are 3D models, animated in 3D, rendered
from a fixed orthographic side camera to 2D sprite sheets, and shown in Godot as
ordinary 2D sprites. Our version renders a non-pixel look: soft three-tone cel
shading with cool shadows, a warm back rim, a thick warm-black inverted-hull
outline (`#120D12`), rendered at 2x supersampling and downsampled with Lanczos
(anti-aliased). Every sheet has a matching camera-space **normal map** so
Godot 2D lights (the amulet's PointLight2D) shade the sprites.

| Piece | File |
|---|---|
| Shared helpers: scene, cel material, outline, normal pass, bmesh primitives | `tools/asset-pipeline/blender/navi_common.py` |
| Planar puppet rig, pose sampler with easing, 2-bone leg IK, renderer | `tools/asset-pipeline/blender/navi_rig.py` |
| Hero tier 1 «Павший» (14 animations) | `tools/asset-pipeline/blender/build_hero.py` |
| Трясинник (6 animations) | `tools/asset-pipeline/blender/build_crawler.py` |
| Топь backdrop: 3 parallax layers, ground strip, log platform | `tools/asset-pipeline/blender/build_swamp_bg.py` |
| Frames -> sheets + normal maps + JSON | `tools/asset-pipeline/blender/pack_sheets.py` |
| Evidence images | `tools/asset-pipeline/blender/make_evidence.py` |
| Godot: hero visual (drop-in for HeroVisual) | `src/player/hero_sprite.gd`, `scenes/hero/hero_sprite.tscn` |
| Godot: crawler skin, room dressing | `src/slice/crawler_sprite.gd`, `src/slice/art_slice.gd` |

## How to regenerate

```sh
apt-get install -y blender        # 4.0.2 on Ubuntu 24.04; any Blender 4.0-4.1 works (EEVEE legacy)
B="xvfb-run -a -s '-screen 0 1280x1024x24' blender -b --python"   # on a desktop PC: blender -b --python
eval $B tools/asset-pipeline/blender/build_hero.py -- /tmp/hraw
python3 tools/asset-pipeline/blender/pack_sheets.py /tmp/hraw assets/art/sprites/hero hero 560 480 230 452 320
eval $B tools/asset-pipeline/blender/build_crawler.py -- /tmp/craw
python3 tools/asset-pipeline/blender/pack_sheets.py /tmp/craw assets/art/sprites/crawler crawler 640 400 300 372 230
eval $B tools/asset-pipeline/blender/build_swamp_bg.py -- assets/art/sprites/swamp
```

`--only=run,roll` re-renders some animations (the other ones stay in `meta.json`),
`--still` renders one frame per animation for a quick look. The packer needs
Pillow and numpy (system Python, not Blender's).

Run the slice: `godot --path . -- --room=2 --seed=3 --hero-art=sprite --art-slice`
(`--art-stage` puts a crawler in front of the hero for screenshots). The hero
sprite alone is `--hero-art=sprite` or the project setting `navi/art/hero_art = "sprite"`;
without it the old cutout rig is used, unchanged.

## Timings on this machine (4 vCPU Xeon 2.3 GHz, no GPU, EEVEE on llvmpipe)

| Job | Frames | Time | Per frame (colour + normal pass) |
|---|---|---|---|
| Hero, 1120x960 render -> 560x480 cell | 101 | 282-297 s | 2.8-2.9 s |
| Трясинник, 1280x800 -> 640x400 | 41 | 115 s | 2.8 s |

Screenshots at 1920x1080 (the project window override is 720p, so `--write-movie` gives 1280x720): `xvfb-run -a godot --path . -s res://tests/integration/slice/art_shot.gd -- --shot=out.png --shot-frame=45 --room=2 --seed=3 --hero-art=sprite --art-slice --art-stage`; `make_evidence.py compare` builds art3d-compare.png.
| Backdrop layers 2560-3840 x 1080 | 5 images | 22 s | 2-8 s |

A full rebuild of everything is about 7 minutes here; on a PC with a GPU, under a minute.

## Licences

Nothing third-party is in the renders: models, rigs, materials and animations are
built by the scripts from primitives (recorded in `assets/provenance.yaml`).
Blender is GPL; its output is not. I did not use a downloaded CC0 rig: building
the model by script kept the hero on-model (art bible §5.1/§5.6) and avoided a
licence question per file. Mixamo, Quaternius, Kenney, Poly Haven are reachable
from the developer's PC and are the natural upgrade (below).

## Budgets (as built)

- Hero: 14 sheets x 2 (colour + normal), 8.4 MB PNG on disk; cell 560x480 at 2x
  of the on-screen size (160 px hero on 1080p). Largest sheet 4480x960.
  VRAM uncompressed ~ 14 x 2 x 4480x960x4 = ~480 MB if all loaded: **too much for
  shipping**. Fix before production: trim cells to the per-frame bounding box
  (most cells are 70% empty), pack all animations into a few atlases, and import
  with VRAM compression (BPTC/ASTC). Expected: 40-60 MB VRAM for the hero.
- Draw calls: one Sprite2D per actor, same as before.
- Lights: one PointLight2D (amulet) + CanvasModulate; normal mapping costs one
  extra texture fetch per lit pixel.

## Honest assessment vs Dead Cells

What works: the pipeline is real and reproducible, entirely free, and gives
consistent on-model frames in any number (the main reason Motion Twin used it);
anticipation / snap / hold timing, baked smear crescents, normal-mapped lighting,
three-quarter view with a visible face; the swamp backdrop has depth (three
parallax layers, fog, reflections, glowing idol eyes).

What is still far from Dead Cells:
- **Models are primitive-built** (capsules and ellipsoids). They read as clean
  toy-like 3D, not as sculpted characters: no anatomy, hands are mittens, the
  face is 3 dots. Dead Cells' models are sculpted and hand-painted, then the
  frames are pixel-cleaned by artists.
- **Animation is keyframed by script** in one plane. It has the right timing but
  little secondary motion (hair, beard, cloth, the crawler's weeds don't
  follow through) and no 3D twist of the torso.
- **No textures**: flat colours per part, no painted detail, no hand-painted
  highlights.
- The background is procedural geometry: good atmosphere, but trees are tubes
  and there is no painted foreground.
- Smears are ghostly (additive-ish blend) rather than the crisp, opaque
  Dead Cells smear shapes.

## v2 hero (branch `art-3d-v2`, 2026-11-27): real anatomy, skinned, painted

Evidence: `art3d-v2-hero-sheet.png` (all 14 animations), `art3d-v2-hero-closeup.png`
(idle frame 0 at 2x), `art3d-v2-compare.png` (v1 vs v2, same frames).

| Piece | File |
|---|---|
| Fetch the CC0 MakeHuman files (sparse, ~6 MB, not committed) | `tools/asset-pipeline/blender/fetch_makehuman.sh` |
| Base body: targets, stylisation, FK re-pose, weight folding (system Python + numpy) | `tools/asset-pipeline/blender/mh_base.py` |
| Derived base (committed, 0.5 MB; the only input build_hero.py needs) | `tools/asset-pipeline/blender/data/hero_base.json.gz` |
| Painted albedo nodes, `rest` attribute | `navi_common.paint_nodes`, `navi_common.add_rest` |
| Spring bones (follow-through) | `navi_rig.Rig.secondary` |

What changed:
- **Body**: MakeHuman hm08 base mesh (CC0), young male with a lean muscular build,
  head x1.07, hands x1.22, feet x1.1 for game read. Re-posed by FK with MakeHuman's
  own skeleton and smooth weights: arms hanging, near hand closed into a fist
  around the stick, far hand relaxed. One mesh, skinned to our 14-bone planar rig
  (the 163 MakeHuman bones' weights folded onto it), so shoulders, elbows, knees
  bend smoothly; no tubes.
- **Face**: real nose, brow ridge, ears, eyelids; eyeballs with sclera/iris/pupil
  and a highlight; heavy stern brows (shell); outline thinned on the face and
  hands and removed around the eyes (per-vertex solidify width).
- **Clothes and hair as shells grown from the body** (inherit its weights):
  baggy linen trousers with folds and dirt toward the hem, foot wraps with spiral
  bands and criss-cross cords, rope belt with a twisted pattern, scalp hair, a full
  beard pointed and pushed forward at the chin, plus tapered strands for a shaggy
  silhouette.
- **Secondary motion**: hair, beard, belt end and amulet hang on spring bones
  (damped point mass on a rigid bone, gravity blend; loops simulated three cycles
  so the cycle closes).
- **Painted look**: procedural albedo on an undeformed `rest` attribute (no
  swimming): noise colour variation, voronoi brush-patch value jitter, cloth weave,
  wood grain, hair streaks, wrap bands; under the same cel ramp, cool shadow
  tint, warm rim and warm-black outline as v1.
- Frame names, cell size (560x480), origin and sheet layout are unchanged:
  `src/player/hero_sprite.gd` and `scenes/hero/hero_sprite.tscn` need no change.

Regenerate: `sh tools/asset-pipeline/blender/fetch_makehuman.sh /tmp/mh` and
`python3 tools/asset-pipeline/blender/mh_base.py /tmp/mh/makehuman/data tools/asset-pipeline/blender/data/hero_base.json.gz`
(only when changing the body), then build_hero.py + pack_sheets.py as above.
Render: ~8.5 s per frame (colour + normal) here, about 3x v1 (13.5k-vertex body,
subdivided shells); a full hero rebuild ~15 min on this CPU, ~1 min with a GPU.

Honest v2 assessment: anatomy, hands, face and clothing now read as a real
character, and hanging parts follow through. Still short of Dead Cells: the
painted look is procedural (no hand-painted highlights or authored texture
maps), hair is a shell + strands rather than sculpted locks (reads a bit slicked
back), legs keep MakeHuman's A-stance splay in 3/4 view, the body is generic
MakeHuman (no sculpted stylisation of the silhouette), the run/attack keys are
still the v1 script keys (no torso twist), and smears are still the v1 crescents.

## What the developer can add on their PC (all free)

1. **Blender with GPU** (any recent NVIDIA/AMD): same scripts, 10-20x faster;
   switch to EEVEE Next (Blender 4.2+) for better soft shadows (the cel ramp
   via Shader to RGB still works).
2. **Mixamo** (free with an Adobe account): rig a better hero mesh and download
   run/attack/roll animations, retarget onto the rig; the renderer and packer
   stay the same.
3. **A real hero model**: sculpt in Blender, or start from CC0 bases
   (Quaternius «Ultimate Modular Characters», Kenney), then texture-paint.
4. **AI textures / painted backgrounds**: FLUX.1 [schnell] (Apache-2.0) locally
   via ComfyUI for hand-painted texture maps and far background plates; keep the
   3D layers for parallax and lighting. Record every generated image in
   `assets/provenance.yaml` (art bible §8).
5. **Cloth / hair simulation** in Blender for beard, hair and the future cape,
   baked before rendering.

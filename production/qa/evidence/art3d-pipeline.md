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

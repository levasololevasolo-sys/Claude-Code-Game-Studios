# Game Brief: Last Lumen

## In your words
1) Сделай мне игру
Есть только идея сделать рогалик с прокачкой и интересными механиками, системой ранов и улучшений
наработок нету
2) я хочу сделать что то типо рпг рогалика как дед селс, хейдес 1 и 2, вот такого формата
3) продажа в стим и хочу получить опыт
4) не знаю какой лучше подойдет, выбереш сам
5) пк
6) по прохождению я бы хотел что бы заняло ну дня 3-5 и дальше можно было перепроходить, улучшаться, усложнять процесс игровой
7) визуально дед селс, но по современнее, без пикселей
8) полный 0 в програмировании, столько сколько достаточно
9) работай максимально самостоятельно, потом будем вносить правки если получится не то что хотел

**Pitch:** A moth-winged lantern knight fights down through a drowned clockwork city whose last light is going out, and every enemy struck feeds the lantern until it erupts in a Flare that remakes the fight. *(inferred (strong))*

**Genre:** action roguelite, side view (runs that end in death, permanent upgrades between runs)

**Controls:** A/D or arrows to move, W / Space / Up to jump (double jump), Shift or K to dash, J or left click to strike, L or right click to Flare when the lantern is full, Esc to pause. *(guessed)*

**Question:** Is a fast side-view run, where the lantern charge turns hits into a Flare and room boons change how the Flare works, fun enough to want "one more run"? *(guessed)*

**Hooks:** The Lantern: every hit charges it, a full lantern unleashes a Flare (a burst of light that stuns and burns), and the dark room is only lit around the player, so the charge is also how far you can see. Boons rewrite the Flare (it chains, it heals, it leaves burning ground). *(guessed)*

**Intent:** payoff builds (from Hades, Dead Cells)

## Look and references
- Look: modern smooth 2D, no pixels: clean vector shapes with soft gradients and glow, painterly dark backgrounds in layered parallax (deep teal and indigo, cool shadows), the player in warm amber and cream, threats in rust red and sick magenta, loot and light in gold. Bold dark outlines on figures, none on the background. Signature: the screen is dark and the player's lantern really lights it; a Flare floods the room with light for a moment. Every figure drawn, no emoji, no plain circles.
- References: Dead Cells (speed of movement and combat, side-view rooms, the run and permanent unlock loop: values only), Hades I and II (a boon chosen after each room, clear readable upgrade text, a death that still moves you forward: values only).
- View: 2D side view · Camera: follows the player smoothly inside each room (`follow2d`), 1280x720 base, scales to fit.

## First minute
The title shows the knight with a dim lantern; Enter starts. Room one is safe: a short corridor with on-screen key hints for move, jump and dash; the lantern barely lights the way. Room two has two Rust Crawlers; striking them fills the lantern ring on the HUD, and at full the hint "L: Flare" pulses. The Flare lights the whole room, stuns both, and the last one falls with a hard hit, a pause, and the door opens with a chime. Three glowing boon cards appear: the player picks one, and the next room is already different.

## Challenge
Room two is gentle; by room four (about minute three) a mix of fliers and a shielded spitter forces dashing through shots. Floor 2 adds the exploding Bloat and denser rooms; the run ends with a Bell Warden boss. A death ends the run: boons are lost, collected Embers are kept and spent at the Shrine on small permanent upgrades (more health, a stronger Flare, a reroll). After a win, the next run can be started at Ash level 1+ (enemies tougher and faster) for more Embers.

## Core loop
- Enter a room; the doors lock; fight with strikes, dashes and the Flare.
- Clear it: Embers fly to you, pick one of three boons that changes your strike, dash or Flare.
- Rooms get harder across two floors and a boss; die or win.
- At the Shrine spend Embers on permanent upgrades, then start a new run, harder after a win.

## Goal & fail state
- A run is won by beating the Bell Warden at the end of floor 2; a run is lost when health hits zero.
- A session feels complete when a run ends and Embers are spent at the Shrine.

## Features
- [x] Side-view movement: run, double jump, dash untouchable from its first moment
- [x] Melee strike combo with hit stop and knockback; health
- [x] The Lantern: charge from hits, Flare when full, light radius tied to charge
- [x] 4 enemy kinds, each attacking differently (Rust Crawler charger, Wisp Bat swooper, Pike Sentry shielded spitter, Bloat exploder) and a Bell Warden boss
- [x] Rooms from hand-made layouts in a new order each run, safe first room, seed shown at the end
- [x] Boon choice after each room (one of three, each saying what it does), about 12 boons
- [x] Embers drop and fly to the player; Shrine between runs with permanent upgrades, saved
- [x] Ash levels: after a win, a harder run can be chosen

## Your systems
- run system (runs that end in death) · in the slice
- upgrades during a run (boons) · in the slice
- permanent progression between runs · in the slice
- rising difficulty on replay (Ash levels) · thin stand-in *(guessed)*
- 3-5 days of content to finish · later *(guessed)*

## Keep
-

## Avoid
- pixel art ("без пикселей")
- Dead Cells' and Hades' names, art, characters, UI and story

## Out of scope
- A hub between runs with characters and a story: grow it
- Many biomes and bosses (the full 3-5 days of content): grow it
- A shop in the middle of a run: change it after play
- Upgrades that multiply each other: add it as a feature
- Co-op runs on one screen: change it after play
- Gamepad support and Steam build: grow it

## Build order
1. The slice: one run of about 8 rooms over two floors plus the Bell Warden, with movement, strikes, dash, the Lantern and Flare, 4 enemy kinds, boons after each room, Embers and the Shrine; win by beating the boss, lose at zero health.
2. Tune feel and difficulty from play; add Ash levels depth.
3. Grow it: more biomes, weapons, bosses, a hub with characters, then the engine build for Steam.

---
**Kill condition:** if after two tuning rounds the Flare still feels like a button you press, not a moment you build toward.

**Who it's for / what they feel:** players of fast action roguelites who want to feel clever and strong as their build comes together.

**Games you love / don't:** Love Dead Cells (format, look) and Hades 1 and 2 (format).

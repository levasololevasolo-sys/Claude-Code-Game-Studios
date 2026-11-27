# Game Brief: Навь (Nav)

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

After play: да, как база выглядит уже прикольно
After play: нужно будет добавить разных фонарей которые бы имели разные способности, разные оружия
After play: добавить анимаций, что бы игра не выглядела каку дудл джамп
After play: монстров тоже апгрейднуть
After play: так же добавить базу, разные ресурсы, разные локации и что бы после боса была сейв комната где был бы выбор в какую локацию идти, у каждой локации должен быть свой привязанный босс
After play: нужно добавить будет еще кучу нпс, которые бы рассказывали сюжет, были бы полезные нпс на базе, по типу торговца, дробилки свето сфер, где можно было бы разбирать и собирать новые сферы
After play: придумать логичный сюжет почему наш воин возраждается,
After play: добавить артефакты который бы можно было находить или выбивать по мере прохождения, добавить секретные комнаты, отдельные мини локации с ловушками и сундуками
After play: по мере прохождения игры дальше локации должны ловить какие то триггеры и видоизменяться
After play: итоговый забег должен быть в районе  35-40 минут, в нем должно быть 6-8 локаций с уникальными боссами с своими механиками
After play: давай немного поменяем концепт, предложи какие есть варианты самые логичные где можно придумать кучу новых доработок, возможно мир элементалей, мифологии какие то
After play: нужно что бы не было похоже и отличалось от самых популярных таких же игр, а то сейчас напоминает силк сонг
After play: надо исправить анимацию атаки, а то след от оружия находится сзади героя при движениях
Chosen: «Навь: славянские боги» (on the concept card)
After play: нужно добавить физику, добавить удары вверх, вниз по поводу покупок оружия и доп слота оружия, идея норм
After play: но давай мы сделаем вариантов оружия штук 35 и доп оружия штук 20
After play: каждый бы имел свое качество, редкость, уникальные механики, если оружие имеет высокое качество, есть шанс  оружия появиться еще с доп каким то эффектом
After play: нужно добавить бафы и дебафы
After play: систему рун героя, когда находит герой какую то руну, он получает еще дополнительную фишку на деш, атаку, спец атаку, от разных рун могут быть синергии( система как в хейдес)
After play: оружия нужно что бы можно было покупать у торговца и если ты его купил, то можешь найти в забеге, так же больше половины оружия я бы сделал супер уникальными, добавил бы луки, бомбы какие то, ловушки, магические палочки и их можно только найти в самом забеге
After play: нужно самое главное придумать систему когда в теории можно будет найти синергию, где твой герой был бы супер имба
After play: крч суть в том, что бы каждый забег был уникален и не похож не на что другое, в конце каждой комнаты, добавить развилку по 2-3м дверям, где ты получал или какой то ресурс по завершению локации или какой то баф для героя

**Pitch:** A fallen bogatyr, held to life by the thread of the goddess Mokosh, cuts his way through Nav, the Slavic underworld that has flooded into the living world, taking back the gods' elemental powers from the monsters of the tales; every blow charges his god's amulet until it bursts in that god's wrath. *(you chose the world; details inferred)*

**Genre:** action roguelite, side view (runs that end in death, permanent upgrades between runs)

**Controls:** A/D or arrows to move, W / Space / Up to jump (double jump), Shift or K to dash, J or left click to strike, L or right click to Flare when the lantern is full, E or Enter to use (stations, doors), Esc to pause. *(guessed)*

**Question:** Is a fast side-view run, where the lantern charge turns hits into a Flare and room boons change how the Flare works, fun enough to want "one more run"? *(guessed)*

**Hooks:** The Amulet (was the Lantern): every hit charges it, a full lantern unleashes a Flare (a burst of light that stuns and burns), and the dark room is only lit around the player, so the charge is also how far you can see. Boons rewrite the Flare (it chains, it heals, it leaves burning ground). *(guessed)*

**Intent:** payoff builds (from Hades, Dead Cells)

## Look and references
- World: Slavic mythology, not an insect or bug world (it read as Silksong). No Greek gods (Hades), no castle (Dead Cells).
- Look: modern smooth 2D, no pixels: clean vector shapes with soft gradients and glow, painterly dark backgrounds in layered parallax (bog green, night-forest blue, frost white), Slavic folk ornament on wood and cloth, the hero in steel, red and gold, threats in rust red and sick magenta, loot and light in gold. Bold dark outlines on figures, none on the background. Signature: Nav is dark and the hero's amulet really lights it; a Flare floods the room with light for a moment. Every figure drawn, no emoji, no plain circles.
- References: Dead Cells (speed of movement and combat, side-view rooms, the run and permanent unlock loop: values only), Hades I and II (a boon chosen after each room, clear readable upgrade text, a death that still moves you forward: values only).
- View: 2D side view · Camera: follows the player smoothly inside each room (`follow2d`), 1280x720 base, scales to fit.

## First minute
The title tells why the hero returns: Koschei broke the Kalinov Bridge, Nav poured into the living world, the bogatyr fell on the bridge, and the Spinner of Mokosh holds his thread. Enter opens the Outpost, a wooden fort: the Spinner by the stove, the Owl Witch who makes amulets, Potap the bear smith, the shrine of Rod, a straw training effigy and the gate to Nav. At the gate, E starts the run in Kikimora's Bog.

## Challenge
The first room is gentle; by its third room a mix of fliers and a shielded spitter forces dashing through shots. Each location ends in its boss; the second and third locations are harder (more and tougher enemies, elites), whichever order is chosen. A death ends the run: boons are lost, collected Embers are kept and spent at the Shrine on small permanent upgrades (more health, a stronger Flare, a reroll). After a win, the next run can be started at Ash level 1+ (enemies tougher and faster) for more Embers.

## Core loop
- Enter a room; the doors lock; fight with strikes, dashes and the Flare.
- Clear it: Embers fly to you, pick one of three boons that changes your strike, dash or Flare.
- Rooms get harder across two floors and a boss; die or win.
- At the base spend Embers and resources on permanent upgrades, new lanterns and weapons, then start a new run, harder after a win.

## Goal & fail state
- A run is won by beating the three location bosses (Kikimora of the Bog, Likho One-Eye, Morena of the Frost) in the order chosen; a run is lost when health hits zero, and can be left from a save room to bank the loot.
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
- [x] 4 lanterns, each with its own Flare and passive, made at the base from resources (now amulets of Svarog, Perun, Zhiva, Veles)
- [x] 4 weapons that play differently (blade, harpoon spear, twin sickles, bell hammer), made at the base
- [x] A walkable base: Shrine, Lantern-maker, Armorer, a training dummy and the Gate; resources banked there
- [x] 3 locations (Drowned Clockworks, Silent Belfry, Moon Reef), each with its own enemies, look, resource and boss
- [x] After each boss a safe save room: heal, the run is saved, choose which location is next or return to base
- [x] Animation: a jointed knight (legs, arms, cape, wings, antennae), weapon smears, squash and stretch, enemy wind-ups, hit squash, spawn and death dissolves
- [x] Upgraded monsters: new attacks for old kinds, 2 new kinds (Bell Ringer, Lantern Jelly), elite variants, 2 new bosses
- [ ] Up and down strikes (pogo bounce on a down strike), heavier physics (knockback, enemy weight)
- [ ] Runes instead of boons: each adds to the dash, strike or special; pairs of runes unlock synergy runes
- [ ] The top goal: a synergy system where a run can, in theory, build an overpowered hero; every run unique
- [ ] A fork of 2-3 doors after each room, each showing its reward (a resource, a rune, a weapon, a buff)
- [ ] Merchant: buys unlock weapons into the drop pool; more than half the weapons (bows, bombs, traps, wands) only drop in runs
- [ ] Weapon loot: 35 main and 20 secondary weapons, rarity and quality, high quality may roll an extra effect; a secondary weapon slot
- [ ] Buffs and debuffs (burn, frost, bleed, curse, haste, shield) shown on the HUD
- [x] Re-theme to Nav: bogatyr hero, Spinner / Owl Witch / bear smith, Kikimora's Bog, Likho's Pinewood, Morena's Frost; enemies and bosses redrawn as Slavic creatures

## Your systems
- run system (runs that end in death) · in the slice
- upgrades during a run (boons) · in the slice
- permanent progression between runs · in the slice
- rising difficulty on replay (Ash levels) · thin stand-in *(guessed)*
- different amulets (god spheres) with different abilities · in the slice
- the Slavic world: Nav, Mokosh's thread as the reason for return · in the slice
- different weapons · in the slice
- base · in the slice
- different resources · in the slice
- different locations, each with its own boss · in the slice
- save room after each boss with the choice of location · in the slice
- 3-5 days of content to finish · later *(guessed)*

## Keep
- как база выглядит уже прикольно (the warm look of the base) *(you said)*
- the systems of iteration 1 (amulets, weapons, base, locations with bosses, save rooms), re-themed

## Avoid
- pixel art ("без пикселей")
- Dead Cells' and Hades' names, art, characters, UI and story
- a look close to Hollow Knight / Silksong: no insect hero, no bug kingdom

## Out of scope
- A story told by the base's characters: grow it
- More biomes and bosses beyond three (the full 3-5 days of content): grow it
- A shop in the middle of a run: change it after play
- Upgrades that multiply each other: add it as a feature
- Co-op runs on one screen: change it after play
- Gamepad support and Steam build: grow it

## Build order
1. The slice: a run through 3 locations of 4 rooms and a boss each, a save room after each boss to pick the next location, the base between runs with lanterns, weapons and resources; win by beating all three bosses, lose at zero health.
2. Tune feel and difficulty from play; add Ash levels depth.
3. Grow it: more biomes, weapons, bosses, a hub with characters, then the engine build for Steam.

---
**Kill condition:** if after two tuning rounds the Flare still feels like a button you press, not a moment you build toward.

**Who it's for / what they feel:** players of fast action roguelites who want to feel clever and strong as their build comes together.

**Games you love / don't:** Love Dead Cells (format, look) and Hades 1 and 2 (format).

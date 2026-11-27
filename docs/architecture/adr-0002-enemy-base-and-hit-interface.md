# ADR-0002: Базовый класс Enemy и интерфейс удара Hit

## Status

Accepted

## Date

2026-11-27

## Last Verified

2026-11-27

## Decision Makers

technical-director; рекомендация godot-gdscript-specialist (ревью кода); решение делегировано
разработчиком (2026-11-27).

## Summary

Герой сейчас знает только `StrawDummy`, поэтому настоящих врагов не к чему подключить. Вводим
абстрактный класс `Enemy` (Node2D, своя простая физика как в прототипе) с полями `w`, `h`,
`flies`, `dead` и методами `hurt(hit: Hit)` и `launch(speed)`; весь урон по врагу идёт через
`hurt`, а формулы урона живут в чистом `DamageRules`.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7 (ПК: 4.7.1) |
| **Domain** | Core |
| **Layer** | Foundation |
| **Knowledge Risk** | MEDIUM — `@abstract` (4.5) и правило типов возврата при переопределении (4.7) |
| **References Consulted** | `breaking-changes.md` § 4.6→4.7, `current-best-practices.md` § GDScript (4.5+), (4.7) |
| **Post-Cutoff APIs Used** | `@abstract` (4.5) |
| **Verification Required** | Наследник `Enemy` без `_behave()` даёт ошибку разбора; `Enemy.new()` невозможен |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (характеристики врагов из `enemies.json`) |
| **Enables** | ADR-0007 (статусы и руны), враги, боссы, оружие |
| **Blocks** | Шаг 2 и 3 порядка переноса (урон, враги) |
| **Ordering Note** | Первая задача по коду (`architecture.md` §9) |

## Context

### Problem Statement
`player.gd` перебирает `Array[StrawDummy]`, сигнал `hit_landed` типизирован чучелом, а герой и
чучело сами пишут `world.hitstop`. GDD требует **одну** точку урона (`hurtEnemy`), через которую
идут удары, тики статусов, Вспышка, снаряды и удары о стену.

### Constraints
- Порт должен вести себя как прототип: враги стоят на полу (`ground_y`), летающие не падают,
  отброс делится на вес — в прототипе это простая ручная кинематика.
- Удары проверяются прямоугольниками от ног (`origin` у ног), как сейчас.

## Decision

### Классы
```
Node2D
└─ Enemy (@abstract, src/enemies/enemy.gd)
   ├─ StrawDummy        src/enemies/dummy.gd
   ├─ Crawler, Bat, Sentry, Bloat, ...   по файлу на вид
   ├─ Knight            Навий витязь
   └─ Boss (@abstract)  src/enemies/bosses/boss.gd

RefCounted
├─ Hit          src/combat/hit.gd         — описание одного удара
├─ DamageRules  src/combat/damage_rules.gd — static, чистые формулы
└─ StatusSet    src/combat/status_set.gd   — статусы на одной цели
```

### Key Interfaces
```gdscript
## src/combat/hit.gd
class_name Hit extends RefCounted
enum Kind { STRIKE, SLAM, PROJECTILE, FLARE, TICK, WALL, CONTACT }
var kind: Kind = Kind.STRIKE
var dmg: float = 0.0          # базовый урон до множителей
var from_x: float = 0.0       # откуда пришёл удар (направление отброса и щита)
var kb: float = 0.0           # сила отброса до деления на вес
var pierce: bool = false      # пробивает щит спереди (булава)
var finisher: bool = false
var burn: float = 0.0         # сила наложения статусов, 0 = нет
var stun: float = 0.0
var mods: Dictionary = {}     # модификаторы сборки героя (руны, баффы): "reaper", "heat"...
var source: Node = null       # кто ударил (может быть null)

## src/enemies/enemy.gd
@abstract
class_name Enemy extends Node2D
signal damaged(enemy: Enemy, amount: float, hit: Hit)
signal died(enemy: Enemy, hit: Hit)
var kind_id: String = ""      # ключ в enemies.json
var w: float                  # ширина хитбокса, px (из таблицы)
var h: float                  # высота хитбокса, px; origin у ног
var flies: bool = false
var dead: bool = false
var boss: bool = false
var hp: float
var max_hp: float
var weight: float = 1.0
var vel: Vector2 = Vector2.ZERO
var statuses: StatusSet
var world: World              # внедряется тем, кто создаёт врага

func hurt_rect() -> Rect2     # Rect2(x - w/2, y - h, w, h)
func hurt(hit: Hit) -> float  # ЕДИНСТВЕННЫЙ вход урона; возвращает нанесённый урон
func launch(speed: float) -> void
@abstract func _behave(dt: float) -> void   # поведение вида; базовый класс делает остальное
```

`Enemy._physics_process` (не переопределяется): пропуск при `world.hitstop > 0` → тики
`statuses` → `_behave(dt)` (если не оглушён) → гравитация (если не `flies`) → движение →
пол/стены комнаты → затухание отброса → проверка удара о стену. Наследник пишет только
`_behave` и `_draw`/визуал.

`Enemy.hurt(hit)` по порядку GDD movement-and-combat §3.7: мёртвый → 0; `DamageRules.final()`
(множители, щит спереди, воздух); вычесть hp; вспышка/цифра; отброс `DamageRules.knockback()`;
статусы; `damaged.emit`; при hp ≤ 0 → `dead = true`, `died.emit`, `Events.enemy_killed.emit`.

### Герой
- `Player` перебирает `Array[Enemy]` из группы `"enemies"`, строит `Hit` и вызывает
  `e.hurt(hit)`. Сигнал `hit_landed(enemy: Enemy, dmg: float)`.
- `Player.hurt(hit: Hit) -> float` — единая точка урона по герою (GDD §3.11: неуязвимость,
  рывок, щит Живы первым).
- Ощущения удара — только через `World`: `request_hitstop(t)` (берёт max), `add_shake(s)`,
  `add_ring(p, r)`. `World` — это нынешний `Main`, переименованный в `src/world/world.gd`.

### Implementation Guidelines
- Урон по врагу **must** идти только через `Enemy.hurt(hit)`; прямое `e.hp -= ...` запрещено.
- Формулы **must** жить в `DamageRules` (static, без узлов) и иметь unit-тесты.
- `Player` **must never** ссылаться на конкретный вид врага (`StrawDummy`, `Bat`...).
- Переопределение метода с типом возврата **must** иметь явный `return` (правило 4.7).
- Хитбоксы — `Rect2`, не `Area2D`. Враги не являются `PhysicsBody2D`.
- Характеристики вида (`hp`, `w`, `h`, `weight`, `flies`, урон, скорость) **must** читаться из
  `Tune.row("enemies", kind_id)` в `_ready()`.

## Alternatives Considered

### Alternative 1: `CharacterBody2D` + `Area2D` хитбоксы/хёртбоксы
- **Pros**: «по-годотовски», готовые столкновения, формы любой сложности.
- **Cons**: отброс, вес, удары о стену и «кегли» прототипа придётся переписать под физику
  движка и заново подбирать; сигналы `area_entered` приходят с задержкой на кадр; больше узлов.
- **Rejection Reason**: ломает соответствие прототипу и усложняет то, что уже работает.

### Alternative 2: Утиная типизация (`has_method("hurt")`) без базового класса
- **Pros**: ноль кода сейчас.
- **Cons**: ошибки только во время игры; общая логика (статусы, отброс) копируется в каждый вид.
- **Rejection Reason**: через 8 видов и 3 босса это станет главным источником багов.

### Alternative 3: Компоненты-узлы (`HealthComponent`, `HurtboxComponent`)
- **Pros**: гибко.
- **Cons**: для новичка много невидимых связей между узлами; врагов всего ~12 видов.
- **Rejection Reason**: наследование одного уровня проще и достаточно.

## Consequences

### Positive
- Новый вид врага = один файл с `_behave` + строка в `enemies.json`.
- Руны, оружие и статусы подключаются в одном месте (`Hit.mods` → `DamageRules`).

### Negative
- `@abstract` — функция 4.5+, её нет в памяти модели; держим использование минимальным.
- Своя кинематика: враги не стоят на платформах (как в прототипе). Если дизайн захочет — нужен
  новый ADR.

## Risks
- **Глубокая иерархия** → правило: не больше двух уровней под `Enemy` (`Boss` → конкретный босс).
- **`Hit.mods` разрастётся в «мешок»** → ключи перечисляются в ADR-0007 и проверяются тестом.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| movement-and-combat.md | §3.7 весь урон через `hurtEnemy`, порядок шагов | `Enemy.hurt(hit)` + `DamageRules` |
| movement-and-combat.md | §3.8 вес, отброс, удары о стену и «кегли» | общий `_physics_process` в `Enemy` |
| movement-and-combat.md | §3.9 воздушный множитель только для нелетающих | `flies`, `DamageRules.final()` |
| movement-and-combat.md | §3.10 хитстоп — берётся большее | `World.request_hitstop()` |
| movement-and-combat.md | §3.11 урон по герою, щит первым | `Player.hurt(hit)` |
| enemies-and-elites.md | §3.1 общие правила врагов, оглушение, летающие | базовый `Enemy` |
| gods-and-runes.md | §3.7 статусы на враге | `StatusSet` в `Enemy` |

## Performance Implications
- **CPU**: ~30 врагов × несколько `Rect2.intersects` за удар — микросекунды. `Hit` создаётся
  на попадание (не на кадр).
- **Memory**: незначительно.
- **Load Time**: нет.
- **Network**: нет.

## Migration Plan
1. Создать `hit.gd`, `damage_rules.gd` (пока: множитель комбо, воздух, отброс), `enemy.gd`.
2. `StrawDummy extends Enemy`: перенести `_physics_process` в `_behave` (пусто) + особое
   правило «не умирает ниже 50%» (GDD §3.7 п.7).
3. `player.gd`: `StrawDummy` → `Enemy`, вызовы `hurt(dmg, from_x, kb)` → `hurt(hit)`.
4. `main.gd` → `world.gd` (`class_name World`) с `request_hitstop/add_shake/add_ring`.
5. Прогнать `tests/integration/core/demo_driver.gd` — поведение и снимки как до изменений.

**Rollback plan**: изменения в 4 файлах, откат одним `git revert`.

## Validation Criteria
- `grep -r StrawDummy src/player` пусто.
- Unit-тесты `DamageRules`: множитель добивающего, воздушный множитель, щит спереди, вес.
- Демо-прогон даёт те же снимки, что до рефакторинга.

## Related
- `src/player/player.gd`, `src/enemies/dummy.gd`, `src/core/main.gd`
- ADR-0001, ADR-0007 (будущий)

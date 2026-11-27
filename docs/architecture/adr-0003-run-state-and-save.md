# ADR-0003: Состояние забега, сохранение и seed

## Status

Accepted

## Date

2026-11-27

## Last Verified

2026-11-27

## Decision Makers

technical-director; решение делегировано разработчиком (2026-11-27).

## Summary

Состояние забега (`RunState`) и мета-прогресс (`MetaState`) — простые классы данных с
`to_dict()/from_dict()`, которыми владеет автозагрузка `Game` и которые передаются системам
ссылкой. Сохраняются в один JSON-файл `user://save.json` с версией, слиянием с умолчаниями и
атомарной записью; вся геймплейная случайность идёт из именованных потоков `RunRng` от seed забега.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7 (ПК: 4.7.1) |
| **Domain** | Core |
| **Layer** | Foundation |
| **Knowledge Risk** | MEDIUM — с 4.4 `FileAccess.store_*` возвращают `bool` |
| **References Consulted** | `VERSION.md` § Before the Cutoff (4.4 FileAccess return types), `breaking-changes.md` § 4.3→4.4 |
| **Post-Cutoff APIs Used** | None (возврат `bool` у `store_string` — 4.4, проверяем его) |
| **Verification Required** | Сейв переживает закрытие игры во время записи (файл не пустой и не битый) |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (умолчания и цены — в JSON) |
| **Enables** | Забег (шаг 7), экономика и база (шаг 10), Пепел (шаг 11) |
| **Blocks** | Сейв-комната (привал), Святилище, торговец |
| **Ordering Note** | `RunRng` нужен уже при шаге 6 (развилки); файл сейва — при шаге 7 |

## Context

### Problem Statement
Забег живёт через много комнат и сцен; часть систем (руны, оружие, баффы, угли) должны
читать и менять одно общее состояние. Между забегами копится мета. Прототип хранит всё в
`localStorage` под ключом `last-lumen-save-v2`.

### Current State
Состояния нет: `main.gd` держит `room_k`, `tier`, `seed_value` и создаёт генератор комнаты из
`seed * 1000 + tier * 100 + room_k`.

### Requirements
- Поля сейва — таблица GDD economy-and-meta §3.9; новые поля не ломают старый файл.
- Сохранение на привале и восстановление забега с того же места, включая seed.
- Одинаковый seed → одинаковые комнаты, развилки, предложения рун и добыча.

## Decision

### Данные
```gdscript
## src/meta/meta_state.gd — всё между забегами (embers, res, up, lanterns, weapons, subs,
## lantern/weapon/sub, runs/wins/bestRooms, maxAsh/ash, bosses)
class_name MetaState extends RefCounted
static func defaults() -> Dictionary
func to_dict() -> Dictionary
static func from_dict(d: Dictionary) -> MetaState   # сливает с defaults()

## src/meta/run_state.gd — один забег (маршрут, tier, room_k, hp, max_hp, заряд, руны,
## угли и ресурсы забега, перебросы, воскрешение, ash, оберег, оружие+звёзды+аффикс,
## доп. оружие, баффы, run_seed, состояния потоков RunRng)
class_name RunState extends RefCounted
signal changed(field: StringName)
func to_dict() -> Dictionary
static func from_dict(d: Dictionary) -> RunState

## src/core/run_rng.gd
class_name RunRng extends RefCounted
func _init(run_seed: int) -> void
func stream(name: StringName) -> RandomNumberGenerator        # rooms, doors, loot, boons, enemies_ai
func for_room(tier: int, room_k: int) -> RandomNumberGenerator # hash([seed, "rooms", tier, room_k])
func save_states() -> Dictionary
func load_states(d: Dictionary) -> void
```

### Владелец
Автозагрузка `Game` (`src/core/game.gd`) держит `meta: MetaState`, `run: RunState` (или
`null`), `rng: RunRng`; умеет `load_save()`, `write_save()`, `start_run(seed)`, `end_run()`,
`goto_hub()`, `goto_run()`. **Системы не обращаются к `Game` сами**: сцена `Run` при старте
передаёт `run_state` и нужные потоки своим детям (`player.build = run.build`,
`hud.bind(run)`). Так системы проверяются тестом без автозагрузки.

### Файл
```json
{ "version": 1, "meta": { ... }, "run": null }
```
- Путь `user://save.json`. Запись: `user://save.tmp` → проверить, что `store_string` вернул
  `true` и файл закрыт → `DirAccess.rename_absolute(tmp, save)`.
- Загрузка: нет файла / не разбирается / `version` новее нашей → чистые умолчания и
  `push_warning` (битый файл переименовать в `save.bad.json`, не удалять).
- `version` растёт, когда меняется **смысл** поля; к каждому шагу — функция `migrate_vN()`.
- Когда пишем: вход на привал, конец забега (`end_run`), покупка на базе, выход в меню.
- `--fresh` в аргументах запуска — не читать сейв.

### Implementation Guidelines
- Геймплейная случайность **must** идти из потоков `RunRng`; `randf()/randi()` — только косметика.
- Чистая логика **must** получать `RandomNumberGenerator` параметром.
- Новое поле сейва **must** иметь значение в `defaults()` и тест «старый файл без поля грузится».
- Сохранение в середине комнаты **must not** существовать (как в прототипе).
- `RunState` **must** содержать только данные (числа, строки, массивы, словари) — никаких узлов.

## Alternatives Considered

### Alternative 1: `ResourceSaver` + `.tres` состояния
- **Pros**: типы, встроено.
- **Cons**: `.tres` из `user://` может содержать скрипты — загрузка чужого сейва исполняет код;
  смена класса ломает старые сейвы.
- **Rejection Reason**: небезопасно и хрупко для формата, который должен жить годами.

### Alternative 2: `ConfigFile`
- **Pros**: просто.
- **Cons**: плохо подходит для вложенных структур (руны, оружие с аффиксом, маршрут).
- **Rejection Reason**: снимок забега глубоко вложен.

### Alternative 3: Состояние в автозагрузке, системы читают её напрямую
- **Pros**: меньше передачи ссылок.
- **Cons**: противоречит стандарту «внедрение зависимостей вместо синглтонов»; тесты требуют
  всей игры.
- **Rejection Reason**: `Game` владеет, но не раздаёт себя всем.

## Consequences

### Positive
- Сейв читается глазами; баг-репорт = приложить `save.json`.
- Детерминизм проверяется тестом; seed можно показать игроку и в отчётах о багах.

### Negative
- `to_dict/from_dict` пишутся руками для каждого поля.
- Seed прототипа и порта несовместимы (разные генераторы) — сравниваем по правилам, не по seed.

## Risks
- **Поле забыли в `to_dict`** → тест «туда-обратно»: `from_dict(to_dict(x))` равен `x`.
- **Steam Cloud позже** → один файл в `user://` переносится без изменений.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| economy-and-meta.md | §3.9 поля сейва; слияние с умолчаниями; `?fresh=1` | `MetaState`/`RunState`, `defaults()`, `--fresh` |
| economy-and-meta.md | §3.6 привал, §3.7 конец забега | точки записи |
| room-generation-and-doors.md | §4 порт: один seed — одна комната; критерий 15 | `RunRng.for_room()` |
| weapons-and-loot.md | проверки на фиксированном seed | поток `loot` |
| gods-and-runes.md | §3.4 предложение из 3 рун | поток `boons` |

## Performance Implications
- **CPU**: запись < 5 мс; только в точках записи.
- **Memory**: < 100 КБ.
- **Load Time**: незаметно.
- **Network**: нет.

## Migration Plan
1. `RunRng` + перевод `main.gd` на `rng.for_room(tier, room_k)` (тест `RoomGen` не меняется).
2. `RunState` / `MetaState` — вместе с забегом (шаг 7) и экономикой (шаг 10).

**Rollback plan**: формат версионирован; откат кода не трогает файл игрока.

## Validation Criteria
- Тест «туда-обратно» для `MetaState` и `RunState`.
- Тест: старый сейв без нового поля грузится с умолчанием.
- Тест: два `RunRng(42)` дают одинаковые комнаты, развилки и руны.

## Related
- `src/core/main.gd` (seed сейчас), `design/gdd/economy-and-meta.md` §3.9
- ADR-0001

# ADR-0001: Формат данных контента — JSON в assets/data

## Status

Accepted

## Date

2026-11-27

## Last Verified

2026-11-27

## Decision Makers

technical-director; решение делегировано разработчиком (режим `full`, 2026-11-27).

## Summary

Все игровые числа и таблицы контента (враги, оружие, боги, руны, баффы, цены) хранятся в
JSON-файлах `assets/data/*.json` и читаются автозагрузкой `Tune`. Godot-ресурсы `.tres`
используются только для того, что делает редактор: сцены, анимации, темы, материалы.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7 (ПК: 4.7.1) |
| **Domain** | Core |
| **Layer** | Foundation |
| **Knowledge Risk** | LOW — `JSON.parse_string`, `FileAccess.get_file_as_string` не менялись |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md`, `current-best-practices.md` § Resources |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | В первой экспортированной сборке игра читает `tuning.json` (риск R7 в `architecture.md`) |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None |
| **Enables** | ADR-0002 (таблица врагов), ADR-0003 (умолчания сейва) |
| **Blocks** | Перенос врагов, оружия, рун, экономики |
| **Ordering Note** | Уже частично реализовано (`src/core/tune.gd`, `tuning.json`) |

## Context

### Problem Statement
В игре сотни чисел и таблиц (35 + 20 видов оружия, 8+ видов врагов, боги × слоты, аффиксы,
цены). Стандарт `coding-standards.md` требует держать их вне кода. Нужно выбрать один формат,
пока таблиц ещё нет.

### Current State
`tuning.json` (скаляры героя и комнат) читается `Tune`; `RoomGen` получает словарь параметром
и проверяется тестом. Работает.

### Constraints
- Разработчик — новичок; правки часто делает ИИ-агент через текст.
- Источник чисел — `prototypes/last-lumen/config.js`: это JS-объекты, почти один в один JSON.
- Чистая логика должна проверяться без сцены и без редактора.

### Requirements
- Одно место для каждого числа; ошибка «нет ключа» видна сразу.
- Читаемый `git diff` при балансировке.

## Decision

**JSON, один файл на таблицу, в `assets/data/`, читает только `Tune`.**

- Скаляры — `tuning.json` (как сейчас). Таблицы — `enemies.json`, `bosses.json`, `gods.json`,
  `weapons.json`, `buffs.json`, `economy.json`, `locations.json`.
- Таблица — словарь `{ "_note": "...единицы...", "<id>": { ... } }`. id — `snake_case`, как в
  прототипе (`bat`, `knight`, `blade`).
- `Tune` получает два метода: `table(name) -> Dictionary` (читает `assets/data/<name>.json`
  один раз и кэширует) и `row(name, id) -> Dictionary` (с `push_error`, если строки нет).
- `.tres` — только для сцен, `AnimationPlayer`-библиотек, `Theme`, материалов, шин звука.

### Key Interfaces
```gdscript
Tune.f("run_speed")              # float, уже есть
Tune.get_value("blade")          # Variant, уже есть
Tune.table("enemies")            # Dictionary всех строк
Tune.row("enemies", "bat")       # Dictionary одной строки
```

### Implementation Guidelines
- Игровое число **must never** быть литералом в `.gd` (исключения: 0, 1, геометрия временной
  графики `_draw`, константы физических слоёв).
- Чистая логика (`RefCounted` + `static func`) **must** получать таблицу параметром, а не
  читать `Tune` сама — так её проверяет тест.
- Узлы читают значения в момент использования (`Tune.f(...)` в тике), чтобы `Tune.reload()`
  работал во время игры.
- Каждый новый JSON-файл **must** иметь тест, который читает его и проверяет обязательные поля
  каждой строки (простая «схема» в тесте).
- В JSON все числа — `float`; где нужно целое, код делает `int(...)`.

## Alternatives Considered

### Alternative 1: Godot-ресурсы `.tres` (`class_name EnemyDef extends Resource`)
- **Pros**: типизированные поля, правка в инспекторе, ссылки на текстуры и сцены.
- **Cons**: на каждую таблицу — класс + десятки файлов; ИИ-агенту и новичку труднее править;
  переименование поля ломает `.tres` молча; перенос из `config.js` — ручной.
- **Estimated Effort**: в 2–3 раза больше на перенос.
- **Rejection Reason**: проигрывает в простоте; выгода (ссылки на ассеты) нужна только для
  графики, а её мы связываем в сценах.

### Alternative 2: `const` словари в GDScript
- **Pros**: проверка при разборе скрипта, ноль кода загрузки.
- **Cons**: нарушает стандарт «числа вне кода»; нельзя перезагрузить без перезапуска.
- **Rejection Reason**: противоречит `coding-standards.md`.

## Consequences

### Positive
- Перенос из `config.js` почти механический; балансировка — правка одного текстового файла.
- Тесты читают тот же файл, что и игра.

### Negative
- Нет проверки типов: опечатку в ключе ловит только `push_error` или тест схемы.
- Ссылки на ассеты (иконка оружия) хранятся строкой-путём и проверяются тестом.

### Neutral
- `Tune` остаётся автозагрузкой: это неизменяемый конфиг, а не игровое состояние.

## Risks
- **JSON не попал в экспорт** → проверить в первой сборке; добавить `*.json` в фильтр экспорта.
- **Файл стал огромным** (оружие) → разрешено разбить на `weapons_main.json` и
  `weapons_sub.json`, `Tune.table` не меняется.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| movement-and-combat.md | §7 Tuning Knobs — все тайминги и силы настраиваются | уже в `tuning.json` |
| enemies-and-elites.md | §3.2 таблица видов, §3.3 сила по ярусу | `enemies.json` |
| weapons-and-loot.md | §3.2–3.5 ARM_ROWS, SUB_ROWS, аффиксы | `weapons.json` |
| gods-and-runes.md | §3.5–3.9 руны по слотам, DUOS | `gods.json` |
| economy-and-meta.md | §3.4 стоки, цены | `economy.json` |

## Performance Implications
- **CPU**: разбор всех файлов < 50 мс при старте; чтение по ключу — доступ к словарю.
- **Memory**: < 1 МБ.
- **Load Time**: незаметно.
- **Network**: нет.

## Migration Plan
Ничего не ломается: добавить `table()`/`row()` в `tune.gd`, новые таблицы — по мере переноса
систем.

**Rollback plan**: таблицу можно перевести на `.tres` по одной — меняется только `Tune.row`.

## Validation Criteria
- `grep` по `src/` не находит игровых чисел-литералов (ревью кода).
- Тест схемы для каждого JSON проходит.

## Related
- `src/core/tune.gd`, `assets/data/tuning.json`, `tests/unit/room_gen/test_room_gen.gd`
- `docs/architecture/architecture.md` §5

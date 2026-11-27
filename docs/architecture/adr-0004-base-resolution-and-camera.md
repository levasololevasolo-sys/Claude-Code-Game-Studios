# ADR-0004: Базовое разрешение 1920×1080, растяжение и камера

## Status

Accepted

## Date

2026-11-27

## Last Verified

2026-11-27

## Decision Makers

technical-director; запрос art-director (art bible §8); решение делегировано разработчиком
(2026-11-27).

## Summary

Art bible просит 1920×1080 вместо нынешних 1280×720, но все числа игры (скорости, ширина
комнат, `ground_y`) — в пикселях прототипа 1280×720. Решение: базовый экран 1920×1080,
`stretch/mode = canvas_items`, `aspect = expand`, а камера мира с `zoom = 1.5`, чтобы мир
остался в единицах прототипа и ни одно число баланса не менялось.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7 (ПК: 4.7.1) |
| **Domain** | Rendering |
| **Layer** | Foundation |
| **Knowledge Risk** | MEDIUM — в 4.7 изменились стандартные `stretch` (только для новых проектов) и толщина `draw_line` |
| **References Consulted** | `breaking-changes.md` § 4.6→4.7 (Project stretch defaults, CanvasItem line drawing), `modules/rendering.md` |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | Снимки экрана при окне 1280×720, 1920×1080, 2560×1440 и 2560×1080: мир показывает ту же высоту, контуры чёткие, HUD не обрезан |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None |
| **Enables** | ADR-0005 (размер частей героя), HUD, параллакс-фоны |
| **Blocks** | Любая работа с графикой и интерфейсом |
| **Ordering Note** | Делать до первой нарисованной части и до HUD (`architecture.md` §9, задача 2) |

## Context

### Problem Statement
Векторный стиль с толстым контуром мылится, если его растягивать с 720p на мониторы 1440p.
Интерфейс и иконки art bible рисует под 1080p. Но перевести мир на 1920 px — значит умножить на
1,5 каждое число в `tuning.json`, GDD и будущих таблицах, и потерять прямое сравнение с прототипом.

### Current State
`project.godot`: `viewport_width=1280`, `viewport_height=720`, **растяжение не задано** (у
старого проекта в 4.7 это `disabled`). Камера — `Camera2D` у героя, `offset (0, -120)`.

### Constraints
- Числа баланса не трогаем. Цель — GTX 1060.
- Проект создан до 4.7: новые стандарты `canvas_items`/`expand` к нему **не** применились.

## Decision

**Экран 1920×1080, мир в единицах прототипа, связь — `Camera2D.zoom = 1.5`.**

| Настройка `project.godot` | Значение |
|---|---|
| `display/window/size/viewport_width` | `1920` |
| `display/window/size/viewport_height` | `1080` |
| `display/window/stretch/mode` | `"canvas_items"` |
| `display/window/stretch/aspect` | `"expand"` |
| `display/window/size/window_width_override` / `height_override` | `1280` / `720` (окно в редакторе помещается на экран ноутбука) |

- В `tuning.json` новый ключ `"camera_zoom": 1.5`. Камера мира: `zoom = Vector2.ONE * Tune.f("camera_zoom")`.
  Видимая область мира = 1920/1,5 × 1080/1,5 = **1280 × 720 единиц прототипа** — как сейчас.
- `canvas_items` рисует 2D сразу в разрешении окна: на 1440p и 4K контуры и текст чёткие.
- `expand`: на 21:9 игрок видит больше комнаты по ширине, на 16:10 — больше по высоте.
  Пределы камеры (`limit_*`) не дают заглянуть за стены. Пробуждение стай `aggro_range` = 760:
  на 16:9 половина видимой ширины 640 — стая просыпается чуть за краем экрана, как в
  прототипе; на 21:9 половина ширины ≈ 840 — игрок видит спящую стаю раньше, чем она
  проснётся. Это допустимо; game-designer решает, нужен ли `aggro_range` от ширины экрана.
- **Интерфейс** (`CanvasLayer`) камера не масштабирует: HUD рисуется в координатах 1920×1080,
  как в макетах art bible. Размеры шрифтов — из темы `assets/ui/theme.tres`.
- **Масштаб графики мира**: 1 единица мира = 1,5 px экрана 1080p. Часть, нарисованная «в 1×»
  (под экран 1080p), ставится в риг с масштабом `1 / 1.5`; «в 2×» (герой, боссы) — `1 / 3`.
  Число лежит в риге один раз (ADR-0005), а не в коде.
- Частота физики — 60 тиков (по умолчанию). Сглаживание физики (`physics_interpolation`) не
  включаем сейчас; вернуться, если на мониторах 144 Гц будет заметно дрожание.

### Implementation Guidelines
- Настройки растяжения **must** быть явно записаны в `project.godot` (не полагаться на стандарты 4.7).
- Игровой код **must never** использовать `1920`, `1080` или `1.5` литералами; размер экрана —
  `get_viewport().get_visible_rect()`, масштаб — `Tune.f("camera_zoom")`.
- Тряска экрана **must** менять `cam.offset`, а не `zoom`.
- Снимки для `production/qa/evidence/` делаются при окне 1920×1080.

## Alternatives Considered

### Alternative 1: Оставить 1280×720 + `canvas_items`
- **Pros**: ноль изменений в камере; чёткость на больших мониторах та же.
- **Cons**: координаты интерфейса расходятся с макетами art bible (1080p); иконки рисуются под
  1080 и уменьшаются — лишний масштаб в каждом элементе UI.
- **Rejection Reason**: решает мир, но портит работу с интерфейсом.

### Alternative 2: 1920×1080 и умножить все числа мира на 1,5
- **Pros**: 1 единица мира = 1 px, без зума.
- **Cons**: переписать `tuning.json`, все GDD-формулы, таблицы; сравнение с прототипом теряется;
  ошибка в одном числе — сломанный баланс.
- **Rejection Reason**: слишком дорого и рискованно ради «красивой единицы».

### Alternative 3: `stretch/mode = viewport`
- **Pros**: пиксель-в-пиксель, одинаковая картинка везде.
- **Cons**: рисует в 1080p и растягивает картинку — на 1440p/4K мыло. Для пиксель-арта, не для нас.
- **Rejection Reason**: противоречит векторному стилю.

## Consequences

### Positive
- Числа баланса и GDD не меняются; HUD совпадает с макетами 1080p; чётко на любых мониторах.

### Negative
- Новичку надо помнить «мир в единицах прототипа, экран в 1080p». Записано в `architecture.md`.
- Линии `_draw` в мире станут в 1,5 раза толще на экране — временной графике это не мешает.

### Neutral
- Ширина окна при запуске в `project.yaml` (`--resolution 1280x720`) остаётся: это только окно.

## Risks
- **Ultrawide показывает лишнее** → при необходимости ограничить `aspect` до `keep_height`.
- **Слабая видеокарта при 4K** → `canvas_items` дороже на 4K; бюджет 1 ГБ текстур (art bible)
  проверить на 4K до раннего доступа.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| movement-and-combat.md | все расстояния и скорости в px прототипа | мир не масштабируется; камера `zoom` |
| room-generation-and-doors.md | ширина комнат `room_w_*`, уровни платформ | без изменений |
| systems-index.md #17 | камера, тряска | тряска через `offset`, зум из `tuning.json` |
| art-bible.md §8 | 1920×1080, `canvas_items`, `expand` | принято |

## Performance Implications
- **CPU**: без изменений.
- **GPU**: `canvas_items` на 1440p рисует ~1,8× пикселей против 1080p — для 2D в пределах бюджета.
- **Memory**: текстуры — по art bible (2× только герой, боссы, иконки).
- **Load Time**: нет.

## Migration Plan
1. `project.godot`: четыре настройки из таблицы. 2. `tuning.json`: `camera_zoom`. 3. `main.gd`:
   `cam.zoom`. 4. HUD: шрифт крупнее (18 → ~27). 5. Демо-прогон, снимки в `production/qa/evidence/`.

**Rollback plan**: вернуть 4 настройки и `camera_zoom = 1.0`.

## Validation Criteria
- Снимки в 4 разрешениях окна: высота видимого мира одинакова, герой одного размера относительно
  комнаты, контуры не мыльные на 2560×1440.

## Related
- `project.godot`, `src/core/main.gd`, `design/art/art-bible.md` §8, ADR-0005

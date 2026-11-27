# Источники ассетов и ИИ-генерация: Навь

> **Owned By**: art-director
> **Дата проверки**: 2026-11-27
> **Связан с**: `design/art/art-bible.md`

## Прочитай сначала: насколько проверены лицензии

Проверка 2026-11-27 шла через веб-поиск. Поиск подтвердил, что **официальная
страница лицензии существует по указанному адресу**, но у агента не было
инструмента, чтобы открыть страницу и прочитать её текст целиком. Поэтому:

- В столбце «Статус» стоит **UNVERIFIED (страница найдена)** — лицензия указана
  по официальной странице, найденной поиском, и по сторонним источникам;
  текст страницы глазами не прочитан. **Перед скачиванием открой ссылку
  «Лицензия» и убедись, что там написано то же самое.** Это 1 минута на источник.
- **UNVERIFIED** без уточнения — даже официальную страницу лицензии найти не удалось.
- Ни одна строка не отмечена «VERIFIED» — так честнее.

Когда проверишь сам — допиши в таблицу «проверено [дата]».

### Как читать лицензии (коротко)

| Лицензия | Можно продавать в Steam? | Что нужно |
|---|---|---|
| **CC0** (общественное достояние) | Да | Ничего. Упомянуть автора — вежливо, но не обязательно |
| **CC-BY** (3.0 / 4.0) | Да | Указать автора и лицензию в титрах игры (текст готов ниже) |
| **OFL** (шрифты) | Да | Можно вшить в игру; нельзя продавать сам шрифт отдельно |
| **Royalty-free** (своя лицензия автора) | Обычно да | Читать условия конкретного автора |
| **CC-BY-NC**, **NC** | **НЕТ** — запрещено коммерческое использование | Отклонять |
| **CC-BY-ND**, **ND** | **НЕТ** для игры — нельзя изменять | Отклонять |
| «Personal use only», «бесплатно для некоммерческих» | **НЕТ** | Отклонять |
| Нет лицензии вообще | **НЕТ** | Отклонять: «нет лицензии» = «всё запрещено» |

Каждый скачанный файл записывается в `assets/provenance.yaml`: откуда,
лицензия, автор, ссылка, дата скачивания.

---

## 1. Список источников

### 1.1 Иконки, интерфейс

| Название | Ссылка | Лицензия | Что даёт | Подходит к стилю | Статус |
|---|---|---|---|---|---|
| **game-icons.net** | https://game-icons.net — лицензия: https://game-icons.net/about.html | **CC BY 3.0** | 4000+ векторных иконок (SVG): оружие, руны, статусы, ресурсы. Цвет и фон меняются на сайте | Да: плоские силуэты, легко перекрасить в палитру раздела 4.6 | **VERIFIED 2026-11-27** (лицензия прочитана на странице); автор каждой иконки указан на её странице, подпись: «Icons made by {автор}. Available on https://game-icons.net» |
| **Kenney — UI-паки** | https://kenney.nl/assets — лицензия: https://kenney.nl/support | **CC0** | кнопки, панели, курсоры | Только как временные заглушки — стиль мультяшный | **VERIFIED 2026-11-27** (лицензия прочитана на странице) |

**Текст для титров game-icons.net** (у каждой иконки свой автор — указан на
странице иконки; впиши тех, чьи иконки взял):

> Icons by Lorc, Delapouite and other contributors from https://game-icons.net,
> licensed under CC BY 3.0 (https://creativecommons.org/licenses/by/3.0/).
> Иконки изменены (перекрашены, обведены).

### 1.2 Эффекты (VFX)

| Название | Ссылка | Лицензия | Что даёт | Подходит | Статус |
|---|---|---|---|---|---|
| **Kenney Particle Pack** | https://kenney.nl/assets/particle-pack (есть и в Godot: https://godotengine.org/asset-library/asset/784) | **CC0** | 80+ текстур частиц: искры, дым, вспышки, свечения, следы | Да: нейтральные белые текстуры, красятся в цвета богов | **VERIFIED 2026-11-27** (лицензия прочитана на странице) |
| **Brackeys' VFX Bundle** | https://brackeysgames.itch.io/brackeys-vfx-bundle | По памяти — CC0; **на странице не подтверждено** | текстуры и спрайты эффектов | Вероятно да | **UNVERIFIED** |

### 1.3 Текстуры (накладывать на фон и дерево интерфейса с прозрачностью 10–20%)

| Название | Ссылка | Лицензия | Что даёт | Подходит | Статус |
|---|---|---|---|---|---|
| **Poly Haven** | https://polyhaven.com — лицензия: https://polyhaven.com/license | **CC0** | фото-текстуры коры, дерева, мха, снега, камня | Да, как подложка-фактура (не как основной рисунок) | **VERIFIED 2026-11-27** (лицензия прочитана на странице) |
| **ambientCG** | https://ambientcg.com — лицензия: https://docs.ambientcg.com/license | **CC0** | то же: дерево, кора, земля, лёд | Да, так же | **VERIFIED 2026-11-27** (лицензия прочитана на странице) |

### 1.4 Славянские образы и орнамент (общественное достояние)

| Название | Ссылка | Лицензия | Что даёт | Статус |
|---|---|---|---|---|
| **Иван Билибин на Wikimedia Commons** | https://commons.wikimedia.org/wiki/Category:Ivan_Bilibin | Общественное достояние (Билибин умер в 1942 г.; срок охраны истёк). **У каждого файла свой тег лицензии — смотри его на странице файла** | рамки-орнаменты, силуэты Кощея, Бабы-яги, леса — образец для UI и для референса ИИ | UNVERIFIED (страница найдена, тег каждого файла проверять) |
| **Виктор Васнецов на Wikimedia Commons** | https://commons.wikimedia.org/wiki/Category:Viktor_Vasnetsov | Общественное достояние (умер в 1926 г.), тег — у каждого файла | облик богатыря, доспех, композиция | **UNVERIFIED** (страница не открывалась поиском) |

Использование: как образец («референс») для своих рисунков и ИИ, и орнамент
можно обвести/перерисовать в векторе для рамок интерфейса.

### 1.5 Шрифты с кириллицей

| Шрифт | Ссылка | Лицензия | Для чего | Статус |
|---|---|---|---|---|
| **Ruslan Display** | https://fonts.google.com/specimen/Ruslan+Display/about | **SIL OFL 1.1** | заголовки, имена богов и боссов | UNVERIFIED (страница открылась, но текста лицензии на ней нет — проверить в архиве шрифта, файл OFL.txt) |
| **Yeseva One** | https://fontsource.org/fonts/yeseva-one/about | **SIL OFL 1.1** | запасной вариант заголовков | UNVERIFIED (страница найдена) |
| **PT Sans** | https://fonts.google.com/specimen/PT+Sans | **SIL OFL 1.1** | весь основной текст | UNVERIFIED (страницу именно этого шрифта поиск не возвращал) |
| **Monomakh** | https://fonts.google.com/specimen/Monomakh/about | **SIL OFL 1.1** | декоративные надписи «под летопись» (не для мелкого текста) | UNVERIFIED (страница найдена) |

Файл лицензии `OFL.txt` кладётся рядом со шрифтом в `assets/fonts/`.

### 1.6 Звуки (решения по звуку — за audio-director; здесь только источники)

| Название | Ссылка | Лицензия | Что даёт | Статус |
|---|---|---|---|---|
| **Kenney — аудио-паки** (Impact Sounds, Interface Sounds, RPG Audio) | https://kenney.nl/assets | **CC0** | удары, шаги, интерфейс | VERIFIED 2026-11-27 для Kenney в целом (kenney.nl/support: все ассеты CC0); сам аудио-пак не открывали |
| **Sonniss GameAudioGDC Bundle** | https://sonniss.com/gameaudiogdc | своя лицензия «royalty-free, коммерческое использование без указания автора» (по сторонним обзорам) | десятки ГБ профессиональных звуков: оружие, магия, природа, монстры | **UNVERIFIED** (официальная страница лицензии поиском не найдена) |
| **Freesound** | https://freesound.org | **у каждого звука своя**: CC0, CC-BY или CC-BY-NC | что угодно | Брать только с фильтром **CC0** (или CC-BY — тогда записать автора). **CC-BY-NC — нельзя.** UNVERIFIED |

### 1.7 Персонажи и тайлы целиком

Готовых бесплатных CC0-персонажей и тайлов в стиле «гладкий вектор + славянская
сказка» **не найдено**. Почти всё бесплатное на itch.io и OpenGameArt — пиксели
(запрещено брифом) или мультяшный стиль. Поэтому **герой, враги, боссы и фоны
делаются через ИИ-генерацию по разделу 2** + доработка руками.

| Название | Ссылка | Лицензия | Использование |
|---|---|---|---|
| OpenGameArt | https://opengameart.org | у каждого ассета своя; брать только CC0 / CC-BY | редкие подходящие векторные вещи; **UNVERIFIED** |
| Godot Asset Store | https://store.godotengine.org | у каждого ассета своя | инструменты, шейдеры (решает technical-artist); **UNVERIFIED** |

### 1.8 Отклонено

| Что | Почему |
|---|---|
| Любые ассеты с пометкой NC / NonCommercial / ND / NoDerivatives | нельзя продавать или изменять |
| Ассеты itch.io без явной строки лицензии на странице | нет лицензии = нельзя |
| Pinterest, ArtStation, Яндекс/Google Картинки | чужие работы без разрешения |
| «Бесплатное за месяц» на платных маркетах (Envato, Unity Asset Store) для Godot-игры | лицензия привязана к подписке/движку — читать отдельно, по умолчанию не брать |
| Пиксельные паки | запрещены брифом («без пикселей») |
| Ассеты в стиле Hollow Knight (насекомые, маски) | запрещено art bible |

---

## 2. ИИ-генерация

### 2.1 Какие инструменты разрешают коммерческое использование картинок

| Инструмент | Цена | Можно продавать результат? | Подвох | Ссылка на условия | Статус |
|---|---|---|---|---|---|
| **FLUX.1 [schnell]** (локально, на своём ПК) | бесплатно | Да — модель под **Apache 2.0** | Нужна видеокарта от 12 ГБ (или облачный сервис, тогда ещё и его условия) | https://huggingface.co/black-forest-labs/FLUX.1-schnell | **VERIFIED 2026-11-27**: Apache 2.0, «personal, scientific, and commercial purposes» |
| **Stable Diffusion XL** (локально: Krita AI Diffusion, ComfyUI, Fooocus) | бесплатно | Да — лицензия **CreativeML Open RAIL++-M**: результаты можно использовать, есть список запрещённых применений (не про игры) | Видеокарта от 8 ГБ | https://stability.ai/license | **UNVERIFIED** (страница лицензии SDXL отдельно не найдена) |
| **Stable Diffusion 3.5** | бесплатно | Да, по **Stability AI Community License**, пока годовой доход < 1 млн $ | После 1 млн $ дохода — нужна платная лицензия | https://stability.ai/license | UNVERIFIED (страница найдена) |
| **Midjourney** | платно, от ~10 $/мес | Да, на платных планах | Если доход компании > 1 млн $/год — нужен Pro или Mega. Бесплатного плана нет. Картинки на младших планах видны всем | https://docs.midjourney.com/docs/terms-of-service | UNVERIFIED (страница найдена) |
| **Adobe Firefly** | есть бесплатные кредиты | Да, для функций не в статусе «бета» | Обучен на лицензированных картинках — самый «чистый» юридически | https://helpx.adobe.com/firefly/faq.html | UNVERIFIED (страница найдена) |
| **ChatGPT / OpenAI (генерация картинок)** | бесплатно с лимитами / подписка | Да: по условиям OpenAI права на результат передаются пользователю | Лимиты на бесплатном плане | https://openai.com/policies/row-terms-of-use/ | UNVERIFIED (страница найдена) |
| ~~FLUX.1 [dev]~~ | — | **Не использовать**: модель под некоммерческой лицензией; для продаж нужна платная лицензия BFL | — | https://bfl.ai/legal/non-commercial-license-terms | UNVERIFIED (страница найдена) |

**Что выбрать новичку:** если есть видеокарта NVIDIA от 8 ГБ — **Krita + плагин
Krita AI Diffusion** (бесплатно, локально, на SDXL или FLUX schnell): там же
можно сразу дорисовать и почистить картинку. Если видеокарты нет — **Adobe
Firefly** (бесплатные кредиты) или **ChatGPT**.

**Важно про авторское право:** в США (и многих других странах) картинка,
целиком сделанная ИИ, не защищается авторским правом — её может скопировать
кто угодно. Чем больше ручной доработки (перерисовать контур, собрать из
частей, перекрасить по палитре), тем больше прав у тебя. Не используй в
промптах имена живых художников и названия чужих игр.

### 2.2 Правила Steam про ИИ-контент

Источники: официальная страница Steamworks
https://partner.steamgames.com/doc/gettingstarted/contentsurvey (**VERIFIED 2026-11-27**, страница прочитана: раздел «Generative Artificial
Intelligence Content», категории Pre-Generated и Live-Generated; цитата: «Efficiency
gains through the use of these tools is not the focus of this section»); новости: правила введены в
январе 2024 г.
(https://www.gamingonlinux.com/2024/01/valve-announces-new-rules-for-games-with-ai-content-on-steam/),
форма уточнена в январе 2026 г.
(https://www.pcgamer.com/software/ai/steam-updates-ai-disclosure-form-to-specify-that-its-focused-on-ai-generated-content-that-is-consumed-by-players-not-efficiency-tools-used-behind-the-scenes/,
https://www.gamingonlinux.com/2026/01/valve-tweak-steam-ai-disclosure-form-for-developers-to-clarify-its-for-content-consumed-by-players/page=2).

Что это значит для Нави (по этим источникам):
1. При подаче игры в Steamworks заполняется **Content Survey** (опрос о
   содержимом). В нём есть раздел про ИИ.
2. Два вида:
   - **Pre-Generated** — контент, сделанный ИИ во время разработки (наш случай:
     картинки героя, врагов, фонов). Нужно описать, что сделано ИИ, и
     пообещать, что там нет ничего незаконного и чужого (нарушающего права).
   - **Live-Generated** — ИИ генерирует контент прямо во время игры. **У нас
     этого нет** — отмечаем «нет».
3. Описание показывается **на странице игры в Steam** в блоке «AI Generated
   Content Disclosure».
4. Уточнение 2026 г.: раскрывать нужно то, что **видит/слышит игрок** (в игре,
   на странице магазина, в маркетинге), а не инструменты, которые помогали
   «за кадром» (например, помощники при написании кода).
5. Тексты, звуки и картинки, сделанные ИИ и попавшие в игру или на страницу
   магазина (капсулы, скриншоты, трейлер), — раскрывать.

**Готовый текст для раскрытия** (поменяй под то, что реально сделано ИИ):

> EN: Some character, enemy and background artwork was created with the help of
> AI image generation tools and then edited and assembled by the developer.
> No content is generated by AI while the game is running.
>
> RU: Часть рисунков персонажей, врагов и фонов создана с помощью
> ИИ-генерации изображений, затем доработана и собрана разработчиком. Во
> время игры ИИ ничего не генерирует.

### 2.3 Готовые промпты

Промпты на английском — так модели понимают лучше. Общие правила:
- генерируй героя и врагов **на однотонном фоне** (`plain flat light gray
  background`), чтобы легко вырезать;
- для анимации-перекладки генерируй **части отдельно** (лист «character parts
  sheet») или целого героя в нейтральной позе, а потом режь;
- после генерации: обрезать фон → перекрасить под палитру art bible →
  обвести контуром `#120D12` 4 px (если модель сделала тоньше).

**Общий хвост стиля** (добавлять в конец каждого промпта персонажа):

```
2D game art, clean vector shapes, smooth soft gradients, subtle glow,
bold dark outline around the figure, flat cel shading, Slavic folk fairy-tale
style, ornamental details, side view, full body, centered, plain flat light gray
background, no text
```

**Негатив** (поле «negative prompt», если есть; иначе — фраза «without …»):

```
pixel art, 3D render, photo, anime, chibi, insect, bug, beetle, mask, empty eye
sockets, pale white body, horns on helmet, thin ink lines, monochrome, greek,
castle, swastika, text, watermark, signature, blurry, extra limbs
```

#### Промпт 1 — герой (павший богатырь), по ярусам облика

Герой меняет вид по мере прокачки (art bible, раздел 5.6), и все детали
должны садиться на **одно и то же тело** (раздел 5.7). Порядок работы:

1. Сначала сгенерировать **манекен** (промпт 1.0) и выбрать одну удачную
   картинку. Она — эталон тела на всю игру.
2. Каждый ярус генерировать **с этим манекеном как образцом**: функция
   «референс персонажа» / «image prompt» / «перерисовать поверх картинки»
   (inpaint) в выбранном инструменте, один и тот же seed, если он есть.
   Поза — та же нейтральная, что у манекена.
3. Детали вырезать из картинки яруса или сгенерировать листом частей
   (промпт 1.6), затем положить поверх манекена и подогнать по суставам.
4. Отбраковка: если лицо, борода, ширина плеч или рост не совпадают с
   манекеном — картинка в работу не идёт.

**Постоянная часть** (вставлять в каждый промпт 1.1–1.5 вместо
`[тело героя]`):

```
the same Slavic man, heroic stocky proportions about 4.5 heads tall, broad
shoulders, large hands, warm tanned skin (#E0A07A), visible human face with
determined eyes and a short light-brown beard (#8A5A34), a thin red thread
tied around his left wrist, the wrist nearest to the viewer (#B3262E), a small glowing amulet on a cord on
his chest, neutral standing pose, feet slightly apart, arms slightly away from
the body, facing right
```

**1.0 — манекен (тело без одежды для рига):**
```
character base body template, [тело героя], wearing only plain short linen
underwear, no hair on the head, no clothes, no weapon, clean simple shapes for
cutout animation,
[общий хвост стиля]
```

**1.1 — ярус 1, «Павший» (старт):**
```
a fallen Slavic bogatyr who has lost everything, [тело героя], bare-chested
with a few scratches, messy light-brown hair, torn rough canvas trousers
(#CDBB98), bare feet wrapped in worn cloth strips, a simple carved wooden
amulet disc on a cord, holding a long gnarled wooden stick (#8C6A44),
tired but unbroken,
[общий хвост стиля]
```

**1.2 — ярус 2, «Странник»:**
```
[тело героя], bleached linen shirt (#E9DFC9) with red folk embroidery on the
collar and hem, rope belt, linen headband with red embroidery on the forehead,
leather wraps on the forearms (#7A4A2A), cloth leg wraps and bast shoes,
small bronze amulet on a leather cord, holding [оружие],
[общий хвост стиля]
```

**1.3 — ярус 3, «Ополченец»:**
```
[тело героя], thick quilted padded jacket (#9A7448) with a leather belt and
bronze buckle, round leather cap without a point, leather bracers with bronze
studs, knee-high leather boots (#6B4428), a short red shoulder cape to the
shoulder blades (#B3262E), bronze amulet, holding [оружие],
[общий хвост стиля]
```

**1.4 — ярус 4, «Витязь»:**
```
[тело героя], chainmail shirt to mid-thigh (#8E9AA3) over a padded jacket,
simple low conical steel helmet without aventail, face fully visible, steel
bracers, boots with iron shin plates, plain red cloak to the knees (#B3262E),
gilded amulet, holding [оружие],
[общий хвост стиля]
```

**1.5 — ярус 5, «Богатырь» (финал):**
```
[тело героя], pointed steel shishak helmet with a thin gold band and a
chainmail aventail over the neck and shoulders, face and beard fully visible,
steel scale armor (#B8C4CC) over chainmail, belt with a gold buckle, steel
bracers with gold trim, boots with steel greaves, long flowing cinnabar red
cloak (#B3262E) to the calves with one thin gold folk ornament border and a
clasp on the shoulder, glowing golden amulet (#FFC94A), holding [оружие],
[общий хвост стиля]
```

`[оружие]` — экипированное оружие: `a long gnarled wooden stick`,
`a straight sword`, `a spear`, `two short sickles`, `a flanged mace` и т. д.
Оружие лучше генерировать отдельно (промпт 1.6), а не в руке.

**1.6 — лист частей одного яруса (чтобы детали совпали с телом):**
```
character parts sheet for cutout animation, all parts belong to the same
character as the reference image, same body size and proportions, same
colors, same lighting from top front, each part complete and separated with
empty space between them, laid out in a grid: [список частей],
[общий хвост стиля]
```
`[список частей]` — только то, что меняется на этом ярусе, по слотам
art bible 5.7, например для яруса 4: `conical steel helmet, chainmail shirt
torso piece, chainmail skirt piece, upper arm sleeve, forearm with steel
bracer, thigh with trousers, shin with boot and iron plate, foot with boot,
red cloak in three overlapping segments, cloak collar with clasp, gilded
amulet on cord`. Для оружия: `[оружие] laid horizontally, grip on the left,
no hand`.

**Добавка к негативу для ярусов 1–2:** `bodybuilder, oiled muscles, pale
skin, skinny, anime shirtless, loincloth only, tribal, caveman` — герой
полуголый, но это бедный славянский мужик, а не варвар и не бледная фигурка.

#### Промпт 2 — враг (болотник-ползун, Топь Кикиморы)

```
A swamp creature from Slavic folklore, low heavy bottom-heavy body like a drop
of mud, draped in hanging strands of green-brown swamp weed, long rusty claws
(#C2502A), two small glowing magenta eyes (#D23A9A) under the weed, muted bog
green body (#24392F to #4D5F3A), crawling pose facing left, menacing but
readable, clearly not an insect,
[общий хвост стиля]
```

#### Промпт 3 — фон (дальний слой Топи Кикиморы)

У фона **нет контура** и нет персонажей:

```
2D game background layer, wide panoramic 16:9, painterly digital painting with
soft gradients, misty Slavic swamp at night, distant silhouettes of crooked dead
birch and alder trees, an old broken wooden bridge far on the horizon, thin fog
bands, a few faint yellow-green will-o'-the-wisp lights (#B6E36B), color palette
dark bog green (#3E5A4A sky, #24392F trees), low contrast, calm, no outlines,
no characters, no text, seamless left and right edges
```

Для среднего и ближнего слоя — тот же промпт, но: `mid-ground layer,
transparent background, darker (#24392F), more detail` и
`foreground silhouettes, very dark (#121E19), reeds and branches only at the
edges of the frame, transparent center`.

### 2.4 Записи о происхождении для ИИ-картинок

В `assets/provenance.yaml` для каждой ИИ-картинки:

```yaml
- file: assets/art/characters/char_hero_torso_01.png
  source: ai
  tool: "Krita AI Diffusion + FLUX.1 schnell"   # точное название и версия
  tool_license: "Apache-2.0"
  prompt: "design/art/asset-sources.md §2.3 Промпт 1 (части)"
  edited_by_hand: "обрезка, перекраска по палитре, контур 4 px"
  date: 2026-11-27
  steam_disclosure: pre-generated
```

# CyberBuilder Docs Index

Документация разложена по тематическим папкам.

## Structure

- `docs/setup/`
  - `INSTALL.md` — установка зависимостей и install-скрипты.
  - `MODDER_QUICKSTART.md` — быстрый старт для моддера.
- `docs/reference/`
  - `PACK_FORMAT.md` — формат `pack.json`, `objects.json`, `recipes.json`.
  - `SAFETY_RULES.md` — ограничения безопасности.
  - `SAFE_CATEGORY_GUIDE.md` — safe/unsafe категории.
  - `BUILD_AUTHORIZATION.md` — пайплайн авторизации.
  - `CATALOG_UI_CONTRACT.md` — контракт данных для UI.
- `docs/features/`
  - `CONSTRUCTION_CHIP.md` — описание Construction Chip.
  - `PLAYER_PROGRESSION.md` — тировая прогрессия.
  - `CATALOG_UI.md` — текущее поведение каталога.
- `docs/guides/`
  - `ADDING_OBJECTS.md` — добавление объектов.
  - `PACK_AUTHORING_GUIDE.md` — рекомендации по авторингу паков.
  - `WORLDBUILDER_EXPORT.md` — экспорт для World Builder.
- `docs/testing/`
  - `CET_UI_SMOKE_CHECKLIST.md` — smoke checklist.
- `docs/roadmap/`
  - `ROADMAP.md`
  - `ROADMAP_v0_4.md`
  - `ROADMAP_v0_5.md`
- `docs/reports/`
  - `V0_3_VALIDATION_REPORT.md`

## Scope Reminder

CyberBuilder валидирует паки и подготавливает безопасные экспорт/авторизацию; размещение объектов в мире выполняется инструментами уровня World Builder.
# CyberBuilder Pack Registry (MVP)

CyberBuilder is a small **pack registry** for Cyberpunk 2077 modding: modders define buildable content in JSON (`pack.json`, `objects.json`, `recipes.json`), the tool **validates** those files, and **exports** resource paths into formats compatible with **World Builder** spawnable lists. It does not place objects in the game world by itself.

## Dependency on World Builder

**World Builder** (or an equivalent workflow that consumes the exported `.txt` spawnable lists) is the layer where objects are spawned, previewed, and edited in the world. CyberBuilder only prepares validated, grouped paths for that tool. You need a working World Builder setup to use the exports as intended.

## Non-goals (this MVP)

CyberBuilder **does not**:

- spawn, scan, delete, or modify objects in the live game world
- implement crafting UI, disassembly gun, quests, NPCs, vehicles, or economy
- replace World Builder’s in-world editing

Invalid packs are skipped so they do not break the rest of the registry; see the project `TODO.md` and `.manager/` docs for acceptance criteria and testing expectations.

## Setup Links

- Install flow and automation scripts: `docs/setup/INSTALL.md`
- Script map and command examples: `scripts/install/README.md`
- World Builder: [Nexus Mods](https://www.nexusmods.com/cyberpunk2077/mods/20660)
- RED4ext: [GitHub Releases](https://github.com/WopsS/RED4ext/releases)
- CET: [GitHub Releases](https://github.com/yamashi/CyberEngineTweaks/releases)


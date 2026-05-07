# CyberBuilder v0.2 — Builder Catalog UI TODO.md

## Full Implementation Mode

NO STUBS. NO FAKE SUCCESS. NO UNSAFE WORLD EDITING.

This version adds the first user-facing Builder Catalog UI and pack browsing layer.

Do not implement object placement, scanning, crafting, disassembly gun, deletion of original world objects, NPC spawning, vehicle spawning, or quest object manipulation.

## Goal

Create CyberBuilder v0.2: an in-game/dev catalog layer that reads validated CyberBuilder packs and lets users/modders browse buildable objects by category, search objects, inspect metadata, and export selected object paths for World Builder usage.

World Builder remains the actual spawning/editing layer.

## CursorAgentAI Execution Contract

Read this TODO.md first.

Execute only the first unchecked task.

Before coding, inspect existing files.

Do not expand scope.

Do not implement placement.

Do not implement scanning.

Do not implement economy gameplay.

Do not write outside allowed folders.

Each task must leave the project in a working state.

## Definition of Done

CyberBuilder v0.2 is done when:

- install scripts are moved to `scripts/install`;
- documentation references the correct scripts path;
- pack registry output can be consumed by catalog UI;
- catalog shows valid enabled objects;
- catalog supports category filtering;
- catalog supports text search;
- object detail panel shows metadata;
- user can copy/export selected `resourcePath`;
- invalid/disabled objects are hidden from normal catalog view;
- errors are logged clearly;
- no game-world objects are spawned or modified.

## What Changed

v0.1 created pack registry and World Builder export.

v0.2 adds the first catalog/browsing layer so CyberBuilder becomes useful for modders before full placement gameplay exists.

## Mini-Rules

World Builder owns spawning.

CyberBuilder owns pack metadata and UX.

Disabled objects are hidden by default.

Invalid packs never appear in catalog.

All UI actions must be safe.

No direct game-world modification in v0.2.

StoryPoints must be <=3.

---

[x] SP:1 Move install scripts from `docs/scripts/install` to `scripts/install` ---

[x] SP:1 Update `docs/INSTALL.md` to reference `scripts/install/check-deps.ps1` and `scripts/install/install-deps.ps1` ---

[x] SP:1 Add `scripts/install/README.md` explaining what each install script does and what it must not modify ---

[x] SP:2 Add dependency check output format: found, missing, versionUnknown, installPath ---

[x] SP:2 Add safe-mode rule to install scripts: never overwrite existing plugin folders without backup or confirmation flag ---

[x] SP:2 Add `.gitignore` entries for `dist/`, logs, temp exports, and local game path config ---

[x] SP:2 Create `src/cyber_builder/catalog_model.lua` for normalized catalog item DTO ---

[x] SP:2 Add catalog item fields: id, packId, name, type, category, tags, price, resourcePath, recipe, sourceFile ---

[x] SP:3 Implement `catalog_service.lua` to convert validated packs into catalog items ---

[x] SP:2 Hide `disabled: true` objects from normal catalog output ---

[x] SP:2 Add option `showDisabled` for debug catalog mode only ---

[x] SP:2 Implement category index: category -> list of catalog items ---

[x] SP:2 Implement tag index: tag -> list of catalog items ---

[x] SP:2 Implement search by name, id, tag, category, and resourcePath substring ---

[x] SP:2 Add deterministic sorting: category, name, id ---

[x] SP:2 Export catalog snapshot to `dist/cyberbuilder_catalog.json` ---

[x] SP:2 Add catalog summary to `dist/cyberbuilder_export_summary.json` ---

[x] SP:2 Add validation rule: catalog cannot contain duplicate global ids `packId:objectId` ---

[x] SP:2 Add validation rule: object price must be >= 0 ---

[x] SP:2 Add validation rule: tags must be array of lowercase strings ---

[x] SP:2 Add validation rule: category must be non-empty string ---

[x] SP:3 Create minimal CET overlay file `src/cyber_builder/ui/catalog_ui.lua` ---

[x] SP:3 Implement basic catalog window open/close toggle in CET UI ---

[x] SP:2 Add config key `uiEnabled` defaulting to false for safe dev mode ---

[x] SP:2 Add config key `catalogHotkey` with documented default ---

[x] SP:3 Render catalog categories list in UI ---

[x] SP:3 Render catalog object list for selected category ---

[x] SP:3 Render object detail panel with name, packId, type, price, tags, resourcePath ---

[x] SP:2 Add UI action: copy selected `resourcePath` to clipboard if CET API supports it, otherwise log path ---

[x] SP:2 Add UI action: export selected object to single-item World Builder txt under `dist/worldbuilder/selected/` ---

[x] SP:2 Add UI warning banner: “CyberBuilder v0.2 does not spawn objects; use World Builder for placement.” ---

[x] SP:2 Add UI empty states for no packs, no category, no search results ---

[x] SP:2 Add UI error panel reading latest validation errors ---

[x] SP:2 Add `docs/CATALOG_UI.md` explaining current catalog UI and limitations ---

[x] SP:2 Add `docs/ADDING_OBJECTS.md` with exact workflow for modders adding new objects to packs ---

[x] SP:2 Add `docs/WORLDBUILDER_EXPORT.md` explaining where generated `.txt` files go ---

[x] SP:2 Add test for catalog generation from valid starter pack ---

[x] SP:2 Add test for disabled object hidden from catalog ---

[x] SP:2 Add test for category index generation ---

[x] SP:2 Add test for search by name ---

[x] SP:2 Add test for search by tag ---

[x] SP:2 Add test for duplicate global catalog id rejection ---

[x] SP:2 Add test for negative price rejection ---

[x] SP:2 Add test for invalid tags rejection ---

[x] SP:2 Add test for deterministic `cyberbuilder_catalog.json` output ---

[x] SP:2 Add smoke test checklist for CET UI: open window, select category, select object, inspect metadata, export selected path ---

[x] SP:2 Update `.manager/ruls.md` with v0.2 rule: UI must not call spawn/place/delete APIs ---

[x] SP:2 Update `.manager/ci-gate.md` with catalog snapshot and UI smoke requirements ---

[x] SP:2 Update `.manager/dod.md` with v0.2 catalog acceptance criteria ---

[x] SP:2 Update `.manager/testing-ruls.md` with catalog service and UI smoke test cases ---

[x] SP:1 Update README with v0.2 usage flow ---

[x] SP:1 Run full validation and document result in `dist/cyberbuilder_export_summary.json` ---
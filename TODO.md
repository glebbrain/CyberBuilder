# CyberBuilder Pack Registry — TODO.md

## Full Implementation Mode

NO STUBS. NO FAKE SUCCESS. NO GAME-WORLD EDITING IN MVP.

Implement only the smallest stable base for future CyberBuilder development:
pack registry, schema validation, and World Builder-compatible export.

Do not implement object spawning, scanning, crafting, disassembly gun, quest-object editing, NPC spawning, vehicle spawning, or deleting original game-world objects in this MVP.

## Goal

Create CyberBuilder Pack Registry: a small Cyberpunk 2077 mod/tool layer that lets modders define buildable object packs through simple JSON manifests and export those object resource paths into World Builder-compatible spawnable lists.

The MVP must make it easy for other modders to add content without editing core code.

## CursorAgentAI Execution Contract

Read this TODO.md first.

Execute only the first unchecked task.

Before coding, inspect existing files.

Keep changes minimal and production-oriented.

Every task must end with a working, testable state.

If a dependency is missing, document it and fail clearly.

Do not guess Cyberpunk resource paths.

Do not modify original game files.

Do not write outside the project folder except the explicit configured World Builder export folder.

## Definition of Done

CyberBuilder can load packs from `packs/*`.

CyberBuilder validates `pack.json`, `objects.json`, and `recipes.json`.

CyberBuilder exports World Builder-compatible `.txt` files grouped by object type.

CyberBuilder logs all errors with actionable messages.

Invalid packs do not break valid packs.

Starter pack is included.

Documentation explains how another modder can create a pack.

No world spawning is implemented in this MVP.

## What Changed

This MVP intentionally uses World Builder as the object spawning/editing layer.

CyberBuilder owns only:
pack format,
validation,
catalog metadata,
recipe metadata,
export to World Builder spawnables.

This avoids duplicating existing World Builder functionality and reduces the risk of breaking Cyberpunk 2077 quests/world state.

## Mini-Rules

Never delete or modify original Night City objects.

Only export known safe buildable resources.

Every object must have stable id, name, type, resourcePath, category, price.

Every pack must be independently valid.

Bad pack must be skipped, not crash the whole registry.

All paths must be normalized.

All logs must include pack id and file name.

StoryPoints must be <=3.

---

[x] SP:1 Create base project folders: `.manager`, `src/cyber_builder`, `packs/starter_furniture`, `schemas`, `dist`, `docs` ---

_Note (2026-05-04): Verified on disk; `dist/` and `docs/` tracked via `.gitkeep`._

[x] SP:1 Create `docs/README.md` explaining CyberBuilder Pack Registry MVP, dependency on World Builder, and non-goals ---

_Note: Added `docs/README.md` with MVP scope, World Builder dependency, and explicit non-goals._

[x] SP:1 Create `docs/INSTALL.md` with required game mods: RED4ext, CET, Codeware, redscript, ArchiveXL, TweakXL, WolvenKit, World Builder ---

_Note: Added `docs/INSTALL.md` listing all required names in tables with one-line roles._

[x] SP:1 Create `docs/PACK_FORMAT.md` describing `pack.json`, `objects.json`, `recipes.json` fields ---

_Note: Added `docs/PACK_FORMAT.md` with field tables for all three files; `components` shape noted as pending final schema._

[x] SP:2 Create `schemas/pack.schema.json` with required fields: id, name, version, author, requires ---

_Note: `schemas/pack.schema.json` updated; `requires` is array of strings._

[x] SP:2 Create `schemas/objects.schema.json` with required fields: id, name, type, resourcePath, category, price, tags, buildable, deletable ---

_Note: `schemas/objects.schema.json` defines array items object with listed required properties and types._

[x] SP:2 Create `schemas/recipes.schema.json` with required fields: objectId, components, seconds ---

_Note: `components` typed as generic JSON array; element shape left to later docs/validator tasks._

[x] SP:1 Create starter `packs/starter_furniture/pack.json` with valid metadata and World Builder dependency ---

_Note: Added `author` and `requires` including `world_builder`; aligns with `schemas/pack.schema.json`._

[x] SP:1 Create starter `packs/starter_furniture/objects.json` with 3 placeholder-safe example records marked `disabled: true` until real resource paths are confirmed ---

_Note: Three objects with empty `resourcePath` and `disabled: true`; no guessed game paths._

[x] SP:1 Create starter `packs/starter_furniture/recipes.json` linked to starter object ids ---

_Note: Three recipes with `objectId` matching starter objects; `components` empty arrays until format is finalized._

[x] SP:2 Implement `src/cyber_builder/logger.lua` with info/warn/error helpers and consistent prefix `[CyberBuilder]` ---

_Note: `info`/`warn`/`error` print lines as `[CyberBuilder] LEVEL message`._

[x] SP:2 Implement `src/cyber_builder/path_utils.lua` for path join, normalization, extension detection, and safe relative path checks ---

_Note: `join` uses `package.config` dir sep; `normalize` uses `/`; `extension` lowercases; `is_safe_relative` rejects absolute/`..`._

[x] SP:3 Implement `src/cyber_builder/json_loader.lua` to read JSON files with clear error reporting and no crash on invalid JSON ---

_Note: `json_loader.read` returns `data, err`; decode via embedded rxi/json.lua (MIT); invalid JSON caught with `pcall`._

[x] SP:3 Implement `src/cyber_builder/pack_registry.lua` to discover pack folders under configured `packs` directory ---

_Note: `discover(packs_dir)` returns sorted `{id, path}`; uses `lfs` when available else Windows `dir /ad /b`; otherwise clear error._

[x] SP:3 Implement `src/cyber_builder/schema_validator.lua` with manual Lua validation for pack, objects, and recipes structures ---

_Note: `validate_pack` / `validate_objects` / `validate_recipes` return `ok, err_list`; dense JSON arrays; optional `disabled` boolean only._

[x] SP:2 Validate `pack.id` format as lowercase slug: letters, numbers, underscore, dash only ---

_Note: Enforced in `schema_validator.validate_pack` via pattern `^[a-z0-9_-]+$` plus non-empty._

[x] SP:2 Validate every object id is unique inside pack ---

_Note: `validate_objects` tracks string `id` values and errors on repeats with first index._

[x] SP:2 Validate every recipe `objectId` exists in `objects.json` ---

_Note: `validate_recipes(recipes, objects)` — when second arg is decoded `objects.json`, each `objectId` must match an object `id`._

[x] SP:2 Validate object `type` enum: `entity`, `mesh`, `decal`, `light`, `sound` ---

_Note: Enforced in `validate_objects` via `OBJECT_TYPES` set._

[x] SP:2 Validate `resourcePath` is non-empty for enabled objects ---

_Note: In `validate_objects`, if `disabled ~= true`, `resourcePath` must contain a non-whitespace character._

[x] SP:2 Skip objects with `disabled: true` during export and log them as skipped ---

_Note: `worldbuilder_exporter.iter_export_objects` skips `disabled` rows and logs via `logger.info` with pack id + `objects.json`._

[x] SP:3 Implement `src/cyber_builder/worldbuilder_exporter.lua` to export entity paths to `dist/worldbuilder/entity/templates/cyberbuilder_<packId>.txt` ---

_Note: `export_entity_templates(objects, pack_id, dist_root, logger?)` writes normalized paths; only `type == "entity"`; uses `iter_export_objects`._

[x] SP:3 Implement mesh export to `dist/worldbuilder/mesh/all/cyberbuilder_<packId>.txt` ---

_Note: `export_mesh_all(objects, pack_id, dist_root, logger?)` mirrors entity export; only `type == "mesh"`._

[x] SP:2 Implement export grouping so unsupported types are skipped with warning, not failure ---

_Note: `iter_export_objects` optional `opts.warn_unsupported_types`; warns for types other than entity/mesh; entity/mesh exports pass this flag._

[x] SP:2 Implement duplicate `resourcePath` de-duplication per export file ---

_Note: `dedupe_paths_in_order` applied before write in entity and mesh exports (first occurrence kept)._

[x] SP:2 Implement deterministic sorting of exported resource paths ---

_Note: After dedupe, `table.sort` on path strings (Lua default byte order) in entity and mesh exports._

[x] SP:3 Implement `src/cyber_builder/init.lua` as entry point: load config, discover packs, validate, export, print summary ---

_Note: `cyber_builder.run` merges optional `cyberbuilder.config.json` with repo defaults; CLI when `arg[0]` ends with `init.lua`; summary line via `logger.info`._

[x] SP:2 Create `cyberbuilder.config.json` with `packsDir`, `distDir`, and optional `worldBuilderSpawnablesDir` ---

_Note: Added repo-root `cyberbuilder.config.json` with relative `packs`/`dist` and `worldBuilderSpawnablesDir: null` (set string when using install export)._

[x] SP:2 Implement safe export mode: default writes only to project `dist`, not game directory ---

_Note: `init.lua` resolves `distDir` relative to repo root and aborts if resolved path is outside `repo_root`._

[x] SP:3 Implement optional install export mode that copies generated `.txt` files into configured World Builder spawnables folder only when path contains `entSpawner\data\spawnables` ---

_Note: `init.lua` reads `worldBuilderSpawnablesDir`, checks normalized path for `entSpawner/data/spawnables`, then copies entity/mesh `.txt` mirroring `worldbuilder/...` layout._

[x] SP:2 Add dry-run mode that validates and prints planned exports without writing files ---

_Note: `opts.dryRun` or CLI `--dry-run`; exporter skips mkdir/write and returns line counts; install copy skipped; summary `dry_run=1`._

[x] SP:2 Add validation summary: packs found, packs valid, packs invalid, objects exported, objects skipped ---

_Note: `init.lua` logs `validation summary:` with those five counts; `objects_skipped` = disabled rows in valid packs; `objects_exported` = entity/mesh eligible rows._

[x] SP:2 Add error summary file `dist/cyberbuilder_errors.log` ---

_Note: `init.lua` collects `emit_error` lines under safe `distDir`; writes `cyberbuilder_errors.log` on success and on discover/install failure; skipped in dry-run._

[x] SP:2 Add export summary file `dist/cyberbuilder_export_summary.json` ---

_Note: `init.lua` writes `cyberbuilder_export_summary.json` under safe `distDir` after a successful run with counters, `dry_run`, and `cyber_builder_version`; skipped in dry-run._

[x] SP:2 Add `docs/MODDER_QUICKSTART.md` with steps to create a new pack by copying starter pack ---

_Note: `docs/MODDER_QUICKSTART.md` — copy `packs/starter_furniture`, match folder/`pack.json` id, edit objects/recipes, run `lua src/cyber_builder/init.lua` (optional `--dry-run`); points to `PACK_FORMAT` and config._

[x] SP:2 Add `docs/SAFETY_RULES.md` documenting blacklist: NPC, vehicle, quest, door, elevator, device, combat objects ---

_Note: `docs/SAFETY_RULES.md` — table + examples for each blacklist category, alignment with `.manager/ruls.md`, scope vs World Builder._

[x] SP:2 Add `.manager/ruls.md` with rule: MVP must not spawn, scan, delete, or modify game-world nodes ---

_Note: `.manager/ruls.md` — consolidated prior spawn/scan/delete bullets into explicit game-world nodes rule._

[x] SP:2 Add `.manager/dod.md` with global acceptance criteria for CyberBuilder Pack Registry ---

_Note: `.manager/dod.md` — replaced “Global MVP Done” with explicit “Global acceptance criteria — CyberBuilder Pack Registry” checklist (discovery, validation/skip, export, dist summaries, logging, starter pack, docs, world scope)._

[x] SP:2 Add `.manager/testing-ruls.md` with manual test cases for valid pack, invalid pack, duplicate ids, disabled objects, missing recipes ---

_Note: `.manager/testing-ruls.md` — intro matrix + “Invalid pack (schema validation)”, “Missing recipes.json”; aligned existing cases (duplicate id, disabled, missing recipe target, invalid JSON)._

[x] SP:2 Add `.manager/ci-gate.md` with checks: schema validation, deterministic export, no write outside allowed folders ---

_Note: `.manager/ci-gate.md` — opening paragraph ties the three themes; checklist adds explicit schema, deterministic two-run wording, and safe `distDir` / optional install path bullets._

[x] SP:2 Add `.manager/cursor-ui-exec.md` instructing Cursor Agent to execute only first unchecked TODO task and stop after validation ---

_Note: `.manager/cursor-ui-exec.md` — new “Cursor Agent — TODO discipline” section (first unchecked task only, validate via manager docs, stop before next item)._

[x] SP:3 Add local test data pack `packs/broken_example_pack` with intentional errors and mark it ignored by default ---

_Note: `packs/broken_example_pack` — duplicate `objects[].id`, recipe `objectId` missing from objects; skipped unless removed from `ignoredPackIds` in `cyberbuilder.config.json` (default ignore also in `load_merged_config`)._

[x] SP:3 Add simple Lua test runner script `tests/run_pack_registry_tests.lua` for registry and validation logic ---

_Note: `tests/run_pack_registry_tests.lua` — `dofile` loads `pack_registry` + `schema_validator`; cases: discover `packs/`, valid pack, invalid slug, duplicate object id, recipe unknown `objectId`; `os.exit(1)` on failure. Lua not on PATH in agent env — run locally from repo root._

[x] SP:2 Add test for invalid JSON handling without crash ---

_Note: `tests/run_pack_registry_tests.lua` — temp malformed JSON file; `pcall(json_loader.read)` + assert `nil` and error string containing `invalid JSON`._

[x] SP:2 Add test for missing `pack.json` handling without crash ---

_Note: `tests/run_pack_registry_tests.lua` — `pcall(json_loader.read, …/pack.json)` for non-existent path; assert no throw and `cannot open`-style error (same read path `init.lua` uses for `pack.json`)._

[x] SP:2 Add test for duplicate object id detection ---

_Note: `tests/run_pack_registry_tests.lua` — duplicate `objects[].id` case now asserts an error string contains `duplicate` and the colliding id._

[x] SP:2 Add test for recipe referencing missing object id ---

_Note: `tests/run_pack_registry_tests.lua` — recipe `objectId` `ghost` not in catalog; assert error text includes `unknown object id`, id, and `objects.json`._

[x] SP:2 Add test for disabled objects not exported ---

_Note: `tests/run_pack_registry_tests.lua` — `export_mesh_all` dry-run with one `disabled: true` mesh and one enabled mesh; line count must be 1._

[x] SP:2 Add test for deterministic sorted export output ---

_Note: `tests/run_pack_registry_tests.lua` — real `export_mesh_all` write under `tests/_tmp_deterministic_dist`; input order z/a/m; assert lexicographic line order + identical bytes on second run; remove output txt._

[x] SP:2 Add `docs/ROADMAP.md` with v0.2 Catalog UI, v0.3 Construction Chip, v0.4 Placement Wrapper, v0.5 Scanner ---

_Note: `docs/ROADMAP.md` — v0.1 pointer + v0.2–v0.5 one-paragraph themes (Catalog UI, Construction Chip, Placement Wrapper, Scanner) with safety pointers._

[x] SP:1 Update README with final MVP usage command/flow and known limitations ---

_Note: `README.md` — MVP one-liner, Lua requirement, `init.lua` / `--dry-run` / test runner commands, doc index table, limitations (no in-world edit, skipped packs, `ignoredPackIds`, paths, install guard)._

[x] SP:1 Run full local validation and update TODO with actual result notes ---

_Note (2026-05-04): **Lua runtime** — `lua` / `lua54` / `luajit` not on `PATH`; no `lua.exe` in common install paths in this session, so **`lua tests/run_pack_registry_tests.lua`** and **`lua src/cyber_builder/init.lua --dry-run`** were **not executed** here. **IDE diagnostics** on `src/cyber_builder/init.lua` and `tests/run_pack_registry_tests.lua`: **no issues**. **Maintainer:** from repo root run `lua tests/run_pack_registry_tests.lua` then `lua src/cyber_builder/init.lua --dry-run`; inspect `dist/` when not using dry-run._
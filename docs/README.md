# CyberBuilder Docs Index

Documentation is organized by topic. Below is the table of contents and a short project overview.

## Structure

### `docs/` (root) — Placement Wrapper v0.4 and bridges

- `PLACEMENT_WRAPPER.md` — placement wrapper architecture and provider model.
- `PLACEMENT_SAFETY.md` — safety guarantees and restrictions.
- `PLACEMENT_LIFECYCLE.md` — request states and transitions.
- `PLACEMENT_PROVIDER_API.md` — provider contract.
- `OWNERSHIP_RULES.md` — ownership and safe metadata-only removal.
- `SAFE_PLACEMENT_GUIDE.md` — authoring safe placement requests.
- `WORLDBUILDER_BRIDGE.md` — World Builder hand-off and export queue.
- `ROADMAP_v0_6.md` — Workshop/Crafting roadmap (planned).

### `docs/setup/`

- `INSTALL.md` — dependencies and install scripts.
- `MODDER_QUICKSTART.md` — quick start for pack authors.

### `docs/reference/`

- `PACK_FORMAT.md` — `pack.json`, `objects.json`, `recipes.json` format.
- `SAFETY_RULES.md` — MVP safety restrictions.
- `SAFE_CATEGORY_GUIDE.md` — safe/unsafe categories (Construction Chip).
- `BUILD_AUTHORIZATION.md` — authorization pipeline.
- `CATALOG_UI_CONTRACT.md` — UI data contract.

### `docs/features/`

- `CONSTRUCTION_CHIP.md` — Construction Chip v0.3.
- `PLAYER_PROGRESSION.md` — tier progression.
- `CATALOG_UI.md` — catalog UI behavior (v0.2).

### `docs/guides/`

- `ADDING_OBJECTS.md` — adding objects to packs.
- `PACK_AUTHORING_GUIDE.md` — pack authoring recommendations.
- `WORLDBUILDER_EXPORT.md` — World Builder export layout.

### `docs/testing/`

- `CET_UI_SMOKE_CHECKLIST.md` — CET UI smoke checklist.

### `docs/roadmap/`

- `ROADMAP.md` — version roadmap (high level).
- `ROADMAP_v0_4.md` — Placement Wrapper: plan, **actual v0.4 validation snapshot**, limits, risks.
- `ROADMAP_v0_5.md` — Scanner Blueprint Integration (planned).

### `docs/reports/`

- `V0_3_VALIDATION_REPORT.md` — historical v0.3 validation report.

## CyberBuilder Pack Registry (overview)

CyberBuilder is a **pack registry** for Cyberpunk 2077 modding: authors describe content in JSON (`pack.json`, `objects.json`, `recipes.json`), the tool **validates** those files and **exports** resource paths into formats compatible with **World Builder** spawnable lists. It does **not** place objects in the game world by itself.

### World Builder dependency

**World Builder** (or any pipeline that consumes the exported `.txt` lists) is where objects appear in-world, are previewed, and edited. CyberBuilder prepares validated, grouped paths for that layer.

### Non-goals (MVP / core)

CyberBuilder does **not**:

- spawn, scan, delete, or modify objects in the live game world;
- implement crafting UI, disassembly gun, quests, NPCs, vehicles, or economy;
- replace full in-world editing in World Builder.

Invalid packs are skipped so the rest of the registry keeps working; acceptance criteria and tests live in `TODO.md` and `.manager/`.

### Build and tests (quick reference)

From the repository root (Windows, PowerShell):

```powershell
.\scripts\build\clean.ps1
.\scripts\build\build.ps1
```

Lua tests: `lua tests/run_pack_registry_tests.lua` (see current status in `docs/roadmap/ROADMAP_v0_4.md`).

## Links

- Setup: `docs/setup/INSTALL.md`
- Scripts: `scripts/install/README.md`
- World Builder: [Nexus Mods](https://www.nexusmods.com/cyberpunk2077/mods/20660)
- RED4ext: [GitHub Releases](https://github.com/WopsS/RED4ext/releases)
- CET: [GitHub Releases](https://github.com/yamashi/CyberEngineTweaks/releases)

---

Last reviewed: 2026-05-07.

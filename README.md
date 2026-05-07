# CyberBuilder (v0.4 Placement Wrapper)

CyberBuilder validates **JSON packs** under `packs/*`, builds a **catalog snapshot** for safe browsing, runs **Construction Chip** authorization flows, and (v0.4) provides a **Placement Wrapper** that validates, tracks ownership, and hands off safe placement intents to **World Builder** (or compatible providers) via exports under `dist/`. It does **not** spawn, scan, or edit objects in the Cyberpunk 2077 world by itself; use **World Builder** (or another consumer of the `.txt` / placement queue outputs) for in-world placement.

## What each version added (on top of the base)

| Version | Added on top of the previous base |
|---------|-----------------------------------|
| **v0.1** | Pack Registry MVP: load packs from `packs/*`, validate `pack.json` / `objects.json` / `recipes.json`, export World Builder path lists, logging, starter pack; invalid packs are skipped without taking down the whole registry. |
| **v0.2** | Catalog UI (CET): browse by category, search, metadata panel, copy/export selected `resourcePath` to `dist/worldbuilder/selected/`, snapshot `dist/cyberbuilder_catalog.json`, install scripts under `scripts/install`. UI is still **browse + path export only**—no spawn from core. |
| **v0.3** | **Construction Chip**: gameplay authorization layer—unlocks, tiers/progression, filtering unsafe categories/tags, safe catalog projection for UI, save/load of unlock state. Direct world placement is still not in core. |
| **v0.4** (current) | **Placement Wrapper**: schemas and Lua modules for request validation, transform normalization, sessions, provider registry, export queue (`dist/placement_queue/`), audit/error/blocked reports, ownership registry (`dist/player_placements.json`), metadata-only safe removal, World Builder hand-off adapter. Actual spawning is done by the export consumer. |

Archived task lists for completed waves: `.manager/.history/TODO-v0.1-06-05-2026.md`, `.manager/.history/TODO-v0.2.md`, `.manager/.history/TODO-v0.3-06-05-2026.md`. The active backlog and acceptance criteria live in the repo root **`TODO.md`**. Directions after v0.4: `docs/roadmap/ROADMAP.md`, `docs/roadmap/ROADMAP_v0_5.md`, `docs/ROADMAP_v0_6.md`.

## Requirements

- **Lua** on your `PATH` (plain Lua 5.x; `lfs` recommended).
- Packs as folders: `pack.json`, `objects.json`, `recipes.json` (see `docs/reference/PACK_FORMAT.md`).

For OS-specific setup and scripted install flow, use `docs/setup/INSTALL.md` and the orchestrators under `scripts/install/`.
Install scripts support backup-first flow and best-effort CET/Lua dependency setup.

## Usage (repo root)

Full validation and export (writes under configured `distDir`, respects `ignoredPackIds`):

```text
lua src/cyber_builder/init.lua
```

Validate and log only (**no** `dist` files, **no** optional install copy):

```text
lua src/cyber_builder/init.lua --dry-run
```

Override logging at runtime (examples):

```text
lua src/cyber_builder/init.lua --log-level=DEBUG --log-targets=console,files --log-file=cyberbuilder.debug.log
```

Configuration is read from **`cyberbuilder.config.json`** (optional keys include `packsDir`, `distDir`, `worldBuilderSpawnablesDir`, `ignoredPackIds`, `logging`). The `logging` block supports `level`, `targets`, `mainFileName`, `errorFileName`, and `externalEnabled`. Defaults keep exports under the repository and skip the broken example pack by id.

Automated checks for registry, validation, export helpers, Construction Chip, and Placement Wrapper units:

```text
lua tests/run_pack_registry_tests.lua
```

## Typical flow (v0.4)

1. Add or edit packs under `packs/<pack_id>/` (`pack.json`, `objects.json`, `recipes.json`).
2. Run build pipeline from repo root (PowerShell):
   - `scripts/build/clean.ps1`
   - `scripts/build/build.ps1`
3. Verify generated outputs:
   - `dist/cyberbuilder_catalog.json`
   - `dist/cyberbuilder_export_summary.json`
   - `dist/cyberbuilder_errors.log`
   - World Builder exports under `dist/worldbuilder/`
   - Placement-related artifacts as implemented (see `docs/PLACEMENT_WRAPPER.md`, `docs/WORLDBUILDER_BRIDGE.md`)
4. Open CET catalog UI and browse (category, metadata, copy/export `resourcePath` — see `docs/features/CATALOG_UI.md`).
5. Use exported `.txt` files and placement queue payloads in World Builder (or your integration) for actual spawning/placement.

## Documentation

| Doc | Purpose |
|-----|---------|
| `docs/README.md` | Index: MVP scope, Placement docs, roadmap links |
| `docs/setup/MODDER_QUICKSTART.md` | Create a pack from `packs/starter_furniture` |
| `docs/reference/PACK_FORMAT.md` | JSON field reference |
| `docs/reference/SAFETY_RULES.md` | MVP blacklist (NPC, vehicles, quests, etc.) |
| `docs/setup/INSTALL.md` | Full install flow (Windows/macOS), script map, and command examples |
| `docs/roadmap/ROADMAP.md` | Post-MVP direction (high level) |
| `docs/roadmap/ROADMAP_v0_4.md` | v0.4 placement: plan, validation snapshot, limits, risks |
| `docs/PLACEMENT_WRAPPER.md` | Placement Wrapper architecture and provider model |

## Official Mod Stack Links

- `RED4ext`: [GitHub Releases](https://github.com/WopsS/RED4ext/releases)
- `CET`: [GitHub Releases](https://github.com/yamashi/CyberEngineTweaks/releases)
- `Codeware`: [GitHub Releases](https://github.com/psiberx/cp2077-codeware/releases)
- `redscript`: [GitHub Releases](https://github.com/jac3km4/redscript/releases)
- `ArchiveXL`: [GitHub Releases](https://github.com/psiberx/cp2077-archive-xl/releases)
- `TweakXL`: [GitHub Releases](https://github.com/psiberx/cp2077-tweak-xl/releases)
- `World Builder`: [Nexus Mods](https://www.nexusmods.com/cyberpunk2077/mods/20660)
- `WolvenKit`: [GitHub Releases](https://github.com/WolvenKit/WolvenKit/releases)

## Known limitations (v0.4)

- **No direct in-world spawn from CyberBuilder core**; catalog UI remains path export / browse-oriented; Placement Wrapper prepares validated payloads and metadata for external tools.
- **Invalid packs are skipped** with errors logged; they do not stop other packs from exporting.
- **`ignoredPackIds`** in config excludes pack folders from processing (the repo ships `broken_example_pack` as intentionally broken test data—remove its id from the list only when you want to exercise failures).
- **Resource paths** are not verified against the real game; you must supply correct `resourcePath` values yourself (`docs/reference/SAFETY_RULES.md`, `.manager/ruls.md`).
- **Optional install copy** to a World Builder spawnables directory only runs when `worldBuilderSpawnablesDir` points at a path that contains `entSpawner/data/spawnables` (after normalization).
- **External logging target** is adapter-based: set `logging.externalEnabled=true` and pass a handler from integration code; no hard dependency on a specific vendor is included.
- **Automated test suite**: see current status in `docs/roadmap/ROADMAP_v0_4.md` (including known failing placement-removal tests when Lua loads duplicate module instances—`docs/PLACEMENT_WRAPPER.md`).

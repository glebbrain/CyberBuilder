# CyberBuilder (Pack Registry MVP)

CyberBuilder validates **JSON packs** under `packs/*` and exports **World Builder–compatible** path lists into the project `dist/` tree. It does **not** spawn, scan, or edit objects in the Cyberpunk 2077 world; use **World Builder** (or another consumer of the `.txt` exports) for in-world work.

## Requirements

- **Lua** on your `PATH` (plain Lua 5.x; `lfs` recommended).
- Packs as folders: `pack.json`, `objects.json`, `recipes.json` (see `docs/PACK_FORMAT.md`).

For OS-specific setup and scripted install flow, use `docs/INSTALL.md` and the orchestrators under `scripts/install/`.
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

Automated checks for registry, validation, and export helpers:

```text
lua tests/run_pack_registry_tests.lua
```

## Documentation

| Doc | Purpose |
|-----|---------|
| `docs/README.md` | MVP scope, World Builder dependency, non-goals |
| `docs/MODDER_QUICKSTART.md` | Create a pack from `packs/starter_furniture` |
| `docs/PACK_FORMAT.md` | JSON field reference |
| `docs/SAFETY_RULES.md` | MVP blacklist (NPC, vehicles, quests, etc.) |
| `docs/INSTALL.md` | Full install flow (Windows/macOS), script map, and command examples |
| `docs/ROADMAP.md` | Post-MVP direction (high level) |

## Official Mod Stack Links

- `RED4ext`: [GitHub Releases](https://github.com/WopsS/RED4ext/releases)
- `CET`: [GitHub Releases](https://github.com/yamashi/CyberEngineTweaks/releases)
- `Codeware`: [GitHub Releases](https://github.com/psiberx/cp2077-codeware/releases)
- `redscript`: [GitHub Releases](https://github.com/jac3km4/redscript/releases)
- `ArchiveXL`: [GitHub Releases](https://github.com/psiberx/cp2077-archive-xl/releases)
- `TweakXL`: [GitHub Releases](https://github.com/psiberx/cp2077-tweak-xl/releases)
- `World Builder`: [Nexus Mods](https://www.nexusmods.com/cyberpunk2077/mods/20660)
- `WolvenKit`: [GitHub Releases](https://github.com/WolvenKit/WolvenKit/releases)

## Known limitations (MVP)

- **No in-game catalog or placement** from this repo alone; exports target World Builder–style layouts under `dist/`.
- **Invalid packs are skipped** with errors logged; they do not stop other packs from exporting.
- **`ignoredPackIds`** in config excludes pack folders from processing (the repo ships `broken_example_pack` as intentionally broken test data—remove its id from the list only when you want to exercise failures).
- **Resource paths** are not verified against the real game; you must supply correct `resourcePath` values yourself (`docs/SAFETY_RULES.md`, `.manager/ruls.md`).
- **Optional install copy** to a World Builder spawnables directory only runs when `worldBuilderSpawnablesDir` points at a path that contains `entSpawner/data/spawnables` (after normalization).
- **External logging target** is adapter-based in MVP: set `logging.externalEnabled=true` and pass a handler from integration code; no hard dependency on a specific vendor is included.

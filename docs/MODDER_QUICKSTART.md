# Modder quickstart — create a pack from the starter pack

CyberBuilder reads every subdirectory of `packs/` that contains `pack.json`, `objects.json`, and `recipes.json`. The fastest way to add your own pack is to copy the reference layout from **`packs/starter_furniture/`** and rename it.

## 1. Copy the starter pack folder

1. In the repo root, duplicate the folder **`packs/starter_furniture`**.
2. Rename the copy to your pack id, for example **`packs/my_furniture_pack`**.

The **folder name** must be a stable slug (letters, digits, `_`, `-`) and must match the **`id`** field in `pack.json` (see `docs/PACK_FORMAT.md`).

## 2. Edit `pack.json`

Open **`packs/<your_pack_id>/pack.json`** and set at least:

- **`id`** — same string as the folder name (e.g. `my_furniture_pack`).
- **`name`**, **`version`**, **`author`** — your metadata.
- **`requires`** — keep `world_builder` if you rely on World Builder for spawnables; add other pack ids or tool names you document as dependencies.

## 3. Edit `objects.json`

Each entry is one catalog object. After copying:

1. Change **`id`** values so they stay **unique within your pack** (and do not collide with ids you intend to keep from the template if you only partially replaced rows).
2. Set **`resourcePath`** only to paths you have verified for your mod or asset pipeline. **Do not invent Cyberpunk resource paths**; leave placeholders **disabled** until you have a real path (see below).
3. Set **`disabled`** to `false` only when the row is valid for export: required fields present, **`resourcePath`** non-empty for enabled objects, and **`type`** is one of the supported values in `docs/PACK_FORMAT.md`.

The starter objects are intentionally **`disabled: true`** with empty **`resourcePath`** so the pack validates without guessing game paths.

## 4. Edit `recipes.json`

Every **`objectId`** must match an **`id`** in **your** `objects.json`. When you rename or remove objects, update recipes to match.

## 5. Configure paths (optional)

**`cyberbuilder.config.json`** at the repo root defaults to:

- **`packsDir`**: `packs` — where your pack folder lives.
- **`distDir`**: `dist` — where exports and summary files are written.
- **`worldBuilderSpawnablesDir`**: `null` — leave unset unless you have a vetted World Builder spawnables path (install rules are documented in the project `TODO` / `.manager` docs).
- **`logging`**: controls diagnostics (`level`, `targets`, output file names). Typical `targets`: `console`, `files`, optionally `external` when wired by integrator code.

## 6. Run validation and export

From the **repository root**, with **Lua** available on your `PATH`:

```text
lua src/cyber_builder/init.lua
```

To validate and log planned work **without** writing export files or install copies:

```text
lua src/cyber_builder/init.lua --dry-run
```

To temporarily increase diagnostics for debugging:

```text
lua src/cyber_builder/init.lua --log-level=DEBUG --log-targets=console,files --log-file=cyberbuilder.debug.log
```

On success, check **`dist/`** for generated World Builder–oriented exports, **`dist/cyberbuilder_errors.log`**, and **`dist/cyberbuilder_export_summary.json`**. Fix any errors reported for your pack id; invalid packs are skipped so other packs can still export.

## Where to read next

- **`docs/PACK_FORMAT.md`** — field-by-field format.
- **`docs/README.md`** — MVP scope and World Builder role.
- **`docs/INSTALL.md`** — dependency stack setup and install scripts.
- **World Builder page** — [Nexus Mods](https://www.nexusmods.com/cyberpunk2077/mods/20660).

# Pack format (`pack.json`, `objects.json`, `recipes.json`)

Each pack lives in its own folder under `packs/<pack_id>/` and ships three JSON files. Filenames are fixed: **`pack.json`**, **`objects.json`**, **`recipes.json`**.

## `pack.json` — pack manifest

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | yes | Stable pack identifier (lowercase slug: letters, digits, `_`, `-`). Must match the folder name you ship under `packs/`. |
| `name` | string | yes | Human-readable pack title. |
| `version` | string | yes | Semantic or mod-style version string (e.g. `0.1.0`). |
| `author` | string | yes | Maintainer or team name. |
| `requires` | array of string | yes | Declared dependencies (e.g. other pack ids or tool names such as `world_builder`). Used for documentation and validation messaging. |

## `objects.json` — catalog entries

Top-level value: **JSON array** of object records.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | yes | Unique object id **within this pack** (stable slug). |
| `name` | string | yes | Display name for lists and logs. |
| `type` | string | yes | One of: `entity`, `mesh`, `decal`, `light`, `sound` (export grouping depends on this). |
| `resourcePath` | string | yes if enabled | Game resource path for this object. May be empty only when the record is **disabled** (see below). |
| `category` | string | yes | Grouping for UX / export (e.g. `furniture`). |
| `price` | number | yes | Notional build or catalog price (non-negative number). |
| `tags` | array of string | yes | Free-form labels (e.g. `["indoor", "chair"]`). |
| `buildable` | boolean | yes | Whether the object is intended to be buildable in the MVP catalog sense. |
| `deletable` | boolean | yes | Whether removal from a player build is allowed in your design (metadata for future tools). |
| `disabled` | boolean | no | If `true`, the object is **skipped during export** and logged; use for placeholders until real `resourcePath` values are confirmed. Defaults to `false` if omitted. |

## `recipes.json` — craft / build recipes

Top-level value: **JSON array** of recipe records. Each recipe must reference an `objectId` that exists in this pack’s `objects.json`.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `objectId` | string | yes | Target object `id` from `objects.json`. |
| `components` | array | yes | Ingredient list (structure may evolve; each entry should identify a component id and quantity in a consistent shape once the schema is finalized). |
| `seconds` | number | yes | Time to complete in seconds (non-negative). |

## File conventions

- UTF-8 encoding, `.json` extension.
- Prefer **normalized paths** in `resourcePath` (no mixed slashes; no `..` segments).
- Invalid packs must be **skippable** without breaking other packs: fix errors in one folder, not across the whole `packs/` tree.

For install prerequisites and MVP boundaries, see `docs/README.md` and `docs/setup/INSTALL.md`.
For the World Builder dependency page, see [Nexus Mods](https://www.nexusmods.com/cyberpunk2077/mods/20660).


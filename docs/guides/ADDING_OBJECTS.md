# Adding Objects to Packs (v0.2)

Use this workflow to add new objects so they appear in the CyberBuilder catalog safely.

## 1) Pick or create a pack folder

Create or reuse a pack folder under:

- `packs/<pack_id>/`

Required files in each pack:

- `pack.json`
- `objects.json`
- `recipes.json`

`<pack_id>` must be a lowercase slug (letters, digits, `_`, `-`) and should match `pack.json.id`.

## 2) Fill `pack.json`

Set these required fields:

- `id`
- `name`
- `version`
- `author`
- `requires` (array)

Keep `id` stable over time.

## 3) Add object records to `objects.json`

`objects.json` is a JSON array. Add one object entry per new object.

Required fields per object:

- `id` (unique inside the pack)
- `name`
- `type` (`entity`, `mesh`, `decal`, `light`, `sound`)
- `resourcePath` (required unless object is disabled)
- `category` (non-empty string)
- `price` (number, must be `>= 0`)
- `tags` (array of lowercase strings)
- `buildable` (boolean)
- `deletable` (boolean)

Optional field:

- `disabled` (boolean, defaults to `false`)

If `disabled` is `true`, the object is hidden from normal catalog/export.

## 4) Add recipe rows to `recipes.json`

`recipes.json` is a JSON array. Each row must target an object that exists in `objects.json`.

Required recipe fields:

- `objectId`
- `components`
- `seconds` (non-negative)

`objectId` must match an object `id` in the same pack.

## 5) Validate and build

Run build scripts to validate packs and regenerate outputs:

```powershell
scripts/build/clean.ps1
scripts/build/build.ps1
```

Check outputs:

- `dist/cyberbuilder_catalog.json`
- `dist/cyberbuilder_export_summary.json`
- `dist/cyberbuilder_errors.log`

If the object is valid and enabled, it should appear in catalog output.

## 6) Check in catalog UI

Open the catalog UI and verify:

- category appears;
- object appears under that category;
- detail panel shows metadata;
- `resourcePath` copy/export actions work.

## Common failure causes

- duplicate global id (`packId:objectId`);
- missing/empty `category`;
- negative `price`;
- tags not lowercase strings;
- missing `resourcePath` on enabled object;
- recipe `objectId` not found in `objects.json`.

---

Last reviewed: 2026-05-07.

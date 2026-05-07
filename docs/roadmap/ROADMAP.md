# CyberBuilder roadmap

This document outlines **planned** directions after the Pack Registry MVP. Ordering and scope may change; nothing here is committed work until it appears as scoped tasks in `TODO.md`.

## v0.1 (current MVP) — Pack Registry

JSON packs, schema validation, logging, and World Builder–compatible export under `dist/`. See `docs/README.md` and `docs/reference/PACK_FORMAT.md`.
Install and dependency links are tracked in `docs/setup/INSTALL.md` and `scripts/install/README.md`.

## v0.2 — Catalog UI

In-game or companion UI to browse validated packs and objects (read-only catalog over exported or packaged data), without spawning into the world from CyberBuilder core.

## v0.3 — Construction Chip

Gameplay-facing layer to select and authorize buildable items from the catalog (still bounded by MVP safety rules in `docs/reference/SAFETY_RULES.md` and `.manager/ruls.md`).

## v0.4 — Placement Wrapper (implemented in code and schemas)

Controlled bridge from Construction Chip authorization to placement via World Builder (or compatible providers), without editing base world nodes. Plan, actual validation snapshot, limits, and risks: `docs/roadmap/ROADMAP_v0_4.md`.

## v0.5 — Scanner Blueprint Integration (planned)

Optional discovery of **safe** build props for catalog hints and blueprints—not NPCs, vehicles, quests, etc.; see `docs/roadmap/ROADMAP_v0_5.md` and `docs/reference/SAFETY_RULES.md`.

## v0.6 — Workshop / Crafting (planned)

See `docs/ROADMAP_v0_6.md`—workshop/crafting integration on top of validated data, without unsafe world editing.

---

Last reviewed: 2026-05-07.


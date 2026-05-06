# CyberBuilder roadmap

This document outlines **planned** directions after the Pack Registry MVP. Ordering and scope may change; nothing here is committed work until it appears as scoped tasks in `TODO.md`.

## v0.1 (current MVP) — Pack Registry

JSON packs, schema validation, logging, and World Builder–compatible export under `dist/`. See `docs/README.md` and `docs/PACK_FORMAT.md`.
Install and dependency links are tracked in `docs/INSTALL.md` and `scripts/install/README.md`.

## v0.2 — Catalog UI

In-game or companion UI to browse validated packs and objects (read-only catalog over exported or packaged data), without spawning into the world from CyberBuilder core.

## v0.3 — Construction Chip

Gameplay-facing layer to select and authorize buildable items from the catalog (still bounded by MVP safety rules in `docs/SAFETY_RULES.md` and `.manager/ruls.md`).

## v0.4 — Placement Wrapper

Controlled bridge toward placement or hand-off to World Builder (or similar tools), without duplicating full world editing or violating the no–game-world-node edit bar for unsupported categories.

## v0.5 — Scanner

Optional scanner-style discovery of **safe** build props for catalog hints only—explicitly not NPC, vehicle, quest, combat, or other blacklisted targets; see `docs/SAFETY_RULES.md`.

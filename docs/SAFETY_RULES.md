# Safety rules — MVP blacklist

CyberBuilder’s MVP is a **pack registry, validation, and export** layer. It must not drive gameplay systems that alter the live world, quests, or hostile simulation. Modders and tool authors should treat the following categories as **out of scope** for CyberBuilder content and workflows in this phase.

## Blacklisted categories

Do **not** use CyberBuilder packs or exports to target, wrap, or promote manipulation of:

| Category | Examples (non-exhaustive) |
|----------|---------------------------|
| **NPC** | Characters, crowds, vendors, pedestrians, scripted actors |
| **Vehicle** | Cars, bikes, AVs, drivable or rideable vehicle entities |
| **Quest** | Quest items, quest triggers, mission-critical interactables |
| **Door** | Doors, gates, portals that control access or streaming |
| **Elevator** | Lifts, moving platforms tied to level flow |
| **Device** | Terminals, security systems, puzzles, world-state machines |
| **Combat objects** | Weapons, mines, turrets, explosives, combat props |

This list matches the project rule set in **`.manager/ruls.md`**: the MVP **must not touch** NPCs, vehicles, quest objects, doors, elevators, devices, or combat objects.

## What CyberBuilder still does

- Validates JSON packs under `packs/*`.
- Exports **World Builder–compatible** path lists for **allowed** object types you define in `objects.json` (see `docs/PACK_FORMAT.md`).
- Leaves **spawning, scanning, deletion, and in-world editing** to **World Builder** (or other tools), not to CyberBuilder core.

## Practical guidance

- Prefer **static build props** (furniture, decor, lights, meshes) with **verified** `resourcePath` values. Do not guess game paths; see `docs/PACK_FORMAT.md` and `docs/MODDER_QUICKSTART.md`.
- If an asset could fall into a gray area (e.g. a prop that doubles as a quest item), **exclude it** from CyberBuilder until a later product phase explicitly supports it.

For acceptance criteria and CI expectations, see **`.manager/dod.md`** and **`.manager/ci-gate.md`**.

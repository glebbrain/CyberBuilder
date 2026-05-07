# Ownership Rules (v0.4)

## Purpose

Defines ownership boundaries for placed objects and the rules for safe removal metadata handling.

## Ownership Model

Placement Wrapper ownership records are metadata-only records for CyberBuilder-managed placements.

Each ownership record uses:

- `placementId`
- `ownerId`
- `packId`
- `objectId`
- `provider`
- `createdAt`
- `lastModifiedAt`

## Ownership Boundaries

- Only placements created through authorized placement flow may become owned records.
- Original game-world objects are never ownership targets.
- Ownership checks are required before removal requests.
- Removal of ownership is scoped to matching `placementId` and `ownerId`.

## Removal Rules

- Removal is metadata-only in v0.4.
- Removal must not modify or delete original world objects.
- Removal request must fail when ownership does not match.
- Successful removal returns metadata indicating safe removal mode.

## Registry Rules

- Ownership registry is exported to `dist/player_placements.json`.
- Duplicate `placementId` entries are rejected.
- Registry exports use deterministic ordering by `placementId`.

## Safety Notes

- Unauthorized ownership mutation is invalid.
- Missing ownership record prevents removal.
- Ownership metadata is part of safety/audit surface and must remain explicit.

## Implementation note (Lua)

`placement_removal_service` loads the ownership registry via an internal `dofile` of `placement_ownership_service`. Registering a record and later calling `mark_removed` / `create_request` must use the **same** registry instance within the process; otherwise removal returns `placement ownership not found` even when ids are valid.

---

Last reviewed: 2026-05-07.

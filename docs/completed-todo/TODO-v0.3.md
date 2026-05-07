# CyberBuilder Construction Chip — TODO.md

## Full Implementation Mode

NO STUBS. NO FAKE SUCCESS. NO UNSAFE WORLD EDITING.

Construction Chip v0.3 is a gameplay-facing authorization and catalog-selection layer only.

This version still DOES NOT:
- spawn objects directly into the world
- scan arbitrary world objects
- modify original Night City objects
- delete quest objects
- alter navmesh
- implement physics destruction
- implement multiplayer/network sync

World Builder remains the underlying spawning/editor layer.

## Goal

Implement CyberBuilder Construction Chip v0.3:
a gameplay-facing layer that allows the player to unlock, browse, authorize, filter, and prepare buildable objects from registered CyberBuilder packs while respecting all safety restrictions.

This layer prepares future construction gameplay without yet becoming a full settlement system.

## CursorAgentAI Execution Contract

Read first:
1. TODO.md
2. `.manager/ruls.md`
3. `.manager/dod.md`
4. `.manager/testing-ruls.md`
5. `.manager/ci-gate.md`
6. `docs/reference/SAFETY_RULES.md`

Execute only the first unchecked task.

No scope creep.

No unsafe spawning.

No direct world editing.

No guessing Cyberpunk resource paths.

All gameplay logic must remain bounded by allowlists and safety validators.

## Definition of Done

Construction Chip system can:

- register buildable catalog entries from packs
- filter unsafe categories
- manage unlock states
- manage build authorization
- expose buildable catalog to UI
- support future economy integration
- support future placement integration
- save/load player unlock state
- export safe build authorization list

Construction Chip must NOT:
- place objects into world directly
- delete world objects
- bypass safety validator
- expose unsafe object categories

## What Changed

v0.3 introduces gameplay-facing systems:
- Construction Chip
- unlock tiers
- authorization state
- category filtering
- catalog browsing
- future economy hooks

World interaction still belongs to World Builder.

## Mini-Rules

Only allow safe categories.

Every buildable object must pass safety validation.

Unsafe objects must never appear in gameplay UI.

Player ownership state must be separated from pack metadata.

Unlock state must survive reload.

Disabled objects must remain inaccessible.

No object placement in this version.

No runtime modification of original game resources.

---

[x] SP:1 Create `docs/features/CONSTRUCTION_CHIP.md` describing gameplay goals, scope limits, and future roadmap ---

[x] SP:1 Create `docs/reference/BUILD_AUTHORIZATION.md` describing authorization pipeline and safety filtering ---

[x] SP:2 Create `schemas/chip_unlocks.schema.json` for player unlock state ---

[x] SP:2 Create `schemas/build_authorization.schema.json` for authorized buildable entries ---

[x] SP:2 Create `src/cyber_builder/construction_chip/` module folder structure ---

[x] SP:2 Create `src/cyber_builder/construction_chip/chip_state.lua` for chip installation and activation state ---

[x] SP:2 Implement chip states enum: `missing`, `installed`, `active`, `restricted` ---

[x] SP:2 Implement `src/cyber_builder/construction_chip/unlock_registry.lua` ---

[x] SP:2 Implement `src/cyber_builder/construction_chip/build_authorizer.lua` ---

[x] SP:2 Implement `src/cyber_builder/construction_chip/category_filter.lua` ---

[x] SP:2 Implement `src/cyber_builder/construction_chip/player_progression.lua` ---

[x] SP:2 Implement `src/cyber_builder/construction_chip/catalog_projection.lua` ---

[x] SP:2 Implement `src/cyber_builder/construction_chip/chip_save_service.lua` ---

[x] SP:2 Implement `src/cyber_builder/construction_chip/chip_load_service.lua` ---

[x] SP:3 Add player unlock persistence file `player_unlocks.json` under safe save folder ---

[x] SP:2 Add validation for duplicate unlock ids ---

[x] SP:2 Add validation for unknown object ids referenced by unlocks ---

[x] SP:2 Add validation for disabled objects never becoming authorized ---

[x] SP:2 Add validation that unsafe categories are always filtered ---

[x] SP:2 Create allowlist categories:
`Furniture`
`Decor`
`Light`
`StaticMesh`
`Interior`
`Workbench`
`Container` ---

[x] SP:2 Create denylist categories:
`NPC`
`Vehicle`
`Quest`
`Door`
`Elevator`
`Combat`
`Device`
`Scripted`
`PhysicsCritical` ---

[x] SP:2 Implement category normalization before validation ---

[x] SP:2 Implement safe-tag filtering:
`buildable`
`safe`
`decor`
`static` ---

[x] SP:2 Implement forbidden-tag filtering:
`quest`
`npc`
`vehicle`
`combat`
`physics`
`story` ---

[x] SP:3 Implement build authorization generation from valid packs only ---

[x] SP:3 Implement authorization cache rebuild when pack registry changes ---

[x] SP:2 Implement deterministic sorting for authorized catalog entries ---

[x] SP:2 Implement hidden/internal object support not shown in gameplay UI ---

[x] SP:2 Implement tier-based unlock system:
`Tier1`
`Tier2`
`Tier3`
`Developer` ---

[x] SP:2 Add starter unlock profile with Tier1 active only ---

[x] SP:2 Implement future economy hook fields:
`price`
`components`
`craftSeconds`
`vendorTier` ---

[x] SP:2 Implement future placement hook fields:
`placementType`
`snapPoints`
`rotationMode` ---

[x] SP:2 Implement authorization export file:
`dist/build_authorization.json` ---

[x] SP:2 Implement unlock export summary:
`dist/chip_unlock_summary.json` ---

[x] SP:2 Implement blocked-object report:
`dist/chip_blocked_objects.json` ---

[x] SP:2 Implement logs with prefix `[ConstructionChip]` ---

[x] SP:2 Add safe fallback if player unlock save is corrupted ---

[x] SP:2 Add recovery flow for missing authorized object definitions ---

[x] SP:2 Add warning when pack category does not match normalized category rules ---

[x] SP:2 Add support for future DLC/community pack dependency metadata ---

[x] SP:2 Add support for future faction/vendor ownership metadata ---

[x] SP:2 Create `docs/features/PLAYER_PROGRESSION.md` describing tier unlock flow ---

[x] SP:2 Create `docs/reference/CATALOG_UI_CONTRACT.md` defining future UI-facing catalog structure ---

[x] SP:2 Create `docs/guides/PACK_AUTHORING_GUIDE.md` with gameplay-safe object authoring examples ---

[x] SP:2 Create `docs/reference/SAFE_CATEGORY_GUIDE.md` explaining safe vs unsafe categories ---

[x] SP:3 Create starter gameplay-safe pack:
`packs/starter_builder_gameplay/` ---

[x] SP:2 Add starter Tier1 furniture entries ---

[x] SP:2 Add starter safe decor entries ---

[x] SP:2 Add starter blocked examples for testing denylist behavior ---

[x] SP:2 Add tests for unsafe category filtering ---

[x] SP:2 Add tests for disabled object authorization rejection ---

[x] SP:2 Add tests for deterministic authorization ordering ---

[x] SP:2 Add tests for corrupted unlock save recovery ---

[x] SP:2 Add tests for duplicate unlock id detection ---

[x] SP:2 Add tests for hidden/internal object exclusion from gameplay catalog ---

[x] SP:2 Add tests for missing pack dependency handling ---

[x] SP:2 Add tests for tier restriction enforcement ---

[x] SP:2 Add `.manager/testing-ruls.md` update for Construction Chip scenarios ---

[x] SP:2 Add `.manager/ci-gate.md` update for authorization validation and denylist enforcement ---

[x] SP:2 Add `.manager/ruls.md` update forbidding gameplay exposure of unsafe objects ---

[x] SP:2 Add `docs/roadmap/ROADMAP_v0_4.md` for future Placement Wrapper integration ---

[x] SP:2 Add `docs/roadmap/ROADMAP_v0_5.md` for future Scanner Blueprint system ---

[x] SP:1 Run full validation and document actual v0.3 limitations and remaining risks ---

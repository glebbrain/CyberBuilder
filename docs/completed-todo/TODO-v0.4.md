# CyberBuilder Placement Wrapper — TODO.md

## Full Implementation Mode

NO STUBS. NO FAKE SUCCESS. NO UNSAFE WORLD EDITING.

Placement Wrapper v0.4 is a controlled placement bridge between:
- CyberBuilder gameplay/catalog systems
- World Builder (or compatible spawning/editing systems)

This version still DOES NOT:
- implement unrestricted world editing
- edit original Night City nodes
- support unsupported categories
- modify quest systems
- edit navmesh
- support NPC placement
- support vehicle placement
- support physics-critical runtime editing
- support multiplayer sync

Placement Wrapper is NOT a replacement for World Builder.

## Goal

Implement CyberBuilder Placement Wrapper v0.4:
a safe abstraction layer that validates, prepares, tracks, and delegates placement operations to supported placement providers while enforcing gameplay safety rules and preventing unsupported world manipulation.

The wrapper must provide:
- placement authorization
- placement preparation
- placement ownership tracking
- placement persistence metadata
- provider abstraction
- safe hand-off to World Builder-compatible systems

without becoming a full editor.

## CursorAgentAI Execution Contract

Read first:
1. TODO.md
2. `.manager/ruls.md`
3. `.manager/dod.md`
4. `.manager/testing-ruls.md`
5. `.manager/ci-gate.md`
6. `docs/reference/SAFETY_RULES.md`
7. `docs/reference/CATALOG_UI_CONTRACT.md`
8. `docs/reference/BUILD_AUTHORIZATION.md`

Execute only the first unchecked task.

No scope creep.

Do not implement unrestricted spawning.

Do not implement destructive editing.

Do not guess Cyberpunk resource paths.

Do not bypass safety validator.

## Definition of Done

Placement Wrapper can:

- validate placement requests
- validate placement ownership
- validate safe categories
- create placement session metadata
- normalize placement transforms
- export placement payloads
- delegate placement to providers
- track player-owned placed objects
- save/load placement metadata
- safely remove player-owned placement metadata

Placement Wrapper must NOT:
- edit original world nodes
- place unsafe categories
- bypass denylist
- delete original objects
- manipulate quest objects
- manipulate navmesh
- manipulate NPCs or vehicles

## What Changed

v0.4 introduces:
- placement sessions
- placement transforms
- provider abstraction
- ownership tracking
- placement persistence metadata
- safe placement delegation

Actual world editing/spawning remains delegated to World Builder or compatible providers.

## Mini-Rules

Every placement must be authorized.

Only safe categories may be placed.

Every placed object must have ownership metadata.

Original world objects must never become owned objects.

Placement provider failures must not corrupt save state.

All placement transforms must be normalized.

Unsafe placement requests must fail explicitly.

No direct editing of Night City base world.

No placement without authorization.

---

[x] SP:1 Create `docs/PLACEMENT_WRAPPER.md` describing wrapper architecture and provider model ---

[x] SP:1 Create `docs/PLACEMENT_SAFETY.md` describing placement safety guarantees and restrictions ---

[x] SP:2 Create `schemas/placement_request.schema.json` ---

[x] SP:2 Create `schemas/placement_result.schema.json` ---

[x] SP:2 Create `schemas/placement_transform.schema.json` ---

[x] SP:2 Create `schemas/placement_session.schema.json` ---

[x] SP:2 Create `schemas/player_placements.schema.json` ---

[x] SP:2 Create `src/cyber_builder/placement_wrapper/` module folder structure ---

[x] SP:2 Implement `placement_request_validator.lua` ---

[x] SP:2 Implement `placement_transform_normalizer.lua` ---

[x] SP:2 Implement `placement_session_service.lua` ---

[x] SP:2 Implement `placement_provider_registry.lua` ---

[x] SP:2 Implement `placement_provider_worldbuilder.lua` ---

[x] SP:2 Implement `placement_ownership_service.lua` ---

[x] SP:2 Implement `placement_save_service.lua` ---

[x] SP:2 Implement `placement_load_service.lua` ---

[x] SP:2 Implement `placement_removal_service.lua` ---

[x] SP:2 Implement `placement_authorization_bridge.lua` connected to Construction Chip authorization ---

[x] SP:2 Implement placement request states:
`pending`
`validated`
`delegated`
`placed`
`failed`
`removed` ---

[x] SP:2 Implement placement provider states:
`available`
`missing`
`disabled`
`unsupported_version`
`runtime_error` ---

[x] SP:2 Validate object exists in authorized build catalog before placement ---

[x] SP:2 Validate object category passes allowlist ---

[x] SP:2 Validate object category does not match denylist ---

[x] SP:2 Validate object is not disabled ---

[x] SP:2 Validate authorization freshness and reject stale Construction Chip authorization entries ---

[x] SP:2 Validate placement ownership before removal requests ---

[x] SP:2 Validate placement transform numeric ranges ---

[x] SP:2 Validate scale range:
`0.1 <= scale <= 3.0` ---

[x] SP:2 Validate rotation normalization:
`0-360 degrees` ---

[x] SP:2 Validate position vector completeness before delegation ---

[x] SP:2 Implement safe placement tags:
`buildable`
`safe`
`decor`
`static`
`owned` ---

[x] SP:2 Implement forbidden placement tags:
`quest`
`npc`
`vehicle`
`combat`
`physics`
`story`
`critical` ---

[x] SP:3 Implement placement request generation from Construction Chip authorized objects only ---

[x] SP:3 Implement deterministic placement id generation ---

[x] SP:2 Implement placement session timeout cleanup ---

[x] SP:2 Implement placement request retry policy for provider failures ---

[x] SP:2 Implement provider capability discovery:
`supportsPlacement`
`supportsRemoval`
`supportsMove`
`supportsRotate`
`supportsPersistence` ---

[x] SP:2 Implement provider version compatibility checks ---

[x] SP:2 Implement provider health checks before delegation ---

[x] SP:3 Implement World Builder export payload generation for placement requests ---

[x] SP:3 Implement placement payload queue:
`dist/placement_queue/` ---

[x] SP:2 Implement placement session logs with prefix `[PlacementWrapper]` ---

[x] SP:2 Implement placement audit log:
`dist/placement_audit.log` ---

[x] SP:2 Implement placement error report:
`dist/placement_errors.log` ---

[x] SP:2 Implement placement ownership registry:
`dist/player_placements.json` ---

[x] SP:2 Implement safe placement removal metadata without touching original world objects ---

[x] SP:2 Implement orphan placement recovery flow ---

[x] SP:2 Implement corrupted placement save recovery flow ---

[x] SP:2 Implement duplicate placement id detection ---

[x] SP:2 Implement duplicate placement transform detection warning ---

[x] SP:2 Implement hidden/internal objects exclusion from placement layer ---

[x] SP:2 Implement blocked placement report:
`dist/blocked_placements.json` ---

[x] SP:2 Add structured blocked reason codes in placement result/reporting:
`unsafe_category`
`forbidden_tag`
`missing_authorization`
`stale_authorization`
`disabled_object`
`provider_unavailable` ---

[x] SP:2 Implement deterministic ordering of placement exports ---

[x] SP:2 Add placement ownership fields:
`placementId`
`ownerId`
`packId`
`objectId`
`provider`
`createdAt`
`lastModifiedAt` ---

[x] SP:2 Add future placement metadata hooks:
`snapGroup`
`placementSurface`
`powerRequirement`
`collisionProfile`
`interiorOnly` ---

[x] SP:2 Add future streaming hooks:
`cellId`
`streamingGroup`
`loadRadius` ---

[x] SP:2 Add future multiplayer-safe metadata placeholders:
`networkSafe`
`shareable`
`sessionScoped` ---

[x] SP:2 Create `docs/PLACEMENT_PROVIDER_API.md` defining provider contract ---

[x] SP:2 Create `docs/PLACEMENT_LIFECYCLE.md` describing placement states and transitions ---

[x] SP:2 Create `docs/OWNERSHIP_RULES.md` defining ownership boundaries and removal rules ---

[x] SP:2 Create `docs/SAFE_PLACEMENT_GUIDE.md` explaining safe placement authoring ---

[x] SP:2 Create `docs/WORLDBUILDER_BRIDGE.md` documenting World Builder hand-off integration ---

[x] SP:3 Create starter safe placement scenarios pack:
`packs/starter_safe_placements/` ---

[x] SP:2 Add starter placement presets for furniture objects ---

[x] SP:2 Add starter placement presets for decor objects ---

[x] SP:2 Add blocked placement examples for denylist testing ---

[x] SP:2 Add tests for unauthorized placement rejection ---

[x] SP:2 Add tests for denylist category rejection ---

[x] SP:2 Add tests for disabled object placement rejection ---

[x] SP:2 Add tests for invalid transform rejection ---

[x] SP:2 Add tests for duplicate placement id handling ---

[x] SP:2 Add tests for orphan placement recovery ---

[x] SP:2 Add tests for corrupted placement save recovery ---

[x] SP:2 Add tests for provider unavailable handling ---

[x] SP:2 Add tests for deterministic placement export ordering ---

[x] SP:2 Add tests for ownership validation during removal requests ---

[x] SP:2 Add tests ensuring original world objects are never marked owned ---

[x] SP:2 Add `.manager/testing-ruls.md` update for placement lifecycle scenarios ---

[x] SP:2 Add `.manager/ci-gate.md` update for placement validation and provider safety checks ---

[x] SP:2 Add `.manager/ruls.md` update forbidding direct Night City world editing ---

[x] SP:2 Add `docs/roadmap/ROADMAP_v0_5.md` for Scanner Blueprint integration ---

[x] SP:2 Add `docs/ROADMAP_v0_6.md` for Workshop/Crafting integration ---

[x] SP:1 Run full validation and document actual v0.4 limitations and remaining risks ---

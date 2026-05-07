# Placement Wrapper v0.4

## Purpose

Placement Wrapper is a safety-first abstraction layer between CyberBuilder gameplay/catalog flows and external placement providers such as World Builder-compatible systems.

It validates and prepares placement operations, tracks ownership metadata, and delegates placement work to a provider without becoming a full world editor.

## Scope

Placement Wrapper v0.4 is responsible for:

- authorizing placement requests from safe, gameplay-approved sources;
- validating request content and safety constraints;
- normalizing placement transforms before delegation;
- creating and tracking placement session metadata;
- delegating placement/removal operations to providers through a stable contract;
- recording player-owned placement metadata for persistence and safe removal.

Placement Wrapper v0.4 does not:

- edit original Night City world nodes;
- spawn unsafe categories (NPC, vehicle, quest, combat, physics-critical, and similar forbidden categories);
- bypass denylist/forbidden-tag safety checks;
- replace World Builder as a full runtime world editing system.

## Architecture Overview

Wrapper flow:

1. **Request intake**  
   Placement request is created from authorized build catalog entries only.
2. **Authorization and safety validation**  
   Request is checked for source authorization, category/tag safety, object availability, and enabled status.
3. **Transform normalization**  
   Position/rotation/scale are normalized to supported numeric ranges and canonical representation.
4. **Session creation**  
   A placement session is created to track lifecycle, provider target, timestamps, and correlation ids.
5. **Provider delegation**  
   Wrapper routes the validated request to a selected provider through provider API methods.
6. **Ownership and persistence update**  
   On successful placement/removal, player-owned metadata is updated in wrapper-managed storage.
7. **Logging and audit output**  
   Wrapper emits deterministic logs for success/failure, provider health, and safety rejections.

## Core Components

- **Placement Request Validator**  
  Verifies schema validity, authorization source, allowlist/denylist, forbidden tags, and object enabled state.
- **Placement Transform Normalizer**  
  Validates numeric completeness and normalizes rotation and scale ranges.
- **Placement Session Service**  
  Creates request session records, manages state transitions, and performs timeout/cleanup logic.
- **Placement Provider Registry**  
  Discovers providers, validates capabilities/version compatibility, and exposes healthy provider selection.
- **Provider Adapter (World Builder)**  
  Converts wrapper request payloads into provider-specific placement/removal payloads.
- **Ownership Service**  
  Tracks CyberBuilder-owned placement entries and enforces ownership checks on removal.
- **Save/Load Services**  
  Persist and recover placement ownership/session metadata from deterministic files.
- **Removal Service**  
  Performs safe metadata-driven removal requests without mutating original world objects directly.

## Request and Provider States

Placement request lifecycle states:

- `pending`
- `validated`
- `delegated`
- `placed`
- `failed`
- `removed`

Provider runtime states:

- `available`
- `missing`
- `disabled`
- `unsupported_version`
- `runtime_error`

State transitions must be explicit and logged. Failed transitions must preserve save integrity.

## Provider Model

The wrapper uses a provider abstraction so integration logic remains stable while backend placement engines can vary.

Provider contract expectations:

- explicit capability declaration (`supportsPlacement`, `supportsRemoval`, `supportsMove`, `supportsRotate`, `supportsPersistence`);
- deterministic input/output payload handling;
- explicit, actionable error reporting;
- health/version checks before delegation;
- no implicit world mutation outside declared placement/removal methods.

Provider selection rules:

- only healthy, compatible, enabled providers are eligible;
- incompatible or unhealthy providers fail fast with explicit reason;
- provider failures must not corrupt wrapper ownership/session state.

## Ownership and Persistence Boundaries

Ownership metadata identifies only CyberBuilder-managed placements and must include stable ids and provenance (for example: placement id, owner id, pack/object ids, provider, timestamps).

Safety boundary rules:

- original game-world objects must never be marked as owned placements;
- removal operations target owned placement metadata and delegated provider removal only;
- wrapper must never perform destructive edits on base world data.

## Logging and Determinism

Placement Wrapper logs should be:

- prefixed for traceability (for example `[PlacementWrapper]`);
- explicit about validation failures and provider errors;
- deterministic in ordering for exported payloads and persisted metadata where practical.

## Failure Handling

Wrapper failures must be explicit and safe:

- invalid or unsafe requests are rejected before provider calls;
- provider errors mark request as `failed` with actionable details;
- retries may be attempted under controlled policy for transient provider failures;
- corrupted metadata inputs trigger safe recovery paths without crashes.

## Integration Notes

- Wrapper operates as a controlled bridge, not as a direct spawn/edit API.
- World Builder (or compatible system) remains the execution backend for actual placement actions.
- Gameplay/UI layers should interact with wrapper APIs only after authorization and validation steps are satisfied.

## Lua module loading note

`placement_removal_service.lua` loads `placement_ownership_service.lua` via `dofile` relative to its own directory. Each such load creates **separate** ownership registry state in one Lua process. Integrators and tests must avoid registering through one module instance and calling `mark_removed` / `create_request` through another (otherwise you may see `placement ownership not found`). Prefer a single load path for Placement Wrapper modules at runtime.

---

Last reviewed: 2026-05-07.

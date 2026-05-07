# Placement Safety Guarantees (v0.4)

## Safety Objective

Placement Wrapper v0.4 exists to make placement operations safe, explicit, and auditable while preventing unsupported world manipulation.

The wrapper must enforce safety before any provider delegation and must fail explicitly on unsafe input.

## Core Safety Guarantees

- Placement requests are accepted only from authorized gameplay/catalog sources.
- Only safe categories and tags are eligible for placement.
- Denylisted categories and forbidden tags are blocked before delegation.
- Disabled or invalid objects are not eligible for placement.
- Every placement operation is tracked through explicit lifecycle states.
- Every owned placement has ownership metadata for safe tracking and removal.
- Provider failures do not silently succeed and must not corrupt save state.
- Original game-world objects are never treated as CyberBuilder-owned placements.

## Forbidden Operations

Placement Wrapper v0.4 does not allow:

- direct editing of Night City base world nodes;
- deletion or modification of original game objects;
- quest object manipulation;
- NPC placement;
- vehicle placement;
- navmesh manipulation;
- combat/physics-critical unsafe placement flows;
- bypassing authorization or safety validators.

## Authorization Boundary

Every placement must be authorized before validation and delegation.

Minimum boundary requirements:

- request source is trusted and expected by wrapper integration;
- object exists in authorized catalog scope;
- object is enabled for use;
- object category/tag safety checks pass.

Requests that fail authorization must be rejected explicitly and logged.

## Category and Tag Safety

Safety enforcement combines allowlist behavior with denylist hard blocking.

Expected safe placement tags:

- `buildable`
- `safe`
- `decor`
- `static`
- `owned`

Forbidden tags (hard fail):

- `quest`
- `npc`
- `vehicle`
- `combat`
- `physics`
- `story`
- `critical`

Any denylisted category or forbidden tag blocks placement before provider hand-off.

## Ownership Safety

Ownership metadata is required for all CyberBuilder-managed placements.

Safety rules:

- ownership is assigned only to wrapper-created placements;
- original world objects must never receive ownership metadata;
- removal requests must validate ownership before delegation;
- failed removal must not remove or mutate unrelated state.

## Transform Safety

Placement transforms must be validated and normalized before provider delegation.

Required checks include:

- numeric completeness for position/rotation/scale fields;
- scale bounds enforcement (`0.1 <= scale <= 3.0`);
- rotation normalization to canonical `0-360` representation;
- explicit failure on malformed or missing transform values.

## Provider Safety Contract

Providers are treated as untrusted until verified healthy and compatible.

Before delegation, wrapper must validate:

- provider availability/enabled state;
- version compatibility;
- required capability flags;
- runtime health status.

If provider checks fail, wrapper must stop the operation safely and record actionable error details.

## Failure and Recovery Safety

Safety-preserving failure behavior:

- reject unsafe requests with explicit reason;
- mark failed lifecycle state (`failed`) without fake success;
- preserve existing ownership/session metadata integrity;
- allow controlled retry only for transient provider failures;
- trigger safe recovery flow for corrupted persisted placement metadata.

## Logging and Audit Expectations

Safety events should be observable and actionable.

Minimum expectations:

- clear safety rejection reasons in logs;
- consistent prefixing for placement wrapper events;
- deterministic ordering where practical for exported or persisted safety-relevant data;
- enough context to diagnose authorization, validation, provider, and ownership failures.

## Non-Goals and Boundaries

Placement Wrapper v0.4 is a controlled bridge, not a full editor.

It delegates actual spawn/edit execution to World Builder-compatible providers and must maintain strict safety boundaries while doing so.

---

Last reviewed: 2026-05-07.

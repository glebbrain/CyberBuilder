# Build Authorization Pipeline v0.3

## Purpose

Build authorization defines which objects are allowed to appear in Construction Chip gameplay-facing catalog views.

The pipeline exists to ensure only safe, validated, and enabled content is authorized for player-facing use.

## Pipeline Overview

Authorization is produced in deterministic stages:

1. load pack data from the registry source;
2. validate pack structure and object-level required fields;
3. reject invalid packs without blocking valid packs;
4. filter out disabled objects;
5. apply category safety rules (allowlist + denylist);
6. apply safety tag rules (required-safe tags and forbidden tags);
7. build normalized authorized entries;
8. output deterministic authorization data for downstream systems.

Each stage must preserve explicit error reporting and must not silently pass invalid content.

## Validation Inputs

Before authorization, input data must satisfy baseline requirements:

- pack metadata is valid and readable;
- object identifiers are stable and unique within a pack;
- global object identity remains `packId:objectId`;
- required object fields are present and typed correctly;
- disabled objects are excluded from gameplay authorization.

Invalid input must produce actionable validation messages.

## Safety Filtering

Safety filtering is mandatory and hard-fail for unauthorized content exposure.

Filtering rules:

- allow only approved gameplay-safe categories;
- deny known unsafe categories (NPC, vehicle, quest, combat, scripted, and similar);
- require safe gameplay tags where configured;
- reject forbidden gameplay tags (quest, npc, vehicle, combat, physics, story);
- prevent unsafe or blocked objects from entering gameplay-facing outputs.

If category/tag state is ambiguous, object should remain blocked until explicitly validated.

## Authorization Output Contract

Authorized output must be deterministic and suitable for catalog projection:

- sorted deterministically;
- excludes disabled, invalid, and blocked objects;
- includes only entries that pass all validation and safety stages;
- remains gameplay-facing only (no direct placement/spawn authority).

This output is an authorization list, not a world-edit command stream.

## Scope Limits

Build authorization in v0.3 does **not**:

- place or spawn objects in the game world;
- edit or delete world objects;
- bypass safety validation under any mode.

Authorization is preparation logic only and must remain bounded by safety validators.

## Future Compatibility

The authorization model is designed to support future fields without weakening safety:

- economy metadata (`price`, components, craft time, vendor tier);
- placement metadata (`placementType`, snap points, rotation mode);
- dependency metadata for DLC/community/faction constraints.

Future extensions must remain backward-compatible with existing safe authorization behavior.

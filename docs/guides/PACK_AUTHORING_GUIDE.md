# Pack Authoring Guide (Construction Chip v0.3)

## Purpose

This guide explains how to author gameplay-safe packs that can be authorized by Construction Chip v0.3.

v0.3 is authorization and catalog preparation only. It does not place objects into the world.

## Required Pack Files

Each pack should provide:

- `pack.json`
- `objects.json`
- optional/required files according to current schema rules

Invalid packs are skipped and should not block valid packs.

## Safe Authoring Rules

Author objects to pass safety filters:

- use gameplay-safe categories only;
- avoid denylisted/unsafe categories;
- include at least one safe tag (`buildable`, `safe`, `decor`, `static`);
- avoid forbidden tags (`quest`, `npc`, `vehicle`, `combat`, `physics`, `story`);
- keep object identifiers stable and unique.

Disabled objects must not be expected to appear in authorized gameplay catalog output.

## Recommended Object Fields

For stable gameplay-facing behavior, include:

- identity: `id`, `name`, `type`
- resource: `resourcePath`, `category`, `tags`
- economy hooks: `price`, `components`, `craftSeconds`, `vendorTier`
- placement hooks: `placementType`, `snapPoints`, `rotationMode`
- future metadata hooks: dependency and ownership fields when relevant

Missing optional fields should degrade gracefully, but required schema fields must be present.

## Gameplay-Safe Example

Example object intent (conceptual):

- category: `Furniture`
- tags: `["buildable", "safe", "decor"]`
- non-negative economy fields
- no forbidden tags
- not disabled

This kind of object is expected to pass category/tag safety gates and appear in authorized catalog output.

## Blocked Example Patterns

Objects will typically be blocked when:

- category is denylisted (e.g. NPC/Vehicle/Quest-related);
- tags include forbidden gameplay tags;
- object is marked disabled;
- required identifiers/fields are missing;
- definition fails validation.

Use generated blocked-object and error outputs in `dist/` to diagnose issues.

## Determinism and Stability

To keep catalog/export stable across builds:

- keep IDs stable across versions;
- avoid random/dynamic field generation in pack data;
- use normalized category naming consistently.

## Scope Reminder

Pack authoring for v0.3 prepares safe authorization/catalog behavior only.

Do not assume pack data grants direct spawn/place/delete behavior in-game.

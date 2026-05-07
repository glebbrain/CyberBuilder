# Safe Placement Guide (v0.4)

## Purpose

Practical authoring guide for safe placement requests in Placement Wrapper v0.4.

## Authoring Checklist

- Use only Construction Chip-authorized objects.
- Use allowlisted categories only.
- Do not use denylisted or forbidden-tagged content.
- Ensure placement transform is complete and numeric.
- Keep scale inside `0.1..3.0`.
- Keep rotation in `0..360` for `pitch`, `yaw`, `roll`.
- Include ownership-safe context (`ownerId`, `sessionId`, `provider`).

## Required Request Shape

A safe placement request must include:

- `requestId`
- `sessionId`
- `ownerId`
- `packId`
- `objectId`
- `globalId`
- `provider`
- `position` (`x`, `y`, `z`)
- `rotation` (`pitch`, `yaw`, `roll`)
- `scale`
- `tags`
- `requestedAt`

## Tag Rules

Safe tags intended for placement flow:

- `buildable`
- `safe`
- `decor`
- `static`
- `owned`

Forbidden tags:

- `quest`
- `npc`
- `vehicle`
- `combat`
- `physics`
- `story`
- `critical`

## Blocked Reasons You Should Expect

If request is unsafe, blocking may report structured reasons such as:

- `unsafe_category`
- `forbidden_tag`
- `missing_authorization`
- `stale_authorization`
- `disabled_object`
- `provider_unavailable`

## Safety Boundaries

- Placement Wrapper is not unrestricted world editing.
- Original world objects are never owned by placement flow.
- Removal is metadata-safe and ownership-gated.

---

Last reviewed: 2026-05-07.

# Safe Category Guide (Construction Chip v0.3)

## Purpose

This guide defines which object categories are considered safe or unsafe for gameplay-facing Construction Chip catalog exposure.

It supports authorization safety rules only. It does not permit world placement/editing.

## Safe Categories (Allowlist)

Objects in these categories are candidates for gameplay catalog authorization:

- `Furniture`
- `Decor`
- `Light`
- `StaticMesh`
- `Interior`
- `Workbench`
- `Container`

Allowlist membership alone is not sufficient; objects must still pass all other safety checks.

## Unsafe Categories (Denylist)

Objects in these categories must never appear in normal gameplay UI:

- `NPC`
- `Vehicle`
- `Quest`
- `Door`
- `Elevator`
- `Combat`
- `Device`
- `Scripted`
- `PhysicsCritical`

If category data maps to denylisted intent, object authorization must fail.

## Normalization Rules

Category values are normalized before validation to reduce pack-format variance:

- trim surrounding whitespace;
- normalize case;
- collapse delimiter variants (spaces/underscores/hyphens) into canonical comparison form.

If a normalized category matches neither allowlist nor denylist, system should produce a warning for author review.

## Tag Interaction

Category safety works together with tag safety:

- safe tags are required for authorization candidates;
- forbidden tags can block objects even when category is allowlisted.

Category pass does not override forbidden tag restrictions.

## Authoring Recommendations

To avoid ambiguity and warnings:

- use canonical allowlist names in pack data;
- avoid mixed naming variants for the same category;
- do not repurpose denylisted categories for non-combat/non-NPC content.

## Scope Limits

This guide applies to Construction Chip v0.3 gameplay-facing catalog authorization only.

It does not authorize spawning, deletion, scanner gameplay, or direct world editing.

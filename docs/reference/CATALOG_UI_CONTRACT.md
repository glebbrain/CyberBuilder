# Catalog UI Contract (Construction Chip v0.3)

## Purpose

This contract defines the UI-facing shape of authorized Construction Chip catalog entries.

It exists to keep gameplay UI predictable, safe, and decoupled from raw pack internals.

## Input Boundary

UI must consume only projection output from Construction Chip authorization/catalog services.

UI must not read raw pack files directly.

UI must not expose entries blocked by safety validation.

## Required Entry Fields

Each UI entry should provide:

- `globalId` (stable: `packId:objectId`)
- `packId`
- `objectId`
- `name`
- `type`
- `category`
- `tags`
- `resourcePath`

## Optional/Forward-Compatible Fields

When available, UI may display or store:

- `price`
- `components`
- `craftSeconds`
- `vendorTier`
- `placementType`
- `snapPoints`
- `rotationMode`
- dependency metadata (DLC/community)
- ownership metadata (faction/vendor)

UI must tolerate missing optional fields without failing.

## Visibility Rules

UI must exclude by default:

- unauthorized entries;
- blocked/unsafe entries;
- hidden/internal entries (unless an explicit debug mode enables them).

Unsafe categories and forbidden-tag content must never appear in normal gameplay UI.

## Filtering and Search Expectations

UI filtering/search should operate on projected safe entries and support:

- category filtering;
- text search over name, ids, tags, category, and resource path.

Search behavior must not bypass authorization/safety constraints.

## Determinism and Stability

Catalog entry ordering should remain deterministic to avoid UI flicker and inconsistent pagination.

`globalId` is the preferred stable key for UI identity, selection persistence, and diffing.

## Scope Limits

This contract is for browse/authorize flow only in v0.3.

It does not grant placement/spawn permissions and does not imply world-edit actions.

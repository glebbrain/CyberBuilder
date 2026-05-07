# Placement Provider API (v0.4)

## Purpose

Defines the provider contract used by Placement Wrapper to delegate placement operations safely.

## Provider Definition

A provider must expose:

- `id` (string, non-empty)
- `name` (string, non-empty)
- `version` (string, semver-like)
- `state` (one of: `available`, `missing`, `disabled`, `unsupported_version`, `runtime_error`)
- `capabilities` object with boolean flags:
  - `supportsPlacement`
  - `supportsRemoval`
  - `supportsMove`
  - `supportsRotate`
  - `supportsPersistence`

## Required Provider Functions

- `get_provider_definition() -> provider_definition`
- `to_place_payload(request) -> payload | nil, error`
- `to_remove_payload(removal_request) -> payload | nil, error`

Optional helper currently used by World Builder adapter:

- `generate_export_payload_for_request(request) -> export_payload | nil, error`

## Place Payload Contract

`to_place_payload` returns:

- `provider` (string)
- `operation` (`place`)
- `requestId` (string)
- `sessionId` (string or nil)
- `ownerId` (string)
- `globalId` (string)
- `packId` (string or nil)
- `objectId` (string or nil)
- `transform`:
  - `position`: `x`, `y`, `z` (number)
  - `rotation`: `pitch`, `yaw`, `roll` (number)
  - `scale` (number)
- `tags` (array or nil)
- `metadataHooks` (future placeholders)
- `streamingHooks` (future placeholders)
- `multiplayerHooks` (future placeholders)

## Remove Payload Contract

`to_remove_payload` returns:

- `provider` (string)
- `operation` (`remove`)
- `requestId` (string)
- `sessionId` (string or nil)
- `placementId` (string)
- `ownerId` (string)

## Error Handling Contract

- On invalid input, provider functions must return `nil, "error message"`.
- Providers must not mutate original game-world objects directly.
- Provider unavailability must be reported via state and explicit errors.

---

Last reviewed: 2026-05-07.

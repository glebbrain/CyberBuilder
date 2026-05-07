# World Builder Bridge (v0.4)

## Purpose

Documents how Placement Wrapper hands off safe, validated placement operations to the World Builder provider adapter.

## Bridge Components

Primary modules used in the hand-off:

- `placement_provider_worldbuilder.lua`
- `placement_queue_service.lua`
- `placement_provider_registry.lua`

## Handoff Flow

1. Validate and authorize placement request in wrapper layer.
2. Convert request to provider payload with `to_place_payload(...)`.
3. Wrap payload for export with `generate_export_payload_for_request(...)`.
4. Enqueue export payload to `dist/placement_queue/` (JSON file per `requestId`).
5. External World Builder-compatible flow consumes queued payloads.

## Provider Payload Contract

Place payload includes:

- `provider = "worldbuilder"`
- `operation = "place"`
- request identity (`requestId`, `sessionId`, `ownerId`, `globalId`, `packId`, `objectId`)
- normalized `transform` (`position`, `rotation`, `scale`)
- `tags`
- future hooks:
  - `metadataHooks`
  - `streamingHooks`
  - `multiplayerHooks`

Remove payload includes:

- `provider = "worldbuilder"`
- `operation = "remove"`
- `requestId`, `sessionId`, `placementId`, `ownerId`

## Safety Notes

- Bridge is delegation only; no direct world editing by wrapper.
- Provider health/version checks are expected before delegation.
- Hidden/internal, disabled, unauthorized, or unsafe objects must be blocked before bridge hand-off.

---

Last reviewed: 2026-05-07.

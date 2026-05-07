# Catalog UI (v0.2)

This document describes the current CyberBuilder catalog UI behavior in v0.2 and its intended safety boundaries.

## Purpose

The catalog UI is a read-only browsing layer for validated pack objects.
It helps modders:

- browse categories;
- inspect object metadata;
- copy `resourcePath`;
- export selected `resourcePath` to a single World Builder `.txt` file.

World Builder remains the spawning/placement tool.

## Current UI behavior

The current UI window (`CyberBuilder Catalog`) provides:

- warning banner: `CyberBuilder v0.2 does not spawn objects; use World Builder for placement.`
- categories list (derived from loaded catalog items);
- object list for the selected category;
- object detail panel with:
  - `name`
  - `packId`
  - `type`
  - `price`
  - `tags`
  - `resourcePath`
- action: copy selected `resourcePath` (clipboard when available; otherwise logs the path);
- action: export selected object to:
  - `dist/worldbuilder/selected/cyberbuilder_selected_<packId>_<objectId>.txt`
- empty-state messages:
  - no packs loaded
  - no category selected
  - no search results
- validation error panel that reads recent lines from:
  - `dist/cyberbuilder_errors.log`

## Safety and scope limits (v0.2)

The catalog UI must not:

- spawn/place/delete objects;
- modify original game-world data;
- scan world objects;
- implement crafting/economy/gameplay systems.

The UI is intentionally limited to safe metadata browsing and safe export helpers under project `dist/`.

---

Last reviewed: 2026-05-07.

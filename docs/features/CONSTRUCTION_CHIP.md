# Construction Chip v0.3

## Gameplay Goals

Construction Chip v0.3 is a gameplay-facing authorization and catalog-selection layer for CyberBuilder packs.

This version is responsible for:

- unlocking buildable content through player progression;
- authorizing safe objects for gameplay-facing browsing;
- filtering unsafe categories and forbidden content before UI exposure;
- preparing deterministic data that later systems can consume.

The Construction Chip is a safety and progression layer, not a world-editing system.

## Scope Limits (Hard Boundaries)

Construction Chip v0.3 does **not**:

- spawn objects directly into the world;
- scan arbitrary game-world objects;
- modify original Night City world data;
- delete world objects, including quest objects;
- alter navmesh, physics destruction, or combat/gameplay simulation systems.

World interaction remains outside this component in v0.3. Any object placement workflow belongs to future layers and must remain safety-gated.

## Safety Model

All gameplay-facing catalog content must pass safety checks before exposure:

1. source pack validity checks;
2. category allowlist/denylist filtering;
3. disabled/unsafe object exclusion;
4. deterministic authorization output generation.

If an object fails safety requirements, it must be blocked from the gameplay-facing catalog.

## Player-Facing Responsibilities

Construction Chip v0.3 supports player-facing preparation flows:

- chip installation/activation state;
- tier-based unlock state;
- authorized object list projection for UI;
- persistence of player unlock progress;
- export of safe authorization data for downstream consumers.

This enables controlled progression now while keeping placement mechanics out of scope.

## Forward Roadmap Alignment

The Construction Chip establishes foundation data for future versions:

- future economy integration (`price`, components, craft timing, vendor tier);
- future placement integration (placement type, snap data, rotation mode);
- future UI expansions built on authorized catalog projections;
- future dependency metadata (DLC/community/faction ownership extensions).

Future roadmap work must preserve core safety boundaries: no unsafe categories in gameplay UI and no direct world editing by this module.

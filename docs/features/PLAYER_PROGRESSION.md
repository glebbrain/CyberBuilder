# Player Progression (Construction Chip v0.3)

## Purpose

Player progression controls which buildable content tiers are available through the Construction Chip gameplay-facing catalog.

The system is progression and authorization support only. It does not place objects into the world.

## Tier Model

Construction Chip v0.3 supports these tiers:

- `Tier1`
- `Tier2`
- `Tier3`
- `Developer`

Tier order is strict and used by access checks:

`Tier1` < `Tier2` < `Tier3` < `Developer`

## Starter Profile

Default starter profile for a new or recovered state:

- active tier: `Tier1`
- unlocked tiers: `Tier1` only

Higher tiers remain locked until explicitly unlocked.

## Unlock Flow

1. player starts with starter profile;
2. progression system unlocks additional tiers over time;
3. active tier can be switched only to an unlocked tier;
4. authorization/catalog projection reflects the current progression constraints.

If a required tier is not unlocked, access is denied for tier-gated content.

## Safety and Separation Rules

- progression state is player-owned runtime/save data;
- pack metadata remains separate from player unlock state;
- invalid/unsafe objects still fail authorization, even if tier is unlocked;
- progression never bypasses category/tag safety filters.

## Persistence Expectations

Progression must survive reload by save/load services. If save data is missing or corrupted, system falls back to the safe starter profile.

## Scope Limits

v0.3 progression does not include:

- economy spending logic;
- placement/spawn execution;
- world editing;
- multiplayer synchronization.

Progression only prepares safe, gameplay-facing authorization and browsing behavior.

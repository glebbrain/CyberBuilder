# Roadmap v0.4 - Placement Wrapper Integration

## Purpose
v0.4 introduces a controlled Placement Wrapper that bridges Construction Chip authorization output to placement-capable tooling without turning CyberBuilder into a direct world editor.

## Scope Intent
The Placement Wrapper should:
- consume only validated, authorized Construction Chip entries;
- enforce existing safety boundaries from `docs/reference/SAFETY_RULES.md` and `.manager/ruls.md`;
- hand off placement actions through approved integration points (for example World Builder pathways);
- keep deterministic logs and auditable outcomes for placement requests.

## Non-Goals
v0.4 must not:
- bypass denylist/forbidden-tag safety filters;
- spawn NPCs, vehicles, quest objects, combat objects, doors, elevators, devices, or scripted objects;
- modify or delete original Night City world objects;
- replace full World Builder editing workflows.

## Planned Integration Milestones
1. **Placement request contract**
   - Define request payload for authorized object placement intent.
   - Include required metadata (object id, pack id, safety context, source authorization signature).
2. **Safety gate before handoff**
   - Re-validate category/tag safety and object authorization at handoff time.
   - Reject disabled or stale authorization entries.
3. **World Builder handoff adapter**
   - Add a narrow adapter that forwards safe placement intents to approved endpoints.
   - Keep adapter behavior deterministic and traceable.
4. **Placement result reporting**
   - Emit structured success/failure records under project-controlled output.
   - Include clear reason codes for blocked requests.

## Testing Direction
Minimum v0.4 test expectations:
- authorized safe object request passes handoff gate;
- unsafe category or forbidden tag is rejected before handoff;
- stale/missing authorization is rejected;
- repeated runs produce deterministic placement wrapper logs;
- no direct world-edit API path exists outside approved adapter.

## Exit Criteria
v0.4 is considered complete when placement handoff is safety-gated, deterministic, and strictly limited to CyberBuilder-authorized safe objects with no direct unsafe world editing.

## Actual v0.4 Validation Snapshot
- `tests/run_pack_registry_tests.lua`: fails with 1 failing test in placement removal metadata path (`placement ownership not found` in `placement_removal_service.mark_removed` test case).
- `scripts/build/clean.ps1`: passes.
- `scripts/build/build.ps1`: passes.
- rerun `scripts/build/build.ps1` (determinism check): passes.

## Actual v0.4 Limitations
- Placement wrapper remains metadata/validation focused and is not a full world editor.
- Placement/removal behavior still depends on provider integration boundaries (for example World Builder hand-off), not direct in-engine object mutation from CyberBuilder.
- Scope remains single-player safe metadata ownership tracking; multiplayer/runtime synchronization is not implemented.
- Forbidden categories/tags and original world object safety restrictions remain hard boundaries.

## Remaining Risks
- Current validation run has one failing placement-removal test, so placement removal safety assertions are not fully green in the automated suite. The failure occurs because the test registers ownership in one `placement_ownership_service` instance while `placement_removal_service` loads its own instance via internal `dofile` (see `docs/PLACEMENT_WRAPPER.md`, `docs/OWNERSHIP_RULES.md`).
- Existing tests are unit-style coverage; there is still risk in end-to-end orchestration across authorization -> wrapper -> provider hand-off.

---

Last reviewed: 2026-05-07.


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


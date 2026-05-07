# Roadmap v0.5 - Scanner Blueprint Integration

## Purpose
v0.5 explores an optional Scanner Blueprint system that discovers candidate **safe** build props for catalog hinting and blueprint preparation without enabling unsafe world interaction.

## Scope Intent
The Scanner Blueprint system should:
- discover only safety-compliant prop candidates;
- produce metadata hints and blueprint references for Construction Chip workflows;
- remain read-focused for discovery and classification rather than direct world editing;
- keep deterministic outputs for repeatable validation and review.

## Integration Focus
v0.5 integrates Scanner Blueprint outputs into CyberBuilder planning flows as optional, safety-filtered blueprint hint data.

## Non-Goals
v0.5 must not:
- scan or expose NPCs, vehicles, quest objects, combat objects, doors, elevators, devices, or scripted objects;
- bypass category allowlist and forbidden-tag safety filters;
- spawn, delete, or directly modify world objects;
- replace Construction Chip authorization or Placement Wrapper safety gates.

## Planned Integration Milestones
1. **Scanner target contract**
   - Define safe target criteria and scanner input boundaries.
   - Encode explicit denylist exclusions before any candidate output.
2. **Blueprint candidate normalization**
   - Normalize discovered candidates into deterministic blueprint records.
   - Include stable identifiers and source context for auditability.
3. **Safety validation pass**
   - Re-validate candidate category/tag eligibility against project safety rules.
   - Reject any candidate with denylist category or forbidden tags.
4. **Catalog hint export**
   - Export scanner-derived hints for optional catalog usage without auto-authorizing unsafe content.
   - Keep exports deterministic and traceable.

## Testing Direction
Minimum v0.5 test expectations:
- safe prop candidates are discovered and normalized deterministically;
- denylisted categories are always excluded from scanner output;
- forbidden-tag candidates are rejected;
- scanner output does not trigger spawn/place/delete flows;
- repeated scanner runs over identical inputs produce stable outputs.

## Exit Criteria
v0.5 is complete when Scanner Blueprint output is safety-bounded, deterministic, and usable as optional catalog hint data without violating no-unsafe-exposure or no-direct-world-edit constraints.

---

Last reviewed: 2026-05-07.

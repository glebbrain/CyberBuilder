# Roadmap v0.6 - Workshop/Crafting Integration

## Purpose
v0.6 defines a safe Workshop/Crafting integration layer that builds on validated CyberBuilder data without enabling unsafe world edits.

## Scope Intent
v0.6 should:
- integrate crafting-facing workflows with validated catalog/authorization outputs;
- keep safety gates from placement and authorization layers intact;
- preserve deterministic outputs for repeatable tests and builds.

## Non-Goals
v0.6 must not:
- bypass denylist category or forbidden-tag safety rules;
- spawn, delete, or directly edit original Night City world objects;
- include NPC, vehicle, quest, combat, or other forbidden gameplay object classes.

## Planned Integration Milestones
1. Define Workshop/Crafting input/output contract.
2. Reuse validated object eligibility from existing safety gates.
3. Add deterministic crafting metadata export for safe objects only.
4. Add validation/test coverage for safety and deterministic behavior.

## Exit Criteria
v0.6 is complete when Workshop/Crafting integration is safety-bounded, deterministic, and compatible with existing authorization and placement safety constraints.

---

Last reviewed: 2026-05-07.

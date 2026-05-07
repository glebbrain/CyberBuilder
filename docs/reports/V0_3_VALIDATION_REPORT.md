# v0.3 Validation Report

**Historical snapshot.** Reflects the repository at the time this report was written. As of 2026-05-07, the repo includes `scripts/build/clean.ps1` and Placement Wrapper v0.4; for the current v0.4 validation snapshot see `docs/roadmap/ROADMAP_v0_4.md`.

## Scope
This report documents the actual validation status, current limitations, and remaining risks for Construction Chip v0.3 based on the required CI/testing gates.

## Validation Performed
- Ran Lua test suite: `lua tests/run_pack_registry_tests.lua`.
- Ran build pipeline multiple times: `pwsh -File ./scripts/build/build.ps1` (three successful runs).
- Verified generated outputs under `dist/`:
  - `cyberbuilder_export_summary.json`
  - `cyberbuilder_errors.log`
  - `build_summary.log`
  - `build_errors.log`
  - `worldbuilder/` export folders
  - `CyberBuilderPackRegistry.zip`
- Checked package reproducibility by comparing zip SHA256 across rerun.

## Actual v0.3 Limitations
- `packs/starter_builder_gameplay/pack.json` is missing, causing pack read failure during build validation (`PACK_READ_PACK_JSON`).
- As currently authored, `starter_furniture` objects are disabled placeholders, resulting in 0 exported object paths in build output.
- Build reproducibility is partial:
  - build reruns succeed,
  - but release zip hash changes across reruns (non-deterministic package bytes).
- Build gate command list references `scripts/build/clean.ps1`, but that script does not exist in repository.

## Remaining Risks
- **Safety/quality risk:** Missing `pack.json` in `starter_builder_gameplay` keeps that pack invalid and unavailable to runtime flows.
- **Content readiness risk:** Export output currently contains no active object paths from starter content.
- **Release reproducibility risk:** Non-deterministic zip bytes can break strict reproducible-build expectations and downstream verification.
- **Process/documentation risk:** CI/testing docs mention `clean.ps1` that is absent, which can create operator confusion in validation workflows.

## Current Status Summary
- Core Construction Chip validation tests pass.
- Build pipeline executes successfully and writes expected logs/summary artifacts.
- v0.3 still has concrete packaging/content limitations that should be addressed before treating release output as fully production-ready.

---

Last reviewed: 2026-05-07.

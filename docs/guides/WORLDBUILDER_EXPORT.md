# World Builder Export Outputs (v0.2)

This document explains where CyberBuilder writes generated World Builder `.txt` files in v0.2.

## Base output folder

All generated outputs are written under project `dist/`.

World Builder export files are written under:

- `dist/worldbuilder/`

## Export file locations

### Pack-level entity export

For object type `entity`, CyberBuilder writes one file per pack:

- `dist/worldbuilder/entity/templates/cyberbuilder_<packId>.txt`

Each line is one normalized `resourcePath`.

### Pack-level mesh export

For object type `mesh`, CyberBuilder writes one file per pack:

- `dist/worldbuilder/mesh/all/cyberbuilder_<packId>.txt`

Each line is one normalized `resourcePath`.

### UI single-object export

From the catalog UI action ("Export selected to World Builder txt"), CyberBuilder writes:

- `dist/worldbuilder/selected/cyberbuilder_selected_<packId>_<objectId>.txt`

This file contains one selected normalized `resourcePath`.

## Important behavior

- Disabled objects (`disabled: true`) are skipped from normal exports.
- Duplicate paths are de-duplicated per export file.
- Paths are sorted deterministically in pack-level exports.
- Unsupported types are skipped with warning logs.

## Related files

- Export summary: `dist/cyberbuilder_export_summary.json`
- Error log: `dist/cyberbuilder_errors.log`
- Placement Wrapper hand-off and queue: `docs/WORLDBUILDER_BRIDGE.md`

---

Last reviewed: 2026-05-07.

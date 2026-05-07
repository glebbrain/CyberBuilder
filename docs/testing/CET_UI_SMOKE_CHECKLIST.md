# CET UI Smoke Checklist (v0.2)

Use this checklist for quick manual validation of the catalog UI behavior in CET.

## Preconditions

- CyberBuilder project builds successfully.
- Catalog files are generated under `dist/`.
- CET is running with CyberBuilder UI enabled.

## Smoke checklist

- [ ] Open the catalog window (hotkey/toggle).
- [ ] Confirm window renders with warning banner:
  - `CyberBuilder v0.2 does not spawn objects; use World Builder for placement.`
- [ ] Select a category from the categories list.
- [ ] Confirm object list updates for selected category.
- [ ] Select an object from the object list.
- [ ] Inspect object metadata panel and confirm values are shown:
  - `name`
  - `packId`
  - `type`
  - `price`
  - `tags`
  - `resourcePath`
- [ ] Click `Copy resourcePath` and confirm clipboard copy works or fallback log appears.
- [ ] Click `Export selected to World Builder txt`.
- [ ] Confirm output file is created under:
  - `dist/worldbuilder/selected/`
- [ ] Open created file and confirm selected `resourcePath` is written.

## Optional quick checks

- [ ] Verify empty-state messages appear when expected.
- [ ] Verify validation error panel shows latest lines from `dist/cyberbuilder_errors.log`.

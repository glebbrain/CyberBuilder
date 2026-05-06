# CyberBuilder Pack Registry (MVP)

CyberBuilder is a small **pack registry** for Cyberpunk 2077 modding: modders define buildable content in JSON (`pack.json`, `objects.json`, `recipes.json`), the tool **validates** those files, and **exports** resource paths into formats compatible with **World Builder** spawnable lists. It does not place objects in the game world by itself.

## Dependency on World Builder

**World Builder** (or an equivalent workflow that consumes the exported `.txt` spawnable lists) is the layer where objects are spawned, previewed, and edited in the world. CyberBuilder only prepares validated, grouped paths for that tool. You need a working World Builder setup to use the exports as intended.

## Non-goals (this MVP)

CyberBuilder **does not**:

- spawn, scan, delete, or modify objects in the live game world
- implement crafting UI, disassembly gun, quests, NPCs, vehicles, or economy
- replace World Builder’s in-world editing

Invalid packs are skipped so they do not break the rest of the registry; see the project `TODO.md` and `.manager/` docs for acceptance criteria and testing expectations.

## Setup Links

- Install flow and automation scripts: `docs/INSTALL.md`
- Script map and command examples: `scripts/install/README.md`
- World Builder: [Nexus Mods](https://www.nexusmods.com/cyberpunk2077/mods/20660)
- RED4ext: [GitHub Releases](https://github.com/WopsS/RED4ext/releases)
- CET: [GitHub Releases](https://github.com/yamashi/CyberEngineTweaks/releases)

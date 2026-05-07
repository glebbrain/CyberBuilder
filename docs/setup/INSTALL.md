# Install Guide (Windows + macOS)

CyberBuilder Pack Registry and its World Builder export path assume:

1. a **modded Cyberpunk 2077** stack (for in-game usage), and
2. a working **CyberBuilder runtime** (Lua) to validate/export packs.

Use this guide to understand what is installed, in what order, and which script to run per OS.

## What gets installed

### 1) CP2077 mod stack (required for in-game usage)

| Component | Role |
|-----------|------|
| **RED4ext** | Native script extension runtime used by many CP2077 mods. |
| **CET** (Cyber Engine Tweaks) | In-game console and scripting surface used by many workflows. |
| **Codeware** | Library layer commonly required alongside redscript/RED4ext stacks. |
| **redscript** | Redscript compiler/runtime for game script mods. |
| **ArchiveXL** | Archive extension for custom assets and related mod patterns. |
| **TweakXL** | Tweak/db extension used with many modern CP2077 mods. |
| **World Builder** | In-world spawning/editing layer that consumes spawnable list exports from this MVP. |
| **WolvenKit** | External modding toolkit for archive/content workflows. |

### 2) CyberBuilder runtime (required to run this repo)

| Component | Role |
|-----------|------|
| **Lua 5.x** | Runs `src/cyber_builder/init.lua` and tests. |
| **LuaFileSystem (`lfs`)** | Recommended; required for pack discovery on non-Windows fallback paths in current implementation. |

## Install sequence

Run in this order:

1. **Prerequisites check** (`Install-CyberBuilderPrereqs.*`)  
   Detects Cyberpunk 2077, creates a backup of mod hotspots (unless disabled), attempts auto-install for GitHub-hosted stack components, and enforces strict full-stack verification by default.
2. **CyberBuilder install/check** (`Install-CyberBuilder.ps1`)  
   Ensures Lua is available, optionally installs `lfs`, and runs `lua src/cyber_builder/init.lua --dry-run`.

The orchestration scripts in the install root already follow this sequence.

## Script map

### Root orchestrators

- `scripts/install/Silent/Install-CyberBuilder-Silent.ps1`  
  Cross-platform PowerShell orchestrator. Detects OS and runs the correct platform scripts in sequence.
- `scripts/install/Silent/Install-CyberBuilder-Silent.sh`  
  macOS shell orchestrator (`Darwin` only). Runs macOS prerequisite script, then macOS PowerShell installer via `pwsh`.

### Platform scripts

- `scripts/install/Windows10x64/Install-CyberBuilderPrereqs.ps1`
- `scripts/install/Windows10x64/Install-CyberBuilder.ps1`
- `scripts/install/Windows11x64/Install-CyberBuilderPrereqs.ps1`
- `scripts/install/Windows11x64/Install-CyberBuilder.ps1`
- `scripts/install/MacOS/Install-CyberBuilderPrereqs.sh`
- `scripts/install/MacOS/Install-CyberBuilder.ps1`

## Quick start commands

### Dependency helper scripts

Use these root-level helpers when you only want dependency checks/install flow:

- `scripts/install/check-deps.ps1`
- `scripts/install/install-deps.ps1`

### Windows (recommended)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\install\Silent\Install-CyberBuilder-Silent.ps1
```

Allow dependency installation attempts (Lua / CET / luarocks / lfs when available):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\install\Silent\Install-CyberBuilder-Silent.ps1 -InstallDeps
```

### macOS (shell entrypoint)

```bash
./scripts/install/Silent/Install-CyberBuilder-Silent.sh
```

Allow dependency installation attempts:

```bash
./scripts/install/Silent/Install-CyberBuilder-Silent.sh --install-deps
```

## Common options

### PowerShell orchestrator (`Install-CyberBuilder-Silent.ps1`)

- `-Mode All|Prereqs|CyberBuilder`
- `-InstallDeps`
- `-InstallCET`
- `-StrictInstall` (default: enabled)
- `-PauseForManualInstall` (wait for manual World Builder step before final verification)
- `-SkipDryRun`
- Windows-only: `-GamePath`, `-SteamAppsCommonPaths`, `-BackupRoot`, `-NoBackupBeforeInstall`

### macOS shell orchestrator (`Install-CyberBuilder-Silent.sh`)

- `--mode all|prereqs|cyberbuilder`
- `--install-deps`
- `--install-cet`
- `--strict-install` / `--no-strict-install` (default: strict enabled)
- `--pause-for-manual-install`
- `--skip-dry-run`
- `--repo-root <path>`
- `--game-path <path>`
- `--backup-root <path>`
- `--no-backup-before-install`

## Notes and boundaries

- Exact mod install order and version compatibility follow each upstream project README (especially RED4ext + redscript vs game patch).
- Prereqs scripts now run in strict mode by default: if any required component is still missing after install attempts, script exits with non-zero code.
- `World Builder` remains a semi-manual Nexus step; strict mode requires it to be present at final verification.
- `WolvenKit` is auto-attempted in strict mode (winget first, then GitHub zip fallback to `%LOCALAPPDATA%\\WolvenKit`).
- You can place package payloads in `distr`; prereqs scripts process all `distr` subfolders and `.zip` archives, install missing files, update older files, and skip conflicting files safely.
- CyberBuilder MVP **does not** replace game mod dependencies; it validates JSON packs and exports World Builder-oriented outputs.
- Dependency installation is opt-in: pass `-InstallDeps` / `--install-deps` (or use `Fresh` mode) to allow Lua/LuaRocks/lfs install attempts.
- Linux is currently unsupported by install orchestrators in this repository.

---

Last reviewed: 2026-05-07.

# Install Scripts Overview

This folder contains automation scripts for setting up CyberBuilder prerequisites and the CyberBuilder runtime across supported OS targets.

## Install behavior (new)

CyberBuilder install scripts now use a unified behavior on all supported OS targets:

- **Check** what is already installed (`lua`, optional `lfs` toolchain).
- **Install missing** dependencies.
- **Update outdated** dependencies (best effort via package managers).
- **Best-effort CET install** when `InstallCET`/`--install-cet` is requested (or with fresh mode in orchestrators).
- **Backup mod-touched game files by default before install** (can be disabled with explicit `NoBackupBeforeInstall` flags in script-specific options).
- **Dependency installation is opt-in**: use `-InstallDeps` / `--install-deps` (or `Fresh` mode) to allow Lua/LuaRocks/lfs install attempts.
- `lfs` install now prefers GitHub source (`lunarmodules/luafilesystem` rockspec) with LuaRocks registry fallback.
- Windows `lfs` build path now also tries to install MinGW-w64 (`x86_64-w64-mingw32-gcc`) from GitHub releases (`xpack-dev-tools/mingw-w64-gcc-xpack`) before package-manager fallback.
- **Prereqs strict mode is enabled by default**: prereqs scripts attempt full mod-stack installation (GitHub components auto, Nexus World Builder semi-manual) and fail with non-zero exit if any required component is missing.
- In Windows strict mode, `WolvenKit` install is auto-attempted via `winget`, then via GitHub zip fallback to `%LOCALAPPDATA%\\WolvenKit`.
- Missing payloads can be dropped into `distr` (for example `distr\\World Builder`); prereqs scripts scan all `distr` subfolders and `.zip` archives, install missing files, update older files, and skip conflicts safely.

They also support two install strategies:

- **Overlay** (default): install/update in place (safe default).
- **Fresh**: force reinstall/update attempts from scratch.

## Execution order

Use this order for a full setup:

1. **Prereqs check** (`Install-CyberBuilderPrereqs.*`)  
   Detects Cyberpunk 2077 location and reports heuristic presence of required mod stack components.
2. **CyberBuilder install/check** (`Install-CyberBuilder.ps1`)  
   Ensures Lua runtime is available, optionally installs extra dependencies, and runs a CyberBuilder dry-run.

Root orchestrators already follow this sequence automatically.

## Script map

### Root orchestrators

- `Install-CyberBuilder-Silent.ps1`  
  PowerShell orchestrator that auto-detects OS and routes to platform scripts.
- `Install-CyberBuilder-Silent.sh`  
  macOS shell orchestrator (Darwin only), then calls macOS PowerShell installer via `pwsh`.
- `Install-CyberBuilder-WithBackup.ps1`  
  PowerShell wrapper that enforces backup first, then runs install.
- `Install-CyberBuilder-WithBackup.sh`  
  macOS shell wrapper that enforces backup first, then runs install via `pwsh`.

### Windows 10 x64

- `Windows10x64/Install-CyberBuilderPrereqs.ps1`
- `Windows10x64/Install-CyberBuilder.ps1`

### Windows 11 x64

- `Windows11x64/Install-CyberBuilderPrereqs.ps1`
- `Windows11x64/Install-CyberBuilder.ps1`

### macOS

- `MacOS/Install-CyberBuilderPrereqs.sh`
- `MacOS/Install-CyberBuilder.ps1`

## What each install script does

- `Silent/Install-CyberBuilder-Silent.ps1` and `Silent/Install-CyberBuilder-Silent.sh`  
  Orchestrate end-to-end install flow (prereqs phase then CyberBuilder runtime phase) with OS-aware routing.
- `Install-CyberBuilder-WithBackup.ps1` and `Install-CyberBuilder-WithBackup.sh`  
  Wrapper entrypoints that enforce backup-first behavior before running install flow.
- `Windows10x64/Install-CyberBuilderPrereqs.ps1` and `Windows11x64/Install-CyberBuilderPrereqs.ps1`  
  Check/install CP2077 mod-stack prerequisites and verify required components.
- `Windows10x64/Install-CyberBuilder.ps1`, `Windows11x64/Install-CyberBuilder.ps1`, and `MacOS/Install-CyberBuilder.ps1`  
  Validate CyberBuilder runtime prerequisites (Lua and optional lfs toolchain) and run dry-run checks.
- `MacOS/Install-CyberBuilderPrereqs.sh`  
  macOS prereqs checker/installer for CP2077 mod-stack dependencies.

## What install scripts must not modify

- Must not modify original game executable files or base game archives.
- Must not modify quest/NPC/vehicle/world state or spawn/place/delete game objects.
- Must not write outside this repo except:
  - explicit game/mod directories selected for dependency installation, and
  - backup targets configured by backup options.
- Must not overwrite existing plugin folders without backup-first behavior or explicit opt-out flags.

## Quick commands

### Windows (recommended entrypoint)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\install\Silent\Install-CyberBuilder-Silent.ps1
```

Force fresh reinstall mode:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\install\Silent\Install-CyberBuilder-Silent.ps1 -InstallMode Fresh
```

Install CET during prereqs phase:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\install\Silent\Install-CyberBuilder-Silent.ps1 -InstallCET
```

Install with mandatory backup:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\install\Install-CyberBuilder-WithBackup.ps1
```

Disable backup explicitly (not recommended):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\install\Silent\Install-CyberBuilder-Silent.ps1 -NoBackupBeforeInstall
```

### macOS (shell entrypoint)

```bash
./scripts/install/Silent/Install-CyberBuilder-Silent.sh
```

Force fresh reinstall mode:

```bash
./scripts/install/Silent/Install-CyberBuilder-Silent.sh --install-mode fresh
```

Install CET during prereqs phase:

```bash
./scripts/install/Silent/Install-CyberBuilder-Silent.sh --install-cet
```

Install with mandatory backup:

```bash
./scripts/install/Install-CyberBuilder-WithBackup.sh
```

Disable backup explicitly (not recommended):

```bash
./scripts/install/Silent/Install-CyberBuilder-Silent.sh --no-backup-before-install
```

### Direct platform scripts (disable backup)

Windows 10/11 prereqs:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\install\Windows10x64\Install-CyberBuilderPrereqs.ps1 -NoBackupBeforeInstall
```

macOS prereqs:

```bash
./scripts/install/MacOS/Install-CyberBuilderPrereqs.sh --no-backup-before-install
```

## CI / automation examples

### Windows CI runner

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\install\Silent\Install-CyberBuilder-Silent.ps1 -Mode CyberBuilder -InstallMode Overlay
```

### macOS CI runner

```bash
./scripts/install/Silent/Install-CyberBuilder-Silent.sh --mode cyberbuilder --install-mode overlay
```

### Validation-only (no forced reinstall)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\install\Silent\Install-CyberBuilder-Silent.ps1 -Mode CyberBuilder
```

```bash
./scripts/install/Silent/Install-CyberBuilder-Silent.sh --mode cyberbuilder
```

## Important notes

- Prerequisite detection is heuristic; "not detected" can still be valid in some mod manager layouts.
- In strict prereqs mode, unresolved components become hard failures after install attempts and final verification.
- Version compatibility for RED4ext / redscript must match the installed game patch.
- Dependency updates are best effort and depend on available package managers (`winget`, `brew`, `luarocks`).
- LuaFileSystem source: [lunarmodules/luafilesystem](https://github.com/lunarmodules/luafilesystem).
- CyberBuilder scripts do not replace upstream mod installers; they orchestrate checks and local runtime readiness.
- Linux is currently unsupported by these install orchestrators; use Windows/macOS scripts or run runtime steps manually.

## Official component links

- RED4ext: [GitHub Releases](https://github.com/WopsS/RED4ext/releases)
- CET: [GitHub Releases](https://github.com/yamashi/CyberEngineTweaks/releases)
- Codeware: [GitHub Releases](https://github.com/psiberx/cp2077-codeware/releases)
- redscript: [GitHub Releases](https://github.com/jac3km4/redscript/releases)
- ArchiveXL: [GitHub Releases](https://github.com/psiberx/cp2077-archive-xl/releases)
- TweakXL: [GitHub Releases](https://github.com/psiberx/cp2077-tweak-xl/releases)
- World Builder: [Nexus Mods](https://www.nexusmods.com/cyberpunk2077/mods/20660)
- WolvenKit: [GitHub Releases](https://github.com/WolvenKit/WolvenKit/releases)

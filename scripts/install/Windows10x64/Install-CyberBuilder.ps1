<#
.SYNOPSIS
    Install/check CyberBuilder (Lua runtime + optional LuaFileSystem) on Windows and run a self-test.

.DESCRIPTION
    CyberBuilder is a Lua project. Minimal requirement: `lua` on PATH.
    Optional but recommended on non-Windows platforms: LuaFileSystem (`lfs`) via LuaRocks.

    This script:
      - checks whether `lua` is available
      - optionally installs Lua via winget (if available)
      - optionally installs LuaRocks + luafilesystem (lfs)
      - runs `lua src/cyber_builder/init.lua --dry-run` from repo root

.PARAMETER RepoRoot
    Path to CyberBuilder repository root. Defaults to auto-detected from this script location.

.PARAMETER InstallLua
    Attempt to install Lua (uses winget when available; otherwise opens Lua download page).

.PARAMETER InstallLfs
    Attempt to install LuaRocks and then `luarocks install luafilesystem` (best-effort).

.PARAMETER DryRun
    Run CyberBuilder self-test using `--dry-run` (default: true).

.PARAMETER SkipDryRun
    Convenience flag to skip the self-test (sets -DryRun:$false).

.PARAMETER OpenLinks
    Open documentation/download links in the browser.

.PARAMETER InstallMode
    Installation strategy:
      - Overlay (default): install missing dependencies and update outdated ones in place.
      - Fresh: force a from-scratch reinstall attempt (still non-destructive to repo files).

.PARAMETER GamePath
    Optional explicit CP2077 game root passed to prereqs backup/check script.

.PARAMETER SteamAppsCommonPaths
    Optional extra steamapps/common roots for prereqs backup/check script.

.PARAMETER BackupRoot
    Optional backup parent folder for prereqs backup/check script.

.PARAMETER NoBackupBeforeInstall
    Disable automatic pre-install backup (enabled by default).

.PARAMETER InstallCET
    Attempt CET install via prereqs script before Lua validation.

.EXAMPLE
    .\Install-CyberBuilder.ps1

.EXAMPLE
    .\Install-CyberBuilder.ps1 -InstallLua -InstallLfs
#>

#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string] $RepoRoot,

    [switch] $InstallLua,

    [switch] $InstallLfs,

    [Parameter(Mandatory = $false)]
    [bool] $DryRun = $true,

    [switch] $SkipDryRun,

    [switch] $OpenLinks,

    [ValidateSet('Overlay', 'Fresh')]
    [string] $InstallMode = 'Overlay',

    [string] $GamePath,

    [string[]] $SteamAppsCommonPaths,

    [string] $BackupRoot,

    [switch] $NoBackupBeforeInstall,

    [switch] $InstallCET
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-RepoRootFromScript {
    $here = Split-Path -Parent $PSCommandPath
    # docs/scripts/install/Windows10 -> repo root = ../../../..
    $root = Resolve-Path -LiteralPath (Join-Path $here '..\..\..\..')
    return $root.Path
}

function Test-Command {
    param([Parameter(Mandatory = $true)][string] $Name)
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    return [bool] $cmd
}

function Test-IsAdministrator {
    try {
        $id = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($id)
        return $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
    } catch {
        return $false
    }
}

function Resolve-LuaExecutable {
    if ($GamePath) {
        $gp = $GamePath.TrimEnd('\', '/')
        $cetRoot = Join-Path $gp 'bin\x64\plugins\cyber_engine_tweaks'
        if (Test-Path -LiteralPath $cetRoot) {
            $luaBin = Get-ChildItem -Path $cetRoot -Recurse -Filter "lua*.exe" -File -ErrorAction SilentlyContinue |
                Select-Object -First 1
            if ($luaBin) {
                return $luaBin.FullName
            }
        }
    }

    $pathCmd = Get-Command lua -ErrorAction SilentlyContinue
    if ($pathCmd) {
        return $pathCmd.Source
    }

    $scoopCandidates = @(
        (Join-Path $env:USERPROFILE 'scoop\shims\lua.exe'),
        (Join-Path $env:USERPROFILE 'scoop\apps\lua\current\lua.exe'),
        (Join-Path $env:USERPROFILE 'scoop\apps\lua\current\bin\lua.exe')
    )
    foreach ($candidate in $scoopCandidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate)) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    $cetRoots = @(
        "C:\Program Files (x86)\Steam\steamapps\common\Cyberpunk 2077\bin\x64\plugins\cyber_engine_tweaks",
        "D:\SteamLibrary\steamapps\common\Cyberpunk 2077\bin\x64\plugins\cyber_engine_tweaks",
        "E:\SteamLibrary\steamapps\common\Cyberpunk 2077\bin\x64\plugins\cyber_engine_tweaks",
        "F:\SteamLibrary\steamapps\common\Cyberpunk 2077\bin\x64\plugins\cyber_engine_tweaks",
        "G:\SteamLibrary\steamapps\common\Cyberpunk 2077\bin\x64\plugins\cyber_engine_tweaks",
        "G:\GameHub\Steam\steamapps\common\Cyberpunk 2077\bin\x64\plugins\cyber_engine_tweaks"
    )
    foreach ($root in $cetRoots) {
        if (-not (Test-Path -LiteralPath $root)) { continue }
        $luaBin = Get-ChildItem -Path $root -Recurse -Filter "lua*.exe" -File -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if ($luaBin) {
            return $luaBin.FullName
        }
    }
    return $null
}

function Invoke-OpenUrl {
    param([Parameter(Mandatory = $true)][string] $Url)
    try { Start-Process $Url | Out-Null } catch { }
}

function Invoke-PreInstallBackup {
    if ($NoBackupBeforeInstall) {
        Write-Host 'Pre-install backup disabled by -NoBackupBeforeInstall.' -ForegroundColor DarkGray
        return
    }

    $scriptDir = Split-Path -Parent $PSCommandPath
    $prereqsScript = Join-Path $scriptDir 'Install-CyberBuilderPrereqs.ps1'
    if (-not (Test-Path -LiteralPath $prereqsScript)) {
        throw "Missing prereqs script: $prereqsScript"
    }

    $args = @()
    if ($GamePath) { $args += @('-GamePath', $GamePath) }
    if ($SteamAppsCommonPaths) {
        $args += @('-SteamAppsCommonPaths')
        $args += $SteamAppsCommonPaths
    }
    if ($BackupRoot) { $args += @('-BackupRoot', $BackupRoot) }
    if ($InstallCET -or $InstallMode -eq 'Fresh') { $args += @('-InstallCET') }

    Write-Host 'Running pre-install backup/check...' -ForegroundColor Cyan
    & powershell -NoProfile -ExecutionPolicy Bypass -File $prereqsScript @args
    if ($LASTEXITCODE -ne 0) {
        throw "Pre-install backup/check failed ($LASTEXITCODE)."
    }
}

function Get-LuaVersion {
    param(
        [string] $LuaExe
    )
    try {
        if (-not $LuaExe) { return $null }
        $v = (& $LuaExe -v) 2>&1
        if (-not $v) { return $null }
        $text = ($v | Out-String)
        $m = [regex]::Match($text, 'Lua\s+(\d+)\.(\d+)(?:\.(\d+))?')
        if (-not $m.Success) { return $null }
        $maj = [int]$m.Groups[1].Value
        $min = [int]$m.Groups[2].Value
        $pat = if ($m.Groups[3].Success) { [int]$m.Groups[3].Value } else { 0 }
        return [version]::new($maj, $min, $pat)
    } catch {
        return $null
    }
}

function Install-OrUpdateLua {
    if (Test-Command -Name 'winget') {
        Write-Host 'Installing/updating Lua via winget...' -ForegroundColor Cyan
        try {
            winget install --id Lua.Lua --source winget --accept-package-agreements --accept-source-agreements
        } catch {
            try {
                winget upgrade --id Lua.Lua --source winget --accept-package-agreements --accept-source-agreements
            } catch {
                Write-Host 'winget could not install/upgrade Lua.' -ForegroundColor Yellow
            }
        }
    } elseif (Test-Command -Name 'scoop') {
        Write-Host 'Installing/updating Lua via Scoop...' -ForegroundColor Cyan
        try {
            scoop install lua
        } catch {
            try {
                scoop update lua
            } catch {
                Write-Host 'Scoop could not install/update Lua.' -ForegroundColor Yellow
            }
        }
    } elseif (Test-Command -Name 'choco') {
        if (-not (Test-IsAdministrator)) {
            Write-Host 'Chocolatey detected but current shell is not elevated; skipping choco install attempt.' -ForegroundColor Yellow
        } else {
            Write-Host 'Installing/updating Lua via Chocolatey...' -ForegroundColor Cyan
            try {
                choco upgrade lua --yes --no-progress --limit-output
            } catch {
                try {
                    choco install lua --yes --no-progress --limit-output
                } catch {
                    Write-Host 'Chocolatey could not install/upgrade Lua.' -ForegroundColor Yellow
                }
            }
        }
    } else {
        Write-Host 'No supported package manager found (winget/choco/scoop); cannot auto-install Lua on this host.' -ForegroundColor Yellow
        Invoke-OpenUrl -Url $links['Lua downloads']
    }
}

$links = [ordered]@{
    'Lua downloads' = 'https://www.lua.org/download.html'
    'LuaRocks'      = 'https://luarocks.org/'
}

if (-not $RepoRoot) {
    $RepoRoot = Resolve-RepoRootFromScript
}

if ($SkipDryRun) {
    $DryRun = $false
}

Invoke-PreInstallBackup

if ($OpenLinks) {
    foreach ($k in $links.Keys) {
        Write-Host "Opening: $k -> $($links[$k])"
        Invoke-OpenUrl -Url $links[$k]
    }
}

$luaExe = Resolve-LuaExecutable
$recommendedLua = [version]::new(5, 4, 0)
$luaVersion = Get-LuaVersion -LuaExe $luaExe
$luaMissing = -not $luaExe
$luaOutdated = $false
if ($luaVersion -and $luaVersion -lt $recommendedLua) {
    $luaOutdated = $true
}

if ($luaMissing -or $luaOutdated -or $InstallMode -eq 'Fresh') {
    if ($luaMissing) {
        Write-Host 'Lua is not installed (or not on PATH).' -ForegroundColor Yellow
    } elseif ($luaOutdated) {
        Write-Host ("Lua version {0} is older than recommended {1}." -f $luaVersion, $recommendedLua) -ForegroundColor Yellow
    } else {
        Write-Host 'InstallMode=Fresh: forcing Lua reinstall/upgrade attempt.' -ForegroundColor Yellow
    }

    if ($InstallLua -or $InstallMode -eq 'Fresh') {
        Install-OrUpdateLua
        $luaExe = Resolve-LuaExecutable
        $luaVersion = Get-LuaVersion -LuaExe $luaExe
        $luaMissing = -not $luaExe
    }
}

if (-not $luaExe) {
    throw 'Lua is required. Aborting.'
}

Write-Host ('Lua found: {0}' -f $luaExe) -ForegroundColor Green

if ($InstallLfs -or $InstallMode -eq 'Fresh') {
    if (-not (Test-Command -Name 'luarocks')) {
        Write-Host 'LuaRocks not found. Please install LuaRocks, then rerun.' -ForegroundColor Yellow
        Write-Host ("  Link: {0}" -f $links['LuaRocks']) -ForegroundColor DarkGray
    } else {
        Write-Host 'Installing/updating luafilesystem (lfs) via luarocks...' -ForegroundColor Cyan
        try {
            luarocks install luafilesystem
        } catch {
            try {
                luarocks update luafilesystem
            } catch {
                Write-Host 'luarocks failed to install/update luafilesystem. You may need a compiler toolchain for your Lua build.' -ForegroundColor Yellow
            }
        }
    }
}

Write-Host 'Checking LuaFileSystem (lfs) availability...' -ForegroundColor Cyan
$lfsOk = $false
try {
    & $luaExe -e "local ok = pcall(require, 'lfs'); if ok then os.exit(0) else os.exit(2) end" | Out-Null
    if ($LASTEXITCODE -eq 0) { $lfsOk = $true }
} catch { }
Write-Host ("lfs available = {0}" -f $lfsOk) -ForegroundColor $(if ($lfsOk) { 'Green' } else { 'DarkYellow' })

if (-not (Test-Path -LiteralPath (Join-Path $RepoRoot 'src\cyber_builder\init.lua'))) {
    throw "RepoRoot does not look like CyberBuilder: missing src\\cyber_builder\\init.lua at $RepoRoot"
}

if ($DryRun) {
    Write-Host 'Running CyberBuilder self-test (--dry-run)...' -ForegroundColor Cyan
    Push-Location $RepoRoot
    try {
        & $luaExe 'src/cyber_builder/init.lua' '--dry-run'
        if ($LASTEXITCODE -ne 0) { throw "CyberBuilder dry-run failed (exit code $LASTEXITCODE)" }
    } finally {
        Pop-Location
    }
    Write-Host 'CyberBuilder dry-run completed.' -ForegroundColor Green
} else {
    Write-Host 'DryRun disabled; skipping self-test.' -ForegroundColor DarkGray
}


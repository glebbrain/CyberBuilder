<#
.SYNOPSIS
    Silent installer/orchestrator for CyberBuilder docs scripts.

.DESCRIPTION
    Detects OS, selects the appropriate platform scripts under docs/scripts/install/*,
    and runs them in the intended order:
      1) prerequisite check for CP2077 mod stack (optional / heuristic)
      2) CyberBuilder install/check (Lua runtime + optional lfs) + self-test (dry-run)

    This script is designed to be non-interactive by default:
      - no browser tabs
      - best-effort package manager usage only when explicitly enabled

.PARAMETER Mode
    What to do:
      - All       : run prereqs check then install/check CyberBuilder (default)
      - Prereqs   : run only prereqs check
      - CyberBuilder : run only CyberBuilder install/check

.PARAMETER InstallDeps
    If set, the orchestrator will allow platform scripts to attempt installing dependencies
    using the platform package manager when available (winget / brew / luarocks).

.PARAMETER InstallCET
    Attempt CET install during prereqs step.

.PARAMETER GamePath
    Windows-only: explicit Cyberpunk 2077 game root for prereqs checker.

.PARAMETER SteamAppsCommonPaths
    Windows-only: extra steamapps/common roots for game detection (repeatable).

.PARAMETER NoBackupBeforeInstall
    Disable backup mode for prereqs checker (backup is enabled by default).

.PARAMETER BackupRoot
    Windows-only: backup parent folder.

.PARAMETER RepoRoot
    Explicit repo root to run CyberBuilder self-test from.
    Default auto-detect based on this script location.

.PARAMETER SkipDryRun
    Skip CyberBuilder self-test.

.PARAMETER InstallMode
    Installation strategy for platform installers:
      - Overlay (default): install/update in place.
      - Fresh: force reinstall attempts from scratch.

.EXAMPLE
    # Default: silent checks + dry-run self-test
    powershell -NoProfile -ExecutionPolicy Bypass -File .\docs\scripts\install\Install-CyberBuilder-Silent.ps1

.EXAMPLE
    # Allow installing Lua/lfs (best-effort) + run all steps
    powershell -NoProfile -ExecutionPolicy Bypass -File .\docs\scripts\install\Install-CyberBuilder-Silent.ps1 -InstallDeps
#>

#Requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet('All', 'Prereqs', 'CyberBuilder')]
    [string] $Mode = 'All',

    [switch] $InstallDeps,

    [switch] $InstallCET,

    [Parameter(Mandatory = $false)]
    [string] $GamePath,

    [Parameter(Mandatory = $false)]
    [string[]] $SteamAppsCommonPaths,

    [switch] $NoBackupBeforeInstall,

    [Parameter(Mandatory = $false)]
    [string] $BackupRoot,

    [Parameter(Mandatory = $false)]
    [string] $RepoRoot,

    [switch] $SkipDryRun,

    [ValidateSet('Overlay', 'Fresh')]
    [string] $InstallMode = 'Overlay'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-RepoRootFromHere {
    $here = Split-Path -Parent $PSCommandPath
    # docs/scripts/install -> repo root = ../../..
    $root = Resolve-Path -LiteralPath (Join-Path $here '..\..\..')
    return $root.Path
}

function Is-OS {
    param([Parameter(Mandatory = $true)][ValidateSet('Windows','MacOS','Linux')] [string] $Name)
    try {
        $rt = [System.Runtime.InteropServices.RuntimeInformation]
        switch ($Name) {
            'Windows' { return $rt::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows) }
            'MacOS'   { return $rt::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::OSX) }
            'Linux'   { return $rt::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Linux) }
        }
    } catch {
        # Fallback for older hosts: assume Windows when env var is present
        if ($Name -eq 'Windows') { return [bool] $env:WINDIR }
        return $false
    }
    return $false
}

function Get-WindowsMajorFlavor {
    try {
        $cv = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction Stop
        $build = 0
        [void][int]::TryParse(($cv.CurrentBuildNumber | ForEach-Object { "$_" }), [ref] $build)
        if ($build -ge 22000) { return 'Windows11x64' }
        return 'Windows10x64'
    } catch {
        return 'Windows10x64'
    }
}

function Invoke-ChildScript {
    param(
        [Parameter(Mandatory = $true)][string] $Path,
        [Parameter(Mandatory = $false)][string[]] $ArgList = @()
    )
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Missing script: $Path"
    }
    Write-Host ("-> {0}" -f $Path) -ForegroundColor Cyan
    & powershell -NoProfile -ExecutionPolicy Bypass -File $Path @ArgList
    if ($LASTEXITCODE -ne 0) {
        throw "Child script failed ($LASTEXITCODE): $Path"
    }
}

if (-not $RepoRoot) {
    $RepoRoot = Resolve-RepoRootFromHere
}

$silentRoot = Split-Path -Parent $PSCommandPath
$installRoot = Split-Path -Parent $silentRoot
$prereqsRan = $false

if (Is-OS -Name 'Windows') {
    $flavor = Get-WindowsMajorFlavor
    $winDir = Join-Path $installRoot $flavor

    if ($Mode -eq 'All' -or $Mode -eq 'Prereqs') {
        $pr = Join-Path $winDir 'Install-CyberBuilderPrereqs.ps1'
        $prArgList = @()
        if ($GamePath) { $prArgList += @('-GamePath', $GamePath) }
        if ($SteamAppsCommonPaths) {
            # repeatable string[] param
            $prArgList += @('-SteamAppsCommonPaths')
            $prArgList += $SteamAppsCommonPaths
        }
        if ($NoBackupBeforeInstall) { $prArgList += @('-NoBackupBeforeInstall') }
        if ($BackupRoot) { $prArgList += @('-BackupRoot', $BackupRoot) }
        if ($InstallCET -or $InstallMode -eq 'Fresh') { $prArgList += @('-InstallCET') }
        Invoke-ChildScript -Path $pr -ArgList $prArgList
        $prereqsRan = $true
    }

    if ($Mode -eq 'All' -or $Mode -eq 'CyberBuilder') {
        $cb = Join-Path $winDir 'Install-CyberBuilder.ps1'
        $cbArgList = @('-RepoRoot', $RepoRoot, '-InstallMode', $InstallMode)
        if ($prereqsRan) { $cbArgList += @('-NoBackupBeforeInstall') }
        if ($GamePath) { $cbArgList += @('-GamePath', $GamePath) }
        if ($BackupRoot) { $cbArgList += @('-BackupRoot', $BackupRoot) }
        if ($InstallCET -or $InstallMode -eq 'Fresh') { $cbArgList += @('-InstallCET') }
        if ($SteamAppsCommonPaths) {
            $cbArgList += @('-SteamAppsCommonPaths')
            $cbArgList += $SteamAppsCommonPaths
        }
        if ($SkipDryRun) { $cbArgList += @('-SkipDryRun') }
        if ($InstallDeps -or $InstallMode -eq 'Fresh') { $cbArgList += @('-InstallLua', '-InstallLfs') }
        Invoke-ChildScript -Path $cb -ArgList $cbArgList
    }

    Write-Host 'Done.' -ForegroundColor Green
    exit 0
}

if (Is-OS -Name 'MacOS') {
    # Prefer pwsh host already running this file; call local macOS pwsh script for CyberBuilder.
    $macDir = Join-Path $installRoot 'MacOS'

    if ($Mode -eq 'All' -or $Mode -eq 'Prereqs') {
        $sh = Join-Path $macDir 'Install-CyberBuilderPrereqs.sh'
        if (Test-Path -LiteralPath $sh) {
            # Best effort: requires bash + python3 for Steam VDF parsing
            if (Get-Command bash -ErrorAction SilentlyContinue) {
                Write-Host ("-> {0}" -f $sh) -ForegroundColor Cyan
                $prArgs = @()
                if ($NoBackupBeforeInstall) { $prArgs += @('--no-backup-before-install') }
                if ($BackupRoot) { $prArgs += @('--backup-root', $BackupRoot) }
                if ($GamePath) { $prArgs += @('--game-path', $GamePath) }
                if ($InstallCET -or $InstallMode -eq 'Fresh') { $prArgs += @('--install-cet') }
                & bash $sh @prArgs
                if ($LASTEXITCODE -ne 0) {
                    throw "Prereqs script failed ($LASTEXITCODE): $sh"
                }
                $prereqsRan = $true
            } else {
                Write-Host 'bash not found; skipping macOS prereqs script.' -ForegroundColor Yellow
            }
        }
    }

    if ($Mode -eq 'All' -or $Mode -eq 'CyberBuilder') {
        $cb = Join-Path $macDir 'Install-CyberBuilder.ps1'
        if (-not (Test-Path -LiteralPath $cb)) {
            throw "Missing macOS CyberBuilder script: $cb"
        }
        $cbArgs = @{
            RepoRoot  = $RepoRoot
            OpenLinks = $false
            InstallMode = $InstallMode
        }
        if ($SkipDryRun) { $cbArgs['SkipDryRun'] = $true }
        if ($prereqsRan) { $cbArgs['NoBackupBeforeInstall'] = $true }
        if ($GamePath) { $cbArgs['GamePath'] = $GamePath }
        if ($BackupRoot) { $cbArgs['BackupRoot'] = $BackupRoot }
        if ($InstallCET -or $InstallMode -eq 'Fresh') { $cbArgs['InstallCET'] = $true }
        if ($InstallDeps -or $InstallMode -eq 'Fresh') {
            $cbArgs['InstallLua'] = $true
            $cbArgs['InstallLfs'] = $true
        }
        # Use current host powershell if it's pwsh; otherwise just invoke pwsh if available.
        if ($PSVersionTable.PSEdition -eq 'Core') {
            & $cb @cbArgs
            if ($LASTEXITCODE -ne 0) { throw "Child script failed ($LASTEXITCODE): $cb" }
        } elseif (Get-Command pwsh -ErrorAction SilentlyContinue) {
            Write-Host ("-> {0}" -f $cb) -ForegroundColor Cyan
            & pwsh -NoProfile -File $cb @cbArgs
            if ($LASTEXITCODE -ne 0) { throw "Child script failed ($LASTEXITCODE): $cb" }
        } else {
            throw 'pwsh (PowerShell 7+) is required on macOS to run the CyberBuilder installer.'
        }
    }

    Write-Host 'Done.' -ForegroundColor Green
    exit 0
}

if (Is-OS -Name 'Linux') {
    Write-Error 'Linux is currently unsupported by install orchestrators in scripts/install (available targets: Windows, macOS).'
    Write-Host 'Use Windows/macOS install scripts, or run CyberBuilder manually with an existing Lua runtime.' -ForegroundColor Yellow
    exit 2
}

throw 'Unsupported OS.'


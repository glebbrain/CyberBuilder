<#
.SYNOPSIS
    Install CyberBuilder with mandatory backup step.

.DESCRIPTION
    Cross-platform PowerShell wrapper that enforces backup before install.

    Sequence:
      1) Run platform prereqs script with backup enabled
      2) Run platform CyberBuilder installer (overlay/fresh mode)

.PARAMETER InstallMode
    Overlay (default) or Fresh.

.PARAMETER InstallDeps
    Allow dependency installation/update attempts.

.PARAMETER GamePath
    Optional explicit CP2077 game root for prereqs checker.

.PARAMETER BackupRoot
    Optional backup root directory. If omitted, platform default is used.

.PARAMETER RepoRoot
    Optional explicit repository root for CyberBuilder installer.

.PARAMETER SkipDryRun
    Skip CyberBuilder dry-run self-test.

.PARAMETER InstallCET
    Attempt CET install during prereqs step.
#>

#Requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet('Overlay', 'Fresh')]
    [string] $InstallMode = 'Overlay',

    [switch] $InstallDeps,

    [switch] $InstallCET,

    [string] $GamePath,

    [string] $BackupRoot,

    [string] $RepoRoot,

    [switch] $SkipDryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-RepoRootFromHere {
    $here = Split-Path -Parent $PSCommandPath
    # scripts/install -> repo root = ../..
    $root = Resolve-Path -LiteralPath (Join-Path $here '..\..')
    return $root.Path
}

function Is-OS {
    param([Parameter(Mandatory = $true)][ValidateSet('Windows','MacOS','Linux')] [string] $Name)
    $rt = [System.Runtime.InteropServices.RuntimeInformation]
    switch ($Name) {
        'Windows' { return $rt::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows) }
        'MacOS'   { return $rt::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::OSX) }
        'Linux'   { return $rt::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Linux) }
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

if (-not $RepoRoot) {
    $RepoRoot = Resolve-RepoRootFromHere
}

$installRoot = Split-Path -Parent $PSCommandPath

if (Is-OS -Name 'Windows') {
    $flavor = Get-WindowsMajorFlavor
    $platformDir = Join-Path $installRoot $flavor
    $pr = Join-Path $platformDir 'Install-CyberBuilderPrereqs.ps1'
    $cb = Join-Path $platformDir 'Install-CyberBuilder.ps1'

    $prArgs = @()
    if ($GamePath) { $prArgs += @('-GamePath', $GamePath) }
    if ($BackupRoot) { $prArgs += @('-BackupRoot', $BackupRoot) }
    if ($InstallCET -or $InstallMode -eq 'Fresh') { $prArgs += @('-InstallCET') }

    Write-Host ("-> {0}" -f $pr) -ForegroundColor Cyan
    & powershell -NoProfile -ExecutionPolicy Bypass -File $pr @prArgs
    if ($LASTEXITCODE -ne 0) { throw "Prereqs+backup failed ($LASTEXITCODE)." }

    $cbArgs = @('-RepoRoot', $RepoRoot, '-InstallMode', $InstallMode, '-NoBackupBeforeInstall')
    if ($GamePath) { $cbArgs += @('-GamePath', $GamePath) }
    if ($BackupRoot) { $cbArgs += @('-BackupRoot', $BackupRoot) }
    if ($SkipDryRun) { $cbArgs += @('-SkipDryRun') }
    if ($InstallDeps -or $InstallMode -eq 'Fresh') { $cbArgs += @('-InstallLua', '-InstallLfs') }

    Write-Host ("-> {0}" -f $cb) -ForegroundColor Cyan
    & powershell -NoProfile -ExecutionPolicy Bypass -File $cb @cbArgs
    if ($LASTEXITCODE -ne 0) { throw "CyberBuilder install failed ($LASTEXITCODE)." }

    Write-Host 'Done (with backup).' -ForegroundColor Green
    exit 0
}

if (Is-OS -Name 'MacOS') {
    $macDir = Join-Path $installRoot 'MacOS'
    $pr = Join-Path $macDir 'Install-CyberBuilderPrereqs.sh'
    $cb = Join-Path $macDir 'Install-CyberBuilder.ps1'

    $prArgs = @('--backup-before-install')
    if ($GamePath) { $prArgs += @('--game-path', $GamePath) }
    if ($BackupRoot) { $prArgs += @('--backup-root', $BackupRoot) }
    if ($InstallCET -or $InstallMode -eq 'Fresh') { $prArgs += @('--install-cet') }

    Write-Host ("-> {0}" -f $pr) -ForegroundColor Cyan
    & bash $pr @prArgs
    if ($LASTEXITCODE -ne 0) { throw "Prereqs+backup failed ($LASTEXITCODE)." }

    $cbArgs = @('-NoProfile', '-File', $cb, '-RepoRoot', $RepoRoot, '-InstallMode', $InstallMode, '-NoBackupBeforeInstall')
    if ($GamePath) { $cbArgs += @('-GamePath', $GamePath) }
    if ($BackupRoot) { $cbArgs += @('-BackupRoot', $BackupRoot) }
    if ($SkipDryRun) { $cbArgs += @('-SkipDryRun') }
    if ($InstallDeps -or $InstallMode -eq 'Fresh') { $cbArgs += @('-InstallLua', '-InstallLfs') }

    if (Get-Command pwsh -ErrorAction SilentlyContinue) {
        Write-Host ("-> {0}" -f $cb) -ForegroundColor Cyan
        & pwsh @cbArgs
    } else {
        throw 'pwsh (PowerShell 7+) is required on macOS.'
    }
    if ($LASTEXITCODE -ne 0) { throw "CyberBuilder install failed ($LASTEXITCODE)." }

    Write-Host 'Done (with backup).' -ForegroundColor Green
    exit 0
}

throw 'Unsupported OS for this installer.'


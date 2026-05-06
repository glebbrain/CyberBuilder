<#
.SYNOPSIS
    Install/check CyberBuilder on macOS (Lua + optional LuaFileSystem) and run a self-test.

.DESCRIPTION
    CyberBuilder is a Lua project. On macOS/Linux, directory discovery requires LuaFileSystem (`lfs`)
    unless you implement an alternative enumerator, so `lfs` is strongly recommended.

    This script (PowerShell 7+ on macOS):
      - checks `lua` presence
      - optionally installs Lua via Homebrew
      - optionally installs LuaRocks and `luafilesystem` via Homebrew + luarocks
      - runs `lua src/cyber_builder/init.lua --dry-run` from repo root

.PARAMETER RepoRoot
    Path to CyberBuilder repository root. Defaults to auto-detected from this script location.

.PARAMETER InstallLua
    Attempt to install Lua via Homebrew (`brew install lua`).

.PARAMETER InstallLfs
    Attempt to install LuaRocks via Homebrew and then install LuaFileSystem (`lfs`) from GitHub
    (with LuaRocks registry fallback).

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

.PARAMETER BackupRoot
    Optional backup parent folder for prereqs backup/check script.

.PARAMETER NoBackupBeforeInstall
    Disable automatic pre-install backup (enabled by default).

.PARAMETER InstallCET
    Attempt CET install via prereqs script before Lua validation.
#>

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

    [string] $BackupRoot,

    [switch] $NoBackupBeforeInstall,

    [switch] $InstallCET
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-RepoRootFromScript {
    $here = Split-Path -Parent $PSCommandPath
    # docs/scripts/install/MacOS -> repo root = ../../../..
    $root = Resolve-Path -LiteralPath (Join-Path $here '..\..\..\..')
    return $root.Path
}

function Test-Command {
    param([Parameter(Mandatory = $true)][string] $Name)
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    return [bool] $cmd
}

function Invoke-OpenUrl {
    param([Parameter(Mandatory = $true)][string] $Url)
    try { & open $Url | Out-Null } catch { }
}

function Invoke-PreInstallBackup {
    if ($NoBackupBeforeInstall) {
        Write-Host 'Pre-install backup disabled by -NoBackupBeforeInstall.' -ForegroundColor DarkGray
        return
    }
    if (-not (Test-Command -Name 'bash')) {
        throw 'bash is required to run pre-install backup/check script on macOS.'
    }

    $scriptDir = Split-Path -Parent $PSCommandPath
    $prereqsScript = Join-Path $scriptDir 'Install-CyberBuilderPrereqs.sh'
    if (-not (Test-Path -LiteralPath $prereqsScript)) {
        throw "Missing prereqs script: $prereqsScript"
    }

    $args = @()
    if ($GamePath) { $args += @('--game-path', $GamePath) }
    if ($BackupRoot) { $args += @('--backup-root', $BackupRoot) }
    if ($InstallCET -or $InstallMode -eq 'Fresh') { $args += @('--install-cet') }

    Write-Host 'Running pre-install backup/check...' -ForegroundColor Cyan
    & bash $prereqsScript @args
    if ($LASTEXITCODE -ne 0) {
        throw "Pre-install backup/check failed ($LASTEXITCODE)."
    }
}

function Get-LuaVersion {
    try {
        $v = (& lua -v) 2>&1
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

function Write-DependencyCheckOutput {
    param(
        [Parameter(Mandatory = $true)][string] $Name,
        [Parameter(Mandatory = $true)][bool] $Found,
        [Parameter(Mandatory = $true)][bool] $VersionUnknown,
        [string] $InstallPath = ''
    )
    $entry = [ordered]@{
        dependency     = $Name
        found          = $Found
        missing        = (-not $Found)
        versionUnknown = $VersionUnknown
        installPath    = $InstallPath
    }
    Write-Host ("dependency-check: {0}" -f (($entry | ConvertTo-Json -Compress))) -ForegroundColor DarkGray
}

function Install-OrUpdateLuaMac {
    if (-not (Test-Command -Name 'brew')) {
        Write-Host 'Homebrew not found. Install Homebrew first.' -ForegroundColor Yellow
        Write-Host ("  Link: {0}" -f $links['Homebrew']) -ForegroundColor DarkGray
        return
    }
    Write-Host 'Installing/updating Lua via Homebrew...' -ForegroundColor Cyan
    try { & brew install lua } catch { }
    try { & brew upgrade lua } catch { }
}

$links = [ordered]@{
    'Lua downloads' = 'https://www.lua.org/download.html'
    'Homebrew'      = 'https://brew.sh/'
    'LuaRocks'      = 'https://luarocks.org/'
    'LuaFileSystem GitHub' = 'https://github.com/lunarmodules/luafilesystem'
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

$recommendedLua = [version]::new(5, 4, 0)
$luaVersion = Get-LuaVersion
$luaMissing = -not (Test-Command -Name 'lua')
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
        Install-OrUpdateLuaMac
    }
}

if (-not (Test-Command -Name 'lua')) {
    Write-DependencyCheckOutput -Name 'lua' -Found $false -VersionUnknown $false -InstallPath ''
    Write-DependencyCheckOutput -Name 'lfs' -Found $false -VersionUnknown $false -InstallPath ''
    throw 'Lua is required. Aborting.'
}

$luaPath = (Get-Command lua).Source
Write-Host ('Lua found: {0}' -f $luaPath) -ForegroundColor Green

if ($InstallLfs -or $InstallMode -eq 'Fresh') {
    if (-not (Test-Command -Name 'brew')) {
        Write-Host 'Homebrew not found; cannot install/update luarocks automatically.' -ForegroundColor Yellow
        Write-Host ("  Link: {0}" -f $links['Homebrew']) -ForegroundColor DarkGray
    } else {
        if (-not (Test-Command -Name 'luarocks')) {
            Write-Host 'Installing/updating LuaRocks via Homebrew...' -ForegroundColor Cyan
            try { & brew install luarocks } catch { }
            try { & brew upgrade luarocks } catch { }
        }
        if (Test-Command -Name 'luarocks') {
            $lfsGithubRockspec = 'https://raw.githubusercontent.com/lunarmodules/luafilesystem/master/luafilesystem-scm-1.rockspec'
            Write-Host 'Installing/updating luafilesystem (lfs) from GitHub via luarocks...' -ForegroundColor Cyan
            try {
                & luarocks install $lfsGithubRockspec
            } catch {
                try {
                    & luarocks make $lfsGithubRockspec
                } catch {
                    Write-Host 'GitHub lfs install failed, trying LuaRocks registry fallback...' -ForegroundColor Yellow
                    try { & luarocks install luafilesystem } catch { }
                    try { & luarocks update luafilesystem } catch { }
                }
            }
        } else {
            Write-Host 'luarocks still not found after install attempt.' -ForegroundColor Yellow
            Write-Host ("  Link: {0}" -f $links['LuaRocks']) -ForegroundColor DarkGray
            Write-Host ("  GitHub: {0}" -f $links['LuaFileSystem GitHub']) -ForegroundColor DarkGray
        }
    }
}

Write-Host 'Checking LuaFileSystem (lfs) availability...' -ForegroundColor Cyan
$lfsOk = $false
try {
    & lua -e "local ok = pcall(require, 'lfs'); if ok then os.exit(0) else os.exit(2) end" | Out-Null
    if ($LASTEXITCODE -eq 0) { $lfsOk = $true }
} catch { }
Write-Host ("lfs available = {0}" -f $lfsOk) -ForegroundColor $(if ($lfsOk) { 'Green' } else { 'DarkYellow' })
$luaVersionUnknown = [bool]((Test-Command -Name 'lua') -and -not $luaVersion)
$lfsVersionUnknown = [bool]$lfsOk
$lfsInstallPath = if ($lfsOk -and (Test-Command -Name 'luarocks')) { 'luarocks:luafilesystem' } else { '' }
Write-DependencyCheckOutput -Name 'lua' -Found $true -VersionUnknown $luaVersionUnknown -InstallPath $luaPath
Write-DependencyCheckOutput -Name 'lfs' -Found $lfsOk -VersionUnknown $lfsVersionUnknown -InstallPath $lfsInstallPath
if (-not $lfsOk) {
    Write-Host 'Note: pack discovery on macOS requires lfs. Re-run with -InstallLfs (recommended).' -ForegroundColor Yellow
}

if (-not (Test-Path -LiteralPath (Join-Path $RepoRoot 'src/cyber_builder/init.lua'))) {
    throw "RepoRoot does not look like CyberBuilder: missing src/cyber_builder/init.lua at $RepoRoot"
}

if ($DryRun) {
    Write-Host 'Running CyberBuilder self-test (--dry-run)...' -ForegroundColor Cyan
    Push-Location $RepoRoot
    try {
        & lua 'src/cyber_builder/init.lua' '--dry-run'
        if ($LASTEXITCODE -ne 0) { throw "CyberBuilder dry-run failed (exit code $LASTEXITCODE)" }
    } finally {
        Pop-Location
    }
    Write-Host 'CyberBuilder dry-run completed.' -ForegroundColor Green
} else {
    Write-Host 'DryRun disabled; skipping self-test.' -ForegroundColor DarkGray
}


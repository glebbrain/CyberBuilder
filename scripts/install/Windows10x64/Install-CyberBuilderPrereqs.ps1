<#
.SYNOPSIS
    Windows helper aligned with docs\INSTALL.md: locate Cyberpunk 2077, sanity-check the mod stack, and optionally open official download/docs pages.

.DESCRIPTION
    CyberBuilder assumes a modded CP2077 stack (RED4ext, CET, Codeware, redscript, ArchiveXL, TweakXL, World Builder) and WolvenKit.
    This script does not download Nexus/GitHub archives (versions must match your game patch). It automates discovery and reporting.

.PARAMETER GamePath
    Explicit game root (folder containing bin\x64\Cyberpunk2077.exe).

.PARAMETER OpenDocumentationLinks
    Open a browser tab for each listed component's primary releases/docs URL.

.PARAMETER Json
    Emit a single JSON object to stdout (for tooling); suppresses human banner.

.PARAMETER SteamAppsCommonPaths
    Extra `steamapps\common` folders to probe before VDF discovery (first match wins). Default includes this repo maintainer's Steam library layout.

.PARAMETER NoBackupBeforeInstall
    Disable backup before checks/install flow. By default backup is enabled.

.PARAMETER BackupRoot
    Parent directory for backups (default: Documents\CyberBuilder-CP2077-backups). Each run creates a subfolder `CP2077-pre-mod-<timestamp>`.

.PARAMETER InstallCET
    Best-effort CET install from official GitHub release into resolved game directory.

.EXAMPLE
    .\Install-CyberBuilderPrereqs.ps1

.EXAMPLE
    .\Install-CyberBuilderPrereqs.ps1 -GamePath 'D:\Games\Cyberpunk 2077' -OpenDocumentationLinks

.EXAMPLE
    .\Install-CyberBuilderPrereqs.ps1

.EXAMPLE
    $env:CYBERBUILDER_STEAM_COMMON = 'G:\OtherSteam\steamapps\common'  # optional; semicolon-separated list allowed
    .\Install-CyberBuilderPrereqs.ps1

.NOTES
    Read docs\INSTALL.md for rationale and install order; RED4ext and redscript versions must match your game patch per upstream READMEs.
    Override default Steam common paths with -SteamAppsCommonPaths @() and/or env CYBERBUILDER_STEAM_COMMON.
#>

#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string] $GamePath,

    [switch] $OpenDocumentationLinks,

    [switch] $Json,

    [Parameter(Mandatory = $false)]
    [string[]] $SteamAppsCommonPaths = @('G:\GameHub\Steam\steamapps\common'),

    [switch] $NoBackupBeforeInstall,

    [switch] $ConfirmPluginOverwrite,

    [Parameter(Mandatory = $false)]
    [string] $BackupRoot,

    [switch] $InstallCET,

    [switch] $StrictInstall = $true,

    [switch] $NoStrictInstall,

    [switch] $PauseForManualInstall
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if ($NoStrictInstall) { $StrictInstall = $false }

$script:ComponentLinks = [ordered]@{
    'RED4ext'      = 'https://github.com/WopsS/RED4ext/releases'
    'CET'          = 'https://github.com/yamashi/CyberEngineTweaks/releases'
    'Codeware'     = 'https://github.com/psiberx/cp2077-codeware/releases'
    'redscript'    = 'https://github.com/jac3km4/redscript/releases'
    'ArchiveXL'    = 'https://github.com/psiberx/cp2077-archive-xl/releases'
    'TweakXL'      = 'https://github.com/psiberx/cp2077-tweak-xl/releases'
    'World Builder' = 'https://www.nexusmods.com/cyberpunk2077/mods/20660'
    'WolvenKit'    = 'https://github.com/WolvenKit/WolvenKit/releases'
}

function Get-SteamCommonCandidates {
    param(
        [string[]] $ConfiguredSteamAppsCommonPaths
    )
    $paths = New-Object System.Collections.Generic.List[string]

    if ($env:CYBERBUILDER_STEAM_COMMON) {
        foreach ($chunk in ($env:CYBERBUILDER_STEAM_COMMON -split ';')) {
            $t = $chunk.Trim()
            if ($t) { $paths.Add($t.TrimEnd('\', '/')) | Out-Null }
        }
    }

    foreach ($p in $ConfiguredSteamAppsCommonPaths) {
        if (-not $p) { continue }
        $paths.Add($p.TrimEnd('\', '/')) | Out-Null
    }

    $roots = @(
        (Join-Path $env:ProgramFiles 'Steam'),
        (Join-Path ${env:ProgramFiles(x86)} 'Steam')
    ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -Unique

    foreach ($steamRoot in $roots) {
        $libFile = Join-Path $steamRoot 'steamapps\libraryfolders.vdf'
        if (-not (Test-Path -LiteralPath $libFile)) { continue }
        $text = Get-Content -LiteralPath $libFile -Raw -Encoding UTF8
        foreach ($m in [regex]::Matches($text, '"path"\s+"([^"]+)"')) {
            $raw = $m.Groups[1].Value -replace '\\\\', '\'
            if (-not $raw) { continue }
            $libRoot = $raw.TrimEnd('\', '/')
            if (-not (Test-Path -LiteralPath $libRoot)) { continue }
            $common = Join-Path $libRoot 'steamapps\common'
            if (Test-Path -LiteralPath $common) {
                $paths.Add($common) | Out-Null
            } else {
                $paths.Add($libRoot) | Out-Null
            }
        }
        $defaultLib = Join-Path $steamRoot 'steamapps\common'
        if (Test-Path -LiteralPath $defaultLib) {
            $paths.Add($defaultLib) | Out-Null
        }
    }

    $out = New-Object System.Collections.Generic.List[string]
    foreach ($p in ($paths | Select-Object -Unique)) {
        if ($p -and (Test-Path -LiteralPath $p)) {
            $out.Add((Resolve-Path -LiteralPath $p).Path) | Out-Null
        }
    }
    return $out
}

function Resolve-Cyberpunk2077GameRoot {
    param(
        [string] $ExplicitPath,
        [string[]] $ConfiguredSteamAppsCommonPaths
    )

    if ($ExplicitPath) {
        $root = $ExplicitPath.TrimEnd('\', '/')
        $exe  = Join-Path $root 'bin\x64\Cyberpunk2077.exe'
        if (Test-Path -LiteralPath $exe) { return (Resolve-Path -LiteralPath $root).Path }
        throw "GamePath is set but Cyberpunk2077.exe was not found at: $exe"
    }

    foreach ($lib in (Get-SteamCommonCandidates -ConfiguredSteamAppsCommonPaths $ConfiguredSteamAppsCommonPaths)) {
        $candidate = Join-Path $lib 'Cyberpunk 2077'
        $exe = Join-Path $candidate 'bin\x64\Cyberpunk2077.exe'
        if (Test-Path -LiteralPath $exe) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    $gog = @(
        'HKLM:\SOFTWARE\GOG.com\Games\1423049311',
        'HKLM:\SOFTWARE\WOW6432Node\GOG.com\Games\1423049311'
    )
    foreach ($key in $gog) {
        if (-not (Test-Path -LiteralPath $key)) { continue }
        $p = (Get-ItemProperty -LiteralPath $key -ErrorAction SilentlyContinue).PATH
        if ($p) {
            $exe = Join-Path $p 'bin\x64\Cyberpunk2077.exe'
            if (Test-Path -LiteralPath $exe) { return (Resolve-Path -LiteralPath $p).Path }
        }
    }

    return $null
}

function Test-ModStackHints {
    param([string] $Root)

    $hints = [ordered]@{}
    $binX64 = Join-Path $Root 'bin\x64'

    $hints['RED4ext'] = @(
        (Test-Path -LiteralPath (Join-Path $Root 'red4ext')),
        (Test-Path -LiteralPath (Join-Path $binX64 'RED4ext'))
    ) -contains $true

    $hints['CET'] = Test-Path -LiteralPath (Join-Path $binX64 'plugins\cyber_engine_tweaks')

    $hints['redscript'] = @(
        (Test-Path -LiteralPath (Join-Path $Root 'r6\cache\modded')),
        (Test-Path -LiteralPath (Join-Path $Root 'tools\redscript')),
        (Test-Path -LiteralPath (Join-Path $Root 'engine\tools\scc.exe')),
        (Test-Path -LiteralPath (Join-Path $Root 'engine\tools\scc_lib.dll'))
    ) -contains $true

    $hints['Codeware'] = Test-Path -LiteralPath (Join-Path $Root 'r6\scripts\Codeware')
    if (-not $hints['Codeware']) {
        $hints['Codeware'] = Test-Path -LiteralPath (Join-Path $Root 'archive\pc\mod\Codeware.archive')
    }
    if (-not $hints['Codeware']) {
        $hints['Codeware'] = Test-Path -LiteralPath (Join-Path $Root 'red4ext\plugins\Codeware\Codeware.dll')
    }

    $hints['ArchiveXL'] = Test-Path -LiteralPath (Join-Path $Root 'r6\scripts\ArchiveXL')
    if (-not $hints['ArchiveXL']) {
        $hints['ArchiveXL'] = Test-Path -LiteralPath (Join-Path $Root 'mods\ArchiveXL')
    }
    if (-not $hints['ArchiveXL']) {
        $hints['ArchiveXL'] = Test-Path -LiteralPath (Join-Path $Root 'red4ext\plugins\ArchiveXL\ArchiveXL.dll')
    }

    $hints['TweakXL'] = Test-Path -LiteralPath (Join-Path $Root 'r6\scripts\TweakXL')
    if (-not $hints['TweakXL']) {
        $hints['TweakXL'] = Test-Path -LiteralPath (Join-Path $Root 'mods\TweakXL')
    }
    if (-not $hints['TweakXL']) {
        $hints['TweakXL'] = Test-Path -LiteralPath (Join-Path $Root 'red4ext\plugins\TweakXL\TweakXL.dll')
    }

    $hints['World Builder'] = @(
        (Test-Path -LiteralPath (Join-Path $Root 'r6\scripts\WorldBuilder')),
        (Test-Path -LiteralPath (Join-Path $Root 'r6\scripts\entBuilder.reds')),
        (Test-Path -LiteralPath (Join-Path $Root 'mods\World Builder')),
        (Test-Path -LiteralPath (Join-Path $Root 'mods\WorldBuilder')),
        (Test-Path -LiteralPath (Join-Path $Root 'bin\x64\plugins\cyber_engine_tweaks\mods\entSpawner\init.lua'))
    ) -contains $true

    return $hints
}

function Get-WolvenKitHint {
    $local = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\WolvenKit.exe'
    if (Test-Path -LiteralPath $local) { return $true }
    $localInstall = Join-Path $env:LOCALAPPDATA 'WolvenKit\WolvenKit.exe'
    if (Test-Path -LiteralPath $localInstall) { return $true }
    $pf = @(
        (Join-Path $env:ProgramFiles 'WolvenKit'),
        (Join-Path ${env:ProgramFiles(x86)} 'WolvenKit')
    )
    foreach ($d in $pf) {
        if (Test-Path -LiteralPath $d) { return $true }
    }
    return $false
}

function Backup-Cp2077ModHotspots {
    param(
        [string] $GameRoot,
        [string] $BackupParent
    )

    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $destRoot = Join-Path $BackupParent "CP2077-pre-mod-$stamp"
    New-Item -ItemType Directory -Force -Path $destRoot | Out-Null

    $copied = New-Object System.Collections.Generic.List[string]
    $relDirs = @(
        'red4ext',
        'bin\x64\plugins',
        'mods',
        'archive\pc\mod',
        'r6\scripts',
        'r6\config',
        'r6\tweaks'
    )

    foreach ($rel in $relDirs) {
        $src = Join-Path $GameRoot $rel
        if (-not (Test-Path -LiteralPath $src)) { continue }
        $dst = Join-Path $destRoot $rel
        $parent = Split-Path -Parent $dst
        if (-not (Test-Path -LiteralPath $parent)) {
            New-Item -ItemType Directory -Force -Path $parent | Out-Null
        }
        Copy-Item -LiteralPath $src -Destination $dst -Recurse -Force
        $copied.Add($rel) | Out-Null
    }

    $binX64 = Join-Path $GameRoot 'bin\x64'
    $dllDstRoot = Join-Path $destRoot 'bin\x64'
    foreach ($dll in @('version.dll', 'winmm.dll', 'dinput8.dll')) {
        $fp = Join-Path $binX64 $dll
        if (-not (Test-Path -LiteralPath $fp)) { continue }
        if (-not (Test-Path -LiteralPath $dllDstRoot)) {
            New-Item -ItemType Directory -Force -Path $dllDstRoot | Out-Null
        }
        Copy-Item -LiteralPath $fp -Destination (Join-Path $dllDstRoot $dll) -Force
        $copied.Add("bin\x64\$dll") | Out-Null
    }

    $readme = Join-Path $destRoot 'README-backup.txt'
    @(
        "Cyberpunk 2077 modding snapshot (before installing or updating mods).",
        "Game root: $GameRoot",
        "Created: $(Get-Date -Format 'o')",
        "",
        "Folders/files copied (only if they existed):",
        ($copied | ForEach-Object { "  - $_" }) -join "`r`n",
        "",
        "r6\cache (redscript cache) is not copied - it can be very large; delete or rebuild after restores if needed."
    ) -join "`r`n" | Set-Content -LiteralPath $readme -Encoding UTF8

    return [pscustomobject]@{
        BackupPath = $destRoot
        CopiedRel  = @($copied)
    }
}

function Get-CetReleaseAssetUrl {
    $api = 'https://api.github.com/repos/yamashi/CyberEngineTweaks/releases/latest'
    $headers = @{ 'User-Agent' = 'CyberBuilder-InstallScript' }
    $release = Invoke-RestMethod -Method Get -Uri $api -Headers $headers
    if (-not $release -or -not $release.assets) {
        throw 'CET install: no release assets returned by GitHub API.'
    }
    $asset = $release.assets |
        Where-Object { $_.name -match '(?i)\.zip$' } |
        Where-Object { $_.name -notmatch '(?i)source|symbols|debug|pdb' } |
        Select-Object -First 1
    if (-not $asset) {
        throw 'CET install: could not find ZIP asset in latest release.'
    }
    return $asset.browser_download_url
}

function Install-CetFromGitHub {
    param([string] $GameRoot)
    if (-not $GameRoot) {
        throw 'CET install requires resolved game root.'
    }

    $cetDir = Join-Path $GameRoot 'bin\x64\plugins\cyber_engine_tweaks'
    if (Test-Path -LiteralPath $cetDir) {
        return [pscustomobject]@{ Installed = $false; Reason = 'already_present' }
    }

    $zipPath = Join-Path ([IO.Path]::GetTempPath()) ("cyberbuilder-cet-" + [guid]::NewGuid().ToString('N') + ".zip")
    $extractDir = Join-Path ([IO.Path]::GetTempPath()) ("cyberbuilder-cet-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $extractDir | Out-Null
    try {
        $url = Get-CetReleaseAssetUrl
        Invoke-WebRequest -Uri $url -OutFile $zipPath -UseBasicParsing
        Expand-Archive -LiteralPath $zipPath -DestinationPath $extractDir -Force

        $pluginDir = Get-ChildItem -Path $extractDir -Recurse -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -ieq 'cyber_engine_tweaks' } |
            Select-Object -First 1
        if (-not $pluginDir) {
            throw 'CET install: extracted archive does not contain cyber_engine_tweaks folder.'
        }

        $pluginsRoot = Join-Path $GameRoot 'bin\x64\plugins'
        if (-not (Test-Path -LiteralPath $pluginsRoot)) {
            New-Item -ItemType Directory -Force -Path $pluginsRoot | Out-Null
        }
        $target = Join-Path $pluginsRoot 'cyber_engine_tweaks'
        if ($NoBackupBeforeInstall -and -not $ConfirmPluginOverwrite -and (Test-Path -LiteralPath $target)) {
            throw 'Safe-mode: refusing to overwrite existing plugin folder without backup or -ConfirmPluginOverwrite.'
        }
        if (Test-Path -LiteralPath $target) {
            Remove-Item -LiteralPath $target -Recurse -Force
        }
        Copy-Item -LiteralPath $pluginDir.FullName -Destination $target -Recurse -Force

        return [pscustomobject]@{ Installed = $true; Reason = 'installed'; AssetUrl = $url }
    } finally {
        if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force -ErrorAction SilentlyContinue }
        if (Test-Path -LiteralPath $extractDir) { Remove-Item -LiteralPath $extractDir -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

function Get-GitHubLatestAssetUrl {
    param(
        [Parameter(Mandatory = $true)][string] $Repo,
        [Parameter(Mandatory = $true)][string] $PreferredPattern
    )
    $api = "https://api.github.com/repos/$Repo/releases/latest"
    $headers = @{ 'User-Agent' = 'CyberBuilder-InstallScript' }
    $release = Invoke-RestMethod -Method Get -Uri $api -Headers $headers
    if (-not $release -or -not $release.assets) {
        throw "Component install: no release assets returned by GitHub API for $Repo."
    }

    $asset = $release.assets |
        Where-Object { $_.name -match $PreferredPattern } |
        Select-Object -First 1
    if (-not $asset) {
        $asset = $release.assets |
            Where-Object { $_.name -match '(?i)\.zip$' } |
            Where-Object { $_.name -notmatch '(?i)source|symbols|debug|pdb' } |
            Select-Object -First 1
    }
    if (-not $asset) {
        throw "Component install: could not find suitable asset for $Repo."
    }
    return $asset.browser_download_url
}

function Install-GitHubZipComponent {
    param(
        [Parameter(Mandatory = $true)][string] $Repo,
        [Parameter(Mandatory = $true)][string] $PreferredPattern,
        [Parameter(Mandatory = $true)][string] $GameRoot,
        [Parameter(Mandatory = $true)][string] $ComponentName
    )
    $zipPath = Join-Path ([IO.Path]::GetTempPath()) ("cyberbuilder-$($ComponentName.ToLowerInvariant())-" + [guid]::NewGuid().ToString('N') + ".zip")
    $extractDir = Join-Path ([IO.Path]::GetTempPath()) ("cyberbuilder-$($ComponentName.ToLowerInvariant())-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $extractDir | Out-Null
    try {
        $url = Get-GitHubLatestAssetUrl -Repo $Repo -PreferredPattern $PreferredPattern
        Invoke-WebRequest -Uri $url -OutFile $zipPath -UseBasicParsing
        Expand-Archive -LiteralPath $zipPath -DestinationPath $extractDir -Force

        $topEntries = Get-ChildItem -LiteralPath $extractDir -ErrorAction SilentlyContinue
        if (-not $topEntries) {
            throw "$ComponentName install: archive is empty."
        }

        $pluginsRoot = Join-Path $GameRoot 'bin\x64\plugins'
        if ($NoBackupBeforeInstall -and -not $ConfirmPluginOverwrite -and (Test-Path -LiteralPath $pluginsRoot)) {
            throw "Safe-mode: refusing component install for $ComponentName because plugin folders may be overwritten without backup or -ConfirmPluginOverwrite."
        }
        foreach ($entry in $topEntries) {
            Copy-Item -LiteralPath $entry.FullName -Destination $GameRoot -Recurse -Force
        }
        return [pscustomobject]@{ Installed = $true; Reason = 'installed'; Repo = $Repo; AssetPattern = $PreferredPattern }
    } finally {
        if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force -ErrorAction SilentlyContinue }
        if (Test-Path -LiteralPath $extractDir) { Remove-Item -LiteralPath $extractDir -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

function Install-WolvenKit {
    if (Get-WolvenKitHint) {
        return [pscustomobject]@{ Installed = $false; Reason = 'already_present' }
    }
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        try {
            winget install --id WolvenKit.WolvenKit --source winget --accept-package-agreements --accept-source-agreements | Out-Null
            if (Get-WolvenKitHint) {
                return [pscustomobject]@{ Installed = $true; Reason = 'installed_via_winget' }
            }
        } catch {
        }
    }
    try {
        $zipPath = Join-Path ([IO.Path]::GetTempPath()) ("cyberbuilder-wolvenkit-" + [guid]::NewGuid().ToString('N') + ".zip")
        $extractDir = Join-Path ([IO.Path]::GetTempPath()) ("cyberbuilder-wolvenkit-" + [guid]::NewGuid().ToString('N'))
        $installRoot = Join-Path $env:LOCALAPPDATA 'WolvenKit'
        New-Item -ItemType Directory -Force -Path $extractDir | Out-Null
        New-Item -ItemType Directory -Force -Path $installRoot | Out-Null
        $url = Get-GitHubLatestAssetUrl -Repo 'WolvenKit/WolvenKit' -PreferredPattern '(?i)^WolvenKit-\d+.*\.zip$'
        Invoke-WebRequest -Uri $url -OutFile $zipPath -UseBasicParsing
        Expand-Archive -LiteralPath $zipPath -DestinationPath $extractDir -Force
        $contentRoot = $extractDir
        $wkExe = Get-ChildItem -Path $extractDir -Recurse -Filter 'WolvenKit.exe' -File -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($wkExe) {
            $contentRoot = Split-Path -Parent $wkExe.FullName
        }
        Copy-Item -Path (Join-Path $contentRoot '*') -Destination $installRoot -Recurse -Force
        if (Get-WolvenKitHint) {
            return [pscustomobject]@{ Installed = $true; Reason = 'installed_from_github_zip' }
        }
    } catch {
    } finally {
        if ($zipPath -and (Test-Path -LiteralPath $zipPath)) { Remove-Item -LiteralPath $zipPath -Force -ErrorAction SilentlyContinue }
        if ($extractDir -and (Test-Path -LiteralPath $extractDir)) { Remove-Item -LiteralPath $extractDir -Recurse -Force -ErrorAction SilentlyContinue }
    }
    return [pscustomobject]@{ Installed = $false; Reason = 'manual_required' }
}

function Install-PayloadDirectoryContent {
    param(
        [Parameter(Mandatory = $true)][string] $PayloadRoot,
        [Parameter(Mandatory = $true)][string] $GameRoot,
        [Parameter(Mandatory = $true)][hashtable] $Stats
    )
    $files = Get-ChildItem -LiteralPath $PayloadRoot -Recurse -File -ErrorAction SilentlyContinue
    foreach ($src in $files) {
        $rel = $src.FullName.Substring($PayloadRoot.Length).TrimStart('\')
        if (-not $rel) { continue }
        $dst = Join-Path $GameRoot $rel
        $dstParent = Split-Path -Parent $dst
        if (-not (Test-Path -LiteralPath $dstParent)) {
            New-Item -ItemType Directory -Path $dstParent -Force | Out-Null
        }

        if (-not (Test-Path -LiteralPath $dst)) {
            Copy-Item -LiteralPath $src.FullName -Destination $dst -Force
            $Stats.installed += 1
            continue
        }

        $dstItem = Get-Item -LiteralPath $dst -ErrorAction SilentlyContinue
        if (-not $dstItem -or $dstItem.PSIsContainer) {
            $Stats.skippedConflicts += 1
            continue
        }

        # Update only when payload is clearly newer; otherwise treat as conflict and skip.
        if ($src.LastWriteTimeUtc -gt $dstItem.LastWriteTimeUtc) {
            Copy-Item -LiteralPath $src.FullName -Destination $dst -Force
            $Stats.updated += 1
        } else {
            $Stats.skippedConflicts += 1
        }
    }
}

function Install-AllFromDistr {
    param(
        [Parameter(Mandatory = $true)][string] $GameRoot
    )
    $stats = @{
        installed = 0
        updated = 0
        skippedConflicts = 0
        archives = 0
        payloads = 0
    }
    try {
        $scriptDir = Split-Path -Parent $PSCommandPath
        $repoRoot = Resolve-Path -LiteralPath (Join-Path $scriptDir '..\..\..')
        $distrRoot = Join-Path $repoRoot.Path 'distr'
        if (-not (Test-Path -LiteralPath $distrRoot)) {
            return [pscustomobject]@{ Applied = $false; Reason = 'distr_missing'; Stats = $stats }
        }

        $entries = Get-ChildItem -LiteralPath $distrRoot -Force -ErrorAction SilentlyContinue
        if (-not $entries) {
            return [pscustomobject]@{ Applied = $false; Reason = 'distr_empty'; Stats = $stats }
        }

        foreach ($entry in $entries) {
            try {
                if ($entry.PSIsContainer) {
                    Install-PayloadDirectoryContent -PayloadRoot $entry.FullName -GameRoot $GameRoot -Stats $stats
                    $stats.payloads += 1
                    continue
                }
                if ($entry.Extension -ieq '.zip') {
                    $extractDir = Join-Path ([IO.Path]::GetTempPath()) ("cyberbuilder-distr-" + [guid]::NewGuid().ToString('N'))
                    New-Item -ItemType Directory -Path $extractDir -Force | Out-Null
                    try {
                        Expand-Archive -LiteralPath $entry.FullName -DestinationPath $extractDir -Force
                        Install-PayloadDirectoryContent -PayloadRoot $extractDir -GameRoot $GameRoot -Stats $stats
                        $stats.payloads += 1
                        $stats.archives += 1
                    } finally {
                        if (Test-Path -LiteralPath $extractDir) {
                            Remove-Item -LiteralPath $extractDir -Recurse -Force -ErrorAction SilentlyContinue
                        }
                    }
                }
            } catch {
                $stats.skippedConflicts += 1
            }
        }
        return [pscustomobject]@{ Applied = $true; Reason = 'ok'; Stats = $stats }
    } catch {
        return [pscustomobject]@{ Applied = $false; Reason = $_.Exception.Message; Stats = $stats }
    }
}

$backupParentDefault = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'CyberBuilder-CP2077-backups'
if (-not $BackupRoot) {
    $BackupRoot = $backupParentDefault
}

$resolved = Resolve-Cyberpunk2077GameRoot -ExplicitPath $GamePath -ConfiguredSteamAppsCommonPaths $SteamAppsCommonPaths
$backupResult = $null
if (-not $NoBackupBeforeInstall) {
    if (-not $resolved) {
        throw 'Backup requires a resolved game path. Set -GamePath or fix Steam discovery (see -SteamAppsCommonPaths / CYBERBUILDER_STEAM_COMMON).'
    }
    if (-not (Test-Path -LiteralPath $BackupRoot)) {
        New-Item -ItemType Directory -Force -Path $BackupRoot | Out-Null
    }
    $backupResult = Backup-Cp2077ModHotspots -GameRoot $resolved -BackupParent $BackupRoot
}

$distrInstallResult = $null
if ($resolved) {
    $distrInstallResult = Install-AllFromDistr -GameRoot $resolved
}

$cetInstallResult = $null
if ($InstallCET -or $StrictInstall) {
    if (-not $resolved) {
        throw 'InstallCET requires a resolved game path. Set -GamePath or fix Steam discovery.'
    }
    $cetInstallResult = Install-CetFromGitHub -GameRoot $resolved
}

if ($StrictInstall -and $resolved) {
    $hintsBefore = Test-ModStackHints -Root $resolved
    if (-not $hintsBefore['RED4ext']) {
        try { [void](Install-GitHubZipComponent -Repo 'WopsS/RED4ext' -PreferredPattern '(?i)^red4ext-(?!symbols).+\.zip$' -GameRoot $resolved -ComponentName 'RED4ext') } catch { Write-Host ("RED4ext install failed: {0}" -f $_.Exception.Message) -ForegroundColor Yellow }
    }
    if (-not $hintsBefore['Codeware']) {
        try { [void](Install-GitHubZipComponent -Repo 'psiberx/cp2077-codeware' -PreferredPattern '(?i)\.zip$' -GameRoot $resolved -ComponentName 'Codeware') } catch { Write-Host ("Codeware install failed: {0}" -f $_.Exception.Message) -ForegroundColor Yellow }
    }
    if (-not $hintsBefore['redscript']) {
        try { [void](Install-GitHubZipComponent -Repo 'jac3km4/redscript' -PreferredPattern '(?i)redscript-v.+-windows\.zip$' -GameRoot $resolved -ComponentName 'redscript') } catch { Write-Host ("redscript install failed: {0}" -f $_.Exception.Message) -ForegroundColor Yellow }
    }
    if (-not $hintsBefore['ArchiveXL']) {
        try { [void](Install-GitHubZipComponent -Repo 'psiberx/cp2077-archive-xl' -PreferredPattern '(?i)\.zip$' -GameRoot $resolved -ComponentName 'ArchiveXL') } catch { Write-Host ("ArchiveXL install failed: {0}" -f $_.Exception.Message) -ForegroundColor Yellow }
    }
    if (-not $hintsBefore['TweakXL']) {
        try { [void](Install-GitHubZipComponent -Repo 'psiberx/cp2077-tweak-xl' -PreferredPattern '(?i)\.zip$' -GameRoot $resolved -ComponentName 'TweakXL') } catch { Write-Host ("TweakXL install failed: {0}" -f $_.Exception.Message) -ForegroundColor Yellow }
    }
    if (-not $hintsBefore['World Builder']) {
        $wbLocal = Install-WorldBuilderFromDistr -GameRoot $resolved
        if (-not $wbLocal.Installed) {
            Write-Host ("World Builder local distr install unavailable ({0})." -f $wbLocal.Reason) -ForegroundColor Yellow
            Write-Host ("World Builder requires semi-manual installation from Nexus: {0}" -f $script:ComponentLinks['World Builder']) -ForegroundColor Yellow
        }
        if ($OpenDocumentationLinks) { Start-Process $script:ComponentLinks['World Builder'] }
        if ($PauseForManualInstall) {
            [void](Read-Host 'Install World Builder now, then press Enter to continue verification')
        }
    }
    [void](Install-WolvenKit)
}

$wbHints = if ($resolved) { Test-ModStackHints -Root $resolved } else { $null }
$wolven = Get-WolvenKitHint

if ($StrictInstall) {
    if (-not $resolved) {
        throw 'Strict install requires resolved game root. Set -GamePath or configure Steam discovery.'
    }
    $missing = New-Object System.Collections.Generic.List[string]
    foreach ($name in @('RED4ext','CET','Codeware','redscript','ArchiveXL','TweakXL','World Builder')) {
        if (-not $wbHints[$name]) { $missing.Add($name) | Out-Null }
    }
    if (-not $wolven) { $missing.Add('WolvenKit') | Out-Null }
    if ($missing.Count -gt 0) {
        throw ("Strict install verification failed. Missing components: {0}" -f ($missing -join ', '))
    }
}

if ($OpenDocumentationLinks) {
    foreach ($name in @(
            'RED4ext', 'CET', 'Codeware', 'redscript', 'ArchiveXL', 'TweakXL', 'World Builder', 'WolvenKit'
        )) {
        $url = $script:ComponentLinks[$name]
        Write-Host "Opening: $name -> $url"
        Start-Process $url
    }
}

if ($Json) {
    $steamTried = @(Get-SteamCommonCandidates -ConfiguredSteamAppsCommonPaths $SteamAppsCommonPaths)
    $obj = [ordered]@{
        gamePathResolved     = $resolved
        steamCommonTried     = $steamTried
        gameMods             = $wbHints
        wolvenKitHeuristic   = $wolven
        links                = [hashtable]$script:ComponentLinks
        backupPath           = if ($backupResult) { $backupResult.BackupPath } else { $null }
        backupCopiedRelative = if ($backupResult) { @($backupResult.CopiedRel) } else { $null }
        cetInstall           = $cetInstallResult
    }
    ($obj | ConvertTo-Json -Depth 8)
    exit 0
}

Write-Host 'CyberBuilder prerequisite check (see docs\INSTALL.md)' -ForegroundColor Cyan
Write-Host ''

if (-not $resolved) {
    Write-Host 'Could not auto-detect Cyberpunk 2077. Pass -GamePath "<game root>" (folder with bin\x64\Cyberpunk2077.exe).' -ForegroundColor Yellow
    Write-Host 'Steam: extra steamapps\common paths come from -SteamAppsCommonPaths and env CYBERBUILDER_STEAM_COMMON (semicolon-separated).' -ForegroundColor DarkGray
} else {
    Write-Host "Game root: $resolved"
    Write-Host ''
    Write-Host 'Heuristic presence (false does not mean missing - layout varies by manager):' -ForegroundColor DarkGray
    foreach ($k in $wbHints.Keys) {
        $ok = $wbHints[$k]
        $color = if ($ok) { 'Green' } else { 'DarkYellow' }
        Write-Host ("  {0,-16} {1}" -f $k, ($(if ($ok) { 'possibly present' } else { 'not detected' }))) -ForegroundColor $color
    }
}

if ($backupResult) {
    Write-Host ''
    Write-Host "Backup written to: $($backupResult.BackupPath)" -ForegroundColor Green
    Write-Host ('  Entries: {0}' -f ($backupResult.CopiedRel -join ', ')) -ForegroundColor DarkGray
}
if ($cetInstallResult) {
    Write-Host ''
    if ($cetInstallResult.Installed) {
        Write-Host 'CET install: completed from latest GitHub release.' -ForegroundColor Green
    } else {
        Write-Host ("CET install: skipped ({0})." -f $cetInstallResult.Reason) -ForegroundColor DarkGray
    }
}
if ($distrInstallResult -and $distrInstallResult.Applied) {
    Write-Host ''
    Write-Host ('distr payloads applied: payloads={0}, archives={1}, installed={2}, updated={3}, skippedConflicts={4}' -f `
            $distrInstallResult.Stats.payloads, $distrInstallResult.Stats.archives, $distrInstallResult.Stats.installed, $distrInstallResult.Stats.updated, $distrInstallResult.Stats.skippedConflicts) -ForegroundColor DarkGray
}

Write-Host ''
Write-Host ("WolvenKit (install separately): heuristic install found = {0}" -f $wolven) -ForegroundColor $(if ($wolven) { 'Green' } else { 'DarkYellow' })

Write-Host ''
Write-Host 'Required stack (install order per each upstream README):' -ForegroundColor Cyan
foreach ($name in $script:ComponentLinks.Keys) {
    Write-Host ("  - {0,-16} {1}" -f $name, $script:ComponentLinks[$name])
}

Write-Host ''
Write-Host 'CyberBuilder MVP only validates packs and exports World Builder-oriented outputs; it does not replace any of the above (docs\INSTALL.md).' -ForegroundColor DarkGray

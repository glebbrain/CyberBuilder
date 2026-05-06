#!/usr/bin/env bash

set -euo pipefail

COMPONENT_NAMES=(
  "RED4ext"
  "CET"
  "Codeware"
  "redscript"
  "ArchiveXL"
  "TweakXL"
  "World Builder"
  "WolvenKit"
)

COMPONENT_LINKS=(
  "https://github.com/WopsS/RED4ext/releases"
  "https://github.com/yamashi/CyberEngineTweaks/releases"
  "https://github.com/psiberx/cp2077-codeware/releases"
  "https://github.com/jac3km4/redscript/releases"
  "https://github.com/psiberx/cp2077-archive-xl/releases"
  "https://github.com/psiberx/cp2077-tweak-xl/releases"
  "https://www.nexusmods.com/cyberpunk2077/mods/20660"
  "https://github.com/WolvenKit/WolvenKit/releases"
)

GAME_PATH=""
OPEN_DOCUMENTATION_LINKS=false
JSON_MODE=false
BACKUP_BEFORE_INSTALL=true
BACKUP_ROOT="${HOME}/Documents/CyberBuilder-CP2077-backups"
INSTALL_CET=false
STRICT_INSTALL=true
PAUSE_FOR_MANUAL_INSTALL=false
STEAM_COMMON_PATHS=()

usage() {
  cat <<'EOF'
Install-CyberBuilderPrereqs.sh

Usage:
  ./Install-CyberBuilderPrereqs.sh [options]

Options:
  --game-path <path>            Explicit game root (folder containing bin/x64/Cyberpunk2077.exe)
  --open-documentation-links    Open official docs/download links in browser
  --json                        Emit a single JSON object to stdout
  --steam-common-path <path>    Extra steamapps/common path to probe (repeatable)
  --backup-before-install       Copy mod-related hotspots to backup folder (default)
  --no-backup-before-install    Disable backup before install
  --backup-root <path>          Parent backup directory (default: ~/Documents/CyberBuilder-CP2077-backups)
  --install-cet                 Best-effort CET install from latest GitHub release
  --strict-install              Enforce full stack verification and fail if any component missing (default)
  --no-strict-install           Disable strict full stack enforcement
  --pause-for-manual-install    Wait for Enter after opening manual install pages
  -h, --help                    Show this help

Environment:
  CYBERBUILDER_STEAM_COMMON     Extra steamapps/common paths, separated by semicolon (;)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --game-path)
      [[ $# -lt 2 ]] && { echo "Missing value for --game-path" >&2; exit 1; }
      GAME_PATH="$2"
      shift 2
      ;;
    --open-documentation-links)
      OPEN_DOCUMENTATION_LINKS=true
      shift
      ;;
    --json)
      JSON_MODE=true
      shift
      ;;
    --steam-common-path)
      [[ $# -lt 2 ]] && { echo "Missing value for --steam-common-path" >&2; exit 1; }
      STEAM_COMMON_PATHS+=("$2")
      shift 2
      ;;
    --backup-before-install)
      BACKUP_BEFORE_INSTALL=true
      shift
      ;;
    --no-backup-before-install)
      BACKUP_BEFORE_INSTALL=false
      shift
      ;;
    --backup-root)
      [[ $# -lt 2 ]] && { echo "Missing value for --backup-root" >&2; exit 1; }
      BACKUP_ROOT="$2"
      shift 2
      ;;
    --install-cet)
      INSTALL_CET=true
      shift
      ;;
    --strict-install)
      STRICT_INSTALL=true
      shift
      ;;
    --no-strict-install)
      STRICT_INSTALL=false
      shift
      ;;
    --pause-for-manual-install)
      PAUSE_FOR_MANUAL_INSTALL=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

trim_path() {
  local p="$1"
  p="${p%/}"
  printf "%s" "$p"
}

ensure_dir() {
  local dir="$1"
  [[ -z "$dir" ]] && return 0
  if [[ -d "$dir" ]]; then
    return 0
  fi
  local parent
  parent="$(dirname "$dir")"
  if [[ "$parent" != "$dir" && ! -d "$parent" ]]; then
    ensure_dir "$parent"
  fi
  mkdir "$dir"
}

is_game_root() {
  local root="$1"
  [[ -f "${root}/bin/x64/Cyberpunk2077.exe" ]]
}

add_unique_path() {
  local p="$1"
  local canonical=""
  [[ -z "$p" ]] && return 0
  if [[ -e "$p" ]]; then
    canonical="$(cd "$p" && pwd -P)"
  else
    return 0
  fi
  for existing in "${STEAM_TRIED[@]:-}"; do
    [[ "$existing" == "$canonical" ]] && return 0
  done
  STEAM_TRIED+=("$canonical")
}

STEAM_TRIED=()
get_steam_common_candidates() {
  local configured=("$@")
  local candidates=()
  local chunk=""

  if [[ -n "${CYBERBUILDER_STEAM_COMMON:-}" ]]; then
    IFS=';' read -r -a env_paths <<< "${CYBERBUILDER_STEAM_COMMON}"
    for chunk in "${env_paths[@]}"; do
      chunk="$(trim_path "$chunk")"
      [[ -n "$chunk" ]] && candidates+=("$chunk")
    done
  fi

  for chunk in "${configured[@]}"; do
    chunk="$(trim_path "$chunk")"
    [[ -n "$chunk" ]] && candidates+=("$chunk")
  done

  local steam_roots=(
    "${HOME}/Library/Application Support/Steam"
    "/Users/Shared/Steam"
  )

  local steam_root=""
  local lib_file=""
  local parsed_paths=()
  for steam_root in "${steam_roots[@]}"; do
    [[ -d "$steam_root" ]] || continue
    lib_file="${steam_root}/steamapps/libraryfolders.vdf"
    if [[ -f "$lib_file" ]]; then
      mapfile -t parsed_paths < <(python3 - "$lib_file" <<'PY'
import re
import sys

path = sys.argv[1]
with open(path, "r", encoding="utf-8", errors="ignore") as f:
    text = f.read()

for m in re.finditer(r'"path"\s+"([^"]+)"', text):
    print(m.group(1).replace("\\\\", "\\"))
PY
)
      for chunk in "${parsed_paths[@]}"; do
        [[ -d "$chunk" ]] || continue
        if [[ -d "${chunk}/steamapps/common" ]]; then
          candidates+=("${chunk}/steamapps/common")
        else
          candidates+=("$chunk")
        fi
      done
    fi

    if [[ -d "${steam_root}/steamapps/common" ]]; then
      candidates+=("${steam_root}/steamapps/common")
    fi
  done

  local out=()
  local c=""
  for c in "${candidates[@]}"; do
    add_unique_path "$c"
  done

  for c in "${STEAM_TRIED[@]:-}"; do
    out+=("$c")
  done
  printf '%s\n' "${out[@]}"
}

resolve_game_root() {
  local explicit="$1"
  shift
  local configured=("$@")

  if [[ -n "$explicit" ]]; then
    explicit="$(trim_path "$explicit")"
    if is_game_root "$explicit"; then
      (cd "$explicit" && pwd -P)
      return 0
    fi
    echo "Game path is set but Cyberpunk2077.exe not found at: ${explicit}/bin/x64/Cyberpunk2077.exe" >&2
    exit 1
  fi

  local libs=()
  mapfile -t libs < <(get_steam_common_candidates "${configured[@]}")
  local lib=""
  for lib in "${libs[@]}"; do
    [[ -n "$lib" ]] || continue
    local candidate="${lib}/Cyberpunk 2077"
    if is_game_root "$candidate"; then
      (cd "$candidate" && pwd -P)
      return 0
    fi
  done

  return 1
}

test_mod_stack_hints() {
  local root="$1"
  local bin_x64="${root}/bin/x64"

  local red4ext=false
  [[ -d "${root}/red4ext" || -d "${bin_x64}/RED4ext" ]] && red4ext=true

  local cet=false
  [[ -d "${bin_x64}/plugins/cyber_engine_tweaks" ]] && cet=true

  local redscript=false
  [[ -d "${root}/r6/cache/modded" || -d "${root}/tools/redscript" || -f "${root}/engine/tools/scc.exe" ]] && redscript=true

  local codeware=false
  [[ -d "${root}/r6/scripts/Codeware" || -f "${root}/archive/pc/mod/Codeware.archive" ]] && codeware=true

  local archivexl=false
  [[ -d "${root}/r6/scripts/ArchiveXL" || -d "${root}/mods/ArchiveXL" ]] && archivexl=true

  local tweakxl=false
  [[ -d "${root}/r6/scripts/TweakXL" || -d "${root}/mods/TweakXL" ]] && tweakxl=true

  local world_builder=false
  [[ -d "${root}/r6/scripts/WorldBuilder" || -d "${root}/mods/World Builder" || -d "${root}/mods/WorldBuilder" ]] && world_builder=true

  cat <<EOF
RED4ext=${red4ext}
CET=${cet}
redscript=${redscript}
Codeware=${codeware}
ArchiveXL=${archivexl}
TweakXL=${tweakxl}
World Builder=${world_builder}
EOF
}

get_wolvenkit_hint() {
  command -v wolvenkit >/dev/null 2>&1 && return 0
  [[ -d "/Applications/WolvenKit.app" ]] && return 0
  return 1
}

backup_cp2077_mod_hotspots() {
  local game_root="$1"
  local backup_parent="$2"
  local stamp
  stamp="$(date +"%Y%m%d-%H%M%S")"
  local dest_root="${backup_parent}/CP2077-pre-mod-${stamp}"

  ensure_dir "$dest_root"

  local copied=()
  local rel_dirs=(
    "red4ext"
    "bin/x64/plugins"
    "mods"
    "archive/pc/mod"
    "r6/scripts"
    "r6/config"
    "r6/tweaks"
  )

  local rel=""
  for rel in "${rel_dirs[@]}"; do
    local src="${game_root}/${rel}"
    [[ -e "$src" ]] || continue
    local dst="${dest_root}/${rel}"
    ensure_dir "$(dirname "$dst")"
    cp -R "$src" "$dst"
    copied+=("$rel")
  done

  local bin_x64="${game_root}/bin/x64"
  local dll_dst_root="${dest_root}/bin/x64"
  local dll=""
  for dll in version.dll winmm.dll dinput8.dll; do
    local fp="${bin_x64}/${dll}"
    [[ -f "$fp" ]] || continue
    ensure_dir "$dll_dst_root"
    cp "$fp" "${dll_dst_root}/${dll}"
    copied+=("bin/x64/${dll}")
  done

  local readme="${dest_root}/README-backup.txt"
  {
    echo "Cyberpunk 2077 modding snapshot (before installing or updating mods)."
    echo "Game root: ${game_root}"
    echo "Created: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    echo
    echo "Folders/files copied (only if they existed):"
    for rel in "${copied[@]}"; do
      echo "  - ${rel}"
    done
    echo
    echo "r6/cache (redscript cache) is not copied - it can be very large; delete or rebuild after restores if needed."
  } > "$readme"

  BACKUP_PATH="$dest_root"
  BACKUP_COPIED=("${copied[@]}")
}

install_cet_from_github() {
  local game_root="$1"
  local api_url="https://api.github.com/repos/yamashi/CyberEngineTweaks/releases/latest"

  if [[ ! -d "${game_root}/bin/x64" ]]; then
    CET_INSTALL_STATUS="invalid_game_root"
    return 0
  fi
  if [[ -d "${game_root}/bin/x64/plugins/cyber_engine_tweaks" ]]; then
    CET_INSTALL_STATUS="already_present"
    return 0
  fi
  if ! command -v curl >/dev/null 2>&1 || ! command -v python3 >/dev/null 2>&1 || ! command -v unzip >/dev/null 2>&1; then
    CET_INSTALL_STATUS="missing_tools"
    return 0
  fi

  local release_json
  if ! release_json="$(curl -fsSL "$api_url")"; then
    CET_INSTALL_STATUS="release_fetch_failed"
    return 0
  fi

  local zip_url
  zip_url="$(python3 - <<'PY' "$release_json"
import json
import re
import sys
obj = json.loads(sys.argv[1])
pick = ""
for a in obj.get("assets", []):
    name = a.get("name", "")
    if not name.lower().endswith(".zip"):
        continue
    if re.search(r"source|symbols|debug|pdb", name, re.I):
        continue
    pick = a.get("browser_download_url", "")
    if pick:
        break
print(pick)
PY
)"
  if [[ -z "$zip_url" ]]; then
    CET_INSTALL_STATUS="zip_asset_not_found"
    return 0
  fi

  local stamp
  stamp="$(date +%s)"
  local zip_path="/tmp/cyberbuilder-cet-${stamp}.zip"
  local extract_dir="/tmp/cyberbuilder-cet-${stamp}-$$"
  ensure_dir "$extract_dir"
  if ! curl -fsSL "$zip_url" -o "$zip_path"; then
    CET_INSTALL_STATUS="download_failed"
    rm -rf "$extract_dir" "$zip_path"
    return 0
  fi
  if ! unzip -oq "$zip_path" -d "$extract_dir"; then
    CET_INSTALL_STATUS="extract_failed"
    rm -rf "$extract_dir" "$zip_path"
    return 0
  fi

  local plugin_dir=""
  plugin_dir="$(python3 - <<'PY' "$extract_dir"
import os
import sys
root = sys.argv[1]
for cur, dirs, _ in os.walk(root):
    for d in dirs:
        if d.lower() == "cyber_engine_tweaks":
            print(os.path.join(cur, d))
            raise SystemExit(0)
print("")
PY
)"
  if [[ -z "$plugin_dir" || ! -d "$plugin_dir" ]]; then
    CET_INSTALL_STATUS="plugin_folder_missing"
    rm -rf "$extract_dir" "$zip_path"
    return 0
  fi

  ensure_dir "${game_root}/bin/x64/plugins"
  rm -rf "${game_root}/bin/x64/plugins/cyber_engine_tweaks"
  cp -R "$plugin_dir" "${game_root}/bin/x64/plugins/cyber_engine_tweaks"

  CET_INSTALL_STATUS="installed"
  rm -rf "$extract_dir" "$zip_path"
}

install_github_zip_component() {
  local repo="$1"
  local preferred_regex="$2"
  local game_root="$3"
  local component_name="$4"
  local api_url="https://api.github.com/repos/${repo}/releases/latest"

  if ! command -v curl >/dev/null 2>&1 || ! command -v python3 >/dev/null 2>&1 || ! command -v unzip >/dev/null 2>&1; then
    return 1
  fi
  local release_json
  if ! release_json="$(curl -fsSL "$api_url")"; then
    return 1
  fi

  local zip_url
  zip_url="$(python3 - <<'PY' "$release_json" "$preferred_regex"
import json, re, sys
obj = json.loads(sys.argv[1])
preferred = re.compile(sys.argv[2], re.I)
assets = obj.get("assets", [])
pick = ""
for a in assets:
    name = a.get("name", "")
    if preferred.search(name):
        pick = a.get("browser_download_url", "")
        if pick:
            break
if not pick:
    for a in assets:
        name = a.get("name", "")
        if not name.lower().endswith(".zip"):
            continue
        if re.search(r"source|symbols|debug|pdb", name, re.I):
            continue
        pick = a.get("browser_download_url", "")
        if pick:
            break
print(pick)
PY
)"
  [[ -n "$zip_url" ]] || return 1

  local stamp
  stamp="$(date +%s)"
  local zip_path="/tmp/cyberbuilder-${component_name// /_}-${stamp}.zip"
  local extract_dir="/tmp/cyberbuilder-${component_name// /_}-${stamp}-$$"
  ensure_dir "$extract_dir"
  curl -fsSL "$zip_url" -o "$zip_path" || { rm -rf "$extract_dir" "$zip_path"; return 1; }
  unzip -oq "$zip_path" -d "$extract_dir" || { rm -rf "$extract_dir" "$zip_path"; return 1; }
  cp -R "${extract_dir}/." "$game_root/" || { rm -rf "$extract_dir" "$zip_path"; return 1; }
  rm -rf "$extract_dir" "$zip_path"
  return 0
}

parse_hints_to_assoc() {
  local lines="$1"
  declare -gA HINTS
  HINTS=()
  local key=""
  local value=""
  while IFS='=' read -r key value; do
    [[ -n "${key}" ]] || continue
    HINTS["$key"]="$value"
  done <<< "$lines"
}

join_by() {
  local sep="$1"
  shift
  local first=true
  local item=""
  for item in "$@"; do
    if $first; then
      printf "%s" "$item"
      first=false
    else
      printf "%s%s" "$sep" "$item"
    fi
  done
}

RESOLVED_GAME_PATH=""
if resolve_out="$(resolve_game_root "$GAME_PATH" "${STEAM_COMMON_PATHS[@]}")"; then
  RESOLVED_GAME_PATH="$resolve_out"
fi

BACKUP_PATH=""
BACKUP_COPIED=()
CET_INSTALL_STATUS="not_requested"
if $BACKUP_BEFORE_INSTALL; then
  if [[ -z "$RESOLVED_GAME_PATH" ]]; then
    echo "Backup requires a resolved game path. Set --game-path or fix Steam discovery (--steam-common-path / CYBERBUILDER_STEAM_COMMON)." >&2
    exit 1
  fi
  ensure_dir "$BACKUP_ROOT"
  backup_cp2077_mod_hotspots "$RESOLVED_GAME_PATH" "$BACKUP_ROOT"
fi
if $INSTALL_CET || $STRICT_INSTALL; then
  if [[ -z "$RESOLVED_GAME_PATH" ]]; then
    echo "Install CET requires a resolved game path. Set --game-path or fix Steam discovery." >&2
    exit 1
  fi
  install_cet_from_github "$RESOLVED_GAME_PATH"
fi

HINTS_RAW=""
declare -A HINTS
if [[ -n "$RESOLVED_GAME_PATH" ]]; then
  if $STRICT_INSTALL; then
    if ! test_mod_stack_hints "$RESOLVED_GAME_PATH" | grep -q '^RED4ext=true$'; then
      install_github_zip_component "WopsS/RED4ext" "\\.zip$" "$RESOLVED_GAME_PATH" "RED4ext" || true
    fi
    if ! test_mod_stack_hints "$RESOLVED_GAME_PATH" | grep -q '^Codeware=true$'; then
      install_github_zip_component "psiberx/cp2077-codeware" "\\.zip$" "$RESOLVED_GAME_PATH" "Codeware" || true
    fi
    if ! test_mod_stack_hints "$RESOLVED_GAME_PATH" | grep -q '^redscript=true$'; then
      install_github_zip_component "jac3km4/redscript" "\\.zip$" "$RESOLVED_GAME_PATH" "redscript" || true
    fi
    if ! test_mod_stack_hints "$RESOLVED_GAME_PATH" | grep -q '^ArchiveXL=true$'; then
      install_github_zip_component "psiberx/cp2077-archive-xl" "\\.zip$" "$RESOLVED_GAME_PATH" "ArchiveXL" || true
    fi
    if ! test_mod_stack_hints "$RESOLVED_GAME_PATH" | grep -q '^TweakXL=true$'; then
      install_github_zip_component "psiberx/cp2077-tweak-xl" "\\.zip$" "$RESOLVED_GAME_PATH" "TweakXL" || true
    fi
    if ! test_mod_stack_hints "$RESOLVED_GAME_PATH" | grep -q '^World Builder=true$'; then
      echo "World Builder requires semi-manual install from Nexus: ${COMPONENT_LINKS[6]}"
      if $OPEN_DOCUMENTATION_LINKS; then
        open "${COMPONENT_LINKS[6]}"
      fi
      if $PAUSE_FOR_MANUAL_INSTALL; then
        read -r -p "Install World Builder manually, then press Enter to continue verification..."
      fi
    fi
  fi
  HINTS_RAW="$(test_mod_stack_hints "$RESOLVED_GAME_PATH")"
  parse_hints_to_assoc "$HINTS_RAW"
fi

WOLVENKIT=false
if get_wolvenkit_hint; then
  WOLVENKIT=true
fi

if $STRICT_INSTALL; then
  if [[ -z "$RESOLVED_GAME_PATH" ]]; then
    echo "Strict install requires resolved game root. Set --game-path or fix Steam discovery." >&2
    exit 2
  fi
  missing=()
  for key in "RED4ext" "CET" "Codeware" "redscript" "ArchiveXL" "TweakXL" "World Builder"; do
    value="${HINTS[$key]:-false}"
    [[ "$value" == "true" ]] || missing+=("$key")
  done
  [[ "$WOLVENKIT" == "true" ]] || missing+=("WolvenKit")
  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "Strict install verification failed. Missing components: $(join_by ", " "${missing[@]}")" >&2
    exit 2
  fi
fi

if $OPEN_DOCUMENTATION_LINKS; then
  for i in "${!COMPONENT_NAMES[@]}"; do
    echo "Opening: ${COMPONENT_NAMES[$i]} -> ${COMPONENT_LINKS[$i]}"
    open "${COMPONENT_LINKS[$i]}"
  done
fi

if $JSON_MODE; then
  STEAM_TRIED_RAW="$(printf "%s\n" "${STEAM_TRIED[@]:-}")"
  BACKUP_COPIED_RAW="$(printf "%s\n" "${BACKUP_COPIED[@]:-}")"
  export STEAM_TRIED_RAW
  export HINTS_RAW
  export BACKUP_COPIED_RAW
  python3 - "$RESOLVED_GAME_PATH" "$WOLVENKIT" "$BACKUP_PATH" "$CET_INSTALL_STATUS" <<'PY'
import json
import os
import sys

resolved = sys.argv[1] if sys.argv[1] else None
wolven = sys.argv[2].lower() == "true"
backup_path = sys.argv[3] if sys.argv[3] else None
cet_install_status = sys.argv[4] if len(sys.argv) > 4 else "not_requested"

component_names = [
    "RED4ext",
    "CET",
    "Codeware",
    "redscript",
    "ArchiveXL",
    "TweakXL",
    "World Builder",
    "WolvenKit",
]
component_links = [
    "https://github.com/WopsS/RED4ext/releases",
    "https://github.com/yamashi/CyberEngineTweaks/releases",
    "https://github.com/psiberx/cp2077-codeware/releases",
    "https://github.com/jac3km4/redscript/releases",
    "https://github.com/psiberx/cp2077-archive-xl/releases",
    "https://github.com/psiberx/cp2077-tweak-xl/releases",
    "https://www.nexusmods.com/cyberpunk2077/mods/20660",
    "https://github.com/WolvenKit/WolvenKit/releases",
]

steam_tried = []
if "STEAM_TRIED_RAW" in os.environ and os.environ["STEAM_TRIED_RAW"].strip():
    steam_tried = [x for x in os.environ["STEAM_TRIED_RAW"].split("\n") if x.strip()]

game_mods = None
if "HINTS_RAW" in os.environ and os.environ["HINTS_RAW"].strip():
    game_mods = {}
    for line in os.environ["HINTS_RAW"].splitlines():
        if "=" not in line:
            continue
        key, value = line.split("=", 1)
        game_mods[key] = value.strip().lower() == "true"

backup_copied = None
if "BACKUP_COPIED_RAW" in os.environ and os.environ["BACKUP_COPIED_RAW"].strip():
    backup_copied = [x for x in os.environ["BACKUP_COPIED_RAW"].split("\n") if x.strip()]

obj = {
    "gamePathResolved": resolved,
    "steamCommonTried": steam_tried,
    "gameMods": game_mods,
    "wolvenKitHeuristic": wolven,
    "links": dict(zip(component_names, component_links)),
    "backupPath": backup_path,
    "backupCopiedRelative": backup_copied,
    "cetInstallStatus": cet_install_status,
}
print(json.dumps(obj, ensure_ascii=False, indent=2))
PY
  exit 0
fi

echo "CyberBuilder prerequisite check (see docs/INSTALL.md)"
echo

if [[ -z "$RESOLVED_GAME_PATH" ]]; then
  echo "Could not auto-detect Cyberpunk 2077. Pass --game-path \"<game root>\" (folder with bin/x64/Cyberpunk2077.exe)."
  echo "Steam: extra steamapps/common paths come from --steam-common-path and CYBERBUILDER_STEAM_COMMON (semicolon-separated)."
else
  echo "Game root: ${RESOLVED_GAME_PATH}"
  echo
  echo "Heuristic presence (false does not mean missing - layout varies by manager):"
  for key in "RED4ext" "CET" "redscript" "Codeware" "ArchiveXL" "TweakXL" "World Builder"; do
    value="${HINTS[$key]:-false}"
    if [[ "$value" == "true" ]]; then
      echo "  ${key}: possibly present"
    else
      echo "  ${key}: not detected"
    fi
  done
fi

if [[ -n "$BACKUP_PATH" ]]; then
  echo
  echo "Backup written to: ${BACKUP_PATH}"
  if [[ ${#BACKUP_COPIED[@]} -gt 0 ]]; then
    echo "  Entries: $(join_by ", " "${BACKUP_COPIED[@]}")"
  fi
fi
if [[ "$CET_INSTALL_STATUS" != "not_requested" ]]; then
  echo
  if [[ "$CET_INSTALL_STATUS" == "installed" ]]; then
    echo "CET install: completed from latest GitHub release."
  elif [[ "$CET_INSTALL_STATUS" == "already_present" ]]; then
    echo "CET install: skipped (already present)."
  else
    echo "CET install: not completed (${CET_INSTALL_STATUS})."
    echo "Manual fallback: ${COMPONENT_LINKS[1]}"
  fi
fi

echo
echo "WolvenKit (install separately): heuristic install found = ${WOLVENKIT}"
echo
echo "Required stack (install order per each upstream README):"
for i in "${!COMPONENT_NAMES[@]}"; do
  printf "  - %-16s %s\n" "${COMPONENT_NAMES[$i]}" "${COMPONENT_LINKS[$i]}"
done

echo
echo "CyberBuilder MVP only validates packs and exports World Builder-oriented outputs; it does not replace any of the above (docs/INSTALL.md)."

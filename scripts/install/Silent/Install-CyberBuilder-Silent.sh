#!/usr/bin/env bash

set -euo pipefail

MODE="all"          # all | prereqs | cyberbuilder
INSTALL_DEPS=false  # if true: allow brew/luarocks installs via ps1 script flags
SKIP_DRY_RUN=false
REPO_ROOT=""
INSTALL_MODE="overlay" # overlay | fresh
NO_BACKUP_BEFORE_INSTALL=false
BACKUP_ROOT=""
GAME_PATH=""
INSTALL_CET=false

usage() {
  cat <<'EOF'
Install-CyberBuilder-Silent.sh

Silent orchestrator for macOS.

Order:
  1) MacOS/Install-CyberBuilderPrereqs.sh
  2) MacOS/Install-CyberBuilder.ps1 (via pwsh)

Options:
  --mode <all|prereqs|cyberbuilder>
  --install-deps
  --skip-dry-run
  --no-backup-before-install
  --backup-root <path>
  --game-path <path>
  --install-cet
  --install-mode <overlay|fresh>
  --repo-root <path>
  -h, --help

Examples:
  ./docs/scripts/install/Install-CyberBuilder-Silent.sh
  ./docs/scripts/install/Install-CyberBuilder-Silent.sh --install-deps
  ./docs/scripts/install/Install-CyberBuilder-Silent.sh --mode cyberbuilder --skip-dry-run
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)
      [[ $# -lt 2 ]] && { echo "Missing value for --mode" >&2; exit 1; }
      MODE="$2"
      shift 2
      ;;
    --install-deps)
      INSTALL_DEPS=true
      shift
      ;;
    --skip-dry-run)
      SKIP_DRY_RUN=true
      shift
      ;;
    --no-backup-before-install)
      NO_BACKUP_BEFORE_INSTALL=true
      shift
      ;;
    --backup-root)
      [[ $# -lt 2 ]] && { echo "Missing value for --backup-root" >&2; exit 1; }
      BACKUP_ROOT="$2"
      shift 2
      ;;
    --game-path)
      [[ $# -lt 2 ]] && { echo "Missing value for --game-path" >&2; exit 1; }
      GAME_PATH="$2"
      shift 2
      ;;
    --install-cet)
      INSTALL_CET=true
      shift
      ;;
    --install-mode)
      [[ $# -lt 2 ]] && { echo "Missing value for --install-mode" >&2; exit 1; }
      INSTALL_MODE="$2"
      shift 2
      ;;
    --repo-root)
      [[ $# -lt 2 ]] && { echo "Missing value for --repo-root" >&2; exit 1; }
      REPO_ROOT="$2"
      shift 2
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

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This .sh orchestrator is intended for macOS (Darwin). Use the PowerShell orchestrator on Windows." >&2
  exit 2
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
install_root="$(cd "${script_dir}/.." && pwd -P)"
mac_dir="${install_root}/MacOS"
PREREQS_RAN=false

if [[ -z "${REPO_ROOT}" ]]; then
  # scripts/install/Silent -> repo root = ../..
  REPO_ROOT="$(cd "${script_dir}/../.." && pwd -P)"
fi

case "$INSTALL_MODE" in
  overlay|fresh) ;;
  *)
    echo "Invalid --install-mode: $INSTALL_MODE" >&2
    usage
    exit 1
    ;;
esac

run_prereqs() {
  local sh="${mac_dir}/Install-CyberBuilderPrereqs.sh"
  if [[ -f "$sh" ]]; then
    echo "-> $sh"
    local pr_args=()
    $NO_BACKUP_BEFORE_INSTALL && pr_args+=("--no-backup-before-install")
    [[ -n "$BACKUP_ROOT" ]] && pr_args+=("--backup-root" "$BACKUP_ROOT")
    [[ -n "$GAME_PATH" ]] && pr_args+=("--game-path" "$GAME_PATH")
    ($INSTALL_CET || [[ "$INSTALL_MODE" == "fresh" ]]) && pr_args+=("--install-cet")
    bash "$sh" "${pr_args[@]}"
    PREREQS_RAN=true
  else
    echo "Missing prereqs script: $sh" >&2
    exit 1
  fi
}

run_cyberbuilder() {
  local ps1="${mac_dir}/Install-CyberBuilder.ps1"
  if [[ ! -f "$ps1" ]]; then
    echo "Missing CyberBuilder script: $ps1" >&2
    exit 1
  fi
  if ! command -v pwsh >/dev/null 2>&1; then
    echo "pwsh (PowerShell 7+) is required on macOS to run: $ps1" >&2
    exit 1
  fi

  local args=("-NoProfile" "-File" "$ps1" "-RepoRoot" "$REPO_ROOT")
  args+=("-InstallMode" "$INSTALL_MODE")
  $PREREQS_RAN && args+=("-NoBackupBeforeInstall")
  [[ -n "$BACKUP_ROOT" ]] && args+=("-BackupRoot" "$BACKUP_ROOT")
  [[ -n "$GAME_PATH" ]] && args+=("-GamePath" "$GAME_PATH")
  ($INSTALL_CET || [[ "$INSTALL_MODE" == "fresh" ]]) && args+=("-InstallCET")
  if $SKIP_DRY_RUN; then
    args+=("-SkipDryRun")
  fi
  if $INSTALL_DEPS || [[ "$INSTALL_MODE" == "fresh" ]]; then
    args+=("-InstallLua" "-InstallLfs")
  fi

  echo "-> pwsh ${ps1}"
  pwsh "${args[@]}"
}

case "$MODE" in
  all)
    run_prereqs
    run_cyberbuilder
    ;;
  prereqs)
    run_prereqs
    ;;
  cyberbuilder)
    run_cyberbuilder
    ;;
  *)
    echo "Invalid --mode: $MODE" >&2
    usage
    exit 1
    ;;
esac

echo "Done."


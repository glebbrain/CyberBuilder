#!/usr/bin/env bash

set -euo pipefail

INSTALL_MODE="overlay" # overlay | fresh
INSTALL_DEPS=false
SKIP_DRY_RUN=false
GAME_PATH=""
BACKUP_ROOT=""
REPO_ROOT=""
INSTALL_CET=false

usage() {
  cat <<'EOF'
Install-CyberBuilder-WithBackup.sh

macOS installer wrapper with mandatory backup.

Sequence:
  1) MacOS/Install-CyberBuilderPrereqs.sh --backup-before-install
  2) MacOS/Install-CyberBuilder.ps1

Options:
  --install-mode <overlay|fresh>
  --install-deps
  --skip-dry-run
  --game-path <path>
  --backup-root <path>
  --repo-root <path>
  --install-cet
  -h, --help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --install-mode)
      [[ $# -lt 2 ]] && { echo "Missing value for --install-mode" >&2; exit 1; }
      INSTALL_MODE="$2"
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
    --game-path)
      [[ $# -lt 2 ]] && { echo "Missing value for --game-path" >&2; exit 1; }
      GAME_PATH="$2"
      shift 2
      ;;
    --backup-root)
      [[ $# -lt 2 ]] && { echo "Missing value for --backup-root" >&2; exit 1; }
      BACKUP_ROOT="$2"
      shift 2
      ;;
    --repo-root)
      [[ $# -lt 2 ]] && { echo "Missing value for --repo-root" >&2; exit 1; }
      REPO_ROOT="$2"
      shift 2
      ;;
    --install-cet)
      INSTALL_CET=true
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

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This script is intended for macOS (Darwin)." >&2
  exit 2
fi

case "$INSTALL_MODE" in
  overlay|fresh) ;;
  *)
    echo "Invalid --install-mode: $INSTALL_MODE" >&2
    exit 1
    ;;
esac

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
mac_dir="${script_dir}/MacOS"

if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "${script_dir}/../.." && pwd -P)"
fi

pr_script="${mac_dir}/Install-CyberBuilderPrereqs.sh"
cb_script="${mac_dir}/Install-CyberBuilder.ps1"

[[ -f "$pr_script" ]] || { echo "Missing script: $pr_script" >&2; exit 1; }
[[ -f "$cb_script" ]] || { echo "Missing script: $cb_script" >&2; exit 1; }
command -v pwsh >/dev/null 2>&1 || { echo "pwsh is required for $cb_script" >&2; exit 1; }

pr_args=("--backup-before-install")
[[ -n "$GAME_PATH" ]] && pr_args+=("--game-path" "$GAME_PATH")
[[ -n "$BACKUP_ROOT" ]] && pr_args+=("--backup-root" "$BACKUP_ROOT")
($INSTALL_CET || [[ "$INSTALL_MODE" == "fresh" ]]) && pr_args+=("--install-cet")

echo "-> $pr_script"
bash "$pr_script" "${pr_args[@]}"

cb_args=("-NoProfile" "-File" "$cb_script" "-RepoRoot" "$REPO_ROOT" "-InstallMode" "$INSTALL_MODE" "-NoBackupBeforeInstall")
[[ -n "$GAME_PATH" ]] && cb_args+=("-GamePath" "$GAME_PATH")
[[ -n "$BACKUP_ROOT" ]] && cb_args+=("-BackupRoot" "$BACKUP_ROOT")
$SKIP_DRY_RUN && cb_args+=("-SkipDryRun")
if $INSTALL_DEPS || [[ "$INSTALL_MODE" == "fresh" ]]; then
  cb_args+=("-InstallLua" "-InstallLfs")
fi

echo "-> pwsh $cb_script"
pwsh "${cb_args[@]}"

echo "Done (with backup)."


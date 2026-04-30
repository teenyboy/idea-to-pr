#!/usr/bin/env bash
# git-platform/api.sh — Platform-agnostic git PR/repo operations
#
# Usage:
#   git-platform/api.sh pr view <number> [--json fields] [--jq filter]
#   git-platform/api.sh pr diff <number>
#   git-platform/api.sh pr create --title <title> --body-file <path> --base <branch>
#   git-platform/api.sh pr edit <number> --body-file <path>
#   git-platform/api.sh pr ready <number>
#   git-platform/api.sh pr list --head <branch> [--json fields]
#   git-platform/api.sh pr checks <number> [--json fields]
#   git-platform/api.sh pr comment <number> --body <text>
#   git-platform/api.sh repo view [--json fields] [--jq filter]
#
# Config:
#   git-platform/config contains the platform name (github|gitlab|bitbucket|local)
#   Default: github

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLATFORM=$(cat "$SCRIPT_DIR/config" 2>/dev/null || echo "github")
ADAPTER="$SCRIPT_DIR/adapters/${PLATFORM}.sh"

if [ ! -f "$ADAPTER" ]; then
  echo "ERROR: No adapter found for platform '$PLATFORM' at $ADAPTER" >&2
  echo "Available platforms:" >&2
  for f in "$SCRIPT_DIR/adapters/"*.sh; do
    name=$(basename "$f" .sh)
    echo "  - $name" >&2
  done
  exit 1
fi

# shellcheck disable=SC1090
source "$ADAPTER"

DOMAIN="${1:?Usage: api.sh <pr|repo> <action> [args...]}"
ACTION="${2:?Usage: api.sh <domain> <action> [args...]}"
shift 2

case "$DOMAIN" in
  pr)
    case "$ACTION" in
      view|diff|create|edit|ready|list|checks|comment)
        "platform_pr_${ACTION}" "$@"
        ;;
      *)
        echo "ERROR: Unknown pr action: $ACTION" >&2
        echo "Valid: view diff create edit ready list checks comment" >&2
        exit 1
        ;;
    esac
    ;;
  repo)
    case "$ACTION" in
      view) platform_repo_view "$@" ;;
      *)
        echo "ERROR: Unknown repo action: $ACTION" >&2
        echo "Valid: view" >&2
        exit 1
        ;;
    esac
    ;;
  *)
    echo "ERROR: Unknown domain: $DOMAIN" >&2
    echo "Usage: api.sh <pr|repo> <action> [args...]" >&2
    exit 1
    ;;
esac

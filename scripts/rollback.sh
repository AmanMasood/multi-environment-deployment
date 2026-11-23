#!/usr/bin/env bash
# Manually roll an environment back to the previous (or a named) successful version.
#   rollback.sh <environment> [version]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENVIRONMENT="${1:?environment required}"
STATE_DIR="${STATE_DIR:-$ROOT/.deployments}"
HISTORY_FILE="$STATE_DIR/${ENVIRONMENT}.history"
CURRENT="$(cat "$STATE_DIR/${ENVIRONMENT}.current" 2>/dev/null || true)"

if [[ -n "${2:-}" ]]; then
  TARGET="$2"
else
  # newest successfully deployed version that is not the current one
  TARGET="$(awk '$3=="deployed"{print $4}' "$HISTORY_FILE" 2>/dev/null | tac | grep -vx "${CURRENT:-__none__}" | head -1 || true)"
fi
[[ -n "${TARGET:-}" ]] || { echo "no previous version to roll back to" >&2; exit 1; }

echo "==> rolling ${ENVIRONMENT} back from ${CURRENT:-none} to ${TARGET}"
ALLOW_UNTESTED=true "$ROOT/scripts/deploy.sh" "$ENVIRONMENT" "$TARGET"

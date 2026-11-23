#!/usr/bin/env bash
# Show what is running in every environment.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STATE_DIR="${STATE_DIR:-$ROOT/.deployments}"
printf '%-12s %-10s %-8s %s\n' ENVIRONMENT VERSION PORT HEALTH
for env in dev staging production; do
  # shellcheck disable=SC1090
  source "$ROOT/environments/${env}.env"
  v="$(cat "$STATE_DIR/${env}.current" 2>/dev/null || echo '-')"
  h="$(curl -fsS -m 2 "http://localhost:${HTTP_PORT}/health" >/dev/null 2>&1 && echo up || echo down)"
  printf '%-12s %-10s %-8s %s\n' "$env" "$v" "$HTTP_PORT" "$h"
done

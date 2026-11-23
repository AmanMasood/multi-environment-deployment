#!/usr/bin/env bash
# Unit tests for deploy/rollback logic using fake docker + curl (no daemon needed).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export FAKE_STATE STATE_DIR
FAKE_STATE="$(mktemp -d)"; STATE_DIR="$(mktemp -d)"
trap 'rm -rf "$FAKE_STATE" "$STATE_DIR"' EXIT
export PATH="$ROOT/tests/fakes:$PATH" HEALTH_RETRIES=2 HEALTH_INTERVAL=0
chmod +x "$ROOT"/tests/fakes/*
cur() { cat "$STATE_DIR/$1.current"; }
running() { cat "$FAKE_STATE/$1.running"; }

echo "1) deploy 1.0.0 to dev and staging"
"$ROOT/scripts/deploy.sh" dev 1.0.0 >/dev/null
"$ROOT/scripts/deploy.sh" staging 1.0.0 >/dev/null
[[ "$(cur dev)" == 1.0.0 && "$(cur staging)" == 1.0.0 ]]

echo "2) production only accepts what staging runs"
if "$ROOT/scripts/deploy.sh" production 9.9.9 2>/dev/null; then echo "should refuse"; exit 1; fi
"$ROOT/scripts/deploy.sh" production 1.0.0 >/dev/null
grep -q "docker-compose.production.yml" "$FAKE_STATE/calls.log"

echo "3) broken release auto-rolls back"
echo "2.0.0" > "$FAKE_STATE/broken_versions"
if "$ROOT/scripts/deploy.sh" staging 2.0.0 2>/dev/null; then echo "broken release reported success"; exit 1; fi
[[ "$(running staging)" == 1.0.0 ]] || { echo "staging not rolled back"; exit 1; }
[[ "$(cur staging)" == 1.0.0 ]]
grep -q "staging rollback 1.0.0" "$STATE_DIR/staging.history"

echo "4) manual rollback to previous good version"
"$ROOT/scripts/deploy.sh" dev 1.1.0 >/dev/null
"$ROOT/scripts/rollback.sh" dev >/dev/null
[[ "$(cur dev)" == 1.0.0 && "$(running dev)" == 1.0.0 ]]

echo "5) unknown environment rejected"
if "$ROOT/scripts/deploy.sh" qa 1.0.0 2>/dev/null; then exit 1; fi

echo "All deploy tests passed"

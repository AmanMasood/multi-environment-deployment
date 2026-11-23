#!/usr/bin/env bash
# Deploy a version to an environment with health checking and automatic rollback.
#   deploy.sh <dev|staging|production> <version>
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENVIRONMENT="${1:?environment required: dev|staging|production}"
VERSION="${2:?version required}"
IMAGE="${IMAGE:-multienv-app}"
HEALTH_RETRIES="${HEALTH_RETRIES:-20}"
HEALTH_INTERVAL="${HEALTH_INTERVAL:-3}"
STATE_DIR="${STATE_DIR:-$ROOT/.deployments}"

case "$ENVIRONMENT" in dev|staging|production) ;; *) echo "unknown environment: $ENVIRONMENT" >&2; exit 2 ;; esac
ENV_FILE="$ROOT/environments/${ENVIRONMENT}.env"
# shellcheck disable=SC1090
source "$ENV_FILE"

mkdir -p "$STATE_DIR"
CURRENT_FILE="$STATE_DIR/${ENVIRONMENT}.current"
HISTORY_FILE="$STATE_DIR/${ENVIRONMENT}.history"
PREVIOUS="$(cat "$CURRENT_FILE" 2>/dev/null || true)"

compose() {
  local files=(-f "$ROOT/docker-compose.yml")
  [[ "$ENVIRONMENT" == "production" ]] && files+=(-f "$ROOT/docker-compose.production.yml")
  APP_ENV="$ENVIRONMENT" APP_VERSION="$1" IMAGE="$IMAGE" HTTP_PORT="$HTTP_PORT" \
    docker compose -p "$ENVIRONMENT" "${files[@]}" "${@:2}"
}

healthy() {
  for _ in $(seq 1 "$HEALTH_RETRIES"); do
    if curl -fsS "http://localhost:${HTTP_PORT}/health" >/dev/null 2>&1; then return 0; fi
    sleep "$HEALTH_INTERVAL"
  done
  return 1
}

record() { echo "$(date -Iseconds) $ENVIRONMENT $1 $2" >> "$HISTORY_FILE"; }

if [[ "$ENVIRONMENT" == "production" && "${ALLOW_UNTESTED:-false}" != "true" ]]; then
  STAGING_VERSION="$(cat "$STATE_DIR/staging.current" 2>/dev/null || true)"
  if [[ "$STAGING_VERSION" != "$VERSION" ]]; then
    echo "refusing: $VERSION is not the version running in staging (${STAGING_VERSION:-none})" >&2
    exit 3
  fi
fi

echo "==> deploying ${IMAGE}:${VERSION} to ${ENVIRONMENT} (port ${HTTP_PORT}, previous: ${PREVIOUS:-none})"
compose "$VERSION" up -d --remove-orphans --wait || true

if healthy; then
  echo "$VERSION" > "$CURRENT_FILE"
  record deployed "$VERSION"
  echo "==> ${ENVIRONMENT} is healthy on ${VERSION}"
  exit 0
fi

echo "!! ${VERSION} failed health checks in ${ENVIRONMENT}" >&2
record failed "$VERSION"
if [[ -n "$PREVIOUS" ]]; then
  echo "==> rolling back to ${PREVIOUS}" >&2
  compose "$PREVIOUS" up -d --remove-orphans --wait || true
  if healthy; then record rollback "$PREVIOUS"; echo "==> rollback to ${PREVIOUS} succeeded" >&2; fi
fi
exit 1

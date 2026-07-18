#!/usr/bin/env bash
# Documented rollback procedure for FormFlow.
#
# Rolls a single tier (or both) back to a specific, already-built, already-pushed
# image tag. Never rebuilds. Never touches `main`. Never restarts the db.
#
# Usage:
#   ./rollback.sh backend  sha-a1b2c3d
#   ./rollback.sh frontend sha-e4f5g6h
#   ./rollback.sh all      sha-a1b2c3d      # roll both tiers to the same tag

set -euo pipefail

SERVICE="${1:-}"
TAG="${2:-}"

if [ -z "$SERVICE" ] || [ -z "$TAG" ]; then
  echo "Usage: $0 <backend|frontend|all> <sha-tag>"
  echo "Known previous versions:"
  tail -n 10 CURRENT_VERSION 2>/dev/null || echo "  (no CURRENT_VERSION history found)"
  exit 1
fi

cd "$(dirname "$0")/.."

case "$SERVICE" in
  backend)
    export BACKEND_TAG="$TAG"
    TARGETS="backend"
    ;;
  frontend)
    export FRONTEND_TAG="$TAG"
    TARGETS="frontend"
    ;;
  all)
    export BACKEND_TAG="$TAG"
    export FRONTEND_TAG="$TAG"
    TARGETS="backend frontend"
    ;;
  *)
    echo "Unknown service: $SERVICE (expected backend, frontend, or all)"
    exit 1
    ;;
esac

echo "Rolling back [$TARGETS] to $TAG ..."
docker compose --env-file .env pull $TARGETS
docker compose --env-file .env up -d --no-deps $TARGETS

echo "Waiting for health check..."
for i in $(seq 1 10); do
  if curl -sf http://localhost/api/version > /dev/null; then
    break
  fi
  echo "  waiting ($i/10)..."
  sleep 3
done

LIVE=$(curl -sf http://localhost/api/version | grep -o '"gitSha":"[^"]*"' | cut -d'"' -f4)
echo "Backend now reports version: $LIVE"

if [[ "$TARGETS" == *backend* && "$LIVE" != "$TAG" ]]; then
  echo "ROLLBACK VERIFICATION FAILED: expected $TAG, got $LIVE"
  exit 1
fi

echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) ROLLBACK service=$SERVICE tag=$TAG operator=$(whoami)" >> CURRENT_VERSION
echo "Rollback complete and verified."

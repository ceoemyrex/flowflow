#!/usr/bin/env bash
# Initial / manual deploy helper. CI calls the equivalent steps directly over SSH (see
# .github/workflows/deploy.yml); this script exists so a human can reproduce the exact
# same deploy locally on the VM without guessing the commands.
#
# Usage: ./deploy.sh <sha-tag>
# Example: ./deploy.sh sha-a1b2c3d

set -euo pipefail

if [ -z "${1:-}" ]; then
  echo "Usage: $0 <sha-tag>"
  exit 1
fi

TAG="$1"
cd "$(dirname "$0")/.."

export BACKEND_TAG="$TAG"
export FRONTEND_TAG="$TAG"

echo "Pulling $TAG for backend and frontend..."
docker compose --env-file .env pull backend frontend

echo "Restarting backend and frontend only (db untouched)..."
docker compose --env-file .env up -d --no-deps backend frontend

echo "Waiting for health..."
for i in $(seq 1 10); do
  if curl -sf http://localhost/api/version > /dev/null; then
    echo "Backend is up."
    break
  fi
  sleep 3
done

LIVE=$(curl -sf http://localhost/api/version | grep -o '"gitSha":"[^"]*"' | cut -d'"' -f4)
echo "Live version now reports: $LIVE"

if [ "$LIVE" != "$TAG" ]; then
  echo "WARNING: requested $TAG but backend reports $LIVE"
  exit 1
fi

echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) DEPLOY backend=$TAG frontend=$TAG operator=$(whoami)" >> CURRENT_VERSION
echo "Done."

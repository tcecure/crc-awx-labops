#!/usr/bin/env bash
# Refuses to start the agent server unless the local image matches the digest pinned in
# compose/docker-compose.yml. Guards against a floating tag or a tampered local image.
set -euo pipefail

COMPOSE="$(dirname "$0")/../compose/docker-compose.yml"
PINNED="$(grep -oE 'ghcr\.io/openhands/agent-server:[^ ]+@sha256:[0-9a-f]{64}' "$COMPOSE" | head -1)"
[ -n "$PINNED" ] || { echo "no digest-pinned image found in $COMPOSE" >&2; exit 1; }

DIGEST="${PINNED##*@}"

if ! docker image inspect "$PINNED" >/dev/null 2>&1; then
  echo "pulling $PINNED"
  docker pull "$PINNED"
fi

LOCAL="$(docker image inspect "$PINNED" --format '{{index .RepoDigests 0}}' | sed 's/.*@//')"
if [ "$LOCAL" != "$DIGEST" ]; then
  echo "image digest mismatch: expected $DIGEST, got $LOCAL" >&2
  exit 1
fi

echo "agent-server image pin verified: $DIGEST"

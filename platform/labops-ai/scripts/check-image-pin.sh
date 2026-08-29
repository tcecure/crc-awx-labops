#!/usr/bin/env bash
# Refuses to start an investigation unless the local agent-server image matches the pinned
# digest. Guards against a floating tag or a tampered local image.
#
# Since Phase 2 the agent no longer runs as a long-lived compose service: the image is pinned
# in the gateway environment (LABOPS_AGENT_IMAGE) and one container is created per
# investigation, so the pin is read from there, with the committed template as a fallback.
set -euo pipefail

HERE="$(dirname "$0")"
PINNED="${LABOPS_AGENT_IMAGE:-}"
if [ -z "$PINNED" ] && [ -r /etc/labops/gateway.env ]; then
  PINNED="$(sed -n 's/^LABOPS_AGENT_IMAGE=//p' /etc/labops/gateway.env | head -1)"
fi
if [ -z "$PINNED" ]; then
  PINNED="$(sed -n 's/^LABOPS_AGENT_IMAGE=//p' "$HERE/../env/gateway.env.example" | head -1)"
fi
case "$PINNED" in
  *@sha256:*) : ;;
  *) echo "agent image is not digest-pinned: '${PINNED:-<unset>}'" >&2; exit 1 ;;
esac

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

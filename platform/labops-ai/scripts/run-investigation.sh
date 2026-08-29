#!/usr/bin/env bash
# Create / destroy one ephemeral investigation container, per
# docs/phase2/03-investigation-isolation.md. This is the reference implementation of the
# runtime contract the gateway must honour, and the harness the isolation tests drive.
#
#   run-investigation.sh start  <run_id>
#   run-investigation.sh stop   <run_id> [--keep-volume]
#   run-investigation.sh port   <run_id>
#
# The container gets agent.env and a per-run proxy token — never the gateway environment,
# never a host mount, never the Docker socket, never the provider API key.
set -euo pipefail

AGENT_IMAGE="${LABOPS_AGENT_IMAGE:-ghcr.io/openhands/agent-server:1.42.1-python@sha256:141a3628925a18ad55f07a09c0a1e3db9852ab0043458dbe7c8003c92396d143}"
AGENT_ENV="${LABOPS_AGENT_ENV_FILE:-/etc/labops/agent.env}"
NET="${LABOPS_MODEL_NET:-compose_labops-model}"
PROXY="${LABOPS_MODEL_PROXY:-172.31.241.2:8081}"

usage() { sed -n '2,12p' "$0"; exit 64; }
[ $# -ge 2 ] || usage
action="$1"; run_id="$2"; shift 2

# uuid only: the id becomes a container and volume name, and the proxy requires the same form
case "$run_id" in
  [0-9a-f-][0-9a-f-]*) [ ${#run_id} -eq 36 ] || { echo "run id must be a uuid" >&2; exit 64; } ;;
  *) echo "run id must be a uuid" >&2; exit 64 ;;
esac

name="labops-inv-${run_id}"
vol="labops-inv-${run_id}"

case "$action" in
start)
  # The proxy token is read from the proxy's own env file by the gateway and passed here as an
  # argument-free environment variable; it is worthless outside labops-model.
  : "${LABOPS_MODEL_PROXY_TOKEN:?must be exported by the caller (gateway), not stored in agent.env}"

  docker volume create "$vol" >/dev/null
  # uid 10001 owns the workspace, otherwise the read-only rootfs makes the first write fail
  docker run --rm -v "$vol":/w alpine:3 chown 10001:10001 /w >/dev/null

  docker run -d \
    --name "$name" \
    --hostname "inv-${run_id%%-*}" \
    --network "$NET" \
    --env-file "$AGENT_ENV" \
    --env "LABOPS_RUN_ID=${run_id}" \
    --env "LABOPS_LLM_BASE_URL=http://${PROXY}/v1" \
    --env "LABOPS_MODEL_PROXY_TOKEN=${LABOPS_MODEL_PROXY_TOKEN}" \
    --user 10001:10001 \
    --read-only \
    --tmpfs /tmp:size=512m,mode=1777,exec \
    --tmpfs /home/openhands/.config:size=64m,mode=0700,uid=10001,gid=10001 \
    --tmpfs /home/openhands/.cache:size=256m,mode=0700,uid=10001,gid=10001 \
    -v "$vol":/workspace \
    --security-opt no-new-privileges:true \
    --cap-drop ALL \
    --cpus 2 --memory 4g --memory-swap 4g --pids-limit 512 \
    --log-driver json-file --log-opt max-size=20m --log-opt max-file=3 \
    --label labops.role=investigation \
    --label "labops.run_id=${run_id}" \
    "$AGENT_IMAGE" >/dev/null

  # Fail closed rather than hand a mis-provisioned sandbox to an investigation.
  binds=$(docker inspect -f '{{json .HostConfig.Binds}}' "$name")
  case "$binds" in *'/var/run/docker.sock'*|*'":/host'*|*'"/etc'*)
    docker rm -f "$name" >/dev/null; echo "refusing: host mount in $binds" >&2; exit 70 ;;
  esac
  nets=$(docker inspect -f '{{range $k,$v := .NetworkSettings.Networks}}{{$k}} {{end}}' "$name")
  [ "$(echo "$nets" | wc -w)" -eq 1 ] || { docker rm -f "$name" >/dev/null; echo "refusing: extra networks: $nets" >&2; exit 70; }
  echo "$name"
  ;;

stop)
  docker rm -f "$name" >/dev/null 2>&1 || true
  if [ "${1:-}" != "--keep-volume" ]; then
    # retention policy: the workspace is destroyed with the run; findings already live in
    # Supabase, and nothing else in the volume may outlive the investigation
    docker volume rm -f "$vol" >/dev/null 2>&1 || true
  fi
  echo "stopped $name"
  ;;

port)
  # the gateway reaches the container over labops-model; no port is ever published
  docker inspect -f "{{(index .NetworkSettings.Networks \"$NET\").IPAddress}}:8000" "$name"
  ;;

*) usage ;;
esac

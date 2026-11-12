#!/usr/bin/env bash
# Create / inspect / destroy one ephemeral investigation container, per
# docs/phase2/03-investigation-isolation.md. The gateway drives this script — it is the only
# thing on the host allowed to create an investigation container, so the gateway process
# needs no Docker socket of its own and the arguments it may pass are a subcommand and a
# run id.
#
#   run-investigation.sh start   <run_id> [--json]
#   run-investigation.sh inspect <run_id> [--json]     exit 68 when there is no container
#   run-investigation.sh stop    <run_id> [--keep-volume]
#   run-investigation.sh port    <run_id>
#   run-investigation.sh list                          run ids with a container present
#
# The container gets agent.env and the model-proxy token — never the gateway environment,
# never a host mount, never the Docker socket, never the provider API key.
set -euo pipefail

AGENT_IMAGE="${LABOPS_AGENT_IMAGE:-ghcr.io/openhands/agent-server:1.42.1-python@sha256:141a3628925a18ad55f07a09c0a1e3db9852ab0043458dbe7c8003c92396d143}"
AGENT_ENV="${LABOPS_AGENT_ENV_FILE:-/etc/labops/agent.env}"
PROXY_ENV="${LABOPS_MODEL_PROXY_ENV_FILE:-/etc/labops/model-proxy.env}"
NET="${LABOPS_MODEL_NET:-compose_labops-model}"
PROXY="${LABOPS_MODEL_PROXY:-172.31.241.2:8081}"

usage() { sed -n '2,16p' "$0"; exit 64; }
[ $# -ge 1 ] || usage
action="$1"; shift

if [ "$action" = "list" ]; then
  # One line per investigation container, running or not, so the gateway can reap a
  # workspace whose run is already terminal.
  docker ps -aq --filter label=labops.role=investigation |
    while read -r id; do
      [ -n "$id" ] || continue
      docker inspect -f '{{index .Config.Labels "labops.run_id"}}' "$id" || true
    done
  exit 0
fi

[ $# -ge 1 ] || usage
run_id="$1"; shift

# uuid only: the id becomes a container and volume name, and the proxy requires the same form
case "$run_id" in
  [0-9a-f-][0-9a-f-]*) [ ${#run_id} -eq 36 ] || { echo "run id must be a uuid" >&2; exit 64; } ;;
  *) echo "run id must be a uuid" >&2; exit 64 ;;
esac

name="labops-inv-${run_id}"
vol="labops-inv-${run_id}"

# `ip:port` on labops-model. Empty when the container is gone or has left the network.
endpoint() {
  local ip
  ip=$(docker inspect -f "{{(index .NetworkSettings.Networks \"$NET\").IPAddress}}" "$name" 2>/dev/null || true)
  [ -n "$ip" ] && echo "${ip}:8000"
  return 0
}

# The machine-readable form the gateway parses. No secret is ever part of it.
emit_json() {
  local ip running
  running=$(docker inspect -f '{{.State.Running}}' "$name")
  ip=$(endpoint)
  printf '{"run_id":"%s","container":"%s","volume":"%s","image":"%s","endpoint":"%s","running":%s}\n' \
    "$run_id" "$name" "$vol" "$AGENT_IMAGE" "$ip" "$running"
}

case "$action" in
start)
  # The proxy token is not a provider credential: the proxy swaps it for the real key
  # upstream, so it is worthless anywhere except labops-model. Accepted from the caller's
  # environment, and otherwise read — as root — from the proxy's own env file, so the
  # gateway never needs to hold it.
  if [ -z "${LABOPS_MODEL_PROXY_TOKEN:-}" ] && [ -r "$PROXY_ENV" ]; then
    LABOPS_MODEL_PROXY_TOKEN=$(sed -n 's/^LABOPS_MODEL_PROXY_TOKEN=//p' "$PROXY_ENV" | tail -n1)
  fi
  : "${LABOPS_MODEL_PROXY_TOKEN:?must come from the caller or ${PROXY_ENV}, never from agent.env}"

  docker rm -f "$name" >/dev/null 2>&1 || true
  docker volume rm -f "$vol" >/dev/null 2>&1 || true
  docker volume create "$vol" >/dev/null
  # uid 10001 owns the workspace, otherwise the read-only rootfs makes the first write fail.
  # The run mounts it with volume-nocopy so this ownership stands: copying the image's own
  # /workspace into a fresh volume happens after the chown and would restore root ownership.
  # The chown runs in the pinned agent image itself: the host cannot reach docker.io under the
  # egress allow-list, and a floating helper tag would be an unpinned image in the path.
  #
  # The same pass lists the container- and namespace-manipulation tooling the image ships and
  # the agent never needs: none of it is usable without the docker socket or a capability to
  # gain, but a read-only rootfs cannot be pruned at runtime, so each one is masked with a
  # non-executable bind. Paths are resolved inside the image, and a command backed by a
  # multi-call binary is left alone — masking that file would take the shell down with it.
  mask_paths=$(docker run --rm --user 0:0 --entrypoint sh -v "$vol":/w "$AGENT_IMAGE" -c '
    chown 10001:10001 /w
    for b in docker nsenter runc ctr sudo su; do
      p=$(command -v "$b" 2>/dev/null) || continue
      [ -n "$p" ] || continue
      real=$(readlink -f "$p")
      [ "${real##*/}" = "$b" ] || continue
      echo "$real"
    done')

  MASKS=""
  for p in $mask_paths; do
    case "$p" in /*[!\ ]) MASKS="$MASKS -v /dev/null:$p:ro" ;; esac
  done

  docker run -d \
    --name "$name" \
    --hostname "inv-${run_id%%-*}" \
    --network "$NET" \
    --env-file "$AGENT_ENV" \
    --env "LABOPS_RUN_ID=${run_id}" \
    --env "LABOPS_LLM_BASE_URL=http://${PROXY}/r/${run_id}/v1" \
    --env "LABOPS_MODEL_PROXY_TOKEN=${LABOPS_MODEL_PROXY_TOKEN}" \
    --user 10001:10001 \
    --read-only \
    --tmpfs /tmp:size=512m,mode=1777,exec \
    --tmpfs /home/openhands/.config:size=64m,mode=0700,uid=10001,gid=10001 \
    --tmpfs /home/openhands/.cache:size=256m,mode=0700,uid=10001,gid=10001 \
    --tmpfs /home/openhands/.openhands:size=64m,mode=0700,uid=10001,gid=10001 \
    --mount "type=volume,source=$vol,target=/workspace,volume-nocopy=true" \
    $MASKS \
    --security-opt no-new-privileges:true \
    --cap-drop ALL \
    --cpus 2 --memory 4g --memory-swap 4g --pids-limit 512 \
    --log-driver json-file --log-opt max-size=20m --log-opt max-file=3 \
    --label labops.role=investigation \
    --label "labops.run_id=${run_id}" \
    "$AGENT_IMAGE" >/dev/null

  # Fail closed rather than hand a mis-provisioned sandbox to an investigation.
  refuse() { docker rm -f "$name" >/dev/null 2>&1 || true; echo "refusing: $1" >&2; exit 70; }
  binds=$(docker inspect -f '{{json .HostConfig.Binds}}' "$name")
  case "$binds" in *'/var/run/docker.sock'*|*'":/host'*|*'"/etc'*)
    refuse "host mount in $binds" ;;
  esac
  # Masks aside, nothing from the host filesystem may be visible: the workspace is a volume
  # and the writable scratch paths are tmpfs, so any other bind is a defect.
  mounts=$(docker inspect \
    -f '{{range .Mounts}}{{.Type}}:{{.Source}}:{{.Destination}} {{end}}' "$name")
  for m in $mounts; do
    case "$m" in
      bind:/dev/null:*) ;;
      bind:*) refuse "host bind mount: $m" ;;
    esac
  done
  nets=$(docker inspect -f '{{range $k,$v := .NetworkSettings.Networks}}{{$k}} {{end}}' "$name")
  [ "$(echo "$nets" | wc -w)" -eq 1 ] || refuse "extra networks: $nets"
  ports=$(docker inspect -f '{{json .NetworkSettings.Ports}}' "$name")
  case "$ports" in *HostPort*) refuse "published port: $ports" ;; esac
  [ -n "$(endpoint)" ] || refuse "no address on $NET"

  if [ "${1:-}" = "--json" ]; then emit_json; else echo "$name"; fi
  ;;

inspect)
  docker inspect "$name" >/dev/null 2>&1 || exit 68
  if [ "${1:-}" = "--json" ]; then emit_json; else endpoint; fi
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
  endpoint
  ;;

*) usage ;;
esac

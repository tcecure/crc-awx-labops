#!/usr/bin/env bash
# Checkpoint 3: prove one investigation cannot see another's workspace, and that the runtime
# contract (non-root, read-only, no host mounts, no docker socket, limits) actually holds.
#
#   test-investigation-isolation.sh
#
# Starts two throwaway containers with generated run ids, so it never touches a real run. The
# global one-active-investigation cap is a gateway policy, not a docker policy, so raising it
# is not required here.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
# run-investigation.sh refuses to start without the proxy token the gateway normally exports.
# Read it from the proxy's own env file when running the harness by hand as root.
if [ -z "${LABOPS_MODEL_PROXY_TOKEN:-}" ] && [ -r /etc/labops/model-proxy.env ]; then
  LABOPS_MODEL_PROXY_TOKEN=$(sed -n 's/^LABOPS_MODEL_PROXY_TOKEN=//p' /etc/labops/model-proxy.env)
  export LABOPS_MODEL_PROXY_TOKEN
fi
A=$(cat /proc/sys/kernel/random/uuid)
B=$(cat /proc/sys/kernel/random/uuid)

FAIL=0
ok()   { printf '  ok    %s\n' "$1"; }
bad()  { printf '  FAIL  %s\n' "$1"; FAIL=1; }
inA()  { docker exec "labops-inv-$A" sh -lc "$1"; }
deny() { if docker exec "labops-inv-$B" sh -lc "$2" >/dev/null 2>&1; then bad "$1 (succeeded!)"; else ok "$1"; fi; }
have() { if docker exec "labops-inv-$B" sh -lc "$2" >/dev/null 2>&1; then ok "$1"; else bad "$1"; fi; }

cleanup() { "$here/run-investigation.sh" stop "$A" >/dev/null; "$here/run-investigation.sh" stop "$B" >/dev/null; }
trap cleanup EXIT

canary="labops-canary-run-a-$(openssl rand -hex 8)"
"$here/run-investigation.sh" start "$A" >/dev/null
"$here/run-investigation.sh" start "$B" >/dev/null
inA "printf '%s' '$canary' > /workspace/secret-A.txt" >/dev/null

echo "== runtime contract (container B) =="
have "runs as uid 10001"              'test "$(id -u)" = 10001'
deny "root filesystem is read-only"   'touch /root-write-test'
have "workspace is writable"          'touch /workspace/.w && rm /workspace/.w'
# The sdk creates its llm profile store here while starting a conversation; without a tmpfs
# the read-only rootfs turns every POST /api/conversations into a 500.
have "agent state dir is writable"    'touch /home/openhands/.openhands/.w && rm /home/openhands/.openhands/.w'
deny "no docker socket"               'test -S /var/run/docker.sock'
# The agent image ships these; run-investigation.sh masks each with a non-executable bind.
for b in docker nsenter runc ctr sudo su; do
  deny "no usable $b" "command -v $b"
done
deny "cannot mount"                   'mount -t tmpfs none /mnt'
for f in /etc/labops /opt/labops /var/lib/labops-gateway /host; do
  deny "no host path $f" "test -e $f"
done

echo "== cross-investigation filesystem isolation =="
deny "A's workspace file not visible"  'test -e /workspace/secret-A.txt'
# Bounded to writable and mounted paths: sweeping the whole rootfs re-reads the agent image on
# every probe and adds nothing, since only a mount can carry another run's data into this one.
deny "A's canary not found anywhere"   "grep -RIl '$canary' /workspace /tmp /home /etc /var /mnt /media 2>/dev/null | grep -q ."
deny "cannot traverse /proc/*/root"    'ls /proc/*/root/workspace/secret-A.txt'
deny "cannot list other volumes"       'ls /var/lib/docker/volumes'

echo "== limits are in force =="
lim=$(docker inspect -f '{{.HostConfig.NanoCpus}} {{.HostConfig.Memory}} {{.HostConfig.PidsLimit}}' "labops-inv-$B")
case "$lim" in
  "2000000000 4294967296 512") ok "cpu/memory/pids limits applied ($lim)" ;;
  *) bad "unexpected limits: $lim" ;;
esac
mounts=$(docker inspect \
  -f '{{range .Mounts}}{{.Type}}:{{.Name}}:{{.Destination}} {{end}}' "labops-inv-$B")
case "$mounts" in
  *"volume:labops-inv-$B:/workspace"*) ok "its own workspace volume is mounted" ;;
  *) bad "workspace volume missing: $mounts" ;;
esac
for m in $mounts; do
  case "$m" in
    # /dev/null over the container-tooling binaries is the only bind allowed
    bind::/usr/*|bind::/bin/*|bind::/sbin/*) ;;
    bind:*) bad "host bind mount: $m" ;;
  esac
done

echo "== cross-investigation network isolation =="
# Each investigation is on labops-model with the other, so denial comes from the host's
# forward policy, not from docker: B must reach the model proxy and nothing else.
ipA=$(docker inspect -f "{{(index .NetworkSettings.Networks \"${LABOPS_MODEL_NET:-compose_labops-model}\").IPAddress}}" "labops-inv-$A")
connect() { printf 'python3 -c "import socket,sys; s=socket.socket(); s.settimeout(4); sys.exit(0 if s.connect_ex((%s,%s))==0 else 1)"' "'$1'" "$2"; }
deny "cannot reach A's agent port"    "$(connect "$ipA" 8000)"
have "can reach the model proxy"     "$(connect "${LABOPS_MODEL_PROXY_HOST:-172.31.241.2}" 8081)"
deny "cannot reach AWX"              "$(connect 192.168.1.103 30080)"
deny "cannot reach a student pod"     "$(connect 10.50.1.10 445)"
deny "cannot reach the internet"      "$(connect 1.1.1.1 443)"

echo "== workspace destruction =="
"$here/run-investigation.sh" stop "$A" >/dev/null
if docker volume inspect "labops-inv-$A" >/dev/null 2>&1; then
  bad "A's volume survived stop"
else
  ok "A's volume destroyed with the run"
fi

echo
[ "$FAIL" -eq 0 ] && echo "investigation isolation: PASS" || echo "investigation isolation: FAIL"
exit "$FAIL"

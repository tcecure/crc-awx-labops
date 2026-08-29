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
deny "no docker socket"               'test -S /var/run/docker.sock'
deny "no docker client"               'command -v docker'
deny "no nsenter"                     'command -v nsenter'
deny "cannot mount"                   'mount -t tmpfs none /mnt'
for f in /etc/labops /opt/labops /var/lib/labops-gateway /host; do
  deny "no host path $f" "test -e $f"
done

echo "== cross-investigation filesystem isolation =="
deny "A's workspace file not visible"  'test -e /workspace/secret-A.txt'
deny "A's canary not found anywhere"   "grep -RIl '$canary' / 2>/dev/null | grep -q ."
deny "cannot traverse /proc/*/root"    'ls /proc/*/root/workspace/secret-A.txt'
deny "cannot list other volumes"       'ls /var/lib/docker/volumes'

echo "== limits are in force =="
lim=$(docker inspect -f '{{.HostConfig.NanoCpus}} {{.HostConfig.Memory}} {{.HostConfig.PidsLimit}}' "labops-inv-$B")
case "$lim" in
  "2000000000 4294967296 512") ok "cpu/memory/pids limits applied ($lim)" ;;
  *) bad "unexpected limits: $lim" ;;
esac
binds=$(docker inspect -f '{{json .HostConfig.Binds}}' "labops-inv-$B")
case "$binds" in
  *"labops-inv-$B:/workspace"*) ok "only its own workspace volume is bound" ;;
  *) bad "unexpected binds: $binds" ;;
esac

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

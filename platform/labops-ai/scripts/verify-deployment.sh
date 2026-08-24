#!/usr/bin/env bash
# Post-deployment verification for drcc-labops-01. Every check must pass before the
# public hostname is pointed at the service. Run with --pre before deploying to capture
# the untouched state of the existing systems.
set -uo pipefail

FAIL=0
ok()   { printf '  ok    %s\n' "$1"; }
bad()  { printf '  FAIL  %s\n' "$1"; FAIL=1; }
check(){ if eval "$2" >/dev/null 2>&1; then ok "$1"; else bad "$1"; fi; }
# Inverted: the command MUST fail.
deny() { if eval "$2" >/dev/null 2>&1; then bad "$1 (was reachable!)"; else ok "$1"; fi; }

echo "== existing systems must be unaffected =="
check "crc.ai.tcecure.com responds"          "curl -m 10 -sf -o /dev/null https://crc.ai.tcecure.com/"
check "training tracker responds"            "curl -m 10 -sf -o /dev/null https://training.status.tcecure.com/"
check "my.digitalrcc.com responds"           "curl -m 10 -sf -o /dev/null https://my.digitalrcc.com/"

if [ "${1:-}" = "--pre" ]; then
  echo "pre-deployment baseline captured"; exit $FAIL
fi

echo "== services =="
check "labops-agent active"                  "systemctl is-active --quiet labops-agent"
check "labops-gateway active"                "systemctl is-active --quiet labops-gateway"
check "agent server healthy on loopback"     "curl -m 10 -sf -o /dev/null http://127.0.0.1:8000/health"
check "gateway healthy"                      "curl -m 10 -sf -o /dev/null http://127.0.0.1:3100/api/labops/health"

echo "== image pin =="
check "agent image matches pinned digest"    "$(dirname "$0")/check-image-pin.sh"

echo "== isolation =="
check "agent server bound to loopback only"  "ss -ltnp | grep -q '127.0.0.1:8000' && ! ss -ltn | grep -q '0.0.0.0:8000'"
check "nftables default-deny inbound"        "nft list chain inet filter input | grep -qE 'policy drop|drop'"
deny  "agent server unreachable off-host"    "curl -m 5 -sf -o /dev/null http://\$(hostname -I | awk '{print \$1}'):8000/health"
check "workspace containers have no host mounts" \
      "! docker ps -q --filter label=openhands.workspace | xargs -r docker inspect -f '{{json .HostConfig.Binds}}' | grep -q '/'"
check "no docker socket in containers"       "! docker ps -q | xargs -r docker inspect -f '{{json .Mounts}}' | grep -q docker.sock"
check "telemetry disabled"                   "docker inspect labops-agent-server -f '{{json .Config.Env}}' | grep -q 'DO_NOT_TRACK=1'"

echo "== no secret leakage =="
BODY=$(curl -m 10 -sf http://127.0.0.1:3100/api/labops/health || true)
for pat in 'sk-' 'service_role' 'Bearer '; do
  if printf '%s' "$BODY" | grep -q "$pat"; then bad "health body contains '$pat'"; else ok "health body free of '$pat'"; fi
done

echo "== capacity =="
check "disk below 80%"                       "[ \"\$(df --output=pcent /opt/labops | tail -1 | tr -dc 0-9)\" -lt 80 ]"

echo
[ $FAIL -eq 0 ] && echo "ALL CHECKS PASSED" || echo "CHECKS FAILED — do not proceed to DNS"
exit $FAIL

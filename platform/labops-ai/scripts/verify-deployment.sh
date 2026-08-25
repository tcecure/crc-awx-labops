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
check "gateway serving"                      "curl -m 10 -sf -o /dev/null http://127.0.0.1:3100/"
check "gateway health denies anonymous"      "curl -m 10 -s http://127.0.0.1:3100/api/labops/health | grep -q unauthenticated"

echo "== image pin =="
check "agent image matches pinned digest"    "$(dirname "$0")/check-image-pin.sh"

echo "== isolation =="
# grep -q would exit before its producer finishes, and `set -o pipefail` then reports the
# producer's SIGPIPE as a failed check, so these greps read their whole input.
check "agent server bound to loopback only"  "ss -ltn | grep -E '127.0.0.1:8000' >/dev/null && ! ss -ltn | grep -E '0.0.0.0:8000' >/dev/null"
check "nftables default-deny inbound"        "nft list chain inet filter input | grep -E 'policy drop' >/dev/null"
deny  "agent server unreachable off-host"    "curl -m 5 -sf -o /dev/null http://\$(hostname -I | awk '{print \$1}'):8000/health"
check "workspace containers have no host mounts" \
      "! docker ps -q --filter label=openhands.workspace | xargs -r docker inspect -f '{{json .HostConfig.Binds}}' | grep -q '/'"
check "no docker socket in containers"       "! docker ps -q | xargs -r docker inspect -f '{{json .Mounts}}' | grep -q docker.sock"
check "telemetry disabled"                   "docker inspect labops-agent-server -f '{{json .Config.Env}}' | grep -q 'DO_NOT_TRACK=1'"

echo "== public edge =="
EDGE=labops.drcc.digitalrcc.com
check "edge serves the console over TLS"     "curl -m 15 -sf -o /dev/null https://$EDGE/"
check "edge health denies anonymous"         "curl -m 15 -s https://$EDGE/api/labops/health | grep -E unauthenticated >/dev/null"
check "edge redirects http to https"         "[ \"\$(curl -m 15 -s -o /dev/null -w '%{http_code}' http://$EDGE/)\" = 301 ]"
deny  "agent server unreachable from public" "curl -m 8 -sf -o /dev/null http://108.31.169.90:8000/health"
deny  "gateway port unreachable from public" "curl -m 8 -sf -o /dev/null http://108.31.169.90:3100/"

echo "== no secret leakage =="
BODY=$(curl -m 10 -s http://127.0.0.1:3100/api/labops/health || true)
BODY="$BODY$(curl -m 15 -s https://$EDGE/ || true)"
for pat in 'sk-' 'service_role' 'Bearer '; do
  if printf '%s' "$BODY" | grep -q "$pat"; then bad "response bodies contain '$pat'"; else ok "response bodies free of '$pat'"; fi
done

echo "== capacity =="
check "disk below 80%"                       "[ \"\$(df --output=pcent /opt/labops | tail -1 | tr -dc 0-9)\" -lt 80 ]"

echo
[ $FAIL -eq 0 ] && echo "ALL CHECKS PASSED" || echo "CHECKS FAILED — do not proceed to DNS"
exit $FAIL

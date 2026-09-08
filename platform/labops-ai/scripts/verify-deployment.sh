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

AGENT="${LABOPS_AGENT_SERVER:-172.31.241.3:8000}"

echo "== existing systems must be unaffected =="
# Deliberately not probed from here: Phase 2 gives this host a default-deny output chain, and
# crc.ai, the tracker and the portal are not on its allow-list, so a probe would only measure
# the firewall. Verify them from an operator workstation.
for u in https://crc.ai.tcecure.com/ https://training.status.tcecure.com/ https://my.digitalrcc.com/; do
  printf '  skip  %s (verify off-host: this host is default-deny egress)\n' "$u"
done

if [ "${1:-}" = "--pre" ]; then
  echo "pre-deployment baseline captured"; exit $FAIL
fi

echo "== services =="
check "labops-agent active"                  "systemctl is-active --quiet labops-agent"
check "labops-gateway active"                "systemctl is-active --quiet labops-gateway"
check "agent server healthy on labops-model" "curl -m 10 -sf -o /dev/null http://$AGENT/health"
check "gateway serving"                      "curl -m 10 -sf -o /dev/null http://127.0.0.1:3100/"
check "gateway health denies anonymous"      "curl -m 10 -s http://127.0.0.1:3100/api/labops/health | grep -q unauthenticated"

echo "== image pin =="
check "agent image matches pinned digest"    "$(dirname "$0")/check-image-pin.sh"

echo "== isolation =="
# grep -q would exit before its producer finishes, and `set -o pipefail` then reports the
# producer's SIGPIPE as a failed check, so these greps read their whole input.
# Phase 2: the agent publishes no host port at all — labops-model is an internal network, so
# only the host (which owns that bridge) and containers on it can reach the agent.
check "agent server publishes no host port"  "! ss -ltn | grep -E ':8000' >/dev/null"
check "nftables default-deny inbound"        "nft list chain inet filter input | grep -E 'policy drop' >/dev/null"
deny  "agent server unreachable off-host"    "curl -m 5 -sf -o /dev/null http://\$(hostname -I | awk '{print \$1}'):8000/health"
check "model proxy healthy"                  "curl -m 10 -sf -o /dev/null http://172.31.241.2:8081/healthz"
check "nftables default-deny forward"        "nft list chain inet filter forward | grep -E 'policy drop' >/dev/null"
check "nftables default-deny output"         "nft list chain inet filter output | grep -E 'policy drop' >/dev/null"
check "agent env carries no gateway secrets" "! grep -qE '^(SUPABASE_SERVICE_ROLE_KEY|LABOPS_AWX_TOKEN|LABOPS_WIKI_TOKEN|LABOPS_LLM_API_KEY)=' /etc/labops/agent.env"
check "workspace containers have no host mounts" \
      "! docker ps -q --filter label=openhands.workspace | xargs -r docker inspect -f '{{json .HostConfig.Binds}}' | grep -q '/'"
# /health answers regardless, so the conversation store is checked where it actually breaks.
check "conversation store writable by agent uid" \
      "docker exec labops-agent-server sh -c 'touch /home/openhands/.openhands/.writecheck && rm /home/openhands/.openhands/.writecheck'"
check "agent accepts the gateway's conversation contract" \
      "$(dirname "$0")/check-agent-contract.sh"
check "no docker socket in containers"       "! docker ps -q | xargs -r docker inspect -f '{{json .Mounts}}' | grep -q docker.sock"
check "telemetry disabled"                   "docker inspect labops-agent-server -f '{{json .Config.Env}}' | grep -q 'DO_NOT_TRACK=1'"

echo "== public edge =="
EDGE=labops.drcc.digitalrcc.com
# The public hostname is not on this host's egress allow-list, so these have to be measured
# from a workstation: LABOPS_VERIFY_EDGE=1 ./verify-deployment.sh. Run there, they are the
# checks that matter; run here, they would only report the firewall.
if [ "${LABOPS_VERIFY_EDGE:-0}" = 1 ]; then
  check "edge serves the console over TLS"   "curl -m 15 -sf -o /dev/null https://$EDGE/labops"
  check "edge health denies anonymous"       "[ \"\$(curl -m 15 -s -o /dev/null -w '%{http_code}' https://$EDGE/api/labops/health)\" = 401 ]"
  check "edge redirects http to https"       "[ \"\$(curl -m 15 -s -o /dev/null -w '%{http_code}' http://$EDGE/)\" = 301 ]"
  deny  "agent server unreachable from public" "curl -m 8 -sf -o /dev/null http://108.31.169.90:8000/health"
  deny  "gateway port unreachable from public" "curl -m 8 -sf -o /dev/null http://108.31.169.90:3100/"
else
  printf '  skip  edge checks (run with LABOPS_VERIFY_EDGE=1 from a workstation)\n'
fi

echo "== no secret leakage =="
BODY=$(curl -m 10 -s http://127.0.0.1:3100/api/labops/health || true)
BODY="$BODY$(curl -m 10 -s http://127.0.0.1:3100/labops || true)"
for pat in 'sk-' 'service_role' 'Bearer '; do
  if printf '%s' "$BODY" | grep -q "$pat"; then bad "response bodies contain '$pat'"; else ok "response bodies free of '$pat'"; fi
done

echo "== capacity =="
check "disk below 80%"                       "[ \"\$(df --output=pcent /opt/labops | tail -1 | tr -dc 0-9)\" -lt 80 ]"

echo
[ $FAIL -eq 0 ] && echo "ALL CHECKS PASSED" || echo "CHECKS FAILED — do not proceed to DNS"
exit $FAIL

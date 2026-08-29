#!/usr/bin/env bash
# Checkpoint 4: prove an investigation workspace has no network reach except the model proxy.
# Usage: test-egress-isolation.sh <run_id>
# Every probe has a 5 s timeout, so a drop shows up as a timeout rather than a refusal.
set -uo pipefail
run_id="${1:?run id required}"
c="labops-inv-${run_id}"
PROXY="${LABOPS_MODEL_PROXY:-172.31.241.2:8081}"
HOST_LAN_IP="${LABOPS_HOST_LAN_IP:-192.168.1.65}"

FAIL=0
ok()   { printf '  ok    %s\n' "$1"; }
bad()  { printf '  FAIL  %s\n' "$1"; FAIL=1; }
deny() { if docker exec "$c" sh -lc "$2" >/dev/null 2>&1; then bad "$1 (reachable!)"; else ok "$1"; fi; }
allow(){ if docker exec "$c" sh -lc "$2" >/dev/null 2>&1; then ok "$1"; else bad "$1 (blocked)"; fi; }

C="curl -sS -m 5 -o /dev/null"
N="nc -z -w 3"

echo "== public internet =="
deny "https://example.com"            "$C https://example.com/"
deny "raw IP 1.1.1.1"                 "$C http://1.1.1.1/"
deny "DNS resolution off-host"        "getent hosts github.com"

echo "== platform services =="
deny "Supabase REST"                  "$C https://kkacbtkacadgsnbylkti.supabase.co/rest/v1/"
deny "AWX API"                        "$C http://192.168.1.103:30080/api/v2/ping/"
deny "Wiki.js"                        "$C http://192.168.1.42/graphql"
deny "Proxmox API"                    "$C -k https://192.168.1.10:8006/api2/json/version"
deny "Guacamole (other internal host)" "$N 192.168.1.51 4822"

echo "== Active Directory =="
deny "AD LDAP 389"                    "$N 192.168.1.20 389"
deny "AD SMB 445"                     "$N 192.168.1.20 445"

echo "== student pod networks =="
deny "Pod06 gateway SSH"              "$N 10.51.6.1 22"
deny "Pod06 DMZ web server"           "$N 10.52.6.50 80"

echo "== gateway internal API =="
deny "gateway on docker bridge"        "$C http://172.31.241.1:3100/api/labops/health"
deny "gateway on host LAN address"     "$C http://$HOST_LAN_IP:3100/api/labops/health"

echo "== cloud instance metadata =="
deny "169.254.169.254"                 "$C http://169.254.169.254/latest/meta-data/"

echo "== the one permitted path =="
allow "model proxy /v1/models via base_url" \
      "curl -sS -m 10 -o /dev/null -H \"Authorization: Bearer \$LABOPS_MODEL_PROXY_TOKEN\" -H \"X-LabOps-Run: $run_id\" http://$PROXY/v1/models"
deny  "proxy refuses paths outside /v1/" \
      "$C -f http://$PROXY/admin"
deny  "proxy refuses CONNECT tunnelling" \
      "curl -sS -m 5 -o /dev/null -x http://$PROXY https://example.com/"
deny  "proxy does not leak the provider key" \
      "curl -sS -m 10 -H \"Authorization: Bearer \$LABOPS_MODEL_PROXY_TOKEN\" -H \"X-LabOps-Run: $run_id\" http://$PROXY/v1/models | grep -Eq 'sk-[A-Za-z0-9]{20,}'"

echo
[ "$FAIL" -eq 0 ] && echo "egress isolation: PASS" || echo "egress isolation: FAIL"
exit "$FAIL"

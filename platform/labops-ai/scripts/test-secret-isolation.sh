#!/usr/bin/env bash
# Checkpoint 2 canary test: prove an investigation workspace cannot read gateway secrets.
# Usage: test-secret-isolation.sh <run_id>
# Exits non-zero on the first failure, so its output is usable as checkpoint evidence.
set -uo pipefail
# LABOPS_TEST_CONTAINER targets the transitional shared agent server; normally the container
# name is derived from the run id.
run_id="${1:-}"
c="${LABOPS_TEST_CONTAINER:-labops-inv-${run_id:?run id required}}"

FAIL=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; FAIL=1; }
# the command must succeed inside the container
inc()  { if docker exec "$c" sh -lc "$2" >/dev/null 2>&1; then ok "$1"; else bad "$1"; fi; }
# the command must find nothing / fail inside the container
noc()  { if docker exec "$c" sh -lc "$2" >/dev/null 2>&1; then bad "$1 (was reachable!)"; else ok "$1"; fi; }

echo "== workspace identity =="
inc "agent canary is present (test really runs in the agent context)" \
    'test -n "$LABOPS_CANARY_AGENT"'

echo "== gateway secrets must be absent from the environment =="
for v in LABOPS_CANARY_GATEWAY SUPABASE_SERVICE_ROLE_KEY LABOPS_AWX_TOKEN LABOPS_WIKI_TOKEN \
         LABOPS_GITHUB_APP_PRIVATE_KEY LABOPS_AGENT_WEBHOOK_SECRET EMAIL_SMTP_PASSWORD \
         LABOPS_LLM_API_KEY; do
  noc "env has no $v" "env | grep -q '^$v='"
done
noc "no provider-style key anywhere in env" 'env | grep -Eq "sk-[A-Za-z0-9]{20,}"'
noc "no service-role JWT anywhere in env"   'env | grep -Eq "eyJ[A-Za-z0-9_-]{20,}"'

echo "== other processes' environments =="
noc "no gateway canary in /proc/*/environ" \
    'grep -l labops-canary-gateway /proc/*/environ 2>/dev/null | grep -q .'
noc "cannot read pid 1 environ of another namespace" \
    'grep -aq SUPABASE_SERVICE_ROLE_KEY /proc/1/environ'

echo "== host configuration must not be mounted =="
for p in /etc/labops /etc/labops/gateway.env /etc/labops/labops.env /opt/labops \
         /var/run/docker.sock /host; do
  noc "$p absent" "test -e $p"
done

echo "== filesystem sweep for gateway credentials =="
noc "gateway canary not on disk" \
    'grep -RIl labops-canary-gateway /etc /opt /var/lib /home /workspace 2>/dev/null | grep -q .'
# A whole JWT (three dot-separated base64 segments) in a path a leak could write to. The
# agent image itself ships example tokens in vendored test fixtures, and a bare "eyJ..." blob
# also matches inline source maps, so neither the image tree nor node_modules is evidence.
noc "no supabase service-role key on disk" \
    'grep -RIlE --exclude-dir=node_modules "eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}" /etc /home /tmp /workspace /var/lib 2>/dev/null | grep -q .'

echo
[ "$FAIL" -eq 0 ] && echo "secret isolation: PASS" || echo "secret isolation: FAIL"
exit "$FAIL"

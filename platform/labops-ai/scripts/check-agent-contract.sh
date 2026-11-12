#!/usr/bin/env bash
# Creates and deletes a throwaway conversation using the same request shape the gateway
# sends, then deletes it. /health cannot catch this class of defect: the agent server
# accepts the connection and the key, and only rejects the payload — wrong tag keys (422),
# an unwritable conversation store (500), or tool names that are class names rather than
# registry names (500 on the first message). Each of those shipped once.
#
# Runs on drcc-labops-01 as root: it reads the agent key from /etc/labops/labops.env and
# never prints it.
set -euo pipefail

# Phase 2 split the gateway environment out of labops.env; fall back for a pre-split host.
# shellcheck disable=SC1091
set -a; . "$([ -r /etc/labops/gateway.env ] && echo /etc/labops/gateway.env || echo /etc/labops/labops.env)"; set +a

# labops-model is internal, so the agent has no published host port; the host reaches it on
# the bridge address the gateway is configured with.
AGENT=${LABOPS_AGENT_SERVER_URL:-http://172.31.241.3:8000}
BODY=$(cat <<'JSON'
{
  "workspace": { "kind": "LocalWorkspace", "working_dir": "/workspace/contract-check" },
  "confirmation_policy": { "kind": "AlwaysConfirm" },
  "max_iterations": 1,
  "stuck_detection": true,
  "secrets": {},
  "tags": { "runid": "contractcheck" },
  "initial_message": {
    "role": "user",
    "content": [{ "type": "text", "text": "contract check" }],
    "run": false
  },
  "agent": {
    "kind": "Agent",
    "llm": { "usage_id": "labops-contract-check", "model": "openai/gpt-4o", "api_key": "unused" },
    "tools": [
      { "name": "terminal", "params": {} },
      { "name": "file_editor", "params": {} },
      { "name": "task_tracker", "params": {} }
    ]
  }
}
JSON
)

RESPONSE=$(curl -m 30 -sS -X POST "$AGENT/api/conversations" \
  -H "X-Session-API-Key: $LABOPS_AGENT_SERVER_API_KEY" \
  -H "Content-Type: application/json" -d "$BODY")

ID=$(printf '%s' "$RESPONSE" | sed -n 's/.*"id":"\([0-9a-f-]\{36\}\)".*/\1/p')

if [ -z "$ID" ]; then
  # The response carries no secret: it is the server's own validation detail.
  echo "conversation not created: $(printf '%s' "$RESPONSE" | head -c 300)" >&2
  exit 1
fi

# The gateway starts the loop explicitly after creating the conversation. Creation with an
# initial message already starts it, so 409 is the expected answer here and the gateway
# treats it as success; anything else means the start hop has drifted.
START=$(curl -m 30 -sS -o /dev/null -w '%{http_code}' -X POST "$AGENT/api/conversations/$ID/run" \
  -H "X-Session-API-Key: $LABOPS_AGENT_SERVER_API_KEY")

curl -m 20 -sS -o /dev/null -X DELETE "$AGENT/api/conversations/$ID" \
  -H "X-Session-API-Key: $LABOPS_AGENT_SERVER_API_KEY"

case "$START" in
  200|202|204|409) ;;
  *) echo "start hop returned $START" >&2; exit 1 ;;
esac

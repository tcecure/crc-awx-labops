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

# shellcheck disable=SC1091
set -a; . /etc/labops/labops.env; set +a

AGENT=${LABOPS_AGENT_SERVER_URL:-http://127.0.0.1:8000}
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

curl -m 20 -sS -o /dev/null -X DELETE "$AGENT/api/conversations/$ID" \
  -H "X-Session-API-Key: $LABOPS_AGENT_SERVER_API_KEY"

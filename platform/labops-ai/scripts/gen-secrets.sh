#!/usr/bin/env bash
# Generates the host-local secrets (agent-server bearer key, conversation encryption key,
# webhook secret) directly into /etc/labops/labops.env. Values never leave the host and
# are never printed. Provider keys are NOT generated here: the OpenAI key and the AWX
# token are pasted in by the owner.
set -euo pipefail

ENV_FILE=${ENV_FILE:-/etc/labops/labops.env}
[ -f "$ENV_FILE" ] || { echo "$ENV_FILE does not exist; copy env/labops.env.example first" >&2; exit 1; }

set_var() {
  local key="$1" value="$2"
  if grep -q "^${key}=" "$ENV_FILE"; then
    sed -i "s|^${key}=.*|${key}=${value}|" "$ENV_FILE"
  else
    printf '%s=%s\n' "$key" "$value" >>"$ENV_FILE"
  fi
  echo "set ${key} (value not shown)"
}

AGENT_KEY="$(openssl rand -hex 32)"
set_var LABOPS_AGENT_SERVER_API_KEY "$AGENT_KEY"
# The container reads SESSION_API_KEY; docker's env_file does not interpolate, so the
# same value is written twice rather than referenced.
set_var SESSION_API_KEY             "$AGENT_KEY"
set_var LABOPS_AGENT_WEBHOOK_SECRET "$(openssl rand -hex 32)"
set_var OH_SECRET_KEY               "$(openssl rand -hex 32)"

chown root:labops-gateway "$ENV_FILE"
chmod 0640 "$ENV_FILE"
echo "done; restart labops-agent and labops-gateway to pick the values up"

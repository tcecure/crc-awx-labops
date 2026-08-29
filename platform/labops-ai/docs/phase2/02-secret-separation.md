# Checkpoint 2 — Gateway / agent secret separation

## Current state (defect)

`/etc/labops/labops.env` (root:labops-gateway 0640) holds every secret the platform has, and
`compose/docker-compose.yml` passes that whole file into the agent container with
`env_file: /etc/labops/labops.env`. Any `bash` tool call the agent makes can run `env` and
read the Supabase service-role key, the AWX token, the Wiki token, `OH_SECRET_KEY`,
`SESSION_API_KEY` and the provider key. That is the single largest Phase 1 exposure.

## Target state

Two files, two audiences, no overlap:

| File | Mode | Read by | Contents |
| --- | --- | --- | --- |
| `/etc/labops/gateway.env` | `root:labops-gateway 0640` | `labops-gateway` systemd unit only | Supabase URL + service-role key, `LABOPS_AWX_*`, `LABOPS_WIKI_*`, `LABOPS_GITHUB_*` (later), session/webhook secrets, budgets, owner email, SMTP settings, agent API key |
| `/etc/labops/agent.env` | `root:root 0640`, group `labops-agent` | the agent/investigation containers only | `SESSION_API_KEY` (gateway↔agent auth), `OH_SECRET_KEY`, telemetry off switches, `LABOPS_LLM_MODEL`, `LABOPS_LLM_BASE_URL` (the model proxy), `LABOPS_MODEL_PROXY_TOKEN` (per-investigation, injected at launch), plus one canary |

Rules that follow from that split:

* The **provider API key never enters an agent container.** It lives only in
  `/etc/labops/model-proxy.env`, read by the model-proxy container (checkpoint 4), which
  injects `Authorization` server-side. The agent's `base_url` points at the proxy and carries
  a per-investigation token that is worthless anywhere else.
* `SUPABASE_SERVICE_ROLE_KEY`, `LABOPS_AWX_TOKEN`, `LABOPS_WIKI_TOKEN`, GitHub App credentials
  and `EMAIL_*` **never appear in `agent.env`**, in a container's `environment:`, in a volume,
  or in a conversation payload. All external reads/writes are performed by the gateway.
* The gateway process must not export its own environment into `docker run` for
  investigations: `scripts/run-investigation.sh` builds an explicit `--env-file
  /etc/labops/agent.env` plus a short allow-list of per-run values, and never `--env` from
  its own environment.

## Canary

`agent.env` carries a value that exists nowhere else:

```
LABOPS_CANARY_AGENT=labops-canary-agent-<random>
```

and `gateway.env` carries `LABOPS_CANARY_GATEWAY=labops-canary-gateway-<random>`.
`scripts/test-secret-isolation.sh` runs inside a live investigation workspace and asserts:

1. `env` contains `LABOPS_CANARY_AGENT` (proves the test really is in the agent context) and
   **not** `LABOPS_CANARY_GATEWAY`.
2. `grep -R` over `/proc/*/environ`, `/etc`, `/opt`, `/var/lib`, `/home`, `/workspace` finds no
   occurrence of the gateway canary, of `SUPABASE_SERVICE_ROLE_KEY`, `LABOPS_AWX_TOKEN`,
   `LABOPS_WIKI_TOKEN`, `OH_SECRET_KEY`, or an `sk-`/`eyJ`-prefixed string.
3. `/etc/labops` is not present in the container at all (no host mounts).
4. The gateway's own `/proc/<pid>/environ` is unreachable (different PID namespace).

The gateway logs a `secret_isolation_test` row in `ai_tool_actions` and `audit_events` for
each execution, so the evidence is auditable rather than a screenshot.

## Migration (host, reversible)

`scripts/split-secrets.sh` is idempotent and never prints a value:

1. Back up `labops.env` to `/etc/labops/backups/labops.env.<ts>` (0600, root).
2. Write `gateway.env` = everything except the agent-only keys; write `agent.env` = the
   agent-only keys plus a fresh canary.
3. Update the systemd unit drop-in to `EnvironmentFile=/etc/labops/gateway.env`.
4. `docker compose up -d` with the new compose file, which uses `agent.env`.
5. Verify with `scripts/verify-deployment.sh` and `scripts/test-secret-isolation.sh`.
6. Leave `labops.env` in place, mode `0600 root:root`, for one week as the rollback path
   (checkpoint 13), then delete.

Rollback is `scripts/split-secrets.sh --revert`, which restores the unit drop-in and the
previous compose file; no data is touched.

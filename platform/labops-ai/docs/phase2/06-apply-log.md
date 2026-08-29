# Phase 2 apply log — drcc-labops-01

What was actually applied to the live host, and what the applied state proves. Database changes
are **not** part of this: no Phase 2 migration has been applied to production or staging, and
every write switch stays disabled.

## Applied

1. `scripts/split-secrets.sh` — `/etc/labops/labops.env` split into `gateway.env`, `agent.env`
   and `model-proxy.env` (backup retained under `/etc/labops/backups`, source kept `0600` as the
   rollback path, gateway switched to a `20-env.conf` drop-in).
2. `compose/docker-compose.yml` + `compose/docker-compose.shared-agent.yml` — model proxy started;
   the transitional shared agent server re-created against `agent.env` on the internal
   `labops-model` network.
3. `scripts/bootstrap-host.sh` nftables section — default-deny `forward` and `output`, with the
   name-resolved egress allow-list refreshed every two minutes.

## Corrections the apply surfaced

- **Gateway reported `not_configured`.** The split moved model selection and timeout variables
  out of the gateway environment; they are configuration, not credentials, and the gateway
  budgets a run against the same model the agent uses. They are now shared, while the provider
  key stays only in `model-proxy.env` and the gateway holds the sentinel `via-model-proxy`.
- **Gateway could not reach the agent.** `labops-model` is an internal network, and docker
  cannot publish a host port from one, so `127.0.0.1:8000` no longer existed. The gateway now
  uses `http://172.31.241.3:8000` over that bridge; nothing off-host can route to it.
- **Agent-to-proxy traffic was dropped.** The first default-deny `forward` chain had no rule for
  the one path that must work. Added: `172.31.241.0/24 -> 172.31.241.2 tcp 8081`.
- **Provider egress was dropped intermittently.** `api.openai.com` answers with a rotating
  subset of a CDN address pool, so a flush-and-replace refresh dropped the connection that had
  just resolved a new address. The refresh now queries each name repeatedly and accumulates,
  pruning once a day.
- **The volume `chown` helper pulled `alpine:3` from docker.io**, which the host's egress
  allow-list does not permit. It now runs in the pinned agent image itself.
- **The agent image ships `docker`, `runc`, `ctr`, `nsenter`, `sudo` and `su`.** Unusable without
  the socket or a capability to gain, but each is masked with a non-executable bind so the
  read-only rootfs cannot be pruned around.

## Verified on the applied host

- `scripts/test-secret-isolation.sh` — PASS against a real per-run container: no gateway canary,
  no Supabase service-role key, no AWX/Wiki/GitHub/SMTP/provider credential, no `/etc/labops`,
  no other process's environment.
- `scripts/test-egress-isolation.sh` — PASS: public internet, Supabase, AWX, Wiki.js, Proxmox,
  AD, student pods, the gateway's own APIs, cloud metadata and Guacamole all denied; the model
  proxy is the only reachable destination, it refuses paths outside `/v1/`, refuses `CONNECT`,
  and does not leak the provider key.
- `scripts/test-investigation-isolation.sh` — PASS: non-root, read-only rootfs, no host mounts,
  no socket, limits in force, one run cannot see another's workspace, volume destroyed with the run.
- `scripts/verify-deployment.sh` — ALL CHECKS PASSED on the host. The edge and third-party checks
  are skipped there by design (the host is default-deny egress) and were run from a workstation:
  `/labops` 200, `/api/labops/health` 401 anonymous, `http://` 301.

## Not applied / still absent

- Real provider key. `model-proxy.env` holds a placeholder, so a live investigation stops at the
  provider call with 401 — the path itself is proven end to end up to that point.
- Any Phase 2 database migration, on production or staging.
- AWX execution account, GitHub App and Wiki.js write credentials.
- Per-investigation launching from the gateway: the transitional shared agent is still in place,
  which is why `docker-compose.shared-agent.yml` exists.

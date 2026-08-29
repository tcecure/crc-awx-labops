# Checkpoint 1 — Phase 1 live validation

Observed on the live systems (not read from `deployment-log.md`) on 2026-08-29.
Every line below is either a command output or a direct consequence of one.

## Confirmed working

| Item | Live evidence |
| --- | --- |
| LabOps host | `hostname` → `drcc-labops-01` |
| Gateway service | `systemctl is-active labops-gateway` → `active`, `PORT=3100` |
| Public entry | `https://labops.drcc.digitalrcc.com/` → 302 → `/labops`, HTTP 200 |
| Anonymous denial | `GET /api/labops/health` (unauthenticated) → `401` |
| Agent server | container `labops-agent-server`, image `ghcr.io/openhands/agent-server:1.42.1-python@sha256:141a3628…`, `Up (healthy)` |
| Agent server privacy | listening on `127.0.0.1:8000` only; nftables `input` policy `drop` and an explicit drop for `tcp dport 8000` |
| Container hardening | `read_only: true`, `cap_drop: ALL`, `no-new-privileges`, cpu 4 / mem 8g / pids 2048 |
| Production Supabase | gateway env points at `https://kkacbtkacadgsnbylkti.supabase.co` |
| Production schema | all nine `ai_*` tables present in the DRCC project (`ai_runs`, `ai_run_events`, `ai_messages`, `ai_model_usage`, `ai_tool_actions`, `ai_approval_requests`, `ai_artifacts`, `ai_knowledge_proposals`, `ai_integration_health`) |
| Owner console | Eddie logged in on production and the LabOps AI tab rendered; no gateway errors logged for that session |
| `crc.ai` untouched | `https://crc.ai.tcecure.com/` → 307 → `/login`, HTTP 200, before and after this validation |

## Not complete — Phase 1 items still open

1. **Model credential is a placeholder.** `/etc/labops/labops.env` still contains
   `LABOPS_LLM_API_KEY=REPLACE_ON_HOST_ONLY` (20 characters). Consequence: the ten-step
   read-only investigation demanded by the brief **cannot be produced yet** — a run reaches
   the provider call and fails closed. Steps 1, 2, 5, 6, 7, 9 and 10 of that list are
   exercisable today; steps 3, 4 and 8 (real model, streamed model activity, real findings)
   are blocked on this one value. Eddie chose "skip for now" when asked for the key, so this
   is a deliberate open item, not a defect.
2. **`svc-drcc-labops-ai-ro` does not exist.** `GET /api/v2/users/` on AWX returns exactly one
   user (`admin`). The 20-character `LABOPS_AWX_TOKEN` in the environment is therefore a
   placeholder, not a working read-only token.
3. **No PBS backup for VMID 100.** The `pbs-pve2` datastore exists, but the only backup job
   on the cluster targets VMID `109` (21:00, snapshot). `drcc-labops-01` is unprotected.
   Not created here: Phase 2 forbids production changes before checkpoint approval.
4. **Secrets are not separated** (checkpoint 2) and **the agent container has real egress**
   (checkpoint 4). Both are Phase 2 gates and are addressed in this PR.

## Corrections to earlier reporting

* The deployment plan states the host has "allow-listed egress". It does not:
  `nft list chain inet filter output` → `policy accept`, and `forward` → `policy accept`.
  The claim was aspirational; see checkpoint 4.
* `compose/docker-compose.yml` supplies the **entire** gateway environment to the agent
  container via `env_file: /etc/labops/labops.env`, so the Supabase service-role key, the
  AWX token, the Wiki token and the gateway session secrets are all readable from any
  terminal command the agent runs. See checkpoint 2.

## Verdict

Phase 1 is a working, live, owner-only pilot with a placeholder model credential; it is not
"complete" under the brief's definition, because the end-to-end read-only investigation
cannot be demonstrated without the OpenAI key, and two operational prerequisites
(AWX read-only account, VMID 100 backup) are absent. No Phase 2 write capability should be
enabled until checkpoints 2–4 are approved and applied.

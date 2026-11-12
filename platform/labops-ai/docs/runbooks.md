# LabOps AI runbooks — backup, update, rollback, incident

Host: `drcc-labops-01` (pve2). All commands run as root on that host unless stated.

## Backup

| What | How | Retention |
|---|---|---|
| VM | PBS daily snapshot (guest agent enabled) | 7 daily, 4 weekly |
| `/etc/labops/labops.env` | Excluded from Git; recorded in the password manager. Losing it costs a re-paste of the OpenAI key + AWX token and a `gen-secrets.sh` re-run | n/a |
| Agent state volume | Included in the PBS snapshot | with the VM |
| Run history | Lives in Supabase, backed up by Supabase | per project policy |

The host holds no authoritative data: destroying and rebuilding it loses nothing but
in-flight runs. Verify a restore quarterly by booting the snapshot on an isolated bridge.

## Update — agent server

1. Read the upstream release notes; confirm the SDK version `OpenHands` pins.
2. Wait until the candidate image is **≥ 7 days old**.
3. Resolve the digest and update `compose/docker-compose.yml` (tag *and* digest) in a PR — never a floating tag:
   ```bash
   TOKEN=$(curl -s "https://ghcr.io/token?scope=repository:openhands/agent-server:pull&service=ghcr.io" | jq -r .token)
   curl -sI -H "Authorization: Bearer $TOKEN" \
     -H 'Accept: application/vnd.oci.image.index.v1+json' \
     https://ghcr.io/v2/openhands/agent-server/manifests/<new-tag> | grep -i docker-content-digest
   ```
4. Deploy on `drcc-labops-01`, run `scripts/verify-deployment.sh` and the three `test-*.sh`
   suites, then one real investigation against a designated test ticket. There is no staging
   host to stage this on — keep the previous image so rollback is one restart.
5. `git pull` on the host, `systemctl restart labops-agent`, verify again. Keep the previous image (`docker image ls`) until sign-off.

## Update — gateway / frontend

Releases are unpacked to `/opt/labops/app/releases/<timestamp>` with
`/opt/labops/app/current` as a symlink.

```bash
systemctl stop labops-gateway
ln -sfn /opt/labops/app/releases/<new> /opt/labops/app/current
systemctl start labops-gateway && scripts/verify-deployment.sh
```

Migrations, if any, follow `docs/labops-ai/production-first-workflow.md` in the app repo:
validated on a throwaway local Postgres, then applied to production with explicit approval and
recorded with rollback SQL in `docs/labops-ai/phase2-apply-log.md`. There is no staging project.

## Rollback

| Scope | Command |
|---|---|
| Gateway | `ln -sfn /opt/labops/app/releases/<previous> /opt/labops/app/current && systemctl restart labops-gateway` |
| Agent server | revert the digest in `compose/docker-compose.yml`, `systemctl restart labops-agent` |
| Whole host | restore the PBS snapshot |
| Public exposure | disable the edge nginx vhost and delete the Namecheap record — everything else keeps running privately |

Always finish with `scripts/verify-deployment.sh`, which re-checks `crc.ai`, the tracker
and the portal.

## Secret rotation

| Secret | Procedure |
|---|---|
| OpenAI key | Owner creates a new project-scoped key → paste into `/etc/labops/labops.env` → `systemctl restart labops-gateway` → confirm health → revoke the old key |
| AWX token | New token (scope `Read`) on `svc-drcc-labops-ai-ro` → update env → restart → delete the old token |
| Agent bearer / webhook / `OH_SECRET_KEY` | `scripts/gen-secrets.sh` → `systemctl restart labops-agent labops-gateway`. Note: rotating `OH_SECRET_KEY` invalidates stored conversation secrets, so do it between runs |
| Supabase service role | Rotate in Supabase → update env → restart |

## Incident: suspected agent misbehaviour or key compromise

1. `systemctl stop labops-gateway` — this alone stops all agent activity; the browser has no other path in.
2. `docker compose down` in `compose/` to stop the agent server and any workspace.
3. Revoke: OpenAI key (dashboard), AWX token (`svc-drcc-labops-ai-ro` → Tokens → delete), Supabase service role if implicated.
4. Preserve evidence: `docker logs labops-agent-server > /var/log/labops/incident-$(date +%s).log`, plus the run's `ai_run_events`/`ai_tool_actions` rows (append-only, cannot have been rewritten).
5. Confirm blast radius: AWX has no `Execute` grant, so no job can have been launched; check `ai_tool_actions` for `is_write = true` rows.
6. Verify the lab is unaffected: `scripts/verify-deployment.sh --pre`, plus the pod firewall/AWX spot checks.
7. Rotate everything in the table above before restarting.

## Health monitoring (Phase 1, no SIEM)

`/api/labops/health` reports agent server, Supabase, AWX, Wiki.js and budget state, and
the dashboard surfaces it. `ai_integration_health` keeps the last result per integration.
Log shipping to Wazuh is deliberately out of Phase 1 scope.

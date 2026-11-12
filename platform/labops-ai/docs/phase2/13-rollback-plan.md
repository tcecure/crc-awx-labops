# Checkpoint 13 — Rollback plan

Every Phase 2 change is reversible without data loss and without touching `crc.ai`, the
portal, the tracker or the pods. Rollback is per layer; nothing below depends on a later step.

## 1. Write capability (seconds)

```
sudo sed -i 's/^LABOPS_WRITES_ENABLED=.*/LABOPS_WRITES_ENABLED=false/' /etc/labops/gateway.env
sudo systemctl restart labops-gateway
```
Global kill switch; per-integration switches (`LABOPS_GITHUB_WRITES_ENABLED`,
`LABOPS_WIKI_WRITES_ENABLED`, `LABOPS_AWX_EXEC_ENABLED`) work the same way. Pending approvals
stay pending and expire; approved-but-unexecuted actions never execute. Default is `false`.

## 2. Credentials (minutes, no code change)

| Credential | Revoke by |
| --- | --- |
| GitHub App | uninstall the app from the org (one click); delete `/etc/labops/github-app.pem` |
| Wiki.js token | delete the API key in Wiki.js Administration → API |
| AWX exec token | delete the token, then delete `svc-drcc-labops-ai-exec` |
| Model provider key | rotate at OpenAI, update `/etc/labops/model-proxy.env`, restart the proxy |

No other component holds these values, which is the point of checkpoint 2.

## 3. Secret split (one command)

`scripts/split-secrets.sh --revert` restores the `labops.env` single-file layout for the
gateway unit and restarts it. `labops.env` is retained (mode 0600) for one week after the
split, and a timestamped copy lives in `/etc/labops/backups/`.

## 4. Investigation runtime

Stop creating per-run containers by setting `LABOPS_MAX_ACTIVE_RUNS=0` — the console then
refuses to start investigations while everything else (history, findings, approvals, audit)
keeps working. To restore the Phase 1 runtime entirely, `git revert` the compose change and
`docker compose up -d`; the old `agent-state`/`agent-home` volumes are untouched by this PR.

## 5. Network egress

```
sudo cp /etc/nftables.conf.pre-phase2 /etc/nftables.conf   # written by bootstrap-host.sh
sudo nft -c -f /etc/nftables.conf && sudo systemctl restart nftables
```
If the ruleset is ever applied wrongly and locks out SSH, the recovery path is the Proxmox
console on VMID 100 (`qm terminal 100`) — which is why the PBS backup for VMID 100 is a
prerequisite, not an optional extra.

## 6. Database

The Phase 2 migration is **additive only**: new tables and new nullable columns, no drops, no
type changes, no data rewrites. Rollback is the paired `down` file that drops exactly the new
objects; existing `support_*` and `ai_*` data is never read-modify-written by it. There is no
staging environment, so it is validated on a throwaway local Postgres and applied to production
only with explicit approval; the exact statements applied and their rollback SQL are recorded in
`docs/labops-ai/phase2-apply-log.md` in the app repo. The Phase 2 broker migration was applied
on 2026-08-29 and the owner has directed that it stays in place.

## 7. Application

Releases are directories under `/opt/labops/app/releases/<timestamp>` with a `current`
symlink. Rollback is `ln -sfn <previous> current && systemctl restart labops-gateway`,
≈10 seconds. The Phase 2 UI additions are new routes; reverting them cannot affect
`/admin/support`.

## Verification after any rollback

`scripts/verify-deployment.sh` must pass, including its first three checks — `crc.ai`, the
tracker and `my.digitalrcc.com` must respond exactly as before.

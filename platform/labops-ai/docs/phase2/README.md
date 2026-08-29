# DigitalRCC LabOps AI — Phase 2 checkpoints

Review order. Nothing here creates a credential, applies a production migration, changes DNS or
touches `crc.ai`; the host changes in `scripts/` are validated but **not applied to production**.

| # | Document | What it needs from you |
| --- | --- | --- |
| 1 | [01-phase1-live-validation.md](01-phase1-live-validation.md) | acknowledge the four open Phase 1 items and the two defects found |
| 2 | [02-secret-separation.md](02-secret-separation.md) | approve the three-file split before it is applied to the host |
| 3 | [03-investigation-isolation.md](03-investigation-isolation.md) | approve the per-investigation container design and its one residual limitation |
| 4 | [04-network-egress.md](04-network-egress.md) | approve the default-deny forward/output ruleset (needs the VMID 100 backup first) |
| 8 | [08-github-app-runbook.md](08-github-app-runbook.md) | approve before any GitHub App is created |
| 9 | [09-wikijs-write-token-runbook.md](09-wikijs-write-token-runbook.md) | approve before any Wiki.js write token exists |
| 10 | [10-awx-exec-account.md](10-awx-exec-account.md) | approve the template allow-list before `svc-drcc-labops-ai-exec` is created |
| 11 | [11-approval-broker.md](11-approval-broker.md) | approve the risk classes and TTLs |
| 12 | [12-test-plan.md](12-test-plan.md) | nothing — this is what will be run |
| 13 | [13-rollback-plan.md](13-rollback-plan.md) | nothing |
| — | [hostname-migration.md](hostname-migration.md) | decide whether the shorter hostname is wanted later |

Checkpoints 5 (schema reconciliation), 6 (additive migration, proposed only), 7 (permission
matrix and LabOps role guard) and the support-ticket integration live in the application repo,
`tcecure/drcc-lab-companion`, under `docs/labops-ai/phase2/`.

## Order of operations, once approved

1. PBS backup of VMID 100 — prerequisite for the nftables change, since a mistake there is
   recoverable only from the Proxmox console.
2. Real provider key into `/etc/labops/model-proxy.env`; `svc-drcc-labops-ai-ro` created.
3. `scripts/split-secrets.sh` (checkpoint 2), then `scripts/test-secret-isolation.sh`.
4. Model proxy up; `scripts/run-investigation.sh` smoke run; `test-investigation-isolation.sh`.
5. `scripts/bootstrap-host.sh` egress section; `test-egress-isolation.sh`.
6. One real read-only investigation end to end — the run checkpoint 1 cannot yet demonstrate.
7. Production migration — **done** (2026-08-29, owner-approved). There is no staging
   environment; the migration was validated on a throwaway local Postgres and its invariants
   replayed against production inside a rolled-back transaction. See
   `docs/labops-ai/production-first-workflow.md` and `phase2-apply-log.md` in the app repo.
8. Write flags stay `false` until each integration's runbook is separately approved and piloted.

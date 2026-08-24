# AWX read-only integration (`svc-drcc-labops-ai-ro`)

The full account-creation runbook — permissions, token creation, validation tests,
rotation, revocation — is the approval checkpoint in the application repo:
`docs/labops-ai/checkpoint-awx-readonly-runbook.md`. This file covers only how the
deployed gateway uses the account.

## Live AWX facts this integration relies on

| Object | ID | Use |
|---|---|---|
| AWX 24.6.1, org `Default` | — | API `v2` |
| Inventory `CRC-LabPods` | 4 | pod/host metadata |
| Inventory `CRC-Proxmox` | 3 | node metadata |
| Project `crc-awx-labops` | 10 | revision, last update |
| Project `CRC-LabOps` | 8 | revision, last update |
| Verify templates (AC 13, IA 16, SI 19, SC 22, MP 28, PE 31, all-labs 11) | — | job status and sanitized stdout |
| `Generate Completion Certificate` | 36 | job status only |

## What the gateway calls

Read-only `GET` only, from the host, over the internal network:

```
GET /api/v2/ping/
GET /api/v2/inventories/{4,3}/            GET /api/v2/inventories/4/hosts/
GET /api/v2/projects/{10,8}/
GET /api/v2/job_templates/{id}/           GET /api/v2/job_templates/{id}/jobs/?order_by=-finished&page_size=5
GET /api/v2/jobs/{id}/                    GET /api/v2/jobs/{id}/stdout/?format=txt
```

Enforced client-side as well as by AWX permissions:

- Method allow-list: `GET` only. `POST`/`PUT`/`PATCH`/`DELETE` are rejected before the request is built, so a prompt-injected instruction to launch a job fails in the gateway *and* would fail in AWX.
- Path allow-list: the object IDs above. `/api/v2/credentials/`, `/users/`, `/roles/`, `/settings/` and `ad_hoc_commands` are refused outright.
- Every call is written to `ai_tool_actions` with the URL, status and whether it was denied.
- stdout is truncated and passed through the redaction pipeline before it reaches the model — job output can contain hostnames and occasionally student identifiers.
- Failures are surfaced as degraded health, never retried aggressively; AWX is a shared production service.

## Credential handling

`LABOPS_AWX_TOKEN` lives only in `/etc/labops/labops.env` (`root:labops-gateway`, `0640`)
on `drcc-labops-01`. It is never sent to the browser, never included in a model request,
never written to Supabase, and never logged. Rotation is quarterly or incident-driven per
`runbooks.md`.

## Remediation is out of scope

Nothing in Phase 1 launches an AWX job. Approved remediation, when it comes, gets a
*separate* account with narrowly scoped `Execute` on named templates plus a human approval
gate — never an added grant on this read-only account.

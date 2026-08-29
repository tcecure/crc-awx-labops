# Checkpoint 10 — AWX execution account and template allow-list (nothing created yet)

**Status: proposal awaiting approval.** No account, token, team or role assignment has been
created. `svc-drcc-labops-ai-ro` keeps read-only scope and gains **no** execute permission —
and note from checkpoint 1 that it does not exist yet either (AWX currently has one user,
`admin`).

## Proposed identity

| Field | Value |
| --- | --- |
| User | `svc-drcc-labops-ai-exec` (AWX local user, no org admin, not superuser) |
| Token | OAuth2 personal token, scope `write`, stored only in `/etc/labops/gateway.env` as `LABOPS_AWX_EXEC_TOKEN` |
| Team | `labops-ai-exec`, granted **Execute** on the three job templates below and nothing else |
| Inventory | `4` only, and the gateway passes a limit; no inventory or credential edit rights |
| Denied | project update, credential read/change, template edit, ad-hoc commands, inventory edit, JT creation, workflow launch, anything on inventory 1 |

## Allow-listed templates — the complete list

| ID | Name | Playbook | Accepted extra vars (schema) | Systems touched | Expected change | Validation | Rollback | Risk | Approver |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 22 | Verify CMMC SC Labs | `playbooks/verify-cmmc-sc.yml` | `pod_limit`: `^pod(0[1-9]\|1[0-9]\|20)-gw$`; `sc_lab_id`: `^(ALL\|M[1-4]-L[1-3])$` | pod pfSense gateway (read) | none — read-only checks + AWX artifacts | job `successful`, artifacts parsed | none needed | **low** | `lab_admin` |
| 31 | Verify - PE Family | `playbooks/verify-cmmc-pe.yml` | `pod_limit`: `^pod(0[1-9]\|1[0-9]\|20)$`; `pe_lab_id`: `^(ALL\|M[1-4]-L[1-3])$` | pod DC evidence folders (read) | none | job `successful` | none needed | **low** | `lab_admin` |
| 45 | Seed SC M4-L1 Logs | `playbooks/seed-sc-m4l1-logs.yml` | `pods`: `^(all\|pod(0[1-9]\|1[0-9]\|20))$`; `pod_id`: `^(0[1-9]\|1[0-9]\|20)$` | one pod's pfSense `/var/log/filter.log` | replaces that pod's M4-L1 log evidence | job `successful` + verifier 22 re-run for that pod | re-run 45 for the pod, or the student's evidence is regenerated on next seed | **medium** (student-visible evidence) | `lab_admin` + owner |

Everything else in AWX is out of scope for the agent, explicitly including the templates that
destroy or rewrite student work: `9 Reset to Baseline`, `14/17/20/23 Reset * Labs`,
`29 Reset - MP`, `32 Reset - PE`, `12/15/18/21/27/30 Seed *` (full-family seeds),
`24 Auto-Advance Families`, `36 Generate Completion Certificate`, `37 Setup Certificate
System`, `43 Setup Domain Join Account`, `44 Provision Pod Member Server`, `11/13/16/19/28
Verify *` (family-wide verifies are staff-initiated, not agent-initiated), `7 Demo`.

## Gateway rejections (enforced regardless of AWX permissions)

Arbitrary template IDs; any inventory other than `4`; any extra variable not in the schema
above, or failing its regex; `all`-scoped seeding (a single pod at a time only); shell,
PowerShell, `win_shell`, `raw` or ad-hoc commands; credential read or use outside the
template's own credentials; any Proxmox mutation; any firewall rule change; any reset or
reseed not listed above; more than one AWX action in flight per run; a second execution of the
same idempotency key.

## Execution record

For every launch the gateway stores: template id + name, resolved extra vars, the AWX job id,
job status transitions, sanitized stdout tail (secrets and student PII redacted), and the final
result in `ai_tool_actions` and `audit_events`. A job that does not reach a terminal state
within the run's wallclock limit is marked `timeout`; the gateway never re-launches
automatically.

## Creation steps (only after approval)

1. AWX → Users → create `svc-drcc-labops-ai-exec`, random password, no roles.
2. Teams → create `labops-ai-exec`; add the user; grant **Execute** on templates 22, 31, 45 and
   **Read** on inventory 4. Nothing else.
3. Tokens → create a `write`-scope token as that user; install into `gateway.env`; restart the
   gateway; delete the local copy.
4. Self-test recorded in `audit_events`: launching template `9` must return 403, launching `22`
   with `pod_limit=pod01-gw` must succeed, and launching `22` with `pod_limit=$(whoami)` must be
   rejected by the gateway before AWX is contacted.
5. Enable with `LABOPS_AWX_EXEC_ENABLED=true` **and** `LABOPS_WRITES_ENABLED=true`, one pod, one
   template, with Eddie watching. Disable again after the pilot.

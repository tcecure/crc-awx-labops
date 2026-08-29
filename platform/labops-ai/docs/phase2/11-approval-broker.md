# Checkpoint 11 — Approval / execution broker design

Implemented in `tcecure/drcc-lab-companion` (`lib/labops/broker.ts`, `app/admin/labops/approvals`),
on top of the tables that already exist in production. No new ticket table, no second audit log.

## Reused tables (verified live in the DRCC project)

| Table | Role |
| --- | --- |
| `ai_approval_requests` | the approval record; today `id, run_id, requested_by, action_kind, action_payload, status, decided_by, decided_at, decision_note, expires_at, created_at` |
| `ai_tool_actions` | every attempted action, read or write, with `is_write`, `outcome`, sanitized `response_summary` |
| `audit_events` | actor / action / entity / before / after, append-only |
| `ai_knowledge_proposals` | Wiki.js proposals (checkpoint 9) |
| `integration_events` | **exists in production** (14 columns, with `idempotency_key`, `status`, `attempts`, `available_at`, `claimed_at`, `delivered_at`, `last_error`) — reused as the execution outbox rather than inventing one. It is **absent from staging**; see checkpoint 5. |

The additive migration adds only what is missing for the brief's required fields:
`risk`, `idempotency_key`, `params_hash`, `path_allow_list`, `execution_status`,
`execution_attempts`, `external_ref`, `result_summary`, `failure_reason`, `base_sha`,
`approved_params` (frozen copy) on `ai_approval_requests`, plus `approval_request_id` on
`ai_tool_actions`. No column is dropped or retyped.

## Lifecycle

```
agent proposes  ->  gateway validates + classifies  ->  ai_approval_requests(pending)
                                                          |
                          human approver (not requester)   v
                        reject ---------------------> rejected  (terminal, never executes)
                        expire ---------------------> expired   (terminal, never executes)
                        approve --------------------> approved, params frozen
                                                          |
                                                          v
                                   integration_events(pending, idempotency_key)
                                                          |
                                            single worker claims and executes once
                                                          v
                                   execution_status = succeeded | failed | timeout
                                   + ai_tool_actions row + audit_events row
```

## Invariants (each has a test in checkpoint 12)

1. **No self-approval.** `decided_by <> requested_by`, enforced by a DB check constraint *and*
   in the route. Eddie starting a run cannot approve its writes; a second approver is required.
2. **Expired approvals cannot be approved.** Approval route rejects when `expires_at <= now()`;
   a scheduled sweep moves stale rows to `expired`. Default TTL 24 h, 2 h for `high` risk.
3. **Parameters are immutable after approval.** `params_hash` is computed over the canonical
   JSON at proposal time; approval freezes `approved_params`; the executor recomputes the hash
   and refuses on mismatch. An edited proposal is a new request.
4. **Approved actions execute exactly once.** `integration_events.idempotency_key` is unique;
   the worker claims with `update ... where status='pending' returning`, so a double click, a
   retry or a gateway restart cannot double-execute.
5. **Rejected/expired never execute.** The executor's claim query requires
   `approval.status='approved'`.
6. **Approval and execution are separate.** Approving writes only to the approval row; a
   separate worker executes. A failed execution never re-opens the approval — a new one is
   required.
7. **Everything is logged.** Denial, validation failure, expiry, execution attempt, success and
   failure each produce an `audit_events` row and an `ai_tool_actions` row with sanitized
   payloads. Credentials and PII are redacted by the existing `lib/labops/redact.ts`.
8. **Kill switches.** `LABOPS_WRITES_ENABLED=false` (global) and the per-integration flags are
   checked at proposal time *and* immediately before execution, so flipping one mid-flight stops
   a queued action.
9. **Risk classification** is set by the gateway, not the agent: `low` (read-only,
   workspace-local), `medium` (draft PR, Wiki page in the LabOps namespace, single-pod reseed),
   `high` (anything touching more than one pod, or student-visible evidence). `high` requires
   the owner plus a second approver and has the short TTL.
10. **Workspace-local vs external.** Actions inside the investigation container (edit a file in
    `/workspace`, run a read-only command) are recorded in `ai_tool_actions` with
    `is_write=false` and need no approval. Anything that leaves the sandbox is an external write
    and must go through this broker; the agent has no credential and no route to perform one
    itself, so the boundary is enforced by architecture, not by prompt.

## Confirmation bridge (OpenHands side)

`AlwaysConfirm` stays on and is never weakened. The gateway polls/streams the conversation; when
an action enters `waiting_for_confirmation` it:

1. maps the pending action to an allow-listed `action_kind`, validating parameters against that
   kind's schema (unknown kind → auto-reject with a recorded reason);
2. creates the `ai_approval_requests` row with the sanitized parameters, the risk class and the
   human-readable diff/effect summary;
3. renders it in `/admin/labops/approvals` — parameters, risk, what will change, what will not;
4. on decision, returns `confirm`/`reject` to **that specific action id** in the conversation
   (never a blanket confirm), and for external kinds executes via the broker instead of letting
   the agent act;
5. writes the execution result back into the conversation as an observation, so the agent can
   continue with an accurate world view.

A pending confirmation that is never decided expires with the run's wallclock limit and the run
ends `cancelled`, not `succeeded`.

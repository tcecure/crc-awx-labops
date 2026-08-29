# Checkpoint 9 — Wiki.js write token runbook (nothing created yet)

**Status: proposal awaiting approval.** No write token has been created. `LABOPS_WIKI_TOKEN`
today is a placeholder, and `LABOPS_WIKI_WRITES_ENABLED=false`.

## Boundary

* The token lives **only** in `/etc/labops/gateway.env`. OpenHands never sees it, and
  `agent.env` cannot contain it (checkpoint 2 canary test asserts this).
* Knowledge output stays in `ai_knowledge_proposals`. Publication happens only after a human
  decision recorded on that row; the agent cannot publish.

## Requested identity

| Field | Value |
| --- | --- |
| Wiki.js group | `labops-ai-publisher` (new) |
| Permissions | `read:pages`, `write:pages`, `manage:pages` on the path rule `digitalrcc/labops/**` only |
| Denied | `delete:pages`, `manage:system`, `write:users`, `manage:groups`, `write:assets`, any path outside `digitalrcc/labops/**` |
| API user | `svc-drcc-labops-ai-wiki` (service account, no interactive login, 2FA n/a) |
| Token | Wiki.js API key bound to that group, 180-day expiry, recorded expiry date in the runbook |

## Publication flow

1. Agent produces a proposal → `ai_knowledge_proposals` (`status='pending'`, `target_path`
   must match `digitalrcc/labops/**`, else the row is rejected at insert time by the gateway).
2. Gateway fetches the **current** page version (`pages.single`) and renders a side-by-side
   diff of current vs proposed in `/admin/labops/approvals`. A proposal that would overwrite a
   page whose `updatedAt` changed since the diff was rendered is marked stale and must be
   refreshed — the same freshness rule used for tickets.
3. Approver (not the requester) approves; the gateway performs `pages.update` (or `pages.create`
   for a new path) with an idempotency key, records the resulting page id/version in
   `ai_tool_actions` and `audit_events`, and sets `published_at`.
4. Rejection or expiry never publishes. `LABOPS_WIKI_WRITES_ENABLED=false` and
   `LABOPS_WRITES_ENABLED=false` both block execution regardless of approval state.

## Creation steps (only after approval)

1. Wiki.js → Administration → Groups → create `labops-ai-publisher` with the page rules above.
2. Administration → API → create key, assign the group, 180 days.
3. On the host: add `LABOPS_WIKI_TOKEN` to `gateway.env`, `systemctl restart labops-gateway`.
4. Verify: gateway self-test writes to `digitalrcc/labops/_selftest`, reads it back, then
   asserts `403` for a write to `digitalrcc/handbook/**` and for `pages.delete`. Result in
   `audit_events`; the self-test page is left in place as evidence.
5. `LABOPS_WIKI_TOKEN` is added to the app's config schema (`lib/labops/config.ts`) in the
   companion PR so a missing value fails fast at boot instead of at publish time.

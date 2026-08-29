# Checkpoint 8 — GitHub App permission runbook (nothing created yet)

**Status: proposal awaiting Eddie's approval.** No app has been created, no credential
installed, no `LABOPS_GITHUB_*` value exists on the host. Approve this page first.

## Why an App and not a PAT

A fine-grained PAT is bound to a human account (Eddie's), cannot be scoped per repository
without also carrying his other access, and its expiry silently breaks automation. A GitHub
App installation gives a repo-scoped identity, per-repository install, revocable in one click,
and an audit trail attributed to the app rather than to a person.

## Requested identity

| Field | Value |
| --- | --- |
| App name | `DigitalRCC LabOps AI` |
| Owner | `tcecure` organization |
| Installed on | `tcecure/drcc-lab-companion`, `tcecure/crc-awx-labops` — **these two only** |
| Webhooks | disabled |
| Callback / device flow | disabled |
| Credential storage | private key at `/etc/labops/github-app.pem`, `root:labops-gateway 0640`; `LABOPS_GITHUB_APP_ID` / `LABOPS_GITHUB_INSTALLATION_ID` in `gateway.env` only |

## Repository permissions requested

| Permission | Level | Why |
| --- | --- | --- |
| Contents | Read & write | create a branch, commit an approved patch |
| Pull requests | Read & write | open a **draft** PR, post its body |
| Metadata | Read | mandatory |

Explicitly **not** requested: Actions, Workflows, Secrets, Environments, Administration,
Branch protection, Deployments, Packages, Members, Webhooks, Checks (write). The app cannot
merge, cannot approve, cannot force-push, cannot change protections and cannot deploy —
partly by permission, and additionally by the gateway's own guards below.

## Gateway-side guards (independent of GitHub permissions)

1. OpenHands never receives a GitHub credential. The agent produces a patch as text; the
   gateway applies it.
2. Repository must be in the allow-list; anything else is rejected before authentication.
3. Base must be a non-protected branch and the commit is pinned to the **exact base SHA** read
   at proposal time; if the base moved, the approval is stale and must be re-run.
4. Branch name is forced to `labops/<ticket-code>-<slug>`; existing branches are never reused.
5. Rejected outright: any path under `.github/workflows/`, `.github/actions/`, `Dockerfile`
   changes to CI images, `*.pem`, `.env*`, lockfile-only rewrites of registries, and any path
   outside the approved path allow-list carried on the approval record.
6. Secret scan (`gitleaks --no-git` over the patch) and `npm test`/`npm run typecheck`/
   `npm run build` must pass **before** the approval is presented, and the results are attached
   to the approval.
7. The complete diff is shown in `/admin/labops/approvals`; the parameters are immutable once
   approved (checkpoint 11).
8. PR is created as a draft, with `Written by Devin`-style provenance and the run id; no
   reviewer is auto-assigned, nothing auto-merges.
9. `LABOPS_GITHUB_WRITES_ENABLED=false` and `LABOPS_WRITES_ENABLED=false` by default; both must
   be flipped deliberately.

## Creation steps (only after approval)

1. Eddie: `github.com/organizations/tcecure/settings/apps/new`, name and permissions exactly as
   above, webhook unchecked, "Only on this account".
2. Generate a private key, download the `.pem`, note the App ID.
3. Install the app on the two repositories only, note the installation ID.
4. On `drcc-labops-01`: `install -m 0640 -o root -g labops-gateway app.pem
   /etc/labops/github-app.pem`, add the two IDs to `gateway.env`, `systemctl restart
   labops-gateway`. Delete the download.
5. Verify with the read-only self-test: gateway mints an installation token, calls
   `GET /installation/repositories`, asserts exactly the two repos, and asserts a write attempt
   against a protected branch returns 403. Recorded in `audit_events`.
6. Rotation: regenerate the key quarterly or on any suspicion; revoke by uninstalling the app
   (single click) — no other credential needs touching.

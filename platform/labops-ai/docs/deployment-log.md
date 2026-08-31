# drcc-labops-01 — deployment log (Phase 1)

Record of what has actually been executed on the host, as opposed to the plan in
`deployment-plan.md`. Nothing public has been exposed: no DNS record, no edge nginx
change, no port forward.

## Host

| Item | Value |
| --- | --- |
| Node | pve2 |
| VMID | 100 |
| Name | `drcc-labops-01` |
| Guest IP | 192.168.1.65/24, gw 192.168.1.1 |
| Resources | 8 vCPU, 24 GB RAM (balloon off), 200 GB on `local-lvm` |
| OS | Ubuntu 24.04 LTS cloud image, qemu-guest-agent enabled |
| Access | SSH key only, reachable from the lab management network via pve1 |

## Completed

1. Baseline: apt upgrade, chrony, fail2ban, unattended-upgrades, guest agent,
   `PasswordAuthentication no` / `PermitRootLogin no`.
2. Docker Engine 29.7.2 from Docker's apt repository, `live-restore`, capped json-file
   logging, private address pool `172.31.0.0/16`.
3. `nftables` default-drop inbound; only 22 and 3100 from 192.168.1.0/24, and an
   explicit drop for 8000. Verified from pve1: 8000 refused, 22 reachable.
4. Service account `labops-gateway` (nologin) plus `/etc/labops` (0750),
   `/opt/labops/app/{releases,shared}`, `/var/log/labops`.
5. `/etc/labops/labops.env` at `root:labops-gateway` 0640, host-local secrets generated
   in place (agent bearer key, webhook secret, `OH_SECRET_KEY`). The OpenAI key and the
   AWX token are still placeholders — the owner installs those.
6. Agent server running under `labops-agent.service` from the digest-pinned image, image
   pin re-checked at every start.

## Verified behaviour

| Check | Result |
| --- | --- |
| `GET /health` on 127.0.0.1:8000 | `{"status":"ok"}` |
| `GET /api/conversations` without the bearer key | 401 |
| Same request with `SESSION_API_KEY` | 422 (auth accepted, params missing) |
| Listener binding | `127.0.0.1:8000` only |
| Port 8000 from another host | refused |
| Read-only rootfs violations in logs | none |

## Corrections the first real deployment forced

- **Image digest.** The digest in compose is correct as written; `docker pull` returned
  `sha256:141a3628925a18ad55f07a09c0a1e3db9852ab0043458dbe7c8003c92396d143`, which is what
  `check-image-pin.sh` compares against. Earlier notes that recorded a shorter string were
  a transcription error, not a mismatch.
- **`pids_limit`.** Compose 5.x rejects a project that sets both `pids_limit` and
  `deploy.resources.limits.pids`; only the `deploy` form is kept.
- **`/tmp` needs `exec`.** The agent-server entrypoint maps shared objects out of `/tmp`,
  so a `noexec` tmpfs fails at start with
  `libz.so.1: failed to map segment from shared object`.
- **Writable config/cache.** Under a read-only rootfs, tool discovery tries to create
  `/home/openhands/.config`; small tmpfs mounts for `.config` and `.cache` (uid 10001)
  remove the startup errors without giving up the read-only rootfs.
- **`SESSION_API_KEY`.** `env_file` does not interpolate variables, so `gen-secrets.sh`
  writes the same value to `SESSION_API_KEY` and `LABOPS_AGENT_SERVER_API_KEY` instead of
  the file referencing one from the other.
- **nftables flush vs Docker.** `flush ruleset` removes Docker's `DOCKER-FORWARD` chains,
  after which container networking fails with
  `iptables: No chain/target/match by that name`. A drop-in on `nftables.service` restarts
  Docker after a reload so it rebuilds them.

## Gateway/frontend deployment

The gateway is a Next.js standalone build (`output: "standalone"` in the application repo,
required because the unit runs `node server.js`). Release layout on the host:

```
/opt/labops/app/releases/<utc-timestamp>/   # .next/standalone + .next/static + public
/opt/labops/app/current -> releases/<utc-timestamp>
```

Node.js 22.14.0 is installed from the NodeSource 22.x repository. `labops-gateway.service`
is enabled and listens on 3100; nftables only admits 3100 from `192.168.1.0/24`, so the
service is reachable from the edge proxy and the admin network, never from the internet.

| Check | Result |
| --- | --- |
| `GET /` on 127.0.0.1:3100 | 200 |
| `GET /api/labops/health` without a session | 401 `{"error":"Sign in required.","code":"unauthenticated"}` |
| `GET /admin/labops` without a session | 307 to sign-in |
| Port 3100 from outside `192.168.1.0/24` | dropped |

`verify-deployment.sh` previously expected `/api/labops/health` to return 2xx, which can
only happen if the endpoint stops requiring a session. The check now asserts the gateway
serves and that the health endpoint denies anonymous callers.

### Releases are environment-specific

The first release authenticated against the *production* Supabase project even though
`/etc/labops/labops.env` named staging: `NEXT_PUBLIC_*` values are inlined by
`npm run build`, and the build machine's `.env.local` pointed at production. Logins with
staging accounts failed with "Invalid login credentials" while the server-side reads used
staging. Build each release with the same project the host env names, and check the artifact
before promoting it:

```
grep -rl <expected-project-ref> /opt/labops/app/current/.next   # must match
grep -rl <other-project-ref>   /opt/labops/app/current/.next   # must be empty
```

`lib/env.ts` also validates `NEXT_PUBLIC_APP_URL`; without it every render throws a
`ZodError` and the host answers 500. It is now in the env file and the template.

### Environment file state

`/etc/labops/labops.env` (root:labops-gateway 0640) carries the Supabase URL, anon key and
service-role key, `LABOPS_OWNER_EMAIL`, `PORT=3100` and
`LABOPS_PUBLIC_URL=https://labops.drcc.digitalrcc.com`. `LABOPS_LLM_API_KEY` is still the
`REPLACE_ON_HOST_ONLY` placeholder: investigations will fail at the provider call until the
owner installs the real key on this host.

## Production cutover

The owner approved moving the pilot off DRCC-staging so portal logins work on the LabOps
host. Applied in this order:

1. The `ai_*` tables, RLS policies and helper functions were applied to the production
   project through the management API, then re-audited: 9 tables, RLS on all of them, 9
   policies, 3 helper functions, 0 rows.
2. The grant audit showed `anon`/`authenticated` still holding `TRUNCATE`, `TRIGGER` and
   `REFERENCES` from Supabase's defaults — none of which row-level security filters. They
   were revoked, leaving `authenticated` with `SELECT` only; the migration now revokes them
   too so a fresh apply matches.
3. A release was built with the production `NEXT_PUBLIC_*` values (the build machine's
   `.env.local` still names staging, so they are passed explicitly), verified with the grep
   check above (production ref in 7 files, staging ref in 0), then unpacked to
   `/opt/labops/app/releases/<utc-timestamp>` and promoted.
4. `/etc/labops/labops.env` was pointed at the production project; the previous file is kept
   as `labops.env.staging.bak` on the host for rollback.

Rollback is the symlink plus the env backup: repoint `current` at the previous release,
restore `labops.env.staging.bak`, restart `labops-gateway`.

## Edge / TLS

The edge is `crc-proxy-gateway-01` (VMID 101 on pve1, 192.168.1.55): nginx 1.18 with
per-host files in `sites-available` and certbot-managed certificates. SSH to it is still
unavailable, but the QEMU guest agent is enabled, so the vhost was installed through
`qm guest exec` from pve1.

- `nginx/labops.drcc.digitalrcc.com.conf` proxies to `192.168.1.65:3100`, disables
  buffering and raises the read timeout to an hour so the SSE activity relay survives long
  investigations.
- `location = /` returns `302 /labops` so the LabOps host lands on its own branded sign-in
  page instead of the shared portal home. It pointed at `/admin/labops` first, which worked
  but cost anonymous visitors a second hop through the auth redirect.
- `certbot --nginx --redirect -d labops.drcc.digitalrcc.com` issued the certificate and
  added the HTTP 301; renewal uses the host's existing scheduled task.
- `nginx -t` was run before the reload, and the other nine vhosts were re-checked after it
  (`crc.ai`, `my.digitalrcc.com`, `drcc.wiki`, the tracker) — all unchanged.

| Public check | Result |
| --- | --- |
| `https://labops.drcc.digitalrcc.com/` | 302 to `/labops` |
| `https://labops.drcc.digitalrcc.com/labops` | 200, login box only |
| `https://labops.drcc.digitalrcc.com/api/labops/health` | 401 unauthenticated |
| `https://labops.drcc.digitalrcc.com/admin/labops` | 307 to `/labops` |
| `http://labops.drcc.digitalrcc.com/` | 301 to https |
| `108.31.169.90:8000` and `:3100` | no route |

## Agent-server contract defects found by live testing

Three separate hops fail independently, and only the last one is the provider — worth
knowing before reading `/api/labops/health`, which covers the first two but not the third.

1. **Authentication.** `SESSION_API_KEY` is presented as `X-Session-API-Key`. The server's
   OpenAPI also advertises a bearer scheme, but that is a different credential and returns
   401 for this key.
2. **Conversation tags.** Tag keys must match `^[a-z0-9]+$`; `run_id` is a 422. The gateway
   sends `runid` / `supportrequestid`.
3. **Conversation store.** The container has a read-only rootfs, so
   `/home/openhands/.openhands` must be a writable volume owned by uid 10001, otherwise
   every `POST /api/conversations` 500s on `.../profiles`. `agent-home` in the compose file
   provides it (a tmpfs would drop every investigation on restart), `bootstrap-host.sh`
   sets the ownership, and `verify-deployment.sh` now checks the mount is writable.

4. **Tool names.** The registry keys are `terminal`, `file_editor`, `task_tracker`; class
   names like `TerminalTool` raise `KeyError` during agent initialization, which only
   happens once a conversation carries an `initial_message` — so a bare create probe
   returns 201 while every real start 500s.

`/health` on the agent server answers even when the key is wrong and even when the store is
unwritable, which is why the gateway's health check makes an authenticated call and the
verification script probes the mount directly.

## Release 20260825235156 — rebuilt from merged main

After application PR #4 merged, `origin/main` carried one commit the running release
predated (`fix: embed existing training tracker`), so the host was rebuilt from the merge
commit with the production Supabase values the host env names and promoted:

| Check | Result |
| --- | --- |
| Artifact carries production ref / staging ref | 16 files / 0 files |
| Deployed release under `/opt/labops/app/current/.next` | 7 files production, 0 staging |
| `labops-gateway` after restart | active |
| `/`, `/labops` on 127.0.0.1:3100 | 200, 200 |
| `/admin/labops`, `/api/labops/health` anonymous | 307, 401 |
| Public `/` and `/labops` | 302 → `/labops`, 200 |

## Release 20260829235329 — per-investigation runtime, applied to production

Applied to `drcc-labops-01` (the only environment; there is no staging), write switches all
still `false`.

Changes made on the host:

| Change | Detail | Rollback |
| --- | --- | --- |
| `platform/labops-ai` tree refreshed under `/opt/labops/platform` | root-owned, launcher `0755` | previous tree in `/etc/labops/backups` era release; re-extract from the repo at the prior commit |
| `/etc/sudoers.d/labops-gateway` | one rule for `run-investigation.sh`, `visudo -cf` clean | `rm /etc/sudoers.d/labops-gateway` (the gateway then cannot launch containers) |
| `/etc/labops/gateway.env` | appended `LABOPS_RUNTIME_*`, `LABOPS_MODEL_PROXY_TOKEN`, `LABOPS_AGENT_IMAGE`, `LABOPS_AGENT_ENV_FILE`, `LABOPS_WORKSPACE_RETENTION_HOURS`; timestamped copy in `/etc/labops/backups` | restore that copy, restart the gateway |
| `labops-gateway.service`, `labops-agent.service` | gateway now reads `gateway.env`; `NoNewPrivileges=no` so it can call `sudo -n` for the launcher | previous units are in the git history; `systemctl daemon-reload` after restoring |
| App release `20260829235329` promoted via `/opt/labops/app/current` | per-run runtime, restart recovery, deadline sweep | repoint the symlink at `20260825235156`, restart |
| 4 investigation containers left by an interrupted 2026-08-29 test | stopped through the launcher | none needed |

Results:

| Test | Result |
| --- | --- |
| `test-investigation-isolation.sh` (real pinned image, two runs) | PASS — non-root, read-only rootfs, own volume only, no host bind, no usable container tooling, limits applied, cross-run filesystem denial |
| Cross-investigation network denial (new) | PASS — B cannot reach A's agent port, AWX, a student pod or the internet; only the model proxy answers |
| `test-secret-isolation.sh` | PASS — no Supabase/AWX/Wiki/provider credential in the container, its env, `/proc`, or on disk |
| `test-egress-isolation.sh` | PASS — only `…/v1/` through the proxy; proxy refuses other paths, CONNECT, and never echoes the key |
| `verify-deployment.sh` | ALL CHECKS PASSED |
| Gateway restart with an investigation container present | reaped it: `restart recovery ended 0 investigation(s) and reaped 1 workspace(s)` |
| Local console after deploy | `/labops` 200 |
| Public edge from off-host | `/` 302, `/labops` 200, `/api/labops/health` 401 |
| Existing systems | `crc.ai` 307, tracker 302, `my.digitalrcc.com` 200 — unchanged |

Two defects the deployment exposed, both fixed in code rather than on the host:

1. The first release was built with the developer's `.env.local`, which still names the
   legacy `DRCC-staging` project; `NEXT_PUBLIC_*` values are inlined at build time, so the
   gateway held a staging URL with the production service key and every query failed with
   *Invalid API key*. **Builds for this host must export the host's own public Supabase
   values**, which is how release `20260829235329` was produced.
2. Reaping a container whose run has no `ai_runs` row hit the `ai_tool_actions` foreign key
   and abandoned recovery. Cleanup of an unknown container is no longer audited against a
   run that does not exist.

## Release 20260830191742 — runtime failure text sanitised, applied to production

App-only promotion; no host configuration, network rule or write switch changed (all five
switches still `false`), and no production row touched other than removing the two approved
throwaway test accounts.

| Change | Detail | Rollback |
| --- | --- | --- |
| App release `20260830191742` promoted via `/opt/labops/app/current` | runtime failures reported to staff without the launcher path, its stderr or the raw spawn error; the detail goes to the service journal only | `ln -sfn /opt/labops/app/releases/20260829235329 /opt/labops/app/current && systemctl restart labops-gateway` |
| `labops-test-staff@tcecure.com`, `labops-test-student@tcecure.com` | created for authenticated testing under owner approval, then deleted with their `profiles`/`user_roles` rows | re-create with the same procedure if further authenticated testing is approved |

Results:

| Test | Result |
| --- | --- |
| Artifact check before promotion | production ref in 19 files, legacy staging ref in 0, `could not be invoked: ` in 0 |
| `verify-deployment.sh` after promotion | ALL CHECKS PASSED |
| Local console | `/` 200, `/labops` 200, `/api/labops/health` 401 anonymous |
| Public edge from off-host | `/` 302, `/labops` 200, `/api/labops/health` 401 |
| Existing systems | `crc.ai` 307, tracker 302, `my.digitalrcc.com` 200 — unchanged |
| Gateway journal after restart | started clean, `NRestarts=0`, launcher `list` call succeeded (restart recovery ran, nothing to reap) |
| Not-configured route matrix under `next build && next start` | all 10 gateway routes `503 application/json {"code":"not_configured"}` |
| Test accounts after the run | both absent from `auth.users`, `profiles` and `user_roles` |

Local canary testing (a `next dev` harness with fake credentials, no production data) reported
two defects, both now closed:

1. A start against a host with no launcher returned the raw spawn error, including the
   launcher path, and that text was persisted as `ai_runs.failure_reason` and rendered in the
   investigation list, the detail banner and tool-action summaries. Staff now see a fixed
   message and the host detail is written only to `journalctl -u labops-gateway`.
2. `.../cancel`, `.../findings-note` and `.../activity` answered `404 text/html` in
   not-configured mode. That is a `next dev` on-demand compilation artefact: under a
   production build every gateway route answers `503` JSON, verified above.

## Provider key installed — model proxy only

The owner supplied the OpenAI key and it was written to `/etc/labops/model-proxy.env`
(`root:root 0640`), the only file on the host that holds it. The previous file was kept as
`model-proxy.env.bak-<epoch>`; the key was piped over stdin to a root-only script, so it never
appeared in a shell history, a log line or a repository.

| Check | Result |
| --- | --- |
| `LABOPS_LLM_API_KEY` in `gateway.env` | still the `via-model-proxy` sentinel |
| provider key in `agent.env` | absent |
| `labops-model-proxy` container env | holds the key; investigation containers are not part of the compose stack and receive neither the key nor the proxy env file |
| proxy without a run id (`/v1/models`) | `400 labops: missing X-LabOps-Run` — a call cannot bypass run accounting |
| proxy with a run-scoped path (`/r/<uuid>/v1/models`) | `200` from `api.openai.com`, so the key is valid and reaches the provider through the proxy only |
| `LABOPS_LLM_MODEL` (`openai/gpt-5.5`) | present in the account's model list |

Rollback: `sudo cp /etc/labops/model-proxy.env.bak-<epoch> /etc/labops/model-proxy.env &&
sudo systemctl restart labops-agent.service` restores the placeholder; revoking the key at the
provider is the owner's control.

## First pilot attempt: `Agent server returned 500`, and the fix

The owner started the pilot investigation on the designated test ticket
(`support_requests` `199eaa35-…`, run `9fd501bb-…`). Sanitized intake was persisted, the
container launched, and `POST /api/conversations` then failed. The run was recorded as
`provider_error` with `Agent server returned 500` and no conversation id.

The agent container's own log gave the cause: while starting a conversation the SDK creates
its LLM profile store under `/home/openhands/.openhands`, which the read-only rootfs refused
(`OSError: [Errno 30] Read-only file system`). Nothing to do with the provider key — a call
from inside an investigation container through the run-scoped proxy returns a real completion
from `gpt-5.5` (`/v1/models` `200`, `/v1/chat/completions` `200`).

`run-investigation.sh` now mounts a `64m` tmpfs at `/home/openhands/.openhands`
(`0700`, owned by `10001`), alongside the existing `.config` and `.cache` mounts, so the
state stays inside the run and dies with it. `POST /api/conversations` returns `201` on a
freshly launched container, and `test-investigation-isolation.sh` — which now asserts that
directory is writable — passes every check, including cross-investigation network denial and
workspace destruction.

Rollback: `sudo cp /opt/labops/platform/labops-ai/scripts/run-investigation.sh.bak-<stamp>
/opt/labops/platform/labops-ai/scripts/run-investigation.sh`. No service restart is needed —
the gateway invokes the script per run.

## Release 20260831111015 — the operator can answer the agent's confirmation gate

The first pilot run reached `Awaiting Approval` — the agent server holds every proposed
action under `AlwaysConfirm` — and the console had no way to answer it, so the run could not
progress at all. App-only promotion; no host configuration, network rule, image or write
switch changed (all five switches still `false`).

| Change | Detail | Rollback |
| --- | --- | --- |
| App release `20260831111015` promoted via `/opt/labops/app/current` | owner-only `POST /api/labops/investigations/{id}/step` (`{ accept, reason? }`) plus the Allow/Refuse control on the run page; usage read from `stats.usage_to_metrics`, where the pinned agent server actually reports it; the activity relay resumes from a persisted cursor instead of replaying the timeline | `ln -sfn /opt/labops/app/releases/20260830191742 /opt/labops/app/current && systemctl restart labops-gateway` |

Verified against the live agent server before wiring the app to it:
`POST /api/conversations/<id>/events/respond_to_confirmation` with `{"accept":true}` returned
`200 {"success":true}`, the held `find` command ran, and the agent proposed its next step
(spend moved `$0.04848` → `$0.064838`), so the gate resumes rather than ending the run.

| Test | Result |
| --- | --- |
| Artifact check before promotion | production Supabase ref in 19 server files, legacy staging ref in 0 |
| `verify-deployment.sh` after promotion | ALL CHECKS PASSED |
| Local console | `/labops` 200, `/api/labops/health` 401 anonymous, `/api/labops/investigations/<id>/step` 401 anonymous |
| Restart recovery | ended the in-flight run `b557c4e3` as designed and destroyed its workspace — no investigation container or volume remains |

Cost of the promotion: an investigation open at restart is always ended by recovery, so the
first pilot run was terminated by this deploy and the approval path has to be exercised on a
fresh run.

## Release 20260831114521 — the held step survives a page reload

UI testing of the previous release against a local stack found one real defect in the safety
gate itself: on a fresh load of a run in `awaiting_approval` the Allow/Refuse panel said
"The proposed step has no description", because the panel derived the description only from
live relay frames and the relay deliberately resumes past events it has already persisted.
An operator could therefore approve an action blind. App-only promotion; no host
configuration, network rule, image or write switch changed (all five switches still `false`).

| Change | Detail | Rollback |
| --- | --- | --- |
| App release `20260831114521` promoted via `/opt/labops/app/current` | the run page reads the held action out of the persisted `ai_run_events` timeline and hands it to the decision panel, so the description is present after a reload or a relay reconnect; a run with no agent conversation now answers `409` rather than `404` | `ln -sfn /opt/labops/app/releases/20260831111015 /opt/labops/app/current && sudo systemctl restart labops-gateway` |

| Test | Result |
| --- | --- |
| `npm run typecheck`, `npm run lint`, `npm test` | pass, 192 tests (2 new: relay cursor, held-step summary) |
| Artifact check before promotion | production Supabase ref in 19 server files, legacy staging ref in 0 |
| `verify-deployment.sh` after promotion | ALL CHECKS PASSED |
| Local console | `/labops` 200, `/api/labops/health` 401 anonymous, `/api/labops/investigations/<id>/step` 401 anonymous |
| Edge | `/labops` 200, health 401, `/step` 401 anonymous; `crc.ai` 307 and the portal 200, unchanged |
| Containers after restart | no investigation container or volume remains |

## Not done yet

- AWX read-only token installation — owner-supplied.
- PBS backup job for VMID 100.

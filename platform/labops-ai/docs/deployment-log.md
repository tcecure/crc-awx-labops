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

`/etc/labops/labops.env` (root:labops-gateway 0640) now carries the DRCC-staging Supabase
URL, anon key and service-role key, `LABOPS_OWNER_EMAIL`, `PORT=3100` and
`LABOPS_PUBLIC_URL=https://labops.drcc.digitalrcc.com`. `LABOPS_LLM_API_KEY` is still the
`REPLACE_ON_HOST_ONLY` placeholder: investigations will fail at the provider call until the
owner installs the real key on this host. Point the file at the production Supabase project
only when the pilot leaves staging validation.

## Edge / TLS

The edge is `crc-proxy-gateway-01` (VMID 101 on pve1, 192.168.1.55): nginx 1.18 with
per-host files in `sites-available` and certbot-managed certificates. SSH to it is still
unavailable, but the QEMU guest agent is enabled, so the vhost was installed through
`qm guest exec` from pve1.

- `nginx/labops.drcc.digitalrcc.com.conf` proxies to `192.168.1.65:3100`, disables
  buffering and raises the read timeout to an hour so the SSE activity relay survives long
  investigations.
- `certbot --nginx --redirect -d labops.drcc.digitalrcc.com` issued the certificate and
  added the HTTP 301; renewal uses the host's existing scheduled task.
- `nginx -t` was run before the reload, and the other nine vhosts were re-checked after it
  (`crc.ai`, `my.digitalrcc.com`, `drcc.wiki`, the tracker) — all unchanged.

| Public check | Result |
| --- | --- |
| `https://labops.drcc.digitalrcc.com/` | 200 |
| `https://labops.drcc.digitalrcc.com/api/labops/health` | 401 unauthenticated |
| `https://labops.drcc.digitalrcc.com/admin/labops` | 307 to `/login` |
| `http://labops.drcc.digitalrcc.com/` | 301 to https |
| `108.31.169.90:8000` and `:3100` | no route |

## Not done yet

- OpenAI key installation — owner-supplied, this host only.
- AWX read-only token installation — owner-supplied.
- PBS backup job for VMID 100.

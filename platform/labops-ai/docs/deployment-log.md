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

## Not done yet

- Gateway/frontend deployment (`labops-gateway.service`) — waits on the application build.
- OpenAI key and AWX read-only token installation — owner-supplied.
- Edge nginx vhost and the `labops` DNS record — approval-gated, and SSH to the edge host
  at 108.31.169.90 is still unavailable.
- PBS backup job for VMID 100.

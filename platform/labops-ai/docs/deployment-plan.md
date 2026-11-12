# Approval checkpoint — LabOps AI infrastructure deployment plan

Target host: **`drcc-labops-01`** on **pve2**. Nothing below has been executed.

## 1. VM

| Setting | Value | Reason |
|---|---|---|
| Name | `drcc-labops-01` | New `drcc-` convention; existing `crc-*` names unchanged |
| Node | pve2 | ~88 GB free RAM, ~1.24 TB free `local-lvm`; pve1's 52 GB free is earmarked for the last seven POD-SRVs |
| VMID | next free on pve2 (**not** 105) | 105 is `crc-ai-ide-01`, which stays untouched |
| vCPU | 8 (host type) | Agent + one capped workspace |
| RAM | 24 GB, ballooning off | Fits with 64 GB still free on pve2 |
| Disk | 200 GB on `local-lvm`, discard on, SSD emulation on | Images, workspaces, artifacts |
| NIC | `vmbr0`, firewall enabled, static IP from the server range | Same segment as the other management VMs |
| OS | Ubuntu 24.04 LTS (cloud image) | Matches the rest of the estate |
| Guest agent | on | Needed for clean PBS backups |
| Backup | PBS, daily, keep 7 daily / 4 weekly | `/etc`, `/opt/labops`, the artifact volume |

pve2 after the build: ~64 GB RAM free, ~1.04 TB disk free. No effect on pve1 or the pods.

## 2. Network position

```
internet ──▶ 108.31.169.90  edge nginx (TLS, existing host)
                 │  proxy_pass  http://drcc-labops-01:3100
                 ▼
         drcc-labops-01
           :3100  gateway + frontend      (only inbound port, edge only)
           127.0.0.1:8000  agent server   (loopback only, never exposed)
           docker workspace net           (internal, egress allow-listed)
```

Outbound from the host: `api.openai.com:443`, `ghcr.io`/`*.githubusercontent.com:443`
(image pulls, review-time only), `192.168.1.103:30080` (AWX, read-only),
`192.168.1.42:80` (Wiki.js read), Supabase `*.supabase.co:443`, Ubuntu archives.
Everything else denied. Workspace containers get a narrower allow-list still, and no route
to pod networks.

**Not created:** any port forward to this VM, any public DNS for it, any route from a pod
network to it, any Proxmox API write credential.

## 3. Host firewall (nftables, default deny inbound)

| Direction | Rule |
|---|---|
| in | `ct state established,related accept` |
| in | `tcp dport 22` from the admin/VPN range only |
| in | `tcp dport 3100` from the edge proxy address only |
| in | everything else `drop` (logged) |
| out | allow-list above, then `drop` (logged) |

Proxmox VM firewall enabled as a second layer with the same inbound rules.

## 4. Install order

1. Create the VM (Proxmox UI or the documented `qm` commands); nothing else on pve2 is touched.
2. Baseline: `unattended-upgrades`, SSH keys only (no password auth), `fail2ban`, NTP, `nftables` ruleset above, non-root `labops-gateway` service user.
3. Docker Engine from Docker's apt repo, pinned version; daemon with `live-restore`, `userland-proxy=false`, log rotation, `no-new-privileges` default.
4. `docker compose pull` the digest-pinned agent-server image; verify the digest matches this repo before starting anything.
5. `/etc/labops/labops.env` created `root:labops-gateway 0640` from `env/labops.env.example`. **You** paste the OpenAI key and the AWX token; generated values (`SESSION_API_KEY`, `OH_SECRET_KEY`, webhook secret) come from `scripts/gen-secrets.sh` and never leave the host.
6. Deploy the gateway/frontend build, `systemctl enable --now labops-agent labops-gateway`.
7. `scripts/verify-deployment.sh` (section 6) — must be fully green before any DNS work.
8. Edge nginx vhost + certificate, then the Namecheap record — separate approval (`checkpoint-dns-tls.md` in the app repo).

Superseded 2026-08-29: there is no staging Supabase project, so the stack is validated on the VM
against production over an SSH tunnel before the hostname exists, with production treated
read-only. See `docs/labops-ai/production-first-workflow.md` in the app repo.

## 5. Resource limits

| Scope | Limit |
|---|---|
| Agent server container | 4 CPU, 8 GB, restart `on-failure:3`, read-only root FS with tmpfs `/tmp` |
| Workspace container | 2 CPU, 4 GB, 10 GB, `pids-limit 512`, no host mounts, no docker socket, dropped capabilities |
| Run wall clock | 20 min, then interrupt + destroy |
| Active investigations | 1 (also a database invariant) |
| Artifact retention | 30 days, purge timer |
| Disk guard | alert at 80 %, refuse new runs at 90 % |

## 6. Verification (all must pass, `scripts/verify-deployment.sh`)

```
pre:   crc.ai.tcecure.com 200/307, training.status.tcecure.com 200/302, my.digitalrcc.com 200
       pve2 free RAM > 32 GB, local-lvm free > 500 GB
post:  systemctl is-active labops-agent labops-gateway
       curl 127.0.0.1:8000/health           -> ok  (from the host only)
       curl 127.0.0.1:3100/api/labops/health-> ok, no secret substrings in the body
       docker inspect: agent image digest == pinned digest
       nft list ruleset: default-deny present, 8000 not open
       from another host: 8000 refused, 3100 refused except from the edge
       docker inspect workspace: no bind mounts, no docker.sock, cpu/mem/pids limits set
       agent server telemetry disabled (DO_NOT_TRACK=1)
post:  crc.ai / tracker / portal unchanged (same checks as pre)
```

## 7. Rollback

| Failure | Action |
|---|---|
| Gateway bad release | `systemctl stop labops-gateway`, redeploy previous build directory, restart (previous release kept on disk) |
| Agent-server upgrade regression | revert the digest in `compose/docker-compose.yml`, `docker compose up -d`; the old image is retained until the new one is signed off |
| Host unrecoverable | restore the PBS snapshot; the VM holds no authoritative data — runs live in Supabase |
| Abandon entirely | stop and remove the stack, delete the VM, remove the DNS record and the edge vhost; nothing else is affected |

Every step is reversible and nothing in it modifies pods, DC01, AWX contents, `crc.ai` or
the portal database.

## Approval requested

- [ ] VM shape (8 vCPU / 24 GB / 200 GB on pve2) and the new VMID.
- [ ] Network position: single inbound port from the edge, agent server loopback-only, egress allow-list.
- [ ] Install order, including that you install the OpenAI key and AWX token yourself in step 5.
- [ ] Go-ahead to create the VM (DNS and production cutover remain separately gated).

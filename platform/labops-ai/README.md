# DigitalRCC LabOps AI — infrastructure (`drcc-labops-01`)

Deployment automation for the private OpenHands Agent Server and the DigitalRCC AI
Gateway. Application code lives in [`tcecure/drcc-lab-companion`](https://github.com/tcecure/drcc-lab-companion)
(`docs/labops-ai/` for the architecture, threat model and approval checkpoints).

**Nothing here has been executed.** No VM has been created, no DNS changed, no secret
installed. This is the plan plus the automation to run it after approval.

**No secrets in this directory** — `env/*.example` files contain placeholders and variable
names only.

| Path | Contents |
|---|---|
| `docs/deployment-plan.md` | The approval checkpoint: VM shape, network, firewall, install order, verification, rollback |
| `docs/awx-readonly-integration.md` | How the gateway talks to AWX, and the read-only account it requires |
| `docs/runbooks.md` | Backup, update, rollback, incident and rotation runbooks |
| `env/labops.env.example` | Gateway + agent-server environment template |
| `compose/docker-compose.yml` | Pinned agent-server + gateway services, resource caps, internal-only networking |
| `systemd/labops-*.service` | Unit files for the compose stack and the gateway |
| `scripts/` | Preflight, verification and backup helpers |

## Non-negotiables encoded here

- Agent server is bound to `127.0.0.1:8000` — no public DNS, no port forward, no host `0.0.0.0` bind.
- Image is digest-pinned (`agent-server:1.42.1-python@sha256:141a36…`); `:latest` is never used.
- The browser reaches only the gateway; the gateway is the only holder of the agent-server bearer key, the OpenAI key and the AWX token.
- Host firewall default-deny inbound except SSH from the admin range and 3100 from the edge proxy.
- `crc-ai-ide-01` (VMID 105) and everything under `crc.ai.tcecure.com` are untouched; `scripts/verify-deployment.sh` checks `crc.ai` before and after every change.

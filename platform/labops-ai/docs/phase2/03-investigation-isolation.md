# Checkpoint 3 — Per-investigation isolation

## Finding that changes the design (read this first)

The brief requires that "terminal commands must not inherit the model provider network
access", and says to stop and propose an alternative if the pinned OpenHands agent server
cannot separate model traffic from tool traffic. **It cannot.** Evidence from the running
image and from upstream source:

* `POST /api/conversations` accepts `workspace` typed as `LocalWorkspace` only
  (`openapi.json` on the live container: `"workspace": {"$ref": ".../LocalWorkspace-Input"}`).
  `RemoteWorkspace` exists in the SDK but is a *client-side* concept and is not selectable
  through the agent-server REST API — upstream `openhands-agent-server/models.py` still types
  the start request's workspace as a local workspace.
* Consequently the LLM client and the `bash`/file tools run **in the same container, same
  network namespace, same uid (10001)**. No container-level, uid-level or netns-level control
  can give one of them provider access and deny the other, because they are the same process
  tree with the same identity.

So the pinned architecture (one long-lived shared agent container, `LocalWorkspace`,
provider key in its environment) cannot satisfy Phase 2 and is replaced.

## Design B — per-investigation agent container with a single mediated hole

One ephemeral container **per investigation**, created and destroyed by the gateway:

```
gateway (host, holds every real secret, no docker socket)
   │  sudo -n scripts/run-investigation.sh {start,inspect,stop,list}
   │  then HTTP straight to the container's address on the internal net
   ▼
labops-inv-<run_id>            (ghcr.io/openhands/agent-server, pinned digest)
   user 10001, read_only rootfs, cap_drop ALL, no-new-privileges,
   no host mounts, no docker socket, private volume labops-inv-<run_id>:/workspace,
   cpus 2 / memory 4g / pids 512, wall clock enforced by the gateway,
   networks: labops-model (internal: true) only
   │  base_url http://172.31.241.2:8081/r/<run_id>/v1
   ▼ only reachable destination
labops-model-proxy             (nginx, holds the provider key, on labops-model + labops-egress)
   allow-list: https://api.openai.com/v1/… , per-run path, proxy bearer required
```

Properties, mapped to the brief:

| Requirement | How |
| --- | --- |
| separate ephemeral sandbox per investigation | `docker run --name labops-inv-<run_id>` on start; `docker rm -f` + volume disposal on completion |
| dedicated workspace volume | `labops-inv-<run_id>` volume, created per run, never shared, mounted `volume-nocopy` so the uid 10001 ownership set at creation stands |
| non-root | image uid 10001; `--user 10001:10001` asserted at launch |
| read-only root filesystem | `--read-only` plus explicit tmpfs for `/tmp`, `.config`, `.cache` |
| no host filesystem mounts | launcher refuses to hand over a container whose `.Mounts` contain any bind other than the `/dev/null` masks; verifier re-asserts it |
| no Docker socket | never mounted; verifier asserts no `/var/run/docker.sock` in `Binds`/`Mounts`. The gateway itself has no socket either: it reaches docker only through one root-owned launcher allowed by `/etc/sudoers.d/labops-gateway` |
| container tooling unusable | `docker`, `nsenter`, `runc`, `ctr`, `sudo`, `su` are resolved inside the image and masked with a non-executable bind. A command backed by a multi-call binary (busybox) is left alone: masking that file would take the shell down with it, and none of it grants privilege under `cap_drop ALL` + `no-new-privileges` |
| no shared workspace | one volume per run; volume name derived from run id; cross-run test below |
| CPU / memory / PID / time limits | `--cpus 2 --memory 4g --memory-swap 4g --pids-limit 512`; the gateway's deadline sweep enforces `LABOPS_RUN_WALLCLOCK_MINUTES`, marks the run `timed_out` and destroys the container. A per-volume disk quota is not applied: overlay2 on ext4 cannot enforce `--storage-opt size`, so workspace growth is bounded by the run's wall clock and the host's own disk alerting |
| retention | on run end the gateway archives `findings`/`resolution` to Supabase and destroys the volume; nothing from the workspace is retained beyond `LABOPS_WORKSPACE_RETENTION_HOURS` (default 0 = immediate) |
| one active investigation | `LABOPS_MAX_ACTIVE_RUNS=1` stays in force; it is raised only temporarily by the cross-run isolation test itself |
| no multi-operator execution | unchanged: owner-only start/cancel |
| cleanup on every terminal path | success, cancellation, failure, budget stop, deadline, and gateway restart all destroy the container and volume, and record `runtime.workspace.destroy` in `ai_tool_actions` |
| restart recovery | on Node startup the gateway ends runs the database still calls active (`failure_reason=gateway_restart`), destroys their workspaces, and reaps any investigation container with no active run behind it |

The long-lived `labops-agent-server` container is retired: it is the thing that held the
shared workspace and the provider key. Compose keeps only the model proxy as a service;
investigation containers are created imperatively by the gateway (`scripts/run-investigation.sh`
is the reference implementation and the test harness).

## Residual risk, stated plainly

Because the tool and the model client are one process, a terminal command inside an
investigation container *can* reach the model proxy and spend tokens. It cannot obtain the
provider key, cannot reach anything else on any network, and every proxy request is counted
against the run budget and logged. This is the irreducible residual of the pinned image, and
it is the reason `LABOPS_MAX_ACTIVE_RUNS` stays at 1. Full separation requires either
(a) an OpenHands release that lets the server drive a remote execution workspace, or
(b) moving tool execution to our own executor. Both are Phase 3 candidates; neither is a
prerequisite for read-only Phase 2 work under Design B.

## Cross-investigation isolation test

`scripts/test-investigation-isolation.sh` (run on the live host; it creates only its own
throwaway containers and volumes and destroys them):

1. Start run A; write `/workspace/secret-A.txt` with a random canary.
2. Start run B (temporarily raising the concurrency cap for the test only, then restoring it).
3. From B: `ls /workspace` shows no `secret-A.txt`; `grep -R <canary-A> /` finds nothing;
   `ls /proc/*/root` cannot traverse into A; `docker`, `nsenter`, `/var/run/docker.sock` absent.
4. From B: attempt `ls /host`, `cat /etc/labops/gateway.env`, `cat /proc/1/environ | grep
   SUPABASE` — all must fail.
5. Destroy both; assert both volumes are gone and neither canary survives in any volume.
6. From B: TCP connect to A's own agent port, to AWX, to a student pod and to the internet —
   all must fail, since the host's forward policy allows only the proxy — while the model
   proxy must be reachable.
7. Restart the gateway mid-run and assert the run is reconciled (marked `failed` with
   `failure_reason=gateway_restart` and its workspace destroyed), never silently resumed.

Each step writes a pass/fail line and the whole script exits non-zero on any failure, so it
can be attached to the checkpoint as evidence.

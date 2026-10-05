# CyDeploy on inactive pods — architecture and operations

How the CyDeploy Community Edition labs are deployed to pods that are **not** in
use, without touching a pod an active student is sitting in.

Read `CYDEPLOY-GO-LIVE.md` for what must be true before the labs are shown to
students. This document covers how the automation works, how to run it, how to
roll it back, and what to do when it refuses.

---

## Why this is built the way it is

Three facts drive the whole design.

1. **Pods are not interchangeable.** At any time some pods hold a live student's
   work. Writing to one of those pods destroys work and interrupts a class.
2. **A static list of "free pods" goes stale.** Enrollment changes daily. Any
   list committed to this repository is a hint, never permission.
3. **Shared infrastructure is load-bearing.** DC01-P01 and DC02-P01, the pod
   gateways, the Dream Wall, Guacamole and the reverse proxy serve all 20 pods at
   once. CyDeploy work must never reach them.

So targets are named explicitly by an operator, and then re-proved from live data
on every single run, on the pod server itself.

---

## What runs where

| Component | Host | Role |
|-----------|------|------|
| Lab artifacts, seeded conditions, student responses | `PODNN-SRV` | Everything a student touches lives on their own pod member server |
| CyDeploy Community Edition | `PODNN-SRV` | Installed per pod, scoped to the pod only |
| Preflight eligibility data | Portal API | `https://my.digitalrcc.com/api/integrations/awx/pod-eligibility` |
| Snapshots | `pve1` | `cydeploy-baseline` per pod VM, VMID `400 + pod number` |
| Grading | AWX → `PODNN-SRV` | Verifiers read live host state, not just the student's claims |

The shared domain controllers are a **dependency** of the labs (logon, DNS,
policy, the evidence drop share) and are never read or written by any CyDeploy
playbook.

---

## Target selection

Every CyDeploy playbook takes `cydeploy_targets`, and it is `| mandatory`:

```bash
ansible-playbook -i inventories/prod.ini playbooks/cydeploy/preflight.yml \
  -e cydeploy_targets=pod19-srv
```

Forgetting it is a hard error, not a default. There is no all-pods group, no pod
range fallback, and no wildcard anywhere in the CyDeploy tree —
`tests/test_cydeploy_targeting.py` fails the build if one is reintroduced.

`vars/cydeploy-pods.yml` and the `cydeploy_*` groups in `inventories/prod.ini`
carry the lists:

| Group | Contents | Meaning |
|-------|----------|---------|
| `cydeploy_protected_active_pods` | pods 01–04 | Never a CyDeploy target |
| `cydeploy_pilot_pods` | pods 19–20 | Phase 1 |
| `cydeploy_wave_two` | pods 15–18 | Phase 2 |
| `cydeploy_wave_three` | pods 05–14 | Phase 3 |

Reconcile these against the portal immediately before each phase. Static
approval is necessary and not sufficient.

---

## Preflight — the gate

`roles/cydeploy_preflight` runs at the start of **every** mutating and verifying
playbook. It is fail-closed: missing data is not approval.

A target proceeds only when all of this holds:

- the hostname matches `podNN-srv`, and the pod is on the approved list;
- the pod is not on the protected list, and the two lists do not intersect;
- `ansible_host` equals `10.50.<pod>.20`, and the host resolves to it;
- the host reports its own name as `PODNN-SRV`, and is not a DC or gateway;
- the Proxmox VM for VMID `400 + pod` is the pod's VM;
- the portal reports **no** active, queued or notified assignment for the pod;
- the portal reports **no** open Guacamole session, and no Guacamole activity in
  the last `cydeploy_quiet_minutes` (default 120);
- the Guacamole collector itself is healthy and fresher than
  `cydeploy_eligibility_max_age_minutes` (default 30);
- the `cydeploy-baseline` snapshot exists, or can be created;
- free disk space is at least `cydeploy_min_free_gb`;
- the installer checksum matches `cydeploy_installer_sha256` — only when
  installation is enabled.

Preflight needs the portal token. In AWX supply it as `AWX_OPS_SECRET`; for an
offline run, stage a report and set
`cydeploy_eligibility_source=file`.

---

## The 16 AWX job templates

All manually launched. **No schedules.** Every one requires `cydeploy_targets` at
launch; none may carry a default target, and none may use a `--limit` that
widens to a group of all pods.

| Template | Playbook |
|----------|----------|
| CYDEPLOY - Preflight Inactive Pod | `playbooks/cydeploy/preflight.yml` |
| CYDEPLOY - Snapshot Inactive Pod | `playbooks/cydeploy/snapshot.yml` |
| CYDEPLOY - Install and Configure | `playbooks/cydeploy/install.yml` |
| CYDEPLOY - Seed SI-M5-L1 / L2 / L3 | `playbooks/si/cydeploy/seed_si_cydeploy.yml` with `cydeploy_lab_id` |
| CYDEPLOY - Verify SI-M5-L1 / L2 / L3 | `playbooks/si/cydeploy/verify_si_cydeploy.yml` with `cydeploy_lab_id` |
| CYDEPLOY - Reset SI-M5-L1 / L2 / L3 | `playbooks/si/cydeploy/reset_si_cydeploy.yml` with `cydeploy_lab_id` |
| CYDEPLOY - Seed SC-M5-L1 | `playbooks/sc/cydeploy/seed_sc_cydeploy.yml` |
| CYDEPLOY - Verify SC-M5-L1 | `playbooks/sc/cydeploy/verify_sc_cydeploy.yml` |
| CYDEPLOY - Reset SC-M5-L1 | `playbooks/sc/cydeploy/reset_sc_cydeploy.yml` |
| CYDEPLOY - Remove and Restore Baseline | `playbooks/cydeploy/remove.yml` |

Publication is off by default: `cydeploy_publish_progress=false` keeps verifier
results in AWX job artifacts only, so a staged verify cannot move a live
student's completion percentage.

---

## Running a pod through the labs

```bash
# 1. Prove the pod is free. Read-only; run it on its own first.
-e cydeploy_targets=pod19-srv                      # CYDEPLOY - Preflight

# 2. Baseline snapshot. Everything after this is recoverable.
-e cydeploy_targets=pod19-srv                      # CYDEPLOY - Snapshot

# 3. Install (blocked until the installer and isolation finding exist).
-e cydeploy_targets=pod19-srv cydeploy_install_enabled=true \
   cydeploy_installer_path=... cydeploy_installer_sha256=... \
   cydeploy_isolation_verified=true                # CYDEPLOY - Install

# 4. Seed, verify, reset — per lab.
-e cydeploy_targets=pod19-srv cydeploy_lab_id=M5-L1
```

Phase 1 uses `cydeploy_serial=1` on two pilot pods. Phases 2 and 3 use explicit
host lists, `cydeploy_serial=2`, `any_errors_fatal: true` — the first failure
stops the wave.

---

## Rollback

In increasing order of severity:

| Situation | Action |
|-----------|--------|
| One lab needs a retake | Reset that lab: `cydeploy_lab_id=M5-LN`. Restores the seeded baseline (Spooler, the permissive rule) and leaves other labs alone. |
| A pod's CyDeploy state is wrong | Reset `ALL`, then reseed. |
| CyDeploy itself must go | **CYDEPLOY - Remove and Restore Baseline**. Uninstalls, clears the workspace and artifacts, confirms they are gone. |
| The pod must return to its pre-CyDeploy state | The same template with `cydeploy_restore_baseline=true` — rolls the VM back to `cydeploy-baseline`, starts it, waits for WinRM. |
| Manual last resort | On `pve1`: `qm rollback <vmid> cydeploy-baseline` then `qm start <vmid>`. |

A snapshot rollback discards **everything** on that pod since the snapshot. That
is safe on an inactive pod and destructive on an active one — which is why
preflight runs before the rollback, too.

---

## Troubleshooting

| Symptom | Cause and action |
|---------|------------------|
| `Mandatory variable 'cydeploy_targets' not defined` | Working as designed. Name the pods. |
| `pod is protected` / `pod is not on the approved list` | Reconcile `vars/cydeploy-pods.yml` and the inventory groups against the portal. Do not edit the list to make a run pass. |
| `assignment` / `open session` / `activity within the quiet window` | A student is using or recently used that pod. Pick another pod; do not lower `cydeploy_quiet_minutes`. |
| `eligibility data is stale` / connector not `ok` | The Guacamole collector is behind. Fix the collector; a stale feed cannot prove a pod is idle. |
| `ansible_host does not match` / hostname mismatch | Inventory and reality disagree. Stop — this is how the wrong machine gets changed. |
| `no baseline snapshot` | Run the snapshot template first, or set `cydeploy_require_snapshot=false` only on a pod you are willing to lose. |
| `installer checksum mismatch` | The staged installer is not the approved artifact. Do not proceed. |
| `cydeploy_isolation_verified is not set` | Pod isolation has not been demonstrated and recorded. Installation stays blocked. |
| `No SI/SC CyDeploy results were collected` | Every target was skipped by preflight, or the named hosts never ran the verify role. A verify that graded nothing fails loudly rather than reporting success. |
| Reset cannot reach the pod | The student's firewall change blocked WinRM. Roll back the baseline snapshot. |

---

## Stop conditions

Stop the rollout and escalate if any of these appear:

- an active student is assigned to, or recently active on, a target;
- a protected pod appears anywhere in a CyDeploy job's output;
- CyDeploy cannot be confined to a single pod, or wants to scan the shared
  domain or the management network;
- a lab turns out to need a change to shared infrastructure;
- a snapshot cannot be created, or a reset does not restore the baseline;
- the installer or its checksum cannot be verified;
- an active student reports a new access problem during a rollout window.

---

## Outstanding before anything is installed

- the CyDeploy Community Edition installer, its version and its SHA-256;
- silent install switches, service name, install directory, uninstall command;
- evidence that Community Edition can be scoped to one pod, recorded in this
  directory, before `cydeploy_isolation_verified` may be set;
- the AWX credentials the templates need (portal token, Proxmox, Windows).

Until then every install path is inert by default and the labs are documentary.

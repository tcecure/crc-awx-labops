# Auto-Advance (per-pod family progression)

When a pod completes **every lab** in its current CMMC family, the next family is
**automatically seeded for that pod only** — so students progress at their own
pace without an instructor re-seeding, and without resetting completed work.

Family order: **AC → IA → SI → SC**.

---

## How it works

```
   ┌─────────────┐     artifacts (per-pod, per-lab completed flags)
   │ Verify jobs │ ───────────────────────────────────────────────┐
   │ AC/IA/SI/SC │                                                 │
   └─────────────┘                                                 ▼
                                                       ┌───────────────────────┐
   ┌───────────────────────┐   seed markers           │  Auto-Advance job      │
   │ DC01                   │   C:\CyberLab\PodNN\     │  (advance-families.yml)│
   │ .families\<FAM>.seeded │ ───────────────────────► │  scripts/              │
   └───────────────────────┘                          │  advance_families.py   │
                                                       └───────────┬───────────┘
                                                                   │ for each pod:
                                                                   │ current family 100%?
                                                                   │ next family unseeded?
                                                                   ▼
                                                       Launch per-pod seed of the
                                                       NEXT family (pods=<N>)
```

The Auto-Advance job (AWX Job Template **"Auto-Advance Families"**) does two things:

1. **Reads completion** from the latest *successful* verify job of each family
   (templates AC=13, IA=16, SI=19, SC=22) via the AWX API. A family counts as
   complete for a pod only when **all 12 labs** report `completed=true`.
2. **Reads seed state** from per-family marker files on DC01
   (`C:\CyberLab\PodNN\.families\<FAM>.seeded`).

For each pod it finds the earliest family that is **100% complete** whose
**successor is not yet seeded**, and launches that successor's **per-pod** seed
template (AC=12, IA=15, SI=18, SC=21) with `pods=<N>`.

### Why two signals (completion + markers)?

* **Completion** is a safe, false-positive-free *trigger*: a family can only
  reach 12/12 if it was seeded first and then actually fixed by the student.
* **Markers** make advancement *idempotent*: an already-seeded family is never
  re-seeded (re-seeding would re-apply the misconfigurations and wipe the
  student's progress). The schedule can therefore run every 30 minutes safely.

---

## Guardrails

| Guardrail | Behavior |
|-----------|----------|
| Block until 100% | The current family must be fully complete before its successor is seeded. |
| Idempotent | If the next family already has its `.seeded` marker, it is skipped (no-op). |
| One step per run | At most one family is advanced per pod per run (the earliest gap). |
| No reset | Advancing seeds a **different** family; completed families are untouched. |
| `advance_dry_run=1` | Compute and log decisions without launching any seed. |
| `advance_enabled=0` | Report-only: never launch (for a safe "watch" mode). |

Markers are written by the seed playbooks and cleared by the reset playbooks, so
seed state stays accurate automatically once the mechanism is in place.

---

## Components

| Component | Location |
|-----------|----------|
| Decision + launch logic | `scripts/advance_families.py` |
| Orchestration playbook | `playbooks/advance-families.yml` |
| Marker writes | end of `playbooks/seed-cmmc-{ac,ia,si,sc}.yml` |
| Marker clears | end of `playbooks/reset-{ac,ia,si,sc}-labs.yml` |
| Marker backfill tool | `playbooks/backfill-family-markers.yml` |
| AWX Job Template | **Auto-Advance Families** (id 24) |
| AWX Credential | **CRC AWX API Token** (custom type "AWX API Token") injecting `CRC_AWX_HOST` / `CRC_AWX_TOKEN` |
| AWX Schedule | **Auto-Advance every 30m** (created disabled — see rollout) |

The job template uses two credentials: the WinRM machine credential (to read
markers on DC01) and the AWX API token credential (to read verify artifacts and
launch seeds). `CRC_AWX_HOST` points at the in-cluster ClusterIP
(`http://awx-service.awx.svc.cluster.local`, currently `http://10.43.121.132`)
so the execution pod can reach the AWX API.

---

## Rollout / going live

The mechanism is built and tested but the schedule ships **disabled** so it does
not change behavior on already-seeded pods until you opt in.

1. **Backfill markers for existing seeded pods** so auto-advance does not
   re-seed (and reset) families that are already in place. Run
   **`backfill-family-markers.yml`** for the families that are actually seeded
   today (AC and IA are bulk-seeded on all pods):

   ```
   pods=""            # all pods (blank = 1..pod_count)
   families="AC,IA"   # only mark what is truly seeded
   ```

   Leave SI/SC unmarked where they were never seeded — auto-advance will seed
   them per-pod as students finish the preceding family.

2. **(Recommended) Onboarding model:** seed **AC only** for a fresh/reset pod
   (`Seed CMMC AC Labs` with `pods=<N>`). The student then unlocks IA → SI → SC
   automatically as each family is completed.

3. **Enable the schedule** (AWX → Templates → Auto-Advance Families → Schedules →
   enable), or run the job on demand. Optionally run once with
   `advance_dry_run=1` first to review the decisions in the job output.

---

## Operations

* **Dry run:** launch *Auto-Advance Families* with extra var `advance_dry_run: "1"`.
  The job output prints `completed families`, `seeded families`, and the exact
  actions it would take.
* **Watch mode:** set `advance_enabled: "0"` to log decisions but never launch.
* **Force a single pod now:** seed the next family manually with the per-pod
  seed template (`pods=<N>`); this also writes the family marker.
* **Troubleshooting:**
  * *No actions though a family looks done* — confirm the latest **successful**
    verify job for that family shows 12/12 for the pod, and that the next
    family's `.seeded` marker is absent on DC01.
  * *A family got re-seeded* — its `.seeded` marker was missing; run the
    backfill tool.
  * *API errors in the job* — the credential's `CRC_AWX_HOST`/`CRC_AWX_TOKEN`
    or the AWX ClusterIP changed; update the **CRC AWX API Token** credential.

---

## Adding a 5th family later

1. Add its seed/verify/reset playbooks (write/clear a `<FAM>.seeded` marker like
   the others).
2. Append the family to `FAMILY_ORDER`, `VERIFY_TEMPLATES`, `SEED_TEMPLATES`, and
   `LABS` in `scripts/advance_families.py`.

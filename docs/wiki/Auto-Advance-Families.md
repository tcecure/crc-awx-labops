# Auto-Advance (per-pod family progression)

When a pod completes **every lab** in its current CMMC family, the next family is
**automatically seeded for that pod only** — so students progress at their own
pace without an instructor re-seeding, and without resetting completed work. When certificate launching is enabled, the same scheduled job issues one idempotent PDF certificate and JSON receipt after all 57 labs are complete and the student has submitted a certificate name.

Family order: **AC → IA → SI → SC → MP → PE**. Individual families and modules do not receive separate certificates.

---

## How it works

```
   ┌─────────────┐     artifacts (per-pod, per-lab completed flags)
   │ Verify jobs │ ───────────────────────────────────────────────┐
   │ AC/IA/SI/SC/MP/PE │                                                 │
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

The Auto-Advance job (AWX Job Template **"Auto-Advance Families"**) evaluates three state sources:

1. **Reads completion** from the latest *successful* verify job of each family
   (templates AC=13, IA=16, SI=19, SC=22, MP=28, PE=31) via the AWX API. A family counts as
   complete for a pod only when every lab declared for that family reports `completed=true`
   (12 for AC/IA/SI/SC, 3 for MP, and 6 for PE).
2. **Reads seed state** from per-family marker files on DC01
   (`C:\CyberLab\PodNN\.families\<FAM>.seeded`).
3. **Reads certificate state** from the student profile and final issuance marker
   (`Certificates\CertificateProfile.json` and `.certificates\FINAL.issued`).

For each pod it finds the earliest family that is **100% complete** whose
**successor is not yet seeded**, and launches that successor's **per-pod** seed
template (AC=12, IA=15, SI=18, SC=21, MP=27, PE=30) with `pods=<N>`. Independently, a pod with all six families complete, a student profile, and no `FINAL.issued` marker launches **Generate Completion Certificate**. Certificate generation revalidates all six referenced AWX verifier jobs and all 57 lab results before writing files.

### Why completion plus state markers?

* **Completion** is the grading trigger: every declared lab must be complete in the latest successful verifier job.
* **Seed markers** make advancement idempotent: an already-seeded family is never re-seeded.
* **The certificate profile and `FINAL.issued` marker** provide the student-supplied name and prevent duplicate issuance.

The schedule can therefore run every 30 minutes without resetting completed work or reissuing the final award.

---

## Guardrails

| Guardrail | Behavior |
|-----------|----------|
| Block until 100% | The current family must be fully complete before its successor is seeded. |
| Idempotent | If the next family already has its `.seeded` marker, it is skipped (no-op). |
| One step per run | At most one family is advanced per pod per run (the earliest gap). |
| No reset | Advancing seeds a **different** family; completed families are untouched. |
| `advance_dry_run=1` | Compute and log decisions without launching any seed. |
| `advance_enabled=0` | Report-only: never launch a family seed. |
| Student-named | No certificate is issued until the student runs `REQUEST-MY-CERTIFICATE.cmd` and confirms a display name. |
| Verified at issuance | The certificate job checks the AWX job status, verifier template, pod result, and every required lab again. |
| Final award only | A certificate action is created only after all 57 labs across all six families are complete. |
| Idempotent certificate | `.certificates\FINAL.issued` prevents duplicate scheduled issuance. |
| Preserved history | Family resets do not delete the issued final certificate or receipt. An instructor must explicitly reissue it. |
| Safe rollout | `certificates_enabled=0` disables certificate launches without affecting family progression. |

Seed markers are written by seed playbooks and cleared by reset playbooks. The final certificate marker is written only after both pod and instructor copies are stored successfully.

---

## Components

| Component | Location |
|-----------|----------|
| Decision + launch logic | `scripts/advance_families.py` |
| Orchestration playbook | `playbooks/advance-families.yml` |
| Marker writes | end of `playbooks/seed-cmmc-{ac,ia,si,sc,mp,pe}.yml` |
| Marker clears | end of `playbooks/reset-{ac,ia,si,sc,mp,pe}-labs.yml` |
| Marker backfill tool | `playbooks/backfill-family-markers.yml` |
| Student certificate prompt | `roles/certificates/files/request-certificate-name.ps1` |
| Certificate deployment | `playbooks/setup-certificate-system.yml` |
| Certificate generation | `scripts/generate_completion_certificate.py` |
| Certificate issuance | `playbooks/issue-completion-certificate.yml` |
| AWX Job Template | **Auto-Advance Families** (id 24) |
| Certificate Job Template | **Generate Completion Certificate** (id 36) |
| Certificate setup template | **Setup Certificate System** (id 37) |
| AWX Credential | **CRC AWX API Token** (custom type "AWX API Token") injecting `CRC_AWX_HOST` / `CRC_AWX_TOKEN` |
| AWX Schedule | **Auto-Advance every 30m** (id 7; family advancement and final-certificate launching enabled) |

The job template uses two credentials: the WinRM machine credential (to read
markers on DC01) and the AWX API token credential (to read verify artifacts and
launch seeds). `CRC_AWX_HOST` points at the in-cluster ClusterIP
(`http://awx-service.awx.svc.cluster.local`, currently `http://10.43.121.132`)
so the execution pod can reach the AWX API.

---

## Rollout / live status

Auto-Advance is enabled in AWX and runs every 30 minutes. Before activation, the
live pod state was audited and markers were reconciled without changing lab
artifacts:

* AC was confirmed seeded and marked on Pods 01–20.
* IA was confirmed seeded and marked on Pod01 only.
* A stale IA marker was removed from Pod20; its existing SI and SC markers were
  retained because those families are present.
* MP and PE remained unseeded on every pod.
* A dry run and the first enabled run both reported zero seed actions.

The certificate workflow was deployed to all 20 pods and validated on scratch Pod20:

* **Setup Certificate System** job 19008 deployed the name prompt and launcher.
* Certificate job 19023 validated PDF/JSON generation, dual storage, receipt hashing, profile identity checks, and AWX revalidation using a controlled SI test under the earlier family-certificate design.
* Jobs 19025 and 19026 validated idempotent reruns and explicit `force_reissue=true` replacement.
* The temporary profile, certificate, archive copy, marker, and test helper were removed after validation.
* **Setup Certificate System** job 20249 deployed the final-only student instructions and prompt wording.
* Certificate job 20250 confirmed that a family scope is rejected before profile or artifact processing.
* Auto-Advance dry-run jobs 20251 and 20253 reported zero certificate actions from the existing Pod20 SI-only scratch state.
* Live Auto-Advance job 20254 ran with certificate launching enabled and launched zero unintended seed or certificate jobs.

Schedule 7 is enabled with `advance_enabled: "1"` and `certificates_enabled: "1"`. A completed single family, including Pod20's scratch SI result, cannot trigger a certificate under the final-only policy.

For a new deployment, first use **`backfill-family-markers.yml`** to mark only
families proven already seeded. Run Auto-Advance once with
`advance_dry_run=1`, review the proposed actions, and then enable the schedule.

The recommended onboarding model is to seed **AC only** for a fresh/reset pod
(`Seed CMMC AC Labs` with `pods=<N>`). The student then unlocks
IA → SI → SC → MP → PE automatically as each family is completed.

---

## Operations

* **Dry run:** launch *Auto-Advance Families* with extra var `advance_dry_run: "1"`.
  The job output prints `completed families`, `seeded families`, and the exact
  actions it would take.
* **Watch mode:** set `advance_enabled: "0"` to log decisions but never launch.
* **Certificate control:** `certificates_enabled: "1"` is live. Set it to `"0"` to pause final-certificate launches without changing seed/advance behavior.
* **Force a single pod now:** seed the next family manually with the per-pod
  seed template (`pods=<N>`); this also writes the family marker.
* **Student certificate name:** run `C:\CyberLab\PodNN\REQUEST-MY-CERTIFICATE.cmd`, enter the full name, and confirm it. Issuance occurs after the next scheduled cycle once all 57 labs are complete.
* **Certificate locations:** students receive PDF/JSON files in `C:\CyberLab\PodNN\Certificates`; the protected instructor archive is `C:\ProgramData\DRCC\InstructorCertificates\PodNN`.
* **Correct a name:** update the student profile, then manually launch **Generate Completion Certificate** with the same pod, `certificate_scope=FINAL`, all six verifier job IDs, and `force_reissue=true`.
* **Troubleshooting:**
  * *No actions though a family looks done* — confirm the latest **successful**
    verify job for that family shows every declared lab complete for the pod, and that the next
    family's `.seeded` marker is absent on DC01.
  * *A family got re-seeded* — its `.seeded` marker was missing; run the
    backfill tool.
  * *API errors in the job* — the credential's `CRC_AWX_HOST`/`CRC_AWX_TOKEN`
    or the AWX ClusterIP changed; update the **CRC AWX API Token** credential.

---

## Adding another family later

1. Add its seed/verify/reset playbooks (write/clear a `<FAM>.seeded` marker like
   the others).
2. Append the family to `FAMILY_ORDER`, `VERIFY_TEMPLATES`, `SEED_TEMPLATES`, and
   `LABS` in `scripts/advance_families.py`. Variable family sizes are supported.

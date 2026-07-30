# Auto-Advance (per-pod family progression)

When a pod completes **every lab** in its current CMMC family, the next family is
**automatically seeded for that pod only** — so students progress at their own
pace without an instructor re-seeding, and without resetting completed work. When certificate launching is enabled, the same scheduled job also issues an idempotent PDF certificate and JSON receipt after each completed family when the student has submitted a certificate name.

Family order: **AC → IA → SI → SC → MP → PE**. A final certificate is issued after all six families.

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
3. **Reads certificate state** from the student profile and issuance markers
   (`Certificates\CertificateProfile.json` and `.certificates\<FAM>.issued`).

For each pod it finds the earliest family that is **100% complete** whose
**successor is not yet seeded**, and launches that successor's **per-pod** seed
template (AC=12, IA=15, SI=18, SC=21, MP=27, PE=30) with `pods=<N>`. Independently, each completed family without an issuance marker launches **Generate Completion Certificate** after the student submits a name. Certificate generation revalidates the referenced AWX verifier job before writing files.

### Why completion plus state markers?

* **Completion** is the grading trigger: every declared lab must be complete in the latest successful verifier job.
* **Seed markers** make advancement idempotent: an already-seeded family is never re-seeded.
* **Certificate profiles and issuance markers** provide the student-supplied name and prevent duplicate certificates.

The schedule can therefore run every 30 minutes without resetting completed work or reissuing an existing award.

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
| Idempotent certificates | `.certificates\<FAM>.issued` and `FINAL.issued` prevent duplicate scheduled issuance. |
| Preserved history | Family resets do not delete issued certificates or receipts. An instructor must explicitly reissue them. |
| Safe rollout | `certificates_enabled=0` disables certificate launches without affecting family progression. |

Seed markers are written by seed playbooks and cleared by reset playbooks. Certificate markers are written only after both pod and instructor copies are stored successfully.

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
| AWX Schedule | **Auto-Advance every 30m** (id 7; family advancement enabled, certificate launches disabled pending Pod20 review) |

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
* Certificate job 19023 generated and archived a valid SI PDF/JSON receipt.
* Job 19025 confirmed an ordinary rerun is an idempotent no-op.
* Job 19026 confirmed `force_reissue=true` creates a replacement certificate.
* Auto-Advance proposed SI before issuance and suppressed it after the `.issued` marker existed.
* The temporary profile, SI certificate, archive copy, marker, and test helper were removed after validation.

Certificate launching remains disabled on schedule 7 with `certificates_enabled: "0"`. Pod20 currently has a scratch SI verifier result of 12/12; enabling certificates before that state is reset or explicitly approved could issue a real-looking SI certificate when `student17` submits a name. Family auto-advance remains enabled and unaffected.

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
* **Certificate rollout:** set `certificates_enabled: "1"` only after scratch completion state has been cleared or approved. This flag does not change seed/advance behavior.
* **Force a single pod now:** seed the next family manually with the per-pod
  seed template (`pods=<N>`); this also writes the family marker.
* **Student certificate name:** run `C:\CyberLab\PodNN\REQUEST-MY-CERTIFICATE.cmd`, enter the full name, and confirm it. Issuance occurs after the next scheduled cycle for every already-completed family.
* **Certificate locations:** students receive PDF/JSON files in `C:\CyberLab\PodNN\Certificates`; the protected instructor archive is `C:\ProgramData\DRCC\InstructorCertificates\PodNN`.
* **Correct a name:** update the student profile, then manually launch **Generate Completion Certificate** with the same pod/scope/job mapping and `force_reissue=true`.
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

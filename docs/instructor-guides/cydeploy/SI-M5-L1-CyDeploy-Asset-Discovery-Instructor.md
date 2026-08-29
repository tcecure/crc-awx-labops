# SI-M5-L1 — CyDeploy Asset Discovery (Instructor Guide)

> **STATUS: STAGED.** Do not seed against an active student pod until
> `docs/cydeploy/CYDEPLOY-GO-LIVE.md` is complete.

---

## Seeded condition

Seeded by `playbooks/si/cydeploy/seed_si_cydeploy.yml` (role scripts in
`roles/seed_si_cydeploy/files/`) into
`C:\CyberLab\PodNN\SI-Artifacts\CyDeploy\` on the shared DC:

| File | Purpose |
|------|---------|
| `PNN_Expected_Asset_Inventory.csv` | Documented inventory: DC, GW, APP01, WS01 |
| `PNN_CyDeploy_Discovery_Worksheet.docx` | Student worksheet |
| `PNN_Discovery_Scenario.txt` | Tasking memo |
| `StudentResponses\SI-M5-L1.json` | Response template (pre-populated with pod scope) |
| `_LAB_READY_SI-M5-L1.txt` | Seed marker |

Family marker: `C:\CyberLab\PodNN\.families\SI-CYDEPLOY.seeded` — separate from
`SI.seeded`, so the core SI labs are unaffected.

### The discovery gap

The lab depends on discovery reporting an asset that is **not** in
`PNN_Expected_Asset_Inventory.csv`, referred to as `PNN-UNKNOWN01`.

**This asset does not exist yet, and must not be added to a production pod
during the active class.** How it is created is a go-live decision, and it must be
made only after the CyDeploy executable is available and its discovery behaviour
is known. Options to evaluate at go-live:

1. A lightweight per-pod VM or container on the pod LAN named `PNN-UNKNOWN01`.
2. A second IP/alias on an existing pod host, if CyDeploy reports it as a
   distinct asset.
3. A dedicated non-student test pod first, in all cases.

Until then, SI-M5-L1 is verifiable as a documentation exercise only: the
student's finding must name `PNN-UNKNOWN01`, which is stated in neither the
inventory nor the scenario memo, so the answer cannot be produced without
discovery output.

---

## Expected finding

The documented inventory lists four assets. Discovery is expected to return those
four plus `PNN-UNKNOWN01`, which has no owner and no inventory row.

## Correct answer

| Response field | Expected |
|----------------|----------|
| `discovery_scope` | Contains `PodNN`; must not contain `10.50.`, `192.168.1.`, `acs-p01.local`, or a `/16` |
| `undocumented_asset_identified` | `yes` / `true` |
| `finding` | Names `PNN-UNKNOWN01` |
| `evidence` | ≥ 25 characters, references discovery output vs. the inventory |
| `analyst` | Non-empty |
| `completed` | `yes` / `true` |

---

## Verification logic

`roles/verify_si_cydeploy/tasks/main.yml`, key `M5-L1`, run from
`playbooks/si/cydeploy/verify_si_cydeploy.yml` on the shared DC.

It requires the seed marker and all three seeded artifacts to still exist, then
parses `StudentResponses\SI-M5-L1.json` and applies the table above. Invalid JSON
fails with `is not valid JSON`. Every failure returns a specific reason string,
which the tracker displays.

Tracker publication is gated by `cydeploy_publish_progress` (default `false`), so
running the verifier cannot change live student completion percentages.

---

## Reset behavior

`playbooks/si/cydeploy/reset_si_cydeploy.yml` removes only
`SI-Artifacts\CyDeploy` (including `StudentResponses`) and the
`SI-CYDEPLOY.seeded` marker. Core SI artifacts, `SI.seeded`, and all other
families are untouched.

Re-seeding is idempotent: with the family marker present the seed exits early.
With `force_reseed=true` the reference documents are re-deployed but existing
`StudentResponses\*.json` files are **kept** (logged as `[KEEP]`), so student work
is never overwritten.

Per-pod selection: `pods="7"`, `pods="7,9,12"`, `pod_id=7`; default is pods
1..`pod_count`.

---

## Known limitations

- The undocumented asset does not exist in the environment yet (see above). Until
  it does, a student cannot actually observe the finding.
- CyDeploy Community Edition capability is unverified: installer name, switches,
  scope syntax, service, ports and output format are all unknown until the
  executable is supplied. Nothing in this lab depends on a CyDeploy API.
- The worksheet `.docx` is checked for existence only; its contents are not
  parsed. The JSON response is the graded evidence.
- Discovery scope is validated from what the student *records*, not from network
  telemetry. Enforcing scope technically requires the go-live scope review.

---

## CyDeploy-specific troubleshooting

| Symptom | Action |
|---------|--------|
| CyDeploy not installed | Installation is feature-flagged off (`cydeploy_install_enabled: false` in `roles/cydeploy_community/defaults/main.yml`). Provide the installer path and enable the flag only after go-live testing. |
| Seed reports `Template not found` | The `templates/si/cydeploy/` copy step did not complete; re-run the seed playbook. |
| Discovery returns hosts outside the pod | Stop the lab for that student and re-scope. Cross-pod discovery is a go-live blocker, not a lab quirk. |
| Verifier reports files missing after a student "cleaned up" | Re-seed that pod with `force_reseed=true`; student responses are preserved. |

---

## Expected screenshots (to add after the executable is available)

1. CyDeploy scope configuration showing a pod-only range.
2. Discovery result list including `PNN-UNKNOWN01`.
3. Completed worksheet sections 2–4.
4. Tracker showing SI-M5-L1 complete for the pod.

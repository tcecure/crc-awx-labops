# SI-M5-L2 — CyDeploy Configuration & Security Findings (Instructor Guide)

> **STATUS: STAGED.** Do not seed against an active student pod until
> `docs/cydeploy/CYDEPLOY-GO-LIVE.md` is complete.

---

## Seeded condition

Seeded into `C:\CyberLab\PodNN\SI-Artifacts\CyDeploy\` on the shared DC:

| File | Purpose |
|------|---------|
| `PNN_Observed_Conditions.txt` | Lists observations `OBS-01`..`OBS-05` |
| `PNN_Approved_Software_List.csv` | Approved software |
| `PNN_Exception_Register.csv` | One current exception: `EXC-PNN-014`, LegacyReportViewer 3.2, expires 2027-03-11 |
| `PNN_Configuration_Baseline.pdf` | ACS baseline |
| `PNN_CyDeploy_Findings_Worksheet.docx` | Student worksheet |
| `StudentResponses\SI-M5-L2.json` | Response template with the five observation rows |
| `_LAB_READY_SI-M5-L2.txt` | Seed marker |

The five observations are stated in the tasking memo as expected CyDeploy output.
The underlying software/services (`LegacyReportViewer`, `FileZilla Server`,
`TelemetryAgent`) are **not** installed on any pod by this seed, and must not be
installed on an active pod. Making the tool output match the memo is a go-live
task (see Known limitations).

---

## Expected finding

The student must reach classifications by reading the baseline, the approved
software list, and the exception register — not by pattern-matching on product
names.

## Correct answer

| Observation | Item | Correct classification | Why |
|---|---|---|---|
| OBS-01 | LegacyReportViewer 3.2 | **Approved Exception** | Prohibited by the baseline, but covered by a current, unexpired exception (`EXC-PNN-014`) |
| OBS-02 | FileZilla Server 0.9.60 | **Finding** | Unapproved, unencrypted file transfer service listening; no exception |
| OBS-03 | Remote Registry service | **Finding** | Baseline requires it disabled |
| OBS-04 | Windows Defender Antivirus | **Expected** | Baseline requires it enabled with current definitions |
| OBS-05 | TelemetryAgent 1.4 | **Needs Investigation** | Publisher unverified and no owner recorded — cannot be judged as approved or prohibited |

Every row also requires a `justification` of ≥ 15 characters. `analyst` must be
non-empty and `completed` must be true.

Common student errors: calling OBS-01 a Finding (ignores the exception register),
calling OBS-05 a Finding (guessing instead of requesting information), and
classifying without justification.

---

## Verification logic

`roles/verify_si_cydeploy/tasks/main.yml`, key `M5-L2`. It requires the seed
marker and the seeded reference documents, parses
`StudentResponses\SI-M5-L2.json`, and checks each of the five rows against the
table above plus a justification length floor. Reasons are returned per
observation ID (e.g. `OBS-01 is classified incorrectly`) — the correct answer is
never disclosed to the student.

Tracker publication is gated by `cydeploy_publish_progress` (default `false`).

---

## Reset behavior

Handled by `playbooks/si/cydeploy/reset_si_cydeploy.yml` together with the other
SI CyDeploy labs: removes `SI-Artifacts\CyDeploy` and the `SI-CYDEPLOY.seeded`
marker only. Re-seed is idempotent and preserves existing student response files.

---

## Known limitations

- **Observations are documentary.** The five conditions are described in the
  seeded memo; the corresponding software and services are not deployed. Until a
  go-live decision is made (deploy the conditions on a per-pod app host, or
  accept the lab as a document-analysis exercise), CyDeploy output will not match
  the memo.
- CyDeploy Community Edition's configuration-review capability is unverified. If
  it cannot enumerate installed software or service state, this lab must be
  re-scoped at go-live.
- The `.docx` worksheet and the `.pdf` baseline are checked for existence only;
  contents are not parsed.
- Exception-register realism depends on the seeded dates; `EXC-PNN-014` expires
  2027-03-11. Refresh the template if the class date passes that.

---

## CyDeploy-specific troubleshooting

| Symptom | Action |
|---------|--------|
| Students report CyDeploy shows none of OBS-01..OBS-05 | Expected until the conditions are deployed. Run the lab as document analysis, or complete the go-live condition work first. |
| `PNN_Configuration_Baseline.pdf` will not open in the pod | Confirm the seed copied the file; the PDF is generated from `docs/cydeploy/worksheet-sources/si/SI-M5-L2_Configuration_Baseline.md`. |
| A student edited the response template structure | Re-seed with `force_reseed=true` after moving their file aside; the seed keeps existing responses, so the broken file must be removed deliberately. |

---

## Expected screenshots (to add after the executable is available)

1. CyDeploy configuration/software inventory output for a pod.
2. The exception register alongside the OBS-01 entry.
3. Completed worksheet classification table.
4. Tracker showing SI-M5-L2 complete.

# SI-M5-L3 — CyDeploy Change Impact Comparison (Instructor Guide)

> **STATUS: STAGED.** Do not seed against an active student pod until
> `docs/cydeploy/CYDEPLOY-GO-LIVE.md` is complete.

---

## Seeded condition

Seeded into `C:\CyberLab\PodNN\SI-Artifacts\CyDeploy\` on the shared DC:

| File | Purpose |
|------|---------|
| `PNN_Change_Scenario.txt` | Tasking memo, change ID `CHG-PNN-2026-0431` |
| `PNN_Change_Request.docx` | Approved change request |
| `PNN_Baseline_Worksheet.docx` | Pre-change collection worksheet |
| `PNN_Change_Validation_Report.docx` | Post-change comparison and determination |
| `StudentResponses\SI-M5-L3.json` | Response template, pre-populated `change_id` |
| `_LAB_READY_SI-M5-L3.txt` | Seed marker |

The change target is the service `PNN-LabTelemetry` on `PNN-APP01`.

**The service is not created by this seed.** Creating a per-pod dummy service (and
confirming a pod application host exists) is a go-live task; it must not be added
to an active student pod during the current class.

---

## Expected finding

The intended change (service stopped and disabled) is the only difference between
the two collections. There is **no** hidden side effect seeded — the correct
determination is PASS with `unintended_changes_observed` recorded as none.

The teaching point is sequence discipline: a student who applies the change before
collecting a baseline cannot honestly claim `baseline_recorded: yes`.

## Correct answer

| Response field | Expected |
|----------------|----------|
| `change_id` | `CHG-PNN-2026-0431` |
| `target_item` | References `LabTelemetry` |
| `baseline_recorded` | `yes` / `true` |
| `baseline_state` | Indicates running / started / enabled / automatic |
| `post_change_state` | Indicates stopped **and** disabled |
| `unintended_changes_observed` | None observed (`no` / `none`) |
| `determination` | `PASS` |
| `evidence` | ≥ 25 characters describing the before/after comparison |
| `analyst`, `completed` | Non-empty / true |

---

## Verification logic

`roles/verify_si_cydeploy/tasks/main.yml`, key `M5-L3`. Requires the seed marker
and the seeded documents, parses `StudentResponses\SI-M5-L3.json`, and applies the
table above. `post_change_state` must match both stopped and disabled; a state
showing only "stopped" fails, because a stopped-but-automatic service restarts.

Tracker publication is gated by `cydeploy_publish_progress` (default `false`).

---

## Reset behavior

`playbooks/si/cydeploy/reset_si_cydeploy.yml` removes `SI-Artifacts\CyDeploy` and
the `SI-CYDEPLOY.seeded` marker only.

Note: the reset does **not** restore the `PNN-LabTelemetry` service to running,
because this branch does not create the service. When the service is added at
go-live, the reset script must be extended to set it back to
running/automatic — that is an explicit go-live task, tracked in
`docs/cydeploy/CYDEPLOY-GO-LIVE.md`.

---

## Known limitations

- `PNN-LabTelemetry` and `PNN-APP01` do not exist yet; the lab is documentary
  until they do.
- Reset does not yet re-arm the service state (see above).
- Whether CyDeploy Community Edition supports a comparison/diff view, or whether
  students must compare two exports manually, is unknown until the executable is
  supplied. The lab is written to work either way.
- Timestamps, uptime, and log counts will legitimately differ between the two
  collections; students are told to treat these as observations, not
  configuration changes. Expect questions.

---

## CyDeploy-specific troubleshooting

| Symptom | Action |
|---------|--------|
| Student applied the change before the baseline | Have them record it honestly; re-arm the service (once it exists) and re-run rather than accepting a fabricated baseline. |
| Two collections differ in dozens of places | Confirm both used identical scope; review whether the tool includes volatile data by default. |
| Service will not stay disabled | Check for a dependent service or scheduled task restarting it — and whether the go-live service definition set a recovery action. |
| Verifier reports `response does not reference the approved change request` | The student overwrote `change_id`. Correct value is `CHG-PNN-2026-0431`. |

---

## Expected screenshots (to add after the executable is available)

1. Baseline collection showing `PNN-LabTelemetry` running/automatic.
2. Post-change collection showing it stopped/disabled.
3. The comparison view or side-by-side export.
4. Tracker showing SI-M5-L3 complete.

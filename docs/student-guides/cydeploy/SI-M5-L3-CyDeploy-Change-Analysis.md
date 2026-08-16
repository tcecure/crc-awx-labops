# SI-M5-L3 — CyDeploy Change Impact Comparison

> **STATUS: STAGED — NOT YET AVAILABLE TO ACTIVE STUDENTS.**
> This lab becomes available when your instructor announces that CyDeploy
> Community Edition has been installed in the lab environment.

---

## Mission

ACS Security Operations has an approved change request: a service that serves no
business purpose must be stopped and disabled.

Stopping a service takes ten seconds. Proving that the change did what was asked
— **and nothing else** — is the actual job.

Your job is to capture the state of your pod before the change, apply the
approved change, capture the state afterwards, compare the two, and record a
defensible PASS or FAIL determination.

---

## Learning Objectives

By the end of this lab you will be able to:

1. Explain why a change without a recorded baseline cannot be validated.
2. Capture a before-and-after snapshot with a consistent scope.
3. Distinguish an intended change from an unintended side effect.
4. Record a change validation determination that another analyst could audit.

---

## Prerequisites

- You have completed SI-M5-L1 and SI-M5-L2.
- Your instructor has confirmed CyDeploy Community Edition is available.
- You know your pod number and your student credentials.

---

## Systems Used

| System | Where | What you use it for |
|--------|-------|---------------------|
| `PODXX-DC` (via Guacamole) | Your Guacamole connection list | Reading the change request and recording your response |
| Your pod application host | Named in the change request | Applying the approved change |
| CyDeploy Community Edition | As installed by your instructor | Before-and-after collection |
| Your pod artifact folder | `C:\CyberLab\PodXX\SI-Artifacts\CyDeploy\` | Change request, worksheets, and your response file |

### Scope rules

Collect and change **your own pod only**. Both collections must use the **same
scope**, or the comparison is meaningless.

---

## Instructions

1. Connect to Guacamole and open your **PODXX-DC** connection.
2. Open `C:\CyberLab\PodXX\SI-Artifacts\CyDeploy\`.
3. Read `PXX_Change_Scenario.txt` and `PXX_Change_Request.docx`. Note the change
   ID and the exact item you are authorized to change.
4. **Before changing anything**, run a CyDeploy discovery/configuration
   collection for your pod. This is your baseline.
5. Complete `PXX_Baseline_Worksheet.docx`:
   - how you collected the baseline and where the output is stored
   - the state of the target item before the change
   - any surrounding state you will want to compare afterwards
   - the pre-change attestation
6. Apply the approved change exactly as written in the change request — no more,
   no less.
7. Run a second CyDeploy collection using the **same scope** as your baseline.
8. Complete `PXX_Change_Validation_Report.docx`:
   - what you changed and how
   - a before/after comparison table
   - every difference the change request did **not** ask for (if there are none,
     write "none observed" — do not leave it blank)
   - your PASS or FAIL determination and the basis for it
9. Open `StudentResponses\SI-M5-L3.json` in Notepad and fill in:
   - `analyst` — your student name
   - `target_item` — the item named in the change request
   - `baseline_recorded` — `"yes"` only if you collected the baseline first
   - `baseline_state` — the state before the change
   - `post_change_state` — the state after the change
   - `unintended_changes_observed` — `"none observed"`, or describe what you found
   - `determination` — `PASS` or `FAIL`
   - `evidence` — what your two collections showed
   - `completed` — `true`
10. Save the JSON file. Keep both worksheets saved in the same folder.

> A determination of PASS means: the intended condition changed, and the
> comparison shows no unintended change. If either half is not true, your
> determination must reflect that.

---

## Evidence Required

| Evidence | File |
|----------|------|
| Completed baseline worksheet | `PXX_Baseline_Worksheet.docx` |
| Completed validation report | `PXX_Change_Validation_Report.docx` |
| Completed response file | `StudentResponses\SI-M5-L3.json` |

---

## Verify My Lab

Verification is automatic. You do not run anything yourself, and you do not need
access to AWX.

1. Save both worksheets and your `SI-M5-L3.json` response file.
2. The scheduled verifier reads your response file and evidence, and decides
   PASS or FAIL.
3. Check your result on the training tracker:
   **https://training.status.tcecure.com/pod/XX**, or the "Check Your Progress"
   banner in Guacamole.
4. If the lab shows incomplete, the reason names the missing or inconsistent
   field. Fix it, save, and wait for the next verification run.

---

## Troubleshooting

**I applied the change before running the baseline collection.**
Tell your instructor. Do not claim `baseline_recorded: "yes"` — a change you
cannot compare against a baseline is not validated, and inventing a baseline
after the fact is falsifying evidence.

**The two collections differ in many places.**
Check that both used the same scope, and that time-based details (timestamps,
uptime, log counts) are not being mistaken for configuration changes. Note them
as observations rather than configuration differences.

**The service will not stop or will not stay disabled.**
Record exactly what happened, and tell your instructor. A change that cannot be
applied is a FAIL with evidence — not a lab you should skip.

**CyDeploy output is hard to compare by hand.**
Compare the specific items you listed in your baseline worksheet first, then scan
the rest. That is why section 3 of the baseline worksheet exists.

**The tracker says my post-change state is wrong.**
Your recorded state must show the service both stopped and disabled, as the
change request asked.

**I cannot edit the JSON file.**
Open it with Notepad and keep the JSON valid.

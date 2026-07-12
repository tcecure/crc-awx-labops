# PE-M2-L2 — Temporary Badge Workflow

## Learning Objectives

- Execute the full temporary badge lifecycle.

## Scenario

A power-systems technician needs escorted access for a scheduled UPS inspection.

## Required Artifacts

- `PE-M2-L2_TemporaryBadgeInventory.csv`
- `PE-M2-L2_VisitorLog.csv`
- `_LAB_READY_PE-M2-L2.txt`

## Student Tasks

- Issue TEMP-PNN-014 to Casey Morgan.
- Assign EMP-102 as escort.
- Record valid sign-in and sign-out times.
- Record the badge as returned.

## Validation Logic

- The expected badge and escort are recorded.
- Sign-in and sign-out are valid and ordered.
- BadgeReturned is Yes/True.

## Screenshots

Capture the following assessment evidence when screenshots are required by the instructor:

- Temporary badge inventory before issue.
- Completed visitor log showing issue, escort, sign-out, and return.

Screenshots support the assessment record; the automated verifier grades the structured artifacts listed above.

## Expected Outcome

The visitor and badge are fully accountable from issuance through return.

## AWX Template Used

- Seed: **Seed - PE Family (AWX template 30)**
- Verify: **Verify - PE Family (AWX template 31)**

## Reset Behavior

**Reset - PE Family (AWX template 32)** removes the entire per-pod `PE-Artifacts` directory and the `PE.seeded` family marker. It does not touch another family or pod.

## Automation Requirements

- Seed accepts `pods`, `pod_id`, or blank for all pods.
- Seed writes `_LAB_READY_PE-M2-L2.txt` only after the lab artifacts are deployed.
- Verify returns `PE-M2-L2: {completed, reason}` in every pod's AWX artifacts.
- The tracker lists this lab under Physical Protection.
- Auto-advance counts this lab as one of 6 required PE labs.

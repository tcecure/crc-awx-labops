# PE-M3-L1 — Access Log Review

## Learning Objectives

- Reconcile multiple physical-access records and identify discrepancies.

## Scenario

Badge controller, visitor sheet, and alarm records disagree about after-hours server-room activity.

## Required Artifacts

- `PE-M3-L1_BadgeControllerExport.csv`
- `PE-M3-L1_VisitorSignInSheet.csv`
- `PE-M3-L1_AlarmLog.csv`
- `PE-M3-L1_DiscrepancyReview.csv`
- `_LAB_READY_PE-M3-L1.txt`

## Student Tasks

- Identify BC-5003 as use of a returned visitor badge.
- Identify ALM-9007 as a forced-door alarm without matching badge access.
- Document containment and investigation actions.

## Validation Logic

- D-01 cites BC-5003 and the post-return badge use.
- D-02 cites ALM-9007 and the unmatched forced door.
- Both include appropriate response actions.

## Screenshots

Capture the following assessment evidence when screenshots are required by the instructor:

- Visitor sign-out beside the later badge event.
- Forced-door alarm with no matching access event.
- Completed discrepancy review.

Screenshots support the assessment record; the automated verifier grades the structured artifacts listed above.

## Expected Outcome

Both physical-access discrepancies are identified for investigation.

## AWX Template Used

- Seed: **Seed - PE Family (AWX template 28)**
- Verify: **Verify - PE Family (AWX template 29)**

## Reset Behavior

**Reset - PE Family (AWX template 30)** removes the entire per-pod `PE-Artifacts` directory and the `PE.seeded` family marker. It does not touch another family or pod.

## Automation Requirements

- Seed accepts `pods`, `pod_id`, or blank for all pods.
- Seed writes `_LAB_READY_PE-M3-L1.txt` only after the lab artifacts are deployed.
- Verify returns `PE-M3-L1: {completed, reason}` in every pod's AWX artifacts.
- The tracker lists this lab under Physical Protection.
- Auto-advance counts this lab as one of 6 required PE labs.

# PE-M1-L2 — Server Room Access

## Learning Objectives

- Determine whether physical access events were authorized at the time they occurred.

## Scenario

Badge and server-room logs must be compared with the active roster and approved access list.

## Required Artifacts

- `PE-M1-L2_BadgeLog.csv`
- `PE-M1-L2_ServerRoomLog.csv`
- `PE-M1-L2_EmployeeRoster.csv`
- `PE-M1-L2_ServerRoomAccessList.csv`
- `PE-M1-L2_AccessDecision.csv`
- `_LAB_READY_PE-M1-L2.txt`

## Student Tasks

- Review each E-1001 through E-1004 event.
- Mark active approved employees as authorized.
- Mark the terminated employee and unapproved contractor as unauthorized and explain why.

## Validation Logic

- E-1001 and E-1003 are authorized.
- E-1002 and E-1004 are unauthorized.
- Every event includes a reason.

## Screenshots

Capture the following assessment evidence when screenshots are required by the instructor:

- Badge log alongside the approved access list.
- The completed access decision worksheet.

Screenshots support the assessment record; the automated verifier grades the structured artifacts listed above.

## Expected Outcome

The student correctly evaluates physical access using contemporaneous authorization records.

## AWX Template Used

- Seed: **Seed - PE Family (AWX template 28)**
- Verify: **Verify - PE Family (AWX template 29)**

## Reset Behavior

**Reset - PE Family (AWX template 30)** removes the entire per-pod `PE-Artifacts` directory and the `PE.seeded` family marker. It does not touch another family or pod.

## Automation Requirements

- Seed accepts `pods`, `pod_id`, or blank for all pods.
- Seed writes `_LAB_READY_PE-M1-L2.txt` only after the lab artifacts are deployed.
- Verify returns `PE-M1-L2: {completed, reason}` in every pod's AWX artifacts.
- The tracker lists this lab under Physical Protection.
- Auto-advance counts this lab as one of 6 required PE labs.

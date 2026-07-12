# PE-M1-L1 — Authorized Access Review

## Learning Objectives

- Identify people who retain physical access without current authorization.

## Scenario

A quarterly access review reveals a terminated employee and contractor among active badge and server-room access records.

## Required Artifacts

- `PE-M1-L1_EmployeeRoster.csv`
- `PE-M1-L1_BadgeRoster.csv`
- `PE-M1-L1_ServerRoomAccessList.csv`
- `PE-M1-L1_AccessReview.csv`
- `_LAB_READY_PE-M1-L1.txt`

## Student Tasks

- Reconcile employment, badge, and server-room authorization records.
- Identify Taylor Reed and Morgan Blake as unauthorized.
- Document disablement, removal, or escort-only corrective actions.

## Validation Logic

- Both unauthorized subjects are identified.
- The terminated badge is disabled/revoked.
- The contractor access is removed or restricted to escorted access.

## Screenshots

Capture the following assessment evidence when screenshots are required by the instructor:

- Roster and badge records showing the terminated employee.
- Server-room list showing the contractor with no approval.
- Completed access review.

Screenshots support the assessment record; the automated verifier grades the structured artifacts listed above.

## Expected Outcome

The access review removes stale and unsupported physical access.

## AWX Template Used

- Seed: **Seed - PE Family (AWX template 30)**
- Verify: **Verify - PE Family (AWX template 31)**

## Reset Behavior

**Reset - PE Family (AWX template 32)** removes the entire per-pod `PE-Artifacts` directory and the `PE.seeded` family marker. It does not touch another family or pod.

## Automation Requirements

- Seed accepts `pods`, `pod_id`, or blank for all pods.
- Seed writes `_LAB_READY_PE-M1-L1.txt` only after the lab artifacts are deployed.
- Verify returns `PE-M1-L1: {completed, reason}` in every pod's AWX artifacts.
- The tracker lists this lab under Physical Protection.
- Auto-advance counts this lab as one of 6 required PE labs.

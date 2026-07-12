# PE-M3-L2 — Lost Badge Response

## Learning Objectives

- Contain a lost badge, issue a replacement, and document post-loss use.

## Scenario

Dana Brooks reports a lost badge at 10:00; the badge is used at the server room at 11:12.

## Required Artifacts

- `PE-M3-L2_LostBadgeReport.txt`
- `PE-M3-L2_BadgeInventory.csv`
- `PE-M3-L2_AccessEventsAfterLoss.csv`
- `PE-M3-L2_IncidentReport.csv`
- `_LAB_READY_PE-M3-L2.txt`

## Student Tasks

- Change B-PNN-115 to Disabled or Revoked.
- Assign and activate B-PNN-215 for EMP-115.
- Document EVT-6112, containment, replacement, reporter, and incident summary.

## Validation Logic

- The lost badge is disabled/revoked.
- The replacement badge is active and assigned to EMP-115.
- The incident report cites EVT-6112 and complete containment evidence.

## Screenshots

Capture the following assessment evidence when screenshots are required by the instructor:

- Lost badge report and post-loss event.
- Updated badge inventory.
- Completed incident report.

Screenshots support the assessment record; the automated verifier grades the structured artifacts listed above.

## Expected Outcome

The compromised credential is contained and replacement/incident records are complete.

## AWX Template Used

- Seed: **Seed - PE Family (AWX template 30)**
- Verify: **Verify - PE Family (AWX template 31)**

## Reset Behavior

**Reset - PE Family (AWX template 32)** removes the entire per-pod `PE-Artifacts` directory and the `PE.seeded` family marker. It does not touch another family or pod.

## Automation Requirements

- Seed accepts `pods`, `pod_id`, or blank for all pods.
- Seed writes `_LAB_READY_PE-M3-L2.txt` only after the lab artifacts are deployed.
- Verify returns `PE-M3-L2: {completed, reason}` in every pod's AWX artifacts.
- The tracker lists this lab under Physical Protection.
- Auto-advance counts this lab as one of 6 required PE labs.

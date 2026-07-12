# PE-M2-L1 — Visitor Escort

## Learning Objectives

- Detect and document a visitor escort violation.

## Scenario

A repair visitor has an approved ticket and temporary badge, but camera observations show restricted-area access without the assigned escort.

## Required Artifacts

- `PE-M2-L1_VisitorLog.csv`
- `PE-M2-L1_RepairTicket.txt`
- `PE-M2-L1_CameraObservation.txt`
- `PE-M2-L1_EscortPolicy.txt`
- `PE-M2-L1_EscortReview.csv`
- `_LAB_READY_PE-M2-L1.txt`

## Student Tasks

- Compare the visitor log, ticket, observation, and policy.
- Identify V-3002 as unescorted.
- Document the evidence and corrective action.

## Validation Logic

- V-3002 is classified as unescorted.
- The response cites evidence and an incident/escort corrective action.

## Screenshots

Capture the following assessment evidence when screenshots are required by the instructor:

- Visitor record with missing escort.
- Camera observation showing solo restricted-area access.
- Completed escort review.

Screenshots support the assessment record; the automated verifier grades the structured artifacts listed above.

## Expected Outcome

The visitor escort failure is identified and escalated.

## AWX Template Used

- Seed: **Seed - PE Family (AWX template 28)**
- Verify: **Verify - PE Family (AWX template 29)**

## Reset Behavior

**Reset - PE Family (AWX template 30)** removes the entire per-pod `PE-Artifacts` directory and the `PE.seeded` family marker. It does not touch another family or pod.

## Automation Requirements

- Seed accepts `pods`, `pod_id`, or blank for all pods.
- Seed writes `_LAB_READY_PE-M2-L1.txt` only after the lab artifacts are deployed.
- Verify returns `PE-M2-L1: {completed, reason}` in every pod's AWX artifacts.
- The tracker lists this lab under Physical Protection.
- Auto-advance counts this lab as one of 6 required PE labs.

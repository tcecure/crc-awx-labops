# MP-M1-L1 — Identify FCI Media

## Learning Objectives

- Recognize media that contains FCI and distinguish it from ordinary business media.

## Scenario

The contracts and HR teams submit two removable-media images for classification. One contains federal contract records; the other contains general employee information.

## Required Artifacts

- `PNN-FCI-USB.vhdx`
- `PNN-Employee-Handbook.vhdx`
- `MediaInventory.xlsx`
- `MediaClassificationWorksheet.docx`
- `MediaClassificationResponses.csv`
- `MediaDisposalPolicy.pdf`
- `_LAB_READY_MP-M1-L1.txt`

## Student Tasks

- Inspect both VHDX files, including hidden and ordinary folders.
- Complete the DOCX worksheet with classification and handling notes.
- Enter FCI / Non-FCI classifications and evidence in MediaClassificationResponses.csv.

## Validation Logic

- The readiness marker exists.
- Both VHDX files and all required source documents exist.
- PNN-FCI-USB.vhdx is recorded as FCI with evidence.
- PNN-Employee-Handbook.vhdx is recorded as Non-FCI with evidence.

## Screenshots

Capture the following assessment evidence when screenshots are required by the instructor:

- File Explorer showing both VHDX files in MP-Artifacts.
- The FCI media folders (Contracts, Purchase Orders, Drawings, and Invoices).
- The completed classification worksheet and response CSV.

Screenshots support the assessment record; the automated verifier grades the structured artifacts listed above.

## Expected Outcome

The student demonstrates that media classification follows the information stored on the media.

## AWX Template Used

- Seed: **Seed - MP Family (AWX template 25)**
- Verify: **Verify - MP Family (AWX template 26)**

## Reset Behavior

**Reset - MP Family (AWX template 27)** removes the entire per-pod `MP-Artifacts` directory and the `MP.seeded` family marker. It does not touch another family or pod.

## Automation Requirements

- Seed accepts `pods`, `pod_id`, or blank for all pods.
- Seed writes `_LAB_READY_MP-M1-L1.txt` only after the lab artifacts are deployed.
- Verify returns `MP-M1-L1: {completed, reason}` in every pod's AWX artifacts.
- The tracker lists this lab under Media Protection.
- Auto-advance counts this lab as one of 3 required MP labs.

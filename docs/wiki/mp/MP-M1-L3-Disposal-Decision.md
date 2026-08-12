# MP-M1-L3 — Disposal Decision

## Learning Objectives

- Select the correct disposition using asset, serial, custody, and destruction evidence.

## Scenario

An end-of-life laptop that stored FCI has failed diagnostics and has been transferred to an approved destruction vendor, but its disposal worksheet is incomplete.

## Required Artifacts

- `LaptopAssetRecord.csv`
- `ChainOfCustody.csv`
- `VendorDestructionCertificate.txt`
- `MP-M1-L3_DispositionWorksheet.csv`
- `_LAB_READY_MP-M1-L3.txt`

## Student Tasks

- Reconcile the laptop asset ID, drive serial, chain of custody, and vendor certificate.
- Choose Reuse, Destroy, or Return to inventory.
- Complete the disposition rationale and supporting identifiers.

## Validation Logic

- The readiness marker and supporting records exist.
- The decision is Destroy.
- Asset ID, drive serial, and vendor certificate ID match.
- The rationale explains the failed/end-of-life FCI media decision.

## Screenshots

Capture the following assessment evidence when screenshots are required by the instructor:

- The matching asset and chain-of-custody records.
- The vendor certificate showing the drive serial.
- The completed disposition worksheet.

Screenshots support the assessment record; the automated verifier grades the structured artifacts listed above.

## Expected Outcome

The student chooses destruction and demonstrates complete disposal traceability.

## AWX Template Used

- Seed: **Seed - MP Family (AWX template 27)**
- Verify: **Verify - MP Family (AWX template 28)**

## Reset Behavior

**Reset - MP Family (AWX template 29)** removes the entire per-pod `MP-Artifacts` directory and the `MP.seeded` family marker. It does not touch another family or pod.

## Automation Requirements

- Seed accepts `pods`, `pod_id`, or blank for all pods.
- Seed writes `_LAB_READY_MP-M1-L3.txt` only after the lab artifacts are deployed.
- Verify returns `MP-M1-L3: {completed, reason}` in every pod's AWX artifacts.
- The tracker lists this lab under Media Protection.
- Auto-advance counts this lab as one of 3 required MP labs.

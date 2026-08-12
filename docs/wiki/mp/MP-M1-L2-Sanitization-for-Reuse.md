# MP-M1-L2 — Sanitization for Reuse

## Learning Objectives

- Demonstrate why deleting files is not sanitization and execute the approved reuse process.

## Scenario

The FCI virtual USB must be returned to inventory. It contains visible files, deleted data, temporary content, and a hidden folder.

## Required Artifacts

- `PNN-FCI-USB.vhdx`
- `MediaDisposalPolicy.pdf`
- `MediaSanitizationLog.csv`
- `MediaSanitizationCertificate.csv`
- `MP-M1-L2_SeedMetadata.json`
- `_LAB_READY_MP-M1-L2.txt`

## Student Tasks

- Remove the existing partition and create a new NTFS partition.
- Perform a full format and label the volume PNN-SANITIZED.
- Validate that prior content is unavailable.
- Complete the sanitization log and certificate with Clear or Purge, PASS, and Reuse.

## Validation Logic

- The readiness marker exists.
- The current volume serial differs from the seeded serial.
- The sanitized label matches PNN-SANITIZED.
- No student-data files remain on the volume.
- The sanitization log and certificate contain matching, complete records.

## Screenshots

Capture the following assessment evidence when screenshots are required by the instructor:

- Disk Management or DiskPart showing the recreated partition.
- The empty PNN-SANITIZED volume.
- The completed sanitization log and certificate.

Screenshots support the assessment record; the automated verifier grades the structured artifacts listed above.

## Expected Outcome

The media is verifiably recreated and documented for approved reuse rather than merely having files deleted.

## AWX Template Used

- Seed: **Seed - MP Family (AWX template 27)**
- Verify: **Verify - MP Family (AWX template 28)**

## Reset Behavior

**Reset - MP Family (AWX template 29)** removes the entire per-pod `MP-Artifacts` directory and the `MP.seeded` family marker. It does not touch another family or pod.

## Automation Requirements

- Seed accepts `pods`, `pod_id`, or blank for all pods.
- Seed writes `_LAB_READY_MP-M1-L2.txt` only after the lab artifacts are deployed.
- Verify returns `MP-M1-L2: {completed, reason}` in every pod's AWX artifacts.
- The tracker lists this lab under Media Protection.
- Auto-advance counts this lab as one of 3 required MP labs.

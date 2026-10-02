% Change Request CHG-2026-0431
% ACS Cyber Lab — SI-M5-L3
% Advanced Cyber Solutions (ACS) — Security Operations

## Request summary

| Field | Entry |
|-------|-------|
| Change ID | CHG-2026-0431 (pod-specific suffix on your seeded copy) |
| Requested by | ACS Security Operations |
| Change type | Standard — service removal |
| Target system | Your pod application host (`APP01`) |
| Requested change | Stop and disable the `LabTelemetry` service |
| Approved window | Any time during the lab |
| Rollback | Re-enable the service and return it to its previous start type |

## Justification

The `LabTelemetry` service is not required for any documented business function. Services with no business purpose expand the attack surface and must be removed under the ACS configuration baseline (BL-3).

## Required validation

This change is not complete when the service stops. It is complete when the analyst can prove:

1. The state of the environment before the change was recorded.
2. The intended condition changed.
3. Nothing unintended changed.
4. A defensible PASS or FAIL determination was recorded with evidence.

A change that cannot be evidenced is treated as a failed change.

## Approvals

| Role | Name | Date |
|------|------|------|
| Requested by | ACS Security Operations | |
| Approved by | ACS Change Advisory Board | |
| Implemented by (analyst) | | |
| Validated by (analyst) | | |

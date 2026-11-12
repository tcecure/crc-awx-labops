% Change Request CHG-2026-0431
% ACS Cyber Lab — SI-M5-L3
% Advanced Cyber Solutions (ACS) — Security Operations

## Request summary

| Field | Entry |
|-------|-------|
| Change ID | CHG-2026-0431 (pod-specific suffix on your seeded copy) |
| Requested by | ACS Security Operations |
| Change type | Standard — service removal |
| Target system | Your pod server (`PODXX-SRV`) only |
| Requested change | Stop and disable the Print Spooler service (service name `Spooler`) |
| Approved window | Any time during the lab |
| Rollback | Re-enable the service and return it to its previous start type |

## Justification

The Print Spooler service is not required for any documented business function on this host, and no printer is attached to it. Services with no business purpose expand the attack surface and must be removed under the ACS configuration baseline (BL-3).

The service is running and set to start automatically today, so both the before state and the after state are observable on your own server.

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

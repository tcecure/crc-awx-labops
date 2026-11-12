% Change Request CHG-2026-0552
% ACS Cyber Lab — SC-M5-L1
% Advanced Cyber Solutions (ACS) — Network Security

## Request summary

| Field | Entry |
|-------|-------|
| Change ID | CHG-2026-0552 (pod-specific suffix on your seeded copy) |
| Requested by | ACS Network Security |
| Change type | Standard — firewall rule tightening |
| Target system | The host firewall of your pod server (`PODXX-SRV`) only |
| Requested change | Replace the permissive `PXX-CYDEPLOY-ALLOW-ANY-INBOUND` rule with rules that permit only required inbound communication, each scoped to specific remote addresses and ports |
| Rollback | Staff reset of this lab restores the pre-change rule set |

## Finding that prompted this request

An internal review found that the host firewall on your pod server accepts inbound traffic on any port from any source address. Under CMMC Level 1 system and communications protection expectations, the host must permit only the communication it actually needs.

## Constraint the analyst must respect

Tightening this rule without understanding dependencies will break your own remote desktop session, policy and evidence delivery from the domain controller, and the automated grading channel. The analyst is required to base the change on discovered system and dependency information, not on assumption.

## Required validation

1. Dependency analysis recorded before the change.
2. Permissive rule removed.
3. Only required paths permitted, each with a specific remote address and port — the firewall blocks everything else by default.
4. Required connectivity re-tested after the change and shown to still work.
5. PASS or FAIL determination recorded with evidence.

## Approvals

| Role | Name | Date |
|------|------|------|
| Requested by | ACS Network Security | |
| Approved by | ACS Change Advisory Board | |
| Implemented by (analyst) | | |
| Validated by (analyst) | | |

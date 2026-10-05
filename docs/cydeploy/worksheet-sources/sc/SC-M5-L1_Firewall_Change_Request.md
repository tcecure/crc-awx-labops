% Change Request CHG-2026-0552
% ACS Cyber Lab — SC-M5-L1
% Advanced Cyber Solutions (ACS) — Network Security

## Request summary

| Field | Entry |
|-------|-------|
| Change ID | CHG-2026-0552 (pod-specific suffix on your seeded copy) |
| Requested by | ACS Network Security |
| Change type | Standard — firewall rule tightening |
| Target system | Your pod gateway (`GW`, pfSense) |
| Requested change | Replace the permissive `ALLOW-LAN-TO-ANY` rule with rules that permit only required communication, ending in an explicit default deny |
| Rollback | Restore the previous rule set from the gateway configuration history |

## Finding that prompted this request

An internal review found that the pod LAN can reach any destination on any port through the gateway. Under CMMC Level 1 system and communications protection expectations, the gateway must permit only the communication the environment actually needs.

## Constraint the analyst must respect

Tightening this rule without understanding dependencies will break authentication, name resolution, and policy delivery for the pod. The analyst is required to base the change on discovered system and dependency information, not on assumption.

## Required validation

1. Dependency analysis recorded before the change.
2. Permissive rule removed.
3. Only required paths permitted, with an explicit default deny.
4. Required connectivity re-tested after the change and shown to still work.
5. PASS or FAIL determination recorded with evidence.

## Approvals

| Role | Name | Date |
|------|------|------|
| Requested by | ACS Network Security | |
| Approved by | ACS Change Advisory Board | |
| Implemented by (analyst) | | |
| Validated by (analyst) | | |

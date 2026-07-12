# Physical Protection (PE) — Overview

## CMMC Level 1 Controls

PE.L1-3.10.1 through PE.L1-3.10.5 — Limit, escort, monitor, and log physical access; manage physical access devices.

## Architecture

- Shared domain and shared DC inventory; each pod remains isolated by `PodNN` and `PNN-` naming.
- Per-pod artifacts: `C:\CyberLab\PodNN\PE-Artifacts\`.
- Readiness markers: `_LAB_READY_PE-<module>-<lab>.txt`.
- Family marker: `C:\CyberLab\PodNN\.families\PE.seeded`.
- Workflow: Seed → Verify → Training Tracker → Reset.

## Labs

- [PE-M1-L1 — Authorized Access Review](PE-M1-L1-Authorized-Access-Review.md)
- [PE-M1-L2 — Server Room Access](PE-M1-L2-Server-Room-Access.md)
- [PE-M2-L1 — Visitor Escort](PE-M2-L1-Visitor-Escort.md)
- [PE-M2-L2 — Temporary Badge Workflow](PE-M2-L2-Temporary-Badge-Workflow.md)
- [PE-M3-L1 — Access Log Review](PE-M3-L1-Access-Log-Review.md)
- [PE-M3-L2 — Lost Badge Response](PE-M3-L2-Lost-Badge-Response.md)

## Automation

| Operation | Template |
|---|---|
| Seed | Seed - PE Family (AWX template 28) |
| Verify | Verify - PE Family (AWX template 29) |
| Reset | Reset - PE Family (AWX template 30) |

Verification publishes all 20 pods in AWX `Job.artifacts` and writes `PE_Verification_Report.json`.

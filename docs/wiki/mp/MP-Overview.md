# Media Protection (MP) — Overview

## CMMC Level 1 Controls

MP.L1-3.8.3 — Sanitize or destroy information system media containing Federal Contract Information before disposal or release for reuse.

## Architecture

- Shared domain and shared DC inventory; each pod remains isolated by `PodNN` and `PNN-` naming.
- Per-pod artifacts: `C:\CyberLab\PodNN\MP-Artifacts\`.
- Readiness markers: `_LAB_READY_MP-<module>-<lab>.txt`.
- Family marker: `C:\CyberLab\PodNN\.families\MP.seeded`.
- Workflow: Seed → Verify → Training Tracker → Reset.

## Labs

- [MP-M1-L1 — Identify FCI Media](MP-M1-L1-Identify-FCI-Media.md)
- [MP-M1-L2 — Sanitization for Reuse](MP-M1-L2-Sanitization-for-Reuse.md)
- [MP-M1-L3 — Disposal Decision](MP-M1-L3-Disposal-Decision.md)

## Automation

| Operation | Template |
|---|---|
| Seed | Seed - MP Family (AWX template 25) |
| Verify | Verify - MP Family (AWX template 26) |
| Reset | Reset - MP Family (AWX template 27) |

Verification publishes all 20 pods in AWX `Job.artifacts` and writes `MP_Verification_Report.json`.

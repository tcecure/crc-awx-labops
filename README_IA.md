# CMMC Level 1 — Identification & Authentication (IA) Lab Automation

## Overview

12 IA labs with full **Seed → Verify → Reset** automation, matching the AC lab architecture.
All labs run on the shared domain controller (`acs-p01.local`) with **OU-based pod isolation**
supporting 20 concurrent student pods.

> **Shared DC mode**: All pods use DC01-P01 (10.50.1.10). Pod isolation is achieved via
> `OU=PodXX,OU=Students` OUs and `PXX-` prefixed user accounts.
> All artifacts scoped to `C:\CyberLab\PodXX\` on the DC.

## Architecture

```
┌─────────────────────────────────────────────────┐
│  DC01-P01 (10.50.1.10)  —  acs-p01.local        │
│                                                   │
│  OU=Students                                      │
│  ├── OU=Pod01   (P01-frontdesk, P01-tom.davis …) │
│  ├── OU=Pod02   (P02-frontdesk, P02-tom.davis …) │
│  │     └── OU=Users / Groups / Resources          │
│  └── OU=Pod20   (P20-frontdesk, P20-tom.davis …) │
│                                                   │
│  C:\CyberLab\                                     │
│  ├── Pod01\IA-Artifacts\  (per-pod evidence)      │
│  ├── Pod02\IA-Artifacts\                          │
│  └── Pod20\IA-Artifacts\                          │
└─────────────────────────────────────────────────┘
```

## Lab Map

| Lab ID | Module | Title | Seed FAIL State | Student PASS State |
|--------|--------|-------|-----------------|-------------------|
| M1-L1 | User Identification | Shared Reception Account | `PXX-frontdesk` shared account enabled; individual accounts absent | Disable shared account; create `PXX-k.omalley` + `PXX-temp.agency01`; evidence file |
| M1-L2 | User Identification | Zombie Account | `PXX-tom.davis` enabled in Sales OU with group membership | Disable; move to Terminated OU; strip groups |
| M1-L3 | User Identification | Generic Accounts | `PXX-admin`, `PXX-user1`, `PXX-test` enabled; no inventory CSV | Disable/remove; create `Authorized_User_Inventory.csv` |
| M2-L1 | Non-Person Entity ID | Scheduled Task as Human | "`PodXX ACS Nightly Backup`" runs as `PXX-s.jenkins`; `PXX-svc_backup` absent | Create `PXX-svc_backup`; change task principal |
| M2-L2 | Non-Person Entity ID | Rogue Device Artifact | Device list present; rogue MAC in hint file; no config record | Add rogue MAC as UNAUTHORIZED; create `Device_Config_Record.csv` |
| M2-L3 | Non-Person Entity ID | Service Account Matrix | `PXX-svc_backup/web/print` with empty descriptions; no matrix | Populate descriptions; create `Service_Account_Matrix.csv` |
| M3-L1 | User Auth Management | Password Policy Report | No report or evidence files | Export `PasswordPolicy_Report.html`; create evidence |
| M3-L2 | User Auth Management | Weak Password Policy | MinLen=6, Complexity=Off, Lockout=0 | Set MinLen=12, Complexity=On, Lockout=10 |
| M3-L3 | User Auth Management | Must Change Password | `PXX-d.chen` enabled; must-change flag not set | Reset password; set must-change flag; create incident evidence |
| M4-L1 | Defaults & Process Auth | Default Credentials | `Hardening_Standard.txt` missing default-password clause | Add clause; write remediation summary |
| M4-L2 | Defaults & Process Auth | SNMP Public String | Scan report has SNMP "public" finding; no config record | Create `Device_Config_Record.csv` with SNMP finding |
| M4-L3 | Defaults & Process Auth | Script Contains password123 | `db_connect.py` has hardcoded `password123` | Replace with VAULT_REF; create `Vault_Entries.txt` |

## Directory Structure

```
crc-awx-labops/
  playbooks/
    seed-cmmc-ia.yml         # Master seed (all 12 labs × 20 pods)
    verify-cmmc-ia.yml       # Master verify (C/I report per pod)
    reset-ia-labs.yml         # Master reset (clean IA artifacts)
    ia/                       # (legacy individual playbooks — superseded)
  roles/
    seed_ia_dc/files/
      seed-ia-baseline.ps1    # Per-pod OUs + evidence directories
      apply-ia-lab.ps1        # Individual lab misconfigurations
      reset-ia-labs.ps1       # Remove all IA artifacts per pod
    verify_ia_dc/tasks/
      main.yml                # 12 verification checks per pod
  templates/ia/               # Reference templates (content embedded in PS1)
  group_vars/all.yml          # Shared vars (domain, pod_count, etc.)
```

## AWX Job Templates

| Template Name | Playbook | Inventory | Extra Vars |
|---------------|----------|-----------|------------|
| Seed CMMC IA Labs | `playbooks/seed-cmmc-ia.yml` | prod | `seed_user_password: Welcome!2026` |
| Verify CMMC IA Labs | `playbooks/verify-cmmc-ia.yml` | prod | — |
| Reset IA Labs (AD-Level) | `playbooks/reset-ia-labs.yml` | prod | — |

All templates target `crc_shared_dcs` inventory group and loop over pods 1–20.

## Per-Pod Evidence Paths

| Path | Purpose |
|------|---------|
| `C:\CyberLab\PodXX\` | Root evidence folder (M1-L1.txt, M3-L1.txt, etc.) |
| `C:\CyberLab\PodXX\IA-Artifacts\` | IA-specific artifacts (CSVs, reports) |
| `C:\CyberLab\PodXX\IA-Artifacts\Vault\` | Vault entries (M4-L3) |
| `C:\CyberLab\PodXX\LabArtifacts\` | Lab support files |
| `C:\CyberLab\PodXX\LabArtifacts\Scripts\` | Script files (M4-L3) |
| `C:\CyberLab\PodXX\LabArtifacts\Scans\` | Scan reports (M4-L2) |

## Known Limitations

- **M3-L2 (Weak Password Policy)** modifies the domain Default Domain Policy, which
  is domain-wide and affects all pods. If one student fixes it, all pods see the corrected
  policy. This is an inherent limitation of the shared DC model for domain-level settings.

- **ALL seed mode** runs labs in this order: M1-L1→L3, M2-L2, M2-L3, M2-L1,
  M3-L1→L3, M4-L1→L3. M2-L3 runs before M2-L1 so the final state has
  `PXX-svc_backup` absent (correct for M2-L1). Students should complete labs in
  module order.

## Migration from Legacy Architecture

The previous IA architecture used:
- Per-pod DC hostnames (`dc01-p01` through `dc01-p10`) in `crc_dcs` inventory group
- Global user names (`FrontDesk`, `tom.davis`, etc.) in `OU=ACS`
- Global evidence paths (`C:\CyberLab\IA-Artifacts\`)

The new architecture uses:
- Shared DC (`crc_shared_dcs[0]`) with OU-based isolation
- Pod-prefixed users (`PXX-frontdesk`, `PXX-tom.davis`) in `OU=PodXX,OU=Students`
- Per-pod evidence paths (`C:\CyberLab\PodXX\IA-Artifacts\`)
- 20 pods (expanded from 10)

Legacy playbooks in `playbooks/ia/` are retained for reference but superseded by
the master playbooks at the top level.

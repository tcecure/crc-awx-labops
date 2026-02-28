# CMMC Level 1 — Identification & Authentication (IA) Seed Playbooks

## Overview

12 seed playbooks that set each student pod to a known **FAIL state** for CMMC Level 1 IA labs. Students remediate each misconfiguration to achieve a PASS.

## Lab Map

| Lab ID | Module | Title | Target | Seed FAIL State | Student PASS State |
|--------|--------|-------|--------|-----------------|-------------------|
| IA-M1-L1 | M1: User Identification | Shared Reception Account | DC | `FrontDesk` shared account enabled; `k.omalley` and `temp.agency01` absent | Disable shared account; create individual users; evidence file created |
| IA-M1-L2 | M1: User Identification | Zombie Account | DC | `tom.davis` enabled in Sales OU with group membership | Disable account; move to Terminated_Users OU; strip groups |
| IA-M1-L3 | M1: User Identification | Generic Accounts | DC | `Admin`, `User1`, `Test` accounts enabled; no inventory CSV | Disable/remove generic accounts; create Authorized_User_Inventory.csv |
| IA-M2-L1 | M2: Non-Person Entity ID | Scheduled Task as Human | DC | "ACS Nightly Backup" runs as `s.jenkins`; `svc_backup` absent | Create `svc_backup`; change task principal to service account |
| IA-M2-L2 | M2: Non-Person Entity ID | Rogue Device Artifact | WS | Authorized_Device_List.csv present; rogue MAC in hint file; no config record | Add rogue MAC as UNAUTHORIZED in device list; create Device_Config_Record.csv |
| IA-M2-L3 | M2: Non-Person Entity ID | Service Account Matrix | DC | `svc_backup`, `svc_web`, `svc_print` exist with empty descriptions; no matrix | Populate AD descriptions; create Service_Account_Matrix.csv |
| IA-M3-L1 | M3: User Auth Management | Password Policy Report | DC | Baseline password policy; no report or evidence files | Export PasswordPolicy_Report.html; create M3-L1.txt evidence |
| IA-M3-L2 | M3: User Auth Management | Weak Password Policy | DC | MinLen=6, Complexity=Off, Lockout=0 | Set MinLen=12, Complexity=On, Lockout=10 |
| IA-M3-L3 | M3: User Auth Management | Must Change Password | DC | `d.chen` enabled; must-change flag not set | Reset password; set "must change at next logon"; create incident evidence |
| IA-M4-L1 | M4: Defaults & Process Auth | Default Credentials | WS | Hardening_Standard.txt missing default-password clause | Add clause about changing default passwords; write remediation summary |
| IA-M4-L2 | M4: Defaults & Process Auth | SNMP Public String | WS | Scan report contains "SNMP community string is public"; no config record | Create finding; update Device_Config_Record.csv; update hardening standard |
| IA-M4-L3 | M4: Defaults & Process Auth | Script Contains password123 | WS | `db_connect.py` has hardcoded `password123`; no vault artifacts | Replace with VAULT_REF; create Vault_Entries.txt; write remediation summary |

## Directory Structure

```
crc-awx-labops/
  playbooks/
    ia/
      seed/
        seed_ia_m1_l1.yml    # Shared Reception Account
        seed_ia_m1_l2.yml    # Zombie Account
        seed_ia_m1_l3.yml    # Generic Accounts
        seed_ia_m2_l1.yml    # Scheduled Task as Human
        seed_ia_m2_l2.yml    # Rogue Device Artifact
        seed_ia_m2_l3.yml    # Service Account Matrix
        seed_ia_m3_l1.yml    # Password Policy Report
        seed_ia_m3_l2.yml    # Weak Password Policy
        seed_ia_m3_l3.yml    # Must Change Password
        seed_ia_m4_l1.yml    # Default Credentials
        seed_ia_m4_l2.yml    # SNMP Public String
        seed_ia_m4_l3.yml    # Script Contains password123
      common/
        ensure_ad_ous.yml    # Ensure standard OU structure
        ensure_ad_groups.yml # Ensure security groups
        ensure_artifacts_dirs.yml  # Ensure evidence/artifact dirs
        drop_lab_artifacts.yml     # Drop _LAB_READY marker
  templates/
    ia/
      Authorized_Device_List.csv.j2
      Hardening_Standard.txt.j2
      scan_report_snmp_public.txt.j2
      db_connect_with_password123.txt.j2
  group_vars/
    all.yml                  # Global variables (evidence paths, etc.)
```

## AWX Job Template Setup

| Template Name | Playbook | Inventory | Extra Vars |
|---------------|----------|-----------|------------|
| Seed Labs: CMMC L1 IA - M1-L1 | `playbooks/ia/seed/seed_ia_m1_l1.yml` | prod | `seed_user_password: Welcome!2026` |
| Seed Labs: CMMC L1 IA - M1-L2 | `playbooks/ia/seed/seed_ia_m1_l2.yml` | prod | `seed_user_password: Welcome!2026` |
| ... (same pattern for all 12) | | | |

Or create a single wrapper template that calls all 12 in sequence.

## Tags

All playbooks support these tags for selective execution:

- `ia` — all IA labs
- `seed` — all seed tasks
- `m1`, `m2`, `m3`, `m4` — by module
- `ous`, `groups`, `artifacts` — common setup tasks

## Limiting to Specific Pods

```bash
ansible-playbook playbooks/ia/seed/seed_ia_m1_l1.yml --limit dc01-p01
ansible-playbook playbooks/ia/seed/seed_ia_m2_l2.yml --limit ws01-p03
```

## Evidence Directories

All IA labs use these standard paths:

| Path | Purpose |
|------|---------|
| `C:\Evidence\` | Root evidence folder |
| `C:\Evidence\IA-Artifacts\` | IA-specific artifacts |
| `C:\Evidence\IA-Artifacts\Vault\` | Vault entries (M4-L3) |
| `C:\LabArtifacts\` | Lab support files |
| `C:\LabArtifacts\Scripts\` | Script files (M4-L3) |
| `C:\LabArtifacts\Scans\` | Scan reports (M4-L2) |

## Expected Verification Conditions (for future verify playbooks)

| Lab | Key Verification Checks |
|-----|------------------------|
| M1-L1 | `FrontDesk` disabled or removed; `k.omalley` exists; `temp.agency01` exists; `M1-L1.txt` exists |
| M1-L2 | `tom.davis` disabled; in Terminated_Users OU; stripped from SG-ACS-Sales |
| M1-L3 | `Admin`, `User1`, `Test` disabled/removed; `Authorized_User_Inventory.csv` exists and non-empty |
| M2-L1 | `svc_backup` exists; "ACS Nightly Backup" principal is `svc_backup` |
| M2-L2 | `Device_Config_Record.csv` exists; rogue MAC listed as UNAUTHORIZED |
| M2-L3 | `svc_backup`, `svc_web`, `svc_print` descriptions non-empty; `Service_Account_Matrix.csv` exists |
| M3-L1 | `PasswordPolicy_Report.html` exists; `M3-L1.txt` exists |
| M3-L2 | MinLen >= 12; Complexity = Enabled; Lockout threshold = 10 |
| M3-L3 | `d.chen` password reset; must-change flag set; incident evidence file exists |
| M4-L1 | `Hardening_Standard.txt` contains default-password clause; `M4-L1.txt` exists |
| M4-L2 | `Device_Config_Record.csv` exists with SNMP finding; hardening standard updated |
| M4-L3 | `db_connect.py` contains `VAULT_REF` (not `password123`); `Vault_Entries.txt` exists |

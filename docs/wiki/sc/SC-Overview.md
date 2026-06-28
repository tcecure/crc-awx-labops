# System & Communications Protection (SC) — Overview

## CMMC Level 1 SC Control

**SC.L1-3.13.1** — Monitor, control, and protect communications at the external and internal boundaries of organizational systems.

## Lab Environment

SC labs use **pfSense** — an open-source firewall/router platform running on FreeBSD. Each pod has a dedicated `PodXX-GW` appliance that serves as the primary teaching tool.

### Infrastructure

| Component | Details |
|-----------|---------|
| Platform | pfSense CE 2.7.2 |
| VM Template | TPL-PFSENSE-GW (VMID 112) |
| Instances | 20 linked clones (VMID 300-319) |
| Resources per VM | 2 vCPU, 2GB RAM, 32GB disk |
| WAN Interface | vmbr0 (DHCP) |
| LAN Interface | podXXnet (10.51.X.1/24) |
| Web UI | http://10.51.X.1 |
| SSH | admin@10.51.X.1 |

### Multi-Purpose Design

PodXX-GW VMs are permanent pod infrastructure, reused across families:

| Family | Use |
|--------|-----|
| **SC** | Primary lab target — firewall rules, VLANs, logging |
| **AU** | Firewall syslog as audit trail source |
| **CM** | Config baseline comparison, change detection |
| **AC** | Network ACLs (future expansion) |
| **IA** | RADIUS/LDAP auth (future expansion) |
| **Linux Hardening** | SSH hardening, service lockdown |

## Module Structure

| Module | Focus | Labs |
|--------|-------|------|
| 1: Foundations | Trust boundaries, deny-by-default, monitor/control/protect | M1-L1, M1-L2, M1-L3 |
| 2: Boundaries | Organizational boundary, DMZ, VLAN segmentation | M2-L1, M2-L2, M2-L3 |
| 3: Firewall Rules | Rule audit, ordering, least privilege | M3-L1, M3-L2, M3-L3 |
| 4: Monitoring | Log investigation, compliance verification, capstone | M4-L1, M4-L2, M4-L3 |

## Automation

| AWX Template | Purpose |
|---|---|
| Seed CMMC SC Labs | Configures pfSense + deploys DC artifacts |
| Verify CMMC SC Labs | Checks firewall state + DC markers |
| Reset SC Labs | Restores pfSense baseline + cleans DC artifacts |

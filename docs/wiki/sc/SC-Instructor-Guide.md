# SC Instructor Guide

## Before Class

### 1. Start PodXX-GW VMs

VMs must be running before students can access them. Start all 20 or only needed pods:

```bash
# From pve1 or Proxmox API
for vmid in $(seq 300 319); do qm start $vmid; done
```

### 2. Seed Labs

Run the seed playbook from AWX (Template: "Seed CMMC SC Labs") or manually:

```bash
ansible-playbook playbooks/seed-cmmc-sc.yml -i inventories/prod.ini
```

To seed a specific lab only:
```bash
ansible-playbook playbooks/seed-cmmc-sc.yml -e lab_id=M1-L2
```

### 3. Verify Seeding

```bash
ansible-playbook playbooks/verify-cmmc-sc.yml -i inventories/prod.ini
```

## During Class

### Student Access

Students connect via Guacamole (`https://crc.guac.01.tcecure.com`):
- **PODXX-DC** — the only student connection; lab artifacts, evidence, and the
  pfSense web UI (browse to `http://10.51.XX.1` from that desktop)

There is no `PODXX-GW` connection: Guacamole speaks RDP/VNC/SSH, not HTTP, so a
firewall web UI cannot be a connection tile.

pfSense credentials: `admin` / `pfsense`

### Monitoring Student Progress

Check which pods have completed specific labs:
```bash
ansible-playbook playbooks/verify-cmmc-sc.yml -e lab_id=M1-L2
```

### Common Student Issues

| Issue | Solution |
|-------|----------|
| Can't reach pfSense | Verify VM is running (`qm status XXX`), check correct URL (`http://10.51.XX.1`) |
| "Apply Changes" not clicked | Remind students changes aren't active until applied |
| Accidentally deleted anti-lockout | Reset the pod: `ansible-playbook playbooks/reset-sc-labs.yml -e pod_id=XX` |
| Rules in wrong order | This is intentional for M3-L2 — students must figure out the ordering |
| Student deleted the LAN interface or all rules and locked themselves out | Restore pfSense's own pre-save backup — see `docs/pod-firewall-access-runbook.md` |

### Lab-Specific Notes

**M1-L2 (Deny By Default):** Students often forget to create specific allow rules after deleting Allow Any. They'll lose connectivity. Guide them through creating DNS and web rules.

**M2-L2 (DMZ):** This is the most complex lab. The gateway VMs have only two NICs (vtnet0 WAN, vtnet1 LAN), so **Interfaces > Assignments** shows no **+ Add** button until a VLAN exists — the most common student report on this lab. Students create VLAN 50 on vtnet1 first, assign it (it appears as OPT1), then give it `10.52.XX.1/24`. An address inside `10.51.XX.0/24` is rejected as an overlap with the LAN.

**M2-L3 (VLANs):** VLANs on pfSense require the parent interface (vtnet1/LAN). Students create VLANs under Interfaces > VLANs, then assign them under Interfaces > Assignments (same no-**+ Add**-until-a-VLAN-exists behavior). VLAN interface addresses are `10.61-10.64.XX.1/24` (HR/Finance/Engineering/Guest); the seeded task aliases and the segmentation plan on the DC use the same values.

**M4-L3 (Capstone):** Allow 60 full minutes. Students must apply all previous skills. This is the assessment lab.

## After Class

### Reset Labs

```bash
ansible-playbook playbooks/reset-sc-labs.yml -i inventories/prod.ini
```

### Stop VMs (Optional)

To save resources when not in use:
```bash
for vmid in $(seq 300 319); do qm stop $vmid; done
```

### Review Student Evidence

Student work is saved to `C:\CyberLab\PodXX\SC-Artifacts\` on DC01. Check for:
- Screenshots of firewall rules
- Completed worksheets
- Compliance checklists

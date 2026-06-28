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
- **PODXX-DC** — for lab artifacts and saving evidence
- **PODXX-GW** — for pfSense web UI (primary SC tool)

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

### Lab-Specific Notes

**M1-L2 (Deny By Default):** Students often forget to create specific allow rules after deleting Allow Any. They'll lose connectivity. Guide them through creating DNS and web rules.

**M2-L2 (DMZ):** This is the most complex lab. Students need to understand interface assignments. Walk through creating OPT1 and renaming it to DMZ.

**M2-L3 (VLANs):** VLANs on pfSense require the parent interface (vtnet1/LAN). Students create VLANs under Interfaces > VLANs, then assign them under Interfaces > Assignments.

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

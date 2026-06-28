# SC Lab Deployment Guide

## Prerequisites

- Proxmox VE (pve1) with SSH access
- pfSense golden template (VMID 112, `TPL-PFSENSE-GW`)
- AWX with inventory access to PodXX-GW hosts
- DC01/DC02 accessible via WinRM

## VM Infrastructure

### Golden Template (One-Time Setup)

The golden template `TPL-PFSENSE-GW` (VMID 112) was created from:
- pfSense CE 2.7.2 ISO
- 2 vCPU, 2GB RAM, 32GB disk (local-lvm)
- NIC0: vmbr0 (WAN, DHCP)
- NIC1: pod01net (LAN, 10.51.0.1/24 placeholder)
- SSH enabled, HTTP web UI (port 80), no DHCP server on LAN

### Cloning (Automated)

20 linked clones were created from the template:

```bash
for i in $(seq 1 20); do
  padded=$(printf "%02d" $i)
  vmid=$((299 + i))
  qm clone 112 $vmid --name "Pod${padded}-GW" --full 0
  qm set $vmid --net1 "virtio,bridge=pod${padded}net"
done
```

### Per-Pod Configuration

Each VM's LAN IP is set via SSH to the pfSense PHP shell:

```bash
# From pve1, add temp management IP on pod bridge
ip addr add 10.51.0.100/24 dev pod${padded}net
# SSH to pfSense default LAN IP
sshpass -p 'pfsense' ssh admin@10.51.0.1
# Run PHP config change
php -r "
require_once('config.inc');
\$config = parse_config(true);
\$config['interfaces']['lan']['ipaddr'] = '10.51.X.1';
\$config['system']['hostname'] = 'PodXX-GW';
\$config['system']['domain'] = 'acs-p01.local';
write_config('Configured for PodXX');
"
```

### Pod-to-VM Mapping

| Pod | VMID | Hostname | LAN IP | Bridge |
|-----|------|----------|--------|--------|
| 01 | 300 | Pod01-GW | 10.51.1.1 | pod01net |
| 02 | 301 | Pod02-GW | 10.51.2.1 | pod02net |
| ... | ... | ... | ... | ... |
| 20 | 319 | Pod20-GW | 10.51.20.1 | pod20net |

## Lab Seeding

### AWX Templates

| Template | Target | Action |
|----------|--------|--------|
| Seed CMMC SC Labs | PodXX-GW + DC01 | Creates intentionally misconfigured states |
| Verify CMMC SC Labs | PodXX-GW + DC01 | Checks student work against expected state |
| Reset SC Labs | PodXX-GW + DC01 | Restores baseline for next student |

### Manual Seeding (if AWX unavailable)

```bash
# From AWX or Ansible control node
ansible-playbook playbooks/seed-cmmc-sc.yml -i inventories/prod.ini

# Seed specific lab only
ansible-playbook playbooks/seed-cmmc-sc.yml -i inventories/prod.ini -e lab_id=M1-L2

# Reset labs
ansible-playbook playbooks/reset-sc-labs.yml -i inventories/prod.ini
```

## Troubleshooting

### Cannot SSH to PodXX-GW

pfSense blocks SSH on WAN by default. Access via LAN:
1. Add temp IP on pod bridge: `ip addr add 10.51.X.100/24 dev podXXnet`
2. SSH to LAN IP: `ssh admin@10.51.X.1`
3. Remove temp IP when done

### Student locked out of pfSense web UI

The anti-lockout rule prevents this, but if it happens:
1. SSH to pfSense via LAN (see above)
2. Run: `pfSsh.php playback enableallowallwan`
3. Or reset: `ansible-playbook playbooks/reset-sc-labs.yml -e pod_id=XX`

### VM won't start

Check disk overlay: `lvs | grep vm-XXX-disk-0`
If corrupt, reclone from template: `qm clone 112 XXX --name PodXX-GW --full 0`

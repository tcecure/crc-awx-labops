# SC Automation Architecture

## Overview

SC labs use a dual-automation pattern:
- **pfSense (PodXX-GW):** Ansible → SSH → PHP config manipulation
- **DC01:** Ansible → WinRM → PowerShell artifact deployment

This differs from AC/IA/SI which only use the DC/WinRM path.

## Ansible Role Structure

```
roles/
├── seed_sc_gw/
│   ├── files/
│   │   ├── seed-sc-baseline.sh    # Configures pfSense identity + base settings
│   │   ├── apply-sc-lab.sh        # Seeds per-lab misconfigured states
│   │   └── reset-sc-labs.sh       # Restores pfSense to clean baseline
│   └── tasks/main.yml
├── seed_sc_dc/
│   ├── files/
│   │   ├── seed-sc-baseline.ps1   # Creates SC-Artifacts dir + pod OU
│   │   ├── apply-sc-lab.ps1       # Deploys worksheets + markers
│   │   └── reset-sc-labs.ps1      # Removes all SC artifacts
│   └── tasks/main.yml
├── verify_sc_gw/
│   └── tasks/main.yml             # PHP-based firewall state checks
└── verify_sc_dc/
    └── tasks/main.yml             # Win artifact/marker checks
```

## pfSense Config Manipulation

The `apply-sc-lab.sh` script uses pfSense's built-in PHP libraries:

```php
require_once('config.inc');
require_once('interfaces.inc');
require_once('filter.inc');

$config = parse_config(true);
$config['filter']['rule'] = array();  // Clear rules
$config['filter']['rule'][] = array(  // Add specific rule
    'type' => 'pass',
    'interface' => 'lan',
    'source' => array('any' => ''),
    'destination' => array('any' => ''),
    'descr' => 'Allow Any (student must remove)'
);
write_config('Seeded by Ansible');
```

This approach:
- Uses pfSense's native config API (no XML parsing)
- Automatically handles rule validation
- Config persists across reboots
- Does NOT require `filter_configure_sync()` — rules apply on next page load

## Playbook Flow

```
seed-cmmc-sc.yml
├── Play 1: crc_pod_gateways (SSH)
│   └── role: seed_sc_gw
│       ├── Copy scripts to /tmp/
│       ├── Run baseline (identity, SSH, web UI)
│       └── Run lab seeder (per-lab rule injection)
└── Play 2: crc_shared_dcs (WinRM)
    └── role: seed_sc_dc (loop: pod 1-20)
        ├── Deploy Jinja2 templates to C:\CyberLab\_Templates\SC\
        ├── Run baseline (create SC-Artifacts dir)
        └── Run lab seeder (deploy worksheets + markers)
```

## Inventory

```ini
[crc_pod_gateways]
pod01-gw ansible_host=10.51.1.1 pod_id=1
...
pod20-gw ansible_host=10.51.20.1 pod_id=20

[crc_pod_gateways:vars]
ansible_connection=ssh
ansible_user=admin
ansible_password=pfsense
ansible_shell_type=csh
ansible_python_interpreter=/usr/local/bin/python3
```

Key: `ansible_shell_type=csh` — pfSense uses tcsh, not bash.

## AWX Templates

| ID | Name | Playbook | Extra Vars |
|----|------|----------|-----------|
| 21 | Seed CMMC SC Labs | seed-cmmc-sc.yml | `lab_id: ALL` |
| 22 | Verify CMMC SC Labs | verify-cmmc-sc.yml | `lab_id: ALL` |
| 23 | Reset SC Labs | reset-sc-labs.yml | — |

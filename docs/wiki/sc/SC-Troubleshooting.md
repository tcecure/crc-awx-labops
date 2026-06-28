# SC Troubleshooting Guide

## VM Issues

### PodXX-GW won't start
```bash
# Check VM status
qm status XXX
# Check for lock files
qm unlock XXX
# Verify disk overlay exists
lvs | grep vm-XXX-disk-0
# If disk missing, reclone from template
qm clone 112 XXX --name PodXX-GW --full 0
qm set XXX --net1 "virtio,bridge=podXXnet"
```

### PodXX-GW has wrong LAN IP
```bash
# From pve1, add temp management IP
sudo ip addr add 10.51.0.100/24 dev podXXnet
# SSH in and fix
sshpass -p pfsense ssh admin@10.51.0.1
# In pfSense shell (option 8):
php -r "
require_once('config.inc');
\$config = parse_config(true);
\$config['interfaces']['lan']['ipaddr'] = '10.51.X.1';
write_config('Fixed LAN IP');
"
# Remove temp IP
sudo ip addr del 10.51.0.100/24 dev podXXnet
```

## Student Access Issues

### Can't reach pfSense web UI
1. Verify VM is running: `qm status XXX`
2. Check student is using correct URL: `http://10.51.XX.1`
3. Verify bridge connectivity from DC
4. Try from DC browser instead of Guacamole HTTP connection

### Locked out after deleting anti-lockout rule
The anti-lockout rule should always be the first rule. If accidentally deleted:
```bash
# SSH via LAN from pve1
sudo ip addr add 10.51.X.100/24 dev podXXnet
sshpass -p pfsense ssh admin@10.51.X.1
# Restore anti-lockout via PHP
php -r "
require_once('config.inc');
\$config = parse_config(true);
array_unshift(\$config['filter']['rule'], array(
    'type' => 'pass', 'interface' => 'lan', 'ipprotocol' => 'inet',
    'protocol' => 'tcp',
    'source' => array('network' => 'lan'),
    'destination' => array('address' => '(self)', 'port' => '80'),
    'descr' => 'Anti-lockout: Web UI'
));
write_config('Restored anti-lockout');
"
```

### pfSense shows "wizard" on first login
If the initial setup wizard appears, skip through it:
1. Click Next on each page
2. Set hostname/domain to match pod
3. Leave WAN as DHCP
4. Set LAN to 10.51.XX.1/24
5. Set admin password to `pfsense`
6. Click Finish

## Lab Seeding Issues

### Seed fails with "No route to host"
- pfSense VM not fully booted. Wait 60-90 seconds after start.
- Wrong IP in inventory. Verify: `ansible-inventory -i inventories/prod.ini --host podXX-gw`

### Seed fails with "Permission denied"
- SSH credentials wrong. Default: admin / pfsense
- SSH disabled on pfSense. Fix via console: System > Advanced > Admin Access > Enable Secure Shell

### Config changes not persisting
- Verify `write_config()` is called in PHP scripts
- Check disk overlay is writable: `lvs | grep vm-XXX`
- Try full clone instead of linked clone for the affected VM

## Reset Issues

### Reset doesn't fully clean up
Some VLANs or OPT interfaces may remain after reset if they were assigned to physical interfaces. Manual cleanup:
```bash
sshpass -p pfsense ssh admin@10.51.X.1
php -r "
require_once('config.inc');
\$config = parse_config(true);
unset(\$config['vlans']);
foreach (array_keys(\$config['interfaces']) as \$iface) {
    if (strpos(\$iface, 'opt') === 0) unset(\$config['interfaces'][\$iface]);
}
write_config('Manual cleanup');
"
```

### Nuclear reset (full VM recreate)
```bash
qm stop XXX
qm destroy XXX
qm clone 112 XXX --name PodXX-GW --full 0
qm set XXX --net1 "virtio,bridge=podXXnet"
# Then run per-pod configuration script
```

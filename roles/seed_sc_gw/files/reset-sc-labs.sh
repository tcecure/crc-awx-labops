#!/bin/sh
# reset-sc-labs.sh
# Restores PodXX-GW pfSense to clean SC baseline state
# Removes all lab-specific firewall rules, VLANs, NATs and restores defaults
# Usage: sh /tmp/reset-sc-labs.sh <pod_number>

POD_NUM=$1
POD_PADDED=$(printf "%02d" "$POD_NUM")
HOSTNAME="Pod${POD_PADDED}-GW"
LAN_IP="10.51.${POD_NUM}.1"

echo "=== SC RESET: $HOSTNAME ==="

php -r "
require_once('config.inc');
require_once('interfaces.inc');
require_once('filter.inc');

\$config = parse_config(true);

// Reset hostname and domain
\$config['system']['hostname'] = '$HOSTNAME';
\$config['system']['domain'] = 'acs-p01.local';

// Reset LAN to pod-specific IP
\$config['interfaces']['lan']['ipaddr'] = '$LAN_IP';
\$config['interfaces']['lan']['subnet'] = '24';

// Clear all firewall rules and set clean defaults
\$config['filter']['rule'] = array();

// Default LAN rules (pfSense standard)
\$config['filter']['rule'][] = array(
    'type' => 'pass',
    'interface' => 'lan',
    'ipprotocol' => 'inet',
    'protocol' => 'tcp',
    'source' => array('network' => 'lan'),
    'destination' => array('address' => '(self)', 'port' => '80'),
    'descr' => 'Anti-lockout: Web UI access',
    'tracker' => time()
);

\$config['filter']['rule'][] = array(
    'type' => 'pass',
    'interface' => 'lan',
    'ipprotocol' => 'inet',
    'source' => array('network' => 'lan'),
    'destination' => array('any' => ''),
    'descr' => 'Default allow LAN to any',
    'tracker' => time() + 1
);

// Remove lab VLANs
unset(\$config['vlans']);

// Remove lab NAT rules
unset(\$config['nat']['rule']);

// Remove lab aliases
unset(\$config['aliases']['alias']);

// Clear OPT interfaces (DMZ etc.)
foreach (array_keys(\$config['interfaces']) as \$iface) {
    if (strpos(\$iface, 'opt') === 0) {
        unset(\$config['interfaces'][\$iface]);
    }
}

// Re-enable logging defaults
\$config['syslog']['filterdescriptions'] = '1';
\$config['syslog']['nentries'] = '500';

// Re-enable SSH
\$config['system']['ssh']['enable'] = 'enabled';

// HTTP web UI
\$config['system']['webgui']['protocol'] = 'http';

write_config('SC labs reset to baseline by Devin');
echo \"RESET_COMPLETE\n\";
"

# Reload firewall rules
/etc/rc.filter_configure 2>/dev/null
# Reload interfaces
/etc/rc.reload_interfaces 2>/dev/null

echo "[SC-RESET] $HOSTNAME restored to baseline"

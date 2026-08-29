#!/bin/sh
# seed-sc-baseline.sh
# Establishes the SC lab baseline on a PodXX-GW (pfSense) instance
# Run on pfSense via SSH: sh /tmp/seed-sc-baseline.sh <pod_number>
# Configures clean baseline state suitable for all 12 SC labs

POD_NUM=$1
POD_PADDED=$(printf "%02d" "$POD_NUM")
HOSTNAME="Pod${POD_PADDED}-GW"
LAN_IP="10.51.${POD_NUM}.1"
DOMAIN="acs-p01.local"

echo "=== SC Baseline: $HOSTNAME (LAN=$LAN_IP) ==="

# Verify we're on pfSense
if [ ! -f /cf/conf/config.xml ]; then
    echo "[ERROR] Not a pfSense system"
    exit 1
fi

# Apply baseline config via PHP
php -r "
require_once('config.inc');
require_once('interfaces.inc');

\$config = parse_config(true);

// System identity
\$config['system']['hostname'] = '$HOSTNAME';
\$config['system']['domain'] = '$DOMAIN';

// LAN interface
\$config['interfaces']['lan']['ipaddr'] = '$LAN_IP';
\$config['interfaces']['lan']['subnet'] = '24';

// Enable SSH
\$config['system']['ssh']['enable'] = 'enabled';

// HTTP web UI (not HTTPS for lab simplicity)
\$config['system']['webgui']['protocol'] = 'http';

// Enable logging
if (!isset(\$config['syslog'])) \$config['syslog'] = array();
\$config['syslog']['filterdescriptions'] = '1';
\$config['syslog']['nentries'] = '500';

// Anti-lockout keeps LAN management access (web UI and SSH) reachable even once
// a student adds a LAN default deny, which the SC labs require.
unset(\$config['system']['webgui']['noantilockout']);

write_config('SC baseline configured by Devin');
echo \"BASELINE_SAVED\n\";
"

echo "[SC-BASELINE] $HOSTNAME baseline complete"

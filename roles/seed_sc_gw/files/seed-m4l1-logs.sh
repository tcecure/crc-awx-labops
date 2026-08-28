#!/bin/sh
# seed-m4l1-logs.sh
# Prepares SC lab M4-L1 (Firewall Log Investigation) on a PodXX-GW (pfSense).
# Run on pfSense via SSH: sh /tmp/seed-m4l1-logs.sh <pod_number>
#
# Without this, Status > System Logs > Firewall on a pod only ever shows WAN
# broadcast/multicast noise from the hosting network: that noise rotates the
# 500 KB log about every 20 minutes, and no host in the pod ever generates the
# port-scan, IRC/C2 or denied-application traffic the investigation questions
# ask about. This script:
#   1. stops the implicit default-block rules from logging that noise,
#   2. raises the log size/retention so evidence survives a lab session,
#   3. writes the M4-L1 investigation dataset into the firewall log.

POD_NUM=$1
if [ -z "$POD_NUM" ]; then
    echo "[ERROR] usage: sh seed-m4l1-logs.sh <pod_number>"
    exit 1
fi
POD_PADDED=$(printf "%02d" "$POD_NUM")
HOSTNAME="Pod${POD_PADDED}-GW"
LAN_NET="10.51.${POD_NUM}"

if [ ! -f /cf/conf/config.xml ]; then
    echo "[ERROR] Not a pfSense system"
    exit 1
fi

echo "======================================================"
echo " SC M4-L1 LOG SEEDING - $HOSTNAME"
echo "======================================================"

# ------------------------------------------------------------------
# 1 + 2. Noise suppression and log retention
# ------------------------------------------------------------------
php -r "
require_once('config.inc');
\$config = parse_config(true);

// The hosting network floods the WAN with mDNS/SSDP/broadcast traffic that the
// implicit private-network, bogon and default-block rules log at roughly a full
// 500 KB log file every 20 minutes. Student-authored rules keep their own
// logging; only the implicit drops go quiet.
\$config['syslog']['nologprivatenets'] = true;
\$config['syslog']['nologbogons'] = true;
\$config['syslog']['nologdefaultblock'] = true;
\$config['syslog']['filterdescriptions'] = '1';
\$config['syslog']['nentries'] = '2000';
\$config['syslog']['logfilesize'] = '4096000';

write_config('SC M4-L1 log environment prepared by Devin');
echo \"log environment configured\n\";
"

# Reload the ruleset through the standard pfSense entry point
/etc/rc.filter_configure >/dev/null 2>&1

# newsyslog only picks up a new size limit once the config is regenerated
/etc/rc.d/newsyslog restart >/dev/null 2>&1 || /usr/sbin/newsyslog -CN >/dev/null 2>&1

# ------------------------------------------------------------------
# 3. Investigation dataset
# ------------------------------------------------------------------
WAN_IP=$(php -r "require_once('interfaces.inc'); echo get_interface_ip('wan');")
WAN_IF=$(php -r "require_once('interfaces.inc'); echo get_real_interface('wan');")
LAN_IF=$(php -r "require_once('interfaces.inc'); echo get_real_interface('lan');")

# Fixed tracker id for seeded entries, so re-running replaces the dataset
# instead of stacking a second copy of it on top of the first.
DATASET_TRACKER="15000${POD_PADDED}00"
if grep -q ",,,${DATASET_TRACKER}," /var/log/filter.log 2>/dev/null; then
    grep -v ",,,${DATASET_TRACKER}," /var/log/filter.log > /tmp/filter.log.trimmed
    cat /tmp/filter.log.trimmed > /var/log/filter.log
    rm -f /tmp/filter.log.trimmed
    echo "[M4-L1] replaced previously seeded dataset"
fi

# Records the implicit rules logged before suppression took effect would
# otherwise sit on top of the investigation data in the log viewer. Records
# from student-authored rules are kept.
grep -v -E ',,,(11001|11002|1200[0-9]|10000001[0-9][0-9]),' /var/log/filter.log > /tmp/filter.log.denoised 2>/dev/null
cat /tmp/filter.log.denoised > /var/log/filter.log
rm -f /tmp/filter.log.denoised

# The log viewer also reads the rotated archives, which hold nothing but that
# same pre-suppression noise.
rm -f /var/log/filter.log.[0-9]*

cat > /tmp/crc-m4l1-dataset.php <<'PHPEOF'
<?php
// Writes filterlog-format entries so Status > System Logs > Firewall shows the
// activity the M4-L1 worksheet asks about. Entry format matches filterlog(8)
// so the pfSense log parser and its filters work on these lines unchanged.
$pod = (int)$argv[1];
$wan_ip = $argv[2];
$wan_if = $argv[3];
$lan_if = $argv[4];
$tracker = $argv[5];
$lan_net = '10.51.' . $pod;
$host = sprintf('Pod%02d-GW', $pod);

function stamp($ts)
{
    return date('M', $ts) . sprintf(' %2d ', (int)date('j', $ts)) . date('H:i:s', $ts);
}

function entry($ts, $host, $tracker, $if, $dir, $proto, $src, $dst, $sport, $dport, $flags)
{
    $id = mt_rand(1000, 65000);
    $seq = mt_rand(100000000, 999999999);
    if ($proto == 'tcp') {
        $tail = sprintf('6,tcp,60,%s,%s,%d,%d,0,%s,%d,,65535,,mss;sackOK;TS;nop;wscale',
            $src, $dst, $sport, $dport, $flags, $seq);
    } else {
        $tail = sprintf('17,udp,%d,%s,%s,%d,%d,%d', mt_rand(60, 300), $src, $dst,
            $sport, $dport, mt_rand(30, 260));
    }
    return sprintf("%s %s filterlog[100]: 5,,,%s,%s,match,block,%s,4,0x0,,64,%d,0,DF,%s\n",
        stamp($ts), $host, $tracker, $if, $dir, $id, $tail);
}

$now = time();
$lines = '';

// Q1 - inbound port scans from three external sources
$scanners = array('203.0.113.45', '198.51.100.77', '45.153.160.132');
$scan_ports = array(22, 23, 3389, 445, 1433, 5900);
$t = $now - 5400;
foreach ($scanners as $scanner) {
    foreach ($scan_ports as $port) {
        for ($i = 0; $i < 3; $i++) {
            $lines .= entry($t, $host, $tracker, $wan_if, 'in', 'tcp', $scanner,
                $wan_ip, mt_rand(40000, 61000), $port, 'S');
            $t += 2;
        }
    }
    $t += 120;
}

// Q2 - outbound IRC / C2 attempts from an internal workstation
$t = $now - 3600;
$c2 = array(
    array('185.130.44.108', 6667),
    array('91.219.236.18', 6697),
    array('185.130.44.108', 6669),
);
foreach ($c2 as $target) {
    for ($i = 0; $i < 6; $i++) {
        $lines .= entry($t, $host, $tracker, $lan_if, 'out', 'tcp', $lan_net . '.55',
            $target[0], mt_rand(40000, 61000), $target[1], 'S');
        $t += 300;
    }
}

// Q3 - legitimate application traffic caught by the default deny
$t = $now - 2700;
$denied = array(
    array($lan_net . '.20', '10.50.1.10', 445),   // file share
    array($lan_net . '.20', '10.50.1.10', 389),   // LDAP
    array($lan_net . '.31', '10.50.1.10', 3268),  // global catalog
    array($lan_net . '.31', '10.50.1.10', 123),   // NTP (udp)
);
foreach ($denied as $d) {
    for ($i = 0; $i < 4; $i++) {
        $proto = ($d[2] == 123) ? 'udp' : 'tcp';
        $lines .= entry($t, $host, $tracker, $lan_if, 'in', $proto, $d[0], $d[1],
            mt_rand(40000, 61000), $d[2], 'S');
        $t += 240;
    }
}

// Q4 - inbound attempts from unusual source ranges
$t = $now - 1800;
$foreign = array('103.75.190.22', '178.128.22.9', '5.188.206.14', '196.196.53.7');
foreach ($foreign as $src) {
    foreach (array(3389, 445, 22) as $port) {
        $lines .= entry($t, $host, $tracker, $wan_if, 'in', 'tcp', $src, $wan_ip,
            mt_rand(40000, 61000), $port, 'S');
        $t += 60;
    }
}

file_put_contents('/var/log/filter.log', $lines, FILE_APPEND);
$count = substr_count($lines, "\n");
echo "[M4-L1] wrote $count investigation entries\n";
PHPEOF

php /tmp/crc-m4l1-dataset.php "$POD_NUM" "$WAN_IP" "$WAN_IF" "$LAN_IF" "$DATASET_TRACKER"
rm -f /tmp/crc-m4l1-dataset.php

echo "[SC-M4-L1] $HOSTNAME log environment ready"

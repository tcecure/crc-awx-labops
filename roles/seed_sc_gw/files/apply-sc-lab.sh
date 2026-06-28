#!/bin/sh
# apply-sc-lab.sh
# Seeds SC lab scenarios on PodXX-GW (pfSense)
# Usage: sh /tmp/apply-sc-lab.sh <pod_number> <lab_id|ALL>
# lab_id: M1-L1 through M4-L3 or ALL

POD_NUM=$1
LAB_ID=${2:-ALL}
POD_PADDED=$(printf "%02d" "$POD_NUM")
HOSTNAME="Pod${POD_PADDED}-GW"
LAN_NET="10.51.${POD_NUM}"

echo "======================================================"
echo " SC LAB SEEDING - $HOSTNAME"
echo "======================================================"

# ========================================================================
# Helper: Apply PHP config changes
# ========================================================================
apply_php() {
    local label="$1"
    local code="$2"
    echo "--- Seeding $label ---"
    php -r "
require_once('config.inc');
require_once('interfaces.inc');
require_once('filter.inc');
\$config = parse_config(true);
$code
write_config('SC $label seeded by Devin');
echo \"[SEEDED] $label\n\";
"
}

# ========================================================================
# MODULE 1: Foundations of the Digital Perimeter
# ========================================================================

seed_m1_l1() {
    # SC-L1-L1: Understanding Trust Boundaries (document-based)
    # Seed: Create a network diagram artifact and boundary worksheet on pfSense
    apply_php "M1-L1" "
// Create marker file for boundary identification exercise
file_put_contents('/tmp/sc_m1l1_ready', 'Trust boundary lab ready');
echo \"[M1-L1] Document lab - boundary diagram exercise\n\";
"
}

seed_m1_l2() {
    # SC-L1-L2: Deny By Default Firewall
    # Seed: Start with Allow Any Any rule on LAN - student must reconfigure to deny-by-default
    apply_php "M1-L2" "
// Clear existing LAN rules and add a permissive Allow Any Any
\$config['filter']['rule'] = array();

// Rule 1: Anti-lockout (keep web UI accessible)
\$config['filter']['rule'][] = array(
    'type' => 'pass',
    'interface' => 'lan',
    'ipprotocol' => 'inet',
    'protocol' => 'tcp',
    'source' => array('network' => 'lan'),
    'destination' => array('address' => '(self)', 'port' => '80'),
    'descr' => 'Anti-lockout: LAN to web UI',
    'tracker' => time()
);

// Rule 2: The BAD rule - Allow Any Any (student must remove this)
\$config['filter']['rule'][] = array(
    'type' => 'pass',
    'interface' => 'lan',
    'ipprotocol' => 'inet',
    'source' => array('any' => ''),
    'destination' => array('any' => ''),
    'descr' => 'INSECURE: Allow all traffic (REMOVE THIS)',
    'tracker' => time() + 1
);

// Rule 3: Another bad rule - Allow all outbound (no restrictions)
\$config['filter']['rule'][] = array(
    'type' => 'pass',
    'interface' => 'wan',
    'ipprotocol' => 'inet',
    'source' => array('any' => ''),
    'destination' => array('any' => ''),
    'descr' => 'INSECURE: Allow all WAN traffic (RESTRICT THIS)',
    'tracker' => time() + 2
);
"
}

seed_m1_l3() {
    # SC-L1-L3: Monitor, Control, Protect
    # Seed: Configure rules + logging showing all three responsibilities
    apply_php "M1-L3" "
\$config['filter']['rule'] = array();

// Anti-lockout
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

// MONITOR: Pass rule with logging enabled (shows what monitoring looks like)
\$config['filter']['rule'][] = array(
    'type' => 'pass',
    'interface' => 'lan',
    'ipprotocol' => 'inet',
    'protocol' => 'tcp',
    'source' => array('network' => 'lan'),
    'destination' => array('any' => '', 'port' => '80,443'),
    'descr' => 'MONITOR: Web traffic (logging enabled)',
    'log' => '',
    'tracker' => time() + 1
);

// CONTROL: Pass rule restricting DNS to specific server
\$config['filter']['rule'][] = array(
    'type' => 'pass',
    'interface' => 'lan',
    'ipprotocol' => 'inet',
    'protocol' => 'tcp/udp',
    'source' => array('network' => 'lan'),
    'destination' => array('address' => '10.50.1.10', 'port' => '53'),
    'descr' => 'CONTROL: DNS only to DC01',
    'log' => '',
    'tracker' => time() + 2
);

// PROTECT: Block rule preventing access to sensitive subnet
\$config['filter']['rule'][] = array(
    'type' => 'block',
    'interface' => 'lan',
    'ipprotocol' => 'inet',
    'source' => array('network' => 'lan'),
    'destination' => array('address' => '10.50.0.0/16'),
    'descr' => 'PROTECT: Block access to management network',
    'log' => '',
    'tracker' => time() + 3
);

// Default deny with logging
\$config['filter']['rule'][] = array(
    'type' => 'block',
    'interface' => 'lan',
    'ipprotocol' => 'inet',
    'source' => array('any' => ''),
    'destination' => array('any' => ''),
    'descr' => 'Default Deny - All other traffic blocked',
    'log' => '',
    'tracker' => time() + 4
);

// Enable detailed logging
\$config['syslog']['filterdescriptions'] = '1';
\$config['syslog']['nentries'] = '500';
"
}

# ========================================================================
# MODULE 2: External and Internal Boundaries
# ========================================================================

seed_m2_l1() {
    # SC-L2-L1: Draw the Organizational Boundary (document-based)
    # Seed: Provide network topology data for students to diagram
    apply_php "M2-L1" "
// Document lab - students draw org boundary from live pfSense data
echo \"[M2-L1] Document lab - organizational boundary diagram\n\";
"
}

seed_m2_l2() {
    # SC-L2-L2: Secure the DMZ
    # Seed: Web server rule pointing to LAN (wrong) - student must create OPT1/DMZ
    apply_php "M2-L2" "
\$config['filter']['rule'] = array();

// Anti-lockout
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

// BAD: Web server on internal LAN (should be in DMZ)
\$config['filter']['rule'][] = array(
    'type' => 'pass',
    'interface' => 'wan',
    'ipprotocol' => 'inet',
    'protocol' => 'tcp',
    'source' => array('any' => ''),
    'destination' => array('address' => '${LAN_NET}.50', 'port' => '80,443'),
    'descr' => 'PROBLEM: Web server on internal LAN (move to DMZ)',
    'log' => '',
    'tracker' => time() + 1
);

// BAD: No separation between web server and internal resources
\$config['filter']['rule'][] = array(
    'type' => 'pass',
    'interface' => 'lan',
    'ipprotocol' => 'inet',
    'source' => array('any' => ''),
    'destination' => array('any' => ''),
    'descr' => 'PROBLEM: Flat network - no segmentation',
    'tracker' => time() + 2
);

// NAT rule pointing to LAN web server
if (!isset(\$config['nat']['rule'])) \$config['nat']['rule'] = array();
\$config['nat']['rule'][] = array(
    'source' => array('any' => ''),
    'destination' => array('network' => 'wanip', 'port' => '80'),
    'protocol' => 'tcp',
    'target' => '${LAN_NET}.50',
    'local-port' => '80',
    'interface' => 'wan',
    'descr' => 'PROBLEM: NAT to internal LAN web server (should be DMZ)',
    'associated-rule-id' => 'pass'
);
"
}

seed_m2_l3() {
    # SC-L2-L3: Internal Segmentation with VLANs
    # Seed: Flat network config - student must create VLANs for HR/Finance/Engineering/Guest
    apply_php "M2-L3" "
\$config['filter']['rule'] = array();

// Anti-lockout
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

// Single flat LAN rule - no segmentation
\$config['filter']['rule'][] = array(
    'type' => 'pass',
    'interface' => 'lan',
    'ipprotocol' => 'inet',
    'source' => array('any' => ''),
    'destination' => array('any' => ''),
    'descr' => 'PROBLEM: All departments on flat network (segment with VLANs)',
    'tracker' => time() + 1
);

// Remove any existing VLANs (ensure flat)
unset(\$config['vlans']);

// Leave instructions in aliases
if (!isset(\$config['aliases']['alias'])) \$config['aliases']['alias'] = array();
\$config['aliases']['alias'][] = array(
    'name' => 'TASK_HR_SUBNET',
    'type' => 'network',
    'address' => '${LAN_NET}.0/26',
    'descr' => 'TASK: Create VLAN 10 for HR (${LAN_NET}.0/26)',
    'detail' => 'HR Department'
);
\$config['aliases']['alias'][] = array(
    'name' => 'TASK_FINANCE_SUBNET',
    'type' => 'network',
    'address' => '${LAN_NET}.64/26',
    'descr' => 'TASK: Create VLAN 20 for Finance (${LAN_NET}.64/26)',
    'detail' => 'Finance Department'
);
\$config['aliases']['alias'][] = array(
    'name' => 'TASK_ENGINEERING_SUBNET',
    'type' => 'network',
    'address' => '${LAN_NET}.128/26',
    'descr' => 'TASK: Create VLAN 30 for Engineering (${LAN_NET}.128/26)',
    'detail' => 'Engineering Department'
);
\$config['aliases']['alias'][] = array(
    'name' => 'TASK_GUEST_SUBNET',
    'type' => 'network',
    'address' => '${LAN_NET}.192/26',
    'descr' => 'TASK: Create VLAN 40 for Guest WiFi (${LAN_NET}.192/26)',
    'detail' => 'Guest Network'
);
"
}

# ========================================================================
# MODULE 3: Firewall Rules
# ========================================================================

seed_m3_l1() {
    # SC-L3-L1: Firewall Rule Audit
    # Seed: Intentionally bad rules - shadows, duplicates, Allow Any
    apply_php "M3-L1" "
\$config['filter']['rule'] = array();
\$t = time();

// Anti-lockout
\$config['filter']['rule'][] = array(
    'type' => 'pass', 'interface' => 'lan', 'ipprotocol' => 'inet',
    'protocol' => 'tcp',
    'source' => array('network' => 'lan'),
    'destination' => array('address' => '(self)', 'port' => '80'),
    'descr' => 'Anti-lockout: Web UI', 'tracker' => \$t++
);

// BAD: Allow Any Any (too permissive)
\$config['filter']['rule'][] = array(
    'type' => 'pass', 'interface' => 'lan', 'ipprotocol' => 'inet',
    'source' => array('any' => ''), 'destination' => array('any' => ''),
    'descr' => 'Allow ALL traffic (TOO PERMISSIVE)', 'tracker' => \$t++
);

// SHADOWED: This rule never fires because Allow Any above it
\$config['filter']['rule'][] = array(
    'type' => 'block', 'interface' => 'lan', 'ipprotocol' => 'inet',
    'source' => array('any' => ''), 'destination' => array('address' => '10.50.0.0/16'),
    'descr' => 'Block management access (SHADOWED - never fires)', 'tracker' => \$t++
);

// DUPLICATE: Same as Allow Any above
\$config['filter']['rule'][] = array(
    'type' => 'pass', 'interface' => 'lan', 'ipprotocol' => 'inet',
    'source' => array('any' => ''), 'destination' => array('any' => ''),
    'descr' => 'Pass all LAN (DUPLICATE)', 'tracker' => \$t++
);

// UNUSED: Block a nonexistent network
\$config['filter']['rule'][] = array(
    'type' => 'block', 'interface' => 'lan', 'ipprotocol' => 'inet',
    'source' => array('address' => '172.16.99.0/24'), 'destination' => array('any' => ''),
    'descr' => 'Block 172.16.99.0 (UNUSED - network does not exist)', 'tracker' => \$t++
);

// OK: Legitimate DNS rule (should keep)
\$config['filter']['rule'][] = array(
    'type' => 'pass', 'interface' => 'lan', 'ipprotocol' => 'inet',
    'protocol' => 'tcp/udp',
    'source' => array('network' => 'lan'), 'destination' => array('address' => '10.50.1.10', 'port' => '53'),
    'descr' => 'Allow DNS to DC01 (KEEP THIS)', 'tracker' => \$t++
);

// SHADOWED: More specific HTTP rule shadowed by Allow Any
\$config['filter']['rule'][] = array(
    'type' => 'pass', 'interface' => 'lan', 'ipprotocol' => 'inet',
    'protocol' => 'tcp',
    'source' => array('network' => 'lan'), 'destination' => array('any' => '', 'port' => '80,443'),
    'descr' => 'Allow web traffic (SHADOWED by Allow Any)', 'tracker' => \$t++
);
"
}

seed_m3_l2() {
    # SC-L3-L2: Rule Ordering Challenge
    # Seed: Rules in wrong order - traffic fails until student reorders
    apply_php "M3-L2" "
\$config['filter']['rule'] = array();
\$t = time();

// Anti-lockout (keep first)
\$config['filter']['rule'][] = array(
    'type' => 'pass', 'interface' => 'lan', 'ipprotocol' => 'inet',
    'protocol' => 'tcp',
    'source' => array('network' => 'lan'),
    'destination' => array('address' => '(self)', 'port' => '80'),
    'descr' => 'Anti-lockout: Web UI', 'tracker' => \$t++
);

// WRONG ORDER: Block all BEFORE allow rules (should be after)
\$config['filter']['rule'][] = array(
    'type' => 'block', 'interface' => 'lan', 'ipprotocol' => 'inet',
    'source' => array('any' => ''), 'destination' => array('any' => ''),
    'descr' => 'Default Deny (WRONG POSITION - move to bottom)', 'log' => '',
    'tracker' => \$t++
);

// These rules never fire because Block All is above them
\$config['filter']['rule'][] = array(
    'type' => 'pass', 'interface' => 'lan', 'ipprotocol' => 'inet',
    'protocol' => 'tcp/udp',
    'source' => array('network' => 'lan'), 'destination' => array('address' => '10.50.1.10', 'port' => '53'),
    'descr' => 'Allow DNS to DC01 (BLOCKED - wrong order)', 'tracker' => \$t++
);

\$config['filter']['rule'][] = array(
    'type' => 'pass', 'interface' => 'lan', 'ipprotocol' => 'inet',
    'protocol' => 'tcp',
    'source' => array('network' => 'lan'), 'destination' => array('any' => '', 'port' => '80,443'),
    'descr' => 'Allow Web traffic (BLOCKED - wrong order)', 'tracker' => \$t++
);

\$config['filter']['rule'][] = array(
    'type' => 'pass', 'interface' => 'lan', 'ipprotocol' => 'inet',
    'protocol' => 'tcp',
    'source' => array('network' => 'lan'), 'destination' => array('address' => '10.50.1.10', 'port' => '3389'),
    'descr' => 'Allow RDP to DC01 (BLOCKED - wrong order)', 'tracker' => \$t++
);

\$config['filter']['rule'][] = array(
    'type' => 'pass', 'interface' => 'lan', 'ipprotocol' => 'inet',
    'protocol' => 'icmp',
    'source' => array('network' => 'lan'), 'destination' => array('any' => ''),
    'descr' => 'Allow ICMP/Ping (BLOCKED - wrong order)', 'tracker' => \$t++
);
"
}

seed_m3_l3() {
    # SC-L3-L3: Least Privilege Access
    # Seed: Accounting app with too many ports open - student removes unnecessary
    apply_php "M3-L3" "
\$config['filter']['rule'] = array();
\$t = time();

// Anti-lockout
\$config['filter']['rule'][] = array(
    'type' => 'pass', 'interface' => 'lan', 'ipprotocol' => 'inet',
    'protocol' => 'tcp',
    'source' => array('network' => 'lan'),
    'destination' => array('address' => '(self)', 'port' => '80'),
    'descr' => 'Anti-lockout: Web UI', 'tracker' => \$t++
);

// Accounting app server - TOO MANY PORTS OPEN
\$config['filter']['rule'][] = array(
    'type' => 'pass', 'interface' => 'lan', 'ipprotocol' => 'inet',
    'protocol' => 'tcp',
    'source' => array('network' => 'lan'),
    'destination' => array('address' => '${LAN_NET}.100', 'port' => '21'),
    'descr' => 'Accounting: FTP (UNNECESSARY - remove)', 'tracker' => \$t++
);

\$config['filter']['rule'][] = array(
    'type' => 'pass', 'interface' => 'lan', 'ipprotocol' => 'inet',
    'protocol' => 'tcp',
    'source' => array('network' => 'lan'),
    'destination' => array('address' => '${LAN_NET}.100', 'port' => '22'),
    'descr' => 'Accounting: SSH (UNNECESSARY - remove)', 'tracker' => \$t++
);

\$config['filter']['rule'][] = array(
    'type' => 'pass', 'interface' => 'lan', 'ipprotocol' => 'inet',
    'protocol' => 'tcp',
    'source' => array('network' => 'lan'),
    'destination' => array('address' => '${LAN_NET}.100', 'port' => '23'),
    'descr' => 'Accounting: Telnet (DANGEROUS - remove)', 'tracker' => \$t++
);

\$config['filter']['rule'][] = array(
    'type' => 'pass', 'interface' => 'lan', 'ipprotocol' => 'inet',
    'protocol' => 'tcp',
    'source' => array('network' => 'lan'),
    'destination' => array('address' => '${LAN_NET}.100', 'port' => '80'),
    'descr' => 'Accounting: HTTP (UNNECESSARY - app uses HTTPS)', 'tracker' => \$t++
);

\$config['filter']['rule'][] = array(
    'type' => 'pass', 'interface' => 'lan', 'ipprotocol' => 'inet',
    'protocol' => 'tcp',
    'source' => array('network' => 'lan'),
    'destination' => array('address' => '${LAN_NET}.100', 'port' => '443'),
    'descr' => 'Accounting: HTTPS (REQUIRED - keep this)', 'tracker' => \$t++
);

\$config['filter']['rule'][] = array(
    'type' => 'pass', 'interface' => 'lan', 'ipprotocol' => 'inet',
    'protocol' => 'tcp',
    'source' => array('network' => 'lan'),
    'destination' => array('address' => '${LAN_NET}.100', 'port' => '3306'),
    'descr' => 'Accounting: MySQL direct (UNNECESSARY - app handles DB)', 'tracker' => \$t++
);

\$config['filter']['rule'][] = array(
    'type' => 'pass', 'interface' => 'lan', 'ipprotocol' => 'inet',
    'protocol' => 'tcp',
    'source' => array('network' => 'lan'),
    'destination' => array('address' => '${LAN_NET}.100', 'port' => '8080'),
    'descr' => 'Accounting: Alt HTTP (UNNECESSARY - remove)', 'tracker' => \$t++
);

// DNS
\$config['filter']['rule'][] = array(
    'type' => 'pass', 'interface' => 'lan', 'ipprotocol' => 'inet',
    'protocol' => 'tcp/udp',
    'source' => array('network' => 'lan'), 'destination' => array('address' => '10.50.1.10', 'port' => '53'),
    'descr' => 'Allow DNS to DC01', 'tracker' => \$t++
);

// Default deny
\$config['filter']['rule'][] = array(
    'type' => 'block', 'interface' => 'lan', 'ipprotocol' => 'inet',
    'source' => array('any' => ''), 'destination' => array('any' => ''),
    'descr' => 'Default Deny', 'log' => '', 'tracker' => \$t++
);
"
}

# ========================================================================
# MODULE 4: Monitoring and Validation
# ========================================================================

seed_m4_l1() {
    # SC-L4-L1: Firewall Log Investigation (document-based but with real logs)
    # Seed: Generate realistic log entries for students to investigate
    apply_php "M4-L1" "
\$config['filter']['rule'] = array();
\$t = time();

// Anti-lockout
\$config['filter']['rule'][] = array(
    'type' => 'pass', 'interface' => 'lan', 'ipprotocol' => 'inet',
    'protocol' => 'tcp',
    'source' => array('network' => 'lan'),
    'destination' => array('address' => '(self)', 'port' => '80'),
    'descr' => 'Anti-lockout: Web UI', 'tracker' => \$t++
);

// Rules with logging to generate investigation material
\$config['filter']['rule'][] = array(
    'type' => 'pass', 'interface' => 'lan', 'ipprotocol' => 'inet',
    'protocol' => 'tcp',
    'source' => array('network' => 'lan'), 'destination' => array('any' => '', 'port' => '80,443'),
    'descr' => 'Web traffic (logged)', 'log' => '', 'tracker' => \$t++
);

\$config['filter']['rule'][] = array(
    'type' => 'pass', 'interface' => 'lan', 'ipprotocol' => 'inet',
    'protocol' => 'tcp/udp',
    'source' => array('network' => 'lan'), 'destination' => array('address' => '10.50.1.10', 'port' => '53'),
    'descr' => 'DNS to DC01 (logged)', 'log' => '', 'tracker' => \$t++
);

// Block rules that generate suspicious log entries
\$config['filter']['rule'][] = array(
    'type' => 'block', 'interface' => 'wan', 'ipprotocol' => 'inet',
    'protocol' => 'tcp',
    'source' => array('any' => ''), 'destination' => array('any' => '', 'port' => '22,23,3389,445'),
    'descr' => 'Block inbound port scans (logged)', 'log' => '', 'tracker' => \$t++
);

\$config['filter']['rule'][] = array(
    'type' => 'block', 'interface' => 'lan', 'ipprotocol' => 'inet',
    'protocol' => 'tcp',
    'source' => array('network' => 'lan'), 'destination' => array('any' => '', 'port' => '6660:6669,6697'),
    'descr' => 'Block IRC (possible malware C2)', 'log' => '', 'tracker' => \$t++
);

\$config['filter']['rule'][] = array(
    'type' => 'block', 'interface' => 'lan', 'ipprotocol' => 'inet',
    'source' => array('any' => ''), 'destination' => array('any' => ''),
    'descr' => 'Default Deny (logged)', 'log' => '', 'tracker' => \$t++
);

// Enable detailed logging
\$config['syslog']['filterdescriptions'] = '1';
\$config['syslog']['nentries'] = '1000';
"
}

seed_m4_l2() {
    # SC-L4-L2: Verify SC Compliance (assessor walkthrough)
    # Seed: A mostly-correct config for students to verify against checklist
    apply_php "M4-L2" "
\$config['filter']['rule'] = array();
\$t = time();

// Anti-lockout
\$config['filter']['rule'][] = array(
    'type' => 'pass', 'interface' => 'lan', 'ipprotocol' => 'inet',
    'protocol' => 'tcp',
    'source' => array('network' => 'lan'),
    'destination' => array('address' => '(self)', 'port' => '80'),
    'descr' => 'Anti-lockout: Web UI', 'tracker' => \$t++
);

// Good rules - mostly compliant
\$config['filter']['rule'][] = array(
    'type' => 'pass', 'interface' => 'lan', 'ipprotocol' => 'inet',
    'protocol' => 'tcp/udp',
    'source' => array('network' => 'lan'), 'destination' => array('address' => '10.50.1.10', 'port' => '53'),
    'descr' => 'DNS to DC01', 'tracker' => \$t++
);

\$config['filter']['rule'][] = array(
    'type' => 'pass', 'interface' => 'lan', 'ipprotocol' => 'inet',
    'protocol' => 'tcp',
    'source' => array('network' => 'lan'), 'destination' => array('any' => '', 'port' => '80,443'),
    'descr' => 'Web access', 'tracker' => \$t++
);

// Default deny
\$config['filter']['rule'][] = array(
    'type' => 'block', 'interface' => 'lan', 'ipprotocol' => 'inet',
    'source' => array('any' => ''), 'destination' => array('any' => ''),
    'descr' => 'Default Deny', 'log' => '', 'tracker' => \$t++
);

// Enable logging for compliance
\$config['syslog']['filterdescriptions'] = '1';
\$config['syslog']['nentries'] = '500';
"
}

seed_m4_l3() {
    # SC-L4-L3: Final Capstone
    # Seed: Poorly configured network - student must fix everything
    apply_php "M4-L3" "
\$config['filter']['rule'] = array();
\$t = time();

// Anti-lockout (only protection)
\$config['filter']['rule'][] = array(
    'type' => 'pass', 'interface' => 'lan', 'ipprotocol' => 'inet',
    'protocol' => 'tcp',
    'source' => array('network' => 'lan'),
    'destination' => array('address' => '(self)', 'port' => '80'),
    'descr' => 'Anti-lockout: Web UI', 'tracker' => \$t++
);

// PROBLEM 1: Allow Any Any (no deny-by-default)
\$config['filter']['rule'][] = array(
    'type' => 'pass', 'interface' => 'lan', 'ipprotocol' => 'inet',
    'source' => array('any' => ''), 'destination' => array('any' => ''),
    'descr' => 'CAPSTONE: Allow All (implement deny-by-default)', 'tracker' => \$t++
);

// PROBLEM 2: WAN allows inbound to everything
\$config['filter']['rule'][] = array(
    'type' => 'pass', 'interface' => 'wan', 'ipprotocol' => 'inet',
    'source' => array('any' => ''), 'destination' => array('any' => ''),
    'descr' => 'CAPSTONE: WAN wide open (restrict inbound)', 'tracker' => \$t++
);

// PROBLEM 3: No VLANs (flat network)
unset(\$config['vlans']);

// PROBLEM 4: No logging enabled
unset(\$config['syslog']['filterdescriptions']);

// PROBLEM 5: Dangerous services exposed
\$config['filter']['rule'][] = array(
    'type' => 'pass', 'interface' => 'wan', 'ipprotocol' => 'inet',
    'protocol' => 'tcp',
    'source' => array('any' => ''), 'destination' => array('any' => '', 'port' => '23'),
    'descr' => 'CAPSTONE: Telnet from internet (extremely dangerous)', 'tracker' => \$t++
);

// PROBLEM 6: No NAT rules for proper service publishing
unset(\$config['nat']['rule']);
"
}

# ========================================================================
# EXECUTION
# ========================================================================

run_lab() {
    case "$1" in
        M1-L1) seed_m1_l1 ;;
        M1-L2) seed_m1_l2 ;;
        M1-L3) seed_m1_l3 ;;
        M2-L1) seed_m2_l1 ;;
        M2-L2) seed_m2_l2 ;;
        M2-L3) seed_m2_l3 ;;
        M3-L1) seed_m3_l1 ;;
        M3-L2) seed_m3_l2 ;;
        M3-L3) seed_m3_l3 ;;
        M4-L1) seed_m4_l1 ;;
        M4-L2) seed_m4_l2 ;;
        M4-L3) seed_m4_l3 ;;
        *) echo "[ERROR] Unknown lab: $1"; exit 1 ;;
    esac
}

if [ "$LAB_ID" = "ALL" ]; then
    for lab in M1-L1 M1-L2 M1-L3 M2-L1 M2-L2 M2-L3 M3-L1 M3-L2 M3-L3 M4-L1 M4-L2 M4-L3; do
        run_lab "$lab"
    done
else
    run_lab "$LAB_ID"
fi

echo ""
echo "======================================================"
echo " SC GW SEEDING COMPLETE - $HOSTNAME"
echo "======================================================"

# SC Validation Framework

## Automated Verification

The `verify_sc_gw` role checks pfSense configuration state via SSH/PHP. The `verify_sc_dc` role checks DC01 artifacts via WinRM.

## Per-Lab Verification Logic

### M1-L1: Trust Boundaries (Document)
- **DC Check:** `_LAB_READY_SC-M1-L1.txt` marker exists
- **Student Check:** `M1-L1_Boundary_Diagram.txt` exists in SC-Artifacts

### M1-L2: Deny By Default
- **GW Check 1:** No "pass" rule with `source=any`, `destination=any`, no protocol (Allow Any Any)
- **GW Check 2:** Last rule is `type=block`
- **Expected:** PASS:NoAllowAny + PASS:DefaultDenyLast

### M1-L3: Monitor/Control/Protect
- **GW Check:** At least 2 rules have `log` attribute enabled
- **DC Check:** Completed worksheet exists

### M2-L1: Organizational Boundary (Document)
- **DC Check:** Marker + diagram artifact exists

### M2-L2: Secure the DMZ
- **GW Check:** At least one `opt*` interface exists in config
- **Expected:** PASS:DMZExists

### M2-L3: Internal Segmentation
- **GW Check:** `vlans.vlan` count >= 2
- **Expected:** PASS:VLANs(N)

### M3-L1: Firewall Rule Audit
- **GW Check:** No Allow Any rules, no duplicate rule signatures
- **Expected:** PASS:RulesClean

### M3-L2: Rule Ordering
- **GW Check:** Block-all rule position > last allow rule position
- **Expected:** PASS:OrderCorrect

### M3-L3: Least Privilege
- **GW Check:** Only TCP 443 allowed to accounting server IP; no other pass rules to that destination
- **Expected:** PASS:OnlyHTTPS

### M4-L1: Log Investigation (Document)
- **DC Check:** Investigation report exists in SC-Artifacts

### M4-L2: Compliance Verification
- **DC Check:** Compliance checklist + evidence screenshots exist

### M4-L3: Final Capstone
- **GW Check (composite):**
  1. `deny_by_default` — no Allow Any
  2. `wan_secured` — no open WAN pass rules
  3. `no_telnet` — no port 23 on WAN
  4. `logging` — syslog configured
  5. `segmentation` — 2+ VLANs
- **Expected:** `passed: 5, total: 5`

## Running Verification

```bash
# Verify all labs on all pods
ansible-playbook playbooks/verify-cmmc-sc.yml -i inventories/prod.ini

# Verify specific lab
ansible-playbook playbooks/verify-cmmc-sc.yml -e lab_id=M1-L2

# Output is JSON with PASS/FAIL per check
```

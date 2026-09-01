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
- **GW Check:** No Allow Any rules, and no duplicate rule *within the same interface*
- **Expected:** PASS:RulesClean
- A duplicate is compared on interface + action + protocol + source + destination. Every
  interface legitimately ends in its own catch-all deny, so the LAN, DMZ and VLAN denies are
  not duplicates of each other; before this scoping a fully segmented pod could not pass.
- **Failure text:** `FAIL:Issues(N): rule 29 on opt5 ('Allow HTTPS'): duplicate of rule 28` —
  the number is the count of offending rules, not a task number, and each one is named.

### M3-L2: Rule Ordering
- **GW Check:** Block-all rule position > last allow rule position
- **Expected:** PASS:OrderCorrect

### M3-L3: Least Privilege
- **GW Check:** Only TCP 443 allowed to the accounting server (`10.51.<pod>.100`); no other pass
  rules to that destination. `443`, `https` and `443-443` all count, and a destination written
  as `.100/32` is accepted.
- **Expected:** PASS:OnlyHTTPS
- **Failure text:** `FAIL:ExtraPorts(N): 21,3306` when unnecessary ports survive, and
  `FAIL:NoHTTPSRuleTo10.51.<pod>.100` when the HTTPS keeper rule is missing — deleting all seven
  seeded rules, or pointing the surviving rule at an interface address instead of the host, is
  the common cause and used to be reported as `ExtraPorts(0)`.

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

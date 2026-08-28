# CMMC Level 1 System & Communications Protection (SC) Labs — Student Completion Guide

This guide provides step-by-step instructions for completing all 12 System & Communications Protection labs. Each lab presents a real-world network security challenge using the pfSense firewall — the same technology used by thousands of organizations to protect their networks.

---

## Table of Contents

1. [Before You Begin](#before-you-begin)
2. [How to Connect to the Lab Environment](#how-to-connect-to-the-lab-environment)
3. [How to Access the pfSense Firewall](#how-to-access-the-pfsense-firewall)
4. [How to Open Lab Artifacts](#how-to-open-lab-artifacts)
5. [Understanding Your Pod](#understanding-your-pod)
6. [Module 1: Foundations of the Digital Perimeter (Labs M1-L1 – M1-L3)](#module-1-foundations-of-the-digital-perimeter)
7. [Module 2: External and Internal Boundaries (Labs M2-L1 – M2-L3)](#module-2-external-and-internal-boundaries)
8. [Module 3: Firewall Rules (Labs M3-L1 – M3-L3)](#module-3-firewall-rules)
9. [Module 4: Monitoring and Validation (Labs M4-L1 – M4-L3)](#module-4-monitoring-and-validation)
10. [Quick Reference: pfSense Navigation](#quick-reference-pfsense-navigation)
11. [Tips and Common Mistakes](#tips-and-common-mistakes)
12. [Lab Completion Checklist](#lab-completion-checklist)

---

## Before You Begin

### What You Need

- Your **Pod number** (your instructor will assign this, e.g., Pod01, Pod05, Pod12)
- Your **Guacamole login credentials** (your instructor will provide your username and password)
- A computer with a web browser (Chrome, Firefox, or Edge) — no special software needed

### What You Will Be Doing

In these labs you will use **pfSense** — an open-source firewall and router platform — to configure boundary protection, create deny-by-default policies, segment networks, audit firewall rules, and investigate logs. These are the same skills a network security analyst uses daily.

### CMMC Context

These labs align with **CMMC Level 1 System & Communications Protection (SC)** requirements:
- **SC.L1-3.13.1** — Monitor, control, and protect communications at the external and internal boundaries of organizational systems

This single SC control covers boundary protection, firewall configuration, network segmentation, deny-by-default policies, and communications monitoring.

---

## How to Connect to the Lab Environment

You will connect to the lab through **Apache Guacamole** — a web-based remote desktop gateway. There is nothing to install; everything runs in your web browser.

### Step 1: Open the Guacamole Gateway

1. Open your web browser (Chrome, Firefox, or Edge)
2. Go to: **https://crc.guac.01.tcecure.com/#/**
3. You will see a login screen

### Step 2: Log In with Your Student Credentials

1. Enter your **Username** — this matches your pod number:
   - Pod 01 → `student01`
   - Pod 02 → `student02`
   - Pod 05 → `student05`
   - Pod 12 → `student12`
   - *(and so on — the number matches your assigned pod)*
2. Enter your **Password** (provided by your instructor)
3. Click **Login**

### Step 3: Connect to the Domain Controller

After logging in, you will see a list of available connections:

| Connection Name | What It Is |
|---|---|
| **PODXX-DC** | Domain Controller — your desktop for every lab, including the firewall labs |

The pfSense firewall is not a separate connection. You reach it from a browser
inside **PODXX-DC**, as described in the next section.

1. Click on **PODXX-DC** (where XX is your pod number, e.g., **POD03-DC**)
2. The remote desktop session will open in your browser
3. Wait for the Windows Server desktop to appear

> **Tip:** To return to the Guacamole home screen, press **Ctrl+Alt+Shift** to open the side menu, then click **Home**.

---

## How to Access the pfSense Firewall

Most SC labs require you to log into the pfSense firewall web interface. Do it
from inside your remote desktop:

1. Connect to **PODXX-DC** via Guacamole
2. Open a web browser (Edge or Firefox) **on that desktop**
3. Navigate to: **http://10.51.XX.1** (replace XX with your pod number)
   - Pod 01 → `http://10.51.1.1`
   - Pod 05 → `http://10.51.5.1`
   - Pod 12 → `http://10.51.12.1`

### pfSense Login Credentials

| Field | Value |
|---|---|
| Username | `admin` |
| Password | `pfsense` |

After logging in, you will see the pfSense Dashboard showing system status, interfaces, and traffic information.

---

## How to Open Lab Artifacts

Lab artifacts (worksheets, instructions, evidence templates) are stored on the Domain Controller:

1. Connect to **PODXX-DC** via Guacamole
2. Open **File Explorer** (click the folder icon in the taskbar)
3. Navigate to: `C:\CyberLab\PodXX\SC-Artifacts\`
4. You will see files for each lab:
   - `SC-M1-L1_*` — Module 1, Lab 1 files
   - `SC-M1-L2_*` — Module 1, Lab 2 files
   - `_LAB_READY_SC-M1-L1.txt` — Marker indicating lab is seeded

### Saving Your Work

After completing each lab, save your evidence to the same `SC-Artifacts` directory:
- Screenshots: Use **Snipping Tool** (Windows key → type "snipping") to capture your pfSense configuration
- Text files: Save completed worksheets and reports
- Always include your pod number in evidence file names

---

## Understanding Your Pod

Each student has an isolated pod environment:

```
Your Pod (PodXX)
├── PODXX-DC (Domain Controller)
│   ├── Active Directory
│   ├── Lab artifacts: C:\CyberLab\PodXX\SC-Artifacts\
│   └── Shared with AC, IA, SI labs
│
└── PODXX-GW (Gateway/Firewall — reached from a browser on PODXX-DC)
    ├── WAN Interface: Connected to external network
    ├── LAN Interface: 10.51.XX.1/24
    ├── Web UI: http://10.51.XX.1
    └── SSH: admin@10.51.XX.1
```

Your firewall is completely isolated from other students' pods. You can make any configuration changes without affecting anyone else.

---

## Module 1: Foundations of the Digital Perimeter

### Lab M1-L1: Understanding Trust Boundaries

**Difficulty:** Beginner | **Time:** 20 minutes | **Type:** Document-based

#### Scenario
You are the new cybersecurity analyst at ACS Consulting, a small defense contractor. Your first task is to identify the trust boundaries in the company's network.

#### What You Need
- Artifact: `SC-M1-L1_Boundary_Worksheet.txt`
- Artifact: `SC-M1-L1_Network_Topology.txt`
- Access to pfSense Dashboard (http://10.51.XX.1)

#### Steps

1. **Open the Network Topology reference:**
   - On PODXX-DC, navigate to `C:\CyberLab\PodXX\SC-Artifacts\`
   - Open `SC-M1-L1_Network_Topology.txt`
   - Review the network layout

2. **Log into pfSense to see the live configuration:**
   - Open browser → `http://10.51.XX.1`
   - Login: admin / pfsense
   - Go to **Status → Dashboard** to see interfaces
   - Go to **Status → Interfaces** for detailed network info

3. **Open the Boundary Worksheet:**
   - Open `SC-M1-L1_Boundary_Worksheet.txt`
   - Complete each task:

4. **Task 1 — Identify the External Boundary:**
   - The external boundary is where your network meets the internet
   - Look at the pfSense WAN interface — what separates your network from the outside?
   - Answer: The firewall's WAN interface is the external boundary

5. **Task 2 — Identify the Internal Boundary:**
   - Are there zones within the LAN?
   - Is there a DMZ configured? (Check Interfaces)

6. **Task 3 — Mark Trusted vs Untrusted Assets:**
   - Internet = Untrusted
   - ISP Router = Untrusted
   - Firewall = Boundary device (controls trust)
   - DC01, Workstation, File Server = Trusted (inside the boundary)

7. **Task 4 — Locate where FCI should reside:**
   - FCI (Federal Contract Information) should only exist in the trusted zone
   - Behind the firewall, on protected servers

8. **Save your completed worksheet:**
   ```
   Save as: C:\CyberLab\PodXX\SC-Artifacts\SC-M1-L1_Completed.txt
   ```
   > This exact file name is required (`.txt`, `.csv`, or `.png` is accepted) and it must contain at least 50 characters of content.

#### Why This Matters
CMMC SC.L1-3.13.1 requires organizations to identify and protect their system boundaries. Without knowing where your boundaries are, you cannot protect them.

---

### Lab M1-L2: Deny By Default Firewall

**Difficulty:** Beginner | **Time:** 30 minutes | **Type:** Hands-on (pfSense)

#### Scenario
The pfSense firewall currently has an "Allow Any Any" rule — it permits ALL traffic through without restrictions. This is a critical security misconfiguration that violates CMMC deny-by-default requirements.

#### What You Need
- pfSense web UI (http://10.51.XX.1)
- Artifact: `SC-M1-L2_Lab_Instructions.txt`

#### Steps

1. **Log into pfSense:**
   - Open browser → `http://10.51.XX.1`
   - Login: admin / pfsense

2. **View the current (bad) rules:**
   - Navigate to **Firewall → Rules → LAN**
   - You should see rules including "INSECURE: Allow all traffic"
   - This means ANY device can send ANY traffic anywhere — no restrictions

3. **Understand the problem:**
   - With "Allow Any Any," a compromised workstation can reach every server
   - An attacker inside the network has unrestricted access
   - This violates CMMC's deny-by-default principle

4. **Delete the "Allow Any Any" rule:**
   - Check the box next to the "INSECURE: Allow all traffic" rule
   - Click the **Delete** button (trash can icon)
   - **Also delete** the "INSECURE: Allow all WAN traffic" rule
   - Click **Apply Changes** at the top

5. **Create specific allow rules (deny-by-default):**
   - Click the **+ Add** button (down arrow, add to bottom)
   - Create these rules one at a time:

   **Rule 1: Allow DNS**
   - Action: Pass
   - Interface: LAN
   - Protocol: TCP/UDP
   - Source: LAN net
   - Destination: Single host — `10.50.1.10`
   - Destination Port: DNS (53)
   - Description: `Allow DNS to DC01`
   - Click Save

   **Rule 2: Allow Web Traffic**
   - Action: Pass
   - Interface: LAN
   - Protocol: TCP
   - Source: LAN net
   - Destination: Any
   - Destination Port: HTTP (80) and HTTPS (443)
   - Description: `Allow web browsing`
   - Click Save

   **Rule 3: Allow ICMP (Ping)**
   - Action: Pass
   - Interface: LAN
   - Protocol: ICMP
   - Source: LAN net
   - Destination: Any
   - Description: `Allow ping for troubleshooting`
   - Click Save

6. **Verify the default deny is in place:**
   - pfSense automatically blocks anything not explicitly allowed
   - Your rule list should now show ONLY:
     1. Anti-lockout (Web UI access)
     2. Allow DNS to DC01
     3. Allow web browsing
     4. Allow ping
   - Everything else is denied by default

7. **Click Apply Changes**

8. **Test your configuration:**
   - Go to **Diagnostics → Ping**
   - Ping `10.50.1.10` (DC01) — should succeed
   - Go to **Status → System Logs → Firewall**
   - Look for blocked traffic entries — these prove deny-by-default is working

9. **Save evidence:**
   - Take a screenshot of your final rule list
   ```
   Save as: C:\CyberLab\PodXX\SC-Artifacts\M1-L2_FinalRules.png
   ```

> **Hint:** If you accidentally lock yourself out of the pfSense web UI, don't panic. The anti-lockout rule at the top prevents this. If it does happen, ask your instructor for help.

#### Why This Matters
"Deny by default" is the foundation of all network security. Instead of trying to block everything bad (impossible), you only allow what is specifically needed. This is required by CMMC SC.L1-3.13.1.

---

### Lab M1-L3: Monitor, Control, Protect

**Difficulty:** Intermediate | **Time:** 30 minutes | **Type:** Hands-on (pfSense)

#### Scenario
A firewall has three core responsibilities: **Monitor** (observe and log traffic), **Control** (decide what traffic is allowed), and **Protect** (block harmful traffic). Your firewall has rules demonstrating all three. Your job is to identify which is which.

#### What You Need
- pfSense web UI (http://10.51.XX.1)
- Artifact: `SC-M1-L3_Worksheet.txt`

#### Steps

1. **Log into pfSense** and go to **Firewall → Rules → LAN**

2. **Review each rule and identify its responsibility:**

   | Rule Description | Responsibility | Why? |
   |---|---|---|
   | Web traffic (logging enabled) | **Monitor** | Logging shows us what's happening |
   | DNS only to DC01 | **Control** | Restricts DNS to a specific server |
   | Block access to management network | **Protect** | Prevents unauthorized access |
   | Default Deny | **Protect** | Blocks everything not explicitly allowed |

3. **Check the logs to see monitoring in action:**
   - Go to **Status → System Logs → Firewall**
   - You should see log entries from rules that have logging enabled
   - Each entry shows: time, interface, source IP, destination IP, action (pass/block)

4. **Complete the worksheet:**
   - Open `SC-M1-L3_Worksheet.txt` on the DC
   - For each task, identify the specific rule and explain how it demonstrates that responsibility
   - Answer the analysis questions

5. **Save evidence:**
   - Screenshot the firewall log showing all three types of entries
   ```
   Save as: C:\CyberLab\PodXX\SC-Artifacts\M1-L3_Worksheet_Complete.txt
   ```

#### Why This Matters
Understanding Monitor/Control/Protect helps you design complete security architectures. A firewall that only blocks (protects) but doesn't log (monitor) is blind to attacks. One that only logs but doesn't restrict (control) is useless.

---

## Module 2: External and Internal Boundaries

### Lab M2-L1: Draw the Organizational Boundary

**Difficulty:** Beginner | **Time:** 20 minutes | **Type:** Document-based

#### Scenario
Using your pod's live pfSense configuration, create a complete organizational boundary diagram showing all network zones, connections, and security boundaries.

#### Steps

1. **Gather network information from pfSense:**
   - Log into pfSense (http://10.51.XX.1)
   - Go to **Status → Interfaces** — note WAN and LAN details
   - Go to **Firewall → Rules** — understand traffic flow
   - Go to **Status → Dashboard** — see system overview

2. **Open the boundary worksheet** on the DC:
   - `SC-M2-L1_Boundary_Worksheet.txt`

3. **Draw your diagram including:**
   - ISP / Internet (external, untrusted)
   - Your pod's firewall (boundary device)
   - LAN network (internal, trusted)
   - Each server/workstation with its role
   - Mark each boundary line clearly

4. **Save your completed diagram:**
   ```
   Save as: C:\CyberLab\PodXX\SC-Artifacts\SC-M2-L1_Completed.txt
   ```
   > This exact file name is required (`.txt`, `.csv`, or `.png` is accepted) and it must contain at least 50 characters of content.

---

### Lab M2-L2: Secure the DMZ

**Difficulty:** Advanced | **Time:** 45 minutes | **Type:** Hands-on (pfSense)

#### Scenario
ACS Consulting's public web server is sitting on the internal LAN at 10.51.XX.50. This means external visitors accessing the web server can potentially reach internal resources like DC01. You must move the web server into a DMZ (Demilitarized Zone).

#### Steps

1. **Log into pfSense** and review the current (bad) configuration:
   - Go to **Firewall → Rules → WAN**
   - Note the rule allowing HTTP to an internal LAN IP — this is the problem
   - Go to **Firewall → NAT → Port Forward**
   - Note the NAT rule pointing to the LAN

2. **Create a DMZ interface:**

   Your firewall has only two physical ports (WAN and LAN), so **Interfaces →
   Assignments** has no **+ Add** button until you create a VLAN for the DMZ to
   sit on. Do it in this order:

   - Go to **Interfaces → VLANs → + Add**
     - Parent Interface: `vtnet1` (LAN)
     - VLAN Tag: `50`
     - Description: `DMZ`
     - Save
   - Go to **Interfaces → Assignments** — **+ Add** is now available; add the
     `VLAN 50 on vtnet1` interface (it appears as **OPT1**)
   - Go to **Interfaces → OPT1**
     - Tick **Enable interface**
     - Description: `DMZ`
     - IPv4 Configuration Type: **Static IPv4**
     - IPv4 Address: `10.52.XX.1` / `24` (replace XX with your pod number)
     - Save → **Apply Changes**

   > The DMZ must use a subnet of its own. Do not give it an address inside
   > `10.51.XX.0/24` — that range already belongs to the LAN and pfSense will
   > reject the overlap.

3. **Update firewall rules:**

   **DMZ rules:**
   - Allow inbound HTTP/HTTPS from WAN to DMZ web server
   - **Block** all traffic from DMZ to LAN (critical — isolates the DMZ)
   - Allow DMZ to respond to established connections

   **LAN rules:**
   - Allow LAN to manage DMZ (for administration)

4. **Update NAT rules:**
   - Go to **Firewall → NAT → Port Forward**
   - Change the target from the LAN IP to the new DMZ IP
   - Save → Apply

5. **Verify:**
   - [ ] Web server accessible from WAN through DMZ
   - [ ] DMZ cannot ping or reach LAN resources
   - [ ] LAN can still manage the DMZ
   - [ ] DC01 is NOT accessible from DMZ

6. **Save evidence:**
   ```
   Save as: C:\CyberLab\PodXX\SC-Artifacts\M2-L2_DMZ_Rules.png
   Save as: C:\CyberLab\PodXX\SC-Artifacts\M2-L2_DMZ_Verification.txt
   ```

> **Hint:** The key concept is that a DMZ is a "semi-trusted" zone. External users can reach the web server, but if the web server is compromised, the attacker cannot reach the internal LAN.

**How the automated check scores this lab:** it passes as soon as the firewall
has an assigned optional interface (the DMZ you added in step 2). The rules, NAT
change and verification evidence are graded by your instructor.

---

### Lab M2-L3: Internal Segmentation with VLANs

**Difficulty:** Advanced | **Time:** 45 minutes | **Type:** Hands-on (pfSense)

#### Scenario
ACS Consulting has four departments on a flat network — HR, Finance, Engineering, and Guest WiFi. Any device can reach any other device. A guest on the WiFi can access HR file shares and Finance databases.

#### Steps

1. **Review the segmentation plan:**
   - Open `SC-M2-L3_Segmentation_Plan.txt` on the DC
   - Note the four required VLANs and their subnets

2. **Create VLANs on pfSense:**
   - Go to **Interfaces → VLANs**
   - Click **+ Add**:
     - Parent Interface: `vtnet1` (LAN)
     - VLAN Tag: `10`
     - Description: `HR Department`
   - Repeat for:
     - VLAN 20 — Finance
     - VLAN 30 — Engineering
     - VLAN 40 — Guest WiFi

3. **Assign VLAN interfaces:**
   - Go to **Interfaces → Assignments** (the **+ Add** button only appears once
     at least one VLAN exists)
   - Assign each VLAN as a new interface (OPT1 through OPT4)
   - Rename them: HR, FINANCE, ENGINEERING, GUEST
   - Set each interface to **Static IPv4** with its own subnet — replace XX with
     your pod number:

     | Interface | VLAN | IPv4 address |
     |---|---|---|
     | HR | 10 | `10.61.XX.1/24` |
     | FINANCE | 20 | `10.62.XX.1/24` |
     | ENGINEERING | 30 | `10.63.XX.1/24` |
     | GUEST | 40 | `10.64.XX.1/24` |

   - Enable each interface → Save → Apply

   > Do not give a VLAN an address inside `10.51.XX.0/24`; that range belongs to
   > the LAN and pfSense rejects the overlap.

4. **Configure DHCP (optional):**
   - Go to **Services → DHCP Server**
   - Enable DHCP on each VLAN interface with appropriate ranges

5. **Create firewall rules for isolation:**

   **HR VLAN rules:**
   - Allow DNS to DC01 (10.50.1.10:53)
   - Allow AD traffic to DC01
   - Block traffic to Finance, Engineering, Guest
   - Default deny

   **Finance VLAN rules:**
   - Allow DNS to DC01
   - Allow HTTPS to accounting app
   - Block traffic to HR, Engineering, Guest
   - Default deny

   **Guest VLAN rules:**
   - Allow DNS (any DNS server)
   - Allow HTTP/HTTPS to internet
   - **Block ALL internal networks** (most important rule)
   - Default deny

6. **Verify isolation:**
   - From each VLAN, test connectivity:
     - [ ] Guest cannot reach HR
     - [ ] Guest cannot reach Finance
     - [ ] Engineering cannot reach Finance
     - [ ] All departments can reach DC01 for DNS
     - [ ] Guest can browse the internet

7. **Save evidence:**
   ```
   Save as: C:\CyberLab\PodXX\SC-Artifacts\M2-L3_VLAN_Config.png
   Save as: C:\CyberLab\PodXX\SC-Artifacts\M2-L3_Isolation_Test.txt
   ```

**How the automated check scores this lab:** it passes when two or more VLANs
exist on the firewall. The isolation rules and test evidence are graded by your
instructor.

#### Why This Matters
Network segmentation limits the blast radius of a breach. If an attacker compromises a guest device, they cannot reach HR or Finance data. This is a core CMMC SC requirement.

---

## Module 3: Firewall Rules

### Lab M3-L1: Firewall Rule Audit

**Difficulty:** Intermediate | **Time:** 30 minutes | **Type:** Hands-on (pfSense)

#### Scenario
A previous administrator left messy, insecure firewall rules. You must audit every rule, identify issues, clean up the rule set, and verify everything still works.

#### Steps

1. **Log into pfSense** and go to **Firewall → Rules → LAN**

2. **Open the audit worksheet:**
   - On DC: `SC-M3-L1_Audit_Worksheet.txt`

3. **Audit each rule — identify the issue type:**

   | Issue Type | Description | Example |
   |---|---|---|
   | **[A] Allow Any** | Overly permissive rule | "Allow ALL traffic" |
   | **[S] Shadowed** | Never fires because a broader rule above matches first | A block rule after an allow-all |
   | **[D] Duplicate** | Same effect as another rule | Two identical allow rules |
   | **[U] Unused** | References a network/service that doesn't exist | Blocking a nonexistent subnet |
   | **[O] OK** | Legitimate, properly scoped | "Allow DNS to DC01" |

4. **Document each rule in the audit table**

5. **Clean up the rules:**
   - Delete all [A] Allow Any rules
   - Delete all [D] Duplicate rules
   - Delete all [U] Unused rules
   - Move [S] Shadowed rules above the rule blocking them, OR delete if unnecessary
   - Keep [O] OK rules
   - Click **Apply Changes**

6. **Verify connectivity:**
   - DNS should still work
   - Web browsing should still work
   - Unauthorized traffic should be blocked

7. **Save evidence:**
   ```
   Save as: C:\CyberLab\PodXX\SC-Artifacts\M3-L1_Audit_Complete.txt
   Save as: C:\CyberLab\PodXX\SC-Artifacts\M3-L1_CleanRules.png
   ```

---

### Lab M3-L2: Rule Ordering Challenge

**Difficulty:** Intermediate | **Time:** 25 minutes | **Type:** Hands-on (pfSense)

#### Scenario
The firewall has all the right rules, but they are in the wrong order. A "Block All" rule appears BEFORE the allow rules, so all legitimate traffic is being blocked.

#### Steps

1. **Log into pfSense** and go to **Firewall → Rules → LAN**

2. **Observe the problem:**
   - The "Default Deny" rule is near the top
   - All allow rules (DNS, web, RDP, ICMP) are below it
   - pfSense processes rules top-to-bottom — first match wins
   - Since "Block All" matches everything, the allow rules never fire

3. **Reorder the rules:**
   - Click and drag rules to reorder them (grab the three-line handle on the left)
   - Or select a rule and use the arrow buttons to move it
   - **Correct order:**
     1. Anti-lockout (Web UI access) — keep first
     2. Allow DNS to DC01
     3. Allow Web traffic (80, 443)
     4. Allow RDP to DC01
     5. Allow ICMP/Ping
     6. Default Deny — **must be LAST**

4. **Click Apply Changes**

5. **Verify everything works:**
   - Go to **Diagnostics → Ping** — ping 10.50.1.10 (should succeed now)
   - Go to **Status → System Logs → Firewall** — confirm traffic is flowing
   - Check that the Default Deny is still catching unauthorized traffic

6. **Save evidence:**
   ```
   Save as: C:\CyberLab\PodXX\SC-Artifacts\M3-L2_Reordered_Rules.png
   ```

> **Key Takeaway:** In firewall administration, the ORDER of rules is as important as the rules themselves. A correctly written rule in the wrong position is useless.

**How the automated check scores this lab:** only the **LAN** tab is examined.
It passes when the LAN tab has at least one allow rule and the last LAN rule is
a block rule to any destination. The deny rule may have a source of `LAN net`
or `any` — either is accepted, so this lab and M3-L1 (which is about removing
overly broad and duplicate allow rules) cannot contradict each other. Rules on
the WAN, DMZ or VLAN tabs do not affect this lab.

---

### Lab M3-L3: Least Privilege Access

**Difficulty:** Intermediate | **Time:** 25 minutes | **Type:** Hands-on (pfSense)

#### Scenario
The accounting application at 10.51.XX.100 only needs HTTPS (TCP 443). But the firewall allows FTP, SSH, Telnet, HTTP, MySQL, and an alternate HTTP port — all unnecessary and potentially dangerous.

#### Steps

1. **Log into pfSense** and go to **Firewall → Rules → LAN**

2. **Identify rules targeting the accounting server (10.51.XX.100):**
   - You should see 7 rules allowing different ports
   - Only ONE is needed: TCP 443 (HTTPS)

3. **Delete unnecessary port rules:**
   - Check the box next to each unnecessary rule:
     - [ ] Port 21 (FTP) — DELETE
     - [ ] Port 22 (SSH) — DELETE
     - [ ] Port 23 (Telnet) — DELETE (especially dangerous!)
     - [ ] Port 80 (HTTP) — DELETE (app uses HTTPS)
     - [ ] Port 443 (HTTPS) — **KEEP THIS**
     - [ ] Port 3306 (MySQL) — DELETE (app handles DB internally)
     - [ ] Port 8080 (Alt HTTP) — DELETE
   - Click Delete → Apply Changes

4. **Verify:**
   - The accounting app should still work on HTTPS
   - All other ports should be blocked (default deny catches them)
   - Check **Status → System Logs → Firewall** for blocked traffic to confirm

5. **Save evidence:**
   ```
   Save as: C:\CyberLab\PodXX\SC-Artifacts\M3-L3_LeastPrivilege_Rules.png
   ```

#### Why This Matters
Least privilege means giving only the minimum access needed. An application that only needs port 443 should not have ports 21, 22, 23, 80, 3306, and 8080 open. Each open port is an attack surface.

---

## Module 4: Monitoring and Validation

### Lab M4-L1: Firewall Log Investigation

**Difficulty:** Intermediate | **Time:** 30 minutes | **Type:** Hands-on (pfSense)

#### Scenario
Your firewall logs contain evidence of suspicious activity. As the security analyst, investigate the logs and document your findings.

#### Steps

1. **Log into pfSense** and go to **Status → System Logs → Firewall**

   > The log holds several hundred entries. Use the **Advanced Log Filter**
   > (click the filter icon) to search one thing at a time — for example
   > `22` or `3389` in *Destination Port*, or `6667` to find IRC traffic.
   > Entries on the WAN interface are inbound from outside your pod; entries
   > on the LAN interface come from hosts inside it.

2. **Investigate the following categories:**

   **Port Scans:**
   - Look for blocked connections to ports 22 (SSH), 23 (Telnet), 3389 (RDP), 445 (SMB)
   - Multiple connection attempts from the same IP = likely port scan
   - Document: source IPs, ports targeted, timestamps

   **Blocked Malware Indicators:**
   - Look for blocked outbound connections to IRC ports (6660-6669)
   - These could indicate malware trying to contact a command-and-control server
   - Document: internal IPs making suspicious outbound connections

   **Denied Legitimate Traffic:**
   - Look for blocked traffic that should be allowed
   - This might indicate missing firewall rules
   - Document: what applications are affected

   **Suspicious Sources:**
   - Note any blocked traffic from unusual IP ranges
   - Document: IPs, patterns, recommended actions

3. **Open the investigation worksheet** on the DC:
   - `SC-M4-L1_Investigation_Worksheet.txt`
   - Answer each investigation question with evidence from the logs

4. **Save evidence:**
   ```
   Save as: C:\CyberLab\PodXX\SC-Artifacts\SC-M4-L1_Completed.txt
   ```
   > This exact file name is required (`.txt` or `.csv`) and it must contain at least 50 characters of content.

---

### Lab M4-L2: Verify SC Compliance

**Difficulty:** Intermediate | **Time:** 35 minutes | **Type:** Hands-on (pfSense + DC)

#### Scenario
You are performing a simplified CMMC assessor walkthrough. Using the compliance checklist, verify that your pod's System & Communications Protection controls are properly implemented.

#### Steps

1. **Open the compliance checklist** on the DC:
   - `SC-M4-L2_Compliance_Checklist.txt`

2. **Work through each section:**

   **Boundary Protection:**
   - Log into pfSense → Status → Dashboard
   - Screenshot the dashboard showing the firewall is operational
   - Check Firewall → Rules for configured rules
   - Check Status → System Logs for log entries

   **Firewall Configuration:**
   - Verify default deny policy exists (last rule)
   - Verify no "Allow Any Any" rules
   - List each allow rule and justify why it's needed

   **Logging:**
   - Verify logging is active on key rules
   - Screenshot log entries

   **Segmentation:**
   - Check Interfaces → VLANs for network segmentation
   - If not yet configured, document this as a finding

   **FCI Protection:**
   - Identify where FCI resides
   - Document the firewall rules protecting it

3. **For each checklist item:**
   - Check the box if compliant
   - Take a screenshot as evidence
   - Note any findings or non-compliance issues

4. **Save evidence:**
   ```
   Save your completed checklist to: C:\CyberLab\PodXX\SC-Artifacts\SC-M4-L2_Completed.txt
   Save any screenshots to:          C:\CyberLab\PodXX\SC-Artifacts\M4-L2_Compliance_Evidence\
   ```
   > `SC-M4-L2_Completed.txt` (or `.csv`) is the file verification looks for, and it must contain at least 50 characters of content. Screenshots are supporting evidence only.

---

### Lab M4-L3: Final Capstone

**Difficulty:** Expert | **Time:** 60 minutes | **Type:** Hands-on (pfSense + DC)

#### Scenario
ACS Consulting, a small defense contractor, has inherited a poorly configured network. The firewall allows all traffic, has no segmentation, no logging, and dangerous services are exposed to the internet. You must fix EVERYTHING.

This lab is the practical assessment for the entire SC module. You will use everything you have learned.

#### Steps

1. **Log into pfSense** and assess the damage:
   - Go to **Firewall → Rules** — note the "Allow Any" rules
   - Check WAN rules — note inbound Telnet exposure
   - Check for VLANs — none configured
   - Check logging — not enabled

2. **TASK 1: Implement Deny-By-Default** (15 min)
   - Delete all "Allow Any" rules on LAN and WAN
   - Create specific allow rules for required services
   - Ensure default deny is last rule
   - *(Apply everything you learned in Lab M1-L2)*

3. **TASK 2: Secure the WAN** (10 min)
   - Remove the Telnet exposure (port 23 from WAN)
   - Block all inbound WAN traffic by default
   - Only allow necessary inbound services

4. **TASK 3: Create Network Segmentation** (15 min)
   - Create at least 2 VLANs
   - Configure inter-VLAN rules
   - Isolate sensitive resources
   - *(Apply everything you learned in Lab M2-L3)*

5. **TASK 4: Enable Logging** (5 min)
   - Enable logging on **every** block rule (edit the rule and tick **Log
     packets that are handled by this rule**) — the automated check requires all
     block rules to log
   - Enable logging on critical allow rules
   - Verify logs appear in **Status → System Logs**

6. **TASK 5: Verify Communications** (10 min)
   - Test DNS (ping DC01)
   - Test web browsing
   - Verify internal services accessible
   - Verify external attacks blocked

7. **TASK 6: Produce Assessment Evidence** (5 min)
   - Screenshot final firewall rules
   - Screenshot VLAN configuration
   - Screenshot firewall logs
   - Complete the compliance checklist
   - Draw a network diagram with boundaries marked

8. **Save all evidence:**
   ```
   Save to: C:\CyberLab\PodXX\SC-Artifacts\M4-L3_Capstone\
   ```

#### Grading Criteria
All 6 tasks must be completed with evidence:
- [ ] No "Allow Any" rules, default deny in place
- [ ] WAN secured, no dangerous services exposed
- [ ] At least 2 VLANs configured with isolation rules
- [ ] Logging enabled and generating entries
- [ ] Required communications verified working
- [ ] All evidence screenshots saved

**How the automated check scores this lab:** the verifier reads the firewall
configuration and reports 5 checks — `deny_by_default`, `wan_secured`,
`no_telnet`, `logging` (the **Log packets** box ticked on every block rule) and
`segmentation` (2 or more VLANs). Task 5 and Task 6 are graded from your saved
evidence by your instructor, not by the automated check, so "5 of 5" is a full
pass. If the tracker shows fewer than 5, it now names the failing check.

---

## Quick Reference: pfSense Navigation

| Task | Where to Go |
|---|---|
| View/edit firewall rules | **Firewall → Rules** (select interface: LAN, WAN, etc.) |
| Create a new rule | **Firewall → Rules → + Add** |
| View firewall logs | **Status → System Logs → Firewall** |
| View system dashboard | **Status → Dashboard** |
| View interface status | **Status → Interfaces** |
| Create VLANs | **Interfaces → VLANs** |
| Assign interfaces | **Interfaces → Assignments** |
| Configure NAT/port forwarding | **Firewall → NAT → Port Forward** |
| Test connectivity (ping) | **Diagnostics → Ping** |
| Configure DHCP | **Services → DHCP Server** |
| View ARP table | **Diagnostics → ARP Table** |
| Backup configuration | **Diagnostics → Backup & Restore** |

### pfSense Rule Tips

- **Rules are processed top to bottom** — first match wins
- **Default deny is automatic** — anything not explicitly allowed is blocked
- **Always click "Apply Changes"** after modifying rules
- **Logging:** Click the information icon (i) on a rule to enable/disable logging
- **Rule actions:** Pass = allow, Block = silently drop, Reject = drop with notification

---

## Tips and Common Mistakes

### Common Mistakes

| Mistake | Solution |
|---|---|
| Forgetting to click "Apply Changes" | Always click the yellow "Apply Changes" bar at the top after modifying rules |
| Creating rules on wrong interface | LAN rules = traffic FROM LAN devices. WAN rules = traffic FROM the internet |
| Deleting the anti-lockout rule | Don't delete it — it keeps you from locking yourself out of the web UI |
| Rules in wrong order | Default deny must always be LAST. Specific rules go first |
| Not saving evidence | Screenshot every change before and after |

### Getting Unstuck

- **Locked out of web UI?** Contact your instructor — they can reset your firewall
- **Can't reach pfSense?** Make sure you're using the right IP: `http://10.51.XX.1`
- **Rules not taking effect?** Click "Apply Changes" — changes are not active until applied
- **Lost your changes?** Go to **Diagnostics → Backup & Restore** to restore a previous config

---

## Lab Completion Checklist

Use this checklist to track your progress:

| Lab | Name | Status |
|---|---|---|
| M1-L1 | Understanding Trust Boundaries | ☐ |
| M1-L2 | Deny By Default Firewall | ☐ |
| M1-L3 | Monitor, Control, Protect | ☐ |
| M2-L1 | Draw Organizational Boundary | ☐ |
| M2-L2 | Secure the DMZ | ☐ |
| M2-L3 | Internal Segmentation (VLANs) | ☐ |
| M3-L1 | Firewall Rule Audit | ☐ |
| M3-L2 | Rule Ordering Challenge | ☐ |
| M3-L3 | Least Privilege Access | ☐ |
| M4-L1 | Firewall Log Investigation | ☐ |
| M4-L2 | Verify SC Compliance | ☐ |
| M4-L3 | Final Capstone | ☐ |

**After completing each lab:**
1. Verify your evidence files are saved in `C:\CyberLab\PodXX\SC-Artifacts\`
2. Check that your artifact files have your pod number in the file names
3. Mark the lab as complete in this checklist

---

*This guide was created for the Digital Resilience Community Clinic (DRCC) Cyber Range.*
*CMMC Level 1 — System & Communications Protection (SC) Module*

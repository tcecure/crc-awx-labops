# CMMC Level 1 Physical Protection (PE) Labs — Student Completion Guide

This guide provides step-by-step instructions for completing all 6 Physical Protection labs. Each lab gives you real physical-security records — employee rosters, badge logs, visitor logs, camera notes, alarm exports — and asks you to find who should not have access, what happened, and what action is required.

---

## Table of Contents

1. [Before You Begin](#before-you-begin)
2. [How to Connect to the Lab Environment](#how-to-connect-to-the-lab-environment)
3. [How to Open Your Lab Artifacts](#how-to-open-your-lab-artifacts)
4. [Understanding Your Pod](#understanding-your-pod)
5. [Module 1: Physical Access Authorization (Labs M1-L1 – M1-L2)](#module-1-physical-access-authorization)
6. [Module 2: Visitor Escort and Temporary Badges (Labs M2-L1 – M2-L2)](#module-2-visitor-escort-and-temporary-badges)
7. [Module 3: Audit Logs and Incident Response (Labs M3-L1 – M3-L2)](#module-3-audit-logs-and-incident-response)
8. [Quick Reference: Where to Find Things](#quick-reference-where-to-find-things)
9. [Tips and Common Mistakes](#tips-and-common-mistakes)
10. [Lab Completion Checklist](#lab-completion-checklist)

---

## Before You Begin

### What You Need

- Your **Pod number** (your instructor will assign this, e.g., Pod01, Pod05, Pod12)
- Your **Guacamole login credentials** (your instructor will provide your username and password)
- A computer with a web browser (Chrome, Firefox, or Edge) — no special software needed

### What You Will Be Doing

These labs are **document- and log-analysis labs**. There is no firewall to configure and no Active Directory to edit. You will read the seeded records in your artifacts folder, correlate them against each other (a badge swipe with a roster, a visitor sign-in with a camera observation, an alarm with a badge event), and then write your findings and required actions into the response CSV for each lab.

Everything you are graded on is **what you type into the response CSV**, so be precise with IDs and spelling.

### CMMC Context

These labs align with **CMMC Level 1 Physical Protection (PE)** requirements:
- **PE.L1-3.10.1** — Limit physical access to organizational information systems, equipment, and the respective operating environments to authorized individuals
- **PE.L1-3.10.3** — Escort visitors and monitor visitor activity
- **PE.L1-3.10.4** — Maintain audit logs of physical access
- **PE.L1-3.10.5** — Control and manage physical access devices

They also reference **ACS-POL-PE-002**, the visitor escort policy included in your artifacts.

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
   - Pod 05 → `student05`
   - Pod 12 → `student12`
   - *(and so on — the number matches your assigned pod)*
2. Enter your **Password** (provided by your instructor)
3. Click **Login**

### Step 3: Connect to the Domain Controller

| Connection Name | What It Is |
|---|---|
| **PODXX-DC** | Domain Controller — **use this for all PE labs** |

This is the only connection you get: every PE lab is done on this desktop.

1. Click on **PODXX-DC** (where XX is your pod number, e.g., **POD03-DC**)
2. The remote desktop session opens directly in your browser — no extra login is needed
3. Wait a few seconds for the Windows Server desktop to appear

> **Tip:** Press **Ctrl+Alt+Shift** to open the Guacamole side menu (to return Home or switch connections).

### Step 4: Check Your Lab Progress

**Option 1:** Click the "Check Your Progress — Pod XX" banner at the top of the Guacamole interface.

**Option 2:** Go directly to **https://training.status.tcecure.com/pod/XX** (replace XX with your pod number).

---

## How to Open Your Lab Artifacts

1. Open **File Explorer** on the server desktop (folder icon on the taskbar, or **Windows + E**)
2. Navigate to: **C:\CyberLab\PodXX\PE-Artifacts\\** (e.g., `C:\CyberLab\Pod03\PE-Artifacts\`)

**Alternative method using PowerShell:**
1. Press **Windows key + R**, type `powershell`, press Enter
2. Run: `explorer "C:\CyberLab\Pod03\PE-Artifacts"` (replace `03` with your pod number)

### What You Will See

Files are named by lab, so everything for a lab is grouped together:

| Naming pattern | What it is |
|---|---|
| `PE-Lab-Instructions.txt` | Short summary of all six labs |
| `PE-M1-L1_*`, `PE-M1-L2_*`, … | Evidence and answer files for that lab |
| `_LAB_READY_PE-M1-L1.txt` | Marker confirming the lab was seeded |

Each lab has exactly **one answer file** you fill in (the "response CSV"):

| Lab | Answer file |
|---|---|
| M1-L1 | `PE-M1-L1_AccessReview.csv` |
| M1-L2 | `PE-M1-L2_AccessDecision.csv` |
| M2-L1 | `PE-M2-L1_EscortReview.csv` |
| M2-L2 | `PE-M2-L2_VisitorLog.csv` |
| M3-L1 | `PE-M3-L1_DiscrepancyReview.csv` |
| M3-L2 | `PE-M3-L2_BadgeInventory.csv` **and** `PE-M3-L2_IncidentReport.csv` |

> **Important:** Preserve the original evidence files. Fill in the answer files in place — do not rename them, do not change the header row, and do not delete the `_LAB_READY_` markers.

### Editing the CSV Files

Either:
- Right-click → *Open with* → **Notepad**, and type your values between the commas, or
- Open with **Excel**, fill in the cells, then **Save as CSV** (same file name, same `.csv` type)

If a value you type contains a comma, wrap it in double quotes: `"Disable badge, remove access list entry"`.

---

## Understanding Your Pod

Everything in your pod is prefixed with your pod number. If you are **Pod 03**, your prefix is **P03**:

- Artifacts folder: `C:\CyberLab\Pod03\PE-Artifacts\`
- Employee badges: `B-P03-101`, `B-P03-102`, `B-P03-104`, `B-P03-115`, …
- Temporary visitor badges: `TEMP-P03-011` … `TEMP-P03-014`
- Replacement badge stock: `B-P03-215`

Employee IDs (`EMP-101`, `CTR-209`), event IDs (`E-1001`, `BC-5003`, `ALM-9007`, `EVT-6112`) and visitor IDs (`V-3002`) are the **same in every pod** — only badge IDs carry your prefix.

### The People in Your Scenario

| ID | Name | Role |
|---|---|---|
| EMP-101 | Alex Chen | IT — approved for unescorted server-room access |
| EMP-102 | Jordan Lee | Facilities — approved for unescorted server-room access, common escort |
| EMP-103 | Priya Shah | Contracts |
| EMP-104 | Taylor Reed | Finance — **terminated 2026-05-28** |
| CTR-209 | Morgan Blake | Vendor contractor — no approval on file |
| EMP-115 | Dana Brooks | Employee who reported a lost badge |

Throughout this guide, replace **XX** with your pod number and **PXX** with your pod prefix.

---

## Module 1: Physical Access Authorization

### Lab M1-L1: Physical Access Review

**Difficulty:** Beginner | **Time:** 20 minutes | **Type:** Document analysis

#### Scenario
ACS Consulting must review who holds physical access to the facility and to the server room. HR and Facilities keep separate lists, and they have drifted apart. Find the people who still hold access they should not have.

#### What You Need
- `PE-M1-L1_EmployeeRoster.csv` — employment status and termination dates
- `PE-M1-L1_BadgeRoster.csv` — which badges are active
- `PE-M1-L1_ServerRoomAccessList.csv` — who is approved for the server room, and by whom
- Answer file: `PE-M1-L1_AccessReview.csv`

#### Steps

1. **Open all three evidence files** side by side (Excel makes comparison easier)

2. **Compare the employee roster to the badge roster:**
   - Taylor Reed (`EMP-104`) is **Terminated** with a termination date of `2026-05-28`
   - Yet badge `B-PXX-104` is still **Active** and still on the server-room access list — that access should have been removed at termination

3. **Check the approval column on the server-room access list:**
   - Morgan Blake (`CTR-209`) has **Unescorted** server-room access with **no approval on file**
   - Physical access to a restricted area must be approved by an authorized approver; unapproved access is unauthorized regardless of whether the badge works

4. **Fill in `PE-M1-L1_AccessReview.csv`.** Both rows are already created for you:

   | SubjectId | Finding | RequiredAction |
   |---|---|---|
   | `EMP-104` | `Unauthorized` | Must include **disable**, **remove** or **revoke** — e.g. `Disable badge B-PXX-104 and remove from server room access list` |
   | `CTR-209` | `Unauthorized` | Must include **remove**, **revoke** or **escort** — e.g. `Remove unescorted access; require escorted access until approval is documented` |

   The `Finding` column must be exactly `Unauthorized` for both rows.

#### Completion Criteria
- [ ] Both `EMP-104` and `CTR-209` have `Finding` = `Unauthorized`
- [ ] `EMP-104`'s action calls for badge disablement / access removal
- [ ] `CTR-209`'s action calls for access removal, revocation, or escorted access
- [ ] All three evidence files are still present

#### Why This Matters
PE.L1-3.10.1 requires that physical access be limited to **authorized** individuals. A terminated employee with a working badge and an unapproved contractor are the two most common findings in a real assessment.

---

### Lab M1-L2: Server Room Access Decisions

**Difficulty:** Beginner | **Time:** 25 minutes | **Type:** Log correlation

#### Scenario
Four people badged into the server room over two days. Using the same rosters and approval list, decide whether each entry was authorized.

#### What You Need
- `PE-M1-L2_BadgeLog.csv` — badge events `E-1001` … `E-1004`
- `PE-M1-L2_ServerRoomLog.csv` — the stated purpose of each visit and whether an escort was recorded
- `PE-M1-L2_EmployeeRoster.csv` and `PE-M1-L2_ServerRoomAccessList.csv`
- Answer file: `PE-M1-L2_AccessDecision.csv`

#### Steps

1. **Work event by event.** For each event ID, ask three questions:
   - Was the person employed and active on that date?
   - Are they on the server-room access list with approval?
   - Was an escort required, and was one present?

2. **Analyze the events:**

   | Event | Person | Analysis |
   |---|---|---|
   | `E-1001` | Alex Chen (`EMP-101`) | Active employee, approved unescorted, legitimate purpose → **authorized** |
   | `E-1002` | Taylor Reed (`EMP-104`) | **Terminated 2026-05-28**, badged in on 2026-06-03 → **unauthorized** |
   | `E-1003` | Jordan Lee (`EMP-102`) | Active employee, approved unescorted, UPS inspection → **authorized** |
   | `E-1004` | Morgan Blake (`CTR-209`) | Contractor with **no approval on file** and no escort recorded → **unauthorized** |

3. **Fill in `PE-M1-L2_AccessDecision.csv`.** All four rows exist already:

   | Column | What to enter |
   |---|---|
   | `Authorized` | `Yes` for `E-1001` and `E-1003`; `No` for `E-1002` and `E-1004` |
   | `Reason` | A specific reason for **every** row — name the record that supports it |

   Examples:

   ```
   E-1001,Yes,Active IT employee approved for unescorted server room access
   E-1002,No,Badge used 2026-06-03 after termination on 2026-05-28
   E-1003,Yes,Active facilities employee approved for unescorted access
   E-1004,No,Contractor has no approval on file and no escort was recorded
   ```

#### Completion Criteria
- [ ] `E-1001` and `E-1003` are marked authorized (`Yes`)
- [ ] `E-1002` and `E-1004` are marked unauthorized (`No`)
- [ ] Every row has a non-empty `Reason`
- [ ] Badge log, server-room log and rosters are still present

#### Why This Matters
Access logs only satisfy PE.L1-3.10.4 if someone actually reviews them. Correlating a badge swipe against employment status and approvals is that review.

---

## Module 2: Visitor Escort and Temporary Badges

### Lab M2-L1: Unescorted Visitor Investigation

**Difficulty:** Intermediate | **Time:** 25 minutes | **Type:** Multi-source investigation

#### Scenario
An HVAC repair vendor visited the facility. Security later reviewed the camera footage and something looks wrong. Determine which visitor entered a restricted area without an escort and what must happen next.

#### What You Need
- `PE-M2-L1_VisitorLog.csv` — visitors `V-3001` … `V-3003` with escort assignments
- `PE-M2-L1_RepairTicket.txt` — the approved work window and required escort
- `PE-M2-L1_CameraObservation.txt` — camera SR-02 observations
- `PE-M2-L1_EscortPolicy.txt` — ACS-POL-PE-002
- Answer file: `PE-M2-L1_EscortReview.csv`

#### Steps

1. **Read the escort policy first.** Visitors must sign in, display a temporary badge, and remain under **continuous escort** in restricted areas; unescorted visitor activity must be reported and documented.

2. **Read the repair ticket:** ticket `FAC-PXX-4421` for Cooling Repair technician Kevin Ross, approved window `2026-06-05 11:00–12:30`, **required escort: EMP-102 Jordan Lee**.

3. **Check the visitor log:**
   - `V-3001` Sam Ortega — escort `EMP-101` recorded
   - `V-3002` Kevin Ross — **EscortId is blank**, badge `TEMP-PXX-012`, in 11:05, out 12:20
   - `V-3003` Renee Park — escort `EMP-102` recorded

4. **Corroborate with the camera observation:** at 11:18 and 11:44 the visitor wearing `TEMP-PXX-012` is in the server-room corridor **alone**, with no escort visible. That badge belongs to `V-3002`.

5. **Fill in `PE-M2-L1_EscortReview.csv`** (row `V-3002` already exists):

   | Column | What to enter |
   |---|---|
   | `Finding` | Must state the visitor was **unescorted** / entered **without escort** — e.g. `Entered the restricted server room corridor unescorted` |
   | `RequiredAction` | Must include **report**, **incident**, **remove** or **escort** — e.g. `Report as a physical security incident and require escorted access for future vendor visits` |
   | `Evidence` | At least 15 characters citing the seeded records — e.g. `Visitor log V-3002 has no EscortId; camera SR-02 shows TEMP-PXX-012 alone at 11:18 and 11:44` |

#### Completion Criteria
- [ ] `V-3002` is identified as unescorted
- [ ] A corrective action is documented (report/incident/removal/escort requirement)
- [ ] `Evidence` cites the specific records (visitor log and camera observation)
- [ ] All four evidence files are still present

#### Why This Matters
PE.L1-3.10.3 requires escorting visitors **and** monitoring their activity. The camera note is what turns a blank field in a log into a documented finding.

---

### Lab M2-L2: Temporary Badge Lifecycle

**Difficulty:** Beginner | **Time:** 20 minutes | **Type:** Records completion

#### Scenario
Casey Morgan of Power Systems is arriving to inspect the UPS batteries. You are the badge officer. Run the full temporary-badge lifecycle: issue the badge, assign an escort, record sign-in and sign-out, and confirm the badge came back.

#### What You Need
- `PE-M2-L2_TemporaryBadgeInventory.csv` — temporary badge stock `TEMP-PXX-011` … `TEMP-PXX-014`
- Answer file: `PE-M2-L2_VisitorLog.csv`

#### Steps

1. **Open `PE-M2-L2_TemporaryBadgeInventory.csv`** and note which badges are available. The visitor log is pre-populated with badge `TEMP-PXX-014` — leave that value in place.

2. **Open `PE-M2-L2_VisitorLog.csv`** and complete the row for Casey Morgan:

   | Column | What to enter |
   |---|---|
   | `TemporaryBadgeId` | Leave as `TEMP-PXX-014` |
   | `EscortId` | `EMP-102` (Jordan Lee — Facilities, appropriate for a UPS inspection) |
   | `SignIn` | A date/time, e.g. `2026-06-08 09:15` |
   | `SignOut` | A date/time **after** sign-in, e.g. `2026-06-08 10:40` |
   | `BadgeReturned` | `Yes` |

3. **Keep the inventory consistent (good practice):** update `TEMP-PXX-014` in the badge inventory to show it was issued to Casey Morgan and returned, with matching times. The inventory must still exist for the lab to pass.

4. **Sanity-check your times:** sign-out must be later than sign-in, and both must parse as real date/times (`YYYY-MM-DD HH:MM` is safest).

#### Completion Criteria
- [ ] `TemporaryBadgeId` is `TEMP-PXX-014`
- [ ] `EscortId` is `EMP-102`
- [ ] `SignIn` and `SignOut` are valid times, with sign-out after sign-in
- [ ] `BadgeReturned` is `Yes`
- [ ] `PE-M2-L2_TemporaryBadgeInventory.csv` is still present

#### Why This Matters
PE.L1-3.10.5 requires you to control and manage physical access devices. An unreturned temporary badge is an uncontrolled key to your facility.

---

## Module 3: Audit Logs and Incident Response

### Lab M3-L1: Reconcile the Physical Access Logs

**Difficulty:** Intermediate | **Time:** 30 minutes | **Type:** Log reconciliation

#### Scenario
It is the monthly physical access log review. You have the badge controller export, the visitor sign-in sheet, and the alarm log for 2026-06-06. Two things in these records do not reconcile. Find and document both.

#### What You Need
- `PE-M3-L1_BadgeControllerExport.csv` — events `BC-5001` … `BC-5004`
- `PE-M3-L1_VisitorSignInSheet.csv` — Casey Morgan's visit
- `PE-M3-L1_AlarmLog.csv` — alarms `ALM-9006`, `ALM-9007`
- Answer file: `PE-M3-L1_DiscrepancyReview.csv`

#### Steps

1. **Build a timeline** from the badge export and the sign-in sheet:
   - Visitor sign-in sheet: Casey Morgan in **15:50**, out **16:10**, badge `TEMP-PXX-014` **returned = Yes**
   - `BC-5001` 15:55 Main Lobby — consistent with the visit
   - `BC-5002` 16:18 Server Room — already after sign-out, and in a restricted area
   - `BC-5003` **18:42 Server Room** — hours after the visitor signed out and returned the badge
   - `BC-5004` 21:58 Server Room, employee badge `B-PXX-101`

2. **Discrepancy 1 (`D-01`, source event `BC-5003`):** a temporary visitor badge that was recorded as returned was used to enter the server room at 18:42. Either the badge was not actually returned or it was cloned/misused — it must be contained and investigated.

3. **Check the alarm log:**
   - `ALM-9006` 17:02 Loading Dock, door held open — **resolved** by security, so it reconciles
   - `ALM-9007` 22:14 Server Room, **forced door**, resolution states **no corresponding badge event** — someone entered without presenting a credential

4. **Discrepancy 2 (`D-02`, source event `ALM-9007`):** a forced-door alarm on the server room with no matching badge event.

5. **Fill in `PE-M3-L1_DiscrepancyReview.csv`** (both rows already exist with the `SourceEvent` values filled in):

   | DiscrepancyId | Finding must state | RequiredAction must include |
   |---|---|---|
   | `D-01` (`BC-5003`) | that the badge was used **after** sign-out / **after** it was **returned** (mentioning the 18:42 time is a good way to be explicit) | **disable**, **investigate** or **revoke** |
   | `D-02` (`ALM-9007`) | a **forced** door with **no badge** / an **unmatched** event | **investigate**, **incident** or **review** |

   Examples:

   ```
   D-01,BC-5003,Temporary badge TEMP-PXX-014 was used at the server room at 18:42 after it was returned at 16:10,Disable the badge and investigate how it was used after return
   D-02,ALM-9007,Forced door alarm at the server room with no badge event to match it,Investigate as a physical security incident and review camera footage
   ```

   Do not change the `SourceEvent` values.

#### Completion Criteria
- [ ] `D-01` identifies badge use after sign-out/return and calls for disablement or investigation
- [ ] `D-02` identifies the forced door with no matching badge event and calls for investigation/incident handling
- [ ] `SourceEvent` values remain `BC-5003` and `ALM-9007`
- [ ] All three evidence files are still present

#### Why This Matters
PE.L1-3.10.4 requires audit logs of physical access — but logs are only useful if reconciled. Correlating badge, visitor, and alarm data is how real physical intrusions get caught.

---

### Lab M3-L2: Lost Badge Incident Response

**Difficulty:** Intermediate | **Time:** 30 minutes | **Type:** Incident response

#### Scenario
Dana Brooks reported her badge lost at 10:00 on 2026-06-07. Later that day her badge was used — including at the server room. You are the responder: contain the lost badge, issue a replacement, and write the incident report.

#### What You Need
- `PE-M3-L2_LostBadgeReport.txt` — the initial report (`LBR-PXX-115`)
- `PE-M3-L2_AccessEventsAfterLoss.csv` — events `EVT-6111`, `EVT-6112`
- Answer files: `PE-M3-L2_BadgeInventory.csv` **and** `PE-M3-L2_IncidentReport.csv`

#### Steps

1. **Read the lost badge report:** badge `B-PXX-115`, employee Dana Brooks (`EMP-115`), reported lost `2026-06-07 10:00` to Security Operations.

2. **Review the post-loss access events:**
   - `EVT-6111` 09:42 Main Lobby — **before** the badge was reported lost
   - `EVT-6112` **11:12 Server Room** — **after** the loss report, and in a restricted area. This is the event your incident report must cite.

3. **Contain and re-issue in `PE-M3-L2_BadgeInventory.csv`:**

   | BadgeId | What to set |
   |---|---|
   | `B-PXX-115` | `Status` → `Disabled` (or `Revoked`) |
   | `B-PXX-215` | `Status` → `Active`, `EmployeeId` → `EMP-115` (name stays Dana Brooks; add an issue date) |

4. **Complete `PE-M3-L2_IncidentReport.csv`** (row `IR-PXX-115` already exists):

   | Column | What to enter |
   |---|---|
   | `LostBadgeId` | Leave as `B-PXX-115` |
   | `PostLossEventId` | `EVT-6112` |
   | `ContainmentAction` | Must include **disable** or **revoke** — e.g. `Disabled badge B-PXX-115 in the badge controller` |
   | `ReplacementBadgeId` | Leave as `B-PXX-215` |
   | `ReportedBy` | Your name |
   | `Summary` | At least 25 characters — what was lost, what happened after, what you did |

   Example summary:

   ```
   Badge B-PXX-115 was reported lost at 10:00 and then used at the server room at 11:12 (EVT-6112); the badge was disabled, replacement B-PXX-215 was issued to EMP-115, and the server room access is under investigation.
   ```

#### Completion Criteria
- [ ] `B-PXX-115` is `Disabled` or `Revoked`
- [ ] `B-PXX-215` is `Active` and assigned to `EMP-115`
- [ ] Incident report cites `EVT-6112` and documents disablement/revocation
- [ ] `ReportedBy` is filled in and `Summary` is a full description
- [ ] Lost badge report and post-loss events file are still present

#### Why This Matters
PE.L1-3.10.5 requires control of physical access devices. A lost badge is a live key until it is disabled — and the access that occurred after the loss must be investigated and documented.

---

## Quick Reference: Where to Find Things

| Task | Where to Go |
|---|---|
| Open the artifacts folder | `C:\CyberLab\PodXX\PE-Artifacts\` |
| Read the lab summary | `PE-Lab-Instructions.txt` |
| Edit a CSV as text | Right-click → *Open with* → **Notepad** |
| Edit a CSV as a spreadsheet | Open with **Excel**, then Save as CSV (same name) |
| Open PowerShell | **Windows + R** → `powershell` |
| Preview a CSV in PowerShell | `Import-Csv "C:\CyberLab\PodXX\PE-Artifacts\PE-M1-L2_BadgeLog.csv" \| Format-Table` |
| Check your lab progress | https://training.status.tcecure.com/pod/XX |

### Key IDs Across the Labs

| ID | Meaning |
|---|---|
| `EMP-104` / `B-PXX-104` | Terminated employee whose badge is still active |
| `CTR-209` | Contractor with no server-room approval on file |
| `E-1002`, `E-1004` | The two unauthorized server-room events |
| `V-3002` | The unescorted visitor (Kevin Ross) |
| `TEMP-PXX-014` | Temporary badge used in M2-L2 and M3-L1 |
| `BC-5003` | Badge event after the visitor badge was returned |
| `ALM-9007` | Forced-door alarm with no matching badge event |
| `B-PXX-115` / `B-PXX-215` | Lost badge / its replacement |
| `EVT-6112` | Post-loss server-room access with the lost badge |

---

## Tips and Common Mistakes

| Mistake | Solution |
|---|---|
| Leaving the `Reason`/`Evidence` column blank | Every finding needs a written justification — blank rows fail |
| One-word evidence | Cite the specific file and value (e.g. `visitor log V-3002 has no EscortId`) |
| Typing findings in the wrong row | Match on the ID column (`SubjectId`, `EventId`, `DiscrepancyId`) — do not reorder rows |
| Changing the header row or column names | Keep the header exactly as seeded |
| Overwriting seeded IDs (`SourceEvent`, `LostBadgeId`) | Leave pre-filled ID columns alone; only fill the blank cells |
| Using "N/A" or "OK" as a finding | Use the expected values: `Authorized`/`Unauthorized`, `Yes`/`No` |
| Sign-out earlier than sign-in | Check your times in M2-L2 |
| Forgetting the second file in M3-L2 | Both the badge inventory **and** the incident report must be completed |
| Saving as `.xlsx` | Save as **CSV** with the original file name |
| Unquoted commas inside a value | Wrap the whole value in double quotes |
| Deleting evidence or `_LAB_READY_` files | The checker requires them to be present |

### Getting Unstuck

- **Excel changed my dates.** Format the cell as text or edit the file in Notepad instead
- **Verification says a file was not found.** You probably renamed or moved the answer file — restore the original name
- **Verification says the wrong value.** Read the failure reason on your progress page; it names the exact row and expectation
- **Artifacts missing or damaged?** Ask your instructor to reseed the PE family for your pod

---

## Lab Completion Checklist

| Lab | Name | Status |
|---|---|---|
| M1-L1 | Physical Access Review | ☐ |
| M1-L2 | Server Room Access Decisions | ☐ |
| M2-L1 | Unescorted Visitor Investigation | ☐ |
| M2-L2 | Temporary Badge Lifecycle | ☐ |
| M3-L1 | Reconcile the Physical Access Logs | ☐ |
| M3-L2 | Lost Badge Incident Response | ☐ |

**After completing each lab:**
1. Confirm your answer CSVs are saved in `C:\CyberLab\PodXX\PE-Artifacts\` with their original names
2. Confirm all seeded evidence files are still present
3. Check your status at https://training.status.tcecure.com/pod/XX

---

*This guide was created for the Digital Resilience Community Clinic (DRCC) Cyber Range.*
*CMMC Level 1 — Physical Protection (PE) Module*

# SI-M5-L1 — CyDeploy Asset Discovery

> **STATUS: STAGED — NOT YET AVAILABLE TO ACTIVE STUDENTS.**
> This lab becomes available when your instructor announces that CyDeploy
> Community Edition has been installed in the lab environment.

---

## Mission

ACS IT Operations maintains a documented asset inventory for your area of
responsibility. An internal auditor found that the inventory has not been
validated against the real environment in over a year.

Your job is to use CyDeploy Community Edition to discover what is actually
operating inside **your assigned pod**, compare it against the documented
inventory, and report any asset that is running but is not documented.

You are not asked to fix anything in this lab. Discovery and documentation only.

---

## Learning Objectives

By the end of this lab you will be able to:

1. Explain why a documented asset inventory must be validated against
   discovered reality, not trusted on its own.
2. Run a scoped discovery against only the systems you are authorized to scan.
3. Compare discovery output against a documented inventory and identify
   additions, omissions, and attribute mismatches.
4. State a defensible finding and support it with evidence a reviewer can check.

CMMC context: asset identification underpins the SI practices — you cannot
protect, patch, or monitor a system that nobody knows exists.

---

## Prerequisites

- You have completed the core SI labs (SI M1 through M4).
- Your instructor has confirmed CyDeploy Community Edition is available.
- You know your pod number and your student credentials.
- You know your pod's network range (`10.51.<your pod number>.0/24`).

---

## Systems Used

| System | Where | What you use it for |
|--------|-------|---------------------|
| `PODXX-DC` (via Guacamole) | Your Guacamole connection list | Reading lab documents and recording your response |
| CyDeploy Community Edition | As installed by your instructor | Discovering assets inside your pod |
| Your pod artifact folder | `C:\CyberLab\PodXX\SI-Artifacts\CyDeploy\` | Lab documents, worksheet, and your response file |

### Scope rules — read before you start

You may discover **only your own pod**.

You may **not** scan:

- another student's pod,
- the shared domain (`acs-p01.local`) or the domain controllers,
- the management network,
- any range broader than your pod, such as `10.50.0.0/16` or `192.168.1.0/24`.

Scanning outside your pod is a lab-integrity violation, and the verifier will
fail your submission if the scope you record is broader than your pod.

---

## Instructions

1. Connect to Guacamole and open your **PODXX-DC** connection.
2. Open `C:\CyberLab\PodXX\SI-Artifacts\CyDeploy\`.
3. Read `PXX_Discovery_Scenario.txt`. This is your tasking from IT Operations.
4. Open `PXX_Expected_Asset_Inventory.csv`. This is what ACS *believes* is in
   your environment. Copy each documented asset into section 1 of
   `PXX_CyDeploy_Discovery_Worksheet.docx`.
5. Launch CyDeploy Community Edition as directed by your instructor.
6. Configure the discovery scope to **your pod only**. Record the exact scope
   you used — you will have to submit it.
7. Run discovery and wait for it to complete.
8. Record every asset CyDeploy reports in section 2 of the worksheet, including
   how it was identified.
9. Complete section 3 of the worksheet: what is documented but not discovered,
   what is discovered but not documented, and what is discovered with different
   attributes than documented.
10. Write your conclusion in section 4. If something is operating in your pod
    that is not on the documented inventory, name it exactly as CyDeploy
    reported it.
11. Recommend the next step in section 5 (what ACS should do, and who decides).
12. Sign the attestation in section 6 confirming your discovery stayed inside
    your pod.
13. Open `StudentResponses\SI-M5-L1.json` in Notepad and fill it in:
    - `analyst` — your student name
    - `discovery_scope` — the scope you actually used (must be your pod)
    - `undocumented_asset_identified` — `"yes"` or `"no"`
    - `finding` — name the undocumented asset and state the problem
    - `evidence` — how you know: what CyDeploy showed and what the inventory
      does not contain
    - `completed` — `true`
14. Save the JSON file. Keep the worksheet saved in the same folder.

---

## Evidence Required

Your submission is complete when all of the following exist in
`C:\CyberLab\PodXX\SI-Artifacts\CyDeploy\`:

| Evidence | File |
|----------|------|
| Completed worksheet | `PXX_CyDeploy_Discovery_Worksheet.docx` |
| Completed response file | `StudentResponses\SI-M5-L1.json` |

Your response file must contain a named finding, a scope limited to your pod,
and evidence that a reviewer can verify against the seeded inventory.

---

## Verify My Lab

Verification is automatic. You do not run anything yourself, and you do not need
access to AWX.

1. Save your worksheet and your `SI-M5-L1.json` response file.
2. The scheduled verifier reads your response file and evidence, and decides
   PASS or FAIL.
3. Check your result on the training tracker:
   **https://training.status.tcecure.com/pod/XX** (use your pod number), or the
   "Check Your Progress" banner in Guacamole.
4. If the lab still shows incomplete, read the reason shown for the lab — it
   tells you exactly what is missing — fix it, save, and wait for the next
   verification run.

---

## Troubleshooting

**The CyDeploy folder is empty or missing.**
The lab has not been seeded for your pod yet. Tell your instructor; do not create
the files yourself.

**CyDeploy will not start.**
Confirm with your instructor that it has been installed on the system you are
using. Do not download or install it yourself.

**Discovery returns nothing.**
Check that the scope you entered matches your pod's network
(`10.51.<pod number>.0/24`) and that you used your pod, not another.

**Discovery seems to return systems from outside my pod.**
Stop, do not record them, and tell your instructor immediately. Then re-run with
a scope limited to your pod.

**I cannot edit the JSON file.**
Open it with Notepad. Keep the quotation marks and commas exactly as they are —
if the file is not valid JSON, verification fails with "is not valid JSON".

**The tracker says my scope is outside my assigned pod.**
The `discovery_scope` value you recorded is broader than your pod. Correct it to
your pod only, and re-run discovery if your actual scan was too broad.

**Nothing changed after I saved.**
Verification runs on a schedule, not instantly. Wait for the next run before
assuming something is wrong.

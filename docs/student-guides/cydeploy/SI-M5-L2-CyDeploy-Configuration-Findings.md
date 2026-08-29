# SI-M5-L2 — CyDeploy Configuration & Security Findings

> **STATUS: STAGED — NOT YET AVAILABLE TO ACTIVE STUDENTS.**
> This lab becomes available when your instructor announces that CyDeploy
> Community Edition has been installed in the lab environment.

---

## Mission

A tool tells you what it sees. It does not know your organization's policy.

CyDeploy has reported a set of conditions in your pod. Some of them are real
problems. Some of them are exactly what ACS expects. One of them is a deviation
that ACS has already formally approved. At least one cannot be judged without
more information.

Your job is to turn raw output into **findings** — decisions supported by the ACS
baseline, the approved software list, and the exception register.

You are not asked to remediate anything in this lab. Analysis only.

---

## Learning Objectives

By the end of this lab you will be able to:

1. Distinguish a tool observation from a security finding.
2. Evaluate an observed condition against a written configuration baseline.
3. Recognize when a deviation is a formally approved exception rather than a
   finding.
4. Recognize when you do not have enough information to decide, and say so
   instead of guessing.
5. Justify every classification with a reference a reviewer can check.

---

## Prerequisites

- You have completed SI-M5-L1.
- Your instructor has confirmed CyDeploy Community Edition is available.
- You know your pod number and your student credentials.

---

## Systems Used

| System | Where | What you use it for |
|--------|-------|---------------------|
| `PODXX-DC` (via Guacamole) | Your Guacamole connection list | Reading reference documents and recording your response |
| CyDeploy Community Edition | As installed by your instructor | Configuration/discovery review of your pod |
| Your pod artifact folder | `C:\CyberLab\PodXX\SI-Artifacts\CyDeploy\` | Reference documents, worksheet, and your response file |

### Scope rules

Review **your own pod only**. Do not review another pod, the shared domain, the
domain controllers, or the management network.

---

## Instructions

1. Connect to Guacamole and open your **PODXX-DC** connection.
2. Open `C:\CyberLab\PodXX\SI-Artifacts\CyDeploy\`.
3. Read `PXX_Observed_Conditions.txt`. It lists the observations `OBS-01`
   through `OBS-05` you must classify.
4. Read the three reference documents before you classify anything:
   - `PXX_Configuration_Baseline.pdf` — what ACS requires
   - `PXX_Approved_Software_List.csv` — what ACS has approved
   - `PXX_Exception_Register.csv` — what ACS has formally excepted
5. Run the CyDeploy configuration/discovery review for your pod as directed by
   your instructor, and confirm the observations against what the tool reports.
6. Open `PXX_CyDeploy_Findings_Worksheet.docx`. For every observation, record:
   - the classification: `Finding`, `Expected`, `Approved Exception`, or
     `Needs Investigation`
   - which reference document you used
   - your justification
7. For each observation you classify as a **Finding**, complete the remediation
   priority table: the risk, the recommended remediation, and the priority.
8. For each observation you classify as **Needs Investigation**, complete the
   information request table: exactly what you need and who you would ask.
9. Sign the attestation.
10. Open `StudentResponses\SI-M5-L2.json` in Notepad. For each of the five
    entries, fill in `classification` and `justification`. Then set `analyst`
    and `completed` to `true`.
11. Save the JSON file. Keep the worksheet saved in the same folder.

### How to decide

Ask, in this order:

1. Does the baseline require this? → `Expected`
2. Does the baseline prohibit this? → is there a **current** exception for it?
   - Yes → `Approved Exception`
   - No → `Finding`
3. Can I not tell, because ownership, publisher, or purpose is unknown? →
   `Needs Investigation`

An exception that is not written down does not exist. An expired exception is not
an exception.

---

## Evidence Required

| Evidence | File |
|----------|------|
| Completed worksheet | `PXX_CyDeploy_Findings_Worksheet.docx` |
| Completed response file | `StudentResponses\SI-M5-L2.json` |

Every one of the five observations must have a classification **and** a
justification. A classification with no justification is not evidence and will
fail verification.

---

## Verify My Lab

Verification is automatic. You do not run anything yourself, and you do not need
access to AWX.

1. Save your worksheet and your `SI-M5-L2.json` response file.
2. The scheduled verifier reads your response file and evidence, and decides
   PASS or FAIL.
3. Check your result on the training tracker:
   **https://training.status.tcecure.com/pod/XX**, or the "Check Your Progress"
   banner in Guacamole.
4. If a classification is wrong, the tracker tells you which observation ID is
   incorrect — but not the answer. Re-read the baseline and the exception
   register for that item.

---

## Troubleshooting

**A reference document is missing.**
The lab has not been fully seeded for your pod. Tell your instructor; do not
create the files yourself.

**The exception register looks like it excuses everything.**
Read it carefully: check the item, the approval, and the expiry date. It applies
to one specific item.

**I think an observation is both a finding and an exception.**
It can only be one. If a current, approved exception covers exactly that item,
it is an approved exception.

**The tracker says an observation is classified incorrectly.**
Your classification does not match the baseline. Re-read the relevant baseline
section for that observation and reconsider.

**The tracker says a justification is required.**
Your justification is missing or too short to be meaningful. State which
reference you used and why it supports your classification.

**I cannot edit the JSON file.**
Open it with Notepad, and keep the structure valid — quotation marks, commas,
and brackets must stay as they are.

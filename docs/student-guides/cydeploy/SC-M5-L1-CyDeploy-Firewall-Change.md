# SC-M5-L1 — Dependency-Aware Firewall Change

> **STATUS: STAGED — NOT YET AVAILABLE TO ACTIVE STUDENTS.**
> This lab becomes available when your instructor announces that CyDeploy
> Community Edition has been installed in the lab environment.

---

## Mission

Your pod gateway contains a rule that lets the pod LAN reach anything, anywhere.
ACS Network Security has approved a change to replace it with rules that permit
only the communication the environment actually needs, ending in an explicit
default deny.

The trap is obvious once you have done it in production: tighten a firewall
without knowing what depends on it and you break authentication, name
resolution, and policy delivery for everyone behind it.

Your job is to let discovered system and dependency information drive the network
change — then prove the required communication still works afterwards.

---

## Learning Objectives

By the end of this lab you will be able to:

1. Use discovered system information to identify what a network change would
   affect before making it.
2. Separate business-required communication from convenience or unrestricted
   access.
3. Replace an overly permissive rule with least-privilege rules and an explicit
   default deny.
4. Validate connectivity after a firewall change and record a defensible
   determination.

---

## Prerequisites

- You have completed the core SC labs (SC M1 through M4) — you already know how
  to log in to your pod gateway and edit firewall rules.
- You have completed SI-M5-L1 (scoped CyDeploy discovery).
- Your instructor has confirmed CyDeploy Community Edition is available.
- You know your pod number and your student credentials.

---

## Systems Used

| System | Where | What you use it for |
|--------|-------|---------------------|
| `PODXX-DC` (via Guacamole) | Your Guacamole connection list | Reading lab documents and recording your response |
| `PXX-GW` (pfSense) | `10.51.<pod number>.1` | Applying the approved firewall change |
| CyDeploy Community Edition | As installed by your instructor | Discovering systems and dependencies in your pod |
| Your pod artifact folder | `C:\CyberLab\PodXX\SC-Artifacts\CyDeploy\` | Change request, matrix, worksheets, and your response file |

### Scope rules

Work on **your pod and your pod gateway only**. Never touch another pod's
gateway, the shared domain controllers, or the management network. Discovery must
be scoped to your pod.

---

## Instructions

1. Connect to Guacamole and open your **PODXX-DC** connection.
2. Open `C:\CyberLab\PodXX\SC-Artifacts\CyDeploy\`.
3. Read `PXX_Firewall_Scenario.txt` and `PXX_Firewall_Change_Request.docx`. Note
   the change ID and the name of the permissive rule.
4. Open `PXX_Required_Communication_Matrix.csv`. Every path is listed with a
   stated purpose and whether it is business required.
5. Run CyDeploy discovery for **your pod** and identify which systems and
   applications are operating and what communication they appear to depend on.
6. Complete `PXX_Dependency_Worksheet.docx`:
   - what discovery told you (section 1)
   - a keep-or-remove decision with justification for every path (section 2)
   - the predicted symptom if you removed a required path in error (section 3)
   - the rule set you intend to apply, in order, ending with the default deny
     (section 4)
   - the attestation (section 5)
7. Log in to your pod gateway (`PXX-GW`) as you did in the core SC labs.
8. Apply the approved change:
   - remove the permissive rule named in the change request,
   - permit only the paths you determined are required,
   - end the rule set with an explicit default deny,
   - check rule order — a rule below a deny never matches.
9. Validate connectivity from your pod after the change: domain logon, name
   resolution, and policy delivery must still work. Also confirm that a path you
   removed is in fact blocked.
10. Complete `PXX_Change_Validation_Report.docx` with the rules you changed, your
    path-by-path test results, the service impact checks, and your PASS/FAIL
    determination.
11. Open `StudentResponses\SC-M5-L1.json` in Notepad and fill in:
    - `analyst` — your student name
    - `overly_broad_rule` — the rule you removed
    - `required_paths` — the `PathId` values you kept, e.g. `["PATH-01", ...]`
    - `unnecessary_paths` — the `PathId` values you removed
    - `dependency_source` — how you determined the dependencies
    - `change_applied` — `"yes"` once the change is on the gateway
    - `connectivity_validated` — `"yes"` once you have re-tested
    - `determination` — `PASS` or `FAIL`
    - `evidence` — what your tests showed
    - `completed` — `true`
12. Save the JSON file. Keep both worksheets saved in the same folder.

> If you lock yourself out of your own pod, that is a finding about your change
> — record what happened, restore the previous rule set from the gateway
> configuration history, and work out which dependency you missed.

---

## Evidence Required

| Evidence | File |
|----------|------|
| Completed dependency worksheet | `PXX_Dependency_Worksheet.docx` |
| Completed validation report | `PXX_Change_Validation_Report.docx` |
| Completed response file | `StudentResponses\SC-M5-L1.json` |
| Gateway rule set | The applied change on `PXX-GW` |

---

## Verify My Lab

Verification is automatic. You do not run anything yourself, and you do not need
access to AWX.

1. Save both worksheets and your `SC-M5-L1.json` response file, and leave your
   change in place on the gateway.
2. The scheduled verifier reads your response file and evidence — and, once your
   instructor has enabled it, the gateway rule state — and decides PASS or FAIL.
3. Check your result on the training tracker:
   **https://training.status.tcecure.com/pod/XX**, or the "Check Your Progress"
   banner in Guacamole.
4. If the lab shows incomplete, the reason names what is missing: a path
   classified incorrectly, missing validation, or the permissive rule still being
   present.

---

## Troubleshooting

**I lost connectivity to my pod after applying the change.**
Restore the previous rule set from the gateway configuration history, then
re-check your dependency worksheet: you removed something the pod needs. Note
this in your validation report — it is part of the lesson, not a failure to hide.

**Logon or Group Policy stopped working, but name resolution is fine.**
Compare your applied rules against the required communication matrix path by
path. Authentication and policy delivery each need their own path.

**A path I removed still seems to work.**
Check rule order. A pass rule above your deny still matches first.

**The permissive rule is not present on my gateway.**
Tell your instructor — the gateway condition for this lab has not been staged for
your pod. Do not create the rule yourself.

**The tracker says the permissive rule is still present.**
The rule is still in your gateway configuration. Remove it (do not just disable a
copy) and re-check the rule list.

**The tracker says a path must be retained / must be removed.**
Your classification of that path does not match the business requirement in the
matrix. Re-read the purpose column for that path.

**I cannot edit the JSON file.**
Open it with Notepad. `required_paths` and `unnecessary_paths` are lists — keep
the square brackets and quote each `PathId`.

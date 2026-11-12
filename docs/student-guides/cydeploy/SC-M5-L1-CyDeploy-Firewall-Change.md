# SC-M5-L1 — Dependency-Aware Firewall Change

> **STATUS: STAGED — NOT YET AVAILABLE TO ACTIVE STUDENTS.**
> This lab becomes available when your instructor announces that CyDeploy
> Community Edition has been installed in the lab environment.

---

## Mission

The host firewall on your pod server contains a rule that accepts inbound traffic
on any port from any address. ACS Network Security has approved a change to
replace it with rules that permit only the communication the server actually
needs.

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
3. Replace an overly permissive rule with least-privilege rules scoped to
   specific remote addresses and ports.
4. Validate connectivity after a firewall change and record a defensible
   determination.

---

## Prerequisites

- You have completed the core SC labs (SC M1 through M4) — you already know how
  firewall rule sets are read and ordered.
- You have completed SI-M5-L1 (scoped CyDeploy discovery).
- Your instructor has confirmed CyDeploy Community Edition is available.
- You know your pod number and your student credentials.

---

## Systems Used

| System | Where | What you use it for |
|--------|-------|---------------------|
| `PODXX-SRV` (via Guacamole) | Your Guacamole connection list | Reading lab documents, applying the firewall change, recording your response |
| CyDeploy Community Edition | As installed by your instructor | Discovering systems and dependencies in your pod |
| Your pod artifact folder | `C:\CyberLab\PodXX\SC-Artifacts\CyDeploy\` | Change request, matrix, worksheets, and your response file |

### Scope rules

Work on the **local firewall of your own `PODXX-SRV` only**. Never change the pod
gateway, another pod, the shared domain controllers, the campus firewall, or the
management network. Discovery must be scoped to your pod.

---

## Instructions

1. Connect to Guacamole and open your **PODXX-SRV** connection.
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
   - the replacement rules you intend to apply, with the remote address and port
     each one permits (section 4) — anything you do not permit is blocked by the
     firewall's default inbound action, so no deny rule is needed
   - the attestation (section 5)
7. Open **Windows Defender Firewall with Advanced Security** on `PODXX-SRV`
   (`wf.msc`), or use PowerShell (`Get-NetFirewallRule`,
   `New-NetFirewallRule`, `Remove-NetFirewallRule`).
8. Apply the approved change on this server only:
   - remove or disable the permissive rule named in the change request,
   - create replacement rules named `PXX-CYDEPLOY-<purpose>` that permit only the
     paths you determined are required,
   - give every replacement rule a specific remote address and a specific local
     port — never `Any`.
9. Validate connectivity after the change: your own remote desktop session,
   domain logon, name resolution and the grading channel must still work. Also
   confirm that a path you removed is in fact blocked.
10. Complete `PXX_Change_Validation_Report.docx` with the rules you changed, your
    path-by-path test results, the service impact checks, and your PASS/FAIL
    determination.
11. Open `StudentResponses\SC-M5-L1.json` in Notepad and fill in:
    - `analyst` — your student name
    - `overly_broad_rule` — the rule you removed
    - `required_paths` — the `PathId` values you kept, e.g. `["PATH-01", ...]`
    - `unnecessary_paths` — the `PathId` values you removed
    - `dependency_source` — how you determined the dependencies
    - `change_applied` — `"yes"` once the change is on this server
    - `connectivity_validated` — `"yes"` once you have re-tested
    - `determination` — `PASS` or `FAIL`
    - `evidence` — what your tests showed
    - `completed` — `true`
12. Save the JSON file. Keep both worksheets saved in the same folder.

> If you lock yourself out of your own pod, that is a finding about your change —
> record what happened, tell your instructor (the lab can be reset), and work out
> which dependency you missed. Keep the inbound Remote Desktop rule and the WinRM
> path (TCP 5985) permitted, or you lose both your session and your grading.

---

## Evidence Required

| Evidence | File |
|----------|------|
| Completed dependency worksheet | `PXX_Dependency_Worksheet.docx` |
| Completed validation report | `PXX_Change_Validation_Report.docx` |
| Completed response file | `StudentResponses\SC-M5-L1.json` |
| Firewall rule set | The applied change in the `PODXX-SRV` host firewall |

---

## Verify My Lab

Verification is automatic. You do not run anything yourself, and you do not need
access to AWX.

1. Save both worksheets and your `SC-M5-L1.json` response file, and leave your
   change in place on the server.
2. The scheduled verifier reads your response file, your evidence, and the actual
   host firewall rules on your server, and decides PASS or FAIL.
3. Check your result on the training tracker:
   **https://training.digitalrcc.com/pod/XX**, or the "Check Your Progress"
   banner in Guacamole.
4. If the lab shows incomplete, the reason names what is missing: a path
   classified incorrectly, missing validation, or the permissive rule still being
   present.

---

## Troubleshooting

**I lost connectivity to my pod after applying the change.**
Tell your instructor — staff can restore access and reset the lab. Then re-check
your dependency worksheet: you removed something the server needs. Note this in
your validation report — it is part of the lesson, not a failure to hide.

**Logon or Group Policy stopped working, but name resolution is fine.**
Compare your applied rules against the required communication matrix path by
path. SMB (445) and the RPC endpoint mapper (135) from the domain controller each
need their own rule.

**A path I removed still seems to work.**
Another enabled allow rule still matches it. List every enabled inbound rule and
look for a broader one you left behind.

**The permissive rule is not present on my server.**
Tell your instructor — this lab has not been seeded for your pod. Do not create
the rule yourself.

**The tracker says the permissive rule is still present.**
The rule is still enabled on your server. Remove it, or disable it — a rule left
enabled under a different name still counts.

**The tracker says a path must be retained / must be removed.**
Your classification of that path does not match the business requirement in the
matrix. Re-read the purpose column for that path.

**I cannot edit the JSON file.**
Open it with Notepad. `required_paths` and `unnecessary_paths` are lists — keep
the square brackets and quote each `PathId`.

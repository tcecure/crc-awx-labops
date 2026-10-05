# SC-M5-L1 — Dependency-Aware Firewall Change (Instructor Guide)

> **STATUS: STAGED.** Do not seed against an active student pod until
> `docs/cydeploy/CYDEPLOY-GO-LIVE.md` is complete.

---

## Seeded condition

Seeded by `playbooks/sc/cydeploy/seed_sc_cydeploy.yml` into
`C:\CyberLab\PodNN\SC-Artifacts\CyDeploy\` on `PODNN-SRV`:

| File | Purpose |
|------|---------|
| `PNN_Firewall_Scenario.txt` | Tasking memo, change ID `CHG-PNN-2026-0552` |
| `PNN_Firewall_Change_Request.docx` | Approved change request |
| `PNN_Required_Communication_Matrix.csv` | `PATH-01`..`PATH-06` with purpose and business-required flag |
| `PNN_Dependency_Worksheet.docx` | Dependency analysis and intended rule set |
| `PNN_Change_Validation_Report.docx` | Post-change validation and determination |
| `StudentResponses\SC-M5-L1.json` | Response template with `change_id` pre-populated |
| `_LAB_READY_SC-M5-L1.txt` | Seed marker |

Family marker: `C:\CyberLab\PodNN\.families\SC-CYDEPLOY.seeded` — separate from
`SC.seeded`.

### The firewall condition is seeded on the pod server

The seed creates one namespaced inbound rule in the **local Windows Defender
Firewall of `PODNN-SRV`**:

```text
PNN-CYDEPLOY-ALLOW-ANY-INBOUND   Allow / Inbound / TCP / LocalPort Any / RemoteAddress Any / Enabled
```

It also writes a CSV of the pre-change inbound rule set alongside the documents,
so staff can see exactly what the server looked like before the student worked.

**No gateway, campus firewall, or shared configuration is touched** — not by the
seed, not by the student, and not by the verifier. The pod gateway rule sets
belong to the live SC family (`seed_sc_gw` / `verify_sc_gw`) and are untouched by
anything under `playbooks/*/cydeploy/`.

---

## Expected finding

Discovery plus the communication matrix show that the server needs only the
analyst's remote desktop path, SMB and RPC from the domain controller
(`10.50.1.10`), and the WinRM grading channel from AWX. The permissive rule grants
far more than that.

## Correct answer

| Response field | Expected |
|----------------|----------|
| `change_id` | `CHG-PNN-2026-0552` |
| `overly_broad_rule` | Names `PNN-CYDEPLOY-ALLOW-ANY-INBOUND` |
| `required_paths` | `PATH-01` (RDP from the pod subnet), `PATH-02` (SMB 445 from `10.50.1.10`), `PATH-03` (WinRM 5985 from AWX), `PATH-04` (RPC 135 from `10.50.1.10`) |
| `unnecessary_paths` | `PATH-05` (RDP from any address), `PATH-06` (any port from any address) |
| `dependency_source` | ≥ 15 characters describing how dependencies were determined |
| `change_applied` | `yes` / `true` |
| `connectivity_validated` | `yes` / `true` |
| `determination` | `PASS` |
| `evidence` | ≥ 25 characters |
| `analyst`, `completed` | Non-empty / true |

The intended failure mode for students who skip the dependency analysis: dropping
`PATH-02` or `PATH-04` breaks Group Policy and evidence delivery while their own
remote desktop session still works — exactly the diagnostic the guide asks them to
predict in advance. Dropping `PATH-03` costs them their grading channel.

---

## Verification logic

`roles/verify_sc_cydeploy/tasks/main.yml`, key `M5-L1`, run from
`playbooks/sc/cydeploy/verify_sc_cydeploy.yml`.

The role runs on the pod server itself and grades both the paperwork and the real
rule set:

1. Requires the seed marker and the four seeded documents, parses the response
   JSON, and applies the table above.
2. Reads the live inbound rules. The lab fails if
   `PNN-CYDEPLOY-ALLOW-ANY-INBOUND` is still enabled, if no enabled replacement
   rule exists in the `PNN-CYDEPLOY-*` namespace, or if a replacement rule still
   permits `Any` remote address or `Any` local port.

So a student cannot pass by filling in the worksheets alone, and cannot pass by
replacing one permissive rule with another.

No gateway is read or written; the authoritative check of pod gateway state
remains `verify_sc_gw`. Tracker publication is gated by
`cydeploy_publish_progress` (default `false`).

---

## Reset behavior

`playbooks/sc/cydeploy/reset_sc_cydeploy.yml -e cydeploy_targets=podNN-srv` removes
`SC-Artifacts\CyDeploy`, the `SC-CYDEPLOY.seeded` marker, and every
`PNN-CYDEPLOY-*` firewall rule the student created — including the seeded
permissive rule. `cydeploy_lab_id` accepts `M5-L1` or `ALL`.

It touches no pfSense rule, no non-CyDeploy firewall rule, and no core SC artifact
or `SC.seeded`. After the removals it asserts that an enabled inbound Remote
Desktop rule remains and that WinRM is running, so a reset can never leave the pod
unreachable. A reseed then re-arms the permissive rule, so a retake needs no manual
staging.

Re-seed is idempotent: the family marker short-circuits the seed, and
`force_reseed=true` re-deploys documents while keeping existing student responses.

---

## Known limitations

- Path classification is graded from the student's recorded `required_paths` /
  `unnecessary_paths`; the rule check proves the permissive rule is gone and the
  replacements are specific, but does not map each replacement rule back to a
  `PathId`. Deep rule-order validation stays with the existing SC labs.
- A student who blocks their own RDP or WinRM path loses the session and the
  grading channel until staff reset the lab; the guide warns them explicitly.
- CyDeploy Community Edition's ability to report network dependencies is
  unverified. If it only reports assets and configuration, students will derive
  dependencies from discovery plus the matrix — which the guide already supports.
- The matrix names `10.50.1.10` (DC01) and the AWX address as the required remote
  sources. If DC02 (`10.50.1.11`) starts serving pods, or AWX moves, refresh
  `templates/sc/cydeploy/SC-M5-L1_Required_Communication_Matrix.csv.j2`.

---

## CyDeploy-specific troubleshooting

| Symptom | Action |
|---------|--------|
| Student locked themselves out of the pod | Run the SC CyDeploy reset for that pod; it removes the `PNN-CYDEPLOY-*` rules and asserts RDP and WinRM survive. Have them record what happened. |
| Reset cannot reach the pod over WinRM | Restore the pod's `cydeploy-baseline` Proxmox snapshot (`qm rollback <vmid> cydeploy-baseline`), then reseed. |
| Verifier says the permissive rule is still present | The seeded rule is still enabled on the server; confirm the student removed or disabled it rather than creating a second copy. |
| Verifier says a replacement rule is too broad | A `PNN-CYDEPLOY-*` rule still has `Any` as its remote address or local port. |

---

## Expected screenshots (to add after the executable is available)

1. CyDeploy discovery/dependency output for a pod.
2. Host firewall inbound rule list before the change (permissive rule present).
3. Host firewall inbound rule list after the change, replacements scoped.
4. Post-change connectivity validation output.
5. Tracker showing SC-M5-L1 complete.

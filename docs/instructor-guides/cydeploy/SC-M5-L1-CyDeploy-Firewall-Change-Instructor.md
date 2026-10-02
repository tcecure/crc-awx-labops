# SC-M5-L1 — Dependency-Aware Firewall Change (Instructor Guide)

> **STATUS: STAGED.** Do not seed against an active student pod until
> `docs/cydeploy/CYDEPLOY-GO-LIVE.md` is complete.

---

## Seeded condition

Seeded by `playbooks/sc/cydeploy/seed_sc_cydeploy.yml` into
`C:\CyberLab\PodNN\SC-Artifacts\CyDeploy\` on the shared DC:

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

### The gateway condition is NOT seeded

**No gateway configuration is touched by this branch.** The permissive rule the
lab asks the student to remove (documented as `PNN-ALLOW-LAN-TO-ANY`) does not
exist on any pod gateway today, and the existing SC gateway seeding uses different
rule descriptions (for example `INSECURE: Allow all traffic (REMOVE THIS)`).

At go-live, choose one — after testing on a non-student pod:

1. Add a dedicated CyDeploy gateway seed step that creates a rule described
   `PNN-ALLOW-LAN-TO-ANY`, run only when the CyDeploy labs are activated. Do
   **not** modify the existing `seed_sc_gw` role, which serves the live SC family.
2. Or point the CyDeploy lab at the existing permissive rule by setting
   `cydeploy_sc_permissive_rule_descr` to the existing description, and update the
   change request template and student guide to match.

Option 2 requires no gateway change but overlaps with the live SC labs; option 1
keeps the labs independent. Either way the value used by the verifier and the
gateway read-back is the single variable `cydeploy_sc_permissive_rule_descr`.

---

## Expected finding

Discovery plus the communication matrix show that the pod needs only
authentication, name resolution, and policy delivery to the shared DC
(`10.50.1.10`). The permissive rule grants far more than that.

## Correct answer

| Response field | Expected |
|----------------|----------|
| `change_id` | `CHG-PNN-2026-0552` |
| `overly_broad_rule` | Matches `cydeploy_sc_permissive_rule_descr` (default `PNN-ALLOW-LAN-TO-ANY`) |
| `required_paths` | `PATH-01`, `PATH-02`, `PATH-03`, `PATH-04` (LDAP 389, SMB 445, DNS 53, Kerberos 88 to `10.50.1.10`) |
| `unnecessary_paths` | `PATH-05` (ad-hoc RDP to anywhere), `PATH-06` (unrestricted outbound) |
| `dependency_source` | ≥ 15 characters describing how dependencies were determined |
| `change_applied` | `yes` / `true` |
| `connectivity_validated` | `yes` / `true` |
| `determination` | `PASS` |
| `evidence` | ≥ 25 characters |
| `analyst`, `completed` | Non-empty / true |

The intended failure mode for students who skip the dependency analysis: removing
`PATH-02` or `PATH-04` breaks Group Policy or logon while DNS still works, which
is exactly the diagnostic the guide asks them to predict in advance.

---

## Verification logic

`roles/verify_sc_cydeploy/tasks/main.yml`, key `M5-L1`, run from
`playbooks/sc/cydeploy/verify_sc_cydeploy.yml`.

Two phases:

1. **Gateway phase (OFF by default).** Only when
   `cydeploy_gateway_check_enabled=true` does the playbook run a `raw` `grep` of
   `<descr>` entries in `/cf/conf/config.xml` on `crc_pod_gateways`
   (`ignore_unreachable: true`). It never writes gateway configuration. The
   result becomes `sc_cydeploy_gateway_tightened` (`true`/`false`/`unknown`).
2. **Document phase (shared DC).** Requires the seed marker and the four seeded
   documents, parses the response JSON, and applies the table above. If the
   gateway phase reported `false`, the lab fails with `the permissive rule is
   still present on PNN-GW`; `unknown` (the default) is not treated as failure.

The authoritative check of live SC firewall state remains `verify_sc_gw` — this
role does not duplicate or alter it. Tracker publication is gated by
`cydeploy_publish_progress` (default `false`).

---

## Reset behavior

`playbooks/sc/cydeploy/reset_sc_cydeploy.yml` removes only
`SC-Artifacts\CyDeploy` and the `SC-CYDEPLOY.seeded` marker. It does **not**
change pfSense rules, does not restore the permissive rule, and does not touch
core SC artifacts or `SC.seeded`.

Consequence: once the gateway condition is staged at go-live, resetting a student
for a retake requires re-staging the permissive rule via the go-live mechanism
chosen above. That step must be added to the reset path before activation.

Re-seed is idempotent: the family marker short-circuits the seed, and
`force_reseed=true` re-deploys documents while keeping existing student responses.

---

## Known limitations

- The permissive gateway rule does not exist yet (see above), so today the lab is
  documentary only.
- Reset does not re-arm the gateway condition.
- Path classification is graded from the student's recorded `required_paths` /
  `unnecessary_paths`, not from the applied rule set. Deep rule-order validation
  stays with the existing SC labs.
- CyDeploy Community Edition's ability to report network dependencies is
  unverified. If it only reports assets and configuration, students will derive
  dependencies from discovery plus the matrix — which the guide already supports.
- `PATH-01`..`PATH-04` all target `10.50.1.10` (DC01). If DC02 (`10.50.1.11`)
  becomes an authentication path for pods, refresh the matrix template.

---

## CyDeploy-specific troubleshooting

| Symptom | Action |
|---------|--------|
| Student locked themselves out of the pod | Restore from the pfSense configuration history on `PNN-GW`; treat as a teaching moment and have them record it. |
| Verifier says the permissive rule is still present | The gateway check is enabled and the rule description is still in `config.xml`; confirm the student removed it rather than disabling a duplicate. |
| Gateway check reports `unknown` for every pod | `cydeploy_gateway_check_enabled` is false (default) or the gateways were unreachable — the playbook intentionally continues. |
| Rule description mismatch after go-live | Set `cydeploy_sc_permissive_rule_descr` consistently for both the seed and verify jobs. |

---

## Expected screenshots (to add after the executable is available)

1. CyDeploy discovery/dependency output for a pod.
2. Gateway rule list before the change (permissive rule present).
3. Gateway rule list after the change, ending in the explicit default deny.
4. Post-change connectivity validation output.
5. Tracker showing SC-M5-L1 complete.

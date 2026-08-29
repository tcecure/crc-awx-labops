# CyDeploy Community Edition — Go-Live Checklist

**Current status: STAGED — NOT YET AVAILABLE TO ACTIVE STUDENTS.**

Everything on branch `feature/cydeploy-community-labs` is inert by design:
installation is feature-flagged off, tracker publication is off, the gateway
read-back is off, tracker catalog entries are unpublished, and no CyDeploy
playbook has been run against Pod01–Pod20.

Nothing in this document may be executed while the current two-week class is
running.

---

## Scope of the staged work

| Lab | Title | Family |
|-----|-------|--------|
| SI-M5-L1 | CyDeploy Asset Discovery | SI (supplemental) |
| SI-M5-L2 | Configuration & Security Findings | SI (supplemental) |
| SI-M5-L3 | Change Impact Comparison | SI (supplemental) |
| SC-M5-L1 | Network Dependency / Firewall Change Analysis | SC (supplemental) |

These are supplemental to the existing 57-lab curriculum. They are not a new
family and they must not enter completion percentages or auto-advance until
activation is approved.

---

## Checklist

```text
[ ] Active two-week class has ended
[ ] CyDeploy Community executable provided
[ ] Installer behavior documented
[ ] Installation tested on non-student target
[ ] Per-student discovery scope confirmed
[ ] No cross-pod discovery possible
[ ] SI-M5-L1 tested
[ ] SI-M5-L2 tested
[ ] SI-M5-L3 tested
[ ] SC-M5-L1 tested
[ ] Seed verified
[ ] Reset verified
[ ] Tracker entries enabled
[ ] Completion percentage updated
[ ] Wiki status changed from STAGED to ACTIVE
[ ] Auto-advance logic reviewed
[ ] AWX schedules explicitly approved before enabling
```

---

## How to complete each item

### 1. Active two-week class has ended

Confirm no pod shows in-progress work on the tracker
(`https://training.status.tcecure.com/training/status`) and that the instructor
has closed the class.

### 2. CyDeploy Community executable provided

The administrator supplies the installer. Record, without guessing:

- exact filename and version,
- checksum,
- license terms for lab use,
- where it is staged.

Set `cydeploy_installer_src` (control-node path) and/or
`cydeploy_installer_path` (path on the target) in
`roles/cydeploy_community/defaults/main.yml` or job extra vars.

### 3. Installer behavior documented

Run the installer interactively **once** on a throwaway host and record: silent
install switches, install directory, service names, listening ports, whether it
requires an account or license key, how discovery scope is specified, and the
output/export format. Nothing in this repository may assume any of these until
they are observed.

### 4. Installation tested on non-student target

Set `cydeploy_install_enabled=true`, `cydeploy_installer_path`,
`cydeploy_install_args` and `cydeploy_expected_service`, then run the seed
playbook against a **dedicated non-student pod only** (`pods="<test pod>"`).
Verify the `.installed` marker is written and that a second run is a no-op.

### 5. Per-student discovery scope confirmed

Confirm CyDeploy can be scoped to a single pod (`10.51.<pod>.0/24`) and that the
scope is what students can set themselves.

### 6. No cross-pod discovery possible

From the test pod, attempt discovery of another pod range, the shared domain, and
the management network. All must fail at the network layer. If any succeeds, this
is a **blocker**: fix the pod gateway policy before activation, and do not enable
the labs.

### 7–10. Per-lab testing

Each lab needs its seeded condition to actually exist before it can be tested end
to end. These conditions are deliberately **not** created by this branch:

| Lab | Condition to stage at go-live | Notes |
|-----|------------------------------|-------|
| SI-M5-L1 | An undocumented asset `PNN-UNKNOWN01` on the pod LAN | Must be discoverable and absent from `PNN_Expected_Asset_Inventory.csv` |
| SI-M5-L2 | The five observed conditions (`OBS-01`..`OBS-05`) on a pod host | Decide whether to deploy them or keep the lab as document analysis |
| SI-M5-L3 | Service `PNN-LabTelemetry` running/automatic on `PNN-APP01` | Reset must also be extended to re-arm this service |
| SC-M5-L1 | Permissive gateway rule described `PNN-ALLOW-LAN-TO-ANY`, or point `cydeploy_sc_permissive_rule_descr` at the existing SC permissive rule | Must not modify the existing `seed_sc_gw` role used by the live SC family |

For each lab: seed the test pod, complete it as a student would, confirm the
verifier PASSes, then submit a deliberately wrong response and confirm it FAILs
with a useful reason.

### 11. Seed verified

Confirm on the test pod: first seed deploys everything; a second seed is a no-op
(family marker); `force_reseed=true` re-deploys reference documents but logs
`[KEEP]` for existing `StudentResponses\*.json`; core SI/SC artifacts and
`SI.seeded` / `SC.seeded` are untouched.

### 12. Reset verified

Confirm reset removes only `SI-Artifacts\CyDeploy` / `SC-Artifacts\CyDeploy` and
the `SI-CYDEPLOY.seeded` / `SC-CYDEPLOY.seeded` markers — and nothing else. Then
extend the reset path to re-arm the seeded conditions from the table above
(`PNN-LabTelemetry`, the permissive gateway rule) so a retake is possible.

### 13. Tracker entries enabled

The four labs already exist in the tracker catalog, flagged off. Flip them on
only when activation is approved (see the tracker repository's CyDeploy catalog
entries: `published`, `active`, `visible_to_students`,
`included_in_completion_percentage`, `included_in_auto_advance`).

### 14. Completion percentage updated

Decide explicitly whether the CyDeploy labs count toward completion. If they do,
the denominator changes from 57 to 61 and every existing student's percentage
shifts — do this only between classes and announce it.

### 15. Wiki status changed from STAGED to ACTIVE

Remove the `STATUS: STAGED` banner from the five staged Wiki.js pages
(SI CyDeploy ×3, SC CyDeploy ×1, Cyber Lab Tools → CyDeploy Community Edition)
and link them from the lab family pages.

### 16. Auto-advance logic reviewed

Template 24 (Auto-Advance Families) is untouched by this branch. Decide whether
CyDeploy labs gate advancement. Recommendation: keep them optional/non-gating on
first run, so a tool problem cannot block a student's progression.

### 17. AWX schedules explicitly approved before enabling

No schedule may be created for the CyDeploy templates without explicit approval.
When approved, add them after the existing verifier windows so they cannot
collide with the production verify jobs.

---

## AWX templates

The six CyDeploy job templates were **not** created in AWX by this work (pending
the administrator's decision). When they are created, they must be unscheduled and
excluded from Template 24, and their IDs recorded here:

| Template name | Playbook | AWX ID |
|---------------|----------|--------|
| Seed - SI CyDeploy Labs | `playbooks/si/cydeploy/seed_si_cydeploy.yml` | _not created_ |
| Verify - SI CyDeploy Labs | `playbooks/si/cydeploy/verify_si_cydeploy.yml` | _not created_ |
| Reset - SI CyDeploy Labs | `playbooks/si/cydeploy/reset_si_cydeploy.yml` | _not created_ |
| Seed - SC CyDeploy Lab | `playbooks/sc/cydeploy/seed_sc_cydeploy.yml` | _not created_ |
| Verify - SC CyDeploy Lab | `playbooks/sc/cydeploy/verify_sc_cydeploy.yml` | _not created_ |
| Reset - SC CyDeploy Lab | `playbooks/sc/cydeploy/reset_sc_cydeploy.yml` | _not created_ |

Project 10 (`crc-awx-labops`) has update-on-launch disabled — after this branch
is merged, the project must be synced before any CyDeploy template will see the
new playbooks.

---

## Variables that control staging

| Variable | Default | Effect |
|----------|---------|--------|
| `cydeploy_install_enabled` | `false` | No installation is attempted |
| `cydeploy_installer_path` | `""` | Must be supplied before installation |
| `cydeploy_publish_progress` | `false` | Verifiers do not publish to the tracker |
| `cydeploy_gateway_check_enabled` | `false` | SC verifier does not read gateway config |
| `cydeploy_sc_permissive_rule_descr` | `PNN-ALLOW-LAN-TO-ANY` | Rule the SC lab expects |
| `force_reseed` | `false` | Seeds skip when the family marker exists |

---

## Prohibited before sign-off

- Seeding, verifying, or resetting CyDeploy on Pod01–Pod20.
- Modifying existing AC/IA/SI/SC/MP/PE objects, playbooks, or templates.
- Installing CyDeploy on DC01, DC02, `PodNN-DC`, or `PodNN-GW`.
- Creating or enabling AWX schedules for CyDeploy.
- Adding CyDeploy to Template 24.
- Changing tracker completion calculations.
- Changing pod firewall rules or Guacamole connections.
- Restarting production VMs.

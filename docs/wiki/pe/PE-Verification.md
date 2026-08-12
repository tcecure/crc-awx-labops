# Physical Protection (PE) — Verification

## Contract

The verify playbook publishes:

```yaml
pod01:
  PE-M1-L1:
    completed: false
    reason: "human-readable requirement"
```

Declared lab IDs:

- `PE-M1-L1`
- `PE-M1-L2`
- `PE-M2-L1`
- `PE-M2-L2`
- `PE-M3-L1`
- `PE-M3-L2`

The report file is `/runner/artifacts/PE_Verification_Report.json`. All 20 pod keys remain present even when a family is not seeded; missing readiness markers report the lab as incomplete.

## Read-Only Rules

Verification never edits response files. MP media inspection uses a read-only mount and dismounts media it attached. PE verification only imports CSV/text evidence.

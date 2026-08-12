# Media Protection (MP) — Verification

## Contract

The verify playbook publishes:

```yaml
pod01:
  MP-M1-L1:
    completed: false
    reason: "human-readable requirement"
```

Declared lab IDs:

- `MP-M1-L1`
- `MP-M1-L2`
- `MP-M1-L3`

The report file is `/runner/artifacts/MP_Verification_Report.json`. All 20 pod keys remain present even when a family is not seeded; missing readiness markers report the lab as incomplete.

## Read-Only Rules

Verification never edits response files. MP media inspection uses a read-only mount and dismounts media it attached. PE verification only imports CSV/text evidence.

# Physical Protection (PE) — Automation

## Data Flow

```text
Seed - PE Family (AWX template 30)
  ↓ per-pod artifacts and PE.seeded
Student evidence
  ↓
Verify - PE Family (AWX template 31)
  ↓ AWX Job.artifacts
Training Tracker
  ↓
Reset - PE Family (AWX template 32)
```

## Variables

- `pods="7"` — one pod
- `pods="7,9,12"` — selected pods
- `pod_id=7` — one-pod alias
- blank — all configured pods
- `force_reseed=true` — explicit instructor override

## Auto-Advance

The family is appended to the progression `AC → IA → SI → SC → MP → PE`. Auto-advance uses the exact lab list for each family, so the three-lab and six-lab completion thresholds do not change tracker or advancement logic.

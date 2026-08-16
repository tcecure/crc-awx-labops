% Network Dependency Worksheet
% ACS Cyber Lab — SC-M5-L1
% Advanced Cyber Solutions (ACS)

## Analyst Information

| Field | Entry |
|-------|-------|
| Analyst name | |
| Pod (your assigned pod only) | |
| Change ID | |
| Date | |
| CyDeploy version | |

## 1. What discovery told you

Record what CyDeploy reported about the systems and applications operating in your pod, and what those systems appear to depend on.

| Discovered system / application | Role | Communication it appears to depend on | How you determined it |
|--------------------------------|------|--------------------------------------|----------------------|
| | | | |
| | | | |
| | | | |

## 2. Path-by-path decision

Work through the required communication matrix. For every path, decide whether it must be permitted after the change.

| PathId | Destination | Protocol/Port | Purpose | Keep or remove | Justification |
|--------|------------|---------------|---------|----------------|---------------|
| PATH-01 | | | | | |
| PATH-02 | | | | | |
| PATH-03 | | | | | |
| PATH-04 | | | | | |
| PATH-05 | | | | | |
| PATH-06 | | | | | |

## 3. Impact if you get it wrong

| Path removed in error | Predicted symptom for the student workstation |
|----------------------|----------------------------------------------|
| | |
| | |

## 4. Planned rule set

State the rule set you intend to apply, in order, ending with the default deny.

| Order | Action | Source | Destination | Protocol/Port | Description |
|-------|--------|--------|------------|---------------|-------------|
| 1 | | | | | |
| 2 | | | | | |
| 3 | | | | | |
| 4 | | | | | |
| last | Deny | any | any | any | Explicit default deny |

## 5. Attestation

| Field | Entry |
|-------|-------|
| I confirm this analysis covers only my assigned pod | |
| Signature | |
| Date | |

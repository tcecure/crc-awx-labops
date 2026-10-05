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

State the inbound rules you intend to create on your pod server. Every rule needs a specific remote address and a specific local port; anything you do not permit is blocked by the firewall's default inbound action.

| Rule name | Remote address | Local port | Protocol | Path it covers | Why it is required |
|-----------|---------------|-----------|----------|----------------|--------------------|
| | | | | | |
| | | | | | |
| | | | | | |
| | | | | | |

## 5. Attestation

| Field | Entry |
|-------|-------|
| I confirm this analysis covers only my assigned pod | |
| Signature | |
| Date | |

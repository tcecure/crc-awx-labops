# SC Lab Catalog

## Module 1: Foundations of the Digital Perimeter

### M1-L1: Understanding Trust Boundaries
| Field | Value |
|-------|-------|
| Difficulty | Beginner |
| Time | 20 min |
| Type | Document-based |
| VMs Required | PodXX-GW (read-only), PodXX-DC |
| CMMC | SC.L1-3.13.1 |
| Objective | Students identify external/internal boundaries, trusted/untrusted zones, and FCI location |

### M1-L2: Deny By Default Firewall
| Field | Value |
|-------|-------|
| Difficulty | Beginner |
| Time | 30 min |
| Type | Hands-on (pfSense) |
| VMs Required | PodXX-GW |
| CMMC | SC.L1-3.13.1 |
| Objective | Reconfigure from Allow Any Any to deny-by-default with specific allow rules |
| Seeded State | LAN has Allow Any Any rule; student must delete and create specific rules |

### M1-L3: Monitor, Control, Protect
| Field | Value |
|-------|-------|
| Difficulty | Intermediate |
| Time | 30 min |
| Type | Hands-on (pfSense) |
| VMs Required | PodXX-GW, PodXX-DC |
| CMMC | SC.L1-3.13.1 |
| Objective | Identify which firewall actions represent monitoring, controlling, and protecting |
| Seeded State | Rules with logging (monitor), restricted DNS (control), block rules (protect) |

## Module 2: External and Internal Boundaries

### M2-L1: Draw the Organizational Boundary
| Field | Value |
|-------|-------|
| Difficulty | Beginner |
| Time | 20 min |
| Type | Document-based |
| VMs Required | PodXX-GW (read-only), PodXX-DC |
| CMMC | SC.L1-3.13.1 |
| Objective | Create organizational boundary diagram from live pfSense data |

### M2-L2: Secure the DMZ
| Field | Value |
|-------|-------|
| Difficulty | Advanced |
| Time | 45 min |
| Type | Hands-on (pfSense) |
| VMs Required | PodXX-GW |
| CMMC | SC.L1-3.13.1 |
| Objective | Move web server from internal LAN into a DMZ zone |
| Seeded State | NAT/rules point to LAN IP; student creates OPT1/DMZ interface |

### M2-L3: Internal Segmentation (VLANs)
| Field | Value |
|-------|-------|
| Difficulty | Advanced |
| Time | 45 min |
| Type | Hands-on (pfSense) |
| VMs Required | PodXX-GW |
| CMMC | SC.L1-3.13.1 |
| Objective | Create VLANs for HR/Finance/Engineering/Guest and enforce isolation |
| Seeded State | Flat network, no VLANs; aliases hint at required subnets |

## Module 3: Firewall Rules

### M3-L1: Firewall Rule Audit
| Field | Value |
|-------|-------|
| Difficulty | Intermediate |
| Time | 30 min |
| Type | Hands-on (pfSense) |
| VMs Required | PodXX-GW, PodXX-DC |
| CMMC | SC.L1-3.13.1 |
| Objective | Audit and clean intentionally messy firewall rules |
| Seeded State | Allow Any, shadowed rules, duplicates, unused rules |

### M3-L2: Rule Ordering Challenge
| Field | Value |
|-------|-------|
| Difficulty | Intermediate |
| Time | 25 min |
| Type | Hands-on (pfSense) |
| VMs Required | PodXX-GW |
| CMMC | SC.L1-3.13.1 |
| Objective | Fix rule ordering so traffic flows correctly |
| Seeded State | Block All rule before allow rules; all traffic blocked |

### M3-L3: Least Privilege Access
| Field | Value |
|-------|-------|
| Difficulty | Intermediate |
| Time | 25 min |
| Type | Hands-on (pfSense) |
| VMs Required | PodXX-GW |
| CMMC | SC.L1-3.13.1 |
| Objective | Remove unnecessary ports, keep only TCP 443 for accounting app |
| Seeded State | 7 port rules (21,22,23,80,443,3306,8080); only 443 needed |

## Module 4: Monitoring and Validation

### M4-L1: Firewall Log Investigation
| Field | Value |
|-------|-------|
| Difficulty | Intermediate |
| Time | 30 min |
| Type | Hands-on (pfSense) |
| VMs Required | PodXX-GW, PodXX-DC |
| CMMC | SC.L1-3.13.1 |
| Objective | Investigate port scans, malware indicators, denied traffic in logs |
| Seeded State | Rules with logging on all actions; realistic log patterns |

### M4-L2: Verify SC Compliance
| Field | Value |
|-------|-------|
| Difficulty | Intermediate |
| Time | 35 min |
| Type | Hands-on (pfSense + DC) |
| VMs Required | PodXX-GW, PodXX-DC |
| CMMC | SC.L1-3.13.1 |
| Objective | Perform simplified CMMC assessor walkthrough |
| Seeded State | Mostly-compliant config; students verify against checklist |

### M4-L3: Final Capstone
| Field | Value |
|-------|-------|
| Difficulty | Expert |
| Time | 60 min |
| Type | Hands-on (pfSense + DC) |
| VMs Required | PodXX-GW, PodXX-DC |
| CMMC | SC.L1-3.13.1 |
| Objective | Fix all security problems: deny-by-default, WAN security, VLANs, logging |
| Seeded State | All problems combined: Allow Any, open WAN, Telnet, no VLANs, no logging |

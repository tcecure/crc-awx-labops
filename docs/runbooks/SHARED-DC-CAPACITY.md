# Shared DC capacity (RD Session Host)

Applies to `DC01-P01` (Proxmox VM 200, `10.50.1.10`), the shared domain
controller every pod's Guacamole connection currently targets.

## Why this exists

A Windows Server without the Remote Desktop Session Host role allows only **two**
concurrent RDP sessions (administrative mode). With all pods pointed at one DC,
the third student to connect is told the server is busy and is offered the choice
of disconnecting someone else. Abandoned disconnected sessions made it worse,
because they never released their slot.

This runbook is the stopgap for the shared-DC model. The end state is per-pod
member servers (`docs/runbooks/POD-MEMBER-SERVERS.md`), where students never log
on to a domain controller.

## What is configured

`playbooks/configure-dc-session-host.yml` applies, idempotently:

| Setting | Value | Effect |
| --- | --- | --- |
| `RDS-RD-Server` feature | installed | removes the 2-session limit (needs one reboot) |
| `LicensingMode` | 4 | per-user licensing |
| `MaxDisconnectionTime` | 3600000 | disconnected sessions end after 1 hour |
| `MaxIdleTime` | 7200000 | idle sessions end after 2 hours |
| `fSingleSessionPerUser` | 1 | a student reconnects to their own session |
| `MaxInstanceCount` | 999999 | no artificial session ceiling |
| `WSearch` service | disabled | removes indexer CPU/disk churn per session |
| Defender exclusion | `C:\CyberLab` | keeps evidence writes out of real-time scanning |

Registry policy path: `HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services`.

Licensing: no RD licensing server is deployed, so the host runs in the RDS
**120-day grace period**. Sessions work throughout it. Before the grace period
ends, either complete the member-server cutover (grace period no longer matters,
because each student has their own box with 2 admin sessions) or stand up a
licensing server with per-user CALs.

## Sizing

Measured on the live host: each student session uses 0.5–1.5 GB RAM (avg ~1 GB,
~30 processes — Edge, PowerShell, MMC), and 4 sessions already drove 34% of 4
vCPUs.

| Cohort size | Allocation |
| --- | --- |
| 12 students | 12 vCPU / 32 GB (current) |
| 20 students | 12 vCPU / 48 GB |

Resize from the Proxmox host (VM must be off):

```bash
qm set 200 --cores 12 --memory 32768
```

The QEMU guest agent is not running on VM 200, so `qm shutdown 200` times out.
Shut the guest down from inside Windows instead (`Stop-Computer -Force` through
AWX), then `qm start 200`.

## Verification

Configuration and health:

```powershell
$cs = Get-CimInstance Win32_ComputerSystem
(Get-WindowsFeature RDS-RD-Server).InstallState
(Get-Service TermService, ADWS, Netlogon, DNS).Status
dcdiag /test:services
```

Concurrency (the check that actually matters): open one session per student and
confirm `quser` lists them at the same time. `scripts/dc-capacity/hold-sessions.py`
does this through guacd — see its header for usage. A cohort-sized run on
2026-08-18 held 12 simultaneous sessions with CPU at ~2% and 27 GB RAM free, and
no session was refused.

Sessions opened for testing should be logged off afterwards:

```powershell
quser | Select-Object -Skip 1 | ForEach-Object {
  $id = ($_ -split '\s+' | Where-Object { $_ -match '^\d+$' })[0]
  if ($id) { logoff $id }
}
```

## Cautions

- Installing the role reboots the DC, which interrupts every pod. Check `quser`
  first and run it outside class time.
- This does not change where evidence lives; verification still reads
  `C:\CyberLab\PodNN` on DC01.
- DC02 (`10.50.1.11`) deliberately does **not** get this change: no Guacamole
  connection targets it and its RDS logon right is Administrators-only, so it
  stays a replica DC with no student sessions.

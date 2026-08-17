# Runbook: Students cannot log into the shared domain controller

All 20 pods share one domain controller (`DC01-P01`, Proxmox VM 200 on pve1, `10.50.1.10`,
domain `acs-p01.local`, NetBIOS `ACS-P01`). Guacamole connection `PODXX-DC` targets that host
with stored credentials (`studentXX` / domain `acs-p01.local`).

## Triage order

1. **Is the DC running?**
   `qm status 200` on pve1. A guest-initiated shutdown appears in the DC's System log as event
   1074 and on pve1 as `200.scope: Deactivated successfully`. Start it with `qm start 200`.
   VM 200 is configured `onboot=1, startup=order=1`.
2. **Is the account healthy?**
   `Get-ADUser studentXX -Properties Enabled,LockedOut,PasswordExpired,badPwdCount`.
3. **What did the failure actually say?** Security log 4625 sub-status is decisive:
   - `0xC0000064` — user name does not exist. Usually a wrong domain prefix: `ACS\studentXX`
     is invalid; use `studentXX@acs-p01.local` or `ACS-P01\studentXX`.
   - `0xC000006A` — wrong password.
   - `0xC000015B` — the account lacks the requested logon type: "Allow log on through Remote
     Desktop Services" on a DC defaults to Administrators only.
4. **Rights and delegation**: run `playbooks/ensure-student-access.yml` (idempotent). It grants
   the RDS logon right to `Remote Desktop Users`, ensures `PodNN-Admins` exists with GenericAll
   on `OU=PodNN,OU=Students`, adds `studentNN` to it, and grants that group Modify on
   `C:\CyberLab\PodNN`.

## Do not grant students Domain Admins

Domain Admins carries the DC shutdown right, so one student can take all 20 pods offline
(this happened on 2026-08-17 at 00:23 EDT). Pod-scoped delegation via `PodNN-Admins` provides
everything the AC/IA/SI labs need without that risk.

## End-to-end verification without a student

From the Guacamole host, drive `guacd` directly to confirm a real RDP logon (protocol
handshake: `select` → `args` → `size`/`audio`/`video`/`image` → `connect` with one value per
arg name, version string included). A `sync` instruction means the session established;
confirm with a 4624 logon type 10 for the account on the DC.

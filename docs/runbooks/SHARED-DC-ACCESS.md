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
everything the AC/SI labs and most of IA need without that risk.

## UAC prompt when opening ADUC (or any MMC console)

`mmc.exe` is manifested `highestAvailable`, and the DC keeps UAC enabled with
`ConsentPromptBehaviorUser=3` (prompt for credentials). A standard user therefore gets an
over-the-shoulder UAC prompt for `dsa.msc`, Server Manager → Tools, and a blank MMC console —
and a `studentNN` account is always rejected there because it is not an administrator. This is
not a password problem.

Fix deployed by `playbooks/ensure-student-access.yml`:
`C:\CyberLab\Tools\Open-ADUC.cmd` sets `__COMPAT_LAYER=RunAsInvoker` and starts
`mmc.exe dsa.msc`, so ADUC runs unelevated with the student's own delegated rights, plus a
Public Desktop shortcut pointing at it. Verified as `student20` on 2026-08-17: ADUC opens and
binds to `acs-p01.local` with no prompt. Equivalent one-liner:
`cmd /c "set __COMPAT_LAYER=RunAsInvoker&& start "" mmc.exe dsa.msc"`.

## Known lab steps that still need privileges students do not have

Verified as `student20` on the shared DC:

- **IA M2-L1** (retarget scheduled task `PodXX ACS Nightly Backup` to `PXX-svc_backup`):
  `Get-ScheduledTask` cannot even see the task, and `Set-ScheduledTask` returns *Access is
  denied*. Granting `PodNN-Admins` Modify on `C:\Windows\System32\Tasks\<task>` is **not**
  sufficient (tested and reverted). Storing another account's credentials on a task requires
  local administrator, so this lab cannot be completed by a delegated pod account as written.
- **IA M3-L2** (`Set-ADDefaultDomainPasswordPolicy` / edit Default Domain Policy): editing the
  Default Domain Policy GPO requires Domain Admins or an explicit GPO-edit delegation, which
  students do not have.

Options, in order of preference: give each pod its own member server where the student is local
admin (removes the shared-DC constraint entirely); or add a SYSTEM-side helper that applies only
the allowed pod-scoped change from a student request file; or delegate GPO edit rights on the
Default Domain Policy to the students group (accepting that M3-L2 is already domain-wide).

## End-to-end verification without a student

From the Guacamole host, drive `guacd` directly to confirm a real RDP logon (protocol
handshake: `select` → `args` → `size`/`audio`/`video`/`image` → `connect` with one value per
arg name, version string included). A `sync` instruction means the session established;
confirm with a 4624 logon type 10 for the account on the DC.

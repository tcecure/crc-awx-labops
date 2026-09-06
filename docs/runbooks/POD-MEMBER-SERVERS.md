# Runbook: per-pod member servers

Each pod gets its own Windows Server 2022 **member server** (`POD03-SRV` …), which is
the student's session host. The student is a local administrator of that one box and
nothing else; the domain controllers host no student sessions.

Why: on the shared DC students cannot be local admins (a local admin on a DC is
effectively domain-wide), which broke ADUC (UAC prompt), IA M2-L1 and IA M3-L2, and
Windows caps a non-RDSH server at 2 concurrent RDP sessions for all 20 pods.

AD labs are unaffected — ADUC and the `ActiveDirectory` module are LDAP clients, so
they run against `acs-p01.local` from the member server with the student's existing
per-pod OU delegation.

## Layout

| Item | Value |
| --- | --- |
| Proxmox VMID | `400 + pod_id` (Pod03 -> 403) |
| Name | `PODXX-SRV` |
| Bridge | `podXXnet` |
| Address | `10.50.XX.20/24`, gateway `10.50.XX.1` |
| DNS | `10.50.1.10`, `10.50.1.11` |
| Sizing | 2 vCPU / 4 GB / 60 GB thin |
| Computer OU | `OU=PodServers,DC=acs-p01,DC=local` |
| Evidence | `C:\CyberLab\PodXX` |

## Routing prerequisite

Pod networks reach the DCs through the Guacamole host (`10.50.XX.1` on each pod
side). Both directions must be open:

* On the Guacamole host, UFW must forward `10.50.0.0/16` to `10.50.1.10` and
  `10.50.1.11`.
* Each DC needs a persistent route back to the other pod networks:
  `route -p add 10.50.0.0 mask 255.255.0.0 10.50.1.1 metric 1`.

Without the DC-side route the member server can ping nothing beyond its own
subnet and `nltest /dsgetdc:acs-p01.local` returns `ERROR_NO_SUCH_DOMAIN`.

## Build a pod server

1. On the Proxmox host, clone and boot with the bootstrap injected:

   ```bash
   echo -n '<bootstrap-password>' | scripts/pod-servers/clone-pod-server.sh 3
   ```

   The bootstrap password is the one stored in the AWX credential
   **CRC Pod Server Local** (username `crcsvc`). It is never passed on the command
   line — the script reads it from stdin.

2. Wait for the first boot to finish (about 3 minutes), then confirm AWX can reach
   the host over WinRM with that credential.

3. Provision it, attaching the **CRC Pod Server Local** and **CRC Domain Join**
   credentials:

   ```
   Job template: Provision Pod Member Server
   Limit:        pod03-srv
   ```

   That renames the host, joins the domain into `OU=PodServers`, installs
   RSAT/GPMC, makes `ACS-P01\studentXX` a local admin and Remote Desktop user, and
   creates the evidence directory.

4. Repoint the pod's Guacamole connection from `10.50.1.10` to `10.50.XX.20` and
   rename it `PODXX-SRV`.

## Patching and licensing

Pod networks have no outbound TCP/443, so Windows Update and Microsoft activation
both need the temporary maintenance NIC:

```bash
scripts/pod-servers/maintenance-nic.sh attach 1 2 4 5   # run on the Proxmox host
scripts/pod-servers/maintenance-nic.sh detach 1 2 4 5   # immediately afterwards
```

`msmigration/patch_license_fleet.py`-style batching is the safe pattern: attach the
NIC for one batch, run **Patch Pod Member Server**, then **License Pod Member
Server**, then detach before moving on. A server must never be left with `net1`.

`playbooks/license-pod-server.yml` (job template **License Pod Member Server**)
takes the 20 purchased Datacenter keys from the **CRC Pod Server Datacenter Keys**
custom credential as one ordered comma-separated secret, and picks the key matching
the host's own pod number. The key is passed to Windows only through a process
environment variable, every task scrubs it out of its own output, and the DISM logs
that record the command line are deleted, so the key never reaches job output, a
guest file or the evidence tree.

An evaluation install cannot take a key with `slmgr /ipk` (`0xC004F069`): the SKU is
converted first with `DISM /Set-Edition:ServerDatacenter`, which requires a reboot,
and only then does `slmgr /ato` succeed. The playbook fails the host unless it ends
at `edition=ServerDatacenter status=1`.

## Domain-join account

`playbooks/setup-domain-join-account.yml` creates the account the join uses. It is
delegated only `CCDC;computer` on `OU=PodServers` and belongs to no privileged
group, so the credential cannot administer the domain. Run it once before the first
provision, and again if the password is rotated.

Both playbooks read `domain_join_user` / `domain_join_password` from the **CRC
Domain Join** custom credential; never pass them as extra vars, which would record
them on the job.

## Where seed, verify and reset run

Every seed/verify/reset playbook takes `crc_target_mode`:

| value | meaning |
|---|---|
| `shared_dc` (default) | the legacy path: everything runs on `crc_shared_dcs[0]`, one job grades all 20 pods. Kept for rollback. |
| `member_server` | host-local work runs on the student's own `crc_pod_servers` host, one pod per host, using that host's `pod_id`. |

**SI, MP, PE and the document half of SC** only ever touch files and host state, so
in `member_server` mode they run entirely on the session host. The SC gateway play
(pfSense), certificate generation and tracker publishing are unchanged.

**AC and IA are different: they read Active Directory.** Their checks stay on the
domain controller even in `member_server` mode, deliberately. Querying AD from a
member server over WinRM is a second hop, which would mean putting domain
credentials (via `become`/CredSSP) onto a box where the student is a local
administrator — a credential the student could then lift and replay against every
other pod. So the credentials stay off the session host and the *evidence* travels
instead:

* `playbooks/sync-pod-evidence.yml` with `sync_direction=pull` zips
  `C:\CyberLab\PodXX` on the session host, brings it through the controller and
  expands it on the DC. `verify-cmmc-ac.yml` and `verify-cmmc-ia.yml` import it
  before grading, so the DC grades what the student actually did on their server.
* The same playbook with `sync_direction=push` runs at the end of the AC/IA seed
  and reset playbooks, so seeded artifacts and post-reset state land on the
  session host the student logs into.
* Both directions are a no-op while `crc_target_mode` is `shared_dc`.

One IA check (`M2-L1`, the scheduled task) and the MP media-mount step inspect live
host state and remain waived (`ia_m2l1_task_step_waived`,
`mp_media_mount_waived`) until the pilots prove them on a session host.

## Running a verify job for one pod

The verify playbooks have a second play (`hosts: localhost`) that consolidates the
per-pod results and publishes them to the tracker. An AWX `limit` applies to the
whole job, so limiting to a single session host silently drops that play and the
job succeeds without grading anything. Limit to **both**:

```text
pod03-srv,localhost
```

Pods with no results publish nothing, so a single-pod run cannot overwrite another
pod's tracker record.

To rehearse a family on a session host without touching the pod's tracker record —
for example seeding a finished pod to prove the member-server path — launch the
verify template with:

```yaml
crc_publish_tracker: false
```

The grading output still appears in the job and in the AWX artifacts; only the POST
to the portal is skipped.

`pod_id` scopes the AD-side seed and reset plays to one pod, because an extra var
outranks the per-pod loop variable. For the same reason never pass it to a verify
run: the loop keeps grading all 20 pods but files every result under that one pod,
so the artifact says `pod03` while the findings are another pod's objects.

## Troubleshooting

**RDP dies at NLA after the edition conversion.** Symptom: Guacamole reports
`Security mode: NLA` then `RDP server closed/refused connection`, the host logs
`Listener RDP-Tcp received a connection` (event 261) but there is no 4625/4776
locally and no 4768/4771/4776 for the account on the DC — i.e. it failed inside
TLS/CredSSP, before any credential was validated. Time skew, SPN registration and
the firewall scope are *not* the cause if those events are absent. Rebuild the
listener certificate:

```powershell
Get-ChildItem Cert:\LocalMachine\'Remote Desktop' | Remove-Item -Force
Remove-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' `
  -Name SSLCertificateSHA1Hash -ErrorAction SilentlyContinue
Restart-Service TermService -Force
```

**Scheduled tasks with a stored credential.** A local account that is not in
Administrators (or another holder of `SeBatchLogonRight`) registers the task fine
but the run fails with `LastTaskResult: 267011` and no output. Grant *Log on as a
batch job* to the account, or run the task as a member of Administrators.

**`whoami /groups` shows Administrators as "deny only".** That is UAC token
filtering, not a missing membership — check capability from an elevated prompt.

**Hyper-V cmdlets are absent** on the session hosts, so the MP media steps use
`diskpart` (`create vdisk`, `attach vdisk`, `detach vdisk`) rather than
`New-VHD`/`Mount-VHD`.

## Cut-over notes

* Do not cut a pod over mid-family — the graded evidence under `C:\CyberLab\PodXX`
  lives on whichever host the student worked on, so migrate it or switch at a
  family boundary.
* Run one family end to end (seed → student action → verify → tracker → reset) in
  `member_server` mode before switching the scheduled verify jobs over.
* Neither the new `PODXX-SRV` connections nor the legacy `PODXX-DC` rollback
  connections store a password: both prompt inside the RDP session. A stored
  password there survives an identity reset and silently breaks the tile with
  `Log in failed` and no prompt, which is how the legacy tiles were found broken.

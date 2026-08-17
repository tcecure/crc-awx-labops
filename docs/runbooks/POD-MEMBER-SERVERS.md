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

## Domain-join account

`playbooks/setup-domain-join-account.yml` creates the account the join uses. It is
delegated only `CCDC;computer` on `OU=PodServers` and belongs to no privileged
group, so the credential cannot administer the domain. Run it once before the first
provision, and again if the password is rotated.

Both playbooks read `domain_join_user` / `domain_join_password` from the **CRC
Domain Join** custom credential; never pass them as extra vars, which would record
them on the job.

## Cut-over notes

* Do not cut a pod over mid-family — the graded evidence under `C:\CyberLab\PodXX`
  lives on whichever host the student worked on, so migrate it or switch at a
  family boundary.
* Seed/verify playbooks still target `crc_shared_dcs[0]` for AD work. Host-level
  evidence paths must move to the pod server as part of the cut-over.

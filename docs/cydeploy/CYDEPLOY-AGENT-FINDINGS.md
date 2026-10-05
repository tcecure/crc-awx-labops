# CyDefense Agent — artifact findings and isolation decision

What the supplied vendor artifact actually does, how that was established, and
what the automation does about it. Written before any pod was touched: at the
time of writing no agent has been installed anywhere in the lab.

## The artifact

| Fact | Value |
| --- | --- |
| File | `CyDefenseAgent-1.0.16226.849.msi` |
| SHA-256 | `1648363b29d502eb978c0ae805a91fcc11e9c73f627097adfc84c79edd232fb9` |
| Product name | CyDeploy Agent |
| Product version | 1.0.16226.849 |
| Product code | `{00BDA44B-2F36-464E-BCF9-99E5BD743CA1}` |
| Upgrade code | `{AD71ABB9-E34E-4DEB-9FC2-A50B6B854D51}` |
| Built with | WiX Toolset 6.0.2.0, x64, .NET Framework 4.8 |
| Services | `CyDefenseService` (auto, `NT SERVICE\CyDefenseService`), `CyDefenseImagingHelper` (demand, `LocalSystem`) |

Install and removal:

```text
msiexec /i CyDefenseAgent-1.0.16226.849.msi /qn /norestart ONLINE_MODE=0 APIURL=https://localhost:57523
msiexec /x {00BDA44B-2F36-464E-BCF9-99E5BD743CA1} /qn /norestart
```

The automation drives both through `ansible.windows.win_package`, which supplies
`/qn` itself and uses the product code for idempotency.

Everything above was read out of the MSI's own tables (`Property`,
`ServiceInstall`, `ServiceControl`, `Registry`, `CustomAction`, `Upgrade`) and
out of the installed assemblies. It is static analysis on Linux: no part of it
has been observed running on Windows yet, which is what the Pod19/Pod20 pilot is
for.

## Installer defaults that are wrong for this lab

Three MSI defaults had to be overridden.

`Insights=#1`. The vendor documentation says insights collection is opt-in and
defaults to off. The MSI's `Registry` table writes `1`, and the service starts
the collector whenever the flag reads true:

```il
IL_0288:  ldstr "Insights"
IL_028d:  call bool CyDefenseShared.RegistryLogger::IsRegistryDwordBool(string)
IL_0292:  brfalse.s IL_02c2
IL_0295:  ldstr "C:\\ProgramData\\CyDefense\\Telemetry\\UserInsight"
...         CyUserInsightAgent::Start()
```

That collector records window titles, process start/stop via ETW, DNS queries,
PowerShell script-block content, USB arrivals and session activity on the
student's desktop. None of the four labs need it, and collecting a learner's
keystroke-adjacent activity to grade a firewall exercise is not something the
lab should do quietly. The role sets `Insights=0` and asserts it after start.

`ONLINE_MODE=1` and `APIURL=https://localhost:57523`. Online mode drives
enrollment, heartbeat, the daily licence refresh and the API job queue — the
path by which the vendor's server can push topology scans, sandbox provisioning,
hardening audits and digital-twin backups into the pod. The pods have no
outbound internet, so an online agent would produce nothing but failing
heartbeats and a growing spool. The role installs with `ONLINE_MODE=0`, leaves
the API pointed at the loopback default, and never supplies an enrollment token,
so no server can queue work on a pod.

The imaging helper. `CyDefenseImagingHelper` runs as `LocalSystem` and exists to
write VHDX images of the volume hosting `C:` into
`C:\ProgramData\CyDefense\Backups`. Nothing in the four labs uses it, pod disks
have no room for repeated full-volume images, and `create_backup` is reachable
by a student (below). The role stops it and sets its start type to Disabled.

## The isolation finding

**The agent cannot be confined to one pod by configuration. Confinement has to
be imposed on it from outside, and that is what the role does.**

Two reasons.

First, the licence gate is not a gate. `HasLicenseFeature` returns `true`
unconditionally in this build:

```il
.method private hidebysig instance default bool HasLicenseFeature (string feature) cil managed
{
    IL_0000:  ldc.i4.1
    IL_0001:  ret
}
```

So "Community/Starter edition does not include topology scanning" is not a
control. Topology, digital twin, insights, hardening audit and compliance all
run if asked. The vendor documentation says as much ("gating not yet enforced"),
and the binary agrees.

Second, the command pipe is open to ordinary users. `CyDefensePipe` is created
with an ACL granting `BUILTIN\Users` read and write, and of the documented
commands only four check `callerIsAdmin`. `scan_network:<CIDR>` explicitly logs
the non-admin case and proceeds:

```text
Command [scan_network]: caller=<non-admin> — accepting (tray-triggered local scan).
```

`scan_topology`, `discover_devices`, `cve_scan` and `create_backup` do not check
at all. On a pod member server the ordinary interactive user is the student, so
without an external control a student could type `scan_network:10.50.1.0/24` at
the tray and sweep the shared domain controllers, or `scan_network:192.168.1.0/24`
and sweep the management network, or ask for a full-volume VHDX image and fill
the pod disk. Only the *upload* of a topology result is licence-checked; the scan
itself is not.

### What the automation does about it

The `cydeploy_community` role denies the three agent binaries
(`CyDefenseService.exe`, `CyDefenseTray.exe`, `CyDefenseImagingHelper.exe`) any
outbound path at all, for every protocol and every profile, with local Windows
Firewall rules named `CRC-CYDEPLOY-GUARD-*`. All four labs are host-local —
application inventory and discovery read the registry, WMI and local services,
the CVE match is a string match against a local dataset, SI-M5-L3 reads the
local Spooler service, SC-M5-L1 reads the local firewall — so the agent needs no
network and loses nothing. A student scan of any CIDR now returns an empty
result instead of a sweep.

The guard rules are deliberately **not** in the `P<NN>-CYDEPLOY-*` namespace that
SC-M5-L1 seeds and its reset deletes, so a student firewall exercise cannot
remove the guard and the reset cannot either. They are outbound and
program-scoped, so RDP, WinRM, AD authentication and Guacamole are untouched.

Install does not report success until it has read back `Online`, `Insights`, the
service state, the imaging helper's start type and the guard rule count, and
asserted each is as approved. A pod that comes up any other way fails the job
and should be treated as unsafe for student use until corrected or removed.

### What this does not prove

The student is a local administrator on their own pod member server — the
SC-M5-L1 firewall exercise requires it — so a determined student could delete a
guard rule. The guard is a control against the agent and against casual misuse,
not a sandbox around an administrator. The structural boundary remains the pod's
own network segment plus the shared DCs' own hardening, exactly as before
CyDeploy existed. Worth raising with the vendor: a pipe that accepts
`scan_network` from `BUILTIN\Users` is a privilege boundary problem in their
product, not in this lab.

## Session recording exists, and is not covered by the Insights opt-in

Undocumented in the vendor's agent page: the agent can record a student's
session. It ships `Accord.Video.FFMPEG` and has a Learning mode that captures
screenshots and screen video, packages them with the behavioural event stream and
uploads them —

```text
RunStartLearning: started UserInsight capture for learning.
RunStartLearning: session {0} capturing continuously until stopped.
Command [learning_artifacts]: session {0} sent {1} folders
Command [replay_results]: accepted results for run {0} (nav={1}, func={2}, steps={3}).
```

— with a data model that includes `keyEvents`, `mouseEvents`, `navigations`,
`steps`, `focusSeconds` and window titles. The web platform's own configuration
confirms the shape: it drops `key_down,key_up,mouse_down,mouse_up,mouse_wheel`
*centrally* while noting they are "still captured locally for Learning".

Two things matter here. Learning is started by a server-pushed job
(`ExecuteAgentJob[startLearning]`), so an offline, unenrolled agent cannot be
asked to record — which is the posture the role installs. And the
`RunStartLearningAsync` path calls `EnsureInsightUploaderRunning()` without
reading the `Insights` flag first, so `Insights=0` does not by itself prevent
recording; only the absence of a server does. That is the strongest argument for
`ONLINE_MODE=0` with no enrollment token: screen-recording a student is not
something a vendor job queue should be able to turn on.

## A self-hosted server exists — relevant, but not on a pod

`CyDeployWebSetup-1.0.16226.940.msi` (SHA-256
`68b3006f1858cad02100bd32c8cbc75cece7effccfe84ac68e71a8e07c875e98`, product code
`{ED1FBA12-5A17-4ADE-9039-E78B35D66AC9}`) is the on-premise half: an ASP.NET
Core API as the `CyDeployApi` service plus an Angular portal, over SQL Server.

It answers the question the agent documentation does not — what the agent talks
to when it has no internet. Its API default port is `57523`, exactly the agent's
built-in `APIURL` default, so a lab-local server is the intended offline
topology, and the vendor's own configuration comment states the entitlement
worker makes no outbound calls until a tenant token is configured (their claim,
unverified here).

Not in scope for this rollout, and it must not be installed on a pod or on a
domain controller: it wants IIS/Kestrel, SQL Server and a certificate, and the
install is driven by `CyDeploySetup.exe` with `/SqlServer /SqlDatabase /ApiPort
/PortalPort /ServiceAccount /ServicePassword /AdminPassword /EnableSsl
/SslCertThumbprint /ApiUrl /WebUrl`. If enrolled agents are ever wanted, it
needs its own VM and its own decision, and it would re-open everything
`ONLINE_MODE=0` currently closes — including Learning.

## CVE data does not ship with the installer

The CVE scan reads `C:\ProgramData\CyDefense\cvelistv5`, which the service seeds
on start from a `cvelistv5.zip` or `cvelistv5\` tree in its install directory:

```text
CVE seed skipped: no cvelistv5.zip or cvelistv5\ found in install directory.
```

Neither is in the MSI, and the in-product refresh (`update_cve_db`) is a
`git clone https://github.com/CVEProject/cvelistV5.git`, which a pod cannot
reach and which would be several gigabytes if it could. So on a pod as shipped,
`cve_scan` produces an empty report, and SI-M5-L2 would grade an empty finding
set as a pass-looking result.

The role therefore takes `cydeploy_cve_dataset_src`: stage a `cvelistv5.zip` on
the control node, the role drops it in the install directory, and the service
seeds it offline on first start. Until a dataset is staged, SI-M5-L2 must be
treated as not deliverable — matching is also substring-based, not
version-aware, so its findings are suggestive rather than authoritative and the
student worksheet says so.

## Still unverified before the pilot

Static analysis cannot answer these; the Pod19/Pod20 pilot must:

- that `/qn` install and product-code removal behave as read, and that removal
  leaves no service, no `C:\ProgramData\CyDefense` and no guard rules;
- that the service starts and stays running with `Online=0` and no enrollment;
- that discovery, application inventory and CVE scan produce usable exports with
  no network at all;
- that the guard rules survive an agent restart, an MSI repair, and a full
  SC-M5-L1 seed/verify/reset cycle;
- disk cost of an install plus repeated scans against `cydeploy_min_free_gb`.

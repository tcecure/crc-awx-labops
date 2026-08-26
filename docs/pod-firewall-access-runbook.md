# Pod firewall (pfSense) access runbook

How students reach their pod's pfSense web UI for the SC labs, and how to
recover it when a pod's firewall looks unreachable.

## Access path

Students open `http://10.51.XX.1` in a browser **inside their `PODXX-DC`
Guacamole desktop**. There is no Guacamole tile for the firewall: guacd
supports RDP, VNC, SSH and telnet only, so a connection stored with protocol
`http` fails at tunnel creation and, with `autoretry` set, loops. guacd logs it
as:

```
guacd[...]: WARNING: Support for protocol "http" is not installed
```

The twenty `PODXX-GW` connections created that way are hidden from students
(their `READ` permission was removed; the connection rows and `guacadmin`
permissions remain, so the tiles can be restored if a supported protocol is
ever configured).

## Network path

The Guacamole gateway VM (VMID 100) is also the pod router. Each pod has two
networks on the same bridge `podXXnet`:

| Network | Purpose | Router address |
| --- | --- | --- |
| `10.50.XX.0/24` | Windows hosts (DC01 at `10.50.1.10`, `PODXX-SRV`) | `10.50.XX.1` on VM 100 |
| `10.51.XX.0/24` | pfSense LAN, UI at `10.51.XX.1` | `10.51.XX.2` on VM 100 |

`scripts/pod-routing.sh` runs on VM 100 (installed at
`/usr/local/sbin/pod-routing.sh`, applied at boot by `pod-routing.service`). It
adds the `10.51.XX.2/24` router address, SNATs traffic entering a pod's
firewall network to that address, and permits forwarding **only between the
matching pod's two networks**, so pods cannot reach each other.

Shared DC01 is the one exception: because every student shares that host, it is
allowed to reach `10.51.XX.1` for all pods. Per-pod isolation of firewall
access returns once students move to their own `PODXX-SRV` member servers, at
which point the `10.50.1.10` exception rules should be dropped from the script.

## Verifying

From DC01 (or a pod member server):

```powershell
Invoke-WebRequest -Uri http://10.51.6.1/ -UseBasicParsing -TimeoutSec 10 | Select-Object StatusCode
```

From pve1, check every pod firewall at once:

```bash
for i in $(seq 1 20); do
  printf 'pod%02d %s\n' "$i" "$(curl -s -o /dev/null -w '%{http_code}' --max-time 6 "http://10.51.$i.1/")"
done
```

All twenty should return `200`.

## Recovering a wedged gateway

Pod gateway VMs (VMIDs 300–319) can end up "running" in `qm list` while their
QMP socket is dead and the firewall answers nothing. `qm reset` then fails with
a QMP timeout. Kill the KVM process using the PID from `qm list` — the `.pid`
file is unreliable in this state — and start the VM again:

```bash
pid=$(qm list | awk -v v=305 '$1==v {print $6}')
kill -9 "$pid"; sleep 4; qm start 305
```

Give pfSense about a minute to boot, then re-run the curl loop above.

## Recovering a pod firewall a student locked themselves out of

Symptom: the student reports `10.51.XX.1` is unreachable ("Destination host
unreachable") while the VM is running, and `ping 10.51.XX.1` from pve1 fails
with no ARP entry (`ip neigh show dev podXXnet` shows `FAILED`). Cause is a
student deleting the LAN interface assignment or all firewall rules from
**Interfaces** / **Firewall → Rules** — pfSense then boots WAN-only, so nothing
on the pod network can reach it.

pfSense writes the previous configuration to `/cf/conf/backup/config-<epoch>.xml`
before every save, so the state from just before the mistake is recoverable from
the console. There is no network path in, so drive the VGA console with
`qm sendkey` and read it back with `qm screendump` (helper scripts live in this
repo's `scripts/` directory as `pf-console-type.py` / `pf-console-shot.sh`).

1. Confirm what was lost:

   ```sh
   # console option 8 (Shell)
   echo lan=$(grep -c '<lan>' /cf/conf/config.xml) rules=$(grep -c '<rule>' /cf/conf/config.xml)
   ```

   `lan=1 rules=0` means both the LAN interface and the rules are gone.

2. Pick the newest backup that still has the LAN interface and the student's
   rules:

   ```sh
   for f in $(ls -t /cf/conf/backup/config-*.xml | head -8); do
     echo $f lan=$(grep -c '<lan>' $f) r=$(grep -c '<rule>' $f)
   done
   ```

3. Restore it, keeping the broken copy for the incident record, and reboot:

   ```sh
   cp /cf/conf/config.xml /root/broken-config-$(date +%s).xml
   cp /cf/conf/backup/config-<epoch>.xml /cf/conf/config.xml
   rm -f /tmp/config.cache
   reboot
   ```

4. Verify from pve1 — `ping 10.51.XX.1` answers and
   `curl -o /dev/null -w '%{http_code}' http://10.51.XX.1/` returns `200`.

The webConfigurator password is part of the restored configuration, so the
instructor-provided credentials keep working. The student resumes the lab from
whatever state that backup captured; tell them which of their rules survived.

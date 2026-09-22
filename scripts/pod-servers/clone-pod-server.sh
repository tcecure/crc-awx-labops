#!/bin/bash
# Clone the Windows Server 2022 template into a pod member server and boot it with
# the offline first-boot bootstrap already injected. Run on the Proxmox host as root.
#
# Usage: echo -n "<bootstrap-password>" | clone-pod-server.sh <pod_id>
#
# The template has no known local Administrator password and the pod networks have
# no DHCP, so the clone cannot be configured interactively. Instead the bootstrap is
# written straight into the clone's disk: a script under C:\Windows\Temp plus an
# auto-start service registration in the offline SYSTEM hive. On first boot it sets
# the static address, creates the local crcsvc account AWX authenticates with,
# enables WinRM and Remote Desktop, then deletes itself. Everything after that is
# done by playbooks/provision-pod-server.yml.
set -euo pipefail

POD="$1"
PW="$(cat)"

TEMPLATE_VMID="${TEMPLATE_VMID:-102}"
POD2="$(printf '%02d' "$POD")"
VMID="$((400 + POD))"
NAME="POD${POD2}-SRV"
BRIDGE="pod${POD2}net"
IP="10.50.${POD}.20"
GW="10.50.${POD}.1"
HERE="$(cd "$(dirname "$0")" && pwd)"

if qm status "$VMID" >/dev/null 2>&1; then
  echo "VM $VMID already exists; refusing to clobber it" >&2
  exit 1
fi

qm clone "$TEMPLATE_VMID" "$VMID" --name "$NAME" --full 1
qm set "$VMID" \
  --cores 2 \
  --memory 4096 \
  --net0 "e1000,bridge=${BRIDGE},firewall=0" \
  --ide2 none,media=cdrom \
  --onboot 1 \
  --agent 1

printf '%s' "$PW" | TMPL="${HERE}/firstboot.ps1.tmpl" "${HERE}/inject-firstboot.sh" "$VMID" "$IP" "$GW"
qm start "$VMID"
echo "started ${NAME} vmid=${VMID} ip=${IP} bridge=${BRIDGE}"

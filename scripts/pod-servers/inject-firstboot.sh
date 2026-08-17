#!/bin/bash
# Offline-inject the CRC first-boot bootstrap into a stopped Windows clone's disk.
# Usage: inject.sh <vmid> <ip> <gw>
# Reads the bootstrap password from stdin so it never appears in argv or logs.
set -euo pipefail
VMID="$1"; IP="$2"; GW="$3"
PW="$(cat)"

LV="/dev/pve/vm-${VMID}-disk-1"
MNT="/mnt/crc-inject-${VMID}"

lvchange -ay "pve/vm-${VMID}-disk-1"
LO="$(losetup -f -P --show "$LV")"
mkdir -p "$MNT"
mount -t ntfs-3g -o rw "${LO}p3" "$MNT"

cleanup() {
  umount "$MNT" 2>/dev/null || true
  losetup -d "$LO" 2>/dev/null || true
  rmdir "$MNT" 2>/dev/null || true
}
trap cleanup EXIT

sed -e "s|__IP__|${IP}|g" -e "s|__GW__|${GW}|g" \
  ${TMPL:-/root/crc-podsrv/firstboot.ps1.tmpl} > "${MNT}/Windows/Temp/crc-firstboot.ps1"
printf '%s' "$PW" > "${MNT}/Windows/Temp/crc-bootstrap.dat"

cat > /tmp/crc-svc-${VMID}.reg <<'REG'
Windows Registry Editor Version 5.00

[\\ControlSet001\Services\CRCFirstBoot]
"Type"=dword:00000010
"Start"=dword:00000002
"ErrorControl"=dword:00000000
"DisplayName"="CRC Lab First Boot"
"ObjectName"="LocalSystem"
"ImagePath"="C:\\Windows\\System32\\cmd.exe /c start \"CRCFirstBoot\" /min C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\\Windows\\Temp\\crc-firstboot.ps1"
REG

printf 'y\n' | reged -I "${MNT}/Windows/System32/config/SYSTEM" "\\\\" /tmp/crc-svc-${VMID}.reg
rm -f /tmp/crc-svc-${VMID}.reg

sync
echo "injected vmid=${VMID} ip=${IP}"

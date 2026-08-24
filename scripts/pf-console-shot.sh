#!/bin/bash
# Capture a pod gateway's VGA console as a PNG, for recovery work when the
# firewall has no reachable network path.
#
# usage: pf-console-shot.sh <vmid> [outname] [ssh-host]
set -euo pipefail
VMID=$1
OUT=${2:-console}
HOST=${3:-pve1}
ssh "$HOST" "echo 'screendump /tmp/${OUT}.ppm' | sudo qm monitor $VMID >/dev/null; sudo cp /tmp/${OUT}.ppm /tmp/${OUT}_r.ppm; sudo chmod 644 /tmp/${OUT}_r.ppm"
scp -q "$HOST:/tmp/${OUT}_r.ppm" "./${OUT}.ppm"
python3 -c "from PIL import Image; Image.open('./${OUT}.ppm').save('./${OUT}.png')"
echo "./${OUT}.png"

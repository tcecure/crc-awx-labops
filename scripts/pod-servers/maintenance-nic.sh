#!/usr/bin/env bash
# Attaches or detaches a temporary maintenance NIC on pod member servers.
#
# A pod member server only has a NIC on its own isolated pod bridge, and the pod
# gateway denies outbound traffic (that default deny is graded student work, so
# it is never relaxed for our convenience). That leaves the server with no path
# to Windows Update or the Defender signature service, which is why patching has
# to happen through a second NIC on the management bridge that exists only for
# the length of the patch window.
#
# Run on the Proxmox host:
#   ./maintenance-nic.sh attach 3 4 5     # before "Patch Pod Member Server"
#   ./maintenance-nic.sh detach 3 4 5     # immediately after it finishes
#
# Detach is what puts the server back into pod isolation, so it is never
# optional: a server must not be handed to a student while it can still reach
# the management network.
set -euo pipefail

ACTION="${1:-}"
shift || true

if [[ "$ACTION" != "attach" && "$ACTION" != "detach" ]] || [[ $# -eq 0 ]]; then
  echo "usage: $0 {attach|detach} POD [POD...]" >&2
  exit 64
fi

BRIDGE="${MAINTENANCE_BRIDGE:-vmbr0}"

for pod in "$@"; do
  vmid="$((400 + pod))"
  name="POD$(printf '%02d' "$pod")-SRV"

  if ! qm config "$vmid" >/dev/null 2>&1; then
    echo "$name (vmid $vmid): no such VM, skipping" >&2
    continue
  fi

  if [[ "$ACTION" == "attach" ]]; then
    if qm config "$vmid" | grep -q '^net1:'; then
      echo "$name: maintenance NIC already attached"
      continue
    fi
    qm set "$vmid" --net1 "e1000,bridge=${BRIDGE},firewall=0" >/dev/null
    echo "$name: maintenance NIC attached to ${BRIDGE}"
  else
    if ! qm config "$vmid" | grep -q '^net1:'; then
      echo "$name: no maintenance NIC to remove"
      continue
    fi
    qm set "$vmid" --delete net1 >/dev/null
    echo "$name: maintenance NIC removed, back to pod isolation only"
  fi
done

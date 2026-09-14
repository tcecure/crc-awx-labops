#!/usr/bin/env bash
# Installs or updates local_drccops on the DigitalRCC Moodle host.
#
# The LMS VM is only reachable through pve1, so the plugin travels as a base64
# tarball over a nested ssh session. Nothing here touches Moodle data: the
# plugin ships read-only web service functions and the upgrade step only
# registers them.
#
# Usage: ./deploy-local-drccops.sh [--dry-run]

set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/local_drccops"
JUMP_HOST="${DRCC_LMS_JUMP:-pve1}"
LMS_HOST="${DRCC_LMS_HOST:-devin-adm@192.168.1.169}"
MOODLE_ROOT="${DRCC_MOODLE_ROOT:-/var/www/moodle}"
DRY_RUN=0

if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=1
fi

if [[ ! -f "${PLUGIN_DIR}/version.php" ]]; then
  echo "plugin source not found at ${PLUGIN_DIR}" >&2
  exit 1
fi

PAYLOAD="$(tar -C "$(dirname "${PLUGIN_DIR}")" -czf - local_drccops | base64 -w0)"

if [[ "${DRY_RUN}" -eq 1 ]]; then
  echo "would ship $(printf '%s' "${PAYLOAD}" | wc -c) base64 bytes to ${LMS_HOST}:${MOODLE_ROOT}/local/drccops"
  exit 0
fi

REMOTE_SCRIPT=$(cat <<REMOTE
set -euo pipefail
umask 022
printf '%s' "\${PAYLOAD}" | base64 -d > /tmp/local_drccops.tgz
sudo -n rm -rf ${MOODLE_ROOT}/local/drccops
sudo -n tar -C ${MOODLE_ROOT}/local -xzf /tmp/local_drccops.tgz
sudo -n mv ${MOODLE_ROOT}/local/local_drccops ${MOODLE_ROOT}/local/drccops
sudo -n chown -R root:root ${MOODLE_ROOT}/local/drccops
rm -f /tmp/local_drccops.tgz
cd ${MOODLE_ROOT}
sudo -n -u www-data php admin/cli/upgrade.php --non-interactive
sudo -n -u www-data php admin/cli/purge_caches.php
REMOTE
)

# shellcheck disable=SC2029
ssh "${JUMP_HOST}" "ssh ${LMS_HOST} 'PAYLOAD=${PAYLOAD} bash -s'" <<< "${REMOTE_SCRIPT}"

echo "local_drccops deployed. Add the two functions to the DigitalRCC Portal (read only) external service"
echo "and allow local/drccops:viewactivity on the DigitalRCC Portal Read Only role."

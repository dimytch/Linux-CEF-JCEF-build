#!/usr/bin/env bash
# Install systemd unit to autostart PSP after xorg-nvidia.service on boot.
#
# Usage (on AWS PSP VM, from ~/psp):
#   ./install-psp-service.sh
#   ./install-psp-service.sh --start
#
# Options:
#   --start     Enable and start psp.service immediately
#   --user U    Service user (default: owner of PSP_HOME, or $USER)
#   --home DIR  PSP deploy directory (default: script directory)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PSP_HOME="${PSP_HOME:-${SCRIPT_DIR}}"
PSP_USER="${PSP_USER:-$(stat -c '%U' "${PSP_HOME}" 2>/dev/null || echo "${USER}")}"
PSP_GROUP="${PSP_GROUP:-$(id -gn "${PSP_USER}" 2>/dev/null || echo "${PSP_USER}")}"
DO_START=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --start) DO_START=1; shift ;;
    --user) PSP_USER="$2"; shift 2 ;;
    --home) PSP_HOME="$2"; shift 2 ;;
    -h|--help)
      sed -n '2,12p' "$0"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

TEMPLATE="${SCRIPT_DIR}/psp.service.template"
UNIT_PATH="/etc/systemd/system/psp.service"

if [[ ! -f "${TEMPLATE}" ]]; then
  echo "ERROR: ${TEMPLATE} not found"
  exit 1
fi

if [[ ! -x "${PSP_HOME}/startup-psp.sh" ]]; then
  echo "ERROR: ${PSP_HOME}/startup-psp.sh not found or not executable"
  echo "  chmod +x ${PSP_HOME}/startup-psp.sh"
  exit 1
fi

if [[ ! -f "${PSP_HOME}/psp.jar" ]]; then
  echo "WARN: ${PSP_HOME}/psp.jar not found — service will fail until deployed"
fi

if ! systemctl is-enabled xorg-nvidia.service >/dev/null 2>&1; then
  echo "WARN: xorg-nvidia.service is not enabled. Enable it first:"
  echo "  sudo systemctl enable xorg-nvidia.service"
fi

echo "Installing psp.service"
echo "  PSP_HOME=${PSP_HOME}"
echo "  PSP_USER=${PSP_USER}"
echo "  PSP_GROUP=${PSP_GROUP}"

TMP="$(mktemp)"
sed \
  -e "s|@PSP_HOME@|${PSP_HOME}|g" \
  -e "s|@PSP_USER@|${PSP_USER}|g" \
  -e "s|@PSP_GROUP@|${PSP_GROUP}|g" \
  "${TEMPLATE}" > "${TMP}"

sudo cp "${TMP}" "${UNIT_PATH}"
rm -f "${TMP}"

sudo systemctl daemon-reload
sudo systemctl enable psp.service

echo ""
echo "Installed: ${UNIT_PATH}"
echo "Enabled:   psp.service (starts after xorg-nvidia.service on boot)"

if [[ "${DO_START}" -eq 1 ]]; then
  echo ""
  sudo systemctl start psp.service
  sleep 2
  sudo systemctl status psp.service --no-pager -l || true
else
  echo ""
  echo "Start now:  sudo systemctl start psp.service"
  echo "Logs:       journalctl -u psp.service -f"
fi

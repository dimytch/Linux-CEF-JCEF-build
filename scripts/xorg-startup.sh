#!/usr/bin/env bash
set -u

DISPLAY_NUM="${DISPLAY_NUM:-0}"
XVT="${XVT:-7}"
XCONF="/etc/X11/xorg.conf"

if [[ ! -f "${XCONF}" ]]; then
  echo "ERROR: ${XCONF} missing. Run:"
  echo "  sudo nvidia-xconfig --allow-empty-initial-configuration"
  exit 1
fi

if ! nvidia-smi >/dev/null 2>&1; then
  echo "ERROR: nvidia-smi failed"
  exit 1
fi

echo "Stopping old X..."
sudo systemctl stop xorg-nvidia 2>/dev/null || true
sudo pkill -9 -f Xorg 2>/dev/null || true
sleep 2
sudo rm -f "/tmp/.X${DISPLAY_NUM}-lock" "/tmp/.X11-unix/X${DISPLAY_NUM}"

echo "Starting Xorg via systemd-run (detached from SSH)..."
sudo systemd-run \
  --unit=xorg-manual \
  --property=Type=forking \
  --property=KillMode=process \
  /bin/sh -c "/usr/lib/xorg/Xorg :${DISPLAY_NUM} vt${XVT} -config ${XCONF} -ac -noreset -nolisten tcp </dev/null >>/var/log/Xorg.${DISPLAY_NUM}.log 2>&1 &"

sleep 3

if pgrep -f "[X]org :${DISPLAY_NUM}" >/dev/null 2>&1; then
  echo "OK: Xorg running on :${DISPLAY_NUM}"
  pgrep -af "[X]org :${DISPLAY_NUM}"
  echo ""
  echo "Run verify:  ./verify-xorg.sh"
else
  echo "ERROR: Xorg not running. Log:"
  sudo tail -40 "/var/log/Xorg.${DISPLAY_NUM}.log"
  exit 1
fi
#!/usr/bin/env bash
set -u

export DISPLAY="${DISPLAY:-:0}"
export __EGL_VENDOR_LIBRARY_FILENAMES=/usr/share/glvnd/egl_vendor.d/10_nvidia.json

echo "DISPLAY=${DISPLAY}"
echo ""

if ! timeout 5 xdpyinfo >/dev/null 2>&1; then
  echo "ERROR: cannot connect to ${DISPLAY} (xdpyinfo timeout)"
  exit 1
fi

echo "=== glxinfo (10s timeout) ==="
OUT="$(timeout 10 glxinfo -B 2>/dev/null | grep -E 'OpenGL vendor|OpenGL renderer' || true)"
echo "${OUT}"

if echo "${OUT}" | grep -qi llvmpipe; then
  echo ""
  echo "FAIL: software rendering (llvmpipe). NVIDIA X not active."
  echo "Check: sudo tail -50 /var/log/Xorg.0.log"
  exit 1
fi

if echo "${OUT}" | grep -qi nvidia; then
  echo ""
  echo "PASS: NVIDIA GPU active"
  exit 0
fi

echo "FAIL: unexpected GL vendor"
exit 1
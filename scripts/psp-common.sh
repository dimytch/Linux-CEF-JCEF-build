#!/usr/bin/env bash
# Shared environment and pre-flight checks for PSP on AWS Ubuntu (NVIDIA T4 + Xorg :0).
# Sourced by startup-osr-probe.sh, run-probe-stress.sh, startup-psp.sh

# Do not use set -u here — caller may not have all vars set yet.

psp_script_dir() {
  cd "$(dirname "${BASH_SOURCE[1]}")" && pwd
}

PSP_HOME="${PSP_HOME:-$(psp_script_dir)}"

export DISPLAY="${DISPLAY:-:0}"
export __EGL_VENDOR_LIBRARY_FILENAMES="${__EGL_VENDOR_LIBRARY_FILENAMES:-/usr/share/glvnd/egl_vendor.d/10_nvidia.json}"
export NO_PROXY="${NO_PROXY:-localhost,127.0.0.1}"
export no_proxy="${no_proxy:-localhost,127.0.0.1}"

psp_apply_exports() {
  echo "Apply exports..."
  echo "DISPLAY=${DISPLAY}"
  echo "__EGL_VENDOR_LIBRARY_FILENAMES=${__EGL_VENDOR_LIBRARY_FILENAMES}"
}

psp_ensure_xorg() {
  if pgrep -f '[X]org :0' >/dev/null 2>&1; then
    return 0
  fi
  echo "Xorg :0 not running — trying systemctl start xorg-nvidia..."
  if systemctl is-enabled xorg-nvidia.service >/dev/null 2>&1; then
    sudo systemctl start xorg-nvidia.service || true
    sleep 2
  fi
  if ! pgrep -f '[X]org :0' >/dev/null 2>&1; then
    echo "ERROR: Xorg on ${DISPLAY} is not running."
    echo "  sudo systemctl status xorg-nvidia.service"
    return 1
  fi
  return 0
}

psp_preflight() {
  echo ""
  echo "=== PRE-FLIGHT Check ==="
  echo "DISPLAY=${DISPLAY}"
  echo "PSP_HOME=${PSP_HOME}"
  echo ""

  if ! command -v java >/dev/null 2>&1; then
    echo "ERROR: java not found. Install Temurin JDK 21."
    return 1
  fi
  echo "--- java ---"
  java -version 2>&1 | head -1

  if command -v nvidia-smi >/dev/null 2>&1; then
    echo ""
    echo "--- nvidia-smi ---"
    nvidia-smi --query-gpu=name,driver_version --format=csv,noheader 2>/dev/null || nvidia-smi | head -3
  fi

  echo ""
  echo "Check Xorg..."
  if ! psp_ensure_xorg; then
    return 1
  fi
  ps aux | grep '[X]org :0' | head -1

  if command -v glxinfo >/dev/null 2>&1; then
    echo ""
    echo "--- glxinfo vendors ---"
    local gl_out
    gl_out="$(timeout 10 glxinfo -B 2>/dev/null | grep -E 'OpenGL vendor|OpenGL renderer' || true)"
    echo "${gl_out}"
    if echo "${gl_out}" | grep -qi llvmpipe; then
      echo "ERROR: software rendering (llvmpipe). NVIDIA X is not active."
      return 1
    fi
    if ! echo "${gl_out}" | grep -qi nvidia; then
      echo "WARN: glxinfo does not report NVIDIA — CEF GPU path may fail."
    fi
  else
    echo "WARN: glxinfo not installed (sudo apt install mesa-utils)"
  fi

  return 0
}

psp_kill_previous() {
  echo ""
  echo "Kill previous processes..."
  pkill -9 -f jcef_helper 2>/dev/null || true
  pkill -9 -f 'com.playtech.psp.CefOsrProbe' 2>/dev/null || true
  pkill -9 -f 'com.playtech.psp.EntryPoint' 2>/dev/null || true
  pkill -9 -f 'psp.jar' 2>/dev/null || true
  sleep 1
}

psp_clear_cef_cache() {
  if [[ "${CLEAR_CEF_CACHE:-1}" == "1" ]]; then
    echo "Clear CEF cache..."
    rm -rf "${PSP_HOME}/java/jcef/cache"/* 2>/dev/null || true
  fi
}

psp_java_cmd() {
  PSP_JAVA_CMD=(java)
  if [[ -n "${JAVA_OPTS:-}" ]]; then
    # shellcheck disable=SC2206
    PSP_JAVA_CMD+=(${JAVA_OPTS})
  fi
}

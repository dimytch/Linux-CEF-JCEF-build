#!/usr/bin/env bash
# Start full PSP application on AWS Ubuntu (NVIDIA T4 + Xorg :0).
# Copy to ~/psp alongside psp.jar, lib/, and optionally psp.env.
#
# Usage:
#   ./startup-psp.sh
#
# JVM options — configure in one of three ways (highest priority first):
#   1. Export JAVA_OPTS before run (replaces all built-in options)
#   2. Create psp.env next to this script (see psp.env.example)
#   3. Edit the defaults in the "JVM configuration" section below
#
# Environment (optional):
#   PSP_HOME          Deploy directory (default: script directory)
#   JAVA_OPTS         Full JVM flag string (skips auto-build if set)
#   CLEAR_CEF_CACHE   1 to clear JCEF cache before start (default: 1)
#
# Note: TomcatService defaults to port 80 without -Dtomcat.port (requires root on Linux).
#       -Djava.awt.headless=false is required for JCEF with DISPLAY=:0 (not headless X11).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Optional local overrides (PSP_XMS, PSP_XMX, PSP_TOMCAT_PORT, PSP_JAVA_OPTS_EXTRA, …)
if [[ -f "${SCRIPT_DIR}/psp.env" ]]; then
  # shellcheck source=/dev/null
  source "${SCRIPT_DIR}/psp.env"
fi

# --- JVM configuration (edit defaults here) ---
: "${PSP_XMS:=512m}"
: "${PSP_XMX:=2g}"
: "${PSP_TOMCAT_PORT:=8080}"
: "${PSP_AWT_HEADLESS:=false}"
# Extra JVM flags appended after the options above, e.g. -XX:+HeapDumpOnOutOfMemoryError
: "${PSP_JAVA_OPTS_EXTRA:=}"

psp_build_java_opts() {
  if [[ -n "${JAVA_OPTS:-}" ]]; then
    return 0
  fi
  JAVA_OPTS="-Xms${PSP_XMS} -Xmx${PSP_XMX}"
  JAVA_OPTS+=" -Djava.awt.headless=${PSP_AWT_HEADLESS}"
  JAVA_OPTS+=" -Dtomcat.port=${PSP_TOMCAT_PORT}"
  if [[ -n "${PSP_JAVA_OPTS_EXTRA}" ]]; then
    JAVA_OPTS+=" ${PSP_JAVA_OPTS_EXTRA}"
  fi
  export JAVA_OPTS
}

# shellcheck source=psp-common.sh
source "${SCRIPT_DIR}/psp-common.sh"

psp_apply_exports

if ! psp_preflight; then
  exit 1
fi

if [[ ! -f "${PSP_HOME}/psp.jar" ]]; then
  echo "ERROR: ${PSP_HOME}/psp.jar not found"
  exit 1
fi

if [[ ! -d "${PSP_HOME}/lib" ]]; then
  echo "ERROR: ${PSP_HOME}/lib not found"
  exit 1
fi

psp_kill_previous
psp_clear_cef_cache

psp_build_java_opts
psp_java_cmd

echo ""
echo "=== Starting PSP... ==="
echo "JAVA_OPTS=${JAVA_OPTS}"
exec "${PSP_JAVA_CMD[@]}" -jar "${PSP_HOME}/psp.jar" "$@"

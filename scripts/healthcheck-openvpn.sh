#!/bin/sh
# Enhanced healthcheck: validate processes, tun0, SOCKS port, and (optionally) OpenVPN init log.
set -eu

PORT="${SOCKS5_PORT:-1080}"
STRICT="${HEALTHCHECK_STRICT:-0}"
LOGFILE="${OPENVPN_LOG:-/var/log/openvpn.log}"

# 1) processes
if ! pidof openvpn >/dev/null 2>&1; then
  echo "openvpn not running"
  exit 1
fi
if ! pidof sockd >/dev/null 2>&1; then
  echo "sockd not running"
  exit 1
fi

# 2) interface
if ! ip link show dev tun0 >/dev/null 2>&1; then
  echo "tun0 missing"
  exit 1
fi

# 3) socks port listening
if ! ss -lnt 2>/dev/null | grep -q ":${PORT} "; then
  echo "sockd port ${PORT} not listening"
  exit 1
fi

# 4) optional strict check: require init sequence completed in log
case "${STRICT}" in
  1|true|TRUE|yes|YES)
    if [ ! -f "$LOGFILE" ] || ! grep -q "Initialization Sequence Completed" "$LOGFILE" 2>/dev/null; then
      echo "openvpn not initialized (no 'Initialization Sequence Completed' in log)"
      exit 1
    fi
  ;;
esac

exit 0

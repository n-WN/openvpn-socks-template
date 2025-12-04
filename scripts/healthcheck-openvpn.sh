#!/bin/sh
# Simple healthcheck: ensures tun0 exists and OpenVPN pid is alive.
set -eu

if ! pidof openvpn >/dev/null 2>&1; then
  echo "openvpn not running"
  exit 1
fi

if ip link show dev tun0 >/dev/null 2>&1; then
  exit 0
fi

echo "tun0 missing"
exit 1

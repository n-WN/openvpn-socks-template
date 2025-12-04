#!/bin/sh
set -eu

log() {
  printf '[%s] %s\n' "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" "$*"
}

OPENVPN_CONFIG="${OPENVPN_CONFIG:-/vpn/client.ovpn}"
OPENVPN_AUTH_USER="${OPENVPN_AUTH_USER:-}"
OPENVPN_AUTH_PASS="${OPENVPN_AUTH_PASS:-}"
OPENVPN_EXTRA_ARGS="${OPENVPN_EXTRA_ARGS:-}"

SOCKS5_PORT="${SOCKS5_PORT:-1080}"
SOCKS5_BIND="${SOCKS5_BIND:-0.0.0.0}"
SOCKS5_USER="${SOCKS5_USER:-}"
SOCKS5_PASS="${SOCKS5_PASS:-}"

if [ ! -f "$OPENVPN_CONFIG" ]; then
  log "fatal: OPENVPN_CONFIG not found: $OPENVPN_CONFIG"
  exit 1
fi

mkdir -p /var/log /run /etc/dante
AUTH_FILE=""

if [ -n "$OPENVPN_AUTH_USER" ] || [ -n "$OPENVPN_AUTH_PASS" ]; then
  if [ -z "$OPENVPN_AUTH_USER" ] || [ -z "$OPENVPN_AUTH_PASS" ]; then
    log "fatal: both OPENVPN_AUTH_USER and OPENVPN_AUTH_PASS must be set for auth-user-pass"
    exit 1
  fi
  AUTH_FILE="/run/openvpn-auth.txt"
  {
    printf '%s\n' "$OPENVPN_AUTH_USER"
    printf '%s\n' "$OPENVPN_AUTH_PASS"
  } >"$AUTH_FILE"
  chmod 600 "$AUTH_FILE"
fi

gen_dante_config() {
  cat >/etc/dante/sockd.conf <<EOF
logoutput: stderr
internal: ${SOCKS5_BIND} port = ${SOCKS5_PORT}
external: *
socksmethod: $( [ -n "$SOCKS5_USER" ] && echo username || echo none )
clientmethod: none
user.privileged: root
user.notprivileged: nobody
user.libwrap: nobody
client pass {
  from: 0.0.0.0/0 to: 0.0.0.0/0
  log: error
}
sockd pass {
  from: 0.0.0.0/0 to: 0.0.0.0/0
  log: error
}
EOF
}

start_openvpn() {
  set -- openvpn --config "$OPENVPN_CONFIG" \
    --writepid /run/openvpn.pid \
    --log /var/log/openvpn.log \
    --daemon

  if [ -n "$AUTH_FILE" ]; then
    set -- "$@" --auth-user-pass "$AUTH_FILE"
  fi

  if [ -n "$OPENVPN_EXTRA_ARGS" ]; then
    # shellcheck disable=SC2086
    set -- "$@" $OPENVPN_EXTRA_ARGS
  fi

  log "starting openvpn with config $OPENVPN_CONFIG"
  "$@"
}

start_socks() {
  gen_dante_config
  if [ -n "$SOCKS5_USER" ] || [ -n "$SOCKS5_PASS" ]; then
    if [ -z "$SOCKS5_USER" ] || [ -z "$SOCKS5_PASS" ]; then
      log "fatal: both SOCKS5_USER and SOCKS5_PASS must be set for proxy auth"
      exit 1
    fi
    # create passwd entry for dante's username auth; uses /etc/passwd auth via system accounts
    adduser -D "$SOCKS5_USER" || true
    echo "$SOCKS5_USER:$SOCKS5_PASS" | chpasswd
  fi
  log "starting dante sockd on ${SOCKS5_BIND}:${SOCKS5_PORT}"
  exec sockd -f /etc/dante/sockd.conf -N 50 -D
}

start_openvpn

if [ -f /var/log/openvpn.log ]; then
  tail -n 20 /var/log/openvpn.log || true
fi

start_socks

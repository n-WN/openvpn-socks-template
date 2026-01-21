# OpenVPN-SOCKS5

Lightweight OpenVPN tunnel → SOCKS5 proxy container.

**Features:** Alpine-based, ~25MB image, built-in healthcheck, optional SOCKS5 auth, kill-switch support.

## Quick Start

```bash
# 1. Prepare VPN config in key/ directory
key/
├── client.ovpn
├── ca.crt, client.crt, client.key
└── auth.txt   # line1: username, line2: password (recommended)

# 2. Start
docker compose up -d

# 3. Use proxy
curl --socks5 localhost:1080 https://httpbin.org/ip
```

## Credentials

**Option 1: `key/auth.txt`** (recommended - supports special chars like `#`)
```
username
password
```

**Option 2: Environment variables**
```bash
cp .env.example .env
# Edit OPENVPN_AUTH_USER and OPENVPN_AUTH_PASS
```

> ⚠️ `.env` treats `#` as comment - passwords get truncated. Use `auth.txt` instead.

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| **OpenVPN** |||
| `OPENVPN_CONFIG` | `/vpn/client.ovpn` | Config file path |
| `OPENVPN_AUTH_FILE` | `/vpn/auth.txt` | Credentials file (priority over env) |
| `OPENVPN_AUTH_USER/PASS` | - | VPN credentials |
| `OPENVPN_EXTRA_ARGS` | - | Extra openvpn args |
| `OPENVPN_VERB` | `3` | Log verbosity (0-11) |
| **SOCKS5** |||
| `SOCKS5_PORT` | `1080` | Proxy port |
| `SOCKS5_USER/PASS` | - | Proxy authentication |
| `SOCKS_MAX_CONN` | `3` | Max concurrent connections |
| `SOCKS_LOG` | `error` | Log level (`error` or `connect error`) |
| **Security** |||
| `ENABLE_KILL_SWITCH` | `0` | iptables leak protection |
| `SOCKS_CLIENT_CIDRS` | `0.0.0.0/0` | Allowed client CIDRs |
| **DNS** |||
| `USE_VPN_DNS` | `1` | Use VPN-pushed DNS |
| `VPN_DNS` | - | Fallback DNS (comma-separated) |

## Docker Run

```bash
docker run -d --name openvpn-socks \
  --cap-add=NET_ADMIN \
  --device=/dev/net/tun \
  -p 1080:1080 \
  -v $(pwd)/key:/vpn:ro \
  openvpn-socks:lite
```

## Troubleshooting

```bash
# Check credentials
docker exec openvpn-socks cat /run/openvpn-auth.txt

# View logs
docker logs openvpn-socks
docker exec openvpn-socks cat /var/log/openvpn.log
```

| Issue | Cause | Fix |
|-------|-------|-----|
| `AUTH_FAILED` | Password with `#` truncated | Use `auth.txt` |
| `unhealthy` | tun0 not established | Check VPN config/network |
| `permission denied` | Stale container mount | `docker rm` then recreate |

## Security

- **Kill-Switch**: `ENABLE_KILL_SWITCH=1` - blocks traffic if VPN drops
- **SOCKS Auth**: Set `SOCKS5_USER/PASS` to require authentication
- **Client Restriction**: `SOCKS_CLIENT_CIDRS=192.168.0.0/16` limits source IPs

## Tips

- MTU issues: `OPENVPN_EXTRA_ARGS="--tun-mtu 1500 --mssfix 1460"`
- Stream logs: `STREAM_OPENVPN_LOG=1` pipes OpenVPN log to `docker logs`
- Strict healthcheck: `HEALTHCHECK_STRICT=1` requires `Initialization Sequence Completed`

# Lightweight OpenVPN + SOCKS5 proxy
FROM alpine:3.20

# microsocks 不在 Alpine 主仓库，使用 tinyproxy 版 socks（dante-server），同时保留 openvpn 依赖。
RUN apk add --no-cache \
      openvpn \
      iproute2 \
      iptables \
      dante-server \
      dumb-init

# Copy entrypoint and healthcheck scripts from scripts/
COPY scripts/entrypoint-openvpn-socks.sh /usr/local/bin/entrypoint-openvpn-socks.sh
COPY scripts/healthcheck-openvpn.sh /usr/local/bin/healthcheck-openvpn.sh

RUN chmod +x /usr/local/bin/entrypoint-openvpn-socks.sh /usr/local/bin/healthcheck-openvpn.sh

ENTRYPOINT ["dumb-init", "--", "/usr/local/bin/entrypoint-openvpn-socks.sh"]
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 CMD /usr/local/bin/healthcheck-openvpn.sh

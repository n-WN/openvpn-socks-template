# 极简可复现的 OpenVPN -> SOCKS5 容器

特点（对比 curve25519xsalsa20poly1305/docker-openvpn-socks5）：
- 更轻：基于 `alpine:3.20` + `openvpn` + `dante-server` + `dumb-init`，无额外 Go 代码/构建步骤。
- 更简单：单入口脚本，依赖仅 OpenVPN/MicroSocks；镜像构建快、攻击面小。
- 可选鉴权：`SOCKS5_USER/SOCKS5_PASS` 环境变量开启用户名密码。
- 健康检查：检测 `openvpn` 进程和 `tun0`。
- 完全参数化：支持 `OPENVPN_AUTH_USER/PASS`、`OPENVPN_EXTRA_ARGS`，易多实例。

## 构建镜像
在本目录下构建：
```bash
docker build -t openvpn-socks:lite .
```

## 使用 compose 运行
将 `config/vpn-profiles/<your-vpn-profile>` 挂载到容器 `/vpn`，`.ovpn` 内相对引用的 `ca/cert/key` 会自动生效。
注意：远程仓库不包含任何真实或示例的 `.ovpn/.crt/.key` 文件，仅提供目录结构（`config/vpn-profiles/sample/` 空目录）。

1) 复制 `.env` 示例并按需填写：
```bash
cp .env.example .env
# 编辑 .env 填写 OPENVPN_AUTH_USER/OPENVPN_AUTH_PASS（若需要）以及 SOCKS5_USER/PASS（如需鉴权）
```

2) 准备你的 VPN 配置目录（默认挂载空目录 `config/vpn-profiles/sample`，请将 `client.ovpn` 及所需证书放入其中），然后：
```bash
docker compose up -d
```

默认将宿主机 `EXPOSE_SOCKS5_PORT`(默认 1080) 映射到容器 `SOCKS5_PORT`(默认 1080)。

也可以直接 `docker run`（默认挂载空目录；需自行放置 `client.ovpn` 与证书）：
```bash
docker run -d --name ovpn-socks \
  --cap-add=NET_ADMIN \
  --device=/dev/net/tun \
  -p 1080:1080 \
  -v $(pwd)/config/vpn-profiles/sample:/vpn:ro \
  -e OPENVPN_CONFIG=/vpn/client.ovpn \
  -e OPENVPN_AUTH_USER=your_user \
  -e OPENVPN_AUTH_PASS=your_pass \
  -e SOCKS5_USER=proxyuser \   # 可选
  -e SOCKS5_PASS=proxypass \   # 可选
  -e SOCKS5_PORT=1080 \        # 可选
  openvpn-socks:lite
```

## 日志与健康检查
- OpenVPN 日志：默认写入 `/var/log/openvpn.log`（可通过 `OPENVPN_LOG` 指定），启动时会自动 `tail` 最近 80 行；也可将宿主机目录挂载到 `/var/log` 持久化。
- OpenVPN 详细程度：`OPENVPN_VERB`（默认 3），也可用 `OPENVPN_EXTRA_ARGS` 自定义（若两者同时指定，以 `EXTRA_ARGS` 内为准）。
- SOCKS 日志：`SOCKS_LOG`（默认 `error`，可设为 `connect error` 记录连接与错误）。最大并发 `SOCKS_MAX_CONN`（默认 50）。
- 健康检查：镜像内置 `HEALTHCHECK`，脚本检查：
  - `openvpn` 进程存在；
  - `sockd` 进程存在；
  - `tun0` 接口存在；
  - 指定 `SOCKS5_PORT` 监听成功；
  - 若 `HEALTHCHECK_STRICT=1`，额外要求日志包含 `Initialization Sequence Completed`。

示例（持久化日志并开启严格健康检查）：
```bash
docker compose run -d \
  -e HEALTHCHECK_STRICT=1 \
  -e OPENVPN_VERB=4 \
  -e SOCKS_LOG="connect error" \
  -v $(pwd)/logs:/var/log \
  openvpn-socks
```

## 环境变量
- `OPENVPN_CONFIG`：必填，容器内 ovpn 路径，默认 `/vpn/client.ovpn`。
- `OPENVPN_AUTH_USER` / `OPENVPN_AUTH_PASS`：可选，若服务端要求 `auth-user-pass`。
- `OPENVPN_EXTRA_ARGS`：可选，追加 OpenVPN 启动参数（如 `--verb 3 --auth-nocache`）。
- `SOCKS5_PORT`：SOCKS5 端口，默认 1080。
- `SOCKS5_BIND`：绑定地址，默认 `0.0.0.0`。
- `SOCKS5_USER` / `SOCKS5_PASS`：可选，设置后开启 SOCKS5 用户名密码认证。

## 健康检查
镜像内置 `HEALTHCHECK`：检查 `openvpn` 进程与 `tun0` 设备。失败时容器状态为 `unhealthy`，可配合编排重启策略。

## 对比优势
- 体积小、依赖少、构建快。
- 使用发行版 dante-server，稳定且支持用户名密码。
- 健康检查+参数化，适合多实例、一机多隧道。
- 安全性可控：可选 SOCKS5 鉴权，auth 文件在 `/run/`，权限 600。

## 小贴士
- OpenVPN 常见需求：若服务端 MTU 推送过大，添加环境 `OPENVPN_EXTRA_ARGS="--tun-mtu 1500 --mssfix 1460"`。
- 如需静态路由/iptables，可在编排层挂载额外脚本，通过 `OPENVPN_EXTRA_ARGS="--up /path/to/script.sh --route-noexec"` 等方式注入。

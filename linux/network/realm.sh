#!/usr/bin/env bash
# 开启 BBR + 安装 realm 端口转发并注册 systemd 服务
set -uo pipefail

# ---------- 提权：支持 bash <(curl ...) 直接运行 ----------
if [ "$(id -u)" -ne 0 ]; then
  if ! command -v sudo >/dev/null 2>&1; then
    echo "需要 root 权限运行，请切换到 root 用户后重试。" >&2
    exit 1
  fi
  # bash <(curl ...) 时 $0 是 /dev/fd/*，sudo 会关闭该 fd，所以先复制到临时文件
  SELF_TMP="$(mktemp /tmp/xcript-realm-XXXXXX.sh 2>/dev/null || echo "/tmp/xcript-realm-$$.sh")"
  if ! cat "$0" > "$SELF_TMP" 2>/dev/null; then
    echo "读取自身脚本失败，请先下载脚本到本地再运行。" >&2
    exit 1
  fi
  chmod +x "$SELF_TMP"
  echo ">>> 需要 root 权限，正在通过 sudo 重新执行..."
  exec sudo bash "$SELF_TMP" "$@"
fi

# ---------- 1. 开启 BBR ----------
echo "检查 BBR 是否启用..."
if [ "$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)" = "bbr" ]; then
  echo "BBR 已启用"
else
  echo "启用 BBR ..."
  # 先删掉历史遗留的重复行，保证重复执行也不会堆积
  touch /etc/sysctl.conf
  sed -i '/^net\.core\.default_qdisc=fq$/d; /^net\.ipv4\.tcp_congestion_control=bbr$/d' /etc/sysctl.conf
  {
    echo "net.core.default_qdisc=fq"
    echo "net.ipv4.tcp_congestion_control=bbr"
  } >> /etc/sysctl.conf
  sysctl -p >/dev/null 2>&1 || true

  if [ "$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)" = "bbr" ]; then
    echo "BBR 已成功启用！"
  else
    echo "[!] BBR 启用失败（内核不支持时会这样），继续安装 realm。" >&2
  fi
fi

# ---------- 2. 安装 realm ----------
# 下载工具：curl 优先，回退 wget
if command -v curl >/dev/null 2>&1; then
  DL() { curl -fL --connect-timeout 20 -o "$2" "$1"; }
elif command -v wget >/dev/null 2>&1; then
  DL() { wget -O "$2" "$1"; }
else
  echo "缺少 curl / wget，尝试自动安装 curl ..."
  if command -v apt-get >/dev/null 2>&1; then
    apt-get update -y && apt-get install -y curl
  elif command -v dnf >/dev/null 2>&1; then
    dnf install -y curl
  elif command -v yum >/dev/null 2>&1; then
    yum install -y curl
  fi
  if command -v curl >/dev/null 2>&1; then
    DL() { curl -fL --connect-timeout 20 -o "$2" "$1"; }
  else
    echo "自动安装 curl 失败，请手动安装后重试。" >&2
    exit 1
  fi
fi

# realm 只发布 x86_64 / aarch64 两个包，按架构挑选
case "$(uname -m)" in
  x86_64|amd64)  REALM_ARCH="x86_64" ;;
  aarch64|arm64) REALM_ARCH="aarch64" ;;
  *) echo "暂不支持的架构: $(uname -m)（realm 仅提供 x86_64 / aarch64）" >&2; exit 1 ;;
esac

REALM_VER="${REALM_VER:-v2.7.0}"
REALM_PKG="realm-${REALM_ARCH}-unknown-linux-gnu.tar.gz"
REALM_URL="https://github.com/zhboner/realm/releases/download/${REALM_VER}/${REALM_PKG}"

echo "安装 realm ${REALM_VER} (${REALM_ARCH}) ..."
mkdir -p /root/realm
cd /root/realm
DL "$REALM_URL" "$REALM_PKG"
tar -xzf "$REALM_PKG"
rm -f "$REALM_PKG"
install -m 0755 realm /usr/local/bin/realm

# ---------- 3. 生成配置（已存在就不覆盖） ----------
if [ ! -f /root/realm/realm.toml ]; then
  echo "生成默认 realm.toml（含占位符，请按需修改）..."
  cat > /root/realm/realm.toml << 'EOF'
[log]
level = "warn"
output = "/root/realm.log"

[network]
use_udp = true
tcp_timeout = 10
udp_timeout = 30
tcp_keepalive = 15

[[endpoints]]
listen = "0.0.0.0:端口"
remote = "目标IP:端口"
EOF
fi

# ---------- 4. 注册 systemd 服务 ----------
echo "配置 realm 自启动服务..."
cat > /etc/systemd/system/realm.service << 'EOF'
[Unit]
Description=Realm Proxy Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/realm -c /root/realm/realm.toml
Restart=on-failure
RestartSec=5
User=root

[Install]
WantedBy=multi-user.target
EOF

if command -v systemctl >/dev/null 2>&1; then
  systemctl daemon-reload || true
  systemctl enable realm >/dev/null 2>&1 || true
else
  echo "[!] 未检测到 systemd，跳过开机自启配置。"
fi

# 配置里还是占位符就别启动，避免无意义的重启循环
if ! command -v systemctl >/dev/null 2>&1; then
  echo "请手动运行：realm -c /root/realm/realm.toml"
elif grep -q '端口\|目标IP' /root/realm/realm.toml; then
  echo "[!] /root/realm/realm.toml 仍是占位符，已设为开机自启但未立即启动。"
  echo "修改配置后执行：systemctl restart realm"
else
  systemctl restart realm || true
fi

echo "全部完成！配置文件：/root/realm/realm.toml"

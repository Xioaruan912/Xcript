#!/usr/bin/env bash
# rclone 安装 + 云盘（OneDrive 等）挂载：自动补依赖、可选 systemd 自动挂载
set -uo pipefail

# ================= 可选参数（export 后再跑可跳过交互）=================
RCLONE_REMOTE="${RCLONE_REMOTE:-}"       # 形如 "myonedrive:backup"（rclone config 里的 remote）
RCLONE_MOUNT="${RCLONE_MOUNT:-}"         # 本地挂载点目录，例如 /mnt/onedrive
RCLONE_OPTS="${RCLONE_OPTS:---vfs-cache-mode writes}"   # 额外挂载参数
AUTO_ENABLE_SERVICE="${AUTO_ENABLE_SERVICE:-1}"         # 1=自动创建并启用 systemd 服务
# =====================================================================

if [ "$(id -u)" -eq 0 ]; then SUDO=""; else SUDO="sudo"; fi
RUN_USER="${SUDO_USER:-$(id -un)}"
RUN_HOME="$(getent passwd "$RUN_USER" 2>/dev/null | cut -d: -f6)"
[ -n "$RUN_HOME" ] || RUN_HOME="$HOME"

# 以真实用户身份运行交互命令（rclone config 等）
as_user() {
  if [ "$(id -u)" -eq 0 ] && [ "$RUN_USER" != "root" ] && command -v sudo >/dev/null 2>&1; then
    sudo -u "$RUN_USER" "$@"
  else
    "$@"
  fi
}

echo "正在准备环境..."
if command -v apt-get >/dev/null 2>&1; then
  $SUDO apt-get update -y
  $SUDO apt-get install -y curl ca-certificates fuse3
elif command -v dnf >/dev/null 2>&1; then
  $SUDO dnf install -y curl ca-certificates fuse3 fuse
elif command -v yum >/dev/null 2>&1; then
  $SUDO yum install -y curl ca-certificates fuse3 fuse
fi

echo "检测 rclone 是否已安装..."
if command -v rclone >/dev/null 2>&1; then
  echo "[OK] 已检测到 rclone：$(rclone version 2>/dev/null | head -n1 || true)"
else
  echo "[*] 未检测到 rclone，安装官方最新版..."
  TMP_INST="$(mktemp /tmp/rclone-install-XXXXXX.sh 2>/dev/null || echo "/tmp/rclone-install-$$.sh")"
  if ! curl -fsSL https://rclone.org/install.sh -o "$TMP_INST"; then
    echo "下载 rclone 安装脚本失败，请检查网络后重试。" >&2
    exit 1
  fi
  $SUDO bash "$TMP_INST"
  rm -f "$TMP_INST"
  echo "[OK] rclone 安装完成：$(rclone version 2>/dev/null | head -n1 || true)"
fi

# bash 自动补全（可选，新旧版本命令名不同）
if [ -d /etc/bash_completion.d ]; then
  if rclone help completion >/dev/null 2>&1; then
    rclone completion bash 2>/dev/null | $SUDO tee /etc/bash_completion.d/rclone >/dev/null 2>&1 || true
  elif rclone help genautocomplete >/dev/null 2>&1; then
    rclone genautocomplete bash 2>/dev/null | $SUDO tee /etc/bash_completion.d/rclone >/dev/null 2>&1 || true
  fi
fi

# ---------- 配置目录 ----------
CONF_DIR="${RCLONE_CONFIG_DIR:-$RUN_HOME/.config/rclone}"
CONF_FILE="${RCLONE_CONFIG:-$CONF_DIR/rclone.conf}"
mkdir -p "$(dirname "$CONF_FILE")"
if [ ! -f "$CONF_FILE" ]; then
  printf '# rclone 配置，由 rclone config 生成\n' > "$CONF_FILE"
  chmod 600 "$CONF_FILE"
  echo "已创建空配置：$CONF_FILE"
fi

# ---------- 前提：先把云盘 remote 配好 ----------
if [ -z "$RCLONE_REMOTE" ] && [ -t 0 ]; then
  echo
  echo "还没有指定要挂载的云盘。"
  echo "rclone config 里选 n（新建）-> 选 OneDrive 等 -> 一路回车完成授权。"
  read -r -p "现在运行 rclone config 添加云盘吗？[Y/n] " ans
  case "${ans:-y}" in
    [Nn]*) ;;
    *) as_user rclone --config "$CONF_FILE" config ;;
  esac

  read -r -p "要挂载的 remote（形如 myonedrive:backup，留空=只装 rclone 不挂载）: " RCLONE_REMOTE
  if [ -n "$RCLONE_REMOTE" ] && [ -z "$RCLONE_MOUNT" ]; then
    read -r -p "本地挂载点（默认 /mnt/onedrive）: " ans_mount
    RCLONE_MOUNT="${ans_mount:-/mnt/onedrive}"
  fi
fi

# ---------- 可选：创建 systemd 服务用于自动挂载 ----------
create_service() {
  local remote="$1"
  local mount_point="$2"
  local opts="$3"
  local remote_name="${remote%%:*}"

  if ! grep -q "^\[${remote_name}\]" "$CONF_FILE" 2>/dev/null; then
    echo "[!] rclone 配置里没有 [${remote_name}]，请先运行：rclone config" >&2
    return 1
  fi

  $SUDO mkdir -p "${mount_point}"

  local group_name
  group_name="$(id -gn "${RUN_USER}" 2>/dev/null || echo nogroup)"

  local rclone_bin fusermount_bin
  rclone_bin="$(command -v rclone || echo /usr/bin/rclone)"
  fusermount_bin="$(command -v fusermount3 || command -v fusermount || echo /bin/fusermount3)"

  local svc=/etc/systemd/system/rclone-mount.service
  echo "生成 systemd 服务：${svc}"
  $SUDO tee "${svc}" >/dev/null <<EOF
[Unit]
Description=Rclone Mount (${remote} -> ${mount_point})
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${RUN_USER}
Group=${group_name}
ExecStart=${rclone_bin} mount ${remote} ${mount_point} \\
  --config ${CONF_FILE} \\
  --allow-other \\
  --umask 002 \\
  --dir-cache-time 72h \\
  --poll-interval 1m \\
  ${opts} \\
  --log-file /var/log/rclone-mount.log \\
  --log-level INFO
ExecStop=${fusermount_bin} -u ${mount_point}
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

  echo "赋权 allow_other"
  if ! grep -q '^user_allow_other' /etc/fuse.conf 2>/dev/null; then
    echo "user_allow_other" | $SUDO tee -a /etc/fuse.conf >/dev/null || true
  fi

  echo "启用并启动服务..."
  $SUDO systemctl daemon-reload
  $SUDO systemctl enable --now rclone-mount.service
  sleep 2
  if command -v mountpoint >/dev/null 2>&1 && mountpoint -q "${mount_point}"; then
    echo "[OK] 挂载完成：${remote} -> ${mount_point}"
  else
    echo "[!] 服务已启动，但 ${mount_point} 暂未挂载。查看日志：journalctl -u rclone-mount -n 50" >&2
    $SUDO systemctl status rclone-mount.service --no-pager || true
  fi
}

# 当提供了 remote 和 mount 变量时，自动创建服务
if [ -n "${RCLONE_REMOTE}" ] && [ -n "${RCLONE_MOUNT}" ]; then
  if [ "${AUTO_ENABLE_SERVICE}" = "1" ]; then
    create_service "${RCLONE_REMOTE}" "${RCLONE_MOUNT}" "${RCLONE_OPTS}"
  else
    echo "ℹ  已提供 RCLONE_REMOTE / RCLONE_MOUNT，但未启用 AUTO_ENABLE_SERVICE。跳过创建服务。"
  fi
else
  echo "ℹ  未提供 RCLONE_REMOTE / RCLONE_MOUNT，跳过 systemd 挂载服务创建。"
fi

echo
echo "完成！"
echo "交互式配置：  rclone config"
echo "示例挂载（前台调试）："
echo "rclone mount <remote:bucket> /mnt/cloud --vfs-cache-mode writes"
echo
rclone version 2>/dev/null | head -n1 || true

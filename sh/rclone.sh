#!/bin/bash
set -euo pipefail

# ================= 可选参数（按需 export 后再跑脚本）=================
# 示例：export RCLONE_REMOTE="mycos:bucket" ; export RCLONE_MOUNT="/mnt/cloud"
RCLONE_REMOTE="${RCLONE_REMOTE:-}"       # 形如 "mycos:bucket"（rclone config 里定义的 remote）
RCLONE_MOUNT="${RCLONE_MOUNT:-}"         # 本地挂载点目录，例如 /mnt/cloud
RCLONE_OPTS="${RCLONE_OPTS:---vfs-cache-mode writes}"   # 额外挂载参数
AUTO_ENABLE_SERVICE="${AUTO_ENABLE_SERVICE:-1}"         # 1=自动创建并启用 systemd 服务（需要上面两个变量）
# =====================================================================

if [[ $EUID -ne 0 ]]; then SUDO="sudo"; else SUDO=""; fi

echo "🌥️  正在准备环境..."
$SUDO apt-get update -y
$SUDO apt-get install -y curl ca-certificates fuse3

echo "🔍 检测 rclone 是否已安装..."
if command -v rclone >/dev/null 2>&1; then
  echo "✅ 已检测到 rclone：$(rclone version | head -n1)"
else
  echo "⬇️  未检测到 rclone，安装官方最新版..."
  # 官方安装脚本（会拉取预编译二进制并放到 /usr/bin/rclone）
  curl -fsSL https://rclone.org/install.sh | $SUDO bash
  echo "✅ rclone 安装完成：$(rclone version | head -n1)"
fi

# bash 自动补全（可选）
if [[ -d /etc/bash_completion.d ]]; then
  echo "🧩 安装 bash 补全..."
  rclone genautocomplete bash | $SUDO tee /etc/bash_completion.d/rclone >/dev/null || true
fi

# 配置目录
CONF_DIR="${HOME}/.config/rclone"
CONF_FILE="${CONF_DIR}/rclone.conf"
echo "📂 准备配置目录：${CONF_DIR}"
mkdir -p "${CONF_DIR}"
if [[ ! -f "${CONF_FILE}" ]]; then
  echo "# 在此文件中由 'rclone config' 生成或手动填写远程配置" > "${CONF_FILE}"
  chmod 600 "${CONF_FILE}"
  echo "📝 已创建空配置：${CONF_FILE}"
fi

# 可选：创建 systemd 服务用于自动挂载
create_service() {
  local remote="$1"
  local mount_point="$2"
  local opts="$3"

  # 确保挂载点存在
  $SUDO mkdir -p "${mount_point}"

  # 取当前用户信息（非 root 情况下跑 systemd --user 更合适，但这里用 system 服务方便服务器场景）
  local user_name="${SUDO_USER:-$USER}"
  local group_name
  group_name="$(id -gn "${user_name}")"

  local svc=/etc/systemd/system/rclone-mount.service
  echo "🛠️  生成 systemd 服务：${svc}"
  $SUDO tee "${svc}" >/dev/null <<EOF
[Unit]
Description=Rclone Mount (${remote} -> ${mount_point})
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${user_name}
Group=${group_name}
ExecStart=/usr/bin/rclone mount ${remote} ${mount_point} \\
  --config ${CONF_FILE} \\
  --allow-other \\
  --umask 002 \\
  --dir-cache-time 72h \\
  --poll-interval 1m \\
  ${opts} \\
  --log-file /var/log/rclone-mount.log \\
  --log-level INFO
ExecStop=/bin/fusermount3 -u ${mount_point}
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

  echo "🔐  赋权 allow_other"
  echo "user_allow_other" | $SUDO tee -a /etc/fuse.conf >/dev/null || true

  echo "🚀 启用并启动服务..."
  $SUDO systemctl daemon-reload
  $SUDO systemctl enable --now rclone-mount.service
  $SUDO systemctl status rclone-mount.service --no-pager || true
  echo "✅ 挂载完成：${remote} → ${mount_point}"
}

# 当提供了 remote 和 mount 变量时，自动创建服务
if [[ -n "${RCLONE_REMOTE}" && -n "${RCLONE_MOUNT}" ]]; then
  if [[ "${AUTO_ENABLE_SERVICE}" == "1" ]]; then
    create_service "${RCLONE_REMOTE}" "${RCLONE_MOUNT}" "${RCLONE_OPTS}"
  else
    echo "ℹ️  已提供 RCLONE_REMOTE / RCLONE_MOUNT，但未启用 AUTO_ENABLE_SERVICE。跳过创建服务。"
  fi
else
  echo "ℹ️  未提供 RCLONE_REMOTE / RCLONE_MOUNT，跳过 systemd 挂载服务创建。"
fi

echo
echo "🎉 完成！"
echo "👉 运行交互式配置：  rclone config"
echo "👉 示例挂载（前台调试）："
echo "   rclone mount <remote:bucket> /mnt/cloud --vfs-cache-mode writes"
echo
rclone version

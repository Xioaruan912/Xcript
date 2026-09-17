#!/usr/bin/env bash
# 一键设置时区为 Asia/Shanghai（systemd 与容器环境都能用）
set -euo pipefail

# root 下不依赖 sudo
if [ "$(id -u)" -eq 0 ]; then SUDO=""; else SUDO="sudo"; fi

echo ">>> 设置时区为 Asia/Shanghai ..."
if command -v timedatectl >/dev/null 2>&1 && $SUDO timedatectl set-timezone Asia/Shanghai 2>/dev/null; then
  echo "（已通过 timedatectl 设置）"
else
  echo "（timedatectl 不可用，直接写入 /etc/localtime）"
  $SUDO ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
  if [ -f /etc/timezone ]; then
    echo "Asia/Shanghai" | $SUDO tee /etc/timezone >/dev/null
  fi
fi

echo ">>> 当前时间："
date
echo "[OK] 已完成！"

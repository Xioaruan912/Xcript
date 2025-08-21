#!/bin/bash
set -euo pipefail

green(){ echo -e "\033[32m$1\033[0m"; }
yellow(){ echo -e "\033[33m$1\033[0m"; }
red(){ echo -e "\033[31m$1\033[0m"; }

# 使用 root 或自动加 sudo
if [[ $EUID -ne 0 ]]; then SUDO="sudo"; else SUDO=""; fi

# 目录与端口
INSTALL_DIR="${INSTALL_DIR:-$HOME/vaultwarden}"
HTTP_PORT="${HTTP_PORT:-8443}"

# 生成随机 ADMIN_TOKEN
ADMIN_TOKEN="$(openssl rand -hex 16)"

green "🔍 检测 Docker..."
if ! command -v docker &>/dev/null; then
  yellow "未检测到 Docker，开始安装..."
  $SUDO apt-get update -y
  $SUDO apt-get install -y ca-certificates curl gnupg lsb-release
  $SUDO install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | $SUDO gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | $SUDO tee /etc/apt/sources.list.d/docker.list >/dev/null
  $SUDO apt-get update -y
  $SUDO apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
  $SUDO systemctl enable --now docker
  green "✅ Docker 安装完成"
else
  green "✅ 检测到 Docker 已安装"
fi

green "🔍 检测 docker compose..."
if ! docker compose version &>/dev/null; then
  red "未检测到 docker compose 插件，请检查 Docker 版本（需要 docker-compose-plugin）。"
  exit 1
fi
green "✅ docker compose 可用"

# 准备目录
mkdir -p "$INSTALL_DIR/data"
cd "$INSTALL_DIR"

# 生成/覆盖 docker-compose.yml
cat > docker-compose.yml <<EOF
services:
  vaultwarden:
    image: vaultwarden/server:latest
    container_name: vaultwarden
    restart: unless-stopped
    ports:
      - "${HTTP_PORT}:80"
    volumes:
      - ./data:/data
    environment:
      - TZ=Asia/Shanghai
      - ADMIN_TOKEN=${ADMIN_TOKEN}
      - LOG_FILE=/data/vaultwarden.log
EOF

# 启动
green "🚀 启动 Vaultwarden..."
docker compose up -d

# 打印关键信息
echo
green "🎉 Vaultwarden 已安装并运行！"
echo "📦 访问地址：  http://<服务器IP>:${HTTP_PORT}"
echo "🔑 管理后台：  http://<服务器IP>:${HTTP_PORT}/admin"
echo "🔐 本次生成的 ADMIN_TOKEN："
echo
echo "   ${ADMIN_TOKEN}"
echo
yellow "（已写入 ${INSTALL_DIR}/docker-compose.yml 的 environment 中）"
yellow "如需再次查看：grep ADMIN_TOKEN ${INSTALL_DIR}/docker-compose.yml"

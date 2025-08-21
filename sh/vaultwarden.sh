#!/bin/bash
set -e

# 颜色输出
green() { echo -e "\033[32m$1\033[0m"; }
red() { echo -e "\033[31m$1\033[0m"; }

# 检测是否 root
if [ "$(id -u)" -ne 0 ]; then
  red "请使用 root 用户运行此脚本！"
  exit 1
fi

# 检测 docker
if ! command -v docker &>/dev/null; then
  green "未检测到 Docker，开始安装..."
  apt-get update
  apt-get install -y ca-certificates curl gnupg lsb-release
  mkdir -p /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
  apt-get update
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
  systemctl enable docker --now
  green "Docker 安装完成"
else
  green "检测到 Docker 已安装"
fi

# 检测 docker compose
if ! docker compose version &>/dev/null; then
  red "未检测到 docker compose 插件，请检查 Docker 版本！"
  exit 1
else
  green "docker compose 已可用"
fi

# 部署 Vaultwarden
INSTALL_DIR=~/vaultwarden
mkdir -p "$INSTALL_DIR/data"

cat > "$INSTALL_DIR/docker-compose.yml" <<EOF
version: '3.7'

services:
  vaultwarden:
    image: vaultwarden/server:latest
    container_name: vaultwarden
    restart: always
    ports:
      - "8443:80"
    volumes:
      - ./data:/data
    environment:
      - TZ=Asia/Shanghai
      - ADMIN_TOKEN=$(openssl rand -hex 16)
      - LOG_FILE=/data/vaultwarden.log
EOF

cd "$INSTALL_DIR"
docker compose up -d

green "Vaultwarden 已安装并运行！"
green "访问地址：http://服务器IP:8443"
green "管理后台：http://服务器IP:8443/admin"

#!/bin/bash
set -e

echo "=== 更新系统包 ==="
sudo apt-get update -y
sudo apt-get upgrade -y

echo "=== 安装依赖 ==="
sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

echo "=== 添加 Docker 官方 GPG key ==="
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo "=== 添加 Docker APT 源 ==="
echo \
  "deb [arch=$(dpkg --print-architecture) \
  signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "=== 安装 Docker 引擎和 Compose 插件 ==="
sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

echo "=== 验证版本 ==="
docker --version
docker compose version

echo "✅ 安装完成，可以使用 docker 和 docker compose 命令了"

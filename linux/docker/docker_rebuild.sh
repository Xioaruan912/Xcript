#!/usr/bin/env bash
# 强制重建当前目录下的 compose 项目（删卷 + 无缓存重建）
set -uo pipefail

if ! command -v docker >/dev/null 2>&1; then
  echo "未检测到 docker，请先安装：" >&2
  echo "bash <(curl -sSL https://raw.githubusercontent.com/Xioaruan912/Xcript/main/linux/docker/docker.sh)" >&2
  exit 1
fi

# 必须在本机的 compose 项目目录里执行
if [ ! -f compose.yaml ] && [ ! -f compose.yml ] && [ ! -f docker-compose.yaml ] && [ ! -f docker-compose.yml ]; then
  echo "当前目录 $PWD 下没有 compose 文件，请先 cd 到项目目录再执行。" >&2
  exit 1
fi

# 当前用户没有权限时自动加 sudo
if docker info >/dev/null 2>&1; then
  DOCKER="docker"
elif command -v sudo >/dev/null 2>&1; then
  echo ">>> 当前用户没有 docker 权限，改用 sudo 执行..."
  DOCKER="sudo docker"
else
  echo "当前用户无法访问 docker，请用 root 运行或加入 docker 组。" >&2
  exit 1
fi

echo "清理旧容器、网络和卷..."
$DOCKER compose down --volumes --remove-orphans

echo "强制重新构建镜像..."
$DOCKER compose build --no-cache

echo "启动容器..."
$DOCKER compose up -d --force-recreate

echo "[OK] 重建完成。使用 docker compose logs -f 查看日志。"
$DOCKER compose logs -f

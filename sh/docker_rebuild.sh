#!/bin/bash

echo "🧹 清理旧容器、网络和卷..."
docker compose down --volumes --remove-orphans

echo "🧱 强制重新构建镜像..."
docker compose build --no-cache

echo "🚀 启动容器..."
docker compose up -d --force-recreate

echo "✅ 重建完成。使用 docker compose logs -f 查看日志。"

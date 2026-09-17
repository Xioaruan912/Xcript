#!/usr/bin/env bash
# Docker + Docker Compose 一键安装（国内镜像加速版）
set -euo pipefail

# ---------- 提权方式（root 下不依赖 sudo） ----------
if [ "$(id -u)" -eq 0 ]; then SUDO=""; else SUDO="sudo"; fi
CURRENT_USER="$(id -un)"

# ---------- 基础依赖 ----------
if ! command -v curl >/dev/null 2>&1; then
  if command -v apt-get >/dev/null 2>&1; then
    $SUDO apt-get update -y
    $SUDO apt-get install -y curl ca-certificates gnupg
  elif command -v dnf >/dev/null 2>&1; then
    $SUDO dnf install -y curl ca-certificates gnupg
  elif command -v yum >/dev/null 2>&1; then
    $SUDO yum install -y curl ca-certificates gnupg
  else
    echo "无法自动安装 curl，请先手动安装。" >&2
    exit 1
  fi
fi

# ---------- 安装 Docker（使用阿里云镜像） ----------
# 正确写法：bash -s -- --mirror Aliyun
curl -fsSL https://get.docker.com | bash -s -- --mirror Aliyun

# 启用并启动 docker 服务
if command -v systemctl >/dev/null 2>&1; then
  $SUDO systemctl enable --now docker
fi

# 将当前用户加入 docker 组（非 root 才有必要）
NEED_NEWGRP=0
if [ "$(id -u)" -ne 0 ] && ! id -nG "$CURRENT_USER" | tr ' ' '\n' | grep -qx docker; then
  $SUDO usermod -aG docker "$CURRENT_USER" || true
  NEED_NEWGRP=1
fi

# ---------- 安装 Docker Compose v2 ----------
# 用 sudo 运行时 HOME 会变成 /root，这里取真实用户的家目录
if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
  REAL_HOME="$(getent passwd "$SUDO_USER" 2>/dev/null | cut -d: -f6)"
  [ -z "$REAL_HOME" ] && REAL_HOME="$HOME"
else
  REAL_HOME="$HOME"
fi
DOCKER_CONFIG="${DOCKER_CONFIG:-$REAL_HOME/.docker}"
mkdir -p "$DOCKER_CONFIG/cli-plugins"

ARCH_RAW="$(uname -m)"
case "$ARCH_RAW" in
  x86_64|amd64) COMP_ARCH="x86_64" ;;
  aarch64|arm64) COMP_ARCH="aarch64" ;;
  armv7l)       COMP_ARCH="armv7" ;;  # 若该版本未发布此构建，需手动改用可用架构
  *)
    echo "不支持的架构: $ARCH_RAW" >&2
    exit 1
    ;;
esac

COMPOSE_VER="${COMPOSE_VER:-v2.29.2}"
COMPOSE_URL="https://ghfast.top/https://github.com/docker/compose/releases/download/${COMPOSE_VER}/docker-compose-linux-${COMP_ARCH}"

echo "下载 docker compose ${COMPOSE_VER} (${COMP_ARCH}) ..."
curl -fL "$COMPOSE_URL" -o "$DOCKER_CONFIG/cli-plugins/docker-compose"
chmod +x "$DOCKER_CONFIG/cli-plugins/docker-compose"

# root 运行时再装一份系统级插件，所有用户都能直接用
if [ "$(id -u)" -eq 0 ]; then
  mkdir -p /usr/local/lib/docker/cli-plugins
  cp -f "$DOCKER_CONFIG/cli-plugins/docker-compose" /usr/local/lib/docker/cli-plugins/docker-compose
  chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
fi

export DOCKER_CONFIG

# ---------- 验证 ----------
echo "Docker 版本："
docker --version || { echo "docker 未安装成功"; exit 1; }

echo "Docker Compose 版本："
docker compose version || { echo "docker compose 未安装成功"; exit 1; }

# 提示：docker 组变更需要新会话生效
if [ "$NEED_NEWGRP" = "1" ]; then
  echo "提示：已将 $CURRENT_USER 加入 docker 组。请重新登录，或执行：newgrp docker"
fi

echo "[OK] 安装完成。"

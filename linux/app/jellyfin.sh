#!/usr/bin/env bash
set -euo pipefail

# ========== 可改参数 ==========
APP_DIR="${APP_DIR:-$HOME/jellyfin}"        # Jellyfin 目录
JF_IMAGE="${JF_IMAGE:-jellyfin/jellyfin:latest}"
TZ_VAL="${TZ:-Asia/Shanghai}"               # 时区
USE_HOST_NET="${USE_HOST_NET:-1}"           # 1=使用 host 网络；0=端口映射
HTTP_PORT="${HTTP_PORT:-8096}"              # 非 host 模式时的 HTTP 端口
HTTPS_PORT="${HTTPS_PORT:-8920}"            # 非 host 模式时的 HTTPS 端口
# ============================

# root 直接运行；否则用 sudo
if [ "$(id -u)" -eq 0 ]; then SUDO=""; DOCKER="docker"; else SUDO="sudo"; DOCKER="sudo docker"; fi

echo "==> 检测 Docker 是否已安装"
if ! command -v docker &>/dev/null; then
  echo "未检测到 Docker，开始安装..."
  $SUDO apt-get update -y
  $SUDO apt-get install -y ca-certificates curl gnupg lsb-release

  $SUDO install -m 0755 -d /etc/apt/keyrings

  # Docker 源要跟发行版走：Debian 用 debian、Ubuntu 用 ubuntu，否则 apt 会 404
  OS_ID="$(. /etc/os-release 2>/dev/null; echo "${ID:-ubuntu}")"
  case "$OS_ID" in
    debian|ubuntu) DOCKER_DISTRO="$OS_ID" ;;
    *) case "$(. /etc/os-release 2>/dev/null; echo "${ID_LIKE:-}")" in
         *debian*) DOCKER_DISTRO="debian" ;;
         *)        DOCKER_DISTRO="ubuntu" ;;
       esac ;;
  esac
  OS_CODENAME="$(. /etc/os-release 2>/dev/null; echo "${VERSION_CODENAME:-}")"
  [ -z "$OS_CODENAME" ] && OS_CODENAME="$(lsb_release -cs)"

  curl -fsSL "https://download.docker.com/linux/${DOCKER_DISTRO}/gpg" | $SUDO gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  $SUDO chmod a+r /etc/apt/keyrings/docker.gpg
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/${DOCKER_DISTRO} ${OS_CODENAME} stable" | \
    $SUDO tee /etc/apt/sources.list.d/docker.list >/dev/null

  $SUDO apt-get update -y
  $SUDO apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

  $SUDO systemctl enable --now docker
  echo "[OK] Docker 安装完成"
else
  echo "[OK] Docker 已安装，跳过安装步骤"
fi

echo "==> 检测 Docker Compose 是否可用"
if ! $DOCKER compose version &>/dev/null; then
  echo "[ERR] 未检测到 docker compose 插件，请检查 Docker 安装"
  exit 1
fi

echo "==> 准备 Jellyfin 目录：$APP_DIR/{config,cache,media}"
mkdir -p "$APP_DIR"/{config,cache,media}
cd "$APP_DIR"

echo "==> 生成 docker-compose.yml"
if [[ "${USE_HOST_NET}" == "1" ]]; then
  cat > docker-compose.yml <<EOF
services:
  jellyfin:
    image: ${JF_IMAGE}
    container_name: jellyfin
    restart: unless-stopped
    network_mode: "host"
    environment:
      - TZ=${TZ_VAL}
    volumes:
      - ./config:/config
      - ./cache:/cache
      - ./media:/media
EOF
else
  cat > docker-compose.yml <<EOF
services:
  jellyfin:
    image: ${JF_IMAGE}
    container_name: jellyfin
    restart: unless-stopped
    ports:
      - "${HTTP_PORT}:8096"
      - "${HTTPS_PORT}:8920"
    environment:
      - TZ=${TZ_VAL}
    volumes:
      - ./config:/config
      - ./cache:/cache
      - ./media:/media
EOF
fi

echo "==> 拉取镜像并启动 Jellyfin"
$DOCKER compose pull
$DOCKER compose up -d

echo
echo "[OK] Jellyfin 已启动！"
if [[ "${USE_HOST_NET}" == "1" ]]; then
  echo "请在浏览器访问：http://<服务器IP>:8096"
else
  echo "请在浏览器访问：http://<服务器IP>:${HTTP_PORT}"
fi

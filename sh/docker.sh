#!/usr/bin/env bash
# ==============================================================================
# 终极通用 Linux Docker & Docker Compose 安装/更新脚本 (增强版)
# 特性：自动提权 / 自动判断国内网络并换源 / 兼容 Arch 等特殊发行版 / 补全底层依赖
# ==============================================================================

set -e

# --- 1. 颜色与打印日志函数 ---
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# --- 2. 自动检测并提取 root/sudo 权限 ---
if [ "$(id -u)" -ne 0 ]; then
    log_warn "当前没有 Root 权限，准备请求 sudo 提权执行..."
    if command -v sudo >/dev/null 2>&1; then
        exec sudo bash "$0" "$@"
    else
        log_error "系统未安装 sudo，请直接使用 root 用户运行此脚本！"
    fi
fi

# --- 3. 自动探测网络环境 (判断是否需要使用国内镜像) ---
USE_MIRROR=false
log_info "正在检测网络环境..."
if ! curl -s --connect-timeout 3 https://www.google.com > /dev/null 2>&1; then
    log_info "检测到可能位于国内网络，将自动使用镜像源(Aliyun)加速安装..."
    USE_MIRROR=true
else
    log_info "网络环境良好，将使用官方源安装..."
fi

# --- 4. 基础更新与底层依赖补全 (多发行版检测) ---
log_info "检查发行版并准备底层运行环境..."
if command -v apt-get >/dev/null 2>&1; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq -y
    apt-get install -qq -y curl ca-certificates gnupg iptables lsb-release
elif command -v dnf >/dev/null 2>&1; then
    dnf install -y -q curl ca-certificates gnupg iptables
elif command -v yum >/dev/null 2>&1; then
    yum install -y -q curl ca-certificates gnupg iptables
elif command -v pacman >/dev/null 2>&1; then
    pacman -Sy --noconfirm --needed curl ca-certificates gnupg iptables
elif command -v zypper >/dev/null 2>&1; then
    zypper --non-interactive install curl ca-certificates gnupg iptables
else
    log_warn "未识别到主流包管理器，尝试跳过依赖安装步骤继续..."
fi

# --- 5. 安装 Docker 核心组件 ---
log_info "开始安装 Docker 引擎与 Compose..."

# Arch Linux 特殊处理 (官方脚本不支持 Arch)
if [ -f "/etc/arch-release" ] || [ -f "/etc/manjaro-release" ]; then
    log_info "检测到 Arch 系发行版，使用 pacman 原生安装..."
    pacman -S --noconfirm --needed docker docker-compose
else
    # 其他主流系统使用官方 Convenience Script
    curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
    if [ "$USE_MIRROR" = true ]; then
        sh /tmp/get-docker.sh --mirror Aliyun
    else
        sh /tmp/get-docker.sh
    fi
    rm -f /tmp/get-docker.sh
fi

# --- 6. 解决历史遗留习惯 (兼容 docker-compose 命令) ---
if ! command -v docker-compose >/dev/null 2>&1; then
    log_info "创建 docker-compose 兼容别名..."
    # 写入一个简单的包装脚本将 docker-compose 转发给 docker compose
    cat > /usr/local/bin/docker-compose << 'EOF'
#!/bin/sh
exec docker compose "$@"
EOF
    chmod +x /usr/local/bin/docker-compose
fi

# --- 7. 配置 Docker 镜像加速 (针对国内网络) ---
if [ "$USE_MIRROR" = true ]; then
    log_info "配置 Docker 镜像加速器 (Registry Mirrors)..."
    mkdir -p /etc/docker
    cat > /etc/docker/daemon.json << 'EOF'
{
  "registry-mirrors": [
    "https://docker.m.daocloud.io",
    "https://docker.1panel.live",
    "https://registry.cn-hangzhou.aliyuncs.com"
  ]
}
EOF
fi

# --- 8. 启动 Docker 守护进程并设置为开机自启 ---
log_info "启动 Docker 后台服务并设置开机自启..."
if command -v systemctl >/dev/null 2>&1; then
    systemctl daemon-reload >/dev/null 2>&1 || true
    systemctl enable --now docker >/dev/null 2>&1 || true
elif command -v service >/dev/null 2>&1; then
    service docker start >/dev/null 2>&1 || true
fi

# --- 9. 将发起用户（如果不是 root 本身）加入 docker 用户组 ---
REAL_USER=${SUDO_USER:-$USER}
if [ -n "$REAL_USER" ] && [ "$REAL_USER" != "root" ]; then
    log_info "把非 Root 用户 '$REAL_USER' 加入 docker 权限组..."
    usermod -aG docker "$REAL_USER" || true
    log_warn "提示: 为使非 root 用户直接使用 docker，请在安装完成后退出终端重新登录，或执行 'su - $REAL_USER'"
fi

# --- 10. 版本校验与总结 ---
log_info "开始校验安装结果..."
DOCKER_VER=$(docker --version 2>/dev/null || echo "未安装成功")
COMPOSE_VER=$(docker compose version 2>/dev/null || echo "未安装成功")

echo "-------------------------------------------------------------------"
if [[ "$DOCKER_VER" != "未安装成功" ]]; then
    echo -e "${GREEN}✅ Docker 环境安装与配置全部完成！${NC}"
    echo -e "🐳 Docker 核心:       ${BLUE}${DOCKER_VER}${NC}"
    echo -e "📦 Docker Compose:    ${BLUE}${COMPOSE_VER}${NC}"
    if [ "$USE_MIRROR" = true ]; then
        echo -e "🚀 镜像加速器:        ${GREEN}已开启 (daocloud / 1panel / aliyun)${NC}"
    fi
else
    echo -e "${RED}❌ 安装可能存在异常，请检查上方日志。${NC}"
fi
echo "-------------------------------------------------------------------"
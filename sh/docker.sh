#!/usr/bin/env bash
# ==============================================================================
# 通用 Linux Docker & Docker Compose 安装/更新脚本
# 支持发行版: Ubuntu, Debian, RHEL, CentOS, Fedora, Rocky, AlmaLinux, Arch, SUSE 等
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
    log_info "当前没有 Root 权限，准备提权执行..."
    exec sudo bash "$0" "$@"
fi

# --- 3. 基础更新与工具链准备 (多发行版检测) ---
log_info "检查发行版并准备必要工具 (curl)..."

if command -v apt-get >/dev/null 2>&1; export DEBIAN_FRONTEND=noninteractive; then
    apt-get update -y && apt-get install -y curl ca-certificates
elif command -v dnf >/dev/null 2>&1; then
    dnf install -y curl ca-certificates
elif command -v yum >/dev/null 2>&1; then
    yum install -y curl ca-certificates
elif command -v pacman >/dev/null 2>&1; then
    pacman -Sy --noconfirm curl ca-certificates
elif command -v zypper >/dev/null 2>&1; then
    zypper --non-interactive install curl ca-certificates
else
    log_warn "未识别到通用包管理器，将尝试直接运行安装依赖库程序..."
fi

# --- 4. 安装 Docker 引擎（基于 Docker 官方 Convenience Script） ---
log_info "获取 Docker 官方通用安装脚本，启动智能安装流程..."
# get.docker.com 会自动判别发行版、配置对应官方仓库并装上所有 Docker 核心包与 Compose 插件
curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
sh /tmp/get-docker.sh
rm -f /tmp/get-docker.sh

# --- 5. 启动 Docker 守护进程并设置为开机自启 ---
log_info "启动 Docker 后台服务并设置开机自启..."
if command -v systemctl >/dev/null 2>&1; then
    systemctl enable --now docker >/dev/null 2>&1 || true
elif command -v service >/dev/null 2>&1; then
    service docker start >/dev/null 2>&1 || true
fi

# --- 6. 将发起用户（如果不是 root 本身）加入 docker 用户组 ---
REAL_USER=${SUDO_USER:-$USER}
if [ -n "$REAL_USER" ] && [ "$REAL_USER" != "root" ]; then
    log_info "把非 Root 用户 '$REAL_USER' 加入 docker 权限组..."
    usermod -aG docker "$REAL_USER"
    log_warn "提示: 为使 docker 权限组立竿见影，运行命令前可能需要针对账户执行一次 'su - $REAL_USER' 或重启终端/系统。"
fi

# --- 7. 版本校验 ---
log_info "开始校验客户端安装及运行情况..."
DOCKER_VER=$(docker --version 2>/dev/null || echo "未安装成功")
COMPOSE_VER=$(docker compose version 2>/dev/null || echo "未安装成功")

echo "----------------------------------------------------"
echo -e "${GREEN}✅ 安装与升级全部完成！${NC}"
echo -e "🐳 Docker 核心引擎:   ${BLUE}${DOCKER_VER}${NC}"
echo -e "📦 Docker Compose:    ${BLUE}${COMPOSE_VER}${NC}"
echo "----------------------------------------------------"

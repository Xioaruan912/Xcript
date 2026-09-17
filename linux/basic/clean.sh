#!/usr/bin/env bash
# VPS 清理脚本（非 root 会自动用 sudo 提权）

# ---------- 提权：支持 bash <(curl ...) 直接运行 ----------
if [ "$(id -u)" -ne 0 ]; then
    if ! command -v sudo >/dev/null 2>&1; then
        echo "需要 root 权限运行，请切换到 root 用户后重试。" >&2
        exit 1
    fi
    # bash <(curl ...) 时 $0 是 /dev/fd/*，sudo 会关闭该 fd，所以先复制到临时文件
    SELF_TMP="$(mktemp /tmp/xcript-clean-XXXXXX.sh 2>/dev/null || echo "/tmp/xcript-clean-$$.sh")"
    if ! cat "$0" > "$SELF_TMP" 2>/dev/null; then
        echo "读取自身脚本失败，请先下载脚本到本地再运行。" >&2
        exit 1
    fi
    chmod +x "$SELF_TMP"
    echo ">>> 需要 root 权限，正在通过 sudo 重新执行..."
    exec sudo bash "$SELF_TMP" "$@"
fi

clear
echo "[WARN] 本脚本将执行以下清理操作："
echo "- 清理 APT/YUM 缓存"
echo "- 清理 /tmp"
echo "- 清理 3 天前的系统日志"
echo "- Docker 清理：删除未使用的镜像/容器/网络（不影响运行中的容器）"
echo "- 清理 journald 日志（保留 3 天）"
echo "- 删除 core dump 文件"
echo "- 清理旧内核（不影响当前内核）"
echo ""

read -r -p "是否继续执行？(y/n): " confirm

if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "已取消操作。"
    exit 0
fi

echo "开始清理系统垃圾文件..."

# 1. 清理系统缓存
echo "-> 清理 APT/YUM 缓存..."
if command -v apt-get >/dev/null 2>&1; then
    apt-get clean
    apt-get autoclean
    apt-get autoremove -y
elif command -v yum >/dev/null 2>&1; then
    yum clean all
    yum autoremove -y
fi

# 2. 清理 /tmp 目录（保留最近 1 天与本脚本自己的临时文件）
echo "-> 清理 /tmp ..."
find /tmp -mindepth 1 -maxdepth 1 ! -name 'xcript-*' -mtime +0 -exec rm -rf {} + 2>/dev/null || true

# 3. 清理系统日志（保留最近 3 天）
echo "-> 清理系统日志（保留 3 天）..."
find /var/log -type f -mtime +3 -exec truncate -s 0 {} \; 2>/dev/null || true

# 4. 清理 Docker 垃圾（如果使用 Docker）
if command -v docker >/dev/null 2>&1; then
    echo "-> 清理 Docker..."
    docker system prune -af
fi

# 5. 清理 journald 日志
if command -v journalctl >/dev/null 2>&1; then
    echo "-> 压缩 journald 日志..."
    journalctl --vacuum-time=3d
fi

# 6. 删除 core dump 文件
echo "-> 删除 core dump ..."
find / -xdev -type f -name 'core.*' -exec rm -f {} \; 2>/dev/null || true

# 7. 清理旧内核（Debian/Ubuntu）
if command -v apt-get >/dev/null 2>&1; then
    echo "-> 清理旧内核..."
    CURRENT_KERNEL="$(uname -r)"
    OLD_KERNELS="$(dpkg -l 'linux-image-*' 2>/dev/null \
        | awk '/^ii/{print $2}' \
        | grep -Ev '^linux-image-(generic|amd64|arm64|virtual|cloud|oem|lowlatency)$' \
        | grep -v -- "$CURRENT_KERNEL" || true)"
    if [ -n "$OLD_KERNELS" ]; then
        echo "$OLD_KERNELS" | xargs -r apt-get remove -y --purge >/dev/null 2>&1 || true
    else
        echo "（没有需要清理的旧内核）"
    fi
fi

echo "清理完成！"

#!/bin/bash
# VPS 清理脚本
clear
echo "⚠️  本脚本将执行以下清理操作："
echo "  - 清理 APT/YUM 缓存"
echo "  - 清理 /tmp"
echo "  - 清理 3 天前的系统日志"
echo "  - Docker 清理：删除未使用的镜像/容器/网络（不影响运行中的容器）"
echo "  - 清理 journald 日志（保留 3 天）"
echo "  - 删除 core dump 文件"
echo "  - 清理旧内核（不影响当前内核）"
echo ""

read -p "是否继续执行？(y/n): " confirm

if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "已取消操作。"
    exit 0
fi

echo "开始清理系统垃圾文件..."

# 1. 清理系统缓存
echo "→ 清理 APT/YUM 缓存..."
if command -v apt >/dev/null 2>&1; then
    apt clean
    apt autoclean
    apt autoremove -y
elif command -v yum >/dev/null 2>&1; then
    yum clean all
    yum autoremove -y
fi

# 2. 清理 /tmp 目录
echo "→ 清理 /tmp ..."
rm -rf /tmp/*

# 3. 清理系统日志（保留最近 3 天）
echo "→ 清理系统日志（保留 3 天）..."
find /var/log -type f -mtime +3 -exec truncate -s 0 {} \;

# 4. 清理 Docker 垃圾（如果使用 Docker）
if command -v docker >/dev/null 2>&1; then
    echo "→ 清理 Docker..."
    docker system prune -af
fi

# 5. 清理 journald 日志
if command -v journalctl >/dev/null 2>&1; then
    echo "→ 压缩 journald 日志..."
    journalctl --vacuum-time=3d
fi

# 6. 删除 core dump 文件
echo "→ 删除 core dump ..."
find / -type f -name 'core.*' -exec rm -f {} \; 2>/dev/null

# 7. 清理旧内核（Debian/Ubuntu）
if command -v apt >/dev/null 2>&1; then
    echo "→ 清理旧内核..."
    dpkg -l 'linux-image-*' | awk '/^ii/{print $2}' | grep -v $(uname -r | sed 's/-generic//') | xargs apt remove -y >/dev/null 2>&1
fi

echo "🎉 清理完成！"

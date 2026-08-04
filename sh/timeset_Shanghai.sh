#!/bin/bash
# 一键设置 Ubuntu 时区为上海

set -e

echo ">>> 设置时区为 Asia/Shanghai ..."
sudo timedatectl set-timezone Asia/Shanghai

echo ">>> 当前时区："
timedatectl | grep "Time zone"

echo "✅ 已完成！"

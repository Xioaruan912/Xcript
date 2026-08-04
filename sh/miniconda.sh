#!/bin/bash
set -euo pipefail

# 1) 下载并静默安装 Miniconda 到 /opt/miniconda
cd /tmp
wget -O miniconda.sh https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
bash miniconda.sh -b -p /opt/miniconda

# 2) 接受 TOS（如需）
/opt/miniconda/bin/conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main || true
/opt/miniconda/bin/conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r || true

# 3) 让当前脚本会话立刻能用 conda（关键！别只用 conda init）
source /opt/miniconda/etc/profile.d/conda.sh

# 可选：不自动激活 base
conda config --set auto_activate_base false

# 4) 创建并激活环境
conda create -y -n test python=3.11
conda activate test

# 5) 永久生效（下次登录自动有 conda）
# conda init 会往 ~/.bashrc 写入 hook；对 root 用户也适用
conda init bash

echo
echo "✅ Miniconda 安装完成，并已激活环境：$(conda env list | awk '/\*/{print $1}')"
python -V

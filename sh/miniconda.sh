#!/bin/bash
set -e

# 1. 下载并安装 Miniconda
cd /tmp
wget -O miniconda.sh https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
bash miniconda.sh -b -p /opt/miniconda

# 2. 初始化 conda
/opt/miniconda/bin/conda init bash

# 3. 接受 TOS
/opt/miniconda/bin/conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main
/opt/miniconda/bin/conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r

# 4. 创建并激活环境
/opt/miniconda/bin/conda create -y -n test python=3.11

echo
echo "✅ Miniconda 安装完成"
echo "👉 现在请运行:  source ~/.bashrc  && conda activate test"

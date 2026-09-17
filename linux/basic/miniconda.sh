#!/usr/bin/env bash
# 安装 Miniconda 并创建环境（默认 /opt/miniconda，环境名 test）
set -euo pipefail

INSTALL_DIR="${INSTALL_DIR:-/opt/miniconda}"
ENV_NAME="${ENV_NAME:-test}"

# root 下不依赖 sudo
if [ "$(id -u)" -eq 0 ]; then SUDO=""; else SUDO="sudo"; fi

# 下载工具：curl 优先，回退 wget
if command -v curl >/dev/null 2>&1; then
  DL() { curl -fL --connect-timeout 20 -o "$2" "$1"; }
elif command -v wget >/dev/null 2>&1; then
  DL() { wget -O "$2" "$1"; }
else
  echo "缺少 curl / wget，请先安装后再运行本脚本。" >&2
  exit 1
fi

# 架构对应的安装包
case "$(uname -m)" in
  x86_64|amd64)  MC_ARCH="x86_64" ;;
  aarch64|arm64) MC_ARCH="aarch64" ;;
  *) echo "暂不支持的架构: $(uname -m)" >&2; exit 1 ;;
esac

# 1) 下载并静默安装 Miniconda
cd /tmp
DL "https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-${MC_ARCH}.sh" miniconda.sh
$SUDO bash miniconda.sh -b -p "$INSTALL_DIR"
rm -f miniconda.sh

# 非 root 时把安装目录交给当前用户，后续 conda 操作才不需要 sudo
if [ "$(id -u)" -ne 0 ]; then
  $SUDO chown -R "$(id -un):$(id -gn)" "$INSTALL_DIR"
fi

# 2) 接受 TOS（如需）
$SUDO "$INSTALL_DIR/bin/conda" tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main || true
$SUDO "$INSTALL_DIR/bin/conda" tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r || true

# 3) 让当前脚本会话立刻能用 conda
source "$INSTALL_DIR/etc/profile.d/conda.sh"

# 可选：不自动激活 base
conda config --set auto_activate_base false

# 4) 创建并激活环境
conda create -y -n "$ENV_NAME" python=3.11
conda activate "$ENV_NAME"

# 5) 永久生效（往 ~/.bashrc 写 hook）
conda init bash

echo
echo "[OK] Miniconda 安装完成，当前环境：$(conda env list | awk '/\*/{print $1}')"
python -V

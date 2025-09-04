#!/bin/bash
set -e

# ========= 配置 =========
CLASH_DIR="$HOME/.config/clash"
BIN_PATH="/usr/local/bin/clash-meta"
RELEASE_API="https://api.github.com/repos/MetaCubeX/Clash.Meta/releases/latest"
GH_PROXY="https://ghfast.top/"

# ========= 检查依赖 =========
if ! command -v wget >/dev/null 2>&1; then
  echo "缺少 wget，请先安装: apt install -y wget 或 yum install -y wget"
  exit 1
fi

if ! command -v tar >/dev/null 2>&1; then
  echo "缺少 tar，请先安装: apt install -y tar 或 yum install -y tar"
  exit 1
fi

# ========= 检测架构 =========
ARCH=$(uname -m)
case "$ARCH" in
  x86_64)   ARCH="amd64" ;;
  aarch64)  ARCH="arm64" ;;
  *) echo "暂不支持的架构: $ARCH"; exit 1 ;;
esac

echo "检测到架构: $ARCH"

# ========= 获取最新版本号 =========
VERSION=$(wget -qO- "$RELEASE_API" | grep tag_name | head -n1 | cut -d '"' -f4)
if [ -z "$VERSION" ]; then
  echo "无法获取 Clash.Meta 最新版本号"
  exit 1
fi
echo "最新版本: $VERSION"

# ========= 下载并安装内核 =========
TMP_DIR=$(mktemp -d)
cd "$TMP_DIR"
FILE="clash.meta-linux-$ARCH-$VERSION.gz"
URL="https://github.com/MetaCubeX/Clash.Meta/releases/download/$VERSION/$FILE"

echo "下载 Clash.Meta 内核: $URL"
wget -O clash.gz "$GH_PROXY$URL"
gunzip clash.gz
mv clash "$BIN_PATH"
chmod +x "$BIN_PATH"

echo "Clash.Meta 已安装到 $BIN_PATH"

# ========= 准备配置目录 =========
mkdir -p "$CLASH_DIR"

# ========= 下载 Geo 数据 =========
echo "下载 Country.mmdb"
wget -qO "$CLASH_DIR/Country.mmdb" \
  "${GH_PROXY}https://github.com/Loyalsoldier/geoip/releases/latest/download/Country.mmdb"

echo "下载 geoip.dat & geosite.dat"
wget -qO "$CLASH_DIR/geoip.dat" \
  "${GH_PROXY}https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat"
wget -qO "$CLASH_DIR/geosite.dat" \
  "${GH_PROXY}https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat"

echo "所有文件已放置在 $CLASH_DIR"

# ========= 提示用户 =========
echo "安装完成！"
echo "请将你的配置文件放在: $CLASH_DIR/config.yaml"
echo "运行 Clash: clash-meta -d $CLASH_DIR"

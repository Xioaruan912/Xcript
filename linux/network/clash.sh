#!/usr/bin/env bash
set -e

# ========= 配置 =========
CLASH_DIR="${CLASH_DIR:-$HOME/.config/clash}"
BIN_PATH="${BIN_PATH:-/usr/local/bin/clash-meta}"
REPO="MetaCubeX/mihomo"                 # 原 Clash.Meta 仓库已更名为 mihomo
GH_PROXY="https://ghfast.top/"          # 国内加速前缀

# ========= 提权：支持 bash <(curl ...) 直接运行（保留上面的配置目录） =========
if [ "$(id -u)" -ne 0 ]; then
  if ! command -v sudo >/dev/null 2>&1; then
    echo "需要 root 权限运行，请切换到 root 用户后重试。" >&2
    exit 1
  fi
  # bash <(curl ...) 时 $0 是 /dev/fd/*，sudo 会关闭该 fd，所以先复制到临时文件
  SELF_TMP="$(mktemp /tmp/xcript-clash-XXXXXX.sh 2>/dev/null || echo "/tmp/xcript-clash-$$.sh")"
  if ! cat "$0" > "$SELF_TMP" 2>/dev/null; then
    echo "读取自身脚本失败，请先下载脚本到本地再运行。" >&2
    exit 1
  fi
  chmod +x "$SELF_TMP"
  echo ">>> 需要 root 权限，正在通过 sudo 重新执行..."
  exec sudo env "CLASH_DIR=$CLASH_DIR" "BIN_PATH=$BIN_PATH" bash "$SELF_TMP" "$@"
fi

# ========= 下载工具：curl 优先，回退 wget =========
if command -v curl >/dev/null 2>&1; then
  FETCH()    { curl -fsSL --connect-timeout 15 "$1"; }
  FETCH_TO() { curl -fL --connect-timeout 15 --retry 2 -o "$2" "$1"; }
elif command -v wget >/dev/null 2>&1; then
  FETCH()    { wget -qO- "$1"; }
  FETCH_TO() { wget -O "$2" "$1"; }
else
  echo "缺少 curl / wget，请先安装：apt install -y curl" >&2
  exit 1
fi

if ! command -v gzip >/dev/null 2>&1; then
  echo "缺少 gzip，请先安装：apt install -y gzip" >&2
  exit 1
fi

# ========= 检测架构 =========
ARCH_RAW="$(uname -m)"
case "$ARCH_RAW" in
  x86_64|amd64)  ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  armv7l|armv7)  ARCH="armv7" ;;
  *) echo "暂不支持的架构: $ARCH_RAW" >&2; exit 1 ;;
esac
echo "检测到架构: $ARCH"

# ========= 获取最新版本号（直连不通自动走加速） =========
echo "获取最新版本号..."
RELEASE_JSON="$(FETCH "https://api.github.com/repos/$REPO/releases/latest" 2>/dev/null \
  || FETCH "${GH_PROXY}https://api.github.com/repos/$REPO/releases/latest" 2>/dev/null \
  || FETCH "${GH_PROXY}https://github.com/$REPO/releases/latest" 2>/dev/null || true)"

VERSION="$(printf '%s' "$RELEASE_JSON" | grep -o '"tag_name":[[:space:]]*"[^"]*"' | head -n1 | cut -d'"' -f4)"
if [ -z "$VERSION" ]; then
  VERSION="$(printf '%s' "$RELEASE_JSON" | grep -o 'releases/tag/[^"]*' | head -n1 | sed 's#.*releases/tag/##')"
fi
if [ -z "$VERSION" ]; then
  echo "无法获取最新版本号，请检查网络后重试。" >&2
  exit 1
fi
echo "最新版本: $VERSION"

# ========= 从 Release 中挑选对应架构的资产（只取 .gz 二进制，排除 deb/rpm/pkg） =========
ASSET_URL="$(printf '%s' "$RELEASE_JSON" \
  | grep -o '"browser_download_url":[[:space:]]*"[^"]*"' \
  | cut -d'"' -f4 \
  | grep -E "linux-${ARCH}-.*\.gz$" \
  | grep -v -E 'compatible|go1[0-9]' \
  | grep -v -E "linux-${ARCH}-v[0-9]-" \
  | head -n1)"
if [ -z "$ASSET_URL" ]; then
  ASSET_URL="https://github.com/$REPO/releases/download/$VERSION/mihomo-linux-${ARCH}-${VERSION}.gz"
fi
echo "内核地址: $ASSET_URL"

# ========= 下载并安装内核 =========
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
cd "$TMP_DIR"

echo "下载内核中..."
if ! FETCH_TO "$ASSET_URL" kernel.gz 2>/dev/null; then
  FETCH_TO "${GH_PROXY}${ASSET_URL}" kernel.gz
fi

# 校验确实是 gzip，否则回退到通用包名
if ! gzip -t kernel.gz 2>/dev/null; then
  FALLBACK="https://github.com/$REPO/releases/download/$VERSION/mihomo-linux-${ARCH}-${VERSION}.gz"
  echo "内核包异常，尝试回退地址..."
  FETCH_TO "$FALLBACK" kernel.gz 2>/dev/null || FETCH_TO "${GH_PROXY}${FALLBACK}" kernel.gz
fi

# 直接解压成目标文件，不再依赖压缩包内部的文件名
mkdir -p "$(dirname "$BIN_PATH")"
gzip -dc kernel.gz > "$BIN_PATH.new"
chmod +x "$BIN_PATH.new"
mv -f "$BIN_PATH.new" "$BIN_PATH"

echo "[OK] 已安装: $BIN_PATH"
"$BIN_PATH" -v 2>/dev/null || true

# ========= 准备配置目录 =========
mkdir -p "$CLASH_DIR"

# ========= 下载 Geo 数据（直连失败自动走加速） =========
fetch_geo() {
  echo "下载 $(basename "$2")"
  FETCH_TO "$1" "$2" 2>/dev/null || FETCH_TO "${GH_PROXY}${1}" "$2"
}

fetch_geo "https://github.com/Loyalsoldier/geoip/releases/latest/download/Country.mmdb" "$CLASH_DIR/Country.mmdb"
fetch_geo "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat" "$CLASH_DIR/geoip.dat"
fetch_geo "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat" "$CLASH_DIR/geosite.dat"

echo "所有文件已放置在 $CLASH_DIR"

# ========= 提示 =========
echo "安装完成！"
echo "1) 把配置文件放到: $CLASH_DIR/config.yaml"
echo "2) 前台运行:      $BIN_PATH -d $CLASH_DIR"
echo "3) 想在当前终端走代理请手动执行（脚本里的 export 不会影响你的终端）："
echo "export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890"

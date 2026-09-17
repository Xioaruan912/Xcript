#!/usr/bin/env bash
# 自动申请 Let's Encrypt 证书（Nginx），并把证书同步到 /etc/nginx/cert/<域名>/
set -euo pipefail

# ---------- 提权：支持 bash <(curl ...) 直接运行 ----------
if [ "$(id -u)" -ne 0 ]; then
  if ! command -v sudo >/dev/null 2>&1; then
    echo "需要 root 权限运行，请切换到 root 用户后重试。" >&2
    exit 1
  fi
  # bash <(curl ...) 时 $0 是 /dev/fd/*，sudo 会关闭该 fd，所以先复制到临时文件
  SELF_TMP="$(mktemp /tmp/xcript-certbot-XXXXXX.sh 2>/dev/null || echo "/tmp/xcript-certbot-$$.sh")"
  if ! cat "$0" > "$SELF_TMP" 2>/dev/null; then
    echo "读取自身脚本失败，请先下载脚本到本地再运行。" >&2
    exit 1
  fi
  chmod +x "$SELF_TMP"
  echo ">>> 需要 root 权限，正在通过 sudo 重新执行..."
  exec sudo bash "$SELF_TMP" "$@"
fi

# 检查是否安装 certbot
if ! command -v certbot >/dev/null 2>&1; then
  echo "[ERR] 未检测到 certbot，正在安装..."
  if command -v apt >/dev/null 2>&1; then
    apt update && apt install -y certbot python3-certbot-nginx
  else
    echo "自动安装仅支持 apt 系，请先手动安装 certbot 后再运行。" >&2
    exit 1
  fi
fi

# 输入域名和邮箱
read -r -p "请输入域名: " DOMAIN
if [ -z "$DOMAIN" ]; then
  echo "域名不能为空" >&2
  exit 1
fi

read -r -p "请输入邮箱: " EMAIL
if [ -z "$EMAIL" ]; then
  echo "邮箱不能为空" >&2
  exit 1
fi

# 申请证书（--nginx 会自己申请并写入 nginx 配置）
certbot --nginx -d "$DOMAIN" --email "$EMAIL" --agree-tos --no-eff-email

# 同步证书到脚本约定目录，方便其它服务引用
CERT_DIR="/etc/nginx/cert/${DOMAIN}"
LIVE_DIR="/etc/letsencrypt/live/${DOMAIN}"
mkdir -p "$CERT_DIR"
cp -Lf "$LIVE_DIR/privkey.pem" "$CERT_DIR/privkey.pem"
cp -Lf "$LIVE_DIR/fullchain.pem" "$CERT_DIR/fullchain.pem"
chmod 600 "$CERT_DIR/privkey.pem"

nginx -t >/dev/null 2>&1 && systemctl reload nginx 2>/dev/null || true

echo "[OK] 证书申请完成"
echo "私钥路径:   $CERT_DIR/privkey.pem"
echo "证书路径:   $CERT_DIR/fullchain.pem"

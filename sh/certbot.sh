#!/usr/bin/env bash
# 该脚本已迁移到新路径：linux/cert/certbot.sh
# 本文件仅用于兼容旧链接，会自动下载并运行新版本。
set -uo pipefail

NEW_URL="https://raw.githubusercontent.com/Xioaruan912/Xcript/main/linux/cert/certbot.sh"
TMP="$(mktemp "${TMPDIR:-/tmp}/xcript-redirect-XXXXXX.sh" 2>/dev/null || echo "/tmp/xcript-redirect-$$.sh")"
trap 'rm -f "$TMP"' EXIT

echo "[*] 脚本已迁移，正在获取新版本：$NEW_URL" >&2
if command -v curl >/dev/null 2>&1; then
  curl -fsSL "$NEW_URL" -o "$TMP"
elif command -v wget >/dev/null 2>&1; then
  wget -qO "$TMP" "$NEW_URL"
else
  echo "需要 curl 或 wget 才能继续。" >&2
  exit 1
fi
chmod +x "$TMP"
bash "$TMP" "$@"
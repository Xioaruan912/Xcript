#!/usr/bin/env bash
# Let's Encrypt 证书：安装 + 签发 + 续期自检（snap 版 certbot，自动提权）
set -uo pipefail

# ---------- 提权：支持 bash <(curl ...) 直接运行 ----------
if [ "$(id -u)" -ne 0 ]; then
  if ! command -v sudo >/dev/null 2>&1; then
    echo "需要 root 权限运行，请切换到 root 用户后重试。" >&2
    exit 1
  fi
  # bash <(curl ...) 时 $0 是 /dev/fd/*，sudo 会关闭该 fd，所以先复制到临时文件
  SELF_TMP="$(mktemp /tmp/xcript-ssl-XXXXXX.sh 2>/dev/null || echo "/tmp/xcript-ssl-$$.sh")"
  if ! cat "$0" > "$SELF_TMP" 2>/dev/null; then
    echo "读取自身脚本失败，请先下载脚本到本地再运行。" >&2
    exit 1
  fi
  chmod +x "$SELF_TMP"
  echo ">>> 需要 root 权限，正在通过 sudo 重新执行..."
  exec sudo bash "$SELF_TMP" "$@"
fi

# ===== 输入 =====
read -r -p "请输入邮箱 (用于Let’s Encrypt通知): " email
read -r -p "请输入你的域名 (例如 example.com): " domain

if [ -z "${email:-}" ] || [ -z "${domain:-}" ]; then
  echo "邮箱和域名都不能为空。" >&2
  exit 1
fi

# ===== 依赖 & certbot（snap 版）=====
if command -v apt >/dev/null 2>&1; then
  apt update -y
  apt install -y nginx snapd
fi

if command -v snap >/dev/null 2>&1; then
  snap install core || true
  snap refresh core || true
  if ! snap list 2>/dev/null | grep -q '^certbot '; then
    snap install --classic certbot
  fi
  ln -sf /snap/bin/certbot /usr/bin/certbot
fi

# 防火墙（若存在 ufw）
if command -v ufw >/dev/null 2>&1; then
  ufw allow 'Nginx Full' || true
fi

# ===== 处理可能的 Nginx 冲突 =====
# 禁用默认站点（如存在）
[ -f /etc/nginx/sites-enabled/default ] && unlink /etc/nginx/sites-enabled/default || true

# 若有其它泛监听站点导致冲突，可根据需要在此禁用：
# [ -f /etc/nginx/sites-enabled/list.722225.xyz ] && unlink /etc/nginx/sites-enabled/list.722225.xyz || true

# 确保 Nginx 运行
if command -v systemctl >/dev/null 2>&1; then
  systemctl enable nginx || true
  systemctl start nginx || true
fi
nginx -t && { systemctl reload nginx 2>/dev/null || true; }

# ===== 申请证书并自动写 Nginx 配置 =====
if ! certbot --nginx -d "$domain" -m "$email" --agree-tos --no-eff-email --redirect --non-interactive; then
  echo "[ERR] 证书申请失败。请检查 DNS 是否指向本机、80/443 端口是否放行、以及 Nginx 配置是否冲突。" >&2
  exit 2
fi

# ===== 成功后输出信息 =====
cert_path="/etc/letsencrypt/live/$domain"
nginx_conf="/etc/nginx/sites-available/$domain"

if [ -f "$cert_path/fullchain.pem" ] && [ -f "$cert_path/privkey.pem" ]; then
  nginx -t && { systemctl reload nginx 2>/dev/null || true; }
  echo
  echo "[OK] SSL 配置完成！你现在可以通过 https://$domain 访问了。"
  echo "--------------------------------------------"
  echo "证书存放目录: $cert_path"
  echo "- 公钥证书: $cert_path/fullchain.pem"
  echo "- 私钥证书: $cert_path/privkey.pem"
  echo
  echo "Nginx 配置文件: $nginx_conf"
  echo
  echo "证书到期时间:"
  openssl x509 -in "$cert_path/fullchain.pem" -noout -dates 2>/dev/null | sed 's/^/   /' || true
  echo
  echo "自动续期测试:"
  certbot renew --dry-run 2>&1 | sed 's/^/   /' || true
  echo "--------------------------------------------"
else
  echo "[ERR] 未找到签发后的证书文件（$cert_path）。请查看 certbot 输出日志排查。" >&2
  exit 3
fi

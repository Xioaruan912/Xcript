#!/usr/bin/env bash
set -euo pipefail

# ===== 输入 =====
if [ "$(id -u)" -ne 0 ]; then
  echo "请使用 root 用户运行此脚本." >&2
  exit 1
fi

read -p "请输入邮箱 (用于Let’s Encrypt通知): " email
read -p "请输入你的域名 (例如 example.com): " domain

# ===== 依赖 & certbot（snap 版）=====
apt update -y
apt install -y nginx snapd
snap install core
snap refresh core
if ! snap list | grep -q '^certbot '; then
  snap install --classic certbot
fi
ln -sf /snap/bin/certbot /usr/bin/certbot

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
systemctl enable nginx
systemctl start nginx
nginx -t && systemctl reload nginx

# ===== 申请证书并自动写 Nginx 配置 =====
if ! certbot --nginx -d "$domain" -m "$email" --agree-tos --redirect --non-interactive; then
  echo "❌ 证书申请失败。请检查 DNS 是否指向本机、80/443 端口是否放行、以及 Nginx 配置是否冲突。" >&2
  exit 2
fi

# ===== 成功后输出信息 =====
cert_path="/etc/letsencrypt/live/$domain"
nginx_conf="/etc/nginx/sites-available/$domain"

if [ -f "$cert_path/fullchain.pem" ] && [ -f "$cert_path/privkey.pem" ]; then
  nginx -t && systemctl reload nginx
  echo
  echo "✅ SSL 配置完成！你现在可以通过 https://$domain 访问了。"
  echo "--------------------------------------------"
  echo "📂 证书存放目录: $cert_path"
  echo "   - 公钥证书: $cert_path/fullchain.pem"
  echo "   - 私钥证书: $cert_path/privkey.pem"
  echo
  echo "📝 Nginx 配置文件: $nginx_conf"
  echo
  echo "📅 证书到期时间:"
  openssl x509 -in "$cert_path/fullchain.pem" -noout -dates | sed 's/^/   /'
  echo
  echo "🔄 自动续期测试:"
  certbot renew --dry-run | sed 's/^/   /'
  echo "--------------------------------------------"
else
  echo "❌ 未找到签发后的证书文件（$cert_path）。请查看 certbot 输出日志排查。" >&2
  exit 3
fi

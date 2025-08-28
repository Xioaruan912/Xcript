#!/bin/bash
# 自动申请 Let's Encrypt 证书 (Nginx)
# 使用 certbot 并将证书存放到 /etc/nginx/cert/<域名>/

# 检查是否安装 certbot
if ! command -v certbot >/dev/null 2>&1; then
    echo "❌ 未检测到 certbot，正在安装..."
    sudo apt update && sudo apt install -y certbot python3-certbot-nginx
fi

# 输入域名和邮箱
read -p "请输入域名: " DOMAIN
read -p "请输入邮箱: " EMAIL

# 创建存放路径
CERT_DIR="/etc/nginx/cert/${DOMAIN}"
sudo mkdir -p "$CERT_DIR"

# 运行 certbot
sudo certbot --nginx \
  -d "$DOMAIN" \
  --key-path "$CERT_DIR/privkey.pem" \
  --fullchain-path "$CERT_DIR/fullchain.pem" \
  --email "$EMAIL" \
  --agree-tos \
  --no-eff-email

# 输出结果
echo "✅ 证书申请完成"
echo "🔑 私钥路径:   $CERT_DIR/privkey.pem"
echo "📄 证书路径:   $CERT_DIR/fullchain.pem"

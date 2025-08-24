#!/bin/bash
# 自动申请 Let’s Encrypt 证书并配置 Nginx

# 检查是否 root
if [ "$(id -u)" != "0" ]; then
   echo "请使用 root 用户运行此脚本."
   exit 1
fi

# 输入邮箱和域名
read -p "请输入邮箱 (用于Let’s Encrypt通知): " email
read -p "请输入你的域名 (例如 example.com): " domain

# 更新系统并安装必要工具
apt update -y
apt install -y nginx certbot python3-certbot-nginx

# 启动并设置 nginx 开机自启
systemctl enable nginx
systemctl start nginx

# 申请证书并自动配置 nginx
certbot --nginx -d "$domain" --email "$email" --agree-tos --redirect --non-interactive

# 测试 nginx 配置
nginx -t && systemctl reload nginx

# 证书目录
cert_path="/etc/letsencrypt/live/$domain"

echo
echo "✅ SSL 配置完成！你现在可以通过 https://$domain 访问了。"
echo "--------------------------------------------"
echo "📂 证书存放目录: $cert_path"
echo "   - 公钥证书: $cert_path/fullchain.pem"
echo "   - 私钥证书: $cert_path/privkey.pem"
echo
echo "📝 Nginx 配置文件: /etc/nginx/sites-available/$domain"
echo
echo "📅 证书到期时间:"
openssl x509 -in $cert_path/fullchain.pem -noout -dates | sed 's/^/   /'
echo
echo "🔄 自动续期测试:"
certbot renew --dry-run | sed 's/^/   /'
echo "--------------------------------------------"

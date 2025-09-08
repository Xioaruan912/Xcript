#!/bin/bash

# 确保以 root 用户运行
if [ "$(id -u)" -ne 0 ]; then
    echo "请以 root 用户运行该脚本！"
    exit 1
fi

# 检查BBR是否已启用
echo "检查BBR是否启用..."
sysctl net.ipv4.tcp_congestion_control | grep bbr && echo "BBR 已启用" || echo "BBR 启用失败，正在尝试启用..."

# 启用BBR
echo "启用BBR加速..."
echo "net.core.default_qdisc=fq" | tee -a /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" | tee -a /etc/sysctl.conf
sysctl -p

# 检查BBR是否成功启用
if sysctl net.ipv4.tcp_congestion_control | grep -q "bbr"; then
    echo "BBR 已成功启用！"
else
    echo "BBR 启用失败，请检查系统配置。"
    exit 1
fi

# 安装 realm
echo "安装 realm..."
mkdir -p /root/realm
cd /root/realm
wget https://github.com/zhboner/realm/releases/download/v2.7.0/realm-x86_64-unknown-linux-gnu.tar.gz
tar -xzvf realm-x86_64-unknown-linux-gnu.tar.gz
chmod +x realm
mv realm /usr/local/bin/
rm realm-x86_64-unknown-linux-gnu.tar.gz

# 配置 realm.toml 文件
echo "配置 realm.toml 文件..."
cat <<EOF > /root/realm/realm.toml
[log]
level = "warn"
output = "/root/realm.log"

[network]
use_udp = true
tcp_timeout = 10
udp_timeout = 30
tcp_keepalive = 15

[[endpoints]]
listen = "0.0.0.0:端口"
remote = "目标IP:端口"

[[endpoints]]
listen = "0.0.0.0:端口"
remote = "目标IP:端口"
EOF

# 创建 systemd 服务文件
echo "配置 realm 自启动服务..."
cat <<EOF > /etc/systemd/system/realm.service
[Unit]
Description=Realm Proxy Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/realm -c /root/realm/realm.toml
Restart=on-failure
RestartSec=5
User=root

[Install]
WantedBy=multi-user.target
EOF

# 重新加载 systemd 配置并启用 realm 服务
echo "启用 realm 服务..."
systemctl daemon-reload
systemctl enable realm
systemctl restart realm

# 显示服务状态

echo "所有配置完成！ 去/root/realm/realm.toml 修改配置文件"
echo "然后执行 systemctl restart realm" 

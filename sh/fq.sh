#!/bin/bash
clear
echo "-------------安装--------------"
echo "请选择操作："
echo "【1】一键安装x-ui"
echo "【2】一键安装Vless"
echo "【3】一键安装Xboard 节点管理系统"

read -p "请输入选项： " input

if [ "$input" == "1" ]; then
    echo "一键安装x-ui"
    apt update -y 
    apt install curl wget -y
    bash <(curl -Ls https://raw.githubusercontent.com/FranzKafkaYu/x-ui/master/install.sh) 
    clear
    echo "安装成功"
    echo "使用文档：https://v2rayssr.com/reality.html" 
    echo "选择 8  查看面板信息"
    x-ui
elif [ "$input" == "2" ]; then
    echo "一键安装Vless"
    wget -P /root -N --no-check-certificate "https://raw.githubusercontent.com/mack-a/v2ray-agent/master/install.sh" && chmod 700 /root/install.sh && /root/install.sh
elif [ "$input" == "3" ]; then
    # 检查 Docker 是否已安装
    if command -v docker >/dev/null 2>&1; then
        echo "Docker 已经安装，跳过安装"
    else
        echo "Docker 未安装，开始安装"
        curl -sSL https://get.docker.com | bash
        systemctl enable docker
        systemctl start docker
    fi

    # 确保 git 已安装
    apt install git -y

    # 克隆 Xboard 仓库并安装
    git clone -b docker-compose --depth 1 https://github.com/cedar2025/Xboard
    cd Xboard
    clear

    # 运行 Xboard 安装
    docker compose run -it --rm xboard php artisan xboard:install
    docker compose up -d

    # 获取外网 IP
    IP=$(curl -s ifconfig.me)
    echo "Xboard 节点管理系统安装成功"
    echo "访问 http://$IP:7001"
else
    echo "无效的选项，程序退出。"
fi

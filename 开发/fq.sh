#!/bin/bash
clear
echo "-------------安装--------------"
echo "请选择操作："
echo "【1】一键安装x-ui"
echo "【2】一键安装XrayR"
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
    echo "一键安装XrayR"
    apt update -y 
    apt install curl wget -y
    bash <(curl -Ls https://raw.githubusercontent.com/XrayR-project/XrayR-release/master/install.sh)
    clear

    # 请求用户输入NodeID、节点类型、ApiHost和ApiKey
    read -p "请输入NodeID: " ID
    echo "节点类型  V2ray, Vmess, Vless, Shadowsocks, Trojan, Shadowsocks-Plugin"
    read -p "请输入节点类型: " NoteID
    read -p "请输入ApiHost(面板地址): " ApiHost
    read -p "请输入ApiKey(面板通信密钥): " ApiKey

    # 使用用户输入的信息替换配置文件
    sudo bash -c "cat <<EOF > /etc/XrayR/config.yml
Log:
  Level: warning # Log level: none, error, warning, info, debug
  AccessPath: # /etc/XrayR/access.Log
  ErrorPath: # /etc/XrayR/error.log
DnsConfigPath: # /etc/XrayR/dns.json # Path to dns config, check https://xtls.github.io/config/dns.html for help
RouteConfigPath: # /etc/XrayR/route.json # Path to route config, check https://xtls.github.io/config/rouating.html for help
InboundConfigPath: # /etc/XrayR/custom_inbound.json # Path to custom inbound config, check https://xtls.github.io/config/inbound.html for help
OutboundConfigPath: # /etc/XrayR/custom_outbound.json # Path to custom outbound config, check https://xtls.github.io/config/outbound.html for help
ConnectionConfig:
  Handshake: 4 # Handshake time limit, Second
  ConnIdle: 30 # Connection idle time limit, Second
  UplinkOnly: 2 # Time limit when the connection downstream is closed, Second
  DownlinkOnly: 4 # Time limit when the connection is closed after the uplink is closed, Second
  BufferSize: 64 # The internal cache size of each connection, kB
Nodes:
  - PanelType: \"NewV2board\" # Panel type: SSpanel, NewV2board, PMpanel, Proxypanel, V2RaySocks, GoV2Panel, BunPanel
    ApiConfig:
      ApiHost: \"${ApiHost}\"
      ApiKey: \"${ApiKey}\"
      NodeID: $ID
      NodeType: $NoteID # Node type: V2ray, Vmess, Vless, Shadowsocks, Trojan, Shadowsocks-Plugin
      Timeout: 30 # Timeout for the api request
      EnableVless: true  # Enable Vless for V2ray Type
      VlessFlow: \"xtls-rprx-vision\" # Only support vless
      SpeedLimit: 0 # Mbps, Local settings will replace remote settings, 0 means disable
      DeviceLimit: 0 # Local settings will replace remote settings, 0 means disable
      RuleListPath: # /etc/XrayR/rulelist Path to local rulelist file
      DisableCustomConfig: false # disable custom config for sspanel
    ControllerConfig:
      ListenIP: 0.0.0.0 # IP address you want to listen
      SendIP: 0.0.0.0 # IP address you want to send pacakage
      UpdatePeriodic: 60 # Time to update the nodeinfo, how many sec.
      EnableDNS: false # Use custom DNS config, Please ensure that you set the dns.json well
      DNSType: AsIs # AsIs, UseIP, UseIPv4, UseIPv6, DNS strategy
      EnableProxyProtocol: false # Only works for WebSocket and TCP
      AutoSpeedLimitConfig:
        Limit: 0 # Warned speed. Set to 0 to disable AutoSpeedLimit (mbps)
        WarnTimes: 0 # After (WarnTimes) consecutive warnings, the user will be limited. Set to 0 to punish overspeed user immediately.
        LimitSpeed: 0 # The speedlimit of a limited user (unit: mbps)
        LimitDuration: 0 # How many minutes will the limiting last (unit: minute)
      GlobalDeviceLimitConfig:
        Enable: false # Enable the global device limit of a user
        RedisNetwork: tcp # Redis protocol, tcp or unix
        RedisAddr: 127.0.0.1:6379 # Redis server address, or unix socket path
        RedisUsername: # Redis username
        RedisPassword: YOUR PASSWORD # Redis password
        RedisDB: 0 # Redis DB
        Timeout: 5 # Timeout for redis request
        Expiry: 60 # Expiry time (second)
      EnableFallback: false # Only support for Trojan and Vless
      FallBackConfigs:  # Support multiple fallbacks
        - SNI: # TLS SNI(Server Name Indication), Empty for any
          Alpn: # Alpn, Empty for any
          Path: # HTTP PATH, Empty for any
          Dest: 80 # Required, Destination of fallback, check https://xtls.github.io/config/features/fallback.html for details.
          ProxyProtocolVer: 0 # Send PROXY protocol version, 0 for disable
      DisableLocalREALITYConfig: true # disable local reality config
      EnableREALITY: true # Enable REALITY
      REALITYConfigs:
        Show: true # Show REALITY debug
        Dest: www.amazon.com:443 # Required, Same as fallback
        ProxyProtocolVer: 0 # Send PROXY protocol version, 0 for disable
        ServerNames: # Required, list of available serverNames for the client, * wildcard is not supported at the moment.
          - www.amazon.com
        PrivateKey: YOUR_PRIVATE_KEY # Required, execute './XrayR x25519' to generate.
        MinClientVer: # Optional, minimum version of Xray client, format is x.y.z.
        MaxClientVer: # Optional, maximum version of Xray client, format is x.y.z.
        MaxTimeDiff: 0 # Optional, maximum allowed time difference, unit is in milliseconds.
        ShortIds: # Required, list of available shortIds for the client, can be used to differentiate between different clients.
          - \"\"
          - 0123456789abcdef
      CertConfig:
        CertMode: dns # Option about how to get certificate: none, file, http, tls, dns. Choose \"none\" will forcedly disable the tls config.
        CertDomain: \"node1.test.com\" # Domain to cert
        CertFile: /etc/XrayR/cert/node1.test.com.cert # Provided if the CertMode is file
        KeyFile: /etc/XrayR/cert/node1.test.com.key
        Provider: alidns # DNS cert provider, Get the full support list here: https://go-acme.github.io/lego/dns/
        Email: test@me.com
        DNSEnv: # DNS ENV option used by DNS provider
          ALICLOUD_ACCESS_KEY: aaa
          ALICLOUD_SECRET_KEY: bbb
EOF"
    sudo XrayR restart
    echo "XrayR配置完成，NodeID已设置为$ID"
    echo "ApiHost已设置为: $ApiHost"
    echo "ApiKey已设置为: $ApiKey"
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
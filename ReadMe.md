# 🌐 Xcript 脚本集合

> 🚀 本项目收录了我日常使用或通过 AI 辅助开发的脚本，涵盖科学上网、自动备份、Clash 配置等实用工具。持续维护中，欢迎自用、二次开发或贡献改进！

## 📁 项目结构

```
bash复制编辑Xcript/
├── 开发/
│   ├── fq.sh           # 科学上网环境初始化脚本
│   └── backup.sh       # 多组件备份自动化脚本
├── 配置文件/
│   └── clash.yaml      # XBoard 专用 Clash 配置模板
```

### 科学上网初始化（fq.sh）

```
curl -sSL -o fq.sh "https://raw.githubusercontent.com/Xioaruan912/Xcript/main/sh/fq.sh" && chmod +x fq.sh && ./fq.sh && rm fq.sh
```

### 安装MiniConda脚本（fq.sh）

```
curl -sSL -o miniconda.sh "https://raw.githubusercontent.com/Xioaruan912/Xcript/main/sh/miniconda.sh" && chmod +x miniconda.sh && ./miniconda.sh && rm miniconda.sh
```

### Docker 安装脚本(docker.sh)

```
curl -sSL -o docker.sh "https://raw.githubusercontent.com/Xioaruan912/Xcript/main/sh/docker.sh" && chmod +x docker.sh && ./docker.sh && rm docker.sh
```

### Docker 国内安装 安装脚本(docker.sh)

```
curl -sSL -o docker.sh "https://ghfast.top/https://raw.githubusercontent.com/Xioaruan912/Xcript/main/sh/CN/docker.sh" && chmod +x docker.sh && ./docker.sh && rm docker.sh
```

### CertBot 证书自签(certbot.sh)

```
curl -sSL -o certbot.sh "https://ghfast.top/https://raw.githubusercontent.com/Xioaruan912/Xcript/main/sh/certbot.sh" && chmod +x certbot.sh && ./certbot.sh && rm certbot.sh
```

###  Docker rebuild安装脚本(docker_rebuild.sh)

```
curl -sSL -o docker_rebuild.sh "https://raw.githubusercontent.com/Xioaruan912/Xcript/main/sh/docker_rebuild.sh" && chmod +x docker_rebuild.sh && ./docker_rebuild.sh && rm docker_rebuild.sh
```

### Jellyfin 安装脚本(Jellyfin .sh)

```
curl -sSL -o Jellyfin.sh "https://raw.githubusercontent.com/Xioaruan912/Xcript/main/sh/Jellyfin.sh" && chmod +x Jellyfin.sh && ./Jellyfin.sh && rm Jellyfin.sh
```

### rclone 安装脚本(rclone .sh)

```
curl -sSL -o rclone.sh "https://raw.githubusercontent.com/Xioaruan912/Xcript/main/sh/rclone.sh" && chmod +x rclone.sh && ./rclone.sh && rm rclone.sh
```

### Vaultwarden安装脚本(vaultwarden.sh)

```
curl -sSL -o vaultwarden.sh "https://raw.githubusercontent.com/Xioaruan912/Xcript/main/sh/vaultwarden.sh" && chmod +x vaultwarden.sh && ./vaultwarden.sh && rm vaultwarden.sh
```

### 一键备份脚本（backup.sh）

```
curl -sSL -o backup.sh "https://raw.githubusercontent.com/Xioaruan912/Xcript/main/sh/backup.sh" && chmod +x backup.sh && ./backup.sh && rm backup.sh
```

### Let’s Encrypt (let_encrypt.sh)

```
curl -sSL -o let_encrypt.sh "https://raw.githubusercontent.com/Xioaruan912/Xcript/main/sh/let_encrypt.sh" && chmod +x let_encrypt.sh && ./let_encrypt.sh && rm let_encrypt.sh
```

### 设置上海时区（timeset_Shanghai.sh）

```
curl -sSL -o timeset_Shanghai.sh "https://raw.githubusercontent.com/Xioaruan912/Xcript/main/sh/timeset_Shanghai.sh" && chmod +x timeset_Shanghai.sh && ./timeset_Shanghai.sh && rm timeset_Shanghai.sh
```



# 🔧 第三方推荐工具

### [nodequality](https://nodequality.com/)

```
bash <(curl -sL https://run.NodeQuality.com)
```

### [NodeScriptKit](https://github.com/NodeSeekDev/NodeScriptKit)

```
bash <(curl -sL https://sh.nodeseek.com)
```

### [clash-for-linux-install](https://github.com/nelvko/clash-for-linux-install)

```
git clone --branch master --depth 1 https://gh-proxy.com/https://github.com/nelvko/clash-for-linux-install.git \
  && cd clash-for-linux-install \
  && sudo bash install.sh
```

### [迷之调参](https://omnitt.com/)

```
据说有神效
```



# 🧪 VPS 测试记录

| 是否拥有 | 是否续费 | 服务器         | 地区         | 测试时间        | 续费价格（CNY） | NQ检测链接                                                   | 评价                    |
| -------- | -------- | -------------- | ------------ | --------------- | --------------- | ------------------------------------------------------------ | ----------------------- |
| ✅        | ❌        | Claw           | JP优化路线   | 2025/7/23 23:04 | 59/季           | [NQ](https://nodequality.com/r/pVhuqeZBn5qoBRAC8qZDPvIblXXoR1Yg) | 主用线路机 三网优化好用 |
| ❌        |          | Claw           | HK优化线路   | 2025/7/24 10:04 | 59/季           | [NQ]( https://nodequality.com/r/tXw4EQ9uvZv4SAPRpXjAoPhetOJgn51c) | 清退了                  |
| ❌        |          | 亚洲云         | 四川大带宽   | 2025/7/23 23:01 | 99/年           | [NQ](https://nodequality.com/r/YpOzhrkGYfLtjAUqApiABwkJfVgNlA75) | 一般                    |
| ✅        | ❌        | 亚洲云         | 日本三网精品 | 2025/8/18 14:01 | 17.5/月         | [NQ]( https://nodequality.com/r/5ABzV20fZTB0AtJTsfUmIhT2zcBruAkp) | 感觉还不错？            |
| ✅        | ✅        | 亚洲云         | 香港CN2      | 2025/7/23 23:12 | 99/年           | [NQ](https://nodequality.com/r/MR1siE0AhfXmBWyuAQDJtKTfWfeJv0A9) | 感觉还不错？            |
| ✅        | ✅        | GGY            | 广港专线NAT  | 2025/7/23 23:16 | 99/年           | [NQ](https://nodequality.com/r/dNBQzGExdryVuxbt0ETfCHYk5EFJaOF3) |                         |
| ✅        | ✅        | GGY            | 沪日专线NAT  | 2025/7/23 23:14 | 99/年           | [NQ](https://nodequality.com/r/4k5FbPAJMDMDAKeao794wUP5JJ6LnwTa) |                         |
| ✅        | ❌        | GGY            | 苏港专线NAT  | 2025/7/23 23:07 | 119/年          | [NQ](https://nodequality.com/r/13WGZ2D5WTA1aFKHg7qlRoJCf7Wikkh7) |                         |
| ✅        | ❌        | ZGOCLOUD       | USA          | 2025/7/23 23:12 | 72/年           | [NQ](https://nodequality.com/r/0ZxJh84cZe2nIcRfnPVkZ8zzei4EDeAW) | 一般                    |
| ✅        | ❌        | BitsFlowCloud  | USA          | 2025/7/23 23:11 | 68/年           | [NQ](https://nodequality.com/r/bAVKQbkpv5gv3ZArR0Xs14Asme7d0usE) | 一般                    |
| ✅        | ❌        | BitsFlowCloud  | USA \| CHINA | 2025/7/30 23:11 | 168/年          | [NQ](https://nodequality.com/r/UC39b2fKAndPcezxhz0xVrDyZYl1AvT9) | 一般                    |
| ✅        | ❌        | NetJett 4C6G   | USA          | 2025/7/23 23:10 | 163/年          | [NQ](https://nodequality.com/r/qcdoK83MsRddvlA72UvDB0sOAUN4TsFD) |                         |
| ❌        |          | NetJett v6Only | USA          | 2025/7/24 10:12 | free/年         | [NQ](https://nodequality.com/r/Akdhw4AypALC5nBIlclXqhbNiyQBcjvm) |                         |
| ❌        |          | NetJett  3C7G  | USA          | 2025/7/28 11:40 | free/月         | [NQ](https://nodequality.com/r/xBjCBVwt8eM0bzn3ywkdKIolmOOYIys3) |                         |
| ✅        | ✅        | NetJett 8C8G   | USA          | 2025/8/21 23:09 | 100/年          | [NQ](https://nodequality.com/r/lurAsz7271iEsVU0vsAl13cQ1zpra71w) |                         |
| ❌        |          | ACCKCloud      | JP           | 2025/7/23 23:09 | 14/月           | [NQ](https://nodequality.com/r/6XmYLBLCbh3egjGeyLDUHuhs0plntAWP) | 一般                    |
| ❌        |          | HaloCloud      | SG           | 2025/7/23 23:15 | 10/月           | [NQ](https://nodequality.com/r/GuMOKW4gbIXbtC0xbuHMWMEzfMzGztBV) | 一般                    |
| ✅        | ❌        | HaloCloud      | 深港专线NAT  | 2025/8/19 20:34 | 30/月           | [NQ](https://nodequality.com/r/ZBbw0d1bDyE6JfKvw7r3co3WLqtRWAOL) | 大口子并且商家负责任    |
| ✅        | ❌        | Orange         | SG           | 2025/7/23 23:40 | 163/年          | [NQ](https://nodequality.com/r/NKYsApk9ckug5lrfbs68kgLpdqLZgOFM) | 一般                    |
| ❌        |          | VKVM           | JP China     | 2025/7/26 13:15 | 189/年          | [NQ](https://nodequality.com/r/o2nkAR2pAMjgRb99ok3VKxaoYmdJ4q5S) | 差劲                    |
| ❌        |          | VKVM           | HK China     | 2025/7/26 13:00 | 60/季           | [NQ](https://nodequality.com/r/CsdkNltlUALPGkkuJ18AXkcBtSYB5SZE) | 差劲                    |
| ✅        | ❌        | MHYIDC         | HK->TW       | 2025/7/30 13:00 | 9.9/月          | [NQ](https://nodequality.com/r/N6KhB6h40hpbI8ncT4TWQbcDA2UOBozt) |                         |
| ❌        |          | Back Waves     | JP           | 2025/7/31 20:00 | 19.9/月         | [NQ](https://nodequality.com/r/H2Mrojj3ZennAXeG8ALTeBKzDCRvRx83) |                         |
| ❌        |          | VMISS          | KR           | 2025/7/02 01:00 | 24.5/月         | [NQ](https://nodequality.com/r/1BYxQjc5qEB7oEA8ThElPv7wMRp5RurQ) |                         |
| ❌        |          | ISIF           | HK           | 2025/8/05 01:00 | 23/月           | [NQ](https://nodequality.com/r/XKxFYBq7fFEpY12KxYB5hiSDy8ZW1znP) |                         |
| ❌        |          | ISIF           | JP           | 2025/8/05 10:00 | 300/年          | [NQ]( https://nodequality.com/r/8jyl6t0qwRzOBNDKDo1BiBE6aopta34f) |                         |
| ✅        | ✅        | YXVM           | HK           | 2025/8/06 01:00 | 21/月           | [NQ](https://nodequality.com/r/XJTLmmk3JrwgYvU8VNE7CAxIKGhYQj1Q) |                         |
| ✅        | ✅        | Bandwagonhost  | USA          | 2025/8/19 20:34 | 203/年          | [NQ]( https://nodequality.com/r/mhyZMAe6FudUH792IjkE04GT8ERXYTeP) | 老商家 需要邀请码       |
|          |          | Legendvps      | SG           | 2025/9/1 20:34  | 3/cny           | [NQ](https://nodequality.com/r/YY32dWhzTxlWVvv0teWM0tkfXAAsql8H) |                         |

|   确定续费    |    地区     | 续费价格（CNY） |
| :-----------: | :---------: | :-------------: |
|      GGY      | 广港专线NAT |      99/年      |
|      GGY      | 沪日专线NAT |      99/年      |
|    亚洲云     |   香港CN2   |      99/年      |
|    Netjett    |    美国     |     100/年      |
|     YXVM      |    香港     |     252/年      |
| Bandwagonhost |    美国     |     203/年      |



## 🛠 未来计划

-  添加 PushDeer 通知模块
-  对接更多云服务自动备份（如阿里、腾讯 COS）
-  添加自建CDN项目 用于快速通过Nginx构建CDN 并且封锁IP+端口

# 🙇感谢

>不分先后

[NodeSeek论坛](https://www.nodeseek.com/)

[digvps(专注 VPS 测评)](https://digvps.com/)


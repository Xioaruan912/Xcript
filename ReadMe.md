# 🌐 Xcript 脚本集合

> 🚀 本项目收录了我日常使用或通过 AI 辅助开发的实用脚本，涵盖环境配置、容器管理、备份工具等。持续维护中，欢迎使用和改进！

> [!CAUTION]
> 本仓库发布的脚本仅用于学习和研究目的，**不得将本仓库内容用于商业或者非法用途**。否则，一切后果由您自行负责。
>
> **使用本仓库内容视为同意遵守上述条款**

> [!IMPORTANT]
> 本仓库提供的脚本均为我自己编写或基于开源项目修改。部分脚本引用了其他开源项目，均已保留原作者署名信息。
>
> 转载时请保留原作者署名信息，且遵守本仓库的许可协议。

------

## 🚀 快速安装

### 环境配置脚本

| 脚本名称       | 功能描述               | 安装命令                                                     |       |
| :------------- | :--------------------- | :----------------------------------------------------------- | ----- |
| 科学上网初始化 | 环境配置与工具安装     | `curl -sSL https://raw.githubusercontent.com/Xioaruan912/Xcript/main/sh/fq.sh | bash` |
| Docker 环境    | Docker 及 Compose 安装 | `curl -sSL https://raw.githubusercontent.com/Xioaruan912/Xcript/main/sh/docker.sh | bash` |
| MiniConda      | Python 环境管理        | `curl -sSL https://raw.githubusercontent.com/Xioaruan912/Xcript/main/sh/miniconda.sh | bash` |
| 证书管理       | CertBot SSL 证书       | `curl -sSL https://raw.githubusercontent.com/Xioaruan912/Xcript/main/sh/certbot.sh | bash` |

### 应用部署脚本

| 脚本名称    | 功能描述       | 安装命令                                                     |       |
| :---------- | :------------- | :----------------------------------------------------------- | ----- |
| Jellyfin    | 媒体服务器部署 | `curl -sSL https://raw.githubusercontent.com/Xioaruan912/Xcript/main/sh/Jellyfin.sh | bash` |
| Vaultwarden | 密码管理器部署 | `curl -sSL https://raw.githubusercontent.com/Xioaruan912/Xcript/main/sh/vaultwarden.sh | bash` |
| rclone      | 云存储同步工具 | `curl -sSL https://raw.githubusercontent.com/Xioaruan912/Xcript/main/sh/rclone.sh | bash` |
| Realm       | 代理隧道工具   | `curl -sSL https://raw.githubusercontent.com/Xioaruan912/Xcript/main/sh/realm.sh | bash` |

### 系统工具脚本

| 脚本名称      | 功能描述       | 安装命令                                                     |       |
| :------------ | :------------- | :----------------------------------------------------------- | ----- |
| 一键备份      | 多组件数据备份 | `curl -sSL https://raw.githubusercontent.com/Xioaruan912/Xcript/main/sh/backup.sh | bash` |
| 时区设置      | 设置上海时区   | `curl -sSL https://raw.githubusercontent.com/Xioaruan912/Xcript/main/sh/timeset_Shanghai.sh | bash` |
| Let's Encrypt | 免费 SSL 证书  | `curl -sSL https://raw.githubusercontent.com/Xioaruan912/Xcript/main/sh/let_encrypt.sh | bash` |
| Docker 重建   | 容器环境重建   | `curl -sSL https://raw.githubusercontent.com/Xioaruan912/Xcript/main/sh/docker_rebuild.sh | bash` |

------

## 🔧 国内镜像加速

> [!TIP]
> 如果 GitHub 访问缓慢，可以使用以下国内镜像加速下载：

bash

```
# Docker 安装（国内镜像）
curl -sSL https://ghfast.top/https://raw.githubusercontent.com/Xioaruan912/Xcript/main/sh/CN/docker.sh | bash

# Clash 安装（国内镜像）
curl -sSL https://ghfast.top/https://raw.githubusercontent.com/Xioaruan912/Xcript/main/sh/CN/clash.sh | bash
```



------

## 🛠 第三方工具推荐

### 服务器质量检测

bash

```
# NodeQuality 服务器检测
bash <(curl -sL https://run.NodeQuality.com)

# NodeScriptKit 脚本集合
bash <(curl -sL https://sh.nodeseek.com)

# Clash for Linux 安装
git clone --depth 1 https://gh-proxy.com/https://github.com/nelvko/clash-for-linux-install.git
cd clash-for-linux-install && sudo bash install.sh
```



### 系统重装脚本

bash

```
# 快速重装 Debian 12
bash <(wget -qO- 'https://www.moeelf.com/attachment/LinuxShell/InstallNET.sh') -d 12 -v 64 -a

# 阿里云优化版 Debian 13
curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh
bash reinstall.sh debian 13
```



------

## 📊 VPS 使用记录

### 当前在用服务器

| 服务商 | 地区         | 配置     | 续费价格  | 状态       |
| :----- | :----------- | :------- | :-------- | :--------- |
| Claw   | 日本优化线路 | 常规配置 | 59元/季度 | ✅ 主力使用 |
| 亚洲云 | 香港CN2      | 常规配置 | 99元/年   | ✅ 稳定运行 |
| GGY    | 广港专线NAT  | 常规配置 | 99元/年   | ✅ 稳定运行 |
| YXVM   | 香港         | 常规配置 | 21元/月   | ✅ 稳定运行 |


## 🎯 未来计划

- 添加 PushDeer 通知模块
- 支持更多云服务自动备份
- 开发自建 CDN 工具集
- 增强错误处理和日志记录

------

## 🙏 致谢

感谢以下社区和项目的支持：

- [NodeSeek 社区](https://www.nodeseek.com/)
- [digvps VPS 测评](https://digvps.com/)
- 所有开源项目的贡献者

------

**Note**: 本项目持续更新，欢迎 Star ⭐ 和 Fork！

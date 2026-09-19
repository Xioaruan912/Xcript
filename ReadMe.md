# Xcript

平时自用的一些 VPS / Windows 脚本，复制就能跑。

交互式脚本请用 `bash <(curl -sSL <URL>)` 运行。别用管道（`curl ... | bash`），不然脚本里的 `read` 读不到你的输入。

## 目录结构

```
linux/
  basic/    基础（清理、时区、Miniconda）
  docker/   Docker 与 Compose
  cert/     证书
  app/      应用（Vaultwarden、Jellyfin）
  network/  网络（realm、mihomo）
  backup/   备份（rclone、自动备份）
windows/
  codex-switcher/   Codex 配置切换器
```

## Linux（Debian / Ubuntu）

需要 root 的脚本会自己 `sudo`。

**基础**

| 用途 | 命令 |
| --- | --- |
| 清理缓存、日志、旧内核 | `bash <(curl -sSL https://raw.githubusercontent.com/Xioaruan912/Xcript/main/linux/basic/clean.sh)` |
| 时区设为 Asia/Shanghai | `bash <(curl -sSL https://raw.githubusercontent.com/Xioaruan912/Xcript/main/linux/basic/timeset_Shanghai.sh)` |
| 安装 Miniconda（默认 /opt/miniconda） | `bash <(curl -sSL https://raw.githubusercontent.com/Xioaruan912/Xcript/main/linux/basic/miniconda.sh)` |

**Docker**

| 用途 | 命令 |
| --- | --- |
| 安装 / 更新 Docker + Compose（自动换源） | `bash <(curl -sSL https://raw.githubusercontent.com/Xioaruan912/Xcript/main/linux/docker/docker.sh)` |
| 国内镜像版 Docker + Compose | `bash <(curl -sSL https://raw.githubusercontent.com/Xioaruan912/Xcript/main/linux/docker/docker-cn.sh)` |
| 强制重建当前目录的 compose 项目 | `bash <(curl -sSL https://raw.githubusercontent.com/Xioaruan912/Xcript/main/linux/docker/docker_rebuild.sh)` |

**证书**

| 用途 | 命令 |
| --- | --- |
| Let's Encrypt 证书（Nginx，自动装 certbot） | `bash <(curl -sSL https://raw.githubusercontent.com/Xioaruan912/Xcript/main/linux/cert/certbot.sh)` |
| Let's Encrypt 证书 + 续期自检（snap 版） | `bash <(curl -sSL https://raw.githubusercontent.com/Xioaruan912/Xcript/main/linux/cert/let_encrypt.sh)` |

**应用**

| 用途 | 命令 |
| --- | --- |
| Vaultwarden 密码管理器（含 Docker） | `bash <(curl -sSL https://raw.githubusercontent.com/Xioaruan912/Xcript/main/linux/app/vaultwarden.sh)` |
| Jellyfin 媒体服务器（含 Docker） | `bash <(curl -sSL https://raw.githubusercontent.com/Xioaruan912/Xcript/main/linux/app/jellyfin.sh)` |

**网络**

| 用途 | 命令 |
| --- | --- |
| realm 端口转发 + 开启 BBR | `bash <(curl -sSL https://raw.githubusercontent.com/Xioaruan912/Xcript/main/linux/network/realm.sh)` |
| Clash.Meta / mihomo 内核 + Geo 数据 | `bash <(curl -sSL https://raw.githubusercontent.com/Xioaruan912/Xcript/main/linux/network/clash.sh)` |

**备份**

| 用途 | 命令 |
| --- | --- |
| rclone 安装 + OneDrive 等云盘挂载 | `bash <(curl -sSL https://raw.githubusercontent.com/Xioaruan912/Xcript/main/linux/backup/rclone.sh)` |
| 通用自动备份（打包 + 上传） | `bash <(curl -sSL https://raw.githubusercontent.com/Xioaruan912/Xcript/main/linux/backup/backup.sh)` |

## Windows 10 / 11

**Codex 配置切换**：在官方 OpenAI、OpenCode Go、DeepSeek 官方和自定义中转站之间切换 Codex 配置。

PowerShell：

```powershell
iwr -UseBasicParsing https://raw.githubusercontent.com/Xioaruan912/Xcript/main/windows/codex-switcher/codex.bat -OutFile "$env:TEMP\codex.bat"; & "$env:TEMP\codex.bat"
```

CMD：

```bat
curl -L -o "%TEMP%\codex.bat" https://raw.githubusercontent.com/Xioaruan912/Xcript/main/windows/codex-switcher/codex.bat && "%TEMP%\codex.bat"
```

进菜单后用数字键选提供商，`A` 添加中转站，`B` 管理备份，`S` 看状态，`O` 打开配置目录。填了 API Key 会自动列出该 Key 能用的模型。也支持 `-Switch`、`-Status`、`-Restore` 等参数，详见 [windows/codex-switcher/README.md](windows/codex-switcher/README.md)。启动器会缓存核心脚本 24 小时，GitHub 直连失败时自动走 ghfast 镜像。

**按进程代理启动器**：让 ChatGPT Desktop 等 MSIX / Electron 应用单独走本地混合代理，不动系统代理、不开 TUN。

```powershell
iwr -UseBasicParsing https://raw.githubusercontent.com/Xioaruan912/Xcript/main/windows/app-proxy/tools/chatgpt-proxy.ps1 -OutFile "$env:TEMP\chatgpt-proxy.ps1"; & "$env:TEMP\chatgpt-proxy.ps1" -Verify
```

详见 [windows/app-proxy/README.md](windows/app-proxy/README.md)。

## 国内加速

原始地址前面加 `https://ghfast.top/`：

```bash
bash <(curl -sSL https://ghfast.top/https://raw.githubusercontent.com/Xioaruan912/Xcript/main/linux/docker/docker-cn.sh)
```

## 第三方工具

以下不是本仓库维护的。

NodeQuality 服务器检测：

```bash
bash <(curl -sL https://run.NodeQuality.com)
```

TcpQuality 检测：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/ibsgss/TcpQuality/main/runTcpQuality.sh)
```

重装 Debian 13：

```bash
curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh && bash reinstall.sh debian 13
```

TCP 优化（全 1 回车）：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Kylin010/tcpfit/main/tcpfit.sh)
```

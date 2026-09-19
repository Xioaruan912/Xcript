# 按进程代理启动器（MSIX / Electron）

让指定的 MSIX / Electron 应用（默认 ChatGPT Desktop）**单独**走本地混合代理，不修改系统代理、不开启 TUN、不装内核驱动，也不影响其他程序。

原理：用 `IApplicationActivationManager` 以 AUMID 激活 MSIX 应用，同时把 Chromium 的 `--proxy-server` / `--proxy-bypass-list` 参数传进去。应用仍以原本的包身份运行（许可 / 通知 / 更新不受影响），但流量走本地代理。走代理后域名由代理远端解析，顺带解决 DNS 污染。

## 文件

- `ChatGPT-Proxy.bat`：单文件便携版，PowerShell 逻辑内嵌在 `#__PS_PAYLOAD__#` 标记之后。复制到哪都能用，无需外部依赖、无需管理员权限。

## 用法

双击即可启动，或带参数运行：

```bat
ChatGPT-Proxy.bat
ChatGPT-Proxy.bat direct
ChatGPT-Proxy.bat port=7897
ChatGPT-Proxy.bat aumid=OpenAI.Codex_2p2nqsd0c76g0!App
ChatGPT-Proxy.bat make-shortcut
ChatGPT-Proxy.bat help
```

| 参数 | 说明 |
| --- | --- |
| 无参数 | 结束旧实例，以代理方式重新启动 |
| `direct` | 直连 exe（放弃 MSIX 包身份），AUMID 激活失败时的回退 |
| `env` | 为非 Chromium 子进程写入用户级 `HTTP_PROXY/HTTPS_PROXY/NO_PROXY` |
| `port=NNNN` | 指定代理端口，默认自动读 Clash Verge 配置 |
| `aumid=...` | 指定 AUMID，默认按 `PackageFamilyName` 解析 |
| `make-shortcut` | 在桌面创建带应用图标的快捷方式（隐藏窗口启动） |
| `help` | 显示帮助 |

生成快捷方式后，**以后只从该快捷方式启动**，并建议关闭应用自身的「开机自启 / 托盘常驻」，否则直接点应用图标启动的实例不会走代理。

## 自定义

编辑文件顶部的四行：

```bat
set "APP_PKG_MATCH=OpenAI|ChatGPT"
set "APP_PROC="
set "PROXY_PORT="
set "PROXY_BYPASS=localhost;127.0.0.1"
```

| 变量 | 说明 |
| --- | --- |
| `APP_PKG_MATCH` | 匹配 `Get-AppxPackage` 的 Name 的正则 |
| `APP_PROC` | 启动前要结束的进程名，留空则从 `AppxManifest.xml` 的 `Executable` 自动推导 |
| `PROXY_PORT` | 代理端口，留空则自动读取 |
| `PROXY_BYPASS` | `--proxy-bypass-list` 的值 |

## 自动探测

| 项目 | 来源 | 默认 |
| --- | --- | --- |
| 代理端口 | `verge.yaml: verge_mixed_port` -> `clash-verge.yaml/clash-verge.yaml: mixed-port` | 7897 |
| 安装目录 | 由 `PackageFamilyName` 反查 `InstallLocation` | 自动，不写死版本号 |
| 进程名 | `AppxManifest.xml` 的 `Executable="..."` | ChatGPT |
| AUMID | `Get-StartApps` 按 `<PackageFamilyName>!*` 匹配 | 自动 |

ChatGPT Desktop 当前实测：AUMID `OpenAI.Codex_2p2nqsd0c76g0!App`，Chromium 框架，Full Trust（`runFullTrust` + `Windows.FullTrustApplication`，非 AppContainer，无需 loopback 豁免）。

## 验证

启动后会自动轮询检测（最多 25 秒，每 500ms 一次），要求出现到 `127.0.0.1:<端口>` 的 `Established` 连接：

- 成功：`SUCCESS / 成功 : PID <pid> -> 127.0.0.1:<port> established`
- 失败：提示该主进程可能丢弃了未知 argv，并给出回退方式

也可手动检查：

```powershell
Get-NetTCPConnection -OwningProcess <PID> |
  Where-Object State -eq Established |
  Select-Object RemoteAddress, RemotePort
```

代理侧是否命中，看 Clash Verge 的日志 / 连接页里目标域名走的分流节点。

## 回退

按顺序：

1. **直连 exe**：`ChatGPT-Proxy.bat direct`（牺牲包身份，可能影响通知 / 更新）。
2. **按进程代理工具**：Proxifier / Netch / Proxinject，规则 `<进程名> -> HTTPS 127.0.0.1:<端口>`。
3. **最后**才考虑 TUN / 系统代理（需用户同意）。

## 说明

- 不写入系统代理（`HKCU\...\Internet Settings`），不启用 TUN，不装驱动。
- `env` 参数写入的是**用户级**环境变量，对所有程序生效；只在明确需要时使用。
- 文件为 UTF-8 无 BOM，`chcp 65001` 保证中文输出不乱码。
- 若应用坚持忽略 `--proxy-server`，用回退方案。

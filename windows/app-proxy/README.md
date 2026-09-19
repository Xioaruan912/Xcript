# 按进程代理启动器（MSIX / Electron）

让指定的 MSIX / Electron 应用（默认 ChatGPT Desktop）**单独**走本地混合代理，不修改系统代理、不开启 TUN、不装内核驱动，也不影响其他程序。

原理：用 `IApplicationActivationManager` 以 AUMID 激活 MSIX 应用，同时把 Chromium 的 `--proxy-server` / `--proxy-bypass-list` 参数传进去。这样应用仍以原本的包身份运行（许可 / 通知 / 更新不受影响），但流量会走本地代理。走代理后域名由代理远端解析，顺带解决 DNS 污染。

## 文件

- `tools/chatgpt-proxy.ps1`：启动器，含自动探测、启动、验证、生成快捷方式。

## 用法

```powershell
# 结束旧实例并重新以代理方式启动 ChatGPT
.\tools\chatgpt-proxy.ps1

# 启动并检测是否命中本地代理
.\tools\chatgpt-proxy.ps1 -Verify

# 只探测配置，不做任何改动
.\tools\chatgpt-proxy.ps1 -DryRun

# 在桌面生成「ChatGPT (代理)」快捷方式
.\tools\chatgpt-proxy.ps1 -CreateShortcut
```

生成快捷方式后，**以后只从该快捷方式启动**，并建议关闭应用自身的「开机自启 / 托盘常驻」，否则直接点应用图标启动的实例不会走代理。

## 自动探测

| 项目 | 来源 | 默认 |
| --- | --- | --- |
| AUMID | `Get-StartApps` 按名称匹配 | `ChatGPT` |
| 代理端口 | `verge.yaml: verge_mixed_port` -> `clash-verge.yaml/config.yaml: mixed-port` | 7897 |
| 安装目录 | 由 `PackageFamilyName` 反查 `InstallLocation` | 自动，不写死版本号 |
| 沙箱 | 读 `AppxManifest.xml`：`runFullTrust` + `Windows.FullTrustApplication` 表示非 AppContainer | 无需 loopback 豁免 |

ChatGPT Desktop 当前实测：AUMID `OpenAI.Codex_2p2nqsd0c76g0!App`，Chromium 框架，Full Trust。

## 参数

| 参数 | 说明 |
| --- | --- |
| `-AppNameMatch` | `Get-StartApps` 名称匹配，默认 `ChatGPT` |
| `-Aumid` | 手动指定 AUMID，跳过自动探测 |
| `-ProcessNames` | 启动前结束的进程名，默认 `ChatGPT` |
| `-Port` | 代理端口，默认自动探测 |
| `-BypassList` | `--proxy-bypass-list`，默认 `localhost;127.0.0.1` |
| `-AppExeName` | 主可执行文件名，默认 `ChatGPT.exe` |
| `-DirectExe` | 回退：直接运行 exe 并带参数 |
| `-SetChildProxyEnv` | 在当前进程设置 `HTTP_PROXY/HTTPS_PROXY/NO_PROXY`（进程作用域） |
| `-NoKill` | 不结束已有进程 |
| `-Verify` | 启动后检测代理连接 |
| `-CreateShortcut` | 生成桌面快捷方式后退出 |
| `-DryRun` | 只探测，不改动 |

## 验证

`-Verify` 会：

1. 取主进程 PID；无连接时再遍历所有同名进程。
2. 检查是否存在到 `127.0.0.1:<Port>` 的 `Established` 连接。
3. 若只见发往公网地址的 `SynSent`，提示可能是 Electron 丢弃了未知 argv 或 DNS 污染。

也可手动：

```powershell
Get-NetTCPConnection -OwningProcess <PID> |
  Where-Object State -eq Established |
  Select-Object RemoteAddress, RemotePort
```

代理侧是否命中，看 Clash Verge 的日志 / 连接页里目标域名走的分流节点。

## 回退

按顺序：

1. **直连 exe + 参数**：`.\tools\chatgpt-proxy.ps1 -DirectExe`（牺牲包身份，可能影响通知 / 更新）。
2. **按进程代理工具**：Proxifier / Netch / Proxinject，规则 `<进程名> -> HTTPS 127.0.0.1:<端口>`。
3. **最后**才考虑 TUN / 系统代理（需用户同意）。

## 改成其他应用

```powershell
.\tools\chatgpt-proxy.ps1 -AppNameMatch 'SomeApp' -ProcessNames 'SomeApp' -AppExeName 'SomeApp.exe' -Port 7897
```

或直接给 `-Aumid`。判断是否 Electron/Chromium：安装目录里有没有 `chrome.dll` / `resources.pak`。

## 说明

- 不写入系统代理（`HKCU\...\Internet Settings`），不启用 TUN，不装驱动。
- `-SetChildProxyEnv` 是**进程作用域**的，只被本次启动的进程树继承；MSIX 激活方式不保证继承，对独立网络栈子进程（如 Rust/Node CLI）主要配合 `-DirectExe` 使用。
- 若应用坚持忽略 `--proxy-server`，用回退方案。

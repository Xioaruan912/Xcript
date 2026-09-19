# Codex 配置切换器

Windows 下切换 Codex 的配置，支持官方 OpenAI、OpenCode Go、DeepSeek 官方和自定义中转站。

> [!IMPORTANT]
> 旧路径 `win/Codex_switcher/` 已废弃，旧链接会 404。请使用本目录（`windows/codex-switcher/`）的最新地址，旧地址下不提供转发。

Codex CLI、ChatGPT 桌面端、VS Code 扩展共用 `%USERPROFILE%\.codex\config.toml`。切换时只替换里面的 `model`、`model_provider` 和 `[model_providers.*]`，其余设置（`[plugins]`、`[mcp_servers]`、`[projects]`、`[desktop]` 等）原样保留，并在切换后按需重启 ChatGPT 桌面端。

## 文件

- `codex.bat`：启动器。从 GitHub 下载核心脚本并本地缓存 24 小时；下载后会校验内容（必须是核心脚本而不是 404 页面），失败时用旧缓存，直连失败时自动走 ghfast 镜像。下载前会探测本地代理，有就优先走代理。最后运行核心脚本。
- `codex-switcher.ps1`：核心脚本，菜单、切换、备份、模型探测等逻辑都在这里。核心脚本的自动更新同样优先走本地代理。
- `version.txt`：版本号（`bat=` 启动器版本，`ps1=` 核心脚本版本），供启动器和脚本做轻量更新探测。

## 代理

下载与自动更新会先探测本地代理（**只读，不写入任何配置文件**）：

1. 环境变量 `PROXY_PORT`。
2. Clash Verge 配置：`verge.yaml: verge_mixed_port` -> `clash-verge.yaml: mixed-port`。
3. 扫描本机常见端口：7897 / 7890 / 10809 / 10808 / 1080 / 2080 / 8889 / 8080。

探测到就用它访问 GitHub（验证方式是对 GitHub 实际发一次请求），并打印来源；探测不到会询问一次端口（仅在有下载需求时），回车则直接下载。

下载顺序：**本地代理 -> GitHub 直连 -> ghfast 镜像 -> 旧缓存**。

`codex.bat -noproxy` 或 `codex-switcher.ps1 -NoProxy` 可跳过探测，直接直连 / 镜像。

## 更新机制

更新分两级，启动时**不会**因为联网而卡住：

- 启动器 `codex.bat`：缓存命中时做一次**极快**版本比对（只取 `version.txt`，6 秒超时，优先走本地代理，失败静默跳过）。发现缓存的核心脚本落后就自动刷新；否则直接用本地缓存。
- 核心脚本 `codex-switcher.ps1`：**交互启动时只读本地版本缓存，绝不联网**，保证秒开。有新版时只提示，例如「有可用更新（脚本 1.5.2），运行 codex-switcher.ps1 -Update 更新」，不会自动下载。

也就是说：正常双击启动 = 秒开；要更新时显式运行 `-Update`（或 `codex.bat -force` 强制重下核心脚本）。

| 命令 | 行为 |
| --- | --- |
| `codex.bat` | 缓存可用即秒开；仅在缓存脚本落后时自动刷新 |
| `codex.bat -force` | 忽略缓存，重新下载核心脚本 |
| `codex-switcher.ps1 -Update` | 强制探测并下载核心脚本 / 启动器 |
| `codex-switcher.ps1 -Doctor` | 查看本地 / 远端版本与更新状态 |

编码约定：

- 核心脚本是 UTF-8 带 BOM。PowerShell 5.1 只有见到 BOM 才会按 UTF-8 解析，否则中文乱码。
- 启动器是纯 ASCII。cmd.exe 在 `chcp 65001` 下解析含多字节字符的批处理会错位跳行，所以启动器不写中文，中文都由 PowerShell 输出。
- 生成的 `config.toml`、`models.json` 用 UTF-8 无 BOM，这是 Codex 的要求。

## 运行

PowerShell：

```powershell
iwr -UseBasicParsing https://raw.githubusercontent.com/Xioaruan912/Xcript/main/windows/codex-switcher/codex.bat -OutFile "$env:TEMP\codex.bat"; & "$env:TEMP\codex.bat"
```

CMD：

```bat
curl -L -o "%TEMP%\codex.bat" https://raw.githubusercontent.com/Xioaruan912/Xcript/main/windows/codex-switcher/codex.bat && "%TEMP%\codex.bat"
```

GitHub 访问困难时，任意原始地址前加 `https://ghfast.top/`。

## 内置提供商

| id | 名称 | 接口 | 默认模型 |
| --- | --- | --- | --- |
| `openai` | 官方 OpenAI | Codex 内置 provider | 取决于 ChatGPT 登录或 `OPENAI_API_KEY` |
| `go` | OpenCode Go | `https://opencode.ai/zen/go/v1` | `deepseek-v4-flash` |
| `deepseek` | DeepSeek 官方 | `https://api.deepseek.com` | `deepseek-flash` |

切到 DeepSeek 时会写入 DeepSeek 官方的 `models.json`（声明上下文窗口、推理等级、图像输入这些元数据）。切到其他提供商时，如果 `models.json` 是本工具放的，会自动还原或删掉，不动你自己的文件。

## 菜单

按数字键切换提供商。没配置过的会先进配置向导。

```
 [1] 官方 OpenAI
 [2] OpenCode Go
 [3] DeepSeek 官方
 ...  自定义提供商会继续编号
 [A] 添加自定义提供商
 [E] 编辑 / 更新提供商配置
 [X] 删除自定义提供商
 [B] 备份管理
 [S] 查看状态
 [O] 打开配置目录
 [0] 退出
```

配置时会让你填 API Key，填完自动请求该提供商列出这个 Key 能用的模型，直接选序号就行。想重新探测输 `?`，也可以手动输模型名。

## 自定义提供商（中转站 / 自建代理）

菜单 `[A]` 添加，依次填 id、显示名称、API Base URL、API Key、模型。

id 用英文，只能是字母、数字、`_`、`-`，会生成 `config.<id>.toml`。模型会自动调 `{base_url}/models` 探测，探测不到可以手输。

写出来的模板大概是这样：

```toml
model = "gpt-5.5"
model_provider = "myrelay"

[model_providers.myrelay]
name = "我的中转站"
base_url = "https://your-relay.com/v1"
wire_api = "responses"
experimental_bearer_token = "sk-xxxx"
```

提供商信息存在 `%USERPROFILE%\.codex\codex-switcher.providers.json`。

模型探测会带上你的 Key 请求 `{base_url}/models`（也会试去掉 `/v1` 前缀的地址），能认出下面这些返回格式：

- `{"data":[{"id":"..."}]}`
- `{"models":[{"slug":"..."}]}` 或 `{"models":[{"name":"..."}]}`
- `{"result":[...]}`、`{"list":[...]}`、`{"items":[...]}`
- 顶层 `{"model-a":{...},"model-b":{...}}`
- `["a","b"]`

注意 Codex 从 2026 年起只支持 `wire_api = "responses"`，`chat` 已经移除。中转站必须兼容 OpenAI Responses API 才能用。

## 非交互参数

方便做快捷方式或脚本调用。

| 参数 | 说明 |
| --- | --- |
| `-Switch <id / 名称 / 序号>` | 直接切换后退出，如 `-Switch deepseek` |
| `-Status` | 打印当前状态 |
| `-List` | 列出全部备份 |
| `-Restore <latest / 序号 / 文件名>` | 从备份恢复活动配置 |
| `-Prune [-Keep N]` | 清理旧备份，默认保留最近 10 份 |
| `-NoRestart` | 切换后不重启 ChatGPT 桌面端 |
| `-DryRun` | 只显示要做什么，不改文件 |
| `-ApiKey` / `-Model` | 非交互配置时提供的 Key 和模型 |
| `-AddProvider -Id -Name -BaseUrl` | 非交互添加自定义提供商（配合 `-ApiKey` / `-Model`） |
| `-Update` | 强制做一次版本探测，有更新就刷新 |
| `-Doctor` | 环境自检（版本、目录、写权限、远端版本） |
| `-NoCheck` | 跳过启动时的版本探测 |
| `-NoProxy` | 跳过本地代理探测，更新 / 下载直接直连或走镜像 |

```powershell
.\codex-switcher.ps1 -Switch go -ApiKey sk-xxxx -Model deepseek-v4-flash -NoRestart
.\codex-switcher.ps1 -Status
.\codex-switcher.ps1 -Restore latest
.\codex-switcher.ps1 -AddProvider -Id myrelay -Name "我的中转站" -BaseUrl https://relay.example.com/v1 -ApiKey sk-xxxx -Model gpt-5.5
.\codex-switcher.ps1 -Doctor
```

也可以不传 `-ApiKey`，改成设环境变量：`OPENCODE_GO_API_KEY`、`DEEPSEEK_API_KEY`、`OPENAI_API_KEY`。

## 备份与安全

每次覆盖 `config.toml` 前都会生成带时间戳的备份 `config.toml.bak.yyyyMMddHHmmssfff`。默认只保留最近 10 份，避免备份堆积，可以用 `-Keep` 或菜单 `[B]` 改。

备份按**文件名里的时间戳**排序，只识别本工具生成的 `config*.toml.bak.<时间戳>`。`~/.codex` 下其它 `.bak` 文件（例如 `.codex-global-state.json.bak`）不会被列出、不会被清理，更不会被当成备份恢复回 `config.toml`。

写完会尽量收紧权限：用 SID 授权（当前用户、SYSTEM、Administrators），避免非英文系统上组名解析失败。切换并重启桌面端后会复查 `config.toml`，若检测到被桌面端改写会提示并可一键重新应用。

API Key 是明文存在模板文件里的（内联 `experimental_bearer_token`），别把 `config.*.toml` 和 `*.bak.*` 发给别人。

## 排查

| 现象 | 处理 |
| --- | --- |
| 中文乱码 | 确认 `codex-switcher.ps1` 是 UTF-8 带 BOM，`codex.bat` 保持纯 ASCII |
| `Invoke-WebRequest : 404` / 下载失败 | 多半是在用旧路径的旧启动器（`win/Codex_switcher/`），按 README 顶部重新获取新地址的 `codex.bat` |
| 下载失败 | 会先试本地代理，再直连，再试 ghfast 镜像；也可 `codex.bat -force` 手动刷新，或用 `-noproxy` 跳过代理探测 |
| `wire_api` 报错 | 提供商要支持 Responses API，`chat` 已不支持 |
| 切换后没生效 | 正在跑的 CLI / IDE 会话要重启才会读新配置；若桌面端改回了 `config.toml`，按提示重新应用 |
| 切换后设置被清空 | 1.5.0+ 只替换 provider 字段，会保留其它设置；旧版本请更新 |
| 恢复后 Codex 报 TOML 错 | 旧版本可能把无关 `.bak` 当备份恢复；1.5.0+ 只认 `config.toml` 的备份，请在菜单 `[B]` 里选正确的备份 |
| 想回退 | 菜单 `[B]` 或 `-Restore latest` |

## 调试

```powershell
# 语法检查
$e=$null;[System.Management.Automation.Language.Parser]::ParseFile('.\codex-switcher.ps1',[ref]$null,[ref]$e);$e

# 用隔离目录调试，不动真实的 ~/.codex
$env:CODEX_HOME="$env:TEMP\codex-debug"
.\codex-switcher.ps1 -Status
```

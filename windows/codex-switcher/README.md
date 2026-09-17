# Codex 配置切换器

Windows 下切换 Codex 的配置，支持官方 OpenAI、OpenCode Go、DeepSeek 官方和自定义中转站。

Codex CLI、ChatGPT 桌面端、VS Code 扩展共用 `%USERPROFILE%\.codex\config.toml`。这个工具就是替换这个文件，并在切换后按需重启 ChatGPT 桌面端。

## 文件

- `codex.bat`：启动器。从 GitHub 下载核心脚本并本地缓存 24 小时；下载失败时用旧缓存，直连失败时自动走 ghfast 镜像。最后运行核心脚本。
- `codex-switcher.ps1`：核心脚本，菜单、切换、备份、模型探测等逻辑都在这里。

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

```powershell
.\codex-switcher.ps1 -Switch go -ApiKey sk-xxxx -Model deepseek-v4-flash -NoRestart
.\codex-switcher.ps1 -Status
.\codex-switcher.ps1 -Restore latest
```

也可以不传 `-ApiKey`，改成设环境变量：`OPENCODE_GO_API_KEY`、`DEEPSEEK_API_KEY`、`OPENAI_API_KEY`。

## 备份与安全

每次覆盖 `config.toml` 前都会生成带时间戳的备份 `config.toml.bak.yyyyMMddHHmmssfff`。默认只保留最近 10 份，避免备份堆积，可以用 `-Keep` 或菜单 `[B]` 改。写完会尽量收紧权限，移除继承、只留当前用户和 SYSTEM。

API Key 是明文存在模板文件里的（内联 `experimental_bearer_token`），别把 `config.*.toml` 和 `*.bak.*` 发给别人。

## 排查

| 现象 | 处理 |
| --- | --- |
| 中文乱码 | 确认 `codex-switcher.ps1` 是 UTF-8 带 BOM，`codex.bat` 保持纯 ASCII |
| 下载失败 | 直连失败会自动试 ghfast 镜像，也可以 `codex.bat -force` 手动刷新 |
| `wire_api` 报错 | 提供商要支持 Responses API，`chat` 已不支持 |
| 切换后没生效 | 正在跑的 CLI / IDE 会话要重启才会读新配置 |
| 想回退 | 菜单 `[B]` 或 `-Restore latest` |

## 调试

```powershell
# 语法检查
$e=$null;[System.Management.Automation.Language.Parser]::ParseFile('.\codex-switcher.ps1',[ref]$null,[ref]$e);$e

# 用隔离目录调试，不动真实的 ~/.codex
$env:CODEX_HOME="$env:TEMP\codex-debug"
.\codex-switcher.ps1 -Status
```

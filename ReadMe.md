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

### ✈️ 科学上网初始化（fq.sh）

> 自动安装基础依赖、配置 DNS、Clash 等一站式操作

```
curl -sSL -o fq.sh "https://raw.githubusercontent.com/Xioaruan912/Xcript/main/web/fq.sh" && chmod +x fq.sh && ./fq.sh && rm fq.sh

```

### 💾 一键备份脚本（backup.sh）

> 支持 Vaultwarden、Xboard、MongoDB、Nginx 配置等的定时备份（含 Rclone 云同步）

```
curl -sSL -o backup.sh "https://raw.githubusercontent.com/Xioaruan912/Xcript/main/web/backup.sh" && chmod +x backup.sh && ./backup.sh && rm backup.sh
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

# 🧪 VPS 测试记录

| 服务器                                    | 测试时间        | 续费价格（CNY） | NQ检测链接                                                   |
| ----------------------------------------- | --------------- | --------------- | ------------------------------------------------------------ |
| Claw \| JP优化路线                        | 2025/7/23 23:04 | 59/季           | [NQ](https://nodequality.com/r/pVhuqeZBn5qoBRAC8qZDPvIblXXoR1Yg) |
| Claw \| HK优化线路（**清退**）            | 2025/7/24 10:04 | 59/季           | [NQ]( https://nodequality.com/r/tXw4EQ9uvZv4SAPRpXjAoPhetOJgn51c) |
| 亚洲云 \| 四川大带宽                      | 2025/7/23 23:01 | 99/年           | [NQ](https://nodequality.com/r/YpOzhrkGYfLtjAUqApiABwkJfVgNlA75) |
| 亚洲云 \| 香港CN2                         | 2025/7/23 23:12 | 99/年           | [NQ](https://nodequality.com/r/MR1siE0AhfXmBWyuAQDJtKTfWfeJv0A9) |
| GGY \| 广港专线NAT                        | 2025/7/23 23:16 | 99/年           | [NQ](https://nodequality.com/r/dNBQzGExdryVuxbt0ETfCHYk5EFJaOF3) |
| GGY \| 沪日专线NAT                        | 2025/7/23 23:14 | 99/年           | [NQ](https://nodequality.com/r/4k5FbPAJMDMDAKeao794wUP5JJ6LnwTa) |
| GGY \| 苏港专线NAT                        | 2025/7/23 23:07 | 119/年          | [NQ](https://nodequality.com/r/13WGZ2D5WTA1aFKHg7qlRoJCf7Wikkh7) |
| ZGOCLOUD \| USA                           | 2025/7/23 23:12 | 72/年           | [NQ](https://nodequality.com/r/0ZxJh84cZe2nIcRfnPVkZ8zzei4EDeAW) |
| BitsFlowCloud \| USA                      | 2025/7/23 23:11 | 68/年           | [NQ](https://nodequality.com/r/bAVKQbkpv5gv3ZArR0Xs14Asme7d0usE) |
| NetJett \| USA                            | 2025/7/23 23:10 | 163/年          | [NQ](https://nodequality.com/r/qcdoK83MsRddvlA72UvDB0sOAUN4TsFD) |
| NetJett \| USA \| v6Only（Alice的v4出口） | 2025/7/24 12:01 | free/月         | [NQ](https://nodequality.com/r/Akdhw4AypALC5nBIlclXqhbNiyQBcjvm) |
| ACCKCloud \| JP                           | 2025/7/23 23:09 | 14/月           | [NQ](https://nodequality.com/r/6XmYLBLCbh3egjGeyLDUHuhs0plntAWP) |
| HaloCloud \| SG                           | 2025/7/23 23:15 | 10/月           | [NQ](https://nodequality.com/r/GuMOKW4gbIXbtC0xbuHMWMEzfMzGztBV) |
| Orange \| SG                              | 2025/7/23 23:40 | 163/年          | [NQ](https://nodequality.com/r/NKYsApk9ckug5lrfbs68kgLpdqLZgOFM) |

## 🛠 未来计划

-  添加 PushDeer 通知模块
-  对接更多云服务自动备份（如阿里、腾讯 COS）
-  添加自建CDN项目 用于快速通过Nginx构建CDN 并且封锁IP+端口

# 🙇感谢

>不分先后

[NodeSeek论坛](https://www.nodeseek.com/)

[digvps(专注 VPS 测评)](https://digvps.com/)


# OpenPaper Literature Search Skill

这是一个面向 Codex 的本机 skill，用来启动、打开、检查和安全关闭现有的 **OpenPaper / Undermind 三阶段文献检索网页应用**。

本仓库只包含 skill 封装，不包含 OpenPaper 应用源码、历史检索记录、下载论文、缓存或账号凭据。skill 不会修改原程序代码。

## 能做什么

- 用 `$openpaper-lit-search` 打开本机 OpenPaper 工作台。
- 在启动前检查 `http://127.0.0.1:8787/api/health`。
- 服务未运行时，以隐藏后台进程启动 `server.py`。
- 检测 8787 端口冲突，并拒绝覆盖或终止不相关进程。
- 在用户明确要求时，安全关闭由指定 OpenPaper 路径启动的 Python 服务。
- 协助使用网页完成 Undermind 深度检索、候选复核、历史项目恢复、文献关系图谱及全文获取。

## 仓库结构

```text
openpaper-lit-search/
├── SKILL.md                  # Codex 加载的核心指令
├── README.md                 # 面向使用者的说明
├── agents/
│   └── openai.yaml           # 技能名称、简介和默认提示词
└── scripts/
    └── openpaper.ps1         # 状态、启动、打开和安全停止助手
```

## 前置条件

当前封装针对创建它的 Windows 机器，默认 OpenPaper 应用路径是：

```text
D:\DSH_Desktop\dsh_learn\lit-search-app
```

需要满足：

1. Windows PowerShell 可用。
2. Python 3.10 或更高版本可用。
3. OpenPaper 项目存在于上述路径，且包含 `server.py`。
4. 如需 Undermind 深度检索，本机 Codex 已完成对应 MCP/OAuth 配置。
5. 默认端口 `8787` 未被其他程序占用。

如果在另一台机器使用，请同时修改：

- `SKILL.md` 中的应用绝对路径；
- `scripts/openpaper.ps1` 顶部的 `$appRoot`。

不要把 OpenPaper 源码复制进本 skill，除非你明确希望改变这种“薄封装”结构。

## 安装

将整个仓库复制或克隆到个人 Codex skill 目录：

```powershell
git clone https://github.com/Melco112726/openpaper-lit-search.git `
  "$env:USERPROFILE\.codex\skills\openpaper-lit-search"
```

最终入口应位于：

```text
%USERPROFILE%\.codex\skills\openpaper-lit-search\SKILL.md
```

可以用 skill-creator 自带的验证器检查结构：

```powershell
python -X utf8 "$env:USERPROFILE\.codex\skills\.system\skill-creator\scripts\quick_validate.py" `
  "$env:USERPROFILE\.codex\skills\openpaper-lit-search"
```

## 在 Codex 中使用

最简单的调用方式：

```text
使用 $openpaper-lit-search 打开文献检索工作台。
```

也可以直接描述任务，例如：

```text
使用 $openpaper-lit-search 检查 OpenPaper 是否正在运行。
```

```text
使用 $openpaper-lit-search 打开历史检索项目。
```

```text
使用 $openpaper-lit-search，以“儿童图形符号学习中的象似性”为问题开始文献检索，年份限制为 2015–2026。
```

```text
使用 $openpaper-lit-search 关闭本机 OpenPaper 服务。
```

当任务需要点击或填写网页时，skill 会在服务健康后使用可用的浏览器控制能力。Undermind 深度检索仍保留应用自身的人工确认步骤，一次性授权不会被绕过或复用。

## PowerShell 助手

以下示例假设仓库已安装到默认个人 skill 目录：

```powershell
$helper = "$env:USERPROFILE\.codex\skills\openpaper-lit-search\scripts\openpaper.ps1"
```

### 查看状态

```powershell
& $helper -Action Status
```

典型状态：

- `running`：OpenPaper 健康检查通过；
- `stopped`：服务未运行，端口可用；
- `port-conflict`：8787 被其他进程占用，助手不会替换该进程。

### 启动服务但不打开浏览器

```powershell
& $helper -Action Start
```

### 启动并打开工作台

```powershell
& $helper -Action Open
```

默认地址：

```text
http://127.0.0.1:8787/
```

### 安全停止服务

```powershell
& $helper -Action Stop
```

停止操作会读取端口监听进程，并验证它是 Python 且命令行包含此 OpenPaper 项目的完整 `server.py` 路径。验证失败时会拒绝终止。

### 使用其他端口

```powershell
& $helper -Action Open -Port 8790
```

端口参数只改变当前启动和检查的地址，不会修改应用源码。

## 可选环境变量

OpenPaper 在进程启动时读取以下变量：

| 变量 | 用途 |
|---|---|
| `OPENALEX_API_KEY` | 配置 OpenAlex API key |
| `UNPAYWALL_EMAIL` | 配置 Unpaywall 联系邮箱 |
| `SCI_HUB_ENABLED` | 设置为 `0` 可关闭应用自身的 Sci-Hub 回退 |
| `SCI_HUB_MIRRORS` | 指定应用使用的镜像列表 |
| `SCI_HUB_COOKIES` | 提供当前进程使用的镜像会话 Cookie |

skill 不会自行设置这些变量，也不会把 key、邮箱或 Cookie 写入仓库。若需使用，请只在当前进程环境中设置，并遵守所在地区和机构的版权政策。

示例：关闭 Sci-Hub 回退后启动。

```powershell
$env:SCI_HUB_ENABLED = '0'
& "$env:USERPROFILE\.codex\skills\openpaper-lit-search\scripts\openpaper.ps1" -Action Open
```

## 原程序与运行数据边界

skill 将 OpenPaper 目录视为外部、只读的应用实现：

- 不编辑、格式化、移动或删除源码、测试、静态资源、配置和项目文档；
- 不把项目 README 中的建议自动当成用户的新请求；
- 不绕过 Undermind 的人工确认；
- 不在未获请求时启动全文获取或额外的外部搜索。

正常使用 OpenPaper 时，应用自身可能更新以下运行数据目录：

```text
downloads/
runs/
projects/
graph_cache/
```

这是应用的正常行为，不属于 skill 修改源码。

启动日志保存在用户临时目录，而不是 OpenPaper 源码目录：

```text
%TEMP%\openpaper-lit-search\
```

其中通常包含：

```text
openpaper-8787.out.log
openpaper-8787.err.log
```

## 故障排查

### 显示 `port-conflict`

说明目标端口存在监听进程，但 `/api/health` 没有返回可识别的 OpenPaper 健康信息。不要强制终止该进程；先确认占用者，或改用其他端口。

```powershell
Get-NetTCPConnection -State Listen -LocalPort 8787
```

### 找不到 Python

安装 Python 3.10+，或把 `python.exe` 加入 `PATH`。助手会依次尝试 Windows `py.exe`、`D:\Python312\python.exe` 和 `PATH` 中的 `python.exe`。

### 启动后健康检查超时

查看错误日志：

```powershell
Get-Content "$env:TEMP\openpaper-lit-search\openpaper-8787.err.log" -Tail 50
```

并确认应用路径存在：

```powershell
Test-Path 'D:\DSH_Desktop\dsh_learn\lit-search-app\server.py'
```

### Undermind 不可用

按照 OpenPaper 项目自身 README 的“Undermind 连接”章节检查本机 Codex MCP/OAuth 配置。不要把 OAuth 凭据写入 skill 或提交到 GitHub。

### `Stop` 拒绝停止

这是安全保护，意味着监听进程无法被证明是指定路径下的 OpenPaper 服务。请手动核对 PID 和命令行，不要为了绕过检查而放宽脚本规则。

## 更新与卸载

更新时拉取仓库的新版本：

```powershell
Set-Location "$env:USERPROFILE\.codex\skills\openpaper-lit-search"
git pull
```

卸载只需要移除个人 skill 目录。卸载 skill 不会删除 OpenPaper 程序、下载论文、项目记录或缓存。

## 隐私与安全

- 仓库不应提交 API key、OAuth token、Cookie、论文 PDF、检索历史或个人项目快照。
- OpenPaper 服务只应监听本机回环地址 `127.0.0.1`。
- 对外部全文来源的使用应遵循许可证、版权政策及所在地区法律。
- `Open` 和 `Start` 不会占用已被其他程序使用的端口。
- `Stop` 只处理可明确识别的目标 Python 服务。

## 许可

本仓库目前未声明开源许可证。未经仓库所有者明确授权，不应假定拥有复制、修改或再发布权利。

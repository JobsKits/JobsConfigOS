# WindowsOS 新系统配置脚本

![Jobs出品，必属精品](https://picsum.photos/1500/400)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [🔥 前言](#%E5%89%8D%E8%A8%80)
- [一、组件清单](#components)
- [二、模式、参数与确认](#parameters)
- [三、安装、修复与反安装边界](#lifecycle)
- [四、来源、日志与运行限制](#logs)
- [五、验证与交付范围](#verification)

</details>
<!-- jobs-toc:end -->

---

## 🔥 <span id="前言">前言</span>

[实施脚本](./【WindowsOS】🆕新系统配置.ps1)使用系统 [**Windows PowerShell 5.1**](https://learn.microsoft.com/powershell/scripting/windows-powershell/overview)；[双击入口](./【WindowsOS】🆕新系统配置.cmd)只负责解释器、路径、参数和真实退出码透传；无参数启动在显示默认计划后等待按键，便于双击阅读，有参数调用不暂停。默认 `Plan` 只输出静态清单，不联网、不调用包管理器、不创建收据、日志或锁。实际写入要求 Windows 10 1809 64 位及 [**WinGet 1.8+**](https://learn.microsoft.com/windows/package-manager/winget/)。

## 一、<span id="components">组件清单</span> <a href="#前言">🔼</a> <a href="#🔚">🔽</a>

以下 20 项以实施脚本 Catalog 的唯一 ID 计数，核对日期为 2026-11-17；包 ID 已在 [Microsoft 官方清单仓库](https://github.com/microsoft/winget-pkgs)核对存在，不等同于每种架构实际安装成功。版本由当前所配置源解析；本入口不锁定制品版本，不伪称已安装最新版本。

| 组件 ID | WinGet 包 ID | 用途 |
| --- | --- | --- |
| `git` | `Git.Git` | Git 与 Git Bash |
| `git-lfs` | `GitHub.GitLFS` | 大文件工具；不自动修改 Git 全局配置 |
| `gh` | `GitHub.cli` | GitHub CLI；不自动登录 |
| `nushell` | `Nushell.Nushell` | 可选终端 Shell；不设为默认 |
| `node` | `OpenJS.NodeJS.LTS` | Node.js 与 npm；补装选择 LTS |
| `python` | `Python.Python.3.13` | Python 3.13；不改已有项目虚拟环境 |
| `java` | `Microsoft.OpenJDK.17` | JDK 17 |
| `go` | `GoLang.Go` | Go 工具链 |
| `cmake` | `Kitware.CMake` | CMake；不隐式准备 MSVC |
| `vscode` | `Microsoft.VisualStudioCode` | Visual Studio Code；不安装扩展 |
| `7zip` | `7zip.7zip` | 7-Zip |
| `curl` | `cURL.cURL` | cURL；健康系统自带命令优先复用 |
| `jq` | `jqlang.jq` | JSON 处理 |
| `fzf` | `junegunn.fzf` | 模糊选择器 |
| `lazygit` | `JesseDuffield.lazygit` | Git 终端界面 |
| `uv` | `astral-sh.uv` | Python 环境工具 |
| `yt-dlp` | `yt-dlp.yt-dlp` | 下载工具；不预下载内容 |
| `ffmpeg` | `Gyan.FFmpeg` | 媒体工具 |
| `task` | `Task.Task` | Task 任务运行器 |
| `hugo` | `Hugo.Hugo.Extended` | 静态站点工具 |

## 二、<span id="parameters">模式、参数与确认</span> <a href="#前言">🔼</a> <a href="#🔚">🔽</a>

| 参数 | 默认与行为 |
| --- | --- |
| `-Mode` | `Plan`；支持 `Help`、`List`、`Plan`、`Install`、`Uninstall` |
| `-Components` | 只读省略时列全部；写模式必须显式选择，支持数组或逗号分隔 ID |
| `-Operation` | `Install`；仅决定 `Plan` 预览安装或卸载 |
| `-Confirm` | 默认关闭；自动化必须显式传入才允许无人值守写入 |
| `-StateRoot` | 默认当前用户本地应用数据中的 `JobsSystemBootstrap/WindowsOS`；可以显式指定其它收据与日志目录 |

```powershell
& './【WindowsOS】🆕新系统配置.ps1' -Mode Help
& './【WindowsOS】🆕新系统配置.ps1' -Mode Plan -Components git,node
& './【WindowsOS】🆕新系统配置.ps1' -Mode Install -Components git,node
# 已明确接受所选包许可与影响的自动化调用。
& './【WindowsOS】🆕新系统配置.ps1' -Mode Install -Components git,node -Confirm
& './【WindowsOS】🆕新系统配置.ps1' -Mode Uninstall -Components git
```

交互确认默认取消，使用方向键或 Tab 切换至执行后回车；Esc 或默认回车取消。非交互写入未传 `-Confirm` 时失败，不把输入结束当成授权。空组件、未知 ID、错误参数均不写入。只读计划不承诺反映实际安装状态，实际执行时才复检。

## 三、<span id="lifecycle">安装、修复与反安装边界</span> <a href="#前言">🔼</a> <a href="#🔚">🔽</a>

- 确认后先核对系统和包管理器，锁住本工具用户级工作目录，再逐项执行。版本检查必须实际退出成功；Node 还要求 npm 可执行，Python 为 3.13，Java 为 17。健康工具复用，不升级、不认领。
- WinGet 已登记但健康检查失败时调用官方 `repair`，刷新本进程 PATH 后复检。上游不支持修复、权限、许可证、认证或架构不满足时明确失败；既有软件不会获得本工具新增收据。
- 缺失组件在安装前保存 `Pending` 收据；安装后以 WinGet JSON 清单复查包 ID 和确定版本，再体检真实命令。无法确定安装成功时保留待完成状态，不声称就绪。上次中断的 Pending 不自动重新认领，先核对实际状态。
- 独立注册信息与完整安装目录均可核对时，保存所有文件内容、目录节点（含空目录）及注册信息的 SHA-256 指纹，状态为 `Installed`。目录不存在、注册信息不唯一、安装位置缺失、无法读取或含联接／符号链接时，状态为 `InstalledManualUndo`；软件已安装，但自动反安装会保留并返回未完成。**并非全部组件都能自动反安装。**
- 反安装逆序处理，仅操作本工具新增且版本、目录与注册信息未变的组件。原有安装、缺少收据、升级或新增／修改文件、空目录变化均保留并返回非零。收据确认的组件已被外部卸载时只更新收据；重复反安装不再启动卸载器。
- 只调用精确包 ID 的官方卸载器，不清理 WinGet 自动依赖，不清空项目、软件用户配置、缓存、数据库、账户或其它共享环境。所选开发工具可能被工程使用，执行反安装前自行核对影响；上游卸载器对自身配置的处理以该软件行为为准。
- 首个失败或不确定状态会停止后续组件，已完成项保留收据。可识别的 DNS、连接和传输超时错误按上限 30 秒退避重试，Ctrl+C 可结束；其它确定错误直接失败，不反复重放其它业务，不自动重启机器。

## 四、<span id="logs">来源、日志与运行限制</span> <a href="#前言">🔼</a> <a href="#🔚">🔽</a>

执行前显示组件、包 ID、当前选用的源名称和目标策略。`--source winget` 使用本机现有名为 `winget` 的源；本入口不重置来源、不添加镜像，源 URL 与最终下载地址由 WinGet 解析，以其实际输出为准。安装会接受所选包和源许可，可能请求 UAC；拒绝权限或企业策略限制时按真实失败返回。CMD 仅以 `-ExecutionPolicy Bypass` 覆盖本次新建 PowerShell 子进程的执行策略，不持久修改策略，不能覆盖组织组策略。

每轮独立纯文本日志与单组件 JSON 收据保存在同一工作目录；运行时显示实际位置。WinGet 输出逐行显示并追加日志，包管理器自身日志仍在其原生位置。用户级互斥文件只锁当前运行，不抢占其它有效实例；结束、异常与可捕获中断释放句柄。写路径拒绝联接和符号链接。

支持的当前控制台复用本仓现行临时终端配色保护，结束核对并恢复原配色；未知终端、重定向与 `NO_COLOR` 保留原状态并纯文本输出。保护不修改共享 Profile 或系统主题；强杀与控制台崩溃无法保证自动恢复，恢复入口由保护代码提示。真实 Windows 终端切色尚待验证。

## 五、<span id="verification">验证与交付范围</span> <a href="#前言">🔼</a> <a href="#🔚">🔽</a>

已在 macOS 的 PowerShell 7 运行时执行[隔离生命周期回归](../Tests/README.md)，覆盖默认只读、取消、失败、收据、内容与版本变化、坏 JSON、并发锁和保守反安装；实际 WinGet、注册表、UAC、Windows PowerShell 5.1 与 CMD 透传仍待 Windows 实机验证。源码按 5.1 语法编写，中文 `.ps1` 使用 UTF-8 BOM；Parser 与本地隔离回归通过不能代替上述实机结果。

管理面板可以显式传入 `-Events`，在原日志之外读取 `@@JOBS_EVENT@@` 前缀的单行 JSON：`schema=1`、`id`、`operation`、`state`。状态为 `running / completed / reused / skipped / failed`，缺省不输出事件；首项失败照常返回非零并停止后续，未开始项不发成功事件。它只增加结果通道，不改变授权、收据和卸载条件。

<a id="🔚" href="#前言">我是有底线的➤点我回到首页</a>

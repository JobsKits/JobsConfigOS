# WindowsOS 新系统配置

![Jobs出品，必属精品](https://picsum.photos/1500/400)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [🔥 前言](#%E5%89%8D%E8%A8%80)
- [一、平台能力与边界](#coverage)
- [二、快速使用](#usage)

</details>
<!-- jobs-toc:end -->

---

## 🔥 <span id="前言">前言</span>

使用 [**Windows PowerShell**](https://learn.microsoft.com/powershell/scripting/windows-powershell/overview) 和已有 [**WinGet**](https://learn.microsoft.com/windows/package-manager/winget/)按需准备开发工具。最低系统为 Windows 10 1809（build 17763）64 位；包管理器要求 WinGet 1.8 或以上。Windows 11 ARM64 由包清单选择兼容制品，具体包可能有更高系统要求；尚未完成 Windows 实机安装与反安装验收。

| 入口 | 用途 |
| --- | --- |
| [新系统配置](./【WindowsOS】🆕新系统配置.ps1/README.md) | `.cmd` 双击查看默认静态计划；`.ps1` 提供清单、计划、安装和卸载 |
| [反安装快捷入口](./【WindowsOS】↩️卸载新系统配置.ps1/README.md) | 显式选择组件，转交同一收据与指纹检查流程 |
| [原生管理面板](./【WindowsOS】🧰新系统配置管理.ps1/README.md) | 真实 EXE 或 CMD 双击打开 WinForms；多选、计划、受管执行、日志、三主题十语与后台托盘 |
| [EXE 源码构建工程](./【WindowsOS】🧰新系统配置管理.ps1/Launcher/README.md) | C#／net472／AnyCPU，附官方参考包锁、可复现构建说明与成品回执 |
| [隔离回归](./Tests/README.md) | 使用函数替身和临时目录，验证生命周期与失败边界 |

## 一、<span id="coverage">平台能力与边界</span> <a href="#前言">🔼</a> <a href="#🔚">🔽</a>

- 提供基础开发工具、版本管理辅助、终端工具及通用媒体工具；实际组件 ID 与 WinGet 包 ID 见[完整清单](./【WindowsOS】🆕新系统配置.ps1/README.md#components)。源码清单为 20 项（统计口径：唯一组件 ID；依据实施脚本 Catalog；核对日期：2026-11-17）。
- 原有健康工具直接复用；缺失时通过现有包源补装；WinGet 已登记但无法执行的工具定向调用 `repair` 后复检，不因此认领原有软件。Node.js 组件同时体检 Node 与 npm；新安装选择 LTS 包，已有健康版本不强制升级。Python 要求 3.13，Java 要求 17。
- WinGet 缺失或版本过低时提供官方 [App Installer](https://aka.ms/getwinget)入口；不从网络下载执行包管理器安装脚本，不持久修改执行策略，不修改系统代理或默认 Shell；CMD 仅对本次 PowerShell 子进程使用 `-ExecutionPolicy Bypass`，组织策略仍可阻断，不全量升级及清理软件。
- Windows 自带 `curl.exe` 可作为健康工具复用。[**Git for Windows**](https://gitforwindows.org/)附带 Git Bash；本包不冒充原生 zsh，也不隐式安装 WSL。没有可靠 WinGet 清单的 wget、Maven、Gradle 不列为已实现组件。
- MacOS 专属 CLT、Xcode、iOS 平台、Hammerspoon 与 JobsMacEnvVarConfigs 不在本平台执行；本平台提供[原生 GUI](./【WindowsOS】🧰新系统配置管理.ps1/README.md)，与 CLI 共用组件清单及收据边界。

## 二、<span id="usage">快速使用</span> <a href="#前言">🔼</a> <a href="#🔚">🔽</a>

在本目录打开终端；路径包含中文和空格时保留引号。

```powershell
# 默认只读计划；没有包管理器或服务器时也可阅读。
& './【WindowsOS】🆕新系统配置.ps1/【WindowsOS】🆕新系统配置.ps1'
& './【WindowsOS】🆕新系统配置.ps1/【WindowsOS】🆕新系统配置.ps1' -Mode List

# 显式选择组件后进入默认取消的键盘确认。
& './【WindowsOS】🆕新系统配置.ps1/【WindowsOS】🆕新系统配置.ps1' -Mode Install -Components git,node,python

# 只预览卸载边界，不读取包状态或落盘。
& './【WindowsOS】🆕新系统配置.ps1/【WindowsOS】🆕新系统配置.ps1' -Mode Plan -Operation Uninstall -Components git

# 反安装快捷入口仍要求明确确认。
& './【WindowsOS】↩️卸载新系统配置.ps1/【WindowsOS】↩️卸载新系统配置.ps1' -Components git
```

可双击 `./【WindowsOS】🧰新系统配置管理.ps1/JobsSystemSetupManager.exe` 打开 GUI。EXE 为真实编译的 Windows GUI PE／AnyCPU 托管程序，要求系统 .NET Framework 4.7.2+ 与 PowerShell 5.1，依赖邻接配置、面板与后端资源，不能单独分发。成品已跨编译及隔离检查，尚未在 Windows 实机运行。

脚本自身路径是资源基准，可以整体复制 `WindowsOS/` 后从其它工作目录运行。独立交付请保留整个平台目录；反安装快捷入口依赖同平台实施脚本。

<a id="🔚" href="#前言">我是有底线的➤点我回到首页</a>

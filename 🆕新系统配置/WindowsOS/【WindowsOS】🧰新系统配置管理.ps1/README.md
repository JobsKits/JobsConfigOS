# WindowsOS 新系统配置管理面板

![Jobs出品，必属精品](https://picsum.photos/1500/400)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [🔥 前言](#%E5%89%8D%E8%A8%80)
- [一、打开与选择](#entry)
- [二、执行、日志与后台](#execution)
- [三、外观、语言与交付](#preferences)
- [四、验证边界](#verification)

</details>
<!-- jobs-toc:end -->

---

## 🔥 <span id="前言">前言</span>

使用系统自带的 [**Windows PowerShell 5.1**](https://learn.microsoft.com/powershell/scripting/windows-powershell/overview) 与 [**WinForms**](https://learn.microsoft.com/dotnet/desktop/winforms/overview/) 提供原生管理界面；安装、健康检查、修复和受管卸载均转交同平台既有实施脚本。默认空选，打开面板不调用 WinGet、不安装、不卸载。

## 一、<span id="entry">打开与选择</span> <a href="#前言">🔼</a> <a href="#🔚">🔽</a>

双击同目录 [JobsSystemSetupManager.exe](./JobsSystemSetupManager.exe) 打开面板；也可保留使用 `【WindowsOS】🧰新系统配置管理.cmd`。EXE 是真实编译的 AnyCPU／.NET Framework 4.7.2 Windows GUI 启动器，不显示控制台，不触发安装；需要邻接 `.exe.config`、面板脚本、Resources 与同平台 CLI，不能只复制单个 EXE。启动器源码及 Windows 可复现构建见[Launcher 工程](./Launcher/README.md)，成品与源码哈希见[构建回执](./LauncherBuildReceipt.json)。启动器唤起 GUI 后退出。下面的 PowerShell 示例在本包目录运行；从其它工作目录启动时请使用脚本实际路径：

```powershell
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File './【WindowsOS】🧰新系统配置管理.ps1'
```

- 面板读取当前后端 20 项组件目录；初始“归属未知”是尚未查询的状态，不能据此判断是否安装。静态计划不联网、不运行包查询；实际执行时才检查软件状态、收据和指纹。
- 搜索只改变可见行；选择可见、清空全部及整行单击可选中组件。空选禁用计划和执行；空搜索结果显示完整空态并保留重新加载入口。切换安装／卸载、主题或语言保留同会话选择。
- 先按需查看计划。安装／卸载按钮是当前选择的最终确认，会接受所选软件包与 WinGet 源许可，Windows 可能显示 UAC；不会另弹终端确认，不自动重启。Windows 与 WinGet 最低要求、组件清单及保守卸载边界见[平台说明](../README.md)。

## 二、<span id="execution">执行、日志与后台</span> <a href="#前言">🔼</a> <a href="#🔚">🔽</a>

- 后端按原顺序安装、逆序卸载，首个不确定状态停止。界面按真实事件和进程退出码分别显示等待、执行中、完成、复用已有工具、无需卸载、失败、未执行；进度 100% 仅表示本次处理结束。启动阶段失败时未执行项不会冒充成功。
- 安装与卸载分别计时。进程退出且 stdout、stderr 全部排空后才冻结，日志不因关闭窗口而截断。主题和语言仍可在运行中切换，组件选择与重复执行被锁定。
- 显示区保留约 300,000 字符，完整会话日志保存在当前用户 `%LOCALAPPDATA%\JobsSystemBootstrap\WindowsOS\panel-*.log`。复制按钮复制**显示区**，日志文件按钮打开本次完整日志；后台原始诊断不翻译，不按 stderr 来源推断失败。
- 日志默认追尾，滚轮、滚动条或导航键浏览后暂停；重新勾选“自动滚动”恢复追尾。日志区域与组件表格独立滚动，分隔条可调整两区高度。
- 忙时关闭窗口直接转托盘，工作进程和输出继续运行；完成后继续驻留。空闲关闭时可选择后台、完全退出或取消，默认后台；托盘可恢复原窗口，忙时不能完全退出。不会注册开机启动或系统服务。
- 网络获取仍沿用原后端重试策略。当前 GUI 不提供强制终止或中断正在进行的包安装；后台日志可持续查看。需要交互式 Ctrl+C 的运维场景使用保留的终端入口，避免同时运行两个写任务。

## 三、<span id="preferences">外观、语言与交付</span> <a href="#前言">🔼</a> <a href="#🔚">🔽</a>

- 提供白天、黑夜、跟随系统；系统模式轮询当前用户外观，已有日志同时重新着色。
- 提供跟随系统及简体中文、繁体中文、藏文、英文、日文、法文、西班牙文、德文、俄罗斯文、韩文。包名、路径和后端诊断保留原文；藏文字体依赖目标 Windows 的字体回退支持。
- 用户主动修改的偏好写入 `%LOCALAPPDATA%\JobsSystemBootstrap\WindowsOS\panel-settings.json`，重启恢复。组件选择、退出选项不持久化。
- 分发时保留完整 `WindowsOS/`，其中包括实施脚本和 GUI 的 `Resources/`。运行资源从脚本位置解析，没有开发机路径依赖；无需安装 Python、Node.js 或下载 GUI 框架。
- CMD 和子进程仅对当次 PowerShell 使用执行策略参数，不修改系统策略；企业策略仍可能阻止运行。同时保留面板源码与真实编译的 EXE 启动器；EXE 运行需要 .NET Framework 4.7.2 或兼容的更高 4.x，不要求构建所用的现代 .NET SDK，也不是单 EXE 自包含产品。

## 四、<span id="verification">验证边界</span> <a href="#前言">🔼</a> <a href="#🔚">🔽</a>

跨平台只读检查（不加载 WinForms、不调用 WinGet、不写偏好）：

```powershell
& './【WindowsOS】🧰新系统配置管理.ps1/【WindowsOS】🧰新系统配置管理.ps1' -Check
& './Tests/WindowsPanel.Tests.ps1/WindowsPanel.Tests.ps1'
```

2026-11-17：PowerShell 解析、20 项当前目录、103 键十语完整性、后端事件失败与顺序、默认兼容、后台假进程 UTF-8／尾输出／非零退出码等 23 项隔离断言通过；既有 45 项生命周期隔离回归通过。源码整体复制到中文空格路径后，从其它工作目录检查通过。

EXE 已在 macOS 的 .NET SDK 11.0.100 使用锁定官方参考包跨编译，零警告、零错误；PE／CLR 标记核对为 Windows GUI／AnyCPU。18 项隔离断言验证参数、路径、缺资源、重定位及 BCL 引用，没有实际启动 Windows 程序。**EXE 尚未在 Windows 实机运行**，启动器原生消息框和双击行为待目标系统验收。

这些结果不等同 Windows 实机 GUI 验收。WinForms 控件渲染、鼠标／键盘／无障碍、窄窗长翻译、主题切换、UAC、托盘关闭生命周期和真实安装／卸载仍需在 Windows 本机验证；本任务没有调用真实 WinGet。

<a id="🔚" href="#前言">我是有底线的➤点我回到首页</a>

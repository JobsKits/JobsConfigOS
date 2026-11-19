# WindowsOS 新系统配置管理｜源码与成品运行包

![Jobs出品，必属精品](https://picsum.photos/1500/400)

[toc]

---

## 🔥 <span id="前言">前言</span>

平台：WindowsOS。交付类型：`windows-pe-launcher-and-powershell-runtime`。`source.zip` 包含当前源码及必要构建/运行资源，`product.zip` 包含最终运行内容；两者分开交付。每个ZIP旁有独立SHA256，`manifest.json`保存逐文件来源快照摘要，解压后不得拆散原有相对结构。

## 一、<span id="entries">源码、构建与启动</span> <a href="#前言">🔼</a> <a href="#🔚">🔽</a>

- 源码入口（解压source.zip后）：`WindowsOS/【WindowsOS】🧰新系统配置管理.ps1/【WindowsOS】🧰新系统配置管理.ps1`。
- 成品启动文件（解压product.zip后）：`WindowsOS/【WindowsOS】🧰新系统配置管理.ps1/JobsSystemSetupManager.exe`。

构建入口：

- `WindowsOS/【WindowsOS】🧰新系统配置管理.ps1/Launcher/JobsSystemSetupManager.csproj`

Mac产品直接打开App；Windows打开真实EXE并保留相邻运行资源；Unix在目标桌面使用`sh`调用上述启动文件。生产包不要求打包器的Python环境。

## 二、<span id="runtime">运行依赖与范围</span> <a href="#前言">🔼</a> <a href="#🔚">🔽</a>

- Windows 10 1809 64位及以上目标；.NET Framework 4.7.2或兼容后续4.x、Windows PowerShell 5.1和WinForms；目标机验收仍待核
- EXE为AnyCPU托管GUI启动器，不是Native AOT或自包含运行时；必须保留本包PowerShell GUI、同平台CLI和运行资源，安装任务需要WinGet及实际授权

本包不附带用户配置、账户凭据、密钥、运行日志或系统缓存。源码包的默认配置/模板仍保留原文件内容；本轮没有运行其中的安装/卸载动作。Unix包为解释型GUI运行包，不冒充ELF/AppImage；Windows EXE是启动器，不代表PowerShell GUI已经编译到二进制里。

## 三、<span id="verification">已验与未验</span> <a href="#前言">🔼</a> <a href="#🔚">🔽</a>

本次打包实际核验：

- 打包器复核归档逐文件SHA-256与ZIP完整性；此项不是目标系统GUI运行结论
- 真实EXE存在及PE头/架构字段核验；不将其作为WindowsGUI运行结论

目标平台待验边界：

- 目标Windows上的EXE双击、WinForms/UAC/托盘、真实WinGet包事务未由打包器验收

包的生成时间是归档时间，不冒充App/EXE编译时间；原生构建回执单独保存在运行内容或manifest。SHA256能核对完整性，不代表开发者签名或目标机器运行验收。

<a id="🔚" href="#前言">我是有底线的➤点我回到首页</a>

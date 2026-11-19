# Debian 新系统配置管理｜源码与成品运行包

![Jobs出品，必属精品](https://picsum.photos/1500/400)

[toc]

---

## 🔥 <span id="前言">前言</span>

平台：Debian。交付类型：`interpreted-tcl-tk-gui-runtime`。`source.zip` 包含当前源码及必要构建/运行资源，`product.zip` 包含最终运行内容；两者分开交付。每个ZIP旁有独立SHA256，`manifest.json`保存逐文件来源快照摘要，解压后不得拆散原有相对结构。

## 一、<span id="entries">源码、构建与启动</span> <a href="#前言">🔼</a> <a href="#🔚">🔽</a>

- 源码入口（解压source.zip后）：`GuiRuntime/安装面板/UnixManager.tcl/UnixManager.tcl`。
- 成品启动文件（解压product.zip后）：`GuiRuntime/Debian/【Debian】🧰新系统配置管理.sh/【Debian】🧰新系统配置管理.sh`。

构建入口：

- 无二进制构建步骤；源码本身由系统Tcl/Tk解释执行。

Mac产品直接打开App；Windows打开真实EXE并保留相邻运行资源；Unix在目标桌面使用`sh`调用上述启动文件。生产包不要求打包器的Python环境。

## 二、<span id="runtime">运行依赖与范围</span> <a href="#前言">🔼</a> <a href="#🔚">🔽</a>

- 匹配的Debian x64/ARM64桌面；具体最低OS版本尚未实机锁定
- Tcl/Tk 8.6+、DISPLAY；Wayland需XWayland；写任务需root或可用PolicyKit图形授权
- 这是解释型GUI成品运行包，保留完整同平台CLI/共享资源；不是ELF、AppImage或内嵌Tk的独立二进制

本包不附带用户配置、账户凭据、密钥、运行日志或系统缓存。源码包的默认配置/模板仍保留原文件内容；本轮没有运行其中的安装/卸载动作。Unix包为解释型GUI运行包，不冒充ELF/AppImage；Windows EXE是启动器，不代表PowerShell GUI已经编译到二进制里。

## 三、<span id="verification">已验与未验</span> <a href="#前言">🔼</a> <a href="#🔚">🔽</a>

本次打包实际核验：

- 打包器复核归档逐文件SHA-256与ZIP完整性；此项不是目标系统GUI运行结论
- 共享模型与本机Tk隔离验证的历史记录见随包说明；不外推目标发行版已运行

目标平台待验边界：

- Debian原生桌面、字体/辅助技术、PolicyKit和真实系统包事务未验
- 运行依赖Tcl/Tk和图形桌面，不自动安装GUI运行时

包的生成时间是归档时间，不冒充App/EXE编译时间；原生构建回执单独保存在运行内容或manifest。SHA256能核对完整性，不代表开发者签名或目标机器运行验收。

<a id="🔚" href="#前言">我是有底线的➤点我回到首页</a>

# Jobs 新系统配置（多平台）

![Jobs出品，必属精品](https://picsum.photos/1500/400)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [🔥 前言](#%E5%89%8D%E8%A8%80)
- [一、平台入口与图形界面](#gui-entrypoints)
- [二、目录与运行](#jobs-toc-heading-3)
  - [2.1、各平台独立卸载入口](#uninstall-entrypoints)
  - [2.2、图形管理入口](#jobs-toc-heading-5)
- [三、功能边界与依赖](#jobs-toc-heading-6)
- [四、验证范围](#jobs-toc-heading-7)

</details>
<!-- jobs-toc:end -->

---

## 🔥 <span id="前言">前言</span>

按操作系统分目录配置新机器的开发环境。安装与卸载统一归入 `🆕新系统配置/`，实际支持范围由下面的平台入口决定。这里是系统环境初始化工具，不会部署学术服务平台业务。

当前功能目录集中保存平台入口与交付：MacOS 原生面板源码和构建工具位于 [MacOS/安装面板](./MacOS/安装面板/README.md)，六套 Unix 共用的 [安装面板](./安装面板/README.md) 保持独立，版本化源码与成品包归 [交付产物](./交付产物/GUI源码与成品/README.md)。

## 一、<span id="gui-entrypoints">平台入口与图形界面</span> <a href="#前言">🔼</a> <a href="#🔚">🔽</a>

平台集合依据用户指定的学术服务平台 `部署/` 目录核对；`Windows` 在本仓统一命名为 `WindowsOS`。

**直接打开 GUI：** 下表链接指向实际启动文件。MacOS 使用 `.app`；WindowsOS 双击 `.exe`（或保留的 `.cmd`）打开 WinForms 窗口；其余六个平台运行 `.sh` 打开 Tk 窗口。这些 `.cmd`／`.sh` 是图形界面启动器，并非仅有终端安装功能。请在对应目标系统运行，macOS 不能运行 Windows WinForms 或通过 Unix 平台门禁。

| 平台 | GUI 启动文件 | 入口说明 | 配置能力 | 原生工具 |
| --- | --- | --- | --- | --- |
| [**MacOS**](https://www.apple.com/macos/) | [打开管理 App](./MacOS/【MacOS】🧰新系统配置管理.app) | [MacOS/README.md](./MacOS/README.md) | 原有十阶段、组件管理面板与受管卸载 | zsh / Homebrew |
| [**WindowsOS**](https://www.microsoft.com/windows) | [打开管理 EXE](./WindowsOS/【WindowsOS】🧰新系统配置管理.ps1/JobsSystemSetupManager.exe) | [WindowsOS/README.md](./WindowsOS/README.md) | 原生 PowerShell 与双击 CMD 入口 | PowerShell / WinGet |
| [**Ubuntu**](https://ubuntu.com/) | [运行管理 SH](./Ubuntu/【Ubuntu】🧰新系统配置管理.sh/【Ubuntu】🧰新系统配置管理.sh) | [Ubuntu/README.md](./Ubuntu/README.md) | 基础开发工具按组件配置 | sh / apt-get |
| [**Debian**](https://www.debian.org/) | [运行管理 SH](./Debian/【Debian】🧰新系统配置管理.sh/【Debian】🧰新系统配置管理.sh) | [Debian/README.md](./Debian/README.md) | 基础开发工具按组件配置 | sh / apt-get |
| [**RockyLinux**](https://rockylinux.org/) | [运行管理 SH](./RockyLinux/【RockyLinux】🧰新系统配置管理.sh/【RockyLinux】🧰新系统配置管理.sh) | [RockyLinux/README.md](./RockyLinux/README.md) | 基础开发工具按组件配置 | sh / dnf |
| [**Alpine**](https://alpinelinux.org/) | [运行管理 SH](./Alpine/【Alpine】🧰新系统配置管理.sh/【Alpine】🧰新系统配置管理.sh) | [Alpine/README.md](./Alpine/README.md) | 基础开发工具按组件配置 | sh / apk |
| [**AlibabaCloudLinux**](https://www.alibabacloud.com/product/alibaba-cloud-linux) | [运行管理 SH](./AlibabaCloudLinux/【AlibabaCloudLinux】🧰新系统配置管理.sh/【AlibabaCloudLinux】🧰新系统配置管理.sh) | [AlibabaCloudLinux/README.md](./AlibabaCloudLinux/README.md) | 基础开发工具按组件配置 | sh / dnf |
| [**FreeBSD**](https://www.freebsd.org/) | [运行管理 SH](./FreeBSD/【FreeBSD】🧰新系统配置管理.sh/【FreeBSD】🧰新系统配置管理.sh) | [FreeBSD/README.md](./FreeBSD/README.md) | 基础开发工具按组件配置 | sh / pkg |

## <span id="jobs-toc-heading-3" data-jobs-toc="v2">二、目录与运行 <a href="#前言">🔼</a> <a href="#🔚">🔽</a></span><!-- jobs-toc:heading-end -->

```text
🆕新系统配置/
├── README.md
├── MacOS/
│   ├── 【MacOS】🆕新系统配置.command/  # 安装入口、后端和测试
│   └── 【MacOS】↩️卸载新系统配置.command/  # 终端多选卸载
├── WindowsOS/                         # PowerShell 与 CMD
├── Ubuntu/
├── Debian/
├── RockyLinux/
├── Alpine/
├── AlibabaCloudLinux/
└── FreeBSD/
```

从各平台 README 复制命令；脚本按自身位置定位资源，允许整个目录复制、改名，并从其它工作目录运行。MacOS 终端入口如下：

```shell
zsh "./MacOS/【MacOS】🆕新系统配置.command/【MacOS】🆕新系统配置.command"
```

新平台入口默认展示只读计划，使用显式组件和写操作确认后才安装或卸载；详细参数以各平台 `--help` 或 `-Mode Help` 为准。普通执行不批量升级全系统软件，不自动改系统代理、默认 Shell 或个人终端配置。日志与收据位置见对应 README。

### 2.1、<span id="uninstall-entrypoints">各平台独立卸载入口</span> <a href="#前言">🔼</a> <a href="#🔚">🔽</a>

以下八个入口均位于各自平台目录，与安装入口成对。MacOS 在终端通过 fzf 多选；WindowsOS 与六个 Unix 平台显式传入组件，未指定组件不会隐式全选。图形面板也可对所选组件执行相同的受管卸载。

| 平台 | 独立卸载脚本 | 运行与安全边界 |
| --- | --- | --- |
| MacOS | [卸载入口](./MacOS/【MacOS】↩️卸载新系统配置.command/【MacOS】↩️卸载新系统配置.command) | 回车进入选择，查看计划后再用空格确认 |
| WindowsOS | [卸载入口](./WindowsOS/【WindowsOS】↩️卸载新系统配置.ps1/【WindowsOS】↩️卸载新系统配置.ps1) | 指定 `-Components`；`-Confirm` 为显式执行授权 |
| Ubuntu | [卸载入口](./Ubuntu/【Ubuntu】↩️卸载新系统配置.sh/【Ubuntu】↩️卸载新系统配置.sh) | 无参仅显示帮助；指定 `--components`，`--yes` 为显式执行授权 |
| Debian | [卸载入口](./Debian/【Debian】↩️卸载新系统配置.sh/【Debian】↩️卸载新系统配置.sh) | 无参仅显示帮助；指定 `--components`，`--yes` 为显式执行授权 |
| RockyLinux | [卸载入口](./RockyLinux/【RockyLinux】↩️卸载新系统配置.sh/【RockyLinux】↩️卸载新系统配置.sh) | 无参仅显示帮助；指定 `--components`，`--yes` 为显式执行授权 |
| Alpine | [卸载入口](./Alpine/【Alpine】↩️卸载新系统配置.sh/【Alpine】↩️卸载新系统配置.sh) | 无参仅显示帮助；指定 `--components`，`--yes` 为显式执行授权 |
| AlibabaCloudLinux | [卸载入口](./AlibabaCloudLinux/【AlibabaCloudLinux】↩️卸载新系统配置.sh/【AlibabaCloudLinux】↩️卸载新系统配置.sh) | 无参仅显示帮助；指定 `--components`，`--yes` 为显式执行授权 |
| FreeBSD | [卸载入口](./FreeBSD/【FreeBSD】↩️卸载新系统配置.sh/【FreeBSD】↩️卸载新系统配置.sh) | 无参仅显示帮助；指定 `--components`，`--yes` 为显式执行授权 |

所有入口都核对原有归属凭据。既有、共享、被后续修改或缺少收据的对象按各平台后端规则保留并报告；Unix 版本匹配不等同包文件完整性校验。该功能不承诺恢复整台操作系统，也不会删除包管理器的全部自动依赖。复制时保留完整平台目录，GUI 另需共享资源；不能只带走一个卸载脚本。

当前入口、默认值与验证证据见[卸载入口资产盘点](../项目相关报告/新系统配置卸载入口资产盘点.md)。

### <span id="jobs-toc-heading-5" data-jobs-toc="v2">2.2、图形管理入口 <a href="#前言">🔼</a> <a href="#🔚">🔽</a></span><!-- jobs-toc:heading-end -->

> 在目标平台运行对应入口。界面默认空选，提供搜索、多选、全选／清空、预览计划、安装／卸载和日志；语言与主题偏好按当前用户保存。原终端入口继续保留。

| 平台 | GUI 入口 | 运行条件 |
| --- | --- | --- |
| MacOS | [新系统配置管理.app](./MacOS/【MacOS】🧰新系统配置管理.app) · [使用及重建说明](./MacOS/安装面板/README.md) | macOS 13+；App 自包含，可独立复制；[Xcode工程](./MacOS/【MacOS】🧰新系统配置管理.xcodeproj)与[Swift源码](./MacOS/安装面板/Sources/EnvironmentManager.swift)随仓 |
| WindowsOS | [管理面板说明](./WindowsOS/【WindowsOS】🧰新系统配置管理.ps1/README.md) | Windows 桌面、Windows PowerShell 5.1；双击包内 CMD |
| Ubuntu | [管理面板说明](./Ubuntu/【Ubuntu】🧰新系统配置管理.sh/README.md) | 图形桌面、Tcl/Tk 8.6+ |
| Debian | [管理面板说明](./Debian/【Debian】🧰新系统配置管理.sh/README.md) | 图形桌面、Tcl/Tk 8.6+ |
| RockyLinux | [管理面板说明](./RockyLinux/【RockyLinux】🧰新系统配置管理.sh/README.md) | 图形桌面、Tcl/Tk 8.6+ |
| Alpine | [管理面板说明](./Alpine/【Alpine】🧰新系统配置管理.sh/README.md) | 图形桌面、Tcl/Tk 8.6+ |
| AlibabaCloudLinux | [管理面板说明](./AlibabaCloudLinux/【AlibabaCloudLinux】🧰新系统配置管理.sh/README.md) | 图形桌面、Tcl/Tk 8.6+ |
| FreeBSD | [管理面板说明](./FreeBSD/【FreeBSD】🧰新系统配置管理.sh/README.md) | 图形桌面、Tcl/Tk 8.6+ |

Windows 面板使用系统 [**WinForms**](https://learn.microsoft.com/dotnet/desktop/winforms/)，Linux／FreeBSD 使用共享 [**Tcl/Tk**](https://www.tcl-lang.org/) [管理器](./安装面板/README.md)。后两类需连同本平台 CLI 和共享资源按原布局复制；不能只复制启动脚本。缺少图形环境或 Tk 时入口提示依赖，不自动安装桌面或额外运行时。无桌面服务器直接使用 CLI。

三主题为白天／黑夜／跟随系统，十语为简体中文／繁体中文／藏文／英文／日文／法文／西班牙文／德文／俄罗斯文／韩文，并提供跟随系统语言。MacOS 与 Windows 使用状态栏／托盘保留后台任务；Unix 使用最小化保留同一窗口和任务，系统外观跟随能力及授权方式见其说明。目录清单、计划、实际执行状态分别呈现，不把静态包列表当成已安装状态，不使用假数据驱动系统写操作。

## <span id="jobs-toc-heading-6" data-jobs-toc="v2">三、功能边界与依赖 <a href="#前言">🔼</a> <a href="#🔚">🔽</a></span><!-- jobs-toc:heading-end -->

| 能力 | MacOS | WindowsOS / Linux / FreeBSD |
| --- | --- | --- |
| 开发工具 | 保留原 Homebrew formula / cask 清单 | 使用各平台原生软件源映射基础开发工具，具体清单见就近说明 |
| 系统工具链 | CLT、Xcode 和 iOS 平台 | 只提供本系统适用工具，不运行 Apple 专属命令 |
| Jobs 配置 | 保留本仓环境子模块与软件仓调用 | 不套用 MacOS 的 zsh 配置、Hammerspoon 或软件仓 |
| CodeGraph / quicktype / REA | 保留既有受管 npm 能力 | 未提供的平台能力不计作已支持；以平台清单为准 |
| 图形管理面板 | `MacOS/` 内独立 App，源码构建随当前脚本刷新 | 各平台有独立 GUI 入口，共用本平台 CLI；见上方入口表与资产盘点 |
| 反安装 | 保留既有收据、指纹和共享依赖保护 | 仅撤回本工具新装且核验仍匹配的显式组件（Unix按版本，Windows另核对完整指纹）；包管理器自动依赖保留 |

新平台的包版本随目标机器现有软件源解析，不承诺等同 Homebrew 版本。不会为可选组件擅自添加第三方源、关闭安全机制或从网络直接执行脚本。执行计划后仍需检查来源、权限和包名；源里没有的组件会明确失败。已存在的工具不据此获得卸载归属。

## <span id="jobs-toc-heading-7" data-jobs-toc="v2">四、验证范围 <a href="#前言">🔼</a> <a href="#🔚">🔽</a></span><!-- jobs-toc:heading-end -->

当前八平台入口、默认值、持久化与本轮隔离验证记录在[卸载入口资产盘点](../项目相关报告/新系统配置卸载入口资产盘点.md)。各平台的组件生命周期与既有验证边界同时见就近 README。

本轮不在真实机器执行全量安装或卸载；跨平台源码和夹具通过不等于目标系统实机验收。MacOS App 位于 `MacOS/`，构建器默认输出到同一位置，使用包内脚本与资源；修改仓库源码后须重新构建 App 才会生效。

<a id="🔚" href="#前言">我是有底线的➤点我回到首页</a>

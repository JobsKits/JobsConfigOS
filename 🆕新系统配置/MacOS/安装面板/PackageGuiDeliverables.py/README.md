# GUI 源码与成品交付打包器

![Jobs出品，必属精品](https://picsum.photos/1500/400)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [🔥 前言](#%E5%89%8D%E8%A8%80)
- [一、使用方式](#usage)
- [二、输入与交付目录](#contents)
- [三、核验、过滤与失败处理](#verification)
- [四、隔离测试](#tests)

</details>
<!-- jobs-toc:end -->

---

## 🔥 <span id="前言">前言</span>

本入口使用 [**Python**](https://www.python.org/) 3.9+ 标准库，按固定输入清单交付9套 GUI：新系统配置 Mac App、环境配置 Mac App、WindowsOS GUI 及 Ubuntu、Debian、RockyLinux、Alpine、AlibabaCloudLinux、FreeBSD GUI。默认只读计划；只有显式 `--yes` 才归档当前源码与已真实生成的成品。打包器不编译、不联网安装工具、不执行系统安装/卸载、不推送仓库，也不覆盖旧交付物。

## 一、<span id="usage">使用方式</span> <a href="#前言">🔼</a> <a href="#🔚">🔽</a>

在本目录运行；也可从其它工作目录以完整脚本路径调用：

```sh
python3 './PackageGuiDeliverables.py' --plan
python3 './PackageGuiDeliverables.py' --yes
```

项目根默认从脚本自身位置定位到 `JobsConfigOS/`。换目录仍保留原相对结构即可，不固化开发机路径。高级参数：`--project-root /目标/JobsConfigOS` 指定明确输入根，`--output '🆕新系统配置/交付产物/GUI源码与成品'` 指定输出根；相对输出路径从项目根定位。输出不能位于任何输入树内，也不能经符号链接发布。

`--plan` 核对全部9套输入、收据和产物，显示文件数、大小、源码入口、构建入口、启动位置及缺失项；不创建输出、日志或暂存。缺真实 App、构建回执、源码、EXE 或必需资源时返回非零，不能用占位文件补成“成功”。`--yes` 使用相同核验，全部通过才开始暂存；应在并行源码/构建任务结束后运行。

## 二、<span id="contents">输入与交付目录</span> <a href="#前言">🔼</a> <a href="#🔚">🔽</a>

> 输入按本项目已确认的9套工具固定映射，不扫描其它仓库或整个用户目录。

| 交付项 | 源码包 | 成品运行包 |
| --- | --- | --- |
| `MacOS-System` | MacOS/安装面板源码/翻译/构建器、图标、Mac原CLI后端及Xcode工程、环境子仓必需配置与脚本；保留完整 `JobsConfigOS/` 相对树 | 现成新系统管理 `.app`，含完整签名及随包资源 |
| `MacOS-Environment` | 环境子仓安装面板、图标、scripts/zsh/Sys/管理后端/sync_env；若存在相应工程也纳入 | 现成环境配置管理 `.app` |
| `WindowsOS` | 整个WindowsOS源码、Launcher工程/锁文件、CLI、资源、Tests与README | 真实 `JobsSystemSetupManager.exe`及相邻`.exe.config`、构建回执、同平台GUI脚本/运行资源/CLI；排除Launcher工程及Tests |
| 六套Unix | 各自平台源码与公共Tcl/Tk安装面板，含测试 | 同平台启动器/CLI和公共Tcl/Tk完整运行资源，排除Tests |

Mac产品为原生 App；Windows产品为真实 PE GUI 启动器加 [**PowerShell**](https://learn.microsoft.com/powershell/) 运行资源；Unix产品明确是 [**Tcl/Tk**](https://www.tcl-lang.org/) 8.6+ 桌面解释型运行包，**不是 ELF、AppImage 或内嵌 Tk 的独立二进制**。各包自己的README记录启动文件、运行依赖和已验/待验边界，归档时间不冒充原生程序编译时间。

默认输出为：

```text
JobsConfigOS/🆕新系统配置/交付产物/GUI源码与成品/
└── YYYY.MM.DD HH-mm-ss/
    ├── README.md
    ├── manifest.json
    ├── manifest.json.sha256
    ├── packaging.log
    ├── MacOS-System/
    ├── MacOS-Environment/
    ├── WindowsOS/
    └── 六个平台目录/
        ├── source.zip
        ├── source.zip.sha256
        ├── product.zip
        ├── product.zip.sha256
        ├── manifest.json
        ├── manifest.json.sha256
        └── README.md
```

版本目录使用上海时间；同秒已有目录时增加随机后缀，保留旧版本。根manifest汇总9套摘要；每套manifest记录ZIP摘要、逐文件SHA-256、UNIX权限/链接类型及构建校验资料。ZIP条目按路径排序、时间统一为1980-01-01；相同文件内容和权限重复归档时ZIP可复现，外层manifest与日志仍保留真实归档时间。

## 三、<span id="verification">核验、过滤与失败处理</span> <a href="#前言">🔼</a> <a href="#🔚">🔽</a>

- Mac必须有 `BuildReceipt.plist`，其profile、当前Swift源SHA及真实构建时间必须匹配；`Payload.sha256` 逐文件核验，并要求覆盖完整资源集合；还将全部 `Resources/package/` 资源逐项映射到当前仓库源文件核对SHA。新系统App映射JobsConfigOS根，其中包内既有 `【MacOS】🆕新系统配置/` 精确映射到当前源树 `🆕新系统配置/`；环境App映射环境子仓根。该映射仍逐文件核对摘要，不回退到旧目录；当前源文件缺失或内容变化而App未刷新时拒绝归档，避免新源码包与旧后端产品混装。在Mac打包时另调用只读 `codesign --verify --deep --strict`；没有回执不能只凭App存在就放行。
- Windows必须是实际存在、具备MZ/PE头及已知机器类型的EXE。还必须存在`LauncherBuildReceipt.json`，逐项核对其中5份工程/源码/锁文件，以及EXE与config的SHA和产物大小；真实构建时间、工具链和`nativeWindowsRun`原文写入交付manifest。格式或托管构建检查不冒充Windows运行验收。Launcher工程和完整PowerShell实现留在源码包中，成品包保留原相对结构。
- 每个ZIP写入后执行CRC及逐文件SHA读回；记录当前源码/产品快照，在本套完成及九套最终发布前重新对账。任何文件、清单或权限变化均停止整轮发布，避免源码与产物混用不同版本。
- 跳过 `.git`、依赖目录、构建/测试缓存、运行日志、备份和用户运行状态；源码保留Tests。仅对Launcher下的 `bin/obj` 排除编译缓存，不全局排除业务 `bin/`。不会跟随目录链接，树内安全相对链接以链接保存，绝对或逃出输入树的链接拒绝。
- 明确输入树内出现疑似私钥/账户会话文件时拒绝归档并只报告文件名，不打印内容。签名App必须完整复制，不静默删除包内签名资源；App中出现不允许的对象会停止交付。
- 先在输出根的唯一 `.GuiDeliverables-stage-*` 建立独立暂存。全部9套核验通过后再发布版本目录；失败/中断保留该暂存及 `packaging.log`，不覆盖已发布产物，不自动删除用户原文件。

打包成功只证明当前输入、回执和归档完整性；不代表所有目标系统、图形授权、字体、辅助技术或真实安装/卸载已验收。包内产品是否能独立复制与运行，还需各平台按其说明验证。

## 四、<span id="tests">隔离测试</span> <a href="#前言">🔼</a> <a href="#🔚">🔽</a>

运行[标准库测试入口](./Tests/PackageGuiDeliverablesTests.py/PackageGuiDeliverablesTests.py)：

```sh
python3 -B './Tests/PackageGuiDeliverablesTests.py/PackageGuiDeliverablesTests.py'
```

14组测试覆盖固定9套输入、ZIP可复现/读回、源码并发变化、缓存与产品过滤、路径穿越/链接、密钥名称拒绝、Mac收据/完整Payload/实际 MacOS 面板布局下包内路径到当前目录的映射/当前源已变但包未刷新的阻断、PE格式、输出边界，以及9套完整归档夹具与旧版本保全。测试使用临时的源/产物形状夹具，Mac签名调用仅在测试内替身；测试PE头不构成真实EXE，不进入正式产品。测试不构建/启动业务App，不安装系统工具。

<a id="🔚" href="#前言">我是有底线的➤点我回到首页</a>

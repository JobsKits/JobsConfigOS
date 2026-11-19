# Git 父／子仓管理

![Jobs出品，必属精品](https://picsum.photos/1500/400)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [🔥 前言](#%E5%89%8D%E8%A8%80)
- [一、打开面板](#launch)
- [二、三项操作](#operations)
  - [2.1、下载子模块](#jobs-toc-heading-4)
  - [2.2、对齐父子仓引用](#jobs-toc-heading-5)
  - [2.3、补齐 .gitmodules](#jobs-toc-heading-6)
- [三、预览、取消与恢复](#safety)
- [四、语言与主题](#appearance)
- [五、源码与目录](#source)
- [六、环境与源码运行](#environment)
- [七、构建与产物](#build)
- [八、JobsConfigOS 旧入口迁移](#differences)
- [九、验证](#validation)

</details>
<!-- jobs-toc:end -->

---

## 🔥 <span id="前言">前言</span>

用一个 [**Python**](https://www.python.org) GUI 集中管理父子嵌套 [**Git**](https://git-scm.com/) 仓库：下载子模块、对齐父仓引用、发现并补齐 `.gitmodules`。进入面板只扫描，写操作必须先预览、再确认；不自动提交或推送。缓存清理由现有双端系统扩展负责，本面板不再重复提供。

[**MacOS**](https://www.apple.com/macos/) 和 [**Windows**](https://www.microsoft.com/windows) 共用 [**PySide6**](https://doc.qt.io/qtforpython-6/) 源码，分别使用本平台构建入口。源代码、构建入口和当前产物随本目录对应交付；实际验证与待核范围见 [资产盘点](../项目相关报告/Git父子仓管理资产盘点.md)。

## 一、<span id="launch">打开面板</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

- MacOS：双击根目录 [【MacOS】🧩Git仓库管理.command](../【MacOS】🧩Git仓库管理.command)。
- Windows：双击根目录 [【Windows】🧩Git仓库管理.cmd](../【Windows】🧩Git仓库管理.cmd)。
- 入口是普通脚本，按自身位置解析本工程，再读取本目录的 `latest-macos.json` / `latest-windows.json` 定位 `dist/` 内的本平台成品，并传入工程路径。整仓搬迁后保留相对结构即可，不是 Finder 替身或写死机器位置的快捷方式。
- 直接打开独立 App 时，程序从运行位置寻找 Git 根；无法识别时使用“选择仓库”原生目录选择器。没有产物时先运行 [本平台构建入口](#build)，不冒用另一平台的包。

进入后可看到子仓路径、登记状态、分支、当前提交和工作区状态，路径提示展示远端地址。勾选目标后选择功能；选择变化会使旧计划失效，需要重新预览；刷新清空勾选，语言切换保留当前勾选。没有子仓时显示完整空态，并保留“重新扫描”和选择其他仓库入口。

## 二、<span id="operations">三项操作</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

### <span id="jobs-toc-heading-4" data-jobs-toc="v2">2.1、下载子模块 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

- 选择已登记子仓；默认勾选“递归处理后代子模块”和“跟随远端分支最新提交”。递归只沿各层 `.gitmodules`，不接管未登记的独立后代。
- 预览显示所选子仓、分支、来源与执行边界；确认后按各层显式 `branch`、继承分支或远端默认分支更新。只允许安全快进，遇本地源码改动、未跟踪文件、冲突或不能快进的提交停止，不强制舍弃内容。
- 取消“跟随远端分支最新提交”时，依据父仓 gitlink 固定提交下载；不会强制回退现有本地独有提交。该操作不拉取入口父仓，也不自动记录父仓指针。
- 已配置文档目录过滤器的仓库，在更新前后执行其自带工具 `restore` / `verify`；此时需健康的 [**Node.js**](https://nodejs.org)。未配置则跳过，不安装过滤器、不修改全局配置；已有过滤器缺工具或执行失败时停止并报告。

### <span id="jobs-toc-heading-5" data-jobs-toc="v2">2.2、对齐父子仓引用 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

- 选择已登记且已初始化的子仓，计划显示父仓旧 gitlink 到子仓当前 HEAD 的变化。
- 确认后仅精确更新所选 `160000` gitlink 的父仓索引，保留其它暂存文件。子仓的本地源码改动不会因此被提交。
- 不联网、不修改分支、不自动提交或推送。缺失的工作树、未登记路径或普通文件与 gitlink 冲突需先处理，不以修复名义移除旧登记。

### <span id="jobs-toc-heading-6" data-jobs-toc="v2">2.3、补齐 .gitmodules <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

- 扫描普通分类目录中的独立子仓，遇到真实子仓根就停止向内发现；普通分类目录中独立仓库仍能作为本层候选；本仓当前已有 8 个登记子仓。
- 选择未登记且已有提交、真实远端的独立子仓，预览将新增的 section、path、url、branch 与 gitlink。
- 确认后补充 `.gitmodules`、暂存必要 gitlink、初始化本地子模块配置；需要归集 `.git` 目录时使用 Git 官方 `submodule absorbgitdirs`。`.gitmodules` 留在工作区供审阅，不整文件自动暂存。
- 已有 section、URL、branch 和扩展字段保持原样；同站点同 namespace 的兄弟地址可相对化，无法证明映射时保留实际远端。不覆盖已有元数据目标，不自动修复归属不明的 `.git` 指针。

## 三、<span id="safety">预览、取消与恢复</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

执行按钮只有生成计划后才启用。确认窗口再次展示完整计划，默认取消；Esc、关闭弹窗或取消均不执行。执行前复核预览快照，配置、索引或目标状态发生变化时要求重新预览，避免将旧授权套用到新状态。

业务在工作线程执行，期间目标与操作控件锁定；可请求取消并等待 Git 子进程结束，进行中关闭窗口会提醒先取消，空闲关闭直接退出。取消、超时或失败只表示后续停止，已完成步骤不会自动撤销。结果与日志如实保留已完成路径，不以“取消”冒充回滚成功。

写入前在父仓实际 Git 目录的 `jobs-git-manager-backups/<本次编号>/` 保存 `.gitmodules`、父仓索引、本地配置及涉及子仓的配置与索引，`manifest.json` 给出原路径和摘要。目录与文件采用当前用户私有权限。恢复前先查看清单和当前差异，只还原已核对的本轮项，不能用旧索引覆盖后续暂存。

执行日志保存在 Qt 为当前用户解析的应用数据目录 `JobsGitManager/logs/`，从面板“日志目录”打开实际位置。远端凭据和查询参数脱敏，人类可读计划随界面语言翻译，Git 原始诊断与命令保留原文。手动滚动日志时保留浏览位置；回到底部后继续跟随新输出。

## 四、<span id="appearance">语言与主题</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

界面与窗口标题统一为“Git 父／子仓管理”，页内主标题左侧使用随应用打包的 Git 图标；“🌐 语言”和“🌓 主题”及其选择框在同一横行。仓库选择按钮显示“选择仓库”，不带省略号。原“进入面板只扫描”横幅已移除，操作计划与执行确认流程继续生效。图标来源与许可见 [SOURCES.txt](./JobsGitManager/src/jobs_git_manager/assets/SOURCES.txt)。

- 语言：简体中文、繁体中文、藏文、英文、日文、法文、西班牙文、德文、俄罗斯文、韩文；默认简体中文，切换立即刷新现有界面。
- 主题：白天、黑夜、跟随系统；默认跟随系统，监听系统外观变化，手动主题不被覆盖。
- 两项选择通过 `QSettings("Jobs", "JobsGitManager")` 保存到当前用户配置，在重启后恢复，不写入被管理仓库。
- 本轮的控件、字体与目标平台实际验证状态按 [资产盘点](../项目相关报告/Git父子仓管理资产盘点.md#validation) 记录；翻译目录齐全不代表每种语言都经过母语审校。

## 五、<span id="source">源码与目录</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

```text
Git仓库管理/
├── README.md
├── JobsGitManager/
│   ├── pyproject.toml
│   ├── src/jobs_git_manager/
│   │   ├── app.py              # 窗口、工作线程、计划确认、主题与偏好
│   │   ├── git_service.py      # 扫描、计划快照、Git安全执行与备份
│   │   ├── i18n.py             # 完整界面语言目录
│   │   ├── assets/             # 本地 Git 图标与来源许可
│   │   ├── entry.py            # PyInstaller入口
│   │   └── __main__.py         # python -m入口
│   ├── tests/                 # 隔离仓库回归
│   └── scripts/build.py/      # 跨平台构建器及说明
├── MacOS/                     # 本端相对路径启动辅助入口
├── WindowsOS/                 # 本端相对路径启动辅助入口
├── 【MacOS】📦生成dmg.command/ # 本端构建入口与说明
├── 【Windows】📦生成exe.bat/   # 本端构建入口与说明
├── dist/                      # MacOS/、WindowsOS/内按构建时间分组
├── latest-macos.json          # MacOS最新成功产物的相对路径
└── legacy/                    # 旧三脚本和说明的压缩快照
```

`latest-windows.json` 只有 Windows 真实产物构建成功后才生成，不创建指向不存在 EXE 的快捷入口。本目录由父仓管理，没有新建独立 Git 仓库或新增子模块。

## 六、<span id="environment">环境与源码运行</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

依赖版本由 [pyproject.toml](./JobsGitManager/pyproject.toml) 固定：Python `>=3.11,<3.15`、`PySide6-Essentials==6.12.0`，构建使用 `pyinstaller==6.22.3`。成品携带 Python、图形库与应用源码编译结果；操作仓库仍使用目标机器实际 Git，现有目录过滤器按上文另需 Node.js。

开发时在本目录准备独立虚拟环境并安装源码；已有健康环境直接复用。下面的安装命令会联网获取声明依赖：

```shell
python3.13 -m venv .venv
.venv/bin/python -m pip install -e './JobsGitManager[build]'
.venv/bin/python -m jobs_git_manager --repo ..
```

Windows 在本目录使用：

```powershell
py -3.13 -m venv .venv
.\.venv\Scripts\python.exe -m pip install -e './JobsGitManager[build]'
.\.venv\Scripts\python.exe -m jobs_git_manager --repo ..
```

源码的 `--repo` 是用户显式传入路径，示例的 `..` 指本目录的父仓；根快捷启动器会自动传入正确绝对路径。应用、资源与构建器均按自身位置定位，不把本机用户目录写入运行依赖。

## 七、<span id="build">构建与产物</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

- MacOS：双击 [【MacOS】📦生成dmg.command](./【MacOS】📦生成dmg.command/【MacOS】📦生成dmg.command)，生成本平台 `.app`、`.dmg` 和 `.zip`。
- Windows：双击 [【Windows】📦生成exe.bat](./【Windows】📦生成exe.bat/【Windows】📦生成exe.bat)，在 Windows 生成 `.exe` 及分发包；MacOS 不交叉伪造 Windows EXE。
- 构建前打印内置自述并确认，检查已有依赖；缺少必需依赖时先说明，再按回车安装／非空取消处理，不主动升级健康环境。
- 产物位于 `dist/<平台>/YYYY.MM.DD HH-mm-ss/`，成功验证后更新本平台 `latest-*.json` 和入口；失败不发布失效入口。构建只清理本工具当前平台旧输出和对应manifest，保留另一端产物；不清理仓库、用户数据或其它工具。
- 构建成功后打开产物所在目录并启动本次应用；源码运行和打开 DMG 不能代替启动 App。实际产物、系统架构、构建与启动证据见 [资产盘点](../项目相关报告/Git父子仓管理资产盘点.md#validation)。

本轮已重建 `1.0.1` MacOS ARM64，生成 `dist/MacOS/2026.11.18 10-36-55/`：

| 当前交付 | 实际文件／状态 |
| --- | --- |
| MacOS App | [JobsGitManager.app](<./dist/MacOS/2026.11.18 10-36-55/JobsGitManager.app>) |
| MacOS安装分发包 | [JobsGitManager.dmg](<./dist/MacOS/2026.11.18 10-36-55/JobsGitManager.dmg>)、[ZIP](<./dist/MacOS/2026.11.18 10-36-55/JobsGitManager-macOS-arm64.zip>) |
| 源码对应记录 | [build-info.json](<./dist/MacOS/2026.11.18 10-36-55/build-info.json>)：Python3.13.18、本次依赖版本、冻结启动`rows=8`及6模块SHA-256已核对 |
| Windows | 源码、启动器和本机打包入口齐备；尚未生成EXE，也未完成Windows桌面验收 |

本轮 `1.0.1` 冻结与根入口原生启动通过，均识别本仓当前8个子仓；6模块源码摘要和包内SVG对应，ad-hoc签名深度严格校验与本轮DMG CRC通过。本轮不带源码的中文空格路径复制启动亦通过；公证、真实AirDrop／跨机分发和其它系统架构未验，详见[当前证据](../项目相关报告/Git父子仓管理资产盘点.md#validation)。

## 八、<span id="differences">JobsConfigOS 旧入口迁移</span> <a href="#前言">🔼</a> <a href="#🔚">🔽</a>

本仓三份旧 Git 终端脚本已收口为当前面板，完整旧源码与原根 README 见 [归档](./legacy/README.md)。已有 8 个登记子仓、共享相对 URL、`🍎JobsCodeSnippets` 的跨平台异名固定地址、分支、远端与暂存内容保持现状；没有改动现有新系统配置、卸载器或安装面板。

新后端不自动提交／推送，不提供危险舍弃或缺失目录自动移除，不继承旧终端下载器的私有完成标记／缓存协议及强制 Gitee 协议重写。来源以实际 Git 配置为准，写前仍需明确计划确认。本仓没有重复清理入口需要移除，GUI 不新增缓存清理功能。

## 九、<span id="validation">验证</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

Git 后端回归仅使用临时本地父子仓，不联网、不写真实业务仓：

```shell
python3.13 -B -m unittest discover -s JobsGitManager/tests -p 'test_*.py' -v
```

本仓采用 JobsGenesis 已验证的共用 1.0.1 源码。此前 24 项 Git 后端、40 项计划翻译与 20 项旧长文案验证是源模板历史基线，不冒充本仓本轮重验；本轮核对共用源码摘要、资源、8子仓只读扫描、本机打包、根相对入口与搬迁寻址。实际结果和待核项见 [本仓资产盘点](../项目相关报告/Git父子仓管理资产盘点.md#validation)。真实远端下载、真实业务仓写入、Windows EXE 及实机运行未执行。

<a id="🔚" href="#前言">返回前言</a>

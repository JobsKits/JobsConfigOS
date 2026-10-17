# `macOS 新系统配置`

![Jobs出品，必属精品](https://picsum.photos/1500/400)

[toc]

---

## 🔥 <font id=前言>前言</font>

这个入口用于按需准备新 Mac 的开发环境。脚本先展示内置自述并等待回车，再逐个询问九个阶段：直接回车跳过，输入任意字符后回车执行。只选择自己需要的阶段即可。

| 阶段 | 主要行为 | 关键边界 |
| --- | --- | --- |
| 1、Command Line Tools | 检查 CLT；缺失时打开系统安装窗口 | CLT 安装尚未完成时报告失败，完整 Xcode 可用时才处理协议 |
| 2、Xcode 模拟器配件 | 下载 iOS 平台；可选删除 Xcode 与 CoreSimulator 缓存 | 缓存删除必须额外输入 `YES` |
| 3、oh-my-zsh | 缺失时执行官方安装器 | 已有目录保持原样，不启动新 Shell 或自动切换默认 Shell |
| 4、Homebrew | 安装或复用，执行健康体检，可选更新软件列表 | `doctor` 失败会阻止后续 Brew / CodeGraph 安装；不执行全量升级或清理 |
| 5、Homebrew 开发工具 | 补装脚本配置中的 formula / cask，配置 Git LFS | 使用前再次体检；会写入原有 Git 全局传输配置 |
| 6、CodeGraph 代码地图 CLI | 调用相邻仓库中的独立安装器 | 安装 CLI 与建立代码地图分开，不会隐式创建 `.codegraph/` 或修改 Codex 配置 |
| 7、npm / quicktype | 体检 Node.js / npm 后安装 quicktype | 沿用管理员授权的全局 npm 安装方式 |
| 8、gem / CocoaPods | 体检 RubyGems 后安装 CocoaPods | 沿用管理员授权的 gem 安装方式 |
| 9、Jobs 环境配置 | 准备 Jobs 软件仓，运行当前仓库的环境配置安装器 | 本地软件仓有未提交改动时保留原样，不执行 pull |

手动下载页面在九个阶段之后单独询问。所有阶段都可以跳过，失败阶段会列入最后的摘要，并使脚本返回非零退出码。

## 一、<span id="run">运行方式</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

在当前目录双击 `./【MacOS】🆕新系统配置.command`，或在终端执行：

```shell
zsh './【MacOS】🆕新系统配置.command'
```

目录结构为：

```text
【MacOS】🆕新系统配置.command/
├── 【MacOS】🆕新系统配置.command
└── README.md
```

脚本必须在支持交互输入的 macOS 终端中运行。按 `Ctrl+C` 取消；不支持通过管道输入一串答案来跳过人工确认。

## 二、<span id="brew">Homebrew 健康体检与安装</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

[**Homebrew**](https://brew.sh/) 按候选发现、命令验证、激活当前进程、健康诊断的顺序准备。兼容 Apple Silicon 的系统目录、Intel 的系统目录以及用户目录中的既有安装。不会把共享安装目录不可写误判为 Homebrew 未安装。

在执行后续 Brew 安装前，会检查 `brew --version`、真实 `brew --prefix`、`brew config` 和 `brew doctor`。诊断失败时停止该依赖链，并输出排查信息。已有安装只在主动确认后执行 `brew update`，不执行全量 `brew upgrade` 或 `brew cleanup`。

缺少可用 Homebrew 时，会单独询问安装路径：精确输入 `YES` 选择系统标准目录，其它输入或直接回车选择用户目录。系统安装器可能请求管理员密码；用户目录安装不使用 `sudo`。选定路径失败后停止，不自动换到另一路径。只有新安装才写入带边界标记、可重复运行的 shellenv 配置块，并立即激活当前进程。

## 三、<span id="codegraph">CodeGraph 安装与建图</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

[**CodeGraph**](https://github.com/colbymchenry/codegraph) 阶段调用以下本地安装器：

```text
../../JobsCommand@iOS/配置相关/
└── 【MacOS】⚙️安装代码地图CodeGraph.command/
    ├── 【MacOS】⚙️安装代码地图CodeGraph.command
    └── README.md
```

`JobsConfigOS` 与 `JobsCommand@iOS` 需要位于同一父目录。路径基于当前脚本位置计算，与启动时所在目录无关。文件缺失时明确报告目标路径，不会猜测远端地址或临时下载替代安装器。

独立安装器负责从基础工具到 [**Homebrew**](https://brew.sh/)、[**Node.js**](https://nodejs.org/)、[**npm**](https://www.npmjs.com/) 和 [**CodeGraph**](https://github.com/colbymchenry/codegraph) 的依赖体检、安装及复检；详细行为见[安装器 README](../../JobsCommand@iOS/配置相关/【MacOS】⚙️安装代码地图CodeGraph.command/README.md)。

需要建图时，使用已注册的 `codemap`：

```shell
# 对当前目录建图。
codemap

# 对手动输入或拖入的目录建图；路径包含空格时保留引号或终端生成的转义。
codemap '../目标项目'
```

代码地图保存在目标目录的 `.codegraph/` 中。新系统入口只负责调用 CLI 安装阶段；命令注册由[环境配置仓库](../🌍JobsMacEnvVarConfigs/README.md)维护。执行 Jobs 环境配置阶段会运行该仓库的安装入口；若仅需注册或更新终端命令，也可以单独运行它。

## 四、<span id="jobs">Jobs 配置与已有工作区</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

Jobs 阶段使用当前仓库内的 `../🌍JobsMacEnvVarConfigs/install.command/install.command`，不另外克隆旧名称的环境配置仓库。该入口不存在时提示先准备子模块。

软件仓库仍准备在当前用户桌面的 `JobsKits` 工作目录下：缺失时克隆 [**JobsSoftware.MacOS**](https://github.com/JobsKits/JobsSoftware.MacOS)，干净工作区只执行快进更新；已有未提交改动时保留并跳过更新。目标已存在但不是有效仓库时报告错误，不覆盖。

## 五、<span id="logs">日志与排查</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

入口日志位于系统临时目录，文件名为 `【MacOS】🆕新系统配置.log`；运行时会显示实际位置，每次确认运行后重新初始化。业务命令的输出和阶段结果同步记录，非彩色终端自动使用纯文本。

CodeGraph 和 Jobs 环境配置安装器直接使用当前终端，保留它们自身的交互与独立日志；父入口记录调用目标及返回结果，子步骤详情查看各自提示的日志。

| 情况 | 处理方式 |
| --- | --- |
| 没有可交互输入 | 在终端中直接运行，不使用管道输入答案 |
| CLT 安装窗口已经弹出 | 先完成系统安装，再重跑需要 CLT 的阶段 |
| Homebrew 体检失败 | 查看 `doctor` 输出，修复后重新运行；失败期间不会继续 Brew / CodeGraph 安装 |
| CodeGraph 安装器缺失 | 按相邻仓库布局准备 `JobsCommand@iOS`，核对终端显示的完整路径 |
| Jobs 环境配置入口缺失 | 准备当前 `JobsConfigOS` 的 `🌍JobsMacEnvVarConfigs` 子模块 |
| 已有软件仓存在本地改动 | 脚本保留工作区；自行处理改动后按需重新运行 Jobs 阶段 |
| 最后摘要包含失败项 | 查看对应命令输出与日志，处理后仅选择失败的阶段重试 |

## 六、<span id="validation">验证与影响范围</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

该入口会根据阶段选择安装软件、下载平台组件、修改用户终端配置和 Git 全局参数。删除缓存另需 `YES`；未选中的阶段不会执行。脚本不创建提交或推送。

脚本经过 `zsh -n` 静态检查，并以隔离假命令检查 Homebrew 健康与失败门禁、CodeGraph 子安装器调用和失败传播。未通过验证流程真实安装软件、接受系统协议、删除缓存或修改用户工具链。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>

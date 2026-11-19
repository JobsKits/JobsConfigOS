# 新系统配置组件后端

![Jobs出品，必属精品](https://picsum.photos/1500/400)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [🔥 前言](#%E5%89%8D%E8%A8%80)
- [一、组件与边界](#components)
- [二、调用协议](#protocol)
- [三、REA 默认工具](#rea)
- [四、必要依赖自愈与网络获取](#healing)
- [五、清单、备份与重试](#state)
- [六、验证](#validation)

</details>
<!-- jobs-toc:end -->

---

## 🔥 <span id="前言">前言</span>

这个 [**zsh**](https://zsh.sourceforge.io/) 入口为图形管理面板和[终端反安装入口](../../【MacOS】↩️卸载新系统配置.command/README.md)提供同一套组件清单、计划、受管安装与卸载。普通使用打开 MacOS 目录的[管理 App](../../【MacOS】🧰新系统配置管理.app)，源码与构建入口见[安装面板说明](../../安装面板/README.md)；这个入口适合明确传参的自动化调用。

## 一、<span id="components">组件与边界</span>

基础清单有 42 项：4 项基础环境、24 项 [**Homebrew**](https://brew.sh/) formula、7 项 cask、Git LFS 配置、CodeGraph、quicktype、CocoaPods、REA、Jobs 环境配置和 Jobs 软件仓。python 与 python3 指向同一 formula，面板合为一项；go-task/tap/go-task 使用稳定 ID brew.go-task。所选任务自动新装的依赖会以 dependency.公式名 动态加入清单，因而实际总数可以增加；这些依赖支持从面板单独选择反安装。

| 类型 | 安装行为 | 反安装行为 |
| --- | --- | --- |
| CLT | 验证 xcode-select 与实际 clang；缺失时请求一次系统安装器，持续可取消复检，完成后自动续行 | 共享系统开发工具不由脚本删除；缺少收据时保留并返回未完成 |
| iOS 平台 | 选定完整 Xcode 后调用真实平台下载，并检查可用 iOS runtime | 共享模拟器平台保留，不删除用户设备或运行时 |
| Homebrew | 有健康安装直接复用；缺失时须明确选择用户目录，系统目录使用原终端入口 | 仅本工具新建、无 formula/cask、无进程引用且完整指纹不变的用户前缀可以撤回 |
| formula / cask | 体检 Homebrew 后补装缺项，记录前后包清单、具体版本和安装内容摘要 | 只卸载本工具新装且未变的所选包；formula 有其它已安装消费者时保留；不执行 autoremove |
| oh-my-zsh | 官方安装器，保持现有 .zshrc 和登录 Shell | 只撤回有本工具收据、完整内容未变的框架目录 |
| Git LFS / Git 参数 | 先备份原 .gitconfig，再初始化 LFS 与原有传输参数 | 当前配置完全匹配本次写入时恢复原副本；用户后续改动则保留并报未完成 |
| REA / quicktype / CodeGraph | 官方 npm 包，分别使用用户独立前缀，严格校验发布包 engines | 核对独立目录的文件、链接、空目录与模式摘要后撤回；精确移除本工具 PATH 块 |
| CocoaPods | 独立 GEM_HOME 与自包含 pod 包装，不修改系统 Ruby | 同上；原有 CocoaPods 不自动接管 |
| Jobs 环境配置 | 调用相邻环境配置后端的 all 组件 | 由该后端按自己的清单与备份执行；失败状态向上透传 |
| Jobs 软件仓 | 只克隆缺失目录，已有目录不覆盖、不拉取 | 仅本工具新建、提交与完整内容均未变且工作区干净时撤回 |

基础工具和共享依赖的保留项会明确报告，不会将保留旧环境显示为“全部卸载成功”。既有 CLI、框架或软件仓目标不能只凭存在就宣称可复用；安装写流程沿任务必需依赖链自动发现、检测、定向补齐或修复、刷新当前环境并真实复检。人工修改的受管前缀、归属不明的非健康目录、框架入口语法失败和无效 Git 仓库均保留并报冲突。原终端安装器的前九阶段保持原行为；旧安装没有本工具的收据，不能凭当前目录存在就推定归属。

## 二、<span id="protocol">调用协议</span>

在本目录运行，只读盘点输出 ID、显示名、说明、yes/no/unknown，共四列 TSV，无表头：

    zsh ./【MacOS】环境管理后端.command --catalog

只预览，绝不创建收据、日志或安装目录：

    zsh ./【MacOS】环境管理后端.command --install rea quicktype --dry-run

明确安装并授权沿所选任务依赖链自动补齐、修复和复检：

    zsh ./【MacOS】环境管理后端.command --install rea quicktype --yes

确实缺 Homebrew 时，即使它由 REA 等任务间接需要，也必须明确选择安装位置：

    zsh ./【MacOS】环境管理后端.command --install homebrew --brew-location user --yes

    zsh ./【MacOS】环境管理后端.command --install rea --brew-location user --yes

反安装指定组件：

    zsh ./【MacOS】环境管理后端.command --uninstall rea quicktype --yes

组件选择只接受清单内 ID；空选、未知参数、输入结束、未传 --yes 均不写入。安装按清单依赖顺序执行，反安装逆序执行。单项失败后继续其它明确选择的组件，批次最终返回 1；参数错误返回 2。后端不等待终端输入，也不自动请求 sudo；管理员权限、系统协议和必须的图形确认交给原终端或系统界面准备。

每项开始和结束输出 JOBS_MANAGER_EVENT、组件 ID、running/success/failed/skipped、消息，共四列 TSV。--catalog 不输出事件；计划事件使用 planned 消息，不能据此写成已安装。嵌套 Jobs 环境后端的事件也会出现在日志中，面板只按本轮所选顶级 ID 统计。

GUI 协作停止使用 --stop-request-file 后跟本轮私有会话中的绝对路径，初始文件必须不存在；用户请求停止时由 GUI 原子创建普通文件。后端在获取前、退避每秒及组件边界检查；在途包管理器不强杀，当前安全单元成功仍保留成功结果，之后所选项标为 skipped。停止后输出独立行 JOBS_MANAGER_STOPPED 并返回 130。纯查询、计划和卸载不执行自愈，也不消费此安装停止协议。

## 三、<span id="rea">REA 默认工具</span>

[**REA**](https://github.com/morluto/rea) 安装的是官方 [**rea-agents**](https://www.npmjs.com/package/rea-agents) 包；无需拉源码编译。独立 npm 前缀避免覆盖已有全局安装，也不使用管理员权限。首次安装及既有组件复用前实际执行 Node.js 与 npm，并真实运行工具 --version；受管包及可识别的官方全局包还校验已安装版本声明的 engines，避免仅版本命令可运行却不满足支持范围；Node 动态库缺失、npm 损坏或版本不匹配时按下一节自动修复，安装时继续通过 --engine-strict 校验当前发布包。

成功后新终端可以运行 rea --version。连接客户端时再按官方流程运行 rea setup。客户端 MCP、配套 Skill、Hopper / Ghidra / IDA 等分析引擎都属于另一次明确选择，不在默认包安装中自动写入。

## 四、<span id="healing">必要依赖自愈与网络获取</span>

Node/npm 先发现当前 PATH 与已安装 Brew 提供者，并真实执行最小检查。dyld 报缺库时，以已安装提供者的真实 dylib 和只读 otool 结果区分库本身损坏与 consumer 仍引用旧 ABI；健康库配旧 Node 时定向重装 Node，不伪造旧库文件名软链接。运行时缺失或版本不合时读取 Node.js 官方当前 LTS 目录；健康但版本不合的共享 Node 保留，改选兼容版本化 LTS，再核对独立 provider 的 canonical name/keg_only，并用 npm 自带 semver 校验发布包 engines（严格归一npm返回的字符串、单元素数组或明确字段对象；多条、未知形态和非法range直接报错）；不硬编码过期兼容表，不使用 --force 跳过要求。

CLT/Git 缺失时只请求一次系统安装器，并持续可取消地检查实际 clang 和 Git；用户完成后自动续行，不把弹出窗口当作完成，不自动接受系统协议。已有健康运行时直接复用；本轮对同一确定的本地修复最多执行一次并立即复检，不无限递归。同一提供者正被其它 Homebrew 事务占用时，在决定 install/reinstall 和归属快照之前等待、重新发现并复检，可随时取消，不抢删锁、不结束未知归属进程；外部事务已恢复健康则直接续行、不重复本线程修复，也不认领其安装对象。已有共享提供者记录实际修复及 npm/npx 链接前后状态，不认领全局 npm 或运行时的卸载归属。Node修复前仅对原regular全局npm模块做私有字节备份；若Brew替换了该目录，当前必须与本次provider捆绑npm树逐字节相同或明确symlink同源，且原包在新Node上健康、当前对象未并发变化，才恢复原npm版本；无法证明归属则保留当前对象与恢复副本并报冲突。其它全局模块不处理。Homebrew 修复改变 npm/npx 链接时，仅在原入口仍能真实执行、当前链接仍等于本次结果时保留原语义；存在并发修改时停止并保全记录。doctor 的无关警告不会触发全机升级、trust、untap 或批量修复。

CocoaPods 仅根据本轮失败诊断处理缺失或损坏的 Ruby/RubyGems、Git 配置任务缺失的 git-lfs 按同一机制补齐；健康但版本不兼容的共享 Ruby 保留，从官方 Brew versioned_formulae 选候选，并核对 canonical name、keg_only 和本轮 Gem 版本要求，拒绝把默认 Ruby 的 aliases 当成独立 provider；不存在兼容独立版本时保留共享运行时并明确阻断。直接选择 node/ruby/git-lfs 叶子时检查该 formula 的稳定前缀，不以其它健康提供者掩盖所选对象。健康的原全局工具保留；仍不健康的原全局 npm CLI/CocoaPods 不删除，改用独立用户前缀提供可用安装。受管且完整指纹未变的 npm 包与 CocoaPods 可以在独立暂存安装、验证后发布，原前缀移到恢复副本；人工修改的前缀不强删。

npm CLI 自带轻量包装，只为该工具子进程前置选定 runtime/bin，再执行原 npm 入口；即使新登录环境仍保留旧默认 Node，工具也使用已验证的兼容运行时，不为 REA 改全局 Node 版本。新依赖有独立收据及 consumer 关联，仍供其它受管组件或 Brew 包使用时拒绝卸载。卸载组件解除关联后，依赖继续显示在清单，用户可明确选择撤回。

只有明确的网络超时、断流、临时 DNS 或可恢复服务器错误才持续退避重试，可主动取消；下载输出实时转发 GUI 并追加私有日志，JSON 元数据另存保持可解析。权限、磁盘、认证、完整性、架构、ABI 和无法识别的确定错误立即非零，日志说明原因；不会重复已经成功的其它业务单元。Homebrew bootstrap 在新暂存中只初始化仓库一次，对 fetch 获取重试，完整取得后才 checkout 和发布。

## 五、<span id="state">清单、备份与重试</span>

状态、备份与每轮私有日志位于当前用户 Application Support 下的 JobsSystemSetup。receipts 保存纯数据 TSV，不执行其中的文本；backups 保存必要配置副本与 Brew 包清单；logs/session.* 是独立、权限为 600 的运行日志。后端会显示本轮实际路径。

运行中持有 transaction.lock；并发任务直接失败。只允许主 Shell 核对本轮 PID 与 UUID 后释放自己的锁，命令替换等子 Shell 不清父事务锁。正常退出及可捕获信号会释放锁；强制终止或断电可能保留锁，确认没有活跃安装任务后再移走该锁目录，不能删除收据与备份来“解锁”。包管理器本身也有锁，两者不能相互代替。

未完成的 npm 安装及验证失败会留下内容摘要，后续可选择反安装回收未被改动的独立前缀。没有完整摘要的中断、内容变化、缺失备份、仍有共享消费者等情况会保留并报出未完成项。卸载保留日志和恢复副本；不清理整个用户缓存或其它项目目录。

## 六、<span id="validation">验证</span>

见 [Tests](./Tests/README.md)。45 组安装与自愈回归，加 1 组摘要批量兼容专项用例使用临时 HOME 和假 Node/npm/brew/ruby/git-lfs/网络命令，验证自愈、安装与反安装、原配置逐字节恢复、后续改动保留、失败清理、共享依赖、路径迁移、锁、符号链接和事件传播，不操作本机真实包管理器。测试中的系统固定 Node 候选被隔离，otool 由假工具替代，避免泄漏到开发机环境。

目录摘要批量调用系统shasum/stat，保持原排序与摘要语义；真实文件夹具核对旧新排序后的原始输出逐字节一致，并验证中文空格、换行、反斜杠、空目录、符号链接及模式变化。安装与自愈45组已完整回归，摘要两行优化使用独立兼容验证，不将专项结果冒充整套再次运行。

真实下载、管理员授权、跨机 App 启动与完整新系统环境验收分别记录；通过隔离测试不代表这些真实安装已执行。

<a id="🔚" href="#前言">回到前言</a>

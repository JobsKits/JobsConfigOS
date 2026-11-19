# 后端生命周期隔离测试

![Jobs出品，必属精品](https://picsum.photos/1500/400)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [🔥 前言](#%E5%89%8D%E8%A8%80)
- [一、运行与覆盖](#jobs-toc-heading-2)

</details>
<!-- jobs-toc:end -->

---

## 🔥 <span id="前言">前言</span>

测试需要本机已有 fzf，交互用例使用真实 PTY 与选择器，但业务后端是假实现。其它逻辑只使用本机已有 [**Python**](https://www.python.org/) 标准库、macOS 原生工具和临时假命令。--yes 只授权临时夹具，不授权任何真实软件安装或卸载。

## <span id="jobs-toc-heading-2" data-jobs-toc="v2">一、运行与覆盖</span><!-- jobs-toc:heading-end -->

    python3 ./lifecycle_tests.py --yes

46 组安装与自愈场景覆盖（按测试注册列表计数，核验日期：2026-11-17）：四列只读清单与空选拒绝、REA 安装与反安装、无末尾换行配置精确恢复、原配置缺失恢复、用户增量保留、包内容与 PATH 块修改保护、npm 失败与可执行性失败后的撤回、已有全局安装保留、Brew 共享消费者保护与真实假包删除、Brew 内容变化、锁及符号链接拒绝、每轮私有日志、受管空 Homebrew 前缀撤回与新增文件保留、Jobs 环境后端 all 调用和退出码传播；真实 PTY 与 fzf 下左键返回后执行、默认取消及空选取消；受管 CLI 的运行时损坏、已有全局 CLI 损坏、无收据前缀缺少健康 CLI、已有 CocoaPods/oh-my-zsh/软件仓不完整时拒绝成功且保留原内容。

测试会把后端复制到中文与空格路径并从工程外运行。终端卸载用例保留完整的 `MacOS/` 安装／卸载同级布局，在改名后的多平台目录内执行真实入口，并由临时假后端验证定位、选择和取消。Homebrew 空前缀用例提供安装后收据夹具，只验证卸载归属与内容门禁，不执行 Homebrew 下载。所有测试包管理命令均是假实现；源码实现、隔离逻辑通过与真实下载成功是三个不同结论。

自愈夹具另覆盖旧 consumer ABI 只修 Node、缺 npm、发布包 engines 不符、新运行时动态清单与 consumer 保护、网络故障后恢复与信号取消、GUI 停止文件、确定权限错误不重试、健康重复零包变更、只读与卸载不修复、命令替换期间真并发锁持续有效、新登录旧 Node 下组件包装仍用兼容运行时、Ruby/gem 与 git-lfs 自动补齐。所有新增网络及包管理器入口均被假命令拦截。

附加回归覆盖：CLT安装器仅请求一次、用户完成后自动继续；历史Ruby错误日志不影响本轮EACCES确定错误判断。固定系统Xcode工具在测试中也被假命令隔离。

最后的目标提供者回归包含：直接勾选坏Node叶子真实修复、健康但不兼容共享Ruby改用版本化provider、同provider外部事务结束后复检续行而不重复安装或认领。夹具显式剥离所有hostbrew/Node固定回退路径，使用最小环境，并拒绝真实Git网络操作。

另覆盖原全局npm包被provider捆绑版本覆盖后逐字节恢复、来源无法证明的并发npm版本不覆盖、Ruby/Node aliases不冒充独立provider，以及已有受管包版本命令可运行但installed engines不满足时自动修复。

真实Node/npm自带semver的纯本地形态验证可单独运行：

    python3 ./lifecycle_tests.py --yes --case real_node_npm_semver_shapes

该组实际执行同一生产check_package_engine函数，覆盖12个字符串、npm12单元素数组、明确对象字段、无效/多条形态和版本边界；仅载入npm自带semver，不执行npm命令、不联网、不安装。

目录摘要批量兼容另有1组真实文件专项，可单独运行：

    python3 ./lifecycle_tests.py --yes --case tree_digest_batch_compatible

该组对旧逐文件与新批量shasum/stat输出和digest做兼容核对，包含中文空格、换行、反斜杠、空目录、正常与断符号链、内容和权限变化；不执行业务安装。现场保存两份排序后的原始manifest及兼容结果JSON。

<a id="🔚" href="#前言">回到前言</a>

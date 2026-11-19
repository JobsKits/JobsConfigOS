# 终端反安装新系统配置

![Jobs出品，必属精品](https://picsum.photos/1500/400)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [🔥 前言](#%E5%89%8D%E8%A8%80)
- [一、运行与操作](#jobs-toc-heading-2)
- [二、影响、日志与恢复](#jobs-toc-heading-3)
- [三、目录与验证](#jobs-toc-heading-4)

</details>
<!-- jobs-toc:end -->

---

## 🔥 <span id="前言">前言</span>

这个入口保留终端工作方式，为[新系统配置](../【MacOS】🆕新系统配置.command/README.md)补充可多选的反安装流程。普通用户也可以从上一层 MacOS 目录的[新系统管理 App](../【MacOS】🧰新系统配置管理.app)中选择安装或卸载；源码与构建入口见[安装面板说明](../安装面板/README.md)。

## <span id="jobs-toc-heading-2" data-jobs-toc="v2">一、运行与操作</span><!-- jobs-toc:heading-end -->

在当前目录双击主脚本，或：

    zsh './【MacOS】↩️卸载新系统配置.command'

先展示内置自述，回车只表示了解用途；需要可交互终端和健康 [**fzf**](https://github.com/junegunn/fzf)。缺少 fzf 时停止，使用原安装入口准备或改用图形面板，不自动改为数字输入。

组件层用上下键或 Tab 移动、回车勾选或取消、空格确认。提供取消、全选和清空操作行；空选、Esc、输入结束或选择器失败不会执行。确认层先显示计划，默认选取消；选择明确的反安装项后用空格授权，左方向键回到组件层重新选择。

## <span id="jobs-toc-heading-3" data-jobs-toc="v2">二、影响、日志与恢复</span><!-- jobs-toc:heading-end -->

调用[新系统组件后端](../【MacOS】🆕新系统配置.command/【MacOS】环境管理后端.command/README.md)执行同一套清单检查。只撤回可证明属于本工具、未被后续修改且没有共享引用的组件；旧终端安装没有收据时保留并报出未完成，不猜测安装归属。系统 CLT 与 iOS 平台不会整片删除，Brew 自动依赖保留，不运行 autoremove。

独立运行时使用现行终端临时配色保护，退出后恢复进入前状态；无法可靠保存与恢复时沿用纯文本，不修改终端全局偏好。后端执行后显示本轮私有日志位置；清单、恢复副本和历史日志位于当前用户 Application Support 下的 JobsSystemSetup。存在保留项或失败时返回非零，不能把它视为全部卸载完成。

## <span id="jobs-toc-heading-4" data-jobs-toc="v2">三、目录与验证</span><!-- jobs-toc:heading-end -->

该脚本依赖同一 MacOS 目录内完整的新系统安装包，不能单独只复制一个 .command 文件。路径由脚本自身定位，不依赖启动目录。

脚本经过 zsh -n 检查；安装与反安装逻辑由[隔离生命周期测试](../【MacOS】🆕新系统配置.command/【MacOS】环境管理后端.command/Tests/README.md)覆盖。真实系统工具删除与真实用户环境卸载不属于测试行为。

<a id="🔚" href="#前言">回到前言</a>

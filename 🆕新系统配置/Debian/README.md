# Debian 新系统配置

![Jobs出品，必属精品](https://picsum.photos/1500/400)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [🔥 前言](#%E5%89%8D%E8%A8%80)
- [一、运行方式](#usage)
- [二、组件与平台适配](#components)
- [三、收据、卸载与日志](#lifecycle)
- [四、核验与官方依据](#verification)

</details>
<!-- jobs-toc:end -->

---

## 🔥 <span id="前言">前言</span>

本目录提供 [**Debian**](https://www.debian.org/) 原生 Shell 开发环境配置，默认只读预览。**最低支持系统版本尚未完成原生验证并锁定**；目标为仍受维护的对应发行版 x64/ARM64，具备系统 `sh`、健康的 `apt-get / dpkg` 和可用软件源。MacOS 上隔离测试不代表目标系统已验收。

入口：[【Debian】🆕新系统配置.sh](./【Debian】🆕新系统配置.sh/【Debian】🆕新系统配置.sh)；[脚本详细说明](./【Debian】🆕新系统配置.sh/README.md)；[平台总览](../README.md)。

专用卸载入口：[【Debian】↩️卸载新系统配置.sh](./【Debian】↩️卸载新系统配置.sh/【Debian】↩️卸载新系统配置.sh)；[卸载参数与边界](./【Debian】↩️卸载新系统配置.sh/README.md)。无参只显示帮助，明确组件后转交既有收据卸载，不默认全选。


图形管理入口：[【Debian】🧰新系统配置管理.sh](./【Debian】🧰新系统配置管理.sh/README.md)。提供默认空选的组件管理、计划与后台日志、十语三主题；需要 Tcl/Tk 8.6+ 和桌面显示，无桌面时继续使用下方 CLI。

## 一、<span id="usage">运行方式</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

在本目录执行；复制完整平台目录后可从任意工作目录调用，专用卸载入口需保留同平台配置脚本包：

```sh
sh './【Debian】🆕新系统配置.sh/【Debian】🆕新系统配置.sh' --list
sh './【Debian】🆕新系统配置.sh/【Debian】🆕新系统配置.sh' --plan --components git,curl
sudo sh './【Debian】🆕新系统配置.sh/【Debian】🆕新系统配置.sh' --install --components git,curl --yes
sudo sh './【Debian】↩️卸载新系统配置.sh/【Debian】↩️卸载新系统配置.sh' --components git,curl --yes
```

省略动作等同 `--plan`；预览未指定组件时展示全部9项，不形成安装选择。写操作必须显式 `--components`。省略 `--yes` 时先看自述和计划，再用健康的 [**fzf**](https://github.com/junegunn/fzf) 确认，默认取消；无 fzf 的新机器可审阅计划后明确 `--yes`。取消、EOF、无交互未授权和选择器失败均不执行包写入。

## 二、<span id="components">组件与平台适配</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

> 9项稳定ID；安装使用本机软件源候选版本，健康环境复用。

| ID | 系统直接包 |
| --- | --- |
| `git` | `git` |
| `git-lfs` | `git-lfs` |
| `curl` | `curl` |
| `wget` | `wget` |
| `zsh` | `zsh` |
| `fzf` | `fzf` |
| `build` | `build-essential pkg-config` |
| `python` | `python3 python3-venv python3-pip` |
| `node` | `nodejs npm` |

目标包以当前发行版已配置软件源实际可用性为准，不跨版本混装或自动启用第三方源。

第一次确需安装/修复时更新一次 apt 索引；只读预览不更新。已授权安装按“实际运行检查 → 补缺/定向重装 → 刷新命令缓存 → 复检”执行，失败停止后续组件。`--repair` 为兼容参数，所选不健康组件会自动尝试修复。修复不为原有包新增卸载归属；共享依赖由系统包管理器解算，不能承诺系统字节不变。

## 三、<span id="lifecycle">收据、卸载与日志</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

写操作要求用户明确以 root/sudo 运行，脚本不自行提权。状态在 `/var/lib/jobs-new-system/Debian`：`receipts/` 保存版本归属，`logs/run.*` 保存独立纯文本日志，`operation.lock/` 防本工具并行写入。日志实时展示包管理器进度并保留真实退出码。只读操作不创建这些目录、锁或收据。

本轮开始前记录所选直接包原先缺失状态；顺带被同轮其它目标安装的已选直接包也记录版本，普通传递依赖不取得归属。失败/中断保留 pending 收据；仍未安装的 pending 包可明确重试，未知已装状态不自动认领。断电/SIGKILL 可能遗留锁，先核对原进程与日志，再由管理员处理，不自动抢锁。

卸载按直接包逆序，仅处理“本工具新装、收据完整、包版本匹配”对象。**版本匹配不代表包内文件完全未改**；原生配置和包脚本语义仍生效，并非文件快照恢复。无收据、版本变化、依赖阻断或未知事务保留并返回非零。使用 `dpkg --remove` 精确删除直接包，反向依赖阻断时保留；不执行 apt autoremove，不清除已有配置。共享依赖可能保留，不宣称恢复整个操作系统；不得与其它系统包写入任务并行。

本包负责基础工具，不配置默认 Shell、Git 身份、凭据、系统服务、桌面App、代理、防火墙或外部项目业务。与 MacOS 完整安装器覆盖范围不同，不代表全部功能已经对齐。

## 四、<span id="verification">核验与官方依据</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

已执行系统 `sh -n` 与六平台假系统/包数据库隔离回归，覆盖默认预览、防误触、安装重复/失败、版本与归属保护、共享依赖、互斥及顺带直接包收据。未安装本机软件，未在 Debian 原生系统运行；软件仓可用性、权限、真实修复/卸载和终端配色待验。完整测试见[Unix隔离测试](../Ubuntu/Tests/UnixLifecycleTests.mjs/README.md)。

包名和行为参考[官方包/管理资料](https://packages.debian.org/stable/git-lfs)、[官方管理手册](https://manpages.debian.org/stable/apt/apt-get.8.en.html)（2026-11-17查阅），本机实际候选包为最终依据。Linux 仅读取 /etc/os-release 的 ID=debian，不执行文件内容。入口内嵌现行POSIX终端保护，未知/不支持终端及 NO_COLOR 使用纯文本，不修改共享终端Profile；真实目标终端未验。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>

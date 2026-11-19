# AlibabaCloudLinux 卸载新系统配置

![Jobs出品，必属精品](https://picsum.photos/1500/400)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [🔥 前言](#%E5%89%8D%E8%A8%80)
- [一、运行与参数](#usage)
- [二、卸载范围与日志](#lifecycle)
- [三、验证边界](#verification)

</details>
<!-- jobs-toc:end -->

---

## 🔥 <span id="前言">前言</span>

[专用卸载入口](./【AlibabaCloudLinux】↩️卸载新系统配置.sh)只转交同平台配置脚本的 `--uninstall`；无参数只显示帮助。复制时保留完整的 `AlibabaCloudLinux/` 目录，入口按自身位置找后端，不依赖启动工作目录。[平台说明](../README.md)；[配置后端与收据规则](../【AlibabaCloudLinux】🆕新系统配置.sh/README.md)。

## 一、<span id="usage">运行与参数</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

在本目录执行：

```sh
sh './【AlibabaCloudLinux】↩️卸载新系统配置.sh' --help
sh './【AlibabaCloudLinux】↩️卸载新系统配置.sh' --list
sudo sh './【AlibabaCloudLinux】↩️卸载新系统配置.sh' --components git,curl --yes
```

`--components git,curl` 或 `--components=git,curl` 显式指定组件；可用ID由 `--list` 查询。不传 `--yes` 时由后端先要求终端回车、再展示计划并用健康的 [**fzf**](https://github.com/junegunn/fzf) 确认，默认取消。无终端或无 fzf 时不自动执行；已审阅范围的自动化调用才使用 `--yes`。仅传 `--yes` 仍因缺少组件而失败，不默认全选。

`--help` 和 `--list` 必须单独使用。拒绝 `--install`、`--plan`、`--uninstall`、`--repair` 和未知参数，不能通过追加动作切换用途。需要只读健康预览时使用平台配置脚本的 `--plan --components git,curl`；该预览不证明卸载收据已符合条件。

## 二、<span id="lifecycle">卸载范围与日志</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

卸载由既有后端实施：要求 root/sudo，校验目标系统、组件、互斥锁及完整收据，只处理本工具新装且当前版本仍匹配的直接包。原有、无收据、版本变化、依赖受影响和无法确认归属的对象保留并返回非零；不清理全部环境，不新增自动移除依赖行为。

状态、独立纯文本日志、失败/中断恢复及终端配色保护均复用后端。实际位置见[平台生命周期说明](../README.md#lifecycle)；快捷入口不另建状态、不自行提权、不改系统服务或代理。后端非零退出码原样传递；非法参数返回 `2`，配套后端缺失返回 `1`。

## 三、<span id="verification">验证边界</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

已执行系统 `sh -n`、复制到中文/空格路径并从其它工作目录运行的隔离验证，覆盖动作覆盖拒绝、参数完整性、后端缺失及退出码；收据卸载使用假系统和假包数据库验证。未卸载本机软件，未在 AlibabaCloudLinux 原生系统执行。测试与原生限制见[Unix隔离测试](../../Ubuntu/Tests/UnixLifecycleTests.mjs/README.md)。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>


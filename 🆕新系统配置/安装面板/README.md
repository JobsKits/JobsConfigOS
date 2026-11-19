# Unix 新系统配置管理面板

![Jobs出品，必属精品](https://picsum.photos/1500/400)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [🔥 前言](#%E5%89%8D%E8%A8%80)
- [一、平台入口](#entries)
- [二、源码与实际边界](#implementation)
- [三、验证](#verification)

</details>
<!-- jobs-toc:end -->

---

## 🔥 <span id="前言">前言</span>

六个平台的共享 [**Tcl/Tk**](https://www.tcl-lang.org/) 管理器；[MacOS](../MacOS/安装面板/README.md) 与 WindowsOS 使用各自原生 GUI。界面直接调用各平台现有脚本，目录来自当前 `--list`，不复制安装/卸载实现或生成假组件状态。

## 一、<span id="entries">平台入口</span> <a href="#前言">🔼</a> <a href="#🔚">🔽</a>

| 平台 | GUI 入口与说明 |
| --- | --- |
| Ubuntu | [管理器](../Ubuntu/【Ubuntu】🧰新系统配置管理.sh/README.md) |
| Debian | [管理器](../Debian/【Debian】🧰新系统配置管理.sh/README.md) |
| RockyLinux | [管理器](../RockyLinux/【RockyLinux】🧰新系统配置管理.sh/README.md) |
| Alpine | [管理器](../Alpine/【Alpine】🧰新系统配置管理.sh/README.md) |
| AlibabaCloudLinux | [管理器](../AlibabaCloudLinux/【AlibabaCloudLinux】🧰新系统配置管理.sh/README.md) |
| FreeBSD | [管理器](../FreeBSD/【FreeBSD】🧰新系统配置管理.sh/README.md) |

每个平台从自身包定位共享资源与当前 CLI；必须保留完整多平台目录。各入口说明包含依赖提示、授权、偏好和日志路径。系统包写入只发生在成功预览当前计划且点击主操作后；普通启动只读取目录。无桌面的服务器保留 CLI。

## 二、<span id="implementation">源码与实际边界</span> <a href="#前言">🔼</a> <a href="#🔚">🔽</a>

- [界面](./UnixManager.tcl/UnixManager.tcl)使用 Tcl/Tk 8.6+ 的原生复选框、按钮、下拉框与日志控件；空态重载、键盘操作、可拖分隔、三主题与十语齐备。
- [模型](./UnixManager.tcl/ManagerCore.tcl)校验两列清单、稳定 ID、非空写计划，用参数列表执行后端，不对日志执行 Shell 求值。用户偏好和翻译只按 dict 数据解析，不 `source` 用户数据。
- [内部执行器](./UnixManager.tcl/RunBackend.sh/README.md)等待后端真实退出，将结果写入私有状态；事件循环同时等待输出排空和退出码，整批一个后端事务。
- [翻译数据](./Resources/UnixTranslations.dict)保留十语；品牌、包名、真实路径和后端诊断保持原文。所有界面自有文案均由翻译表提供。
- 先预览再启用主操作，默认空选；选择或操作变化使旧计划失效。执行中锁定编辑，仅显示真实批结果，不因日志关键词猜测逐项成功、失败或未执行。
- 非 root 写操作尝试 PolicyKit 图形授权，缺失则报告并保留 CLI 路线；不主动装依赖，不等待隐藏的 sudo 密码。Tk 只负责本会话图形依赖，CLI 无 Tk 要求。
- 忙时关闭直接最小化，空闲可选择最小化或退出；无托盘插件、无系统服务或自启动。用任务栏恢复原窗口，任务完成后不抢前台。
- 跟随系统定时检查常见 GNOME/KDE 外观；其它 X11 桌面没有共同协议时保留 Tk 初始外观。Wayland 需要 XWayland，藏文需要系统字体。这些能力和目标平台认证须实机验证。

异步管道与真实退出码的语义参考 [Tcl open](https://www.tcl-lang.org/man/tcl8.6/TclCmd/open.htm)、[fileevent](https://www.tcl-lang.org/man/tcl8.6/TclCmd/fileevent.htm) 和 [close](https://www.tcl-lang.org/man/tcl8.6/TclCmd/close.htm) 官方手册（2026-11-17查阅）。

## 三、<span id="verification">验证</span> <a href="#前言">🔼</a> <a href="#🔚">🔽</a>

在本目录执行模型回归：

```sh
tclsh './Tests/UnixManagerTests.tcl/UnixManagerTests.tcl'
```

模型测试依赖开发环境已有 Tcl 8.6+ 与 sh，不需要 Tk/显示服务器；使用中文空格临时目录及假后端，不调用系统软件包管理器。[测试说明](./Tests/UnixManagerTests.tcl/README.md)记录覆盖范围。另有[原生控件测试](./Tests/UnixNativeUiTests.tcl/README.md)：本机现有 Tk 9.1.0 的36项有界假 worker/控件事件检查通过，保留可复跑脚本。目标系统的桌面渲染、鼠标/屏幕阅读器、字体、系统授权和真实包事务均须实机验收；模型通过不等同六平台桌面通过。

<a id="🔚" href="#前言">我是有底线的➤点我回到首页</a>

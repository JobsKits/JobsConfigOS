# Unix 管理面板隔离验证

![Jobs出品，必属精品](https://picsum.photos/1500/400)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [🔥 前言](#%E5%89%8D%E8%A8%80)
- [一、测试入口与边界](#entries)

</details>
<!-- jobs-toc:end -->

---

## 🔥 <span id="前言">前言</span>

两套测试共用当前面板源码及有界假后端，不调用真实软件包管理器，不安装或卸载工具。

## 一、<span id="entries">测试入口与边界</span> <a href="#前言">🔼</a> <a href="#🔚">🔽</a>

| 测试 | 环境与覆盖 |
| --- | --- |
| [模型测试](./UnixManagerTests.tcl/README.md) | 已有Tcl与sh；翻译、计划、参数、偏好、真实事件循环及子进程输出／退出码；无需桌面 |
| [原生控件测试](./UnixNativeUiTests.tcl/README.md) | 已有Tcl/Tk与桌面；整行／键盘选择、主题语言、日志、假任务和关闭生命周期 |

临时测试现场与报告路径由各入口输出。目标发行版的实际桌面、字体、辅助技术、图形授权及包事务仍须另行验收；本机Tk结果不外推六个平台通过。返回[共享面板说明](../README.md)。

<a id="🔚" href="#前言">我是有底线的➤点我回到首页</a>

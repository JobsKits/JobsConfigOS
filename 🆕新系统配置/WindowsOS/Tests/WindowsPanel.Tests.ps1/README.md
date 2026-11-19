# WindowsPanel.Tests.ps1

![Jobs出品，必属精品](https://picsum.photos/1500/400)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [🔥 前言](#%E5%89%8D%E8%A8%80)
- [一、运行](#run)
- [二、范围与边界](#scope)

</details>
<!-- jobs-toc:end -->

---

## 🔥 <span id="前言">前言</span>

GUI 资源、后端 JSON 事件协议及有界后台进程的隔离回归。不加载 WinForms、不调用真实 WinGet、不安装或卸载软件。

## 一、<span id="run">运行</span> <a href="#前言">🔼</a> <a href="#🔚">🔽</a>

```powershell
& './WindowsPanel.Tests.ps1'
```

需要 [**PowerShell**](https://learn.microsoft.com/powershell/) 5.1 或以上，亦可在 macOS PowerShell 7 运行。测试按脚本位置定位 GUI 和后端，不依赖调用工作目录。

## 二、<span id="scope">范围与边界</span> <a href="#前言">🔼</a> <a href="#🔚">🔽</a>

- 检查十语资源、当前组件目录、授权参数、路径引用、事件顺序与首败后未执行、默认 CLI 兼容。
- 使用有界假工作进程验证 UTF-8 双流排空和真实非零退出码，不调用包管理器、注册表或真实安装器。
- 23 项隔离断言于 2026-11-17 通过；Windows 原生控件、窗口／托盘生命周期和真实安装业务需在目标系统单独验收，不能从跨平台协议回归推定通过。

<a id="🔚" href="#前言">我是有底线的➤点我回到首页</a>

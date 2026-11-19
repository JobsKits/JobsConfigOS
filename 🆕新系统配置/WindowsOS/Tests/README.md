# WindowsOS 配置隔离测试

![Jobs出品，必属精品](https://picsum.photos/1500/400)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [🔥 前言](#%E5%89%8D%E8%A8%80)
- [一、运行与范围](#run)

</details>
<!-- jobs-toc:end -->

---

## 🔥 <span id="前言">前言</span>

[测试脚本](./WindowsBootstrap.Tests.ps1/README.md)以临时目录和函数替身验证受管安装与反安装，保留真实 JSON 收据与完整目录指纹算法；不调用本机真实包管理器、注册表或软件安装器。

## 一、<span id="run">运行与范围</span> <a href="#前言">🔼</a> <a href="#🔚">🔽</a>

```powershell
& './WindowsBootstrap.Tests.ps1/WindowsBootstrap.Tests.ps1'
```

需要已有 PowerShell 5.1 或以上；本轮实际使用 macOS PowerShell 7。夹具按唯一运行号保留在系统临时目录中，失败不会删除现场。真实 WinGet 与 Windows 原生行为另行验收，静态 Parser 不代替 5.1 实际运行。

GUI 协议与有界假 worker 另见 [WindowsPanel.Tests.ps1](./WindowsPanel.Tests.ps1/README.md)，验证十语资源、目录、事件及双流排空；不等同 Windows 原生控件验收。

<a id="🔚" href="#前言">我是有底线的➤点我回到首页</a>

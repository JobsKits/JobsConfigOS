# WindowsBootstrap.Tests.ps1

![Jobs出品，必属精品](https://picsum.photos/1500/400)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [🔥 前言](#%E5%89%8D%E8%A8%80)
- [一、用法与覆盖](#cases)

</details>
<!-- jobs-toc:end -->

---

## 🔥 <span id="前言">前言</span>

[测试入口](./WindowsBootstrap.Tests.ps1)点加载受管实施脚本，替换真实包管理器和注册信息读取，以临时目录验证实际收据、目录指纹与坏 JSON 处理。

## 一、<span id="cases">用法与覆盖</span> <a href="#前言">🔼</a> <a href="#🔚">🔽</a>

```powershell
& './WindowsBootstrap.Tests.ps1'
```

验证默认计划和空选、取消无写入、新装与重复安装、既有健康复用与修复不认领、安装失败及待完成收据、版本／文件／新增文件／空目录变化、缺少指纹或收据身份不符、卸载失败、重复卸载、并发锁，以及 WinGet 导出坏结构、未知版本和临时文件清理。成功打印断言数与夹具路径，失败返回非零并保留现场。

本轮实际在 macOS 的 PowerShell 7 使用替身运行；没有调用真实 Windows 注册表、WinGet、UAC 或用户工具链。Windows PowerShell 5.1 原生、CMD 参数透传与真实包安装仍未验收。

<a id="🔚" href="#前言">我是有底线的➤点我回到首页</a>

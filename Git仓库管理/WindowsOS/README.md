# Windows 面板启动辅助

![Jobs出品，必属精品](https://picsum.photos/1500/400)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [🔥 前言](#%E5%89%8D%E8%A8%80)
- [一、入口与寻址](#jobs-toc-heading-2)
- [二、环境、日志与失败](#jobs-toc-heading-3)

</details>
<!-- jobs-toc:end -->

---

## 🔥 <span id="前言">前言</span>

[**Windows**](https://www.microsoft.com/windows) 的原生启动辅助，由[根.cmd](../../【Windows】🧩Git仓库管理.cmd)调用；与 MacOS 共用 Python GUI 源码。

## <span id="jobs-toc-heading-2" data-jobs-toc="v2">一、入口与寻址 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

`launch.ps1` 使用 `$PSScriptRoot` 定位交付目录，读取 `../latest-windows.json`；目标须为 `dist/WindowsOS/<构建时间>/JobsGitManager/JobsGitManager.exe`。拒绝空值、绝对路径、父级穿越和缺失产物。父仓由根入口显式传入，直接调用时按辅助目录位置推导。

根入口的 `-ExecutionPolicy Bypass` 仅作用于本次进程，不修改系统策略。

## <span id="jobs-toc-heading-3" data-jobs-toc="v2">二、环境、日志与失败 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

需要系统 `powershell.exe` 和已构建本平台 EXE；缺少或清单无效时显示错误并返回非零。原生界面提示使用系统 Windows Forms；应用日志位置见[总说明](../README.md#safety)，启动器不另建业务日志。

首次使用先在 Windows 运行[本端构建入口](../【Windows】📦生成exe.bat/README.md)。本轮仅交付本端源码与构建方法，实际 Windows 构建／桌面运行待验。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>

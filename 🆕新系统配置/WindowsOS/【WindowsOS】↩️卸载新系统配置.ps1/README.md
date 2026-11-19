# WindowsOS 新系统配置反安装

![Jobs出品，必属精品](https://picsum.photos/1500/400)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [🔥 前言](#%E5%89%8D%E8%A8%80)
- [一、运行、参数与影响](#run)

</details>
<!-- jobs-toc:end -->

---

## 🔥 <span id="前言">前言</span>

[反安装脚本](./【WindowsOS】↩️卸载新系统配置.ps1)为同平台[唯一受管实施脚本](../【WindowsOS】🆕新系统配置.ps1/README.md#lifecycle)的薄入口，固定转交 `Uninstall`。使用原生 [**Windows PowerShell 5.1**](https://learn.microsoft.com/powershell/scripting/windows-powershell/overview)，不复制清单或绕过收据检查。

## 一、<span id="run">运行、参数与影响</span> <a href="#前言">🔼</a> <a href="#🔚">🔽</a>

```powershell
& './【WindowsOS】↩️卸载新系统配置.ps1' -Components git,node
# 自动化的显式反安装授权。
& './【WindowsOS】↩️卸载新系统配置.ps1' -Components git -Confirm
```

支持 `-Components`、`-Confirm`、`-StateRoot`；含义与实施脚本一致。组件必须显式指定，默认取消；不传组件时不会全选。`.cmd` 可传相同参数，裸双击因缺少组件而失败，并等待按键保留错误信息；有参数调用不暂停。

只撤回本工具新增、版本与完整目录／注册信息指纹一致的安装；未知归属、原有安装、内容已变或缺少独立目录信息时保留并返回非零。不是所有软件都有足够原生信息供自动撤回；不会通过强制删除目录补齐卸载。日志与收据由同一实施脚本管理，自动依赖和用户配置不由本入口整片删除。

独立分发需要复制完整 `WindowsOS/`，薄入口基于自身位置查找实施脚本，不依赖启动工作目录。当前仅通过 PowerShell Parser 与本地隔离调用验证；Windows 原生 CMD / UAC / 真实卸载未实机验收。

<a id="🔚" href="#前言">我是有底线的➤点我回到首页</a>

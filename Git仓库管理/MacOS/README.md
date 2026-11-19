# MacOS 面板启动辅助

![Jobs出品，必属精品](https://picsum.photos/1500/400)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [🔥 前言](#%E5%89%8D%E8%A8%80)
- [一、入口与寻址](#jobs-toc-heading-2)
- [二、环境、日志与边界](#jobs-toc-heading-3)

</details>
<!-- jobs-toc:end -->

---

## 🔥 <span id="前言">前言</span>

[**MacOS**](https://www.apple.com/macos/) 的相对路径启动辅助，由[根.command](../../【MacOS】🧩Git仓库管理.command)调用；这里只打开应用，不执行仓库配置写入。

## <span id="jobs-toc-heading-2" data-jobs-toc="v2">一、入口与寻址 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

`launch.command` 依据自身目录找到交付层和父仓，读取 `../latest-macos.json` 的 `executable` 相对路径。目标必须属于 `dist/` 下的 `.app`；缺少、失效或越界清单会提示错误并非零退出，不启动旧包。

根入口无需手填仓库路径，也不依赖终端工作目录；同一工程移动时保留目录结构即可。

## <span id="jobs-toc-heading-3" data-jobs-toc="v2">二、环境、日志与边界 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

使用系统 `/bin/zsh`、`plutil`、`osascript` 和 `open`。成功后由应用接管交互，写操作在 GUI 内预览并确认；日志由 GUI 创建，位置见[总说明](../README.md#safety)。启动器不安装依赖、不联网、不修改 Git。

没有 App 时运行[本端构建入口](../【MacOS】📦生成dmg.command/README.md)。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>

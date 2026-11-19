# MacOS 新系统配置

![Jobs出品，必属精品](https://picsum.photos/1500/400)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [🔥 前言](#%E5%89%8D%E8%A8%80)
- [一、入口](#jobs-toc-heading-2)

</details>
<!-- jobs-toc:end -->

---

## 🔥 <span id="前言">前言</span>

保留原终端十阶段、受管组件后端与隔离测试。

**开发入口：** [直接打开Xcode工程](./【MacOS】🧰新系统配置管理.xcodeproj)，选择同名Scheme后 `⌘R`。实际[Swift源码](./安装面板/Sources/EnvironmentManager.swift)与[完整构建说明](./安装面板/README.md)随仓保留；App是构建产物。

## <span id="jobs-toc-heading-2" data-jobs-toc="v2">一、入口 <a href="#前言">🔼</a> <a href="#🔚">🔽</a></span><!-- jobs-toc:heading-end -->

- [完整安装说明](./【MacOS】🆕新系统配置.command/README.md)
- [安装脚本](./【MacOS】🆕新系统配置.command/【MacOS】🆕新系统配置.command)
- [组件后端](./【MacOS】🆕新系统配置.command/【MacOS】环境管理后端.command/README.md)
- [终端反安装](./【MacOS】↩️卸载新系统配置.command/README.md)
- [管理面板](./安装面板/README.md)
- [原生Xcode工程](./【MacOS】🧰新系统配置管理.xcodeproj)
- [新系统配置管理 App](./【MacOS】🧰新系统配置管理.app)

```shell
zsh "./【MacOS】🆕新系统配置.command/【MacOS】🆕新系统配置.command"
```

终端入口、后端和测试按此布局迁移；依赖本仓环境子模块的功能需保留 `JobsConfigOS` 完整相对目录。独立 App 已从当前源码重建，从包内资源定位，不依赖源码仓库路径。后续修改脚本后通过构建器刷新 App；包内构建收据与资源摘要记录实际交付版本，源码、产物及真实安装结果分别记录。

<a id="🔚" href="#前言">我是有底线的➤点我回到首页</a>

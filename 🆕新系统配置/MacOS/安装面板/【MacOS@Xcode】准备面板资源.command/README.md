# Xcode 面板资源准备阶段

![Jobs出品，必属精品](https://picsum.photos/1500/400)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [🔥 前言](#%E5%89%8D%E8%A8%80)
- [一、调用与路径](#entry)
- [二、资源与影响范围](#payload)
- [三、验证](#validation)

</details>
<!-- jobs-toc:end -->

---

## 🔥 <span id="前言">前言</span>

本包是[新系统配置管理 Xcode 工程](../../【MacOS】🧰新系统配置管理.xcodeproj)的内部资源阶段，使用系统 [**zsh**](https://www.zsh.org/) 和原生命令。从本仓当前源码、后端、翻译与已有图标生成自包含 App 资源，不安装、卸载、编译或发布旁边的发行 App。

## 一、<span id="entry">调用与路径</span> <a href="#前言">🔼</a> <a href="#🔚">🔽</a>

真正入口为[同名脚本](./【MacOS@Xcode】准备面板资源.command)，由 Xcode App target 在资源阶段调用。用户直接打开工程 Build／Run 即可；不要在终端手工伪造构建环境调用。非对应 Xcode target 环境会在写入前返回失败。

源码根从脚本实际位置解析，系统后端从本包的 `../../`（MacOS 目录）读取；App 包内保留既有资源目录名，与配置中的后端路径一致。目标使用 Xcode 提供的 `TARGET_BUILD_DIR`、`TARGET_TEMP_DIR`、`FULL_PRODUCT_NAME` 和 `UNLOCALIZED_RESOURCES_FOLDER_PATH`，不依赖启动工作目录，不写开发机绝对路径。

## 二、<span id="payload">资源与影响范围</span> <a href="#前言">🔼</a> <a href="#🔚">🔽</a>

- 将新系统组件后端和环境子模块必需的脚本、Shell配置按原布局放入 `Contents/Resources/package/`，保留真实运行权限；排除Git、依赖、测试和已有App产物。
- 从仓库既有 `icon.png` 生成ICNS，复制十语翻译并生成当前profile的 `PanelConfiguration.json`。
- 以当前Swift源码SHA-256写入 `BuildReceipt.plist`；`Payload.sha256`记录并核验本阶段全部资源。Xcode的Info.plist与签名仍由原生target管理。
- 临时App仅在本次 `TARGET_TEMP_DIR` 中创建，完成后替换本次构建产物的明确资源项，清理只涉及本轮精确临时目录。阶段失败使Xcode构建失败；不据此把不完整产物标为可发布。
- 不调用包管理器、不修改系统环境、不替换仓库旁的发行 `.app`。原终端[通用构建器](../【MacOS】构建安装面板.command/README.md)继续提供独立发行构建。

## 三、<span id="validation">验证</span> <a href="#前言">🔼</a> <a href="#🔚">🔽</a>

当前目录布局已通过 `zsh -n`、工程引用解析和独立资源装配夹具，覆盖中文空格路径、异工作目录、源码根定位及包内后端内容。迁移前真实 Xcode 构建与自测结果仅作为原基线；当前布局未重新执行真实 Xcode 编译。未运行真实系统配置安装／卸载，不据此代替另一台 Mac 的分发测试。

<a id="🔚" href="#前言">我是有底线的➤点我回到首页</a>

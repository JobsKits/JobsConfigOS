# 构建安装面板

![Jobs出品，必属精品](https://picsum.photos/1500/400)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [🔥 前言](#%E5%89%8D%E8%A8%80)
- [一、用途](#purpose)
- [二、运行](#run)
- [三、执行与恢复](#build-recovery)

</details>
<!-- jobs-toc:end -->

---

## 🔥 <span id="前言">前言</span>

本入口编译并打包自包含的原生管理 App。

## 一、<span id="purpose">用途</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

[【MacOS】构建安装面板.command](./【MacOS】构建安装面板.command) 编译上一级 `Sources/EnvironmentManager.swift`，读取 `Resources/BuildProfile.txt` 与十语翻译，打包项目当前后端和所需资源，默认生成 `../../【MacOS】🧰新系统配置管理.app`。完整功能见[面板说明](../README.md)。同一份源码也由[原生Xcode工程](../../【MacOS】🧰新系统配置管理.xcodeproj)编译，使用统一 `@main` 入口；本构建器以 `swiftc -parse-as-library` 编译，保留原有参数与发布路径。

## 二、<span id="run">运行</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

双击脚本先看内置自述，仅按回车开始构建，输入其它内容或 Ctrl+C 取消。明确的非交互调用：

```zsh
/bin/zsh ./【MacOS】构建安装面板.command --yes
```

| 参数 | 行为 |
| --- | --- |
| `--yes` | 明确授权构建产物，不授权环境安装或卸载 |
| `--native` | 只构建当前 CPU 架构；默认 Apple Silicon／Intel 通用版本 |
| `--output /目标路径.app` | 输出到用户明确指定的实际目录，拒绝符号链接和非自有同名 App |

## 三、<span id="build-recovery">执行与恢复</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

确认后检查本机 <u>[**Swift**](https://www.swift.org/)</u> 编译器、源码、翻译与仓内 `icon.png`，在目标同级私有暂存目录内装配资源、生成 ICNS、编译二进制、签名、验证并运行自测，成功后原子替换目标 App。首次缺少编译器时报告后停止；不会自动运行 `xcodebuild`、安装 SDK 或修改本机开发环境。源后端从 `../../` 读取，App 包内保留既有资源目录合同；重命名外层目录不改变包内后端位置。包内 `BuildReceipt.plist` 记录真实构建时间及面板源码摘要，`Payload.sha256` 记录资源清单并在发布前校验，便于区分源码与实际产物。

构建锁按目标目录和 Bundle 身份隔离。运行中的管理 App 拒绝替换；已有目标 Bundle 身份不匹配时拒绝覆盖。发布失败会尝试恢复上一份 App，恢复失败保留 `previous.app` 并明确其位置。正常退出只清理本轮确认归属的暂存和锁；异常留下的锁须确认没有构建进程后再人工处理。

日志使用系统临时目录中的独立 `JobsPanelBuild.*` 文件，终端实时显示相同内容。非 TTY、`NO_COLOR` 或未知终端保留纯文本；交互终端的临时配色按随脚本内嵌范本保护及恢复。运行不依赖本机 Skill 目录。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>

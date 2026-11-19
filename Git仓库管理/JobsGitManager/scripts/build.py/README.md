# Python 本平台构建器

![Jobs出品，必属精品](https://picsum.photos/1500/400)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [🔥 前言](#%E5%89%8D%E8%A8%80)
- [一、入口、确认与依赖](#jobs-toc-heading-2)
- [二、高层流程与产物](#jobs-toc-heading-3)
- [三、日志与失败](#jobs-toc-heading-4)

</details>
<!-- jobs-toc:end -->

---

## 🔥 <span id="前言">前言</span>

[build.py](./build.py) 按脚本实际位置解析内层工程和外层交付目录，使用 [**PyInstaller**](https://pyinstaller.org/) 打包当前 [**Python**](https://www.python.org) GUI；与启动时的工作目录无关。

## <span id="jobs-toc-heading-2" data-jobs-toc="v2">一、入口、确认与依赖 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

从本目录直接运行：

```shell
python3.13 ./build.py
```

Windows可用 `py -3.13 ./build.py`。只支持在目标 MacOS / Windows 本机运行，Python 3.11–3.14。首屏说明替换旧输出、缺失依赖安装和完成后启动应用；回车继续，非空取消，EOF停止。

必需依赖固定为 `PySide6-Essentials==6.12.0` 与 `pyinstaller==6.22.3`。健康版本直接复用，否则创建／使用内层 `.build-venv` 安装声明版本，再以该环境重新执行。`--yes` 显式确认上述影响；`--no-open` 仅供自动QA跳过最后的打开目录／实际窗口启动。

## <span id="jobs-toc-heading-3" data-jobs-toc="v2">二、高层流程与产物 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

- 确认后检查平台与依赖；任何失败立即停止。
- 只清理本工具当前平台 `Git仓库管理/dist/MacOS/` 或 `dist/WindowsOS/` 与对应 `latest-*.json`；拒绝符号链接输出目录和清单，不触及源码、用户配置、另一端产物或其它工具输出。
- 按一次构建时间建立 `dist/<平台>/YYYY.MM.DD HH-mm-ss/`，在本次临时目录保存PyInstaller工作文件。
- 将Python、图形依赖和应用模块生成本端成品，脱离开发源码导入路径做冻结启动检查，核对`frozen=true`和业务扫描未失败。
- MacOS生成APP、DMG、ZIP；Windows生成onedir EXE及ZIP，同时输出依赖许可和`build-info.json`（系统／架构／Python／依赖／源码摘要／启动结果）。
- 只有成功核验后才发布本平台相对`latest-*.json`；默认打开产物目录并启动刚生成的软件。

## <span id="jobs-toc-heading-4" data-jobs-toc="v2">三、日志与失败 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

构建工具输出直接保留在调用终端；依赖、打包、冒烟或打包分发任一步失败返回非零，不发布缺失成品、不回退启动旧包。`build-info.json`记录的是本次构建与冻结启动，不代表真实远端下载或所有系统架构通过。

应用执行日志、偏好与Git备份的运行时目录见[总说明](../../../README.md#safety)；打包输出不能写入这些用户数据，也不把构建机路径作为运行依赖。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>

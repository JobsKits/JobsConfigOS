# 生成 MacOS App 与 DMG

![Jobs出品，必属精品](https://picsum.photos/1500/400)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [🔥 前言](#%E5%89%8D%E8%A8%80)
- [一、运行与依赖](#jobs-toc-heading-2)
- [二、输出与验证](#jobs-toc-heading-3)

</details>
<!-- jobs-toc:end -->

---

## 🔥 <span id="前言">前言</span>

此入口在 [**MacOS**](https://www.apple.com/macos/) 本机从完整 [**Python**](https://www.python.org) 源码生成应用与分发包。核心构建逻辑见[构建器说明](../JobsGitManager/scripts/build.py/README.md)。

## <span id="jobs-toc-heading-2" data-jobs-toc="v2">一、运行与依赖 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

双击本目录同名 `.command`，或从本目录执行：

```shell
/bin/zsh "./【MacOS】📦生成dmg.command"
```

入口按 `python3.13`、`python3.14`、`python3.12`、`python3.11`、`python3` 顺序发现已有解释器；构建器复核 Python 3.11–3.14。首屏说明影响后，回车确认、其它输入取消，EOF停止；缺少本次锁定依赖时创建独立 `.build-venv` 并安装，不升级其它环境。

## <span id="jobs-toc-heading-3" data-jobs-toc="v2">二、输出与验证 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

仅替换本工具 `../dist/MacOS/` 旧输出，生成 `dist/MacOS/YYYY.MM.DD HH-mm-ss/` 内的 `JobsGitManager.app`、DMG、ZIP、依赖许可与 `build-info.json`。冻结运行检查成功后才发布 `latest-macos.json`，随后打开产物目录并启动本次 App；失败返回非零，不启动旧包。

`--yes` 表示已明确确认首屏影响；`--no-open` 仅供自动化验证跳过打开目录和交互启动，冻结冒烟验证仍执行。构建输出在终端，应用运行日志由 GUI 管理；不下载子仓、不暂存、不提交、不推送。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>

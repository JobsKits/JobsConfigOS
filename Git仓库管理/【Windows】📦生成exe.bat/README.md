# 生成 Windows EXE

![Jobs出品，必属精品](https://picsum.photos/1500/400)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [🔥 前言](#%E5%89%8D%E8%A8%80)
- [一、运行与依赖](#jobs-toc-heading-2)
- [二、输出与失败](#jobs-toc-heading-3)

</details>
<!-- jobs-toc:end -->

---

## 🔥 <span id="前言">前言</span>

此入口在 [**Windows**](https://www.microsoft.com/windows) 本机从同一套 [**Python**](https://www.python.org) 工程生成 EXE 与 ZIP，不在 MacOS 交叉伪造本端产物。

## <span id="jobs-toc-heading-2" data-jobs-toc="v2">一、运行与依赖 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

双击本目录同名 `.bat`。已有 `py` 时按 3.13、3.14、3.12、3.11 查找已安装解释器，否则尝试已有 `python`；解释器须为 3.11–3.14。业务由[共享构建器](../JobsGitManager/scripts/build.py/README.md)处理，首屏自述后回车确认、非空取消，EOF停止。

健康锁定依赖直接复用；缺少时在内层工程 `.build-venv` 创建独立环境并安装声明版本。不会安装或升级系统 Python、Git 或其它工具。

## <span id="jobs-toc-heading-3" data-jobs-toc="v2">二、输出与失败 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

输出 `../dist/WindowsOS/YYYY.MM.DD HH-mm-ss/JobsGitManager/JobsGitManager.exe` 与同目录 ZIP、许可和构建摘要，包含 Python 与图形依赖。验证冻结启动后才发布 `latest-windows.json`，随后打开资源管理器并启动本次 EXE。

构建仅替换本工具旧 `dist/WindowsOS/`，保留MacOS产物；失败保留终端并返回真实退出码，不启动旧包。`--yes` 是显式构建确认；`--no-open` 只供自动QA跳过打开与启动，不跳过包内验证。源码与入口静态检查不等于 Windows 本机打包或实际桌面运行已通过，状态见[资产盘点](../../项目相关报告/Git父子仓管理资产盘点.md#validation)。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>

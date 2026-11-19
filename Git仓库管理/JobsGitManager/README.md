# JobsGitManager 源码工程

![Jobs出品，必属精品](https://picsum.photos/1500/400)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [🔥 前言](#%E5%89%8D%E8%A8%80)
- [一、结构与职责](#jobs-toc-heading-2)
- [二、开发与运行](#jobs-toc-heading-3)

</details>
<!-- jobs-toc:end -->

---

## 🔥 <span id="前言">前言</span>

基于 [**Python**](https://www.python.org) 与 [**PySide6**](https://doc.qt.io/qtforpython-6/) 的跨平台父子仓配置面板。用户操作、平台入口和产物见[外层说明](../README.md)。

## <span id="jobs-toc-heading-2" data-jobs-toc="v2">一、结构与职责 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

| 路径 | 职责 |
| --- | --- |
| [pyproject.toml](./pyproject.toml) | 版本、Python范围、图形和构建依赖 |
| [app.py](./src/jobs_git_manager/app.py) | 主窗口、选择、预览确认、工作线程、主题与当前用户偏好 |
| [git_service.py](./src/jobs_git_manager/git_service.py) | 真实Git根识别、子仓扫描、快照计划、精确写入、备份、超时与取消 |
| [i18n.py](./src/jobs_git_manager/i18n.py) | 十语言界面目录；Git原始命令和诊断保留原文 |
| [entry.py](./src/jobs_git_manager/entry.py) / `__main__.py` | 打包入口／模块运行入口 |
| [tests/](./tests/README.md) | 临时本地父子仓和界面回归 |
| [scripts/](./scripts/README.md) | 平台共享构建编排 |

## <span id="jobs-toc-heading-3" data-jobs-toc="v2">二、开发与运行 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

在本工程目录用已有 Python 3.11–3.14 环境安装源码，安装声明依赖时会联网：

```shell
python -m pip install -e ".[build]"
python -m jobs_git_manager --repo ../..
```

`--repo` 为显式仓库路径；根快捷入口会自动传入所属父仓。可只安装 `-e .` 运行源码，不需要构建依赖。测试和构建命令见各目录README；源码运行不能代替最终成品交付。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>

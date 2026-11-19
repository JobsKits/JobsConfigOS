# Git 面板隔离回归

![Jobs出品，必属精品](https://picsum.photos/1500/400)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [🔥 前言](#%E5%89%8D%E8%A8%80)
- [一、入口与覆盖](#jobs-toc-heading-2)
- [二、依赖、输出与验证边界](#jobs-toc-heading-3)

</details>
<!-- jobs-toc:end -->

---

## 🔥 <span id="前言">前言</span>

本目录验证当前 GUI 后端和界面基础行为。使用临时本地 [**Git**](https://git-scm.com/) 父子仓与本地remote，不联网、不改真实业务仓，不运行旧版归档脚本。

## <span id="jobs-toc-heading-2" data-jobs-toc="v2">一、入口与覆盖 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

从内层工程目录运行：

```shell
python3.13 -B -m unittest discover -s tests -p "test_*.py" -v
```

[test_git_service.py](./test_git_service.py) 覆盖空仓／真实根、普通目录下嵌套发现、增量登记、保留其它暂存、跨远端相对地址、精确gitlink、过时计划、普通文件冲突、缺远端、链接／越界／重复登记、未完成操作、取消／超时、脏仓保护、本地remote快进与分叉、固定提交保护、外部元数据拒绝、已有目录过滤器恢复和递归初次检出。

新增界面回归时以本目录实际`test_*.py`为准，不将静态翻译键检查扩大为各平台母语审校或鼠标实测。

## <span id="jobs-toc-heading-3" data-jobs-toc="v2">二、依赖、输出与验证边界 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

后端使用Python标准库unittest和健康Git；涉及已有目录过滤器的临时夹具需要本机Node，缺少时按具体用例显示跳过。界面测试需要工程声明的图形依赖，可使用`QT_QPA_PLATFORM=offscreen`在隔离进程验证。

终端显示每项用例与真实失败／跳过，测试不自动更新项目报告。完整执行结果、MacOS成品启动、迁移与Windows本机待验状态见[资产盘点](../../../项目相关报告/Git父子仓管理资产盘点.md#validation)。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>

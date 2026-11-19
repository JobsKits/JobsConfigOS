# UnixNativeUiTests.tcl

![Jobs出品，必属精品](https://picsum.photos/1500/400)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [🔥 前言](#%E5%89%8D%E8%A8%80)
- [一、运行](#run)
- [二、覆盖与边界](#coverage)

</details>
<!-- jobs-toc:end -->

---

## 🔥 <span id="前言">前言</span>

使用开发机已有 [**Tcl/Tk**](https://www.tcl-lang.org/) 8.6+ 和桌面事件循环，建立真实控件并运行有界假后端。测试会临时显示一个窗口、最小化及恢复，结束销毁本测试窗口；不调用包管理器，不修改用户系统环境。

## 一、<span id="run">运行</span> <a href="#前言">🔼</a> <a href="#🔚">🔽</a>

```sh
tclsh './UnixNativeUiTests.tcl'
```

启动时先打印独立临时报告路径；Aqua Tk 接管标准输出后，所有断言仍写入该报告。失败退出非零，10秒看门狗防止悬挂；临时中文空格现场保留用于复核。无桌面时只运行[模型测试](../UnixManagerTests.tcl/README.md)，不要把模型结果称为控件验收。

## 二、<span id="coverage">覆盖与边界</span> <a href="#前言">🔼</a> <a href="#🔚">🔽</a>

36项真实控件/事件循环断言：复选框与行空白一次切换、Space、拖动返回/离开/滚动取消、十语和三主题保留选择、忙态锁定、成功计划绑定当前ID、主按钮启动假后端、忙时关闭直接最小化、完成保持后台、尾输出排空、实际计时、恢复原选择、手动追尾状态、空闲关闭默认保留、独立操作计时及空态重载。

本轮实际通过环境为 macOS 上现有 Tk 9.1.0，使用合成事件和假授权/假后端。没有执行真实安装、卸载或系统权限对话框；不能外推六平台桌面渲染、鼠标、辅助技术、字体、PolicyKit 和包事务通过。

<a id="🔚" href="#前言">我是有底线的➤点我回到首页</a>

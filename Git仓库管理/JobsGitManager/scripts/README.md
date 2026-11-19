# Git 面板构建脚本

![Jobs出品，必属精品](https://picsum.photos/1500/400)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [🔥 前言](#%E5%89%8D%E8%A8%80)
- [一、实际入口](#jobs-toc-heading-2)
- [二、运行与边界](#jobs-toc-heading-3)

</details>
<!-- jobs-toc:end -->

---

## 🔥 <span id="前言">前言</span>

本目录只维护 GUI 的本平台构建与校验，不承担仓库配置业务。

## <span id="jobs-toc-heading-2" data-jobs-toc="v2">一、实际入口 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

[build.py/build.py](./build.py/build.py) 是共享构建器，`build.py/README.md` 写明依赖、确认、清理范围、产物和失败处理。平台外层入口只负责定位解释器并转交参数。

```text
scripts/
├── README.md
└── build.py/
    ├── build.py
    └── README.md
```

## <span id="jobs-toc-heading-3" data-jobs-toc="v2">二、运行与边界 <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a></span><!-- jobs-toc:heading-end -->

日常优先使用[外层平台构建入口](../../README.md#build)；直接调用构建器同样执行自述与确认。输出属于外层固定 `dist/`，构建中间文件使用本次临时目录，用户日志由应用在当前用户数据目录保存。

本目录不安装 Git、不下载子仓、不修改被管理仓库的索引或全局配置。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>

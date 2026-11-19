# GUI 源码与成品交付

![Jobs出品，必属精品](https://picsum.photos/1500/400)

[toc]

---

## 🔥 <span id="前言">前言</span>

本轮归档时间（上海）：2026-11-17 11:49:53。范围为昨日新增的两套Mac GUI及今日七平台GUI，共9套；每套提供独立源码包、成品运行包、SHA256及逐文件manifest。归档不执行编译、安装或卸载，也不替代目标系统验收。

## 一、<span id="packages">九套交付</span> <a href="#前言">🔼</a> <a href="#🔚">🔽</a>

| 工具/平台 | 说明与包 | 产物类型 |
| --- | --- | --- |
| MacOS 新系统配置管理 | [MacOS-System](./MacOS-System/README.md) | `native-app` |
| MacOS 环境配置管理 | [MacOS-Environment](./MacOS-Environment/README.md) | `native-app` |
| WindowsOS 新系统配置管理 | [WindowsOS](./WindowsOS/README.md) | `windows-pe-launcher-and-powershell-runtime` |
| Ubuntu 新系统配置管理 | [Ubuntu](./Ubuntu/README.md) | `interpreted-tcl-tk-gui-runtime` |
| Debian 新系统配置管理 | [Debian](./Debian/README.md) | `interpreted-tcl-tk-gui-runtime` |
| RockyLinux 新系统配置管理 | [RockyLinux](./RockyLinux/README.md) | `interpreted-tcl-tk-gui-runtime` |
| Alpine 新系统配置管理 | [Alpine](./Alpine/README.md) | `interpreted-tcl-tk-gui-runtime` |
| AlibabaCloudLinux 新系统配置管理 | [AlibabaCloudLinux](./AlibabaCloudLinux/README.md) | `interpreted-tcl-tk-gui-runtime` |
| FreeBSD 新系统配置管理 | [FreeBSD](./FreeBSD/README.md) | `interpreted-tcl-tk-gui-runtime` |

每套目录包含`source.zip`、`product.zip`、各自`.sha256`、`manifest.json`及本地说明。Mac为现有原生App，Windows为真实EXE启动器及PowerShell运行资源，六Unix为依赖Tcl/Tk桌面的解释型运行包。各包明确自己的运行依赖及已验/待验；不把生成ZIP称为全部平台实机通过。

<a id="🔚" href="#前言">我是有底线的➤点我回到首页</a>

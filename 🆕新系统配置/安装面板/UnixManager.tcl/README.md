# UnixManager.tcl

![Jobs出品，必属精品](https://picsum.photos/1500/400)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [🔥 前言](#%E5%89%8D%E8%A8%80)

</details>
<!-- jobs-toc:end -->

---

## 🔥 <span id="前言">前言</span>

Jobs 六平台 Tcl/Tk 管理器。使用各平台 `【平台】🧰新系统配置管理.sh/` 入口启动，避免选错平台；运行依赖、权限、日志和已验/待验范围见[共享面板说明](../README.md)。

`UnixManager.tcl` 负责原生控件和生命周期，`ManagerCore.tcl` 是可在无桌面 Tcl 中验证的模型模块。模型只调用当前平台既有 CLI，执行前必须选择组件并成功预览；不修改包管理器业务。偏好及会话日志从当前用户状态目录定位，不依赖开发机路径。

<a id="🔚" href="#前言">我是有底线的➤点我回到首页</a>

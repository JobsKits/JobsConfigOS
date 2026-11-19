# 【FreeBSD】🆕新系统配置.sh

![Jobs出品，必属精品](https://picsum.photos/1500/400)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [🔥 前言](#%E5%89%8D%E8%A8%80)
- [一、入口与操作](#entry)
- [二、验证边界](#validation)

</details>
<!-- jobs-toc:end -->

---

## 🔥 <span id="前言">前言</span>

包内同名脚本为 FreeBSD 唯一实施入口，自包含安装/反安装、收据、锁和终端保护。复制完整包即可调用，不依赖开发机目录或外部生命周期库，不需要生成器。

## 一、<span id="entry">入口与操作</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

[平台完整说明](../README.md)包含9组件映射、最低OS待核、权限、日志、卸载边界及官方来源。

```sh
sh './【FreeBSD】🆕新系统配置.sh' --help
sh './【FreeBSD】🆕新系统配置.sh' --plan --components git,curl
sudo sh './【FreeBSD】🆕新系统配置.sh' --install --components git,curl --yes
sudo sh './【FreeBSD】🆕新系统配置.sh' --uninstall --components git,curl --yes
```

默认 `--plan`；`--list` 只列目录。所有写操作必须显式选组件；省略 `--yes` 时 fzf 默认取消，缺选择器停止。root/sudo 由用户指定；状态/日志在 `/var/db/jobs-new-system/FreeBSD`。健康环境复用，所选不健康组件自动定向修复并复检；`--repair` 为兼容参数。无归属、版本变化或依赖阻断保留并返回非零，不自动清理依赖。

## 二、<span id="validation">验证边界</span> <a href="#前言" style="font-size:17px; color:green;"><b>🔼</b></a> <a href="#🔚" style="font-size:17px; color:green;"><b>🔽</b></a>

已做 `sh -n` 与假命令隔离回归，未运行目标OS真实安装/反安装；最低版本、软件仓、权限及终端行为待原生验证。版本收据不等于包文件快照恢复。

<a id="🔚" href="#前言" style="font-size:17px; color:green; font-weight:bold;">我是有底线的➤点我回到首页</a>

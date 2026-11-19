# 新系统组件后端测试

![Jobs出品，必属精品](https://picsum.photos/1500/400)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [🔥 前言](#%E5%89%8D%E8%A8%80)
- [一、运行](#jobs-toc-heading-2)

</details>
<!-- jobs-toc:end -->

---

## 🔥 <span id="前言">前言</span>

[生命周期测试](./lifecycle_tests.py/README.md)使用已有 Python 标准库，为每个场景创建独立临时 HOME 和假 Node/npm/brew。不会下载软件、触发系统安装器或卸载本机环境。

## <span id="jobs-toc-heading-2" data-jobs-toc="v2">一、运行</span><!-- jobs-toc:heading-end -->

    python3 ./lifecycle_tests.py/lifecycle_tests.py --yes

真实入口会复制到中文与空格路径，从工程外工作目录执行。测试结果输出本轮临时目录，失败现场保留供核对。生产入口不依赖 Python。

<a id="🔚" href="#前言">回到前言</a>

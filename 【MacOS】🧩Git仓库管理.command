#!/bin/zsh
# 脚本自述：相对路径启动 Git 管理面板；这里只转交仓库位置，不写 Git。
# shell: zsh
ENTRY_PATH="${0:A}"
# 保留真实文本入口，整个仓库移动后仍可使用。
main() {
    local repository="${ENTRY_PATH:h}"
    /bin/zsh "${repository}/Git仓库管理/MacOS/launch.command" "$@"
}
main "$@"

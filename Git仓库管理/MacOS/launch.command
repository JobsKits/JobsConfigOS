#!/bin/zsh
# 脚本自述：只打开配套的 Git GUI，传入当前仓库；不会修改 Git 状态。
# shell: zsh
ENTRY_PATH="${0:A}"
# 从实际启动器位置找到构建清单，拒绝外部与失效路径。
main() {
    setopt NO_NOMATCH
    local delivery="${ENTRY_PATH:h:h}"
    local repository="${delivery:h}"
    local manifest="${delivery}/latest-macos.json"
    local target=""
    print -r -- 'Git 仓库管理：打开只读面板；写入需在 GUI 预览并确认。'
    if [[ -f "$manifest" ]]; then
        target="$(/usr/bin/plutil -extract executable raw -o - "$manifest" 2>/dev/null)"
    fi
    if [[ -z "$target" || "$target" == /* || "$target" == *'..'* || ! -d "${delivery}/${target}" || "$target" != dist/*.app ]]; then
        /usr/bin/osascript -e 'display alert "Git 仓库管理" message "缺少本机应用包。请在 Git仓库管理 文件夹运行 MacOS 打包入口。" as critical'
        return 1
    fi
    /usr/bin/open -n "${delivery}/${target}" --args --repo "$repository" "$@"
}
main "$@"

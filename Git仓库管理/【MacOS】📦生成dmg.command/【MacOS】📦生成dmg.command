#!/bin/zsh
# 脚本自述：本机生成App/DMG；Python构建器确认后替换本工具dist。
# shell: zsh
ENTRY_PATH="${0:A}"
# 定位解释器和源码；确认及构建由Python统一编排。
main() {
    local delivery="${ENTRY_PATH:h:h}"
    local python=""
    local candidate=""
    for candidate in python3.13 python3.14 python3.12 python3.11 python3; do
        if command -v "$candidate" >/dev/null 2>&1; then
            python="$(command -v "$candidate")"
            break
        fi
    done
    if [[ -z "$python" ]]; then
        print -u2 -- '需要 Python 3.11–3.14。'
        return 1
    fi
    "$python" "${delivery}/JobsGitManager/scripts/build.py/build.py" "$@"
}
main "$@"

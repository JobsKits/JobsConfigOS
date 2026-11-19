#!/bin/sh
# 用途：执行 GUI 已确认的唯一后端命令，排空输出后保留真实退出码。
# 内部入口：仅由管理面板传入已创建的私有状态文件；不做权限提升或重试。
# shell: sh
run_backend() {
    result_path=$1
    shift
    "$@"
    result_code=$?
    printf '%s\n' "$result_code" > "$result_path" || exit 125
    return "$result_code"
}
check_arguments() {
    [ "$#" -ge 2 ] || exit 2
    [ -f "$1" ] && [ ! -L "$1" ] || exit 2
}
main() {
    check_arguments "$@"
    run_backend "$@"
}
main "$@"

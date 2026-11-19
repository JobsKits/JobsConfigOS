#!/bin/sh
# 用途：打开本平台 Jobs 新系统配置 GUI；启动只读取组件目录。
# 依赖：Tcl/Tk 8.6+、桌面 DISPLAY；安装/卸载由界面明确确认后交给既有 CLI。
# shell: sh
PLATFORM='Alpine'
DISTRO='alpine'
SCRIPT_DIR=''
PROJECT_ROOT=''
GUI=''
ENTRY_ACTION=launch
# 展示用途与影响，不产生系统写入。
show_intro() {
    printf '%s\n' "Jobs ${PLATFORM} 新系统配置管理" '启动不安装工具、不改代理、默认Shell或系统服务；关闭忙碌窗口会最小化并保全任务。' '界面默认空选，先预览计划，再点击安装或卸载；系统授权只在执行时请求。'
}
# 按脚本自身位置定位共享GUI，不依赖工作目录。
resolve_resources() {
    SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P) || return 1
    PROJECT_ROOT=$(CDPATH= cd -- "${SCRIPT_DIR}/../.." && pwd -P) || return 1
    GUI="${PROJECT_ROOT}/安装面板/UnixManager.tcl/UnixManager.tcl"
    [ -r "${GUI}" ] && [ -r "${PROJECT_ROOT}/安装面板/UnixManager.tcl/ManagerCore.tcl" ] &&
    [ -r "${PROJECT_ROOT}/安装面板/Resources/UnixTranslations.dict" ] || {
        printf '错误：缺少管理面板资源：%s；请保留完整多平台目录。\n' "${GUI}" >&2
        return 1
    }
}
# 只读取系统标记，拒绝不匹配的系统与发行版。
check_platform() {
    actual_os=$(uname -s) || return 1
    if [ "${PLATFORM}" = FreeBSD ]; then
        [ "${actual_os}" = FreeBSD ] || { printf '%s\n' '错误：入口与当前系统不匹配。' >&2; return 1; }
    else
        [ "${actual_os}" = Linux ] && [ -r /etc/os-release ] || { printf '%s\n' '错误：需要匹配发行版的Linux桌面。' >&2; return 1; }
        actual_distro=$(awk -F= '$1 == "ID" { value=$2; gsub(/["\047]/,"",value); print value; exit }' /etc/os-release)
        [ "${actual_distro}" = "${DISTRO}" ] || { printf '错误：当前发行版 %s 与 %s 不匹配。\n' "${actual_distro}" "${PLATFORM}" >&2; return 1; }
    fi
}
# 检查桌面及Tk；缺失仅提示，不安装或提权。
launch_gui() {
    [ -n "${DISPLAY:-}" ] || { printf '%s\n' '错误：未发现桌面 DISPLAY。纯终端/SSH会话请使用同平台CLI；Wayland桌面需要可用XWayland。' >&2; return 1; }
    wish_command=''
    for candidate in wish wish9.0 wish8.6 wish86; do
        if command -v "${candidate}" >/dev/null 2>&1; then wish_command=$(command -v "${candidate}"); break; fi
    done
    [ -n "${wish_command}" ] || {
        printf '%s\n' '错误：缺少 Tcl/Tk 8.6+。管理员可审阅本机软件源后执行：apk add tk；本入口不自动安装依赖。' >&2
        return 1
    }
    NO_COLOR=1
    PLAIN_OUTPUT=1
    export NO_COLOR PLAIN_OUTPUT
    state_base="${HOME}/.local/state"
    case "${XDG_STATE_HOME:-}" in /*) state_base=${XDG_STATE_HOME} ;; esac
    launch_directory="${state_base}/jobs-new-system-gui/${PLATFORM}"
    umask 077
    [ ! -L "${launch_directory}" ] || { printf '%s\n' '错误：GUI状态目录不能是符号链接。' >&2; return 1; }
    mkdir -p "${launch_directory}" || return 1
    chmod 700 "${launch_directory}" || return 1
    launch_log=$(mktemp "${launch_directory}/launch.XXXXXXXX") || return 1
    nohup "${wish_command}" "${GUI}" "${PLATFORM}" > "${launch_log}" 2>&1 < /dev/null &
    launch_pid=$!
    printf '已请求启动GUI（进程 %s）；启动诊断：%s\n' "${launch_pid}" "${launch_log}"
    # nohup仅解除启动终端HUP；不会关闭用户已有Shell或注册后台服务。
    return 0
}
# 参数只决定帮助、资源核对或启动；不构造系统包操作。
parse_arguments() {
    [ "$#" -le 1 ] || { printf '%s\n' '错误：入口只接受一个可选参数。' >&2; exit 2; }
    case "${1:-}" in
        --help) ENTRY_ACTION=help ;;
        --check) ENTRY_ACTION=check ;;
        '') ENTRY_ACTION=launch ;;
        *) printf '错误：未知参数 %s\n' "$1" >&2; exit 2 ;;
    esac
}
# 帮助不要求图形依赖；只读入口不接管终端配色。
show_help_if_requested() {
    if [ "${ENTRY_ACTION}" = help ]; then
        printf '%s\n' '用法：sh 本入口 [--help|--check]；--check只核对资源及目标系统，不启动GUI。'
        exit 0
    fi
}
# 核对模式不创建日志、锁或收据；其它模式转交唯一GUI。
run_selected_action() {
    if [ "${ENTRY_ACTION}" = check ]; then
        printf '资源核对通过：%s\n' "${GUI}"
        return 0
    fi
    launch_gui
}
# 在门禁函数内处理失败，main不混入判断或退出分支。
validate_launch_environment() {
    resolve_resources || exit 1
    check_platform || exit 1
}
# 仅编排平台原生入口的展示、校验和GUI转交。
main() {
    show_intro # 说明用途、影响与最终确认位置。
    parse_arguments "$@" # 拒绝未知或重复参数。
    show_help_if_requested # 帮助无图形依赖，保持只读。
    validate_launch_environment # 按自身位置核对资源与当前目标系统。
    run_selected_action # 只读核对或启动管理界面。
}
main "$@"

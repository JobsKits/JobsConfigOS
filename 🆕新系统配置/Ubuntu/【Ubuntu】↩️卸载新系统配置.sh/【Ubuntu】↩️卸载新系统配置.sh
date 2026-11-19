#!/bin/sh
# 脚本自述：Ubuntu 新系统配置的专用卸载入口；无参只显示帮助。
# 影响：仅转交同平台后端的收据卸载，不新增安装、修复或清理行为。
# 运行提示：必须明确组件；确认、日志、互斥与终端配色复用后端，Ctrl+C取消。
# shell: sh

SCRIPT_DIR=''
BACKEND=''

# 快捷入口只作说明；真正写入仍由后端展示计划并确认。
show_intro() {
    printf '%s\n' 'Jobs Ubuntu 卸载新系统配置' '用途：卸载本工具有完整且版本匹配收据的指定直接包；原有或共享对象按后端规则保留。' '无参仅显示帮助；日志与收据复用同平台后端状态目录；Ctrl+C取消。'
}
# 锁定卸载动作，不能用透传参数切换成安装或预览。
validate_arguments() {
    [ "$#" -gt 0 ] || { show_help; exit 0; }
    if [ "$#" -eq 1 ]; then
        case "$1" in
            --help) show_help; exit 0 ;;
            --list) return 0 ;;
        esac
    fi
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --components)
                [ "$#" -ge 2 ] || { printf '%s\n' '错误：--components 缺少组件值。' >&2; exit 2; }
                shift ;;
            --components=*|--yes) ;;
            *)
                printf '错误：卸载入口不接受参数 %s；使用 --help 查看用法。\n' "$1" >&2
                exit 2 ;;
        esac
        shift
    done
}
# 帮助本身不需要后端或目标系统，避免误运行产生写入。
show_help() {
    printf '%s\n' '用法：sh 本入口 --components git,curl [--yes]' '只读：sh 本入口 --help 或 --list；两者必须单独使用。' '无参数只显示帮助；卸载必须明确组件，绝不默认全选。' '不传--yes时由后端要求终端回车和默认取消的fzf确认；--yes表示审阅后授权指定组件卸载。' '本入口拒绝--install、--plan、--uninstall、--repair及未知参数；预览请使用同平台配置脚本。'
}
# 从入口自身定位唯一实施脚本，保留完整平台目录即可迁移。
resolve_backend() {
    SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P) || exit 1
    BACKEND="${SCRIPT_DIR}/../【Ubuntu】🆕新系统配置.sh/【Ubuntu】🆕新系统配置.sh"
    [ -r "${BACKEND}" ] || {
        printf '错误：缺少同平台配置后端：%s；请保留完整的平台目录。\n' "${BACKEND}" >&2
        exit 1
    }
}
# exec保留后端真实退出码、信号与既有确认，不复制卸载生命周期。
run_backend() {
    if [ "$#" -eq 1 ] && [ "$1" = --list ]; then
        exec /bin/sh "${BACKEND}" --list
    fi
    exec /bin/sh "${BACKEND}" --uninstall "$@"
}
main() {
    show_intro
    validate_arguments "$@"
    resolve_backend
    run_backend "$@"
}
main "$@"


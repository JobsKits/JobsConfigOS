#!/bin/sh
# 脚本自述：Jobs Alpine 新系统开发环境按组件安装/反安装。
# 默认只预览；写入须明确组件与授权，系统包操作需要root。
# 不修改默认Shell、代理、防火墙或系统服务；日志和收据保留在本机状态目录。
# shell: sh

# >>> Jobs terminal style protection v1 >>>
# 临时保护当前终端配色，业务进程自行管理原有退出清理。
jobs_terminal_style_run() {
    # 无法可靠保存原色时，沿用脚本已有的纯文本约定。
    jobs_terminal_style_plain() {
        PLAIN_OUTPUT=1
        NO_COLOR=1
        FORCE_COLOR=0
        CLICOLOR=0
        ANSI_COLORS_DISABLED=1
        npm_config_color=false
        export PLAIN_OUTPUT NO_COLOR FORCE_COLOR CLICOLOR ANSI_COLORS_DISABLED npm_config_color
        if "$@"; then
            jobs_style_exit_status=0
        else
            jobs_style_exit_status=$?
        fi
        exit "$jobs_style_exit_status"
    }
    if [ ! -t 0 ] || [ ! -t 1 ] || [ -z "${TERM:-}" ] ||
       [ "${TERM:-}" = dumb ] || [ "${NO_COLOR+x}" = x ] ||
       [ "${PLAIN_OUTPUT:-0}" = 1 ] || [ "${IS_SOURCETREE_RUNTIME:-0}" = 1 ] ||
       env | LC_ALL=C grep -qiE '^(SOURCETREE|SOURCE_TREE)'; then
        if "$@"; then
            jobs_style_exit_status=0
        else
            jobs_style_exit_status=$?
        fi
        exit "$jobs_style_exit_status"
    fi
    if [ -n "${TMUX:-}${STY:-}" ]; then
        jobs_terminal_style_plain "$@"
    fi
    jobs_style_tty=$(tty 2>/dev/null) || jobs_terminal_style_plain "$@"
    if ! ps -o pgid= -o tpgid= -p "$$" 2>/dev/null |
         LC_ALL=C awk 'NF == 2 && $1 == $2 && $1 > 0 { foreground = 1 } END { exit !foreground }'; then
        jobs_terminal_style_plain "$@"
    fi
    case ${JOBS_TERMINAL_STYLE_OWNER:-} in
        ''|*[!0-9]*) ;;
        *)
            if [ "${JOBS_TERMINAL_STYLE_TTY:-}" = "$jobs_style_tty" ] &&
               kill -0 "$JOBS_TERMINAL_STYLE_OWNER" 2>/dev/null; then
                if "$@"; then
                    jobs_style_exit_status=0
                else
                    jobs_style_exit_status=$?
                fi
                exit "$jobs_style_exit_status"
            fi
            ;;
    esac
    jobs_style_stty=$(stty -g 2>/dev/null < /dev/tty) || jobs_terminal_style_plain "$@"
    jobs_style_saved=''
    jobs_style_saved_rows=''
    jobs_style_original_rows=''
    jobs_style_applied_rows=''
    jobs_style_changed=0
    jobs_style_applied_complete=0
    jobs_style_query_active=0
    jobs_style_recovery=''
    jobs_style_exit_status=0
    jobs_style_esc=$(printf '\033')
    jobs_style_bel=$(printf '\007')
    # 完整颜色帧有界重发；设置核验与退出恢复容忍帧外回车和明确方向键。
    jobs_terminal_style_query() {
        jobs_style_query_key=$1
        jobs_style_reply=''
        jobs_style_query_buffer=''
        jobs_style_query_target_reply=''
        jobs_style_query_target_normalized=''
        jobs_style_query_target_rgb=''
        jobs_style_query_st="${jobs_style_esc}\\"
        jobs_style_query_stale_count=0
        jobs_style_query_phase=${2:-strict}
        jobs_style_query_cr=$(printf '\r')
        jobs_style_query_lf=$(printf '\n.')
        jobs_style_query_lf=${jobs_style_query_lf%.}
        jobs_style_query_failure='未收到目标颜色的完整答复（最多 3 次查询，每次约 2 秒）'
        for jobs_style_query_round in 1 2 3; do
            printf '\033]%s;?\007' "$jobs_style_query_key" > /dev/tty || {
                jobs_style_query_failure='无法向原终端发送配色查询'
                return 1
            }
            for jobs_style_attempt in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
                # 哨兵保留末尾换行，不能把只有回车的键盘输入误当成无答复。
                jobs_style_piece=$(dd bs=256 count=1 2>/dev/null < /dev/tty; printf '.')
                jobs_style_piece=${jobs_style_piece%.}
                jobs_style_query_buffer=$jobs_style_query_buffer$jobs_style_piece
                while [ -n "$jobs_style_query_buffer" ]; do
                    # 设置核验与退出恢复阶段允许帧外的明确控制键，普通文字仍然失败。
                    if [ "$jobs_style_query_phase" = cleanup ] || [ "$jobs_style_query_phase" = applied ]; then
                        jobs_style_query_control_sequence=''
                        jobs_style_query_control_partial=0
                        case $jobs_style_query_buffer in
                            "$jobs_style_query_cr"*) jobs_style_query_control_sequence=$jobs_style_query_cr ;;
                            "$jobs_style_query_lf"*) jobs_style_query_control_sequence=$jobs_style_query_lf ;;
                        esac
                        if [ -z "$jobs_style_query_control_sequence" ]; then
                            for jobs_style_query_direction in A B C D; do
                                for jobs_style_query_control_candidate in \
                                    "${jobs_style_esc}[${jobs_style_query_direction}" \
                                    "${jobs_style_esc}O${jobs_style_query_direction}" \
                                    "${jobs_style_esc}[1;2${jobs_style_query_direction}" \
                                    "${jobs_style_esc}[1;3${jobs_style_query_direction}" \
                                    "${jobs_style_esc}[1;4${jobs_style_query_direction}" \
                                    "${jobs_style_esc}[1;5${jobs_style_query_direction}" \
                                    "${jobs_style_esc}[1;6${jobs_style_query_direction}" \
                                    "${jobs_style_esc}[1;7${jobs_style_query_direction}" \
                                    "${jobs_style_esc}[1;8${jobs_style_query_direction}"; do
                                    case $jobs_style_query_buffer in
                                        "$jobs_style_query_control_candidate"*)
                                            jobs_style_query_control_sequence=$jobs_style_query_control_candidate
                                            break 2
                                            ;;
                                    esac
                                    case $jobs_style_query_control_candidate in
                                        "$jobs_style_query_buffer"*) jobs_style_query_control_partial=1 ;;
                                    esac
                                done
                            done
                        fi
                        if [ -n "$jobs_style_query_control_sequence" ]; then
                            jobs_style_phase_control_keys=$(( ${jobs_style_phase_control_keys:-0} + 1 ))
                            if [ "$jobs_style_phase_control_keys" -gt 64 ]; then
                                jobs_style_query_failure='本阶段已识别控制键超过 64 个，已停止自动恢复'
                                return 1
                            fi
                            jobs_style_query_buffer=${jobs_style_query_buffer#"$jobs_style_query_control_sequence"}
                            continue
                        fi
                        if [ "$jobs_style_query_control_partial" = 1 ]; then
                            break
                        fi
                    fi
                    case $jobs_style_query_buffer in
                        "$jobs_style_esc"|"$jobs_style_esc]") break ;;
                        "$jobs_style_esc]"*) ;;
                        *) jobs_style_query_failure='收到非配色查询输入，已停止读取'; return 1 ;;
                    esac
                    jobs_style_query_head=''
                    jobs_style_query_terminator=''
                    case $jobs_style_query_buffer in
                        *"$jobs_style_bel"*)
                            jobs_style_query_head=${jobs_style_query_buffer%%"$jobs_style_bel"*}
                            jobs_style_query_terminator=$jobs_style_bel
                            ;;
                    esac
                    case $jobs_style_query_buffer in
                        *"$jobs_style_query_st"*)
                            jobs_style_query_st_head=${jobs_style_query_buffer%%"$jobs_style_query_st"*}
                            if [ -z "$jobs_style_query_terminator" ] ||
                               [ "${#jobs_style_query_st_head}" -lt "${#jobs_style_query_head}" ]; then
                                jobs_style_query_head=$jobs_style_query_st_head
                                jobs_style_query_terminator=$jobs_style_query_st
                            fi
                            ;;
                    esac
                    [ -n "$jobs_style_query_terminator" ] || break
                    jobs_style_query_frame=$jobs_style_query_head$jobs_style_query_terminator
                    jobs_style_query_buffer=${jobs_style_query_buffer#"$jobs_style_query_frame"}
                    jobs_style_query_body=${jobs_style_query_head#"$jobs_style_esc]"}
                    case $jobs_style_query_body in
                        *';rgb:'*) ;;
                        *) jobs_style_query_failure='配色答复格式或 RGB 数据无效'; return 1 ;;
                    esac
                    jobs_style_query_frame_key=${jobs_style_query_body%%';rgb:'*}
                    case $jobs_style_query_frame_key in
                        10|11|12|'4;'[0-9]|'4;1'[0-5]) ;;
                        *) jobs_style_query_failure='收到不属于本次颜色协议的答复'; return 1 ;;
                    esac
                    jobs_style_query_frame_rgb=${jobs_style_query_body#"$jobs_style_query_frame_key;rgb:"}
                    jobs_style_query_frame_normalized=$(printf '%s\n' "$jobs_style_query_frame_rgb" | LC_ALL=C awk -F/ '
                        BEGIN { valid = 1 }
                        NR != 1 || NF != 3 { valid = 0; exit }
                        {
                            for (i = 1; i <= 3; i++) {
                                h = tolower($i)
                                if (length(h) < 1 || length(h) > 4 || h ~ /[^0-9a-f]/) {
                                    valid = 0
                                    exit
                                }
                                n = 0
                                for (j = 1; j <= length(h); j++) n = n * 16 + index("0123456789abcdef", substr(h, j, 1)) - 1
                                value[i] = int(n * 65535 / (16 ^ length(h) - 1) + 0.5)
                            }
                        }
                        END {
                            if (!valid || NR != 1) exit 1
                            printf "%d/%d/%d", value[1], value[2], value[3]
                        }
                    ')
                    if [ -z "$jobs_style_query_frame_normalized" ]; then
                        jobs_style_query_failure='配色答复格式或 RGB 数据无效'
                        return 1
                    fi
                    if [ "$jobs_style_query_frame_key" = "$jobs_style_query_key" ]; then
                        if [ -n "$jobs_style_query_target_reply" ] &&
                           [ "$jobs_style_query_target_normalized" != "$jobs_style_query_frame_normalized" ]; then
                            jobs_style_query_failure='同一颜色的重复答复不一致，已停止自动恢复'
                            return 1
                        fi
                        jobs_style_query_target_reply=$jobs_style_query_frame
                        jobs_style_query_target_normalized=$jobs_style_query_frame_normalized
                        jobs_style_query_target_rgb=$jobs_style_query_frame_rgb
                    else
                        jobs_style_query_stale_count=$((jobs_style_query_stale_count + 1))
                        if [ "$jobs_style_query_stale_count" -gt 128 ]; then
                            jobs_style_query_failure='收到过多旧颜色答复，已停止读取'
                            return 1
                        fi
                    fi
                done
                if [ -n "$jobs_style_query_target_reply" ] && [ -z "$jobs_style_query_buffer" ]; then
                    jobs_style_reply=$jobs_style_query_target_reply
                    jobs_style_normalized=$jobs_style_query_target_normalized
                    jobs_style_rgb=$jobs_style_query_target_rgb
                    return 0
                fi
            done
            # 残缺帧不能通过重发拼成另一个答复，更不能被当成键盘空输入。
            if [ -n "$jobs_style_query_buffer" ]; then
                jobs_style_query_failure='配色答复帧不完整，已停止自动恢复'
                return 1
            fi
        done
        return 1
    }
    # 查询可用不代表终端允许改色，按目标值核对实际生效结果。
    jobs_terminal_style_accepts_target() {
        jobs_style_requested_hex=''
        case $1 in
            10|12) jobs_style_requested_hex=ffffff ;;
            11) jobs_style_requested_hex=000000 ;;
            '4;'*)
                jobs_style_requested_index=0
                for jobs_style_requested_color in 000000 ff5f56 5fd787 ffd75f 5fafff d787ff 5fd7ff eeeeee 9e9e9e ff8787 87ffaf ffff87 87bfff ffafff afffff ffffff; do
                    if [ "4;$jobs_style_requested_index" = "$1" ]; then
                        jobs_style_requested_hex=$jobs_style_requested_color
                        break
                    fi
                    jobs_style_requested_index=$((jobs_style_requested_index + 1))
                done
                ;;
        esac
        [ -n "$jobs_style_requested_hex" ] || return 1
        printf '%s|%s\n' "$jobs_style_normalized" "$jobs_style_requested_hex" | LC_ALL=C awk -F'|' '
            function hexbyte(h) {
                return (index("0123456789abcdef", substr(h, 1, 1)) - 1) * 16 + index("0123456789abcdef", substr(h, 2, 1)) - 1
            }
            {
                if (split($1, actual, "/") != 3 || length($2) != 6) exit 1
                for (i = 1; i <= 3; i++) {
                    difference = actual[i] - hexbyte(substr($2, i * 2 - 1, 2)) * 257
                    if (difference < -255 || difference > 255) exit 1
                }
            }
        '
    }
    # 核验中断时重新读取当前值，只撤回仍等于本轮目标值的颜色。
    jobs_terminal_style_rollback() {
        jobs_style_rollback_issue='无法读取或设置原终端输入模式'
        jobs_style_rollback_safe=''
        jobs_style_rollback_conflicts=''
        jobs_style_phase_control_keys=0
        jobs_style_stty=$(stty -g 2>/dev/null < /dev/tty) || jobs_style_stty=''
        if [ -n "$jobs_style_stty" ] && stty -echo -icanon min 0 time 1 2>/dev/null < /dev/tty; then
            jobs_style_query_active=1
            jobs_style_rollback_ok=1
            while IFS='|' read -r jobs_style_key jobs_style_original_normalized jobs_style_original; do
                [ -n "$jobs_style_key" ] || continue
                if ! jobs_terminal_style_query "$jobs_style_key" cleanup; then
                    jobs_style_rollback_ok=0
                    jobs_style_rollback_issue="回退颜色项 $jobs_style_key：$jobs_style_query_failure"
                    break
                fi
                if [ "$jobs_style_normalized" = "$jobs_style_original_normalized" ]; then
                    continue
                elif jobs_terminal_style_accepts_target "$jobs_style_key"; then
                    jobs_style_rollback_safe=$jobs_style_rollback_safe$jobs_style_original
                else
                    jobs_style_rollback_conflicts="$jobs_style_rollback_conflicts $jobs_style_key"
                fi
            done <<JOBS_STYLE_ROLLBACK
$jobs_style_original_rows
JOBS_STYLE_ROLLBACK
            stty "$jobs_style_stty" 2>/dev/null < /dev/tty || { jobs_style_rollback_ok=0; jobs_style_rollback_issue='无法恢复原终端输入模式'; }
            jobs_style_query_active=0
            if [ "$jobs_style_rollback_ok" = 1 ] && printf '%s\033[0m' "$jobs_style_rollback_safe" > /dev/tty; then
                if [ -z "$jobs_style_rollback_conflicts" ]; then
                    rm -f "$jobs_style_recovery"
                    rmdir "${jobs_style_recovery%/*}" 2>/dev/null || :
                    return 0
                fi
                printf '检测到运行期间的配色变更，已保留这些项：%s\n' "$jobs_style_rollback_conflicts" >&2
                jobs_style_rollback_issue="核验中断后检测到其它配色变更：$jobs_style_rollback_conflicts"
            fi
        fi
        printf '终端配色未能安全自动恢复（%s）；确认覆盖当前配色后可运行：sh "%s"\n' "$jobs_style_rollback_issue" "$jobs_style_recovery" >&2
        return 1
    }
    # 检测到后续改色时只恢复仍由本次保护持有的项，保留独立恢复入口。
    jobs_terminal_style_cleanup() {
        jobs_style_result=$1
        trap '' HUP INT TERM
        if [ "$jobs_style_query_active" = 1 ]; then
            stty "$jobs_style_stty" 2>/dev/null < /dev/tty || :
            jobs_style_query_active=0
        fi
        if [ "$jobs_style_changed" = 1 ] && [ "$jobs_style_applied_complete" != 1 ]; then
            if jobs_terminal_style_rollback; then
                jobs_style_changed=0
            else
                [ "$jobs_style_result" -ne 0 ] || jobs_style_result=1
            fi
            if [ "${2:-}" = continue ]; then
                jobs_style_cleanup_status=$jobs_style_result
                return 0
            fi
            exit "$jobs_style_result"
        fi
        if [ "$jobs_style_changed" = 1 ]; then
            jobs_style_cleanup_ok=0
            jobs_style_cleanup_issue='无法读取或设置原终端输入模式，或临时配色未完成核验'
            jobs_style_conflicts=''
            jobs_style_restore_safe=''
            jobs_style_phase_control_keys=0
            if [ "$jobs_style_applied_complete" = 1 ]; then
                jobs_style_stty=$(stty -g 2>/dev/null < /dev/tty) || jobs_style_stty=''
                if [ -n "$jobs_style_stty" ] && stty -echo -icanon min 0 time 1 2>/dev/null < /dev/tty; then
                    jobs_style_query_active=1
                    jobs_style_cleanup_ok=1
                    while IFS='|' read -r jobs_style_key jobs_style_expected jobs_style_original; do
                        [ -n "$jobs_style_key" ] || continue
                        if ! jobs_terminal_style_query "$jobs_style_key" cleanup; then
                            jobs_style_cleanup_ok=0
                            jobs_style_cleanup_issue="颜色项 $jobs_style_key：$jobs_style_query_failure"
                            break
                        fi
                        if [ "$jobs_style_normalized" = "$jobs_style_expected" ]; then
                            jobs_style_restore_safe=$jobs_style_restore_safe$jobs_style_original
                        else
                            jobs_style_conflicts="$jobs_style_conflicts $jobs_style_key"
                        fi
                    done <<JOBS_STYLE_APPLIED
$jobs_style_applied_rows
JOBS_STYLE_APPLIED
                    stty "$jobs_style_stty" 2>/dev/null < /dev/tty || { jobs_style_cleanup_ok=0; jobs_style_cleanup_issue='无法恢复原终端输入模式'; }
                    jobs_style_query_active=0
                fi
            fi
            if [ "$jobs_style_cleanup_ok" = 1 ] && printf '%s\033[0m' "$jobs_style_restore_safe" > /dev/tty; then
                if [ -z "$jobs_style_conflicts" ]; then
                    rm -f "$jobs_style_recovery"
                    rmdir "${jobs_style_recovery%/*}" 2>/dev/null || :
                else
                    printf '检测到运行期间的配色变更，已保留这些项：%s\n' "$jobs_style_conflicts" >&2
                    printf '确认要覆盖后续改色时才使用恢复入口：sh "%s"\n' "$jobs_style_recovery" >&2
                    [ "$jobs_style_result" -ne 0 ] || jobs_style_result=1
                fi
            else
                printf '终端配色未能安全自动恢复（%s）；确认覆盖当前配色后可运行：sh "%s"\n' "$jobs_style_cleanup_issue" "$jobs_style_recovery" >&2
                [ "$jobs_style_result" -ne 0 ] || jobs_style_result=1
            fi
        fi
        if [ "${2:-}" = continue ]; then
            jobs_style_cleanup_status=$jobs_style_result
            return 0
        fi
        exit "$jobs_style_result"
    }
    trap 'jobs_terminal_style_cleanup "$jobs_style_exit_status"' 0
    trap 'jobs_style_exit_status=129; jobs_terminal_style_cleanup 129 continue; jobs_style_changed=0; exit 129' HUP
    trap 'jobs_style_exit_status=130; jobs_terminal_style_cleanup 130 continue; jobs_style_changed=0; exit 130' INT
    trap 'jobs_style_exit_status=143; jobs_terminal_style_cleanup 143 continue; jobs_style_changed=0; exit 143' TERM
    if ! stty -echo -icanon min 0 time 1 2>/dev/null < /dev/tty; then
        jobs_terminal_style_plain "$@"
    fi
    jobs_style_query_active=1
    jobs_style_probe_ok=1
    for jobs_style_key in 10 11 12 '4;0' '4;1' '4;2' '4;3' '4;4' '4;5' '4;6' '4;7' '4;8' '4;9' '4;10' '4;11' '4;12' '4;13' '4;14' '4;15'; do
        if ! jobs_terminal_style_query "$jobs_style_key"; then
            jobs_style_probe_ok=0
            break
        fi
        jobs_style_saved=$jobs_style_saved$jobs_style_reply
        jobs_style_original_rows="$jobs_style_original_rows$jobs_style_key|$jobs_style_normalized|$jobs_style_reply
"
        jobs_style_saved_rows="$jobs_style_saved_rows$jobs_style_key|$jobs_style_reply
"
    done
    stty "$jobs_style_stty" 2>/dev/null < /dev/tty || { jobs_style_exit_status=1; exit 1; }
    jobs_style_query_active=0
    if [ "$jobs_style_probe_ok" != 1 ]; then
        printf '%s\n' '终端不支持完整配色保存，或启动时收到其它输入；保留原配色并使用纯文本。' >&2
        jobs_terminal_style_plain "$@"
    fi
    jobs_style_recovery_dir=$(umask 077; mktemp -d "${TMPDIR:-/tmp}/jobs-terminal-style.XXXXXX") || jobs_terminal_style_plain "$@"
    jobs_style_recovery=$jobs_style_recovery_dir/restore.sh
    if ! (umask 077; {
        printf '#!/bin/sh\n'
        printf '[ -t 0 ] && [ "$(tty)" = '\''%s'\'' ] || { printf '\''请在原终端运行恢复入口。\\n'\'' >&2; exit 1; }\n' "$jobs_style_tty"
        printf 'printf '\''本操作会覆盖此终端当前配色。确认恢复脚本启动前的配色，请输入 YES：'\'' >&2\n'
        printf 'IFS= read -r jobs_restore_choice\n[ "$jobs_restore_choice" = YES ] || exit 1\n'
        printf 'printf '\''%%s\\033[0m'\'' '\''%s'\'' > /dev/tty\n' "$jobs_style_saved"
    } > "$jobs_style_recovery"); then
        printf '%s\n' '无法保存终端配色恢复入口；保留原配色并使用纯文本。' >&2
        jobs_terminal_style_plain "$@"
    fi
    printf '正在准备本次终端临时配色；强退后恢复入口：sh "%s"\n' "$jobs_style_recovery" >&2
    jobs_style_changed=1
    printf '\033]10;#ffffff\007\033]11;#000000\007\033]12;#ffffff\007' > /dev/tty
    jobs_style_index=0
    for jobs_style_color in 000000 ff5f56 5fd787 ffd75f 5fafff d787ff 5fd7ff eeeeee 9e9e9e ff8787 87ffaf ffff87 87bfff ffafff afffff ffffff; do
        printf '\033]4;%s;#%s\007' "$jobs_style_index" "$jobs_style_color" > /dev/tty
        jobs_style_index=$((jobs_style_index + 1))
    done
    printf '\033[0m' > /dev/tty
    jobs_style_stty=$(stty -g 2>/dev/null < /dev/tty) || { jobs_style_exit_status=1; exit 1; }
    stty -echo -icanon min 0 time 1 2>/dev/null < /dev/tty || { jobs_style_exit_status=1; exit 1; }
    jobs_style_query_active=1
    jobs_style_probe_ok=1
    jobs_style_targets_ok=1
    jobs_style_phase_control_keys=0
    while IFS='|' read -r jobs_style_key jobs_style_original; do
        [ -n "$jobs_style_key" ] || continue
        if ! jobs_terminal_style_query "$jobs_style_key" applied; then
            jobs_style_probe_ok=0
            break
        fi
        jobs_style_applied_rows="$jobs_style_applied_rows$jobs_style_key|$jobs_style_normalized|$jobs_style_original
"
        if ! jobs_terminal_style_accepts_target "$jobs_style_key"; then
            jobs_style_targets_ok=0
        fi
    done <<JOBS_STYLE_ORIGINAL
$jobs_style_saved_rows
JOBS_STYLE_ORIGINAL
    stty "$jobs_style_stty" 2>/dev/null < /dev/tty || { jobs_style_exit_status=1; exit 1; }
    jobs_style_query_active=0
    if [ "$jobs_style_probe_ok" != 1 ]; then
        printf '临时配色核验失败（颜色项 %s：%s），正在核对原色恢复。\n' "$jobs_style_key" "$jobs_style_query_failure" >&2
        jobs_terminal_style_cleanup 0 continue
        jobs_style_changed=0
        if [ "$jobs_style_cleanup_status" != 0 ]; then
            jobs_style_exit_status=1
            exit 1
        fi
        trap 'jobs_style_exit_status=129; jobs_terminal_style_cleanup 129 continue; jobs_style_changed=0; exit 129' HUP
        trap 'jobs_style_exit_status=130; jobs_terminal_style_cleanup 130 continue; jobs_style_changed=0; exit 130' INT
        trap 'jobs_style_exit_status=143; jobs_terminal_style_cleanup 143 continue; jobs_style_changed=0; exit 143' TERM
        printf '%s\n' '已恢复原配色并使用纯文本。' >&2
        jobs_terminal_style_plain "$@"
    fi
    if [ "$jobs_style_targets_ok" != 1 ]; then
        jobs_terminal_style_cleanup 0 continue
        jobs_style_changed=0
        if [ "$jobs_style_cleanup_status" != 0 ]; then
            jobs_style_exit_status=1
            exit 1
        fi
        trap 'jobs_style_exit_status=129; jobs_terminal_style_cleanup 129 continue; jobs_style_changed=0; exit 129' HUP
        trap 'jobs_style_exit_status=130; jobs_terminal_style_cleanup 130 continue; jobs_style_changed=0; exit 130' INT
        trap 'jobs_style_exit_status=143; jobs_terminal_style_cleanup 143 continue; jobs_style_changed=0; exit 143' TERM
        printf '%s\n' '终端未接受本次配色，已恢复原配色并使用纯文本。' >&2
        jobs_terminal_style_plain "$@"
    fi
    jobs_style_applied_complete=1
    printf '%s\n' '本次终端已临时使用黑底白字。' >&2
    JOBS_TERMINAL_STYLE_TTY=$jobs_style_tty
    JOBS_TERMINAL_STYLE_OWNER=$$
    export JOBS_TERMINAL_STYLE_TTY JOBS_TERMINAL_STYLE_OWNER
    if "$@"; then
        jobs_style_exit_status=0
    else
        jobs_style_exit_status=$?
    fi
    exit "$jobs_style_exit_status"
}
# 仅监督直接执行的入口；被 source 时不切换配色、不重新执行业务。
jobs_terminal_style_bootstrap() {
    jobs_style_bootstrap_script=$1
    shift
    # 默认预览及只读动作不创建终端恢复材料。
    jobs_style_write=0
    for jobs_style_arg in "$@"; do
        case "$jobs_style_arg" in --install|--uninstall) jobs_style_write=1 ;; esac
    done
    [ "$jobs_style_write" = 1 ] || return 0
    if [ -n "${ZSH_VERSION:-}" ]; then
        case ${ZSH_EVAL_CONTEXT:-} in
            *:file|*:file:*) return 0 ;;
        esac
    elif [ -n "${BASH_VERSION:-}" ] && [ "${BASH_SOURCE:-$jobs_style_bootstrap_script}" != "$jobs_style_bootstrap_script" ]; then
        return 0
    fi
    if [ "${JOBS_TERMINAL_STYLE_REEXEC:-}" = "$jobs_style_bootstrap_script" ]; then
        unset JOBS_TERMINAL_STYLE_REEXEC
        return 0
    fi
    if [ ! -t 0 ] || [ ! -t 1 ] || [ -z "${TERM:-}" ] ||
       [ "${TERM:-}" = dumb ] || [ "${NO_COLOR+x}" = x ] ||
       [ "${PLAIN_OUTPUT:-0}" = 1 ] || [ "${IS_SOURCETREE_RUNTIME:-0}" = 1 ] ||
       [ -n "${TMUX:-}${STY:-}" ] ||
       env | LC_ALL=C grep -qiE '^(SOURCETREE|SOURCE_TREE)'; then
        return 0
    fi
    case ${JOBS_TERMINAL_STYLE_OWNER:-} in
        ''|*[!0-9]*) ;;
        *)
            if kill -0 "$JOBS_TERMINAL_STYLE_OWNER" 2>/dev/null &&
               [ "${JOBS_TERMINAL_STYLE_TTY:-}" = "$(tty 2>/dev/null)" ]; then
                return 0
            fi
            ;;
    esac
    JOBS_TERMINAL_STYLE_REEXEC=$jobs_style_bootstrap_script
    export JOBS_TERMINAL_STYLE_REEXEC
    jobs_terminal_style_run /bin/sh "$jobs_style_bootstrap_script" "$@"
    jobs_style_bootstrap_result=$?
    exit "$jobs_style_bootstrap_result"
}
jobs_terminal_style_bootstrap "$0" "$@"
# <<< Jobs terminal style protection v1 <<<

PLATFORM='Alpine'
DISTRO='alpine'
MANAGER='apk'
STATE_ROOT='/var/lib/jobs-new-system/Alpine'
MODE=plan
COMPONENTS=''
YES=0
REPAIR=1
LOG_FILE=''
LOCK_HELD=0
OUTCOME=0
APT_INDEX_READY=0
CURRENT_PENDING=''
# 先解释影响，只有显式写入参数才进入确认。
show_script_intro_and_wait() {
    printf '%s\n' "Jobs ${PLATFORM} 新系统配置" '用途：按组件补齐本系统开发工具；默认仅预览，不会安装。' '影响：显式安装/卸载会改变系统软件包；不升级全系统，不改默认Shell、代理或防火墙。' "写操作收据及日志：${STATE_ROOT}；Ctrl+C 取消。"
    intro_write=0
    intro_yes=0
    for intro_arg in "$@"; do
        case "${intro_arg}" in --install|--uninstall) intro_write=1 ;; --yes) intro_yes=1 ;; esac
    done
    [ "${intro_write}" = 1 ] || return 0
    [ "${intro_yes}" = 1 ] && return 0
    [ -t 0 ] && [ -t 1 ] || { printf '%s\n' '需要终端确认；自动化须明确传 --yes 和 --components。' >&2; exit 2; }
    printf '%s' '已了解用途，回车查看本次计划；其它输入取消：'
    IFS= read -r intro_answer || exit 130
    [ -z "${intro_answer}" ] || exit 0
}
# 校验单一动作与显式组件，拒绝未知、空项和参数冲突。
parse_arguments() {
    action_seen=''
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --plan|--install|--uninstall|--list|--help)
                [ -z "${action_seen}" ] || fail '一次只能指定一个操作。'
                MODE=${1#--}; action_seen=${MODE} ;;
            --components)
                [ "$#" -ge 2 ] || fail '--components 缺少值。'
                [ -z "${COMPONENTS}" ] || fail '不能重复指定组件。'
                COMPONENTS=$2; shift ;;
            --components=*)
                [ -z "${COMPONENTS}" ] || fail '不能重复指定组件。'
                COMPONENTS=${1#*=} ;;
            --yes) YES=1 ;;
            --repair) REPAIR=1 ;;
            *) fail "未知参数：$1" ;;
        esac
        shift
    done
    case "${COMPONENTS}" in ,*|*,|*,,*|*[!a-z,-]*) fail '组件必须是以逗号分隔的有效ID。' ;; esac
    selected_ids=$(printf '%s' "${COMPONENTS}" | tr ',' ' ')
    for selected_id in ${selected_ids}; do packages_for "${selected_id}" >/dev/null || fail "未知组件：${selected_id}"; done
    case "${MODE}" in
        install|uninstall) [ -n "${COMPONENTS}" ] || fail '写操作必须显式选择 --components，绝不默认全选。' ;;
    esac
}
# 给出固定ID到当前发行版官方软件源包名的映射。
packages_for() {
    case "$1" in
        git|git-lfs|curl|wget|zsh|fzf) printf '%s\n' "$1" ;;
        build)
            case "${MANAGER}" in apt) printf '%s\n' 'build-essential pkg-config' ;; dnf) printf '%s\n' 'gcc gcc-c++ make pkgconf-pkg-config' ;; apk) printf '%s\n' 'build-base pkgconf' ;; pkg) printf '%s\n' 'gmake pkgconf' ;; esac ;;
        python)
            case "${MANAGER}" in apt) printf '%s\n' 'python3 python3-venv python3-pip' ;; dnf) printf '%s\n' 'python3 python3-pip' ;; apk) printf '%s\n' 'python3 py3-pip' ;; pkg) printf '%s\n' 'python3' ;; esac ;;
        node)
            case "${MANAGER}" in pkg) printf '%s\n' 'node npm' ;; *) printf '%s\n' 'nodejs npm' ;; esac ;;
        *) return 1 ;;
    esac
}
# 展示帮助与组件目录，不访问网络或落盘。
show_help_or_list() {
    case "${MODE}" in
        help)
            printf '%s\n' '用法：sh 本脚本 [--plan|--list|--install|--uninstall] [--components git,curl] [--yes] [--repair]' '默认 --plan；--list 展示包映射；安装只补缺或定向修复所选不健康组件；--repair为兼容参数。' '写操作需要root；无fzf的新系统可显式 --yes；不加--yes时使用默认取消的fzf确认。' '卸载只处理新装且版本未变的收据包；无归属、版本变化或依赖受影响时保留并返回非零。'
            exit 0 ;;
        list)
            printf 'ID\t系统软件包\n'
            for catalog_id in git git-lfs curl wget zsh fzf build python node; do printf '%s\t%s\n' "${catalog_id}" "$(packages_for "${catalog_id}")"; done
            exit 0 ;;
    esac
}
# 错误保留日志并传递非零退出码。
fail() {
    printf '错误：%s\n' "$*" >&2
    if [ -n "${LOG_FILE}" ]; then printf '错误：%s\n' "$*" >> "${LOG_FILE}"; fi
    exit 1
}
# 仅解析发行标记为数据，不能执行os-release内容。
check_platform() {
    actual_os=$(uname -s) || fail '无法读取系统类型。'
    if [ "${PLATFORM}" = FreeBSD ]; then
        [ "${actual_os}" = FreeBSD ] || fail '请使用与当前系统匹配的平台入口。'
    else
        [ "${actual_os}" = Linux ] || fail '请使用与当前系统匹配的平台入口。'
        [ -r "/etc/os-release" ] || fail '缺少 /etc/os-release。'
        actual_distro=$(awk -F= '$1 == "ID" { value=$2; gsub(/["\047]/,"",value); print value; exit }' "/etc/os-release")
        [ "${actual_distro}" = "${DISTRO}" ] || fail "当前发行版 ${actual_distro} 与 ${PLATFORM} 不匹配。"
    fi
    case "$(uname -m)" in x86_64|amd64|aarch64|arm64) ;; *) fail '本入口当前仅面向x64和ARM64，其他架构待验。' ;; esac
}
# 沿目标包管理器链做运行检查，不为查询安装依赖。
check_manager() {
    case "${MANAGER}" in apt) manager_tools='apt-get dpkg dpkg-query' ;; dnf) manager_tools='dnf rpm' ;; apk) manager_tools='apk' ;; pkg) manager_tools='pkg' ;; esac
    for manager_tool in ${manager_tools}; do
        command -v "${manager_tool}" >/dev/null 2>&1 || fail "缺少系统原生工具：${manager_tool}；请先修复系统软件源/包管理器。"
    done
    case "${MANAGER}" in
        apt) apt-get --version >/dev/null 2>&1 && dpkg-query --version >/dev/null 2>&1 ;;
        dnf) dnf --version >/dev/null 2>&1 && rpm --version >/dev/null 2>&1 ;;
        apk) apk --version >/dev/null 2>&1 ;;
        pkg) pkg -N >/dev/null 2>&1 && pkg -v >/dev/null 2>&1 ;;
    esac || fail '系统包管理器不健康；未执行下游安装。'
}
# 返回精确已安装版本；多版本或异常状态均不作为可卸载依据。
package_version() {
    case "${MANAGER}" in
        apt) dpkg-query -W -f='${db:Status-Status}\t${Version}\n' "$1" 2>/dev/null | awk -F '\t' '$1 == "installed" { print $2 }' ;;
        dnf) version_query=$(rpm -q --qf '%{EPOCHNUM}:%{VERSION}-%{RELEASE}.%{ARCH}\n' "$1" 2>/dev/null) || return 1; printf '%s\n' "${version_query}" ;;
        apk) apk info -e "$1" >/dev/null 2>&1 || return 1; apk info -v "$1" 2>/dev/null | sed -n "s/^$1-//p" ;;
        pkg) version_query=$(pkg query '%v' "$1" 2>/dev/null) || return 1; printf '%s\n' "${version_query}" ;;
    esac
}
# 版本非空且单行，防止多架构同名包被合并删除。
valid_version() {
    [ -n "$1" ] || return 1
    case "$1" in *'
'*|*'\t'*) return 1 ;; esac
    return 0
}
# 用当前命令实际启动验证组件，保留本机既有健康环境。
component_healthy() {
    case "$1" in
        git) git --version >/dev/null 2>&1 ;;
        git-lfs) git-lfs version >/dev/null 2>&1 ;;
        curl) curl --version >/dev/null 2>&1 ;;
        wget) wget --version >/dev/null 2>&1 ;;
        zsh) zsh -f -c ':' >/dev/null 2>&1 ;;
        fzf) fzf --version >/dev/null 2>&1 ;;
        build)
            case "${MANAGER}" in pkg) cc --version >/dev/null 2>&1 && gmake --version >/dev/null 2>&1 ;; *) cc --version >/dev/null 2>&1 && make --version >/dev/null 2>&1 ;; esac && pkg-config --version >/dev/null 2>&1 ;;
        python) python3 -c 'import ssl, venv; print(1)' >/dev/null 2>&1 || return 1; [ "${MANAGER}" = pkg ] || python3 -m pip --version >/dev/null 2>&1 ;;
        node) node -e 'process.exit(0)' >/dev/null 2>&1 && npm --version >/dev/null 2>&1 ;;
        *) return 1 ;;
    esac
}
# 生成只读计划，不创建日志、锁或收据。
show_plan() {
    [ -n "${selected_ids}" ] || selected_ids='git git-lfs curl wget zsh fzf build python node'
    printf '\n平台：%s；包管理器：%s；动作：%s\n' "${PLATFORM}" "${MANAGER}" "${MODE}"
    for plan_id in ${selected_ids}; do
        if component_healthy "${plan_id}"; then plan_health=健康; else plan_health=缺失或不健康; fi
        printf '%s | %s | 包：%s\n' "${plan_id}" "${plan_health}" "$(packages_for "${plan_id}")"
    done
    printf '%s\n' '来源：当前系统已配置并受包管理器校验的软件源（下载地址由包管理器解析）；不会改源。' '安装可能保留新增依赖；卸载只撤回明确归属的直接包，不等同恢复整个系统。'
}
# 无显式自动化授权时，确认菜单默认取消，选择器故障不执行。
confirm_write() {
    [ "${MODE}" = install ] || [ "${MODE}" = uninstall ] || exit 0
    [ "${YES}" = 1 ] && return 0
    [ -t 0 ] && [ -t 1 ] || fail '写操作需要交互确认或显式 --yes。'
    command -v fzf >/dev/null 2>&1 && fzf --version >/dev/null 2>&1 || fail '新系统缺少健康fzf；审阅计划后可显式用 --yes 执行所选组件。'
    confirm_choice=$(printf '%s\n' '取消本轮' '执行本次系统包操作' | FZF_DEFAULT_COMMAND='' FZF_DEFAULT_OPTS='' FZF_DEFAULT_OPTS_FILE='' fzf --no-multi --bind='up:up,down:down,tab:down,shift-tab:up,esc:abort' --header='↑/↓ 或 Tab 选择，回车确认；默认取消') || exit 130
    [ "${confirm_choice}" = '执行本次系统包操作' ] || exit 0
}
# 检查状态目录原点与权限，拒绝链接和其它用户可写目录。
safe_state_directory() {
    [ ! -L "$1" ] || fail "状态路径不能是链接：$1"
    if [ ! -e "$1" ]; then mkdir -m 700 "$1" || fail "无法创建状态目录：$1"; fi
    [ -d "$1" ] || fail "状态路径不是目录：$1"
    if [ "${PLATFORM}" = FreeBSD ]; then state_owner=$(stat -f '%u' "$1"); state_mode=$(stat -f '%Lp' "$1"); else state_owner=$(stat -c '%u' "$1"); state_mode=$(stat -c '%a' "$1"); fi
    [ "${state_owner}" = 0 ] || fail "状态目录必须归root所有：$1"
    case "${state_mode}" in 700|750|755) ;; *) fail "状态目录权限不安全：$1 (${state_mode})" ;; esac
}
# 授权之后才建立私有全局状态和本轮互斥。
initialize_write_runtime() {
    [ "$(id -u)" = 0 ] || fail '系统软件包写操作需要root；请由用户显式使用sudo运行本入口。'
    umask 077
    safe_state_directory "$(dirname "${STATE_ROOT}")"
    safe_state_directory "${STATE_ROOT}"
    safe_state_directory "${STATE_ROOT}/receipts"
    safe_state_directory "${STATE_ROOT}/logs"
    mkdir "${STATE_ROOT}/operation.lock" 2>/dev/null || fail "已有操作或遗留锁：${STATE_ROOT}/operation.lock；请核对原操作后手动处理，不会抢锁。"
    LOCK_HELD=1
    printf '%s\n' "$$" > "${STATE_ROOT}/operation.lock/pid" || fail '无法登记锁。'
    trap 'finish_runtime' 0
    trap 'exit 129' HUP
    trap 'exit 130' INT
    trap 'exit 143' TERM
    LOG_FILE=$(mktemp "${STATE_ROOT}/logs/run.XXXXXXXX") || fail '无法创建日志。'
    log "开始 ${MODE}；平台 ${PLATFORM}；组件 ${COMPONENTS}"
}
# 仅释放本进程持有的锁，业务退出码保持原样。
finish_runtime() {
    finish_code=$?
    trap - 0
    if [ "${LOCK_HELD}" = 1 ] && [ ! -L "${STATE_ROOT}/operation.lock" ] && [ "$(cat "${STATE_ROOT}/operation.lock/pid" 2>/dev/null)" = "$$" ]; then
        rm -f "${STATE_ROOT}/operation.lock/pid"
        rmdir "${STATE_ROOT}/operation.lock" || printf '%s\n' '警告：锁目录未能清理，请核对。' >&2
    fi
    [ -z "${LOG_FILE}" ] || printf '退出码：%s；日志：%s\n' "${finish_code}" "${LOG_FILE}" >&2
    exit "${finish_code}"
}
# 日志只保存纯文本，不记录环境和源认证信息。
log() {
    printf '%s\n' "$*" >&2
    printf '%s\n' "$*" >> "${LOG_FILE}" || fail '日志写入失败。'
}
# 外部包管理器输出保留在私有日志并正确传递业务失败。
run_package_command() {
    log "系统软件源操作：$*；下载地址由本机包管理器解析。"
    command_status=$(mktemp "${STATE_ROOT}/logs/.command-status.XXXXXXXX") || fail '无法创建命令退出码记录。'
    { LC_ALL=C "$@" 2>&1; printf '%s\n' "$?" > "${command_status}"; } | tee -a "${LOG_FILE}"
    tee_code=$?
    package_code=$(cat "${command_status}") || fail '无法读取命令退出码。'
    rm "${command_status}" || fail '无法清理命令状态。'
    [ "${tee_code}" = 0 ] || fail '包管理器日志输出失败。'
    case "${package_code}" in ''|*[!0-9]*) fail '包管理器退出码无效。' ;; esac
    return "${package_code}"
}
# 记录正在新增的直接包；失败或中断后不猜测已装版本。
write_receipt() {
    receipt_file="${STATE_ROOT}/receipts/$1"
    [ ! -L "${receipt_file}" ] || fail '收据不能是链接。'
    receipt_temp=$(mktemp "${STATE_ROOT}/receipts/.new.XXXXXXXX") || fail '收据临时文件创建失败。'
    printf 'jobs-new-system-v1\t%s\t%s\t%s\t%s\n' "${PLATFORM}" "$1" "$2" "$3" > "${receipt_temp}" || fail '收据写入失败。'
    mv "${receipt_temp}" "${receipt_file}" || fail '收据发布失败。'
}
# 安装或修复单个直接包，禁止借安装执行全系统升级。
install_package() {
    if [ "${MANAGER}" = apt ] && [ "${APT_INDEX_READY}" = 0 ]; then
        run_package_command apt-get update || fail '系统软件源索引更新失败；未继续安装。'
        APT_INDEX_READY=1
    fi
    case "${MANAGER}:$2" in
        apt:new) run_package_command apt-get install -y --no-upgrade --no-install-recommends "$1" ;;
        apt:repair) run_package_command apt-get install -y --reinstall --no-upgrade --no-install-recommends "$1" ;;
        dnf:new) run_package_command dnf install -y --setopt=install_weak_deps=False "$1" ;;
        dnf:repair) run_package_command dnf reinstall -y "$1" ;;
        apk:new) run_package_command apk add --no-cache "$1" ;;
        apk:repair) run_package_command apk fix "$1" ;;
        pkg:new) run_package_command pkg install -y "$1" ;;
        pkg:repair) run_package_command pkg install -f -y "$1" ;;
    esac
}
# 为本轮全部显式直接包先记原状态，区分顺带装好的目标与普通传递依赖。
snapshot_selected_packages() {
    snapshot_packages=''
    for snapshot_id in ${selected_ids}; do
        if ! component_healthy "${snapshot_id}"; then snapshot_packages="${snapshot_packages} $(packages_for "${snapshot_id}")"; fi
    done
    for snapshot_pkg in $(printf '%s\n' ${snapshot_packages} | awk '!seen[$0]++'); do
        snapshot_version=$(package_version "${snapshot_pkg}")
        if valid_version "${snapshot_version}"; then continue; fi
        snapshot_receipt="${STATE_ROOT}/receipts/${snapshot_pkg}"
        snapshot_expected=$(printf 'jobs-new-system-v1\t%s\t%s\tpending\t-' "${PLATFORM}" "${snapshot_pkg}")
        if [ -e "${snapshot_receipt}" ]; then
            [ ! -L "${snapshot_receipt}" ] && [ "$(cat "${snapshot_receipt}")" = "${snapshot_expected}" ] || fail "旧收据需核对：${snapshot_pkg}"
        else write_receipt "${snapshot_pkg}" pending '-'; fi
        CURRENT_PENDING="${CURRENT_PENDING} ${snapshot_pkg}"
    done
}
# 将本轮最初缺失、后来作为其它目标依赖装好的显式包补齐版本收据。
record_completed_pending_for() {
    for completed_pkg in $(packages_for "$1"); do
        case " ${CURRENT_PENDING} " in *" ${completed_pkg} "*) ;; *) continue ;; esac
        completed_path="${STATE_ROOT}/receipts/${completed_pkg}"
        completed_expected=$(printf 'jobs-new-system-v1\t%s\t%s\tpending\t-' "${PLATFORM}" "${completed_pkg}")
        if [ -f "${completed_path}" ] && [ ! -L "${completed_path}" ] && [ "$(cat "${completed_path}")" = "${completed_expected}" ]; then
            completed_version=$(package_version "${completed_pkg}")
            if valid_version "${completed_version}"; then write_receipt "${completed_pkg}" installed "${completed_version}"; fi
        fi
    done
}
# 仅补缺并自动修复所选组件，既有健康环境不重装。
install_components() {
    snapshot_selected_packages
    for install_id in ${selected_ids}; do
        record_completed_pending_for "${install_id}"
        if component_healthy "${install_id}"; then log "复用健康组件：${install_id}"; continue; fi
        install_packages=$(packages_for "${install_id}") || fail '组件映射缺失。'
        for install_pkg in ${install_packages}; do
            if [ "${MANAGER}" = dnf ] && [ "${install_pkg}" = npm ] && npm --version >/dev/null 2>&1; then log '复用由nodejs提供的健康npm。'; continue; fi
            before_version=$(package_version "${install_pkg}")
            if valid_version "${before_version}"; then
                record_completed_pending_for "${install_id}"
                if [ "${REPAIR}" = 1 ]; then
                    log "定向修复已安装包 ${install_pkg}；原版本 ${before_version}；既有包不取得卸载归属。"
                    install_package "${install_pkg}" repair || fail "修复失败：${install_pkg}"
                else
                    log "保留已安装包：${install_pkg} (${before_version})；组件不健康时使用 --repair。"
                fi
                continue
            fi
            if [ -e "${STATE_ROOT}/receipts/${install_pkg}" ]; then
                pending_expected=$(printf 'jobs-new-system-v1\t%s\t%s\tpending\t-' "${PLATFORM}" "${install_pkg}")
                [ ! -L "${STATE_ROOT}/receipts/${install_pkg}" ] && [ "$(cat "${STATE_ROOT}/receipts/${install_pkg}")" = "${pending_expected}" ] || fail "存在旧收据而包状态不明：${install_pkg}；请核对，不会覆盖归属。"
                log "重试此前未完成且仍未安装的直接包：${install_pkg}"
            fi
            write_receipt "${install_pkg}" pending '-' || fail '无法登记原状态。'
            install_code=0
            install_package "${install_pkg}" new || install_code=$?
            hash -r 2>/dev/null || :
            after_version=$(package_version "${install_pkg}")
            if valid_version "${after_version}"; then write_receipt "${install_pkg}" installed "${after_version}"; fi
            [ "${install_code}" = 0 ] || fail "安装失败：${install_pkg}；已发生变化保留在收据/日志，不会盲目续行。"
            valid_version "${after_version}" || fail "安装后包复检失败：${install_pkg}"
            log "新装完成：${install_pkg} (${after_version})"
        done
        hash -r 2>/dev/null || :
        record_completed_pending_for "${install_id}"
        component_healthy "${install_id}" || fail "组件复检失败：${install_id}；请核对日志和PATH，可用 --repair 定向修复。"
        log "组件已通过运行检查：${install_id}"
    done
}
# 通过系统原生精确删除或严格模拟，禁止自动移除依赖。
remove_package_safely() {
    case "${MANAGER}" in
        apt) run_package_command dpkg --remove "$1" ;;
        dnf) run_package_command rpm -e "$1" ;;
        apk)
            removal_plan=$(apk --simulate del "$1" 2>&1) || return 1
            printf '%s\n' "${removal_plan}" >> "${LOG_FILE}"
            purge_list=$(printf '%s\n' "${removal_plan}" | awk '/\) Purging / {print $3}')
            other_changes=$(printf '%s\n' "${removal_plan}" | awk '/^\([0-9]+\/[0-9]+\)/ && $2 != "Purging" {print}')
            [ "${purge_list}" = "$1" ] && [ -z "${other_changes}" ] || { log "保留 $1：apk模拟会连带依赖或输出无法确认。"; return 1; }
            run_package_command apk del "$1" ;;
        pkg)
            reverse_dependencies=$(pkg query '%?r' "$1") || return 1
            [ "${reverse_dependencies}" = 0 ] || { log "保留 $1：仍有反向依赖。"; return 1; }
            run_package_command pkg -o AUTOREMOVE=false delete -y "$1" ;;
    esac
}
# 只卸载收据仍匹配的直接包；无收据或后续升级均保留并报告未完成。
uninstall_components() {
    uninstall_packages=''
    for uninstall_id in ${selected_ids}; do uninstall_packages="${uninstall_packages} $(packages_for "${uninstall_id}")"; done
    for uninstall_pkg in $(printf '%s\n' ${uninstall_packages} | awk '!seen[$0]++ { lines[++count]=$0 } END { for (i=count;i>0;i--) print lines[i] }'); do
        receipt_path="${STATE_ROOT}/receipts/${uninstall_pkg}"
        if [ ! -f "${receipt_path}" ] || [ -L "${receipt_path}" ]; then log "保留 ${uninstall_pkg}：没有可核对归属的收据。"; OUTCOME=1; continue; fi
        receipt_expected=$(cat "${receipt_path}") || fail '无法读取收据。'
        receipt_version=$(printf '%s\n' "${receipt_expected}" | awk -F '\t' -v platform="${PLATFORM}" -v package="${uninstall_pkg}" 'NF == 5 && $1 == "jobs-new-system-v1" && $2 == platform && $3 == package && $4 == "installed" {print $5}')
        current_version=$(package_version "${uninstall_pkg}")
        if ! valid_version "${receipt_version}" || [ "${receipt_version}" != "${current_version}" ]; then log "保留 ${uninstall_pkg}：收据未完成、版本变更或包状态异常。"; OUTCOME=1; continue; fi
        remove_code=0
        remove_package_safely "${uninstall_pkg}" || remove_code=$?
        remaining_version=$(package_version "${uninstall_pkg}")
        if [ "${remove_code}" = 0 ] && [ -z "${remaining_version}" ]; then
            [ "$(cat "${receipt_path}")" = "${receipt_expected}" ] || fail '收据被并发修改，保留现场。'
            rm "${receipt_path}" || fail '不能撤回已完成收据。'
            log "已卸载本工具新装的直接包：${uninstall_pkg}；依赖和原配置按包管理器保留。"
        else log "保留/卸载未完成：${uninstall_pkg}；可能仍被依赖，请见日志。"; OUTCOME=1; fi
    done
    return "${OUTCOME}"
}
# 执行已确认的唯一动作，失败不能被成功提示覆盖。
run_selected_action() {
    case "${MODE}" in install) install_components ;; uninstall) uninstall_components || exit "$?" ;; esac
    log '本轮所选组件处理完成；不代表系统全部环境已配置。'
}
# 只在授权之后编排系统包写操作。
main() {
    show_script_intro_and_wait "$@" # 先展示用途与影响，写操作未授权时只看计划。
    parse_arguments "$@" # 校验唯一动作与显式组件。
    show_help_or_list # 帮助和目录查询不接触系统包状态。
    check_platform # 拒绝错误系统和发行版。
    check_manager # 只检查当前链需要的系统原生工具。
    show_plan # 展示组件状态与实际软件源边界。
    confirm_write # 默认仅预览，写操作另行确认。
    initialize_write_runtime # 授权之后获取锁并创建日志。
    run_selected_action # 处理已选择组件并保留真实退出码。
}
main "$@"

#!/bin/zsh
# 脚本自述：
# - 脚本名称：【MacOS】环境管理后端.command
# - 核心用途：为新系统配置面板提供组件盘点、安装计划、受管安装与反安装。
# - 影响范围：仅处理明确选择的组件；收据保存在当前用户 Application Support。
# - 运行提示：查询不写入；写操作必须显式 --yes，终端多选卸载使用配套入口。
# shell: zsh

ENTRY_FILE="${0:A}"
PACKAGE_DIR=""
CONFIG_ROOT=""
STATE_DIR=""
LOG_FILE=""
LOCK_DIR=""
LOCK_OWNER_TOKEN=""
ACTION=""
DRY_RUN=0
APPROVED=0
BREW_LOCATION=""
BREW_BIN=""
NODE_BIN=""
NPM_BIN=""
NODE_FAILURE=""
NODE_PROVIDER=""
NODE_ATTEMPTED=""
ACTIVE_CONSUMER=""
STOP_REQUEST_FILE=""
STOP_OBSERVED=0
NETWORK_OUTPUT=""
BREW_EXTERNAL_RECOVERED=0
typeset -A REPAIRED_FORMULAE=()
typeset -a SELECTED=()
typeset -a COMPONENT_IDS=()
typeset -A COMPONENT_NAMES=()
typeset -A COMPONENT_DESCRIPTIONS=()
typeset -A RECEIPT=()
RESULT_CODE=0

# 只读参数在 stdout 保持纯 TSV，其余说明与业务统一写入日志。
show_intro() {
    [[ "$ACTION" == catalog || "$ACTION" == status ]] && return 0
    print -r -- '新系统组件安装与反安装'
    print -r -- '用途：执行已选组件，并沿所选依赖链自动补齐、定向修复和复检；不自动接受系统协议。'
    print -r -- '写操作需要 --yes；--dry-run 仅显示计划。Ctrl+C 取消后可按收据重试。'
    print -r -- '日志：写事务开始后显示独立日志路径；查询和计划不创建日志。'
}

# 以自身目录定位资源，禁止依赖启动工作目录。
initialize_paths() {
    setopt NO_NOMATCH PIPE_FAIL EXTENDED_GLOB
    PACKAGE_DIR="${ENTRY_FILE:h:h}"
    CONFIG_ROOT="${PACKAGE_DIR:h:h:h}"
    STATE_DIR="$HOME/Library/Application Support/JobsSystemSetup"
    LOG_FILE=""
    export HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_INSTALL_CLEANUP=1
    export NO_COLOR=1 CI=1 GIT_TERMINAL_PROMPT=0
}

add_component() {
    COMPONENT_IDS+=("$1")
    COMPONENT_NAMES[$1]="$2"
    COMPONENT_DESCRIPTIONS[$1]="$3"
}

# 组件 ID 是协议，不包含目录路径；Python 的两个别名仅显示一项。
initialize_catalog() {
    local item=""
    add_component clt 'Command Line Tools' '检查编译工具；缺失时打开系统安装器，完成后重新检测'
    add_component ios-platform 'iOS 模拟器平台' '使用当前完整 Xcode 下载 iOS 平台；卸载保留共享系统平台'
    add_component oh-my-zsh 'oh-my-zsh' '安装官方终端框架，保留现有 zshrc 与登录 Shell'
    add_component homebrew 'Homebrew' '复用健康安装；缺失时安装当前用户前缀，不请求 sudo'
    for item in git-lfs gh nushell rbenv node jenv fvm pnpm ruby python python@3.13 fastlane mysql hugo openjdk openjdk@17 yt-dlp ffmpeg go-task uv fzf lazygit dufs git-filter-repo; do
        add_component "brew.$item" "$item" 'Homebrew 开发工具；仅补装缺项并记录版本与依赖归属'
    done
    for item in hammerspoon flutter trex vlc onlyoffice codex-app codex; do
        add_component "cask.$item" "$item" 'Homebrew cask；安装器需要交互权限时返回失败并提示终端准备'
    done
    add_component git-lfs-config 'Git LFS 与传输配置' '保存原 Git 配置后初始化 LFS，反安装仅恢复未被后续修改的配置'
    add_component codegraph 'CodeGraph CLI' '官方 @colbymchenry/codegraph；用户独立 npm 前缀，不建立项目索引'
    add_component quicktype 'quicktype CLI' '用户独立 npm 前缀；不覆盖既有全局 npm 工具'
    add_component cocoapods 'CocoaPods' '用户独立 GEM_HOME；不改系统 Ruby 或既有 CocoaPods'
    add_component rea 'REA · Reverse Engineer Anything' '默认环境组件；安装官方 rea-agents，MCP、Skill 与分析引擎另按需配置'
    add_component jobs-env 'JobsMacEnvVarConfigs' '转交本仓环境配置后端；按所选完整配置执行，收据由该后端管理'
    add_component jobs-software 'JobsSoftware.MacOS 软件仓' '只克隆缺失的软件仓；已有仓库及本地修改保留'
    local receipt="" formula="" component=""
    for receipt in "$STATE_DIR/receipts"/dependency.*.tsv(N); do
        component="${receipt:t:r}"
        formula="${component#dependency.}"
        [[ "$formula" == [a-zA-Z0-9@+_.-]## ]] || continue
        if read_receipt "$component"; then
            add_component "$component" "自动依赖 · $formula" '所选任务新装的依赖；有消费者、版本或内容变化时保留；支持单独撤回'
        fi
    done
}

# 查询无任何写入；空参数与未知 ID 不会变成全选。
parse_arguments() {
    local arg="" expect_location=0 expect_stop=0
    for arg in "$@"; do
        if (( expect_stop )); then
            [[ "$arg" == /* && "$arg" != *$'\n'* && "$arg" != *$'\t'* ]] || return 2
            STOP_REQUEST_FILE="$arg"
            expect_stop=0
            continue
        fi
        if (( expect_location )); then
            [[ "$arg" == user || "$arg" == system ]] || { print -u2 -r -- 'Homebrew 路径必须是 user 或 system。'; return 2; }
            BREW_LOCATION="$arg"
            expect_location=0
            continue
        fi
        case "$arg" in
            --catalog) [[ -z "$ACTION" ]] || return 2; ACTION=catalog ;;
            --status) [[ -z "$ACTION" ]] || return 2; ACTION=status ;;
            --install) [[ -z "$ACTION" ]] || return 2; ACTION=install ;;
            --uninstall) [[ -z "$ACTION" ]] || return 2; ACTION=uninstall ;;
            --yes) APPROVED=1 ;;
            --dry-run) DRY_RUN=1 ;;
            --brew-location) expect_location=1 ;;
            --stop-request-file) expect_stop=1 ;;
            --help|-h) ACTION=help ;;
            --*) print -u2 -r -- "未知参数：$arg"; return 2 ;;
            *) [[ -n "${COMPONENT_NAMES[$arg]-}" ]] || { print -u2 -r -- "未知组件：$arg"; return 2; }
               (( ${SELECTED[(Ie)$arg]} )) || SELECTED+=("$arg") ;;
        esac
    done
    (( ! expect_location )) || { print -u2 -r -- '缺少 --brew-location 的值。'; return 2; }
    (( ! expect_stop )) || { print -u2 -r -- '缺少 --stop-request-file 的值。'; return 2; }
    [[ -n "$ACTION" ]] || ACTION=help
    if [[ "$ACTION" == install || "$ACTION" == uninstall ]]; then
        (( ${#SELECTED} > 0 )) || { print -u2 -r -- '没有选择组件，未执行。'; return 2; }
        (( APPROVED || DRY_RUN )) || { print -u2 -r -- '写操作需要显式 --yes，未执行。'; return 2; }
    fi
}

log_message() {
    print -r -- "$1"
    [[ -z "$LOCK_DIR" ]] || print -r -- "$1" >> "$LOG_FILE"
}

# 收据与锁只能位于普通目录；不用环境变量重新指向未知清理范围。
prepare_transaction() {
    local parent="$HOME/Library/Application Support" owner=""
    [[ "$(uname -s)" == Darwin ]] || { log_message '错误：只支持 macOS。'; return 1; }
    [[ ! -L "$HOME" && ! -L "$HOME/Library" && ! -L "$parent" && ! -L "$STATE_DIR" ]] ||
        { log_message '错误：状态目录存在符号链接，停止。'; return 1; }
    umask 077
    mkdir -p "$STATE_DIR/receipts" "$STATE_DIR/backups" "$STATE_DIR/logs" "$STATE_DIR/dependencies" || return 1
    [[ ! -L "$STATE_DIR/receipts" && ! -L "$STATE_DIR/backups" && ! -L "$STATE_DIR/logs" && ! -L "$STATE_DIR/dependencies" ]] || return 1
    owner="$(stat -f %u "$STATE_DIR")" || return 1
    [[ "$owner" == "$(id -u)" ]] || return 1
    if ! mkdir "$STATE_DIR/transaction.lock" 2>/dev/null; then
        log_message "错误：另一个事务或中断锁尚在，未执行：$STATE_DIR/transaction.lock"
        log_message '确认没有安装任务后，可将该锁目录移走再重试；收据与备份须保留。'
        return 1
    fi
    LOCK_DIR="$STATE_DIR/transaction.lock"
    LOCK_OWNER_TOKEN="$(/usr/bin/uuidgen)" || return 1
    printf '%s\t%s\n' "$$" "$LOCK_OWNER_TOKEN" > "$LOCK_DIR/owner" || return 1
    LOG_FILE="$(mktemp "$STATE_DIR/logs/session.XXXXXXXX")" || return 1
    log_message "本轮日志：$LOG_FILE"
    trap 'exit 130' INT
    trap 'exit 143' TERM HUP
}

TRAPEXIT() {
    local exit_code=$?
    (( ZSH_SUBSHELL == 0 )) || return "$exit_code"
    local owner_pid="" owner_token=""
    if [[ -n "$LOCK_DIR" && -n "$LOCK_OWNER_TOKEN" && -f "$LOCK_DIR/owner" && ! -L "$LOCK_DIR/owner" ]]; then
        IFS=$'\t' read -r owner_pid owner_token < "$LOCK_DIR/owner"
        [[ "$owner_pid" == "$$" && "$owner_token" == "$LOCK_OWNER_TOKEN" ]] || return "$exit_code"
        /bin/rm -f -- "$LOCK_DIR/owner"
        rmdir "$LOCK_DIR" 2>/dev/null
    fi
    return "$exit_code"
}

run_logged() {
    local -a codes=()
    "$@" 2>&1 | tee -a "$LOG_FILE"
    codes=("${pipestatus[@]}")
    (( codes[1] == 0 )) || return "${codes[1]}"
    (( codes[2] == 0 )) || return "${codes[2]}"
}

# 只对明确网络故障重试可重入获取单元；权限、磁盘、认证、ABI 等错误立即停止。
retry_network_command() {
    local capture="$1" attempt=0 code=0 delay="${JOBS_SETUP_RETRY_BASE_SECONDS:-2}" failure="" error_file=""
    shift
    [[ "$delay" == <1-30> ]] || delay=2
    error_file="$(mktemp "$STATE_DIR/logs/network.XXXXXXXX")" || return 1
    while true; do
        stop_requested && return 130
        (( attempt++ ))
        if [[ "${NETWORK_STREAM_LOGGED:-0}" == 1 ]]; then
            local -a stream_codes=()
            "$@" 2>&1 | tee "$capture" | tee -a "$LOG_FILE"
            stream_codes=("${pipestatus[@]}")
            code="${stream_codes[1]}"
            (( stream_codes[2] == 0 && stream_codes[3] == 0 )) || {
                log_message '网络单元日志写入失败，停止而不重放包管理操作。'
                return 1
            }
        else
            "$@" > "$capture" 2> "$error_file"
            code=$?
        fi
        [[ ! -s "$error_file" ]] || { cat "$error_file" >&2; cat "$error_file" >> "$LOG_FILE"; }
        (( code == 0 )) && return 0
        stop_requested && return 130
        failure="$(cat "$capture" "$error_file")"
        if [[ "$code" == 130 || "$code" == 143 ]]; then
            return "$code"
        fi
        if [[ -n "${BREW_WAIT_FORMULA:-}" ]] &&
           print -r -- "$failure" | /usr/bin/grep -Eiq 'already locked|has already locked|Another active Homebrew|Operation already in progress'; then
            log_message "同一提供者 $BREW_WAIT_FORMULA 被其它 Homebrew 事务占用；等待后重新发现和复检，不抢锁。"
            wait_for_formula_transaction "$BREW_WAIT_FORMULA" || return $?
            if selected_formula_healthy "$BREW_WAIT_FORMULA" >/dev/null 2>&1; then
                BREW_EXTERNAL_RECOVERED=1
                log_message '现有事务已经恢复所需提供者，不重复本线程安装，也不接管其安装归属。'
                return 0
            fi
            sleep 1 || return $?
            continue
        fi
        if print -r -- "$failure" | /usr/bin/grep -Eiq 'EACCES|EPERM|Permission denied|ENOSPC|No space left|Authentication|unauthorized|forbidden|EINTEGRITY|EBADENGINE|dyld|Library not loaded|wrong architecture|incompatible architecture|HTTP[^0-9]*(401|403|404)'; then
            log_message "确定错误，停止当前获取单元（退出码 $code），未重复安装。"
            return "$code"
        fi
        if ! print -r -- "$failure" | /usr/bin/grep -Eiq 'ETIMEDOUT|ECONNRESET|EAI_AGAIN|ENETUNREACH|ECONNREFUSED|Could not resolve|Connection timed out|Connection reset|Failed to connect|curl: \((5|6|7|18|28|35|52|55|56|92)\)|HTTP[^0-9]*(429|500|502|503|504)|network.*(timeout|failed|error)'; then
            log_message "非网络或无法确认的错误（退出码 $code），保留现场并停止。"
            return "$code"
        fi
        log_message "网络获取第 $attempt 次失败，$delay 秒后自动重试；Ctrl+C 或停止进程可取消。"
        local remaining="$delay"
        while (( remaining > 0 )); do
            stop_requested && return 130
            sleep 1 || return $?
            (( remaining-- ))
        done
        (( delay < 30 )) && delay=$(( delay * 2 ))
        (( delay <= 30 )) || delay=30
    done
}

run_network_logged() {
    local output="" result=0 NETWORK_STREAM_LOGGED=1
    output="$(mktemp "$STATE_DIR/logs/download.XXXXXXXX")" || return 1
    NETWORK_OUTPUT="$output"
    retry_network_command "$output" "$@" || result=$?
    [[ "$result" != 130 && "$result" != 143 ]] || STOP_OBSERVED=1
    return "$result"
}

stop_requested() {
    [[ "$ACTION" == install && "$DRY_RUN" == 0 ]] || return 1
    (( STOP_OBSERVED )) && return 0
    [[ -n "$STOP_REQUEST_FILE" && -f "$STOP_REQUEST_FILE" && ! -L "$STOP_REQUEST_FILE" ]]
}

find_homebrew() {
    local candidate=""
    for candidate in "${JOBS_HOMEBREW_BIN:-}" "$(command -v brew 2>/dev/null)" /opt/homebrew/bin/brew /usr/local/bin/brew "$HOME/.local/homebrew/bin/brew" "$HOME/.homebrew/bin/brew"; do
        [[ -n "$candidate" && -x "$candidate" ]] || continue
        if "$candidate" --version >/dev/null 2>&1; then
            BREW_BIN="$candidate"
            return 0
        fi
    done
    return 1
}

require_homebrew() {
    if ! find_homebrew; then
        [[ "$ACTION" == install && "$BREW_LOCATION" == user ]] || {
            log_message '缺少健康 Homebrew，需要明确选择用户安装位置；未擅自代选。'
            return 1
        }
        install_homebrew || return 1
        find_homebrew || return 1
    fi
    run_logged "$BREW_BIN" config || return 1
    if ! run_logged "$BREW_BIN" doctor; then
        log_message 'Homebrew doctor 有诊断；只按当前组件的具体失败修复，不批量处理无关警告。'
    fi
    return 0
}

find_node_npm() {
    local candidate="" prefix="" diagnostic="" node_code=0 formula="" real=""
    local -a folders=("$(dirname "$(command -v node 2>/dev/null)")")
    NODE_FAILURE=""
    NODE_ATTEMPTED=""
    NODE_PROVIDER=""
    if find_homebrew; then
        for formula in "${(@f)$("$BREW_BIN" list --formula --versions 2>/dev/null | awk '$1 ~ /^node(@[0-9]+)?$/ {print $1}')}"; do
            prefix="$("$BREW_BIN" --prefix "$formula" 2>/dev/null)"
            [[ "$prefix" == /* ]] && folders+=("$prefix/bin")
        done
    fi
    folders+=(/opt/homebrew/bin /usr/local/bin)
    for candidate in "${(u)folders[@]}"; do
        [[ "$candidate" == /* && -x "$candidate/node" ]] || continue
        [[ -n "$NODE_ATTEMPTED" ]] || NODE_ATTEMPTED="$candidate/node"
        diagnostic="$("$candidate/node" -e 'process.exit(0)' 2>&1)"
        node_code=$?
        if (( node_code != 0 )); then
            log_message "Node 候选不可执行：$candidate/node；退出码 $node_code；$diagnostic" >&2
            [[ -n "$NODE_FAILURE" ]] || NODE_FAILURE="$diagnostic"
            continue
        fi
        if [[ -x "$candidate/npm" ]] && PATH="$candidate:$PATH" "$candidate/npm" --version >/dev/null 2>&1; then
            NODE_BIN="$candidate/node"
            NPM_BIN="$candidate/npm"
            export PATH="$candidate:$PATH"
            if [[ "$ACTION" == install && -n "$LOCK_DIR" && -n "$ACTIVE_CONSUMER" ]] &&
               identify_node_provider "$NODE_BIN" && read_receipt "dependency.$NODE_PROVIDER"; then
                record_dependency_use "$NODE_PROVIDER" "$ACTIVE_CONSUMER" || return 1
            fi
            return 0
        fi
        [[ -n "$NODE_FAILURE" ]] || NODE_FAILURE="npm 缺失或不能执行：$candidate/npm"
    done
    log_message 'Node.js/npm 尚未通过可执行性检查。' >&2
    return 1
}

# 从真实 Cellar 路径识别已有提供者，不执行 nvm/asdf 等用户配置。
identify_node_provider() {
    local brew_prefix="" real="${1:A}" remainder="" formula=""
    NODE_PROVIDER=""
    find_homebrew || return 1
    brew_prefix="$("$BREW_BIN" --prefix)" || return 1
    brew_prefix="${brew_prefix:A}"
    if [[ "$real" == "$brew_prefix/Cellar/"* ]]; then
        remainder="${real#"$brew_prefix/Cellar/"}"
        formula="${remainder%%/*}"
        [[ "$formula" == node || "$formula" == node@<-> ]] || return 1
        NODE_PROVIDER="$formula"
        return 0
    fi
    return 1
}

record_dependency_use() {
    local formula="$1" consumer="$2" file="$STATE_DIR/dependencies/$2.tsv"
    [[ -n "$consumer" && "$formula" == [a-zA-Z0-9@+_.-]## ]] || return 1
    [[ ! -L "$file" ]] || return 1
    [[ -f "$file" ]] && /usr/bin/grep -Fxq "$formula" "$file" && return 0
    print -r -- "$formula" >> "$file"
}

# 新依赖有单独收据；已有/修复过的共享包仅审计，不能变成本工具新装归属。
repair_or_install_formula() {
    local formula="$1" consumer="$2" mode=install before="" after="" target="" digest="" existing=0 result=0
    local -a before_names=() after_names=()
    local npm_link="" npx_link="" brew_prefix="" npm_backup="" dependency_owned=0 BREW_WAIT_FORMULA="$1"
    BREW_EXTERNAL_RECOVERED=0
    require_homebrew || return 1
    wait_for_formula_transaction "$formula" || return $?
    case "$formula" in
        node|node@<->|ruby|ruby@<->.<->|git-lfs)
            if selected_formula_healthy "$formula" >/dev/null 2>&1; then
                log_message "所需提供者已由现有事务恢复健康，直接续行：$formula"
                return 0
            fi ;;
    esac
    if "$BREW_BIN" list --formula --versions "$formula" >/dev/null 2>&1; then
        existing=1
        mode=reinstall
    fi
    if read_receipt "dependency.$formula"; then
        target="$("$BREW_BIN" --cellar "$formula" 2>/dev/null)"
        [[ -n "$target" && "${RECEIPT[fingerprint]}" == "$(tree_digest "$target")" ]] && dependency_owned=1
    fi
    [[ -z "${REPAIRED_FORMULAE[$formula]-}" ]] || {
        log_message "本轮已修复 $formula，复检仍失败，不重复相同本地副作用。"
        return 1
    }
    before="$("$BREW_BIN" list --formula --versions)" || return 1
    printf '%s\n' "$before" >> "$STATE_DIR/logs/dependencies-before.$consumer.$formula.tsv"
    if [[ "$formula" == node || "$formula" == node@<-> ]]; then
        brew_prefix="$("$BREW_BIN" --prefix)" || return 1
        [[ ! -L "$brew_prefix/bin/npm" ]] || npm_link="$(readlink "$brew_prefix/bin/npm")"
        [[ ! -L "$brew_prefix/bin/npx" ]] || npx_link="$(readlink "$brew_prefix/bin/npx")"
        printf 'provider\t%s\nnpm.before\t%s\nnpx.before\t%s\n' "$formula" "$npm_link" "$npx_link" \
            >> "$STATE_DIR/logs/runtime-repairs.tsv"
        if [[ -d "$brew_prefix/lib/node_modules/npm" && ! -L "$brew_prefix/lib/node_modules/npm" ]] &&
           [[ "$(/usr/bin/plutil -extract name raw -o - "$brew_prefix/lib/node_modules/npm/package.json" 2>/dev/null)" == npm ]]; then
            npm_backup="$(mktemp -d "$STATE_DIR/backups/npm-preserve.XXXXXXXX")" || return 1
            local original_digest="$(tree_digest "$brew_prefix/lib/node_modules/npm")"
            cp -pR -- "$brew_prefix/lib/node_modules/npm" "$npm_backup/npm" || return 1
            [[ "$(tree_digest "$npm_backup/npm")" == "$original_digest" &&
               "$(tree_digest "$brew_prefix/lib/node_modules/npm")" == "$original_digest" ]] || return 1
            log_message "已核验原独立全局 npm 包恢复副本：$npm_backup/npm"
        fi
    fi
    before_names=("${(@f)$(print -r -- "$before" | awk '{print $1}')}")
    log_message "依赖修复：$formula；原因：${NODE_FAILURE:-当前任务依赖缺失、损坏或版本不兼容}；动作：brew $mode $formula"
    run_network_logged "$BREW_BIN" "$mode" --formula "$formula" || result=$?
    (( result != 0 )) || REPAIRED_FORMULAE[$formula]=done
    if (( BREW_EXTERNAL_RECOVERED )); then
        log_message "当前依赖由外部事务恢复，跳过本工具新装认领与全局链接恢复：$formula"
        return 0
    fi
    if [[ "$formula" == node || "$formula" == node@<-> ]]; then
        [[ -z "$npm_backup" ]] || restore_healthy_global_npm "$brew_prefix" "$formula" "$npm_backup" || return 1
        preserve_healthy_npm_link "$brew_prefix" "$formula" npm "$npm_link" || return 1
        preserve_healthy_npm_link "$brew_prefix" "$formula" npx "$npx_link" || return 1
    fi
    after="$("$BREW_BIN" list --formula --versions)" || return 1
    after_names=("${(@f)$(print -r -- "$after" | awk '{print $1}')}")
    local item="" snapshot=""
    for item in "${after_names[@]}"; do
        [[ -n "$item" && "$item" == [a-zA-Z0-9@+_.-]## ]] || continue
        if (( ! ${before_names[(Ie)$item]} )); then
            snapshot="$(print -r -- "$after" | awk -v name="$item" '$1==name {print}')"
            target="$("$BREW_BIN" --cellar "$item")" || return 1
            digest="$(tree_digest "$target")" || return 1
            write_receipt "dependency.$item" brew-formula "$("$BREW_BIN" --prefix)" "$snapshot" "$digest" || return 1
            record_dependency_use "$item" "$consumer" || return 1
        fi
    done
    (( result == 0 )) || return "$result"
    if (( dependency_owned )); then
        target="$("$BREW_BIN" --cellar "$formula")" || return 1
        digest="$(tree_digest "$target")" || return 1
        snapshot="$("$BREW_BIN" list --formula --versions "$formula")" || return 1
        write_receipt "dependency.$formula" brew-formula "$("$BREW_BIN" --prefix)" "$snapshot" "$digest" || return 1
    fi
    if read_receipt "dependency.$formula"; then
        record_dependency_use "$formula" "$consumer" || return 1
    elif (( existing )); then
        log_message "已修复共享提供者，保持原有卸载归属：$formula"
    fi
    rehash
}

restore_healthy_global_npm() {
    local prefix="$1" formula="$2" backup="$3" target="$1/lib/node_modules/npm" runtime=""
    local old_digest="" current_identity="" stage="" kind=missing bundled="" bundled_root="" proven=0
    old_digest="$(tree_digest "$backup/npm")" || return 1
    if [[ -d "$target" && ! -L "$target" ]]; then
        current_identity="$(tree_digest "$target")" || return 1
        [[ "$current_identity" != "$old_digest" ]] || return 0
        kind=directory
    elif [[ -L "$target" ]]; then
        current_identity="$(readlink "$target")" || return 1
        kind=symlink
    elif [[ -e "$target" ]]; then
        log_message '全局 npm 目标类型发生未知变化，保留备份并停止，未覆盖。'
        return 1
    fi
    runtime="$("$BREW_BIN" --prefix "$formula")/bin"
    for bundled in "${runtime:h}/libexec/lib/node_modules/npm" "${runtime:h}/lib/node_modules/npm"; do
        [[ -d "$bundled" ]] || continue
        bundled_root="${bundled:A}"
        if [[ "$kind" == directory && "$(tree_digest "$bundled_root")" == "$current_identity" ]]; then
            proven=1
            break
        elif [[ "$kind" == symlink && "${target:A}" == "$bundled_root" ]]; then
            proven=1
            break
        fi
    done
    if (( ! proven )); then
        log_message "当前全局 npm 不能证明属于本次 provider 的捆绑内容，保留当前对象及原副本，未覆盖：$backup"
        return 1
    fi
    if ! PATH="$runtime:$PATH" "$backup/npm/bin/npm-cli.js" --version >/dev/null 2>&1; then
        log_message "原 npm 包在修复后的 Node 上不健康，保留副本并报告，未伪称原版本恢复：$backup"
        return 1
    fi
    stage="$(mktemp -d "$prefix/lib/node_modules/.jobs-npm-restore.XXXXXXXX")" || return 1
    cp -pR -- "$backup/npm" "$stage/npm" || return 1
    case "$kind" in
        directory) [[ ! -L "$target" && "$(tree_digest "$target")" == "$current_identity" ]] || return 1 ;;
        symlink) [[ -L "$target" && "$(readlink "$target")" == "$current_identity" ]] || return 1 ;;
        missing) [[ ! -e "$target" && ! -L "$target" ]] || return 1 ;;
    esac
    if [[ "$kind" != missing ]]; then
        mv -- "$target" "$backup/replaced-npm" || return 1
    fi
    if ! mv -- "$stage/npm" "$target"; then
        [[ "$kind" == missing ]] || mv -- "$backup/replaced-npm" "$target"
        log_message "全局 npm 恢复失败，原包与替换副本：$backup"
        return 1
    fi
    rmdir "$stage" || return 1
    [[ "$(tree_digest "$target")" == "$old_digest" ]] || return 1
    log_message '原独立全局 npm 包已通过修复后运行时复检并逐字节恢复；其它全局模块未处理。'
}

wait_for_formula_transaction() {
    local formula="$1" prefix="$("$BREW_BIN" --prefix)" lock="" holders="" notified=0 busy=0
    while true; do
        stop_requested && return 130
        busy=0
        for lock in "$prefix/var/homebrew/locks/$formula.formula.lock" "$prefix/var/homebrew/locks/$formula.lock"; do
            [[ -f "$lock" && ! -L "$lock" ]] || continue
            holders="$(/usr/sbin/lsof -t "$lock" 2>/dev/null)"
            [[ -z "$holders" ]] || busy=1
        done
        (( busy )) || return 0
        if (( ! notified )); then
            log_message "同一提供者 $formula 正由其它 Homebrew 事务处理；等待其结束再发现和复检，不抢锁、不认领期间对象。"
            notified=1
        fi
        sleep 1 || return $?
    done
}

preserve_healthy_npm_link() {
    local brew_prefix="$1" formula="$2" tool="$3" original="$4" link="$1/bin/$3"
    local current="" original_target="" runtime_prefix="" temporary=""
    [[ -L "$link" ]] || return 0
    current="$(readlink "$link")" || return 1
    printf '%s.after\t%s\n' "$tool" "$current" >> "$STATE_DIR/logs/runtime-repairs.tsv"
    [[ -n "$original" && "$current" != "$original" ]] || return 0
    log_message "Homebrew 修复改变了 $tool 链接；原指向和新指向已记录，不认领原全局 npm 的卸载归属。"
    [[ "$original" != -* ]] || return 0
    if [[ "$original" == /* ]]; then
        original_target="$original"
    else
        original_target="$brew_prefix/bin/$original"
    fi
    [[ -f "$original_target" ]] || return 0
    runtime_prefix="$("$BREW_BIN" --prefix "$formula")" || return 1
    if PATH="$runtime_prefix/bin:$PATH" "$original_target" --version >/dev/null 2>&1; then
        [[ -L "$link" && "$(readlink "$link")" == "$current" ]] || {
            log_message "$tool 链接出现并发修改，保留当前状态。"
            return 1
        }
        temporary="$(mktemp -d "$STATE_DIR/backups/$tool.link.XXXXXXXX")" || return 1
        ln -s "$original" "$temporary/link" || return 1
        mv -f -- "$temporary/link" "$link" || return 1
        rmdir "$temporary" || return 1
        log_message "已复检并保留原有健康 $tool 入口语义。"
    else
        log_message "原 $tool 入口未通过复检，保留包管理器修复结果和路径审计。"
    fi
}

prepare_current_lts_node() {
    local consumer="$1" engine_file="${2:-}" index="" version="" lts="" major="" i=0 formula="" candidate_metadata="" canonical="" keg_only=""
    require_homebrew || return 1
    index="$(mktemp "$STATE_DIR/logs/node-releases.XXXXXXXX")" || return 1
    log_message '来源：https://nodejs.org/dist/index.json；按官方当前 LTS 声明选择运行时，不固化旧版本表。'
    retry_network_command "$index" curl --fail --silent --show-error --location \
        --proto '=https' --proto-redir '=https' --connect-timeout 10 --max-time 120 \
        https://nodejs.org/dist/index.json || return $?
    while (( i < 100 )); do
        lts="$(/usr/bin/plutil -extract "$i.lts" raw -o - "$index" 2>/dev/null)" || break
        if [[ "$lts" != false && "$lts" != 0 && -n "$lts" ]]; then
            version="$(/usr/bin/plutil -extract "$i.version" raw -o - "$index")" || return 1
            if [[ -n "$engine_file" ]] && ! check_package_engine "" "$engine_file" "${version#v}"; then
                (( i++ ))
                continue
            fi
            major="${version#v}"
            major="${major%%.*}"
            [[ "$major" == <-> ]] || return 1
            formula="node@$major"
            if [[ -n "$engine_file" ]]; then
                candidate_metadata="$(mktemp "$STATE_DIR/logs/node-candidate.XXXXXXXX")" || return 1
                retry_network_command "$candidate_metadata" "$BREW_BIN" info --json=v2 --formula "$formula" || return $?
                canonical="$(/usr/bin/plutil -extract formulae.0.name raw -o - "$candidate_metadata" 2>/dev/null)"
                keg_only="$(/usr/bin/plutil -extract formulae.0.keg_only raw -o - "$candidate_metadata" 2>/dev/null)"
                if [[ "$canonical" != "$formula" || ( "$keg_only" != true && "$keg_only" != 1 ) ]]; then
                    log_message "$formula 不是可核实的独立 keg-only provider，保留共享 Node 并跳过。"
                    (( i++ ))
                    continue
                fi
            fi
            repair_or_install_formula "$formula" "$consumer" || return $?
            local runtime_prefix="$("$BREW_BIN" --prefix "$formula")"
            export PATH="$runtime_prefix/bin:$PATH"
            rehash
            find_node_npm && return 0
        fi
        (( i++ ))
    done
    log_message '官方 LTS 目录中没有取得可执行 Node/npm；保留诊断，未猜测版本。'
    return 1
}

# 只在已授权安装事务中调用；缺库先修真实依赖，绝不伪造 ABI 文件名软链接。
ensure_node_npm() {
    local consumer="$1" provider="" missing="" dep="" brew_prefix="" failure=""
    if find_node_npm; then
        if identify_node_provider "$NODE_BIN" && read_receipt "dependency.$NODE_PROVIDER"; then
            record_dependency_use "$NODE_PROVIDER" "$consumer" || return 1
        fi
        return 0
    fi
    [[ "$ACTION" == install && "$APPROVED" == 1 && -n "$LOCK_DIR" ]] || return 1
    failure="$NODE_FAILURE"
    require_homebrew || return 1
    if identify_node_provider "$NODE_ATTEMPTED"; then
        provider="$NODE_PROVIDER"
        brew_prefix="$("$BREW_BIN" --prefix)" || return 1
        missing="$(print -r -- "$failure" | awk '/Library not loaded:/ {sub(/^.*Library not loaded: /,"");print;exit}')"
        if [[ "$missing" == "$brew_prefix/opt/"* ]]; then
            dep="${missing#"$brew_prefix/opt/"}"
            dep="${dep%%/*}"
            if [[ "$dep" == [a-zA-Z0-9@+_.-]## ]] &&
               "$BREW_BIN" list --formula --versions "$dep" >/dev/null 2>&1; then
                if dylib_provider_readable "$dep" "$brew_prefix"; then
                    log_message "依赖 $dep 本身链接健康；Node 引用了旧 ABI，定向修复 consumer：$provider。"
                else
                    NODE_FAILURE="$failure"
                    repair_or_install_formula "$dep" "$consumer" || return $?
                    find_node_npm && return 0
                fi
            fi
        fi
        NODE_FAILURE="$failure"
        repair_or_install_formula "$provider" "$consumer" || return $?
        find_node_npm && return 0
    fi
    NODE_FAILURE="$failure"
    prepare_current_lts_node "$consumer"
}

dylib_provider_readable() {
    local formula="$1" brew_prefix="$2" prefix="" library="" dependency=""
    prefix="$("$BREW_BIN" --prefix "$formula")" || return 1
    [[ -d "$prefix/lib" ]] || return 1
    library="$(find "$prefix/lib" -type f -name '*.dylib' -size +0c -print -quit)"
    [[ -n "$library" ]] || return 1
    /usr/bin/otool -L "$library" >/dev/null 2>&1 || return 1
    while IFS= read -r dependency; do
        if [[ "$dependency" == "$brew_prefix/"* && ! -r "$dependency" ]]; then
            return 1
        fi
    done < <(/usr/bin/otool -L "$library" | awk 'NR>1 {print $1}')
    return 0
}

check_package_engine() {
    local package="$1" engine_file="$2" version="${3:-}"
    "$NODE_BIN" -e '
      // JOBS_ENGINE_CHECK: use npm own bundled semver, no extra dependency.
      const fs=require("fs"),{createRequire}=require("module");
      const engine=fs.readFileSync(process.argv[2],"utf8").trim();
      if(!engine)process.exit(0);
      let range=JSON.parse(engine);
      if(Array.isArray(range)){
        if(range.length!==1){console.error("Ambiguous engines.node metadata: expected one result");process.exit(2)}
        range=range[0];
      }
      if(range && typeof range==="object" && !Array.isArray(range)){
        const keys=Object.keys(range);
        if(keys.length===1 && keys[0]==="engines.node")range=range["engines.node"];
        else if(keys.length===1 && keys[0]==="node")range=range.node;
        else if(keys.length===1 && keys[0]==="engines" && range.engines && typeof range.engines==="object" &&
                !Array.isArray(range.engines) && Object.keys(range.engines).length===1 &&
                Object.prototype.hasOwnProperty.call(range.engines,"node"))range=range.engines.node;
        else {console.error("Unknown engines.node metadata object");process.exit(2)}
      }
      if(typeof range!=="string"){console.error("Invalid engines.node metadata: expected a string");process.exit(2)}
      range=range.trim();
      if(!range)process.exit(0);
      const npmRequire=createRequire(fs.realpathSync(process.argv[1]));
      const semver=npmRequire("semver");
      if(semver.validRange(range)===null){console.error("Invalid engines.node semver range");process.exit(2)}
      const version=process.argv[3]||process.versions.node;
      if(!semver.satisfies(version,range)){console.error("Node "+version+" does not satisfy "+range);process.exit(42)}
    ' "$NPM_BIN" "$engine_file" "$version"
}

check_installed_package_engine() {
    local component="$1" prefix="$2" package="$(npm_package_name "$1")" engine_file="" manifest="${3:-}"
    [[ -n "$manifest" ]] || manifest="$prefix/lib/node_modules/$package/package.json"
    engine_file="$(mktemp "$STATE_DIR/logs/installed-engines.XXXXXXXX")" || return 1
    "$NODE_BIN" -e '
      // JOBS_INSTALLED_ENGINE: validate the installed package, not an unrelated latest release.
      const fs=require("fs"),p=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
      if(p.name!==process.argv[2])process.exit(1);
      console.log(JSON.stringify(p.engines && p.engines.node || ""));
    ' "$manifest" "$package" > "$engine_file" || return 1
    check_package_engine "$package" "$engine_file"
}

ensure_package_engine() {
    local component="$1" package="$(npm_package_name "$1")" engine_file="" code=0 provider=""
    ensure_node_npm "$component" || return $?
    engine_file="$(mktemp "$STATE_DIR/logs/engines.XXXXXXXX")" || return 1
    retry_network_command "$engine_file" "$NPM_BIN" view "$package@latest" engines.node --json --registry=https://registry.npmjs.org/ || return $?
    check_package_engine "$package" "$engine_file" && return 0
    code=$?
    [[ "$code" == 42 ]] || return "$code"
    NODE_FAILURE="发布包 $package@latest 的 engines 与当前 Node 不兼容"
    log_message '现有共享 Node 健康但不满足包版本范围；保留原提供者，选择兼容的独立 LTS。'
    prepare_current_lts_node "$component" "$engine_file" || return $?
    check_package_engine "$package" "$engine_file" || {
        log_message '当前官方 LTS 仍不符合发布包 engines，停止，不使用 --force 绕过。'
        return 1
    }
}

receipt_file() {
    print -r -- "$STATE_DIR/receipts/$1.tsv"
}

# TSV 只按数据读取，禁止 source/eval 收据。
read_receipt() {
    local file="$(receipt_file "$1")" key="" value=""
    RECEIPT=()
    [[ -f "$file" && ! -L "$file" ]] || return 1
    while IFS=$'\t' read -r key value; do
        [[ "$key" == [a-z-]## && "$value" != *$'\t'* ]] || return 1
        RECEIPT[$key]="$value"
    done < "$file"
    [[ "${RECEIPT[id]-}" == "$1" && "${RECEIPT[format]-}" == 1 ]]
}

write_receipt() {
    local component="$1" kind="$2" target="$3" version="$4" fingerprint="$5" outcome="${6:-installed}"
    local file="$(receipt_file "$component")" stage=""
    [[ "$target" != *$'\n'* && "$target" != *$'\t'* ]] || return 1
    stage="$(mktemp "$STATE_DIR/receipts/.receipt.XXXXXXXX")" || return 1
    {
        printf 'format\t1\nid\t%s\nkind\t%s\ntarget\t%s\nversion\t%s\nfingerprint\t%s\noutcome\t%s\n' \
            "$component" "$kind" "$target" "$version" "$fingerprint" "$outcome"
    } > "$stage" || return 1
    mv -f -- "$stage" "$file"
}

# 文件内容与链接目标纳入摘要；不以目录存在或版本号代替归属。
tree_digest() {
    local target="$1"
    [[ -d "$target" && ! -L "$target" ]] || return 1
    (
        cd "$target" || exit 1
        find . -type f -exec /usr/bin/shasum -a 256 {} + &&
        find . -exec /usr/bin/stat -f '%N | %p | %u | %g | %Y' {} +
    ) | LC_ALL=C sort | /usr/bin/shasum -a 256 | awk '{print $1}'
}

file_digest() {
    [[ -f "$1" && ! -L "$1" ]] || return 1
    /usr/bin/shasum -a 256 "$1" | awk '{print $1}'
}

npm_package_name() {
    case "$1" in
        rea) print -r -- rea-agents ;;
        quicktype) print -r -- quicktype ;;
        codegraph) print -r -- @colbymchenry/codegraph ;;
    esac
}

npm_prefix() {
    print -r -- "$HOME/.local/share/jobs-system-setup/$1"
}

npm_manifest_version() {
    local prefix="$(npm_prefix "$1")" package="$(npm_package_name "$1")"
    [[ -f "$prefix/lib/node_modules/$package/package.json" ]] || return 1
    find_node_npm >/dev/null || return 1
    "$NODE_BIN" -e 'const fs=require("fs");const p=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));if(p.name!==process.argv[2]||!p.version)process.exit(1);console.log(p.version)' \
        "$prefix/lib/node_modules/$package/package.json" "$package"
}

# PATH 块独立按组件标识，反安装只移除字节匹配的本工具内容。
profile_block() {
    local component="$1" target="$2"
    printf '# >>> JobsSystemSetup %s >>>\n' "$component"
    printf 'export PATH=%s:"$PATH"\n' "${(q)target}"
    printf '# <<< JobsSystemSetup %s <<<\n' "$component"
}

install_profile_block() {
    local component="$1" target="$2" profile="$HOME/.zprofile" block="" before=""
    [[ ! -L "$profile" && ( ! -e "$profile" || -f "$profile" ) ]] || return 1
    block="$(profile_block "$component" "$target")"
    [[ ! -e "$profile" ]] || before="$(file_digest "$profile")" || return 1
    if [[ -e "$profile" ]] && /usr/bin/grep -Fq "# >>> JobsSystemSetup $component >>>" "$profile"; then
        log_message "错误：PATH 标记已存在但没有可接管收据，保留：$profile"
        return 1
    fi
    if [[ -e "$profile" ]]; then
        if [[ -f "$STATE_DIR/backups/$component.zprofile.before" ]]; then
            mv -- "$STATE_DIR/backups/$component.zprofile.before" "$STATE_DIR/backups/$component.zprofile.before.saved.$$" || return 1
        fi
        /bin/rm -f -- "$STATE_DIR/backups/$component.zprofile.absent"
        cp -p -- "$profile" "$STATE_DIR/backups/$component.zprofile.before" || return 1
    else
        if [[ -f "$STATE_DIR/backups/$component.zprofile.before" ]]; then
            mv -- "$STATE_DIR/backups/$component.zprofile.before" "$STATE_DIR/backups/$component.zprofile.before.saved.$$" || return 1
        fi
        : > "$STATE_DIR/backups/$component.zprofile.absent" || return 1
    fi
    [[ ! -e "$profile" || "$(file_digest "$profile")" == "$before" ]] || return 1
    printf '\n%s\n' "$block" >> "$profile"
}

remove_profile_block() {
    local component="$1" target="$2" profile="$HOME/.zprofile" expected="" actual="" stage="" before=""
    [[ ! -e "$profile" ]] && return 0
    [[ -f "$profile" && ! -L "$profile" ]] || return 1
    expected="$(profile_block "$component" "$target")"
    actual="$(awk -v begin="# >>> JobsSystemSetup $component >>>" -v end="# <<< JobsSystemSetup $component <<<" \
        '$0==begin{on=1;count++} on{print} $0==end{on=0} END{if(on||count>1)exit 1}' "$profile")" || return 1
    [[ -z "$actual" ]] && return 0
    [[ "$actual" == "$expected" ]] || { log_message "保留已被修改的 PATH 块：$profile"; return 1; }
    before="$(file_digest "$profile")" || return 1
    stage="$(mktemp "$STATE_DIR/backups/.profile.XXXXXXXX")" || return 1
    if [[ -f "$STATE_DIR/backups/$component.zprofile.before" && ! -L "$STATE_DIR/backups/$component.zprofile.before" ]]; then
        cat "$STATE_DIR/backups/$component.zprofile.before" > "$stage" || return 1
        printf '\n%s\n' "$expected" >> "$stage"
        if cmp -s "$stage" "$profile"; then
            cp -p -- "$STATE_DIR/backups/$component.zprofile.before" "$profile" || return 1
            /bin/rm -f -- "$stage"
            return 0
        fi
    elif [[ -f "$STATE_DIR/backups/$component.zprofile.absent" ]]; then
        printf '\n%s\n' "$expected" > "$stage"
        if cmp -s "$stage" "$profile"; then
            /bin/rm -f -- "$profile" "$stage"
            return 0
        fi
    fi
    # 按字节移除本工具插入的前导换行与块，保留用户追加内容和原始末尾换行状态。
    /usr/bin/perl -0777 -e '
        use strict;
        use warnings;
        my ($block, $file) = @ARGV;
        open my $fh, "<:raw", $file or die "$file: $!";
        local $/;
        my $bytes = <$fh>;
        my $needle = "\n" . $block . "\n";
        my $count = () = $bytes =~ /\Q$needle\E/g;
        die "managed block mismatch\n" unless $count == 1;
        $bytes =~ s/\Q$needle\E//;
        binmode STDOUT;
        print $bytes;
    ' "$expected" "$profile" > "$stage" || return 1
    [[ "$(file_digest "$profile")" == "$before" ]] || return 1
    cp -p -- "$profile" "$STATE_DIR/backups/$component.zprofile.uninstall"
    cat "$stage" > "$profile" || return 1
    /bin/rm -f -- "$stage"
}

component_status() {
    local component="$1" package="" prefix="" current=""
    case "$component" in
        brew.*|cask.*|dependency.*)
            find_homebrew || { print no; return; }
            package="${component#*.}"
            if [[ "$component" != cask.* ]]; then
                "$BREW_BIN" list --formula --versions "$package" >/dev/null 2>&1 && print yes || print no
            else
                "$BREW_BIN" list --cask --versions "$package" >/dev/null 2>&1 && print yes || print no
            fi ;;
        rea|quicktype|codegraph)
            if npm_manifest_version "$component" >/dev/null 2>&1; then
                print yes
            elif command -v "$component" >/dev/null 2>&1; then
                "$component" --version >/dev/null 2>&1 && print yes || print unknown
            else
                print no
            fi ;;
        homebrew) find_homebrew && print yes || print no ;;
        clt) xcode-select -p >/dev/null 2>&1 && xcrun --find clang >/dev/null 2>&1 && print yes || print no ;;
        ios-platform)
            current="$(xcrun simctl list runtimes -j 2>/dev/null)" || { print unknown; return; }
            [[ "$current" == *com.apple.CoreSimulator.SimRuntime.iOS* ]] && print yes || print no ;;
        oh-my-zsh) [[ -f "$HOME/.oh-my-zsh/oh-my-zsh.sh" ]] && print yes || print no ;;
        cocoapods)
            [[ -x "$HOME/.local/share/jobs-system-setup/cocoapods/bin/pod" ]] &&
                "$HOME/.local/share/jobs-system-setup/cocoapods/bin/pod" --version >/dev/null 2>&1 && { print yes; return; }
            command -v pod >/dev/null 2>&1 && pod --version >/dev/null 2>&1 && print yes || print no ;;
        jobs-software) git -C "$HOME/Desktop/JobsKits/JobsSoftware.MacOS" rev-parse --is-inside-work-tree >/dev/null 2>&1 && print yes || print no ;;
        jobs-env) print unknown ;;
        git-lfs-config) git config --global --get filter.lfs.process >/dev/null 2>&1 && print yes || print no ;;
    esac
}

emit_catalog() {
    local component=""
    for component in "${COMPONENT_IDS[@]}"; do
        printf '%s\t%s\t%s\t%s\n' "$component" "${COMPONENT_NAMES[$component]}" \
            "${COMPONENT_DESCRIPTIONS[$component]}" "$(component_status "$component")"
    done
}

# npm 工具放入互不共享的专属前缀，拒绝覆盖既有同名工具。
install_npm_component() {
    local component="$1" package="$(npm_package_name "$1")" prefix="$(npm_prefix "$1")" version="" fingerprint="" existing_bin="" global_manifest="" owned=0
    ACTIVE_CONSUMER="$component"
    if read_receipt "$component"; then
        [[ "${RECEIPT[outcome]}" == installed ]] || { log_message '错误：上次安装待恢复，请先反安装该组件。'; return 1; }
        [[ "$(tree_digest "$prefix")" == "${RECEIPT[fingerprint]}" ]] ||
            { log_message "错误：受管组件发生后续修改，未覆盖：$prefix"; return 1; }
        version="${RECEIPT[version]}"
        fingerprint="${RECEIPT[fingerprint]}"
        ensure_node_npm "$component" || return $?
        if [[ -x "$prefix/bin/$component" ]] && run_logged "$prefix/bin/$component" --version &&
           check_installed_package_engine "$component" "$prefix"; then
            log_message "已受管安装，通过真实复检，保持版本：$component $version"
            return 0
        fi
        log_message "受管 CLI 仍不健康；仅修复本工具且摘要未变的安装：$prefix"
        repair_managed_npm_component "$component" "$fingerprint"
        return $?
    fi
    if [[ -e "$prefix" || -L "$prefix" ]]; then
        ensure_node_npm "$component" || return $?
        [[ -x "$prefix/bin/$component" ]] &&
            run_logged "$prefix/bin/$component" --version &&
            check_installed_package_engine "$component" "$prefix" ||
            { log_message "错误：已有目标缺少健康 CLI，保留且不覆盖：$prefix"; return 1; }
        log_message "已有可执行组件，保留且不接管卸载归属：$component"
        return 0
    fi
    existing_bin="$(command -v "$component" 2>/dev/null)"
    if [[ -n "$existing_bin" ]]; then
        ensure_node_npm "$component" || return $?
        global_manifest="$("$NODE_BIN" -e '
          // JOBS_CLI_MANIFEST: inspect metadata only; never load the target module.
          const fs=require("fs"),path=require("path");
          let dir=path.dirname(fs.realpathSync(process.argv[1]));
          while(true){const file=path.join(dir,"package.json");if(fs.existsSync(file)){try{if(JSON.parse(fs.readFileSync(file,"utf8")).name===process.argv[2]){console.log(file);break}}catch{}}const parent=path.dirname(dir);if(parent===dir)break;dir=parent}
        ' "$existing_bin" "$package")" || return 1
        if run_logged "$existing_bin" --version &&
           { [[ -z "$global_manifest" ]] || check_installed_package_engine "$component" "" "$global_manifest"; }; then
            log_message "已有全局组件通过运行检查，保留原版本与归属：$existing_bin"
            return 0
        fi
        log_message "已有全局组件仍不健康，保留原物；以独立受管用户前缀补齐：$prefix"
    fi
    ensure_package_engine "$component" || return $?
    if [[ "$component" == rea ]]; then
        # 对最新包使用 npm 的 engine-strict 实际校验，不把过期版本表固化进脚本。
        log_message 'REA 要求与发布包匹配的 Node.js，npm 将严格验证 engines；失败不使用 --force。'
    fi
    [[ ! -L "$HOME/.local" && ! -L "$HOME/.local/share" && ! -L "$HOME/.local/share/jobs-system-setup" ]] || return 1
    mkdir -p "${prefix:h}" || return 1
    write_receipt "$component" npm "$prefix" pending pending preparing || return 1
    log_message "来源：https://registry.npmjs.org/$package；目标：$prefix"
    if ! run_network_logged "$NPM_BIN" install --global --prefix "$prefix" --registry=https://registry.npmjs.org/ --engine-strict "$package@latest"; then
        fingerprint="$(tree_digest "$prefix" 2>/dev/null)"
        write_receipt "$component" npm "$prefix" pending "$fingerprint" incomplete
        log_message '安装未完成；已保留收据，选择该组件反安装可清理未被修改的独立前缀。'
        return 1
    fi
    fingerprint="$(tree_digest "$prefix")" || return 1
    write_receipt "$component" npm "$prefix" pending "$fingerprint" incomplete || return 1
    version="$(npm_manifest_version "$component")" || return 1
    pin_npm_runtime "$component" "$prefix" || return 1
    local verify_code=0
    run_logged "$prefix/bin/$component" --version || verify_code=$?
    fingerprint="$(tree_digest "$prefix")" || return 1
    write_receipt "$component" npm "$prefix" "$version" "$fingerprint" incomplete || return 1
    (( verify_code == 0 )) || return "$verify_code"
    install_profile_block "$component" "$prefix/bin" || return 1
    write_receipt "$component" npm "$prefix" "$version" "$fingerprint" || return 1
    log_message "完成：$component $version；新终端生效。"
    [[ "$component" != rea ]] || log_message 'REA 包已安装；需要连接具体客户端时在终端运行 rea setup，MCP/Skill/引擎未自动写入。'
}

pin_npm_runtime() {
    local component="$1" prefix="$2" node_folder="${NODE_BIN:h}" original="$2/bin/.jobs-$1"
    [[ -x "$prefix/bin/$component" && -n "$NODE_BIN" ]] || return 1
    if [[ -e "$original" || -L "$original" ]]; then
        log_message "运行时包装目标已存在，保留待核对：$original"
        return 1
    fi
    mv -- "$prefix/bin/$component" "$original" || return 1
    {
        print -r -- '#!/bin/zsh'
        printf 'export PATH=%s:"$PATH"\n' "${(q)node_folder}"
        printf 'exec "$(dirname "$0")/.jobs-%s" "$@"\n' "$component"
    } > "$prefix/bin/$component" || return 1
    chmod u+x "$prefix/bin/$component"
}

repair_managed_npm_component() {
    local component="$1" expected="$2" prefix="$(npm_prefix "$1")" package="$(npm_package_name "$1")"
    local stage="" backup="" version="" digest=""
    ensure_package_engine "$component" || return $?
    [[ "$(tree_digest "$prefix")" == "$expected" ]] || { log_message '前缀在检查后被修改，未覆盖。'; return 1; }
    stage="$(mktemp -d "${prefix:h}/.$component.repair.XXXXXXXX")" || return 1
    log_message "受管包修复：从官方 registry 安装到独立暂存并验证；原内容保持到发布前：$stage"
    run_network_logged "$NPM_BIN" install --global --prefix "$stage" --registry=https://registry.npmjs.org/ --engine-strict "$package@latest" || return $?
    pin_npm_runtime "$component" "$stage" || return 1
    run_logged "$stage/bin/$component" --version || return 1
    version="$("$NODE_BIN" -e 'const p=require(process.argv[1]);if(p.name!==process.argv[2])process.exit(1);console.log(p.version)' "$stage/lib/node_modules/$package/package.json" "$package")" || return 1
    [[ "$(tree_digest "$prefix")" == "$expected" ]] || { log_message '原前缀发生并发修改，保留原物与暂存。'; return 1; }
    backup="$STATE_DIR/backups/$component.prefix.$(date +%Y%m%d-%H%M%S).$$"
    [[ ! -e "$backup" && ! -L "$backup" ]] || return 1
    mv -- "$prefix" "$backup" || return 1
    if ! mv -- "$stage" "$prefix"; then
        mv -- "$backup" "$prefix" || log_message "恢复失败；原前缀副本：$backup"
        return 1
    fi
    digest="$(tree_digest "$prefix")" || return 1
    write_receipt "$component" npm "$prefix" "$version" "$digest" || return 1
    log_message "受管包修复并复检完成，原内容恢复副本保留：$backup"
}

brew_snapshot() {
    local kind="$1" package="$2"
    "$BREW_BIN" list "--$kind" --versions "$package"
}

install_brew_component() {
    local component="$1" kind=formula package="${1#*.}" prefix="" snapshot="" target="" fingerprint="" BREW_WAIT_FORMULA="${1#*.}"
    [[ "$component" == cask.* ]] && kind=cask
    [[ "$package" == go-task ]] && package=go-task/tap/go-task
    require_homebrew || return 1
    wait_for_formula_transaction "${package:t}" || return $?
    if snapshot="$(brew_snapshot "$kind" "$package" 2>/dev/null)"; then
        if [[ "$kind" == formula && ( "$package" == node || "$package" == node@<-> || "$package" == ruby || "$package" == ruby@<->.<-> || "$package" == git-lfs ) ]]; then
            verify_or_repair_selected_formula "$package" "$component" || return $?
        fi
        log_message "已安装，保持原版本与归属：$snapshot"
        return 0
    fi
    prefix="$("$BREW_BIN" --prefix)" || return 1
    "$BREW_BIN" list --formula --versions > "$STATE_DIR/backups/$component.formula.before" || return 1
    "$BREW_BIN" list --cask --versions > "$STATE_DIR/backups/$component.cask.before" || return 1
    log_message "来源：https://formulae.brew.sh/；组件：$kind/$package；Homebrew：$prefix"
    write_receipt "$component" "brew-$kind" "$prefix" pending pending preparing || return 1
    BREW_EXTERNAL_RECOVERED=0
    if ! run_network_logged "$BREW_BIN" install "--$kind" "$package"; then
        log_message '安装失败；保留准备收据，未宣称已安装或可安全删除。'
        return 1
    fi
    if (( BREW_EXTERNAL_RECOVERED )); then
        /bin/rm -f -- "$(receipt_file "$component")"
        log_message "组件由外部事务完成，保留其归属：$component"
        return 0
    fi
    snapshot="$(brew_snapshot "$kind" "$package")" || return 1
    "$BREW_BIN" list --formula --versions > "$STATE_DIR/backups/$component.formula.after" || return 1
    "$BREW_BIN" list --cask --versions > "$STATE_DIR/backups/$component.cask.after" || return 1
    target="$("$BREW_BIN" --cellar "${package:t}" 2>/dev/null)"
    [[ "$kind" == cask ]] && target="$prefix/Caskroom/${package:t}"
    fingerprint="$(tree_digest "$target")" || return 1
    write_receipt "$component" "brew-$kind" "$prefix" "$snapshot" "$fingerprint" || return 1
    if [[ "$kind" == formula && ( "$package" == node || "$package" == node@<-> || "$package" == ruby || "$package" == ruby@<->.<-> || "$package" == git-lfs ) ]]; then
        verify_or_repair_selected_formula "$package" "$component" || return $?
    fi
    log_message "完成：$snapshot；自动安装的共享依赖保留，不执行 autoremove。"
}

selected_formula_healthy() {
    local formula="$1" prefix="$("$BREW_BIN" --prefix "$1")"
    [[ "$prefix" == /* ]] || return 1
    case "$formula" in
        node|node@<->)
            run_logged "$prefix/bin/node" -e 'process.exit(0)' &&
                run_logged env PATH="$prefix/bin:$PATH" "$prefix/bin/npm" --version ;;
        ruby|ruby@<->.<->)
            run_logged "$prefix/bin/ruby" -e 'exit 0' &&
                run_logged env PATH="$prefix/bin:$PATH" "$prefix/bin/gem" --version ;;
        git-lfs) run_logged "$prefix/bin/git-lfs" version ;;
        *) brew_snapshot formula "$formula" >/dev/null 2>&1 ;;
    esac
}

verify_or_repair_selected_formula() {
    local formula="$1" component="$2" was_owned=0 target="" digest="" snapshot=""
    selected_formula_healthy "$formula" && return 0
    target="$("$BREW_BIN" --cellar "$formula")" || return 1
    if read_receipt "$component" && [[ "${RECEIPT[fingerprint]}" == "$(tree_digest "$target")" ]]; then
        was_owned=1
    fi
    NODE_FAILURE="明确选中的 $formula 提供者未通过真实执行；不以其它健康 provider 掩盖"
    repair_or_install_formula "$formula" "$component" || return $?
    selected_formula_healthy "$formula" || {
        log_message "明确所选 $formula 修复后仍不健康，未报告安装成功。"
        return 1
    }
    if (( was_owned )); then
        snapshot="$(brew_snapshot formula "$formula")" || return 1
        digest="$(tree_digest "$target")" || return 1
        write_receipt "$component" brew-formula "$("$BREW_BIN" --prefix)" "$snapshot" "$digest" || return 1
    fi
}

# 缺失的 Homebrew 使用用户前缀；标准系统目录的权限准备仍走原终端入口。
install_homebrew() {
    local prefix="$HOME/.local/homebrew" stage="" tag="" commit=""
    if find_homebrew; then
        require_homebrew
        return $?
    fi
    if [[ "$BREW_LOCATION" != user ]]; then
        log_message '缺少 Homebrew：必须明确选择安装路径；未自动代选。'
        log_message '当前用户目录：面板明确确认后传 --brew-location user；系统标准目录：使用原终端安装入口选择 YES。'
        return 1
    fi
    if ! command -v git >/dev/null || ! git --version >/dev/null 2>&1; then
        ensure_clt || return $?
        git --version >/dev/null 2>&1 || { log_message 'CLT 已完成但 Git 仍不可执行，未继续 Homebrew。'; return 1; }
    fi
    [[ "$prefix" != *[[:space:]:]* && ! -e "$prefix" && ! -L "$prefix" &&
       ! -L "$HOME/.local" ]] || { log_message "目标不可安全创建：$prefix"; return 1; }
    mkdir -p "$HOME/.local" || return 1
    stage="$(mktemp -d "$HOME/.local/.jobs-homebrew.XXXXXXXX")" || return 1
    log_message "来源：https://github.com/Homebrew/brew；目标：$prefix（用户前缀）"
    run_network_logged curl --fail --location --show-error --connect-timeout 10 --max-time 120 \
        --proto '=https' --proto-redir '=https' \
        https://api.github.com/repos/Homebrew/brew/releases/latest -o "$stage/release.json" || return 1
    tag="$(/usr/bin/plutil -extract tag_name raw -o - "$stage/release.json")" || return 1
    [[ "$tag" == [0-9]* && "$tag" != *[^0-9.]* ]] || return 1
    write_receipt homebrew homebrew "$prefix" pending pending preparing || return 1
    run_logged git init "$stage/brew" || return 1
    run_logged git -C "$stage/brew" remote add origin https://github.com/Homebrew/brew.git || return 1
    run_network_logged git -C "$stage/brew" -c http.lowSpeedLimit=1 -c http.lowSpeedTime=60 \
        fetch --depth 1 origin "$tag" || return 1
    run_logged git -C "$stage/brew" checkout -b stable FETCH_HEAD || return 1
    run_logged git -C "$stage/brew" config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*' || return 1
    mkdir -p "$stage/brew/Cellar" "$stage/brew/Caskroom" "$stage/brew/etc" "$stage/brew/var" || return 1
    mv -- "$stage/brew" "$prefix" || return 1
    BREW_BIN="$prefix/bin/brew"
    require_homebrew || return 1
    commit="$(git -C "$prefix" rev-parse HEAD)" || return 1
    write_receipt homebrew homebrew "$prefix" "$commit" "$(tree_digest "$prefix")" incomplete || return 1
    install_profile_block homebrew "$prefix/bin" || return 1
    write_receipt homebrew homebrew "$prefix" "$commit" "$(tree_digest "$prefix")" || return 1
    /bin/rm -f -- "$stage/release.json"
    rmdir "$stage" 2>/dev/null
    log_message 'Homebrew 已就绪；用户非标准前缀可能需要源码构建部分 formula。'
}

install_ohmyzsh() {
    local target="$HOME/.oh-my-zsh" installer="" digest=""
    if [[ -e "$target" || -L "$target" ]]; then
        [[ -f "$target/oh-my-zsh.sh" ]] && /bin/zsh -n "$target/oh-my-zsh.sh" ||
            { log_message '错误：已有 oh-my-zsh 缺少有效入口，保留原目录与配置。'; return 1; }
        log_message 'oh-my-zsh 入口存在且语法通过，保留原配置与归属。'
        return 0
    fi
    installer="$(mktemp "$STATE_DIR/backups/ohmyzsh.XXXXXXXX")" || return 1
    log_message "来源：https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh；目标：$target"
    run_logged curl --fail --location --show-error --connect-timeout 10 --max-time 120 \
        --proto '=https' --proto-redir '=https' \
        https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh -o "$installer" || return 1
    /bin/sh -n "$installer" || return 1
    write_receipt oh-my-zsh tree "$target" pending pending preparing || return 1
    if ! run_logged env RUNZSH=no CHSH=no KEEP_ZSHRC=yes /bin/sh "$installer" --unattended; then
        return 1
    fi
    [[ -f "$target/oh-my-zsh.sh" ]] || return 1
    digest="$(tree_digest "$target")" || return 1
    write_receipt oh-my-zsh tree "$target" installed "$digest"
}

install_cocoapods() {
    local target="$HOME/.local/share/jobs-system-setup/cocoapods" digest="" version="" existing_bin="" gem_result=0
    ensure_rubygems cocoapods || return $?
    if [[ -e "$target" || -L "$target" ]]; then
        if [[ -x "$target/bin/pod" ]] &&
            run_logged env GEM_HOME="$target" GEM_PATH="$target" "$target/bin/pod" --version; then
            log_message 'CocoaPods 前缀通过运行检查，保留原版本与归属。'
            return 0
        fi
        repair_managed_cocoapods "$target"
        return $?
    fi
    existing_bin="$(command -v pod 2>/dev/null)"
    if [[ -n "$existing_bin" ]]; then
        if run_logged "$existing_bin" --version; then
            log_message '已有全局 CocoaPods 通过运行检查，保留原版本与归属。'
            return 0
        fi
        log_message "已有全局 CocoaPods 不健康，保留原物并补齐独立用户前缀：$target"
    fi
    [[ ! -L "$HOME/.local" && ! -L "$HOME/.local/share" && ! -L "${target:h}" ]] || return 1
    mkdir -p "${target:h}" || return 1
    write_receipt cocoapods tree "$target" pending pending preparing || return 1
    log_message "来源：https://rubygems.org/gems/cocoapods；目标：$target"
    run_network_logged env GEM_HOME="$target" GEM_PATH="$target" gem install --no-document --install-dir "$target" \
        --bindir "$target/bin" --source https://rubygems.org cocoapods || gem_result=$?
    if (( gem_result != 0 )); then
        [[ "$gem_result" != 130 && "$gem_result" != 143 && "$STOP_OBSERVED" == 0 ]] || return 130
        if [[ -n "$NETWORK_OUTPUT" ]] &&
           ! /usr/bin/grep -Eiq 'EACCES|EPERM|ENOSPC|Permission denied|No space left|Authentication|unauthorized|forbidden' "$NETWORK_OUTPUT" &&
           /usr/bin/grep -Eiq 'requires Ruby|Ruby version|Ruby >=|required_ruby_version' "$NETWORK_OUTPUT"; then
            NODE_FAILURE='CocoaPods 或其依赖要求更新的 Ruby，当前版本不兼容'
            local compatible_ruby=""
            compatible_ruby="$(compatible_ruby_formula)" || return 1
            repair_or_install_formula "$compatible_ruby" cocoapods || return $?
            local ruby_prefix="$("$BREW_BIN" --prefix "$compatible_ruby")"
            export PATH="$ruby_prefix/bin:$PATH"
            rehash
            ensure_rubygems cocoapods || return $?
            run_network_logged env GEM_HOME="$target" GEM_PATH="$target" gem install --no-document --install-dir "$target" \
                --bindir "$target/bin" --source https://rubygems.org cocoapods || return $?
        else
            return 1
        fi
    fi
    digest="$(tree_digest "$target")" || return 1
    write_receipt cocoapods tree "$target" pending "$digest" incomplete || return 1
    version="$(env GEM_HOME="$target" GEM_PATH="$target" "$target/bin/pod" --version)" || return 1
    # gem 执行器需要 GEM_HOME，PATH 块之外另提供自包含 pod 启动包装。
    mv -- "$target/bin/pod" "$target/bin/pod.real" || return 1
    {
        print -r -- '#!/bin/zsh'
        local ruby_bin="$(command -v ruby)"
        printf 'export PATH=%s:"$PATH"\n' "${(q)ruby_bin:h}"
        printf 'export GEM_HOME=%s GEM_PATH=%s\n' "${(q)target}" "${(q)target}"
        print -r -- 'exec "$(dirname "$0")/pod.real" "$@"'
    } > "$target/bin/pod" || return 1
    chmod u+x "$target/bin/pod" || return 1
    digest="$(tree_digest "$target")" || return 1
    write_receipt cocoapods tree "$target" "$version" "$digest" incomplete || return 1
    install_profile_block cocoapods "$target/bin" || return 1
    write_receipt cocoapods tree "$target" "$version" "$digest"
}

ensure_rubygems() {
    local consumer="$1" prefix=""
    if command -v ruby >/dev/null 2>&1 && ruby -e 'exit 0' >/dev/null 2>&1 &&
       command -v gem >/dev/null 2>&1 && gem --version >/dev/null 2>&1; then
        return 0
    fi
    NODE_FAILURE='当前任务所需 Ruby/RubyGems 缺失或损坏'
    repair_or_install_formula ruby "$consumer" || return $?
    prefix="$("$BREW_BIN" --prefix ruby)" || return 1
    export PATH="$prefix/bin:$PATH"
    rehash
    ruby -e 'exit 0' && gem --version || {
        log_message 'Ruby/RubyGems 修复后仍未通过真实复检，未继续 CocoaPods。'
        return 1
    }
}

compatible_ruby_formula() {
    local metadata="" version="" candidate="" candidate_metadata="" requirement="${NETWORK_OUTPUT:-}"
    require_homebrew >&2 || return 1
    metadata="$(mktemp "$STATE_DIR/logs/ruby-formula.XXXXXXXX")" || return 1
    retry_network_command "$metadata" "$BREW_BIN" info --json=v2 --formula ruby >&2 || return $?
    local -a candidates=("${(@f)$(ruby -rjson -rrubygems -e '
      data=JSON.parse(File.read(ARGV[0])).fetch("formulae").first;
      puts data.fetch("versioned_formulae",[]).sort_by{|name| Gem::Version.new(name.split("@").last)}.reverse
    ' "$metadata")}")
    for candidate in "${candidates[@]}"; do
        [[ "$candidate" == ruby@<->.<-> ]] || continue
        candidate_metadata="$(mktemp "$STATE_DIR/logs/ruby-candidate.XXXXXXXX")" || return 1
        retry_network_command "$candidate_metadata" "$BREW_BIN" info --json=v2 --formula "$candidate" >&2 || return $?
        if ruby -rjson -rrubygems -e '
          info=JSON.parse(File.read(ARGV[0])).fetch("formulae").first;
          exit 1 unless info.fetch("name")==ARGV[1] && info.fetch("keg_only")==true;
          text=File.read(ARGV[2]);
          line=text.lines.reverse.find{|s|s.match?(/requires Ruby(?: version)?/i)};
          exit 1 unless line;
          constraint=line.sub(/^.*requires Ruby(?: version)?\s*/i,"").split(/\.\s+(?:The|Your|Current)/i).first.strip.sub(/\.\z/,"");
          req=Gem::Requirement.new(*constraint.split(",").map(&:strip));
          exit(req.satisfied_by?(Gem::Version.new(info.fetch("versions").fetch("stable"))) ? 0 : 1)
        ' "$candidate_metadata" "$candidate" "$requirement"; then
            log_message "保留健康共享 Ruby；已核对 canonical name、keg_only 与当前 Gem 约束，选择独立 $candidate。" >&2
            print -r -- "$candidate"
            return 0
        fi
    done
    log_message '没有可验证且满足当前 Gem 约束的独立 Ruby provider；保留共享 Ruby 并明确阻断。' >&2
    return 1
}
repair_managed_cocoapods() {
    local target="$1" digest="" stage="" backup="" version=""
    read_receipt cocoapods && [[ "${RECEIPT[outcome]}" == installed ]] || {
        log_message "CocoaPods 前缀不健康但归属不明，保留人工内容，不强删：$target"
        return 1
    }
    digest="${RECEIPT[fingerprint]}"
    [[ "$(tree_digest "$target")" == "$digest" ]] || { log_message 'CocoaPods 人工内容已变化，保留待处理。'; return 1; }
    stage="$(mktemp -d "${target:h}/.cocoapods.repair.XXXXXXXX")" || return 1
    run_network_logged env GEM_HOME="$stage" GEM_PATH="$stage" gem install --no-document --install-dir "$stage" \
        --bindir "$stage/bin" --source https://rubygems.org cocoapods || return $?
    version="$(env GEM_HOME="$stage" GEM_PATH="$stage" "$stage/bin/pod" --version)" || return 1
    [[ "$(tree_digest "$target")" == "$digest" ]] || return 1
    backup="$STATE_DIR/backups/cocoapods.prefix.$(date +%Y%m%d-%H%M%S).$$"
    [[ ! -e "$backup" ]] || return 1
    mv -- "$target" "$backup" || return 1
    if ! mv -- "$stage" "$target"; then
        mv -- "$backup" "$target" || log_message "原 CocoaPods 恢复副本：$backup"
        return 1
    fi
    mv -- "$target/bin/pod" "$target/bin/pod.real" || return 1
    local ruby_bin="$(command -v ruby)"
    {
        print -r -- '#!/bin/zsh'
        printf 'export PATH=%s:"$PATH"\n' "${(q)ruby_bin:h}"
        printf 'export GEM_HOME=%s GEM_PATH=%s\n' "${(q)target}" "${(q)target}"
        print -r -- 'exec "$(dirname "$0")/pod.real" "$@"'
    } > "$target/bin/pod" || return 1
    chmod u+x "$target/bin/pod" || return 1
    run_logged "$target/bin/pod" --version || return 1
    write_receipt cocoapods tree "$target" "$version" "$(tree_digest "$target")"
}

ensure_git_lfs() {
    git lfs version >/dev/null 2>&1 && return 0
    NODE_FAILURE='当前 Git 配置任务缺少可执行 git-lfs'
    repair_or_install_formula git-lfs git-lfs-config || return $?
    local prefix="$("$BREW_BIN" --prefix)"
    export PATH="$prefix/bin:$PATH"
    rehash
    git lfs version || { log_message 'git-lfs 修复后未通过真实复检。'; return 1; }
}

install_git_config() {
    local target="$HOME/.gitconfig" backup="$STATE_DIR/backups/git-lfs-config.before" digest="" existed=0 result=0
    read_receipt git-lfs-config && { log_message '已有 Git 配置收据，请先反安装再重新配置。'; return 1; }
    [[ ! -L "$target" && ( ! -e "$target" || -f "$target" ) ]] || return 1
    ensure_git_lfs || return $?
    [[ ! -e "$target" ]] || { cp -p -- "$target" "$backup" || return 1; existed=1; }
    write_receipt git-lfs-config gitconfig "$target" "$existed" pending preparing || return 1
    run_logged git lfs install --skip-repo &&
        run_logged git config --global core.compression 0 &&
        run_logged git config --global http.postBuffer 524288000 || result=$?
    digest="$(file_digest "$target")" || return 1
    if (( result != 0 )); then
        write_receipt git-lfs-config gitconfig "$target" "$existed" "$digest" incomplete || return 1
        return "$result"
    fi
    write_receipt git-lfs-config gitconfig "$target" "$existed" "$digest"
}

install_software_repo() {
    local target="$HOME/Desktop/JobsKits/JobsSoftware.MacOS" commit="" actual_root=""
    if [[ -e "$target" || -L "$target" ]]; then
        actual_root="$(git -C "$target" rev-parse --show-toplevel 2>/dev/null)" &&
            [[ "$actual_root" == "${target:A}" ]] &&
            git -C "$target" rev-parse --verify HEAD >/dev/null 2>&1 ||
            { log_message "错误：已有目标不是可验证的独立软件仓，保留：$target"; return 1; }
        log_message "已有目标，保留原文件与仓库：$target"
        return 0
    fi
    [[ ! -L "$HOME/Desktop" && ! -L "$HOME/Desktop/JobsKits" ]] || return 1
    mkdir -p "${target:h}" || return 1
    log_message "来源：https://github.com/JobsKits/JobsSoftware.MacOS.git；目标：$target"
    write_receipt jobs-software git "$target" pending pending preparing || return 1
    run_logged git clone -- https://github.com/JobsKits/JobsSoftware.MacOS.git "$target" || return 1
    commit="$(git -C "$target" rev-parse HEAD)" || return 1
    write_receipt jobs-software git "$target" "$commit" "$(tree_digest "$target")"
}

env_backend() {
    local candidate="$CONFIG_ROOT/🌍JobsMacEnvVarConfigs/【MacOS】环境管理后端.command/【MacOS】环境管理后端.command"
    [[ -f "$candidate" && ! -L "$candidate" ]] || { log_message "环境配置后端尚未备妥：$candidate"; return 1; }
    /bin/zsh "$candidate" "$@"
}

install_component() {
    local component="$1"
    case "$component" in
        brew.*|cask.*|dependency.*) install_brew_component "$component" ;;
        rea|quicktype|codegraph) install_npm_component "$component" ;;
        homebrew) install_homebrew ;;
        oh-my-zsh) install_ohmyzsh ;;
        cocoapods) install_cocoapods ;;
        git-lfs-config) install_git_config ;;
        jobs-software) install_software_repo ;;
        jobs-env) env_backend --install all --yes ;;
        clt)
            ensure_clt ;;
        ios-platform)
            xcodebuild -version >/dev/null 2>&1 || { log_message '错误：需要选定完整 Xcode，请在终端完成安装与协议。'; return 1; }
            run_logged xcodebuild -downloadPlatform iOS -verbose || return 1
            [[ "$(component_status ios-platform)" == yes ]] || { log_message '下载结束但 iOS 运行时尚未验证，未记为成功。'; return 1; } ;;
    esac
}

ensure_clt() {
    local request="" request_code=0 poll="${JOBS_SETUP_CLT_POLL_SECONDS:-5}" remaining=0
    if xcode-select -p >/dev/null 2>&1 && xcrun --find clang >/dev/null 2>&1 &&
       git --version >/dev/null 2>&1; then
        log_message 'CLT / clang / Git 已可执行。'
        return 0
    fi
    [[ "$ACTION" == install && "$APPROVED" == 1 ]] || return 1
    request="$(mktemp "$STATE_DIR/logs/clt-request.XXXXXXXX")" || return 1
    xcode-select --install > "$request" 2>&1 || request_code=$?
    cat "$request"
    cat "$request" >> "$LOG_FILE"
    if (( request_code != 0 )) && ! /usr/bin/grep -Eiq 'requested|in progress|currently installing' "$request"; then
        log_message '系统安装器未接受请求；权限、许可或完整 Xcode 初始化请在系统界面处理，未自动接受协议。'
        return "$request_code"
    fi
    [[ "$poll" == <1-30> ]] || poll=5
    log_message '已请求一次 CLT 系统安装器；持续只读复检，用户完成后自动续行，可请求停止。'
    while true; do
        stop_requested && return 130
        if xcode-select -p >/dev/null 2>&1 && xcrun --find clang >/dev/null 2>&1 &&
           git --version >/dev/null 2>&1; then
            log_message 'CLT / clang / Git 已真实复检通过，自动继续原任务。'
            return 0
        fi
        remaining="$poll"
        while (( remaining > 0 )); do
            stop_requested && return 130
            sleep 1 || return $?
            (( remaining-- ))
        done
    done
}

uninstall_brew_component() {
    local component="$1" kind=formula package="${1#*.}" snapshot="" target="" users=""
    [[ "$component" == cask.* ]] && kind=cask
    if [[ "$component" == dependency.* ]]; then
        local link="" consumer=""
        for link in "$STATE_DIR/dependencies"/*.tsv(N); do
            consumer="${link:t:r}"
            if /usr/bin/grep -Fxq "$package" "$link" &&
               [[ -f "$(receipt_file "$consumer")" || "$(component_status "$consumer")" == yes ]]; then
                log_message "自动依赖仍供 $consumer 使用，保留：$package"
                return 1
            fi
        done
    fi
    find_homebrew || return 1
    [[ "$("$BREW_BIN" --prefix)" == "${RECEIPT[target]}" ]] || { log_message 'Homebrew 前缀已变化，保留。'; return 1; }
    snapshot="$(brew_snapshot "$kind" "$package" 2>/dev/null)" || {
        /bin/rm -f -- "$(receipt_file "$component")"
        log_message "组件已不存在：$component"
        return 0
    }
    [[ "$snapshot" == "${RECEIPT[version]}" ]] || { log_message "版本已变化，保留：$snapshot"; return 1; }
    target="$("$BREW_BIN" --cellar "$package" 2>/dev/null)"
    [[ "$kind" == cask ]] && target="${RECEIPT[target]}/Caskroom/$package"
    [[ "$(tree_digest "$target")" == "${RECEIPT[fingerprint]}" ]] || { log_message '安装内容已变化，保留。'; return 1; }
    if [[ "$kind" == formula ]]; then
        users="$("$BREW_BIN" uses --installed "$package")" || return 1
        [[ -z "$users" ]] || { log_message "仍被已安装工具依赖，保留：$package；依赖方：$users"; return 1; }
    fi
    run_logged "$BREW_BIN" uninstall "--$kind" "$package" || return 1
    brew_snapshot "$kind" "$package" >/dev/null 2>&1 && { log_message '卸载后仍存在，保留收据。'; return 1; }
    /bin/rm -f -- "$(receipt_file "$component")"
    release_automatic_dependencies "$component"
}

release_automatic_dependencies() {
    local component="$1" file="$STATE_DIR/dependencies/$1.tsv" formula=""
    [[ -f "$file" && ! -L "$file" ]] || return 0
    # 组件已撤回后解除关联；依赖仍保留为清单中的可选叶子，用户可明确选择卸载。
    mv -- "$file" "$STATE_DIR/backups/$component.dependencies.released.$(date +%Y%m%d-%H%M%S).$$" || return 1
    log_message "该组件的自动依赖关联已解除；保留独立依赖条目，按需在清单选择反安装，避免删除共享运行时。"
}

uninstall_component() {
    local component="$1" target="" expected="" digest="" current=""
    if [[ "$component" == jobs-env ]]; then
        env_backend --uninstall all --yes
        return $?
    fi
    if ! read_receipt "$component"; then
        if [[ "$(component_status "$component")" == no ]]; then
            log_message "未安装，无需处理：$component"
            return 0
        fi
        log_message "未取得本工具安装凭据，保留原有或共享环境：$component"
        return 1
    fi
    target="${RECEIPT[target]}"
    [[ "${RECEIPT[outcome]}" != preparing ]] || {
        log_message "安装中断且完整摘要未形成，保留目标与收据，需核对：$target"
        return 1
    }
    case "${RECEIPT[kind]}" in
        brew-formula|brew-cask) uninstall_brew_component "$component"; return $? ;;
        npm) expected="$(npm_prefix "$component")" ;;
        tree)
            case "$component" in
                oh-my-zsh) expected="$HOME/.oh-my-zsh" ;;
                cocoapods) expected="$HOME/.local/share/jobs-system-setup/cocoapods" ;;
                *) return 1 ;;
            esac ;;
        git) expected="$HOME/Desktop/JobsKits/JobsSoftware.MacOS" ;;
        gitconfig)
            [[ "$target" == "$HOME/.gitconfig" && "$(file_digest "$target")" == "${RECEIPT[fingerprint]}" ]] ||
                { log_message 'Git 配置存在后续修改，保留当前配置与恢复副本。'; return 1; }
            if [[ "${RECEIPT[version]}" == 1 ]]; then
                [[ -f "$STATE_DIR/backups/git-lfs-config.before" && ! -L "$STATE_DIR/backups/git-lfs-config.before" ]] || return 1
                cp -p -- "$target" "$STATE_DIR/backups/git-lfs-config.uninstall" || return 1
                cp -p -- "$STATE_DIR/backups/git-lfs-config.before" "$target" || return 1
            else
                /bin/rm -f -- "$target" || return 1
            fi
            /bin/rm -f -- "$(receipt_file "$component")"
            release_automatic_dependencies "$component" || return 1
            log_message 'Git 配置已恢复到本工具操作前状态。'
            return 0 ;;
        homebrew)
            expected="$HOME/.local/homebrew"
            [[ "$target" == "$expected" ]] || return 1
            [[ -x "$target/bin/brew" ]] || return 1
            current="$("$target/bin/brew" list --formula --versions)" || return 1
            [[ -z "$current" ]] || { log_message 'Homebrew 仍含 formula，保留共享包管理器。'; return 1; }
            current="$("$target/bin/brew" list --cask --versions)" || return 1
            [[ -z "$current" ]] || { log_message 'Homebrew 仍含 cask，保留共享包管理器。'; return 1; }
            # 没有进程引用且完整内容未变，才允许撤回本工具创建的空用户前缀。
            local ref_errors="$STATE_DIR/backups/homebrew.lsof" refs="" ref_code=0
            refs="$(/usr/sbin/lsof -n -F pn +D "$target" 2> "$ref_errors")"
            ref_code=$?
            [[ "$ref_code" == 1 && -z "$refs" && ! -s "$ref_errors" ]] ||
                { log_message 'Homebrew 仍被进程引用或无法确认引用状态，保留。'; return 1; } ;;
        *) return 1 ;;
    esac
    [[ "$target" == "$expected" && ! -L "$target" ]] || return 1
    if [[ ! -e "$target" ]]; then
        remove_profile_block "$component" "$target/bin" || return 1
        /bin/rm -f -- "$(receipt_file "$component")"
        return 0
    fi
    digest="$(tree_digest "$target")" || return 1
    [[ -n "$digest" && "$digest" == "${RECEIPT[fingerprint]}" ]] ||
        { log_message "内容被后续修改，保留：$target"; return 1; }
    if [[ "${RECEIPT[kind]}" == git ]]; then
        [[ -z "$(git -C "$target" status --porcelain)" &&
           "$(git -C "$target" rev-parse HEAD)" == "${RECEIPT[version]}" ]] ||
            { log_message '软件仓已变化，保留。'; return 1; }
    fi
    # 整个前缀属于该组件；摘要通过后才允许递归撤回，保留所有其它包。
    remove_profile_block "$component" "$target/bin" || return 1
    /bin/rm -r -- "$target" || return 1
    /bin/rm -f -- "$(receipt_file "$component")"
    release_automatic_dependencies "$component" || return 1
    log_message "已撤回受管组件：$component"
}

run_selected_components() {
    local component="" result=0
    local -a ordered=()
    for component in "${COMPONENT_IDS[@]}"; do
        (( ${SELECTED[(Ie)$component]} )) && ordered+=("$component")
    done
    if [[ "$ACTION" == uninstall ]]; then
        ordered=("${(@Oa)ordered}")
        local -a deferred=() first=()
        for component in "${ordered[@]}"; do
            if [[ "$component" == dependency.* ]]; then
                deferred+=("$component")
            else
                first+=("$component")
            fi
        done
        ordered=("${first[@]}" "${deferred[@]}")
    fi
    for component in "${ordered[@]}"; do
        if stop_requested; then
            printf 'JOBS_MANAGER_EVENT\t%s\tskipped\tnot-started\n' "$component"
            RESULT_CODE=130
            continue
        fi
        printf 'JOBS_MANAGER_EVENT\t%s\trunning\t%s\n' "$component" "$ACTION"
        log_message "[$ACTION] ${COMPONENT_NAMES[$component]} ($component)"
        if (( DRY_RUN )); then
            log_message "计划：$ACTION $component；当前状态：$(component_status "$component")；无写入。"
            printf 'JOBS_MANAGER_EVENT\t%s\tsuccess\t%s\n' "$component" planned
            continue
        fi
        if [[ "$ACTION" == install ]]; then
            install_component "$component"
        else
            uninstall_component "$component"
        fi
        result=$?
        if [[ "$ACTION" == install && ( "$result" == 130 || "$result" == 143 || "$STOP_OBSERVED" == 1 ) ]]; then
            printf 'JOBS_MANAGER_EVENT\t%s\tskipped\tcancelled\n' "$component"
            STOP_OBSERVED=1
            RESULT_CODE=130
            continue
        fi
        if (( result != 0 )); then
            (( RESULT_CODE == 130 )) || RESULT_CODE=1
            printf 'JOBS_MANAGER_EVENT\t%s\tfailed\t%s\n' "$component" "exit=$result"
            log_message "未完成：$component（退出码 $result）；其它明确选中组件继续。"
        else
            printf 'JOBS_MANAGER_EVENT\t%s\tsuccess\t%s\n' "$component" "$ACTION"
        fi
    done
    (( RESULT_CODE != 130 )) || print -r -- JOBS_MANAGER_STOPPED
    return "$RESULT_CODE"
}

show_help() {
    print -r -- '用法：【MacOS】环境管理后端.command --catalog'
    print -r -- '      【MacOS】环境管理后端.command --install <id...> --yes'
    print -r -- '      【MacOS】环境管理后端.command --uninstall <id...> --yes'
    print -r -- '      【MacOS】环境管理后端.command --install <id...> --dry-run'
    print -r -- '安装缺失 Homebrew 还需明确 --brew-location user；system 请使用原终端入口。'
    print -r -- '组件 ID 从 --catalog 获取。空选、未知 ID、未确认不会执行；不自动请求 sudo。'
}

dispatch_action() {
    case "$ACTION" in
        help) show_help ;;
        catalog|status) emit_catalog ;;
        install|uninstall)
            if (( ! DRY_RUN )); then
                prepare_transaction || return 1
            fi
            run_selected_components ;;
    esac
}

# 参数错误直接停止后端，不能在错误状态下分发写操作。
parse_required_arguments() {
  parse_arguments "$@"
  local argument_code=$?
  (( argument_code == 0 )) || exit "$argument_code"
}
# 编排入口阶段，失败与取消由具名职责函数处理。
main() {
    initialize_paths # 只读解析脚本与用户位置。
    initialize_catalog # 构建完整组件协议。
    parse_required_arguments "$@" # 校验选择与显式授权。
    show_intro # 机器查询外展示固定用途、边界和日志。
    dispatch_action # 查询无写入；写操作持锁执行并传播真实退出码。
}

main "$@"

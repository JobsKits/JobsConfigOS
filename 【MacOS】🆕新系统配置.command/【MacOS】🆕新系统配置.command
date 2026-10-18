#!/bin/zsh
# 脚本自述：
# - 脚本名称：【MacOS】🆕新系统配置.command
# - 核心用途：按需配置新 Mac 开发环境，并可安装 CodeGraph 代码地图工具。
# - 影响范围：选中的阶段可能安装软件、修改用户环境、配置 Git 或下载 Xcode 平台。
# - 运行提示：先阅读自述并按回车确认；每个阶段回车跳过、输入任意字符执行，缓存删除另需 YES。
# shell: zsh

# ==============================================================================
# macOS 新系统初始化脚本
# 说明：
# 1. 适合 .command 双击运行，也可终端执行
# 2. 每个安装阶段会在终端打印当前进度
# 3. 关键外网步骤会先检查网络（尤其 GitHub）
# 4. 最终从 main "$@" 统一收口
# ==============================================================================


# =========================
# 日志与彩色输出
# =========================
# 仅渲染自述：标题红色加粗，编号正文蓝色常规字重；非彩色终端输出纯文本。
# >>> Jobs Homebrew install choice >>>
# 输出安装诊断，避免混入返回的命令路径。
jobs_brew_note() {
  if [[ -n "${LOG_FILE:-}" && -f "$LOG_FILE" ]]; then
    print -r -- "ℹ $*" | tee -a "$LOG_FILE" >&2
  else
    print -u2 -r -- "ℹ $*"
  fi
}
# 验证候选能够执行；共享安装只读不代表未安装。
jobs_brew_candidate_ok() {
  local candidate="$1" prefix
  [[ -n "$candidate" && -x "$candidate" ]] || return 1
  HOMEBREW_NO_AUTO_UPDATE=1 "$candidate" --version >/dev/null 2>&1 || return 1
  prefix="$("$candidate" --prefix 2>/dev/null)" || return 1
  [[ "$prefix" == /* && -d "$prefix" ]]
}
# 发现既有健康安装，不以目录可写性决定是否重新安装。
jobs_brew_find() {
  local candidate
  local -a candidates
  candidates=("${JOBS_HOMEBREW_BIN:-}" "$(command -v brew 2>/dev/null)" /opt/homebrew/bin/brew /usr/local/bin/brew
    "${JOBS_HOMEBREW_INSTALL_PREFIX:-$HOME/.local/homebrew}/bin/brew" "$HOME/.homebrew/bin/brew")
  for candidate in "${candidates[@]}"; do
    if jobs_brew_candidate_ok "$candidate"; then
      print -r -- "$candidate"
      return 0
    fi
  done
  return 1
}
# 计算官方系统目录；实际支持范围和授权交由官方安装器处理。
jobs_brew_system_prefix() {
  case "$(/usr/bin/uname -m)" in
    arm64) print -r -- /opt/homebrew ;;
    *) print -r -- /usr/local ;;
  esac
}
# 缺失时强提示选择安装路径；YES 只表示选择系统目录，不验证密码或权限。
jobs_brew_choose_installation() {
  local answer="" system_prefix="$(jobs_brew_system_prefix)"
  if [[ ! -t 0 || ! -t 2 || "${IS_SOURCETREE_RUNTIME:-0}" == 1 ]]; then
    jobs_brew_note "缺少 Homebrew，需要人工选择安装路径；请在可交互终端重新运行，未执行安装。"
    return 1
  fi
  print -u2 -r -- "⚠ Homebrew 尚未就绪，必须先选择安装路径："
  print -u2 -r -- "1、输入精确大写 YES：选择系统标准目录 $system_prefix（Apple Silicon：/opt/homebrew；Intel：/usr/local）。"
  print -u2 -r -- "   这表示你准备向系统目录安装；官方安装器可能随后要求管理员密码，并自行验证权限。"
  print -u2 -r -- "2、其它输入或直接回车：选择用户目录 ${JOBS_HOMEBREW_INSTALL_PREFIX:-$HOME/.local/homebrew}，不使用 sudo；有管理员权限也可选此路径。"
  print -u2 -r -- "本步骤只选择路径，不收集或验证密码；选定路径失败就停止，不自动切换。按 Ctrl+C 取消整个任务。"
  print -u2 -n -r -- "➤ 安装路径选择："
  if ! IFS= read -r answer; then
    jobs_brew_note "输入已取消或结束，停止安装。"
    return 1
  fi
  if [[ "$answer" == YES ]]; then
    typeset -g JOBS_HOMEBREW_INSTALL_MODE=system
  else
    typeset -g JOBS_HOMEBREW_INSTALL_MODE=user
  fi
}
# 将官方系统安装器下载到临时文件后执行，失败不自动改装到用户目录。
jobs_brew_install_system() {
  local installer system_prefix="$(jobs_brew_system_prefix)" installer_result=0
  command -v curl >/dev/null 2>&1 || { jobs_brew_note "缺少 curl，无法获取官方安装器。"; return 1; }
  installer="$(mktemp "${TMPDIR:-/tmp}/jobs-homebrew-install.XXXXXX")" || return 1
  if curl -fsSL --connect-timeout 10 --max-time 120 https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o "$installer"; then
    /bin/bash "$installer" || installer_result=$?
  else
    installer_result=1
  fi
  rm -- "$installer"
  if (( installer_result != 0 )); then
    jobs_brew_note "系统目录安装失败（退出码 $installer_result）；停止，不自动切换安装路径。"
    return 1
  fi
  typeset -g JOBS_HOMEBREW_BIN="$system_prefix/bin/brew"
  jobs_brew_candidate_ok "$JOBS_HOMEBREW_BIN" || { jobs_brew_note "官方安装器结束后未找到健康 Homebrew：$JOBS_HOMEBREW_BIN"; return 1; }
}
# 克隆官方稳定版本到用户目录；不覆盖非空目录，不调用 sudo。
jobs_brew_install_user() {
  local prefix="${JOBS_HOMEBREW_INSTALL_PREFIX:-$HOME/.local/homebrew}" stage release_tag git_bin
  [[ "$prefix" == /* && "$prefix" != / && "$prefix" != *[[:space:]:]* ]] || {
    jobs_brew_note "Homebrew 用户前缀须为不含空白或冒号的绝对目录：$prefix"
    return 1
  }
  if [[ -L "$prefix" || ( -e "$prefix" && ! -d "$prefix" ) || ( -d "$prefix" && -n "$(ls -A "$prefix" 2>/dev/null)" ) ]]; then
    jobs_brew_note "用户安装目标非空或不是普通目录，不覆盖：$prefix"
    return 1
  fi
  git_bin="$(command -v git 2>/dev/null)"
  [[ -n "$git_bin" ]] && "$git_bin" --version >/dev/null 2>&1 || { jobs_brew_note "用户目录安装需要可用 Git；请先准备 Git / Command Line Tools。"; return 1; }
  command -v curl >/dev/null 2>&1 || { jobs_brew_note "缺少 curl，无法获取官方稳定版本。"; return 1; }
  export HOMEBREW_NO_SUDO=1
  mkdir -p "${prefix:h}" || return 1
  stage="$(mktemp -d "${prefix:h}/.jobs-homebrew.XXXXXX")" || return 1
  if ! curl -fsSL --connect-timeout 10 --max-time 60 https://api.github.com/repos/Homebrew/brew/releases/latest -o "$stage/release.json"; then
    rm -r -- "$stage"
    jobs_brew_note "获取官方稳定版本失败，停止安装。"
    return 1
  fi
  release_tag="$(sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([0-9][0-9.]*\)".*/\1/p' "$stage/release.json" | head -n 1)"
  if [[ ! "$release_tag" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]] ||
     ! GIT_TERMINAL_PROMPT=0 "$git_bin" -c http.lowSpeedLimit=1 -c http.lowSpeedTime=60 clone --depth 1 --branch "$release_tag" --single-branch https://github.com/Homebrew/brew.git "$stage/brew" ||
     ! "$git_bin" -C "$stage/brew" checkout -b stable ||
     ! "$git_bin" -C "$stage/brew" config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*' ||
     ! mkdir -p "$stage/brew/Cellar" "$stage/brew/Caskroom" "$stage/brew/etc" "$stage/brew/var"; then
    rm -r -- "$stage"
    jobs_brew_note "Homebrew 用户目录初始化失败，停止安装。"
    return 1
  fi
  # 空目录也只在下载成功后移除，避免提前改动用户的目标目录。
  if [[ -d "$prefix" ]] && ! rmdir -- "$prefix"; then
    rm -r -- "$stage"
    return 1
  fi
  if ! mv "$stage/brew" "$prefix"; then
    rm -r -- "$stage"
    return 1
  fi
  rm -r -- "$stage"
  typeset -g JOBS_HOMEBREW_BIN="$prefix/bin/brew"
  jobs_brew_candidate_ok "$JOBS_HOMEBREW_BIN" || { jobs_brew_note "用户目录安装后复检失败：$prefix"; return 1; }
}
# 只更新本模块的 shellenv 配置块，并保留配置文件的符号链接和权限。
jobs_brew_save_shellenv() {
  local profile_file="$HOME/.zprofile" profile_stage shellenv_line current_shell="${SHELL:-/bin/zsh}"
  [[ "${current_shell##*/}" != bash ]] || profile_file="$HOME/.bash_profile"
  shellenv_line='eval "$('"${(q)JOBS_HOMEBREW_BIN}"' shellenv)"'
  profile_stage="$(mktemp "${TMPDIR:-/tmp}/jobs-homebrew-profile.XXXXXX")" || return 1
  if [[ -e "$profile_file" || -L "$profile_file" ]]; then
    awk '
      $0 == "# >>> Jobs Homebrew shellenv >>>" { inside = 1; block = $0 ORS; next }
      inside {
        block = block $0 ORS
        if ($0 == "# <<< Jobs Homebrew shellenv <<<") { inside = 0; block = "" }
        next
      }
      { print }
      END { if (inside) printf "%s", block }
    ' "$profile_file" > "$profile_stage" || { rm -- "$profile_stage"; return 1; }
  fi
  {
    print -r -- '# >>> Jobs Homebrew shellenv >>>'
    print -rl -- "$shellenv_line" '# <<< Jobs Homebrew shellenv <<<'
  } >> "$profile_stage"
  if ! cmp -s "$profile_stage" "$profile_file"; then
    cat "$profile_stage" > "$profile_file" || { rm -- "$profile_stage"; jobs_brew_note "无法写入用户配置：$profile_file"; return 1; }
  fi
  rm -- "$profile_stage"
}
# 激活当前进程并验证 Ruby 命令层；只有新安装才持久化 shellenv。
jobs_brew_activate() {
  local brew_env
  brew_env="$("$JOBS_HOMEBREW_BIN" shellenv)" || return 1
  eval "$brew_env" || return 1
  typeset -g JOBS_HOMEBREW_PREFIX="$("$JOBS_HOMEBREW_BIN" --prefix)"
  export PATH="$JOBS_HOMEBREW_PREFIX/bin:$JOBS_HOMEBREW_PREFIX/sbin:$PATH"
  rehash
  HOMEBREW_NO_AUTO_UPDATE=1 "$JOBS_HOMEBREW_BIN" config >/dev/null || { jobs_brew_note "Homebrew 命令层复检失败，停止后续业务。"; return 1; }
  if [[ "${1:-}" == installed ]]; then
    if [[ "${JOBS_HOMEBREW_INSTALL_MODE:-}" == user && -z "${HOMEBREW_CASK_OPTS:-}" ]]; then
      export HOMEBREW_CASK_OPTS="--appdir=$HOME/Applications"
    fi
    jobs_brew_save_shellenv || return 1
  fi
}
# 复用或安装 Homebrew；失败时返回阶段，停止下游依赖安装。
jobs_brew_install_or_fail() {
  local installed=""
  if [[ "${DRY_RUN:-0}" == 1 ]]; then
    jobs_brew_note "演练：Homebrew 系统路径 $(jobs_brew_system_prefix)；用户路径 ${JOBS_HOMEBREW_INSTALL_PREFIX:-$HOME/.local/homebrew}；未询问或执行安装。"
    return 1
  fi
  if ! JOBS_HOMEBREW_BIN="$(jobs_brew_find)"; then
    jobs_brew_choose_installation || return 1
    case "$JOBS_HOMEBREW_INSTALL_MODE" in
      system) jobs_brew_install_system || return 1 ;;
      user) jobs_brew_install_user || return 1 ;;
      *) jobs_brew_note "安装路径选择无效，停止。"; return 1 ;;
    esac
    installed=installed
  fi
  jobs_brew_activate "$installed" || return 1
}
# <<< Jobs Homebrew install choice <<<
# 渲染内置自述；非彩色终端使用纯文本。
jobs_intro_style() {
  local intro_color=0
  if [ -t 1 ] && [ -n "${TERM:-}" ] && [ "${TERM:-}" != dumb ] &&
     [ -z "${NO_COLOR+x}" ] && [ "${PLAIN_OUTPUT:-0}" != 1 ] &&
     [ "${IS_SOURCETREE_RUNTIME:-0}" != 1 ]; then
    intro_color=1
  fi
  /usr/bin/awk -v color="$intro_color" -v role="${1:-body}" '
    BEGIN { esc = sprintf("%c", 27) }
    {
      gsub(esc "\\[[0-9;]*m", "")
      gsub(/\\(033|e|x1[bB])\[[0-9;]*m/, "")
      if (!color || $0 ~ /^[[:space:]]*$/) { print; next }
      numbered = ($0 ~ /^[[:space:]➤ℹ🔹✔⚠]*([0-9]+[、.)）]|[0-9]+️⃣|[-•])/)
      heading = ($0 ~ /^[[:space:]]*#{1,6}[[:space:]]/ || $0 ~ /[：:][[:space:]]*$/ || $0 ~ /^[[:space:]]*[=━─-]{3}/)
      title = (!numbered && (role == "title" || heading))
      if (role == "auto" && !seen && !numbered) title = 1
      if ($0 !~ /^[[:space:]]*[=━─-]+[[:space:]]*$/) seen = 1
      printf "%s%s%s\n", esc (title ? "[1;31m" : "[0;34m"), $0, esc "[0m"
    }
  '
}
SCRIPT_DIR=""
SCRIPT_PATH=""
SCRIPT_BASENAME=""
LOG_FILE=""
JOBS_CONFIG_ROOT=""
CODEGRAPH_INSTALLER=""
PLAIN_OUTPUT=0
# 统一输出终端信息并同步记录日志。
log() {
    if [[ "$PLAIN_OUTPUT" == 1 ]]; then
        print -r -- "$1" | /usr/bin/sed $'s/\033\\[[0-9;]*m//g' | tee -a "$LOG_FILE"
    else
        print -r -- "$1" | tee -a "$LOG_FILE"
    fi
}
# 输出 color echo 对应级别的日志信息。
color_echo()     { log $'\033[1;32m'"$1"$'\033[0m'; }
# 输出 info echo 对应级别的日志信息。
info_echo()      { log $'\033[1;34mℹ '"$1"$'\033[0m'; }
# 输出 success echo 对应级别的日志信息。
success_echo()   { log $'\033[1;32m✔ '"$1"$'\033[0m'; }
# 输出 warn echo 对应级别的日志信息。
warn_echo()      { log $'\033[1;33m⚠ '"$1"$'\033[0m'; }
# 输出 warm echo 对应级别的日志信息。
warm_echo()      { log $'\033[1;33m'"$1"$'\033[0m'; }
# 输出 note echo 对应级别的日志信息。
note_echo()      { log $'\033[1;35m➤ '"$1"$'\033[0m'; }
# 输出 error echo 对应级别的日志信息。
error_echo()     { log $'\033[1;31m✖ '"$1"$'\033[0m'; }
# 输出 err echo 对应级别的日志信息。
err_echo()       { log $'\033[1;31m'"$1"$'\033[0m'; }
# 输出 debug echo 对应级别的日志信息。
debug_echo()     { log $'\033[1;35m🐞 '"$1"$'\033[0m'; }
# 输出 highlight echo 对应级别的日志信息。
highlight_echo() { log $'\033[1;36m🔹 '"$1"$'\033[0m'; }
# 输出 gray echo 对应级别的日志信息。
gray_echo()      { log $'\033[0;90m'"$1"$'\033[0m'; }
# 输出 bold echo 对应级别的日志信息。
bold_echo()      { log $'\033[1m'"$1"$'\033[0m'; }
# 输出 underline echo 对应级别的日志信息。
underline_echo() { log $'\033[4m'"$1"$'\033[0m'; }

# =========================
# 全局配置
# =========================
readonly TOTAL_STAGES=9
CURRENT_STAGE=0
HOMEBREW_HEALTH_FAILED=0
typeset -a FAILED_STAGES=()
typeset -a SKIPPED_STAGES=()

readonly JOBS_SOFTWARE_REPO="https://github.com/JobsKits/JobsSoftware.MacOS.git"

# =========================
# Homebrew 第三方配置
# 说明：这里是平时最常改的区域；下面安装流程只读取这里的定义。
# =========================
# 这里配置 Homebrew@formulae
readonly -a BREW_FORMULAE=(
    git-lfs
    gh
    nushell
    rbenv
    node
    jenv
    fvm
    pnpm
    ruby
    python
    python3
    python@3.13
    fastlane
    mysql
    hugo
    openjdk
    openjdk@17
    yt-dlp
    ffmpeg
    go-task/tap/go-task
    uv
    fzf
    lazygit
    dufs
    git-filter-repo
)
# 这里配置 Homebrew@cask
readonly -a BREW_CASKS=(
    hammerspoon
    flutter
    trex
    vlc
    onlyoffice
    codex-app # 图形化界面
    codex # 终端使用
)
# =========================
# 通用基础函数
# =========================
# 打印分隔线
print_divider() {
    gray_echo "------------------------------------------------------------------------"
}
# 阻塞等待用户按回车
pause_for_enter() {
    local prompt="${1:-👉 请按回车继续，或按 Ctrl+C 取消...}"
    local answer=""
    print -r -- ""
    if [[ ! -t 0 ]]; then
        print -u2 -r -- "✖ 没有可交互输入，请在终端重新运行。"
        return 1
    fi
    read -r "answer?${prompt}" || return 1
}
# 普通安装与更新阶段默认跳过，仅在用户主动输入后执行。
ask_any_to_run() {
    local answer=""
    read -r "answer?$1（直接回车跳过；输入任意字符后回车执行）：" || return 1
    [[ -n "$answer" ]]
}
# 缓存删除等破坏性动作必须精确输入 YES。
confirm_yes() {
    local answer=""
    warn_echo "$1"
    read -r 'answer?请输入 YES 后回车执行；其它输入取消：' || return 1
    [[ "$answer" == YES ]]
}
# 输出阶段进度
progress_step() {
    local step_name="$1"
    CURRENT_STAGE=$((CURRENT_STAGE + 1))
    echo ""
    highlight_echo "当前系统配置进度：${CURRENT_STAGE}/${TOTAL_STAGES} 👉 ${step_name}"
    print_divider
}
# 命令执行包装：统一打印、不中断整体流程
run_cmd() {
    local desc="$1"
    shift

    note_echo "${desc}"
    debug_echo "执行命令：$*"

    "$@" 2>&1 | tee -a "$LOG_FILE"
    local exit_code="${pipestatus[1]}"

    if [[ $exit_code -eq 0 ]]; then
        success_echo "${desc}：完成"
    else
        error_echo "${desc}：失败（exit code: ${exit_code}）"
    fi

    return $exit_code
}
# 以 shell 字符串执行，适合复杂命令
run_sh() {
    local desc="$1"
    local cmd="$2"

    note_echo "${desc}"
    debug_echo "执行命令：${cmd}"

    /bin/zsh -c "${cmd}" 2>&1 | tee -a "$LOG_FILE"
    local exit_code="${pipestatus[1]}"

    if [[ $exit_code -eq 0 ]]; then
        success_echo "${desc}：完成"
    else
        error_echo "${desc}：失败（exit code: ${exit_code}）"
    fi

    return $exit_code
}
# 保留子安装器的真实终端交互；它们各自维护独立日志。
run_interactive_script() {
    local desc="$1" script_path="$2" exit_code=0
    note_echo "$desc"
    debug_echo "执行脚本：$script_path"
    /bin/zsh "$script_path" || exit_code=$?
    if (( exit_code == 0 )); then
        success_echo "$desc：完成"
    else
        error_echo "$desc：失败（exit code: $exit_code）"
    fi
    return "$exit_code"
}
# 为每个阶段提供明确选择，并收集失败和跳过结果。
run_optional_stage() {
    local stage_function="$1" stage_name="$2" exit_code=0
    progress_step "$stage_name"
    if ! ask_any_to_run "执行 ${stage_name} 阶段"; then
        SKIPPED_STAGES+=("$stage_name")
        info_echo "已跳过：$stage_name"
        return 0
    fi
    "$stage_function" || exit_code=$?
    if (( exit_code != 0 )); then
        FAILED_STAGES+=("$stage_name")
        error_echo "阶段失败：$stage_name（退出码 $exit_code）；后续独立阶段仍可选择。"
    fi
    return 0
}
# 检查命令是否存在
require_command() {
    local cmd="$1"
    if command -v "${cmd}" >/dev/null 2>&1; then
        return 0
    fi
    return 1
}
# 获取芯片架构
get_cpu_arch() {
    [[ "$(uname -m)" == "arm64" ]] && echo "arm64" || echo "x86_64"
}
# 查找 Homebrew 可执行文件
# 说明：双击 .command 时，PATH 经常拿不到 /opt/homebrew/bin 或 /usr/local/bin。
find_brew_bin() {
    jobs_brew_find
}
# 检测当前是否是双击启动
is_double_click_launch() {
    [[ -z "${TERM_PROGRAM:-}" ]] && return 0
    return 1
}
# 检测网络
check_url_access() {
    local url="$1"
    curl -I -L -s --connect-timeout 8 --max-time 15 "${url}" >/dev/null 2>&1
}
# 检查 GitHub 访问
ensure_github_access() {
    info_echo "开始检查 GitHub 网络连通性..."
    if check_url_access "https://github.com"; then
        success_echo "GitHub 网络访问正常"
        return 0
    fi

    error_echo "当前无法访问 GitHub。你现在的网络环境大概率无法直连 GitHub。"
    warm_echo "这一步在中国大陆网络环境下很常见，需要科学上网/VPN。"
    warm_echo "请先处理网络问题，再重新运行脚本。"
    return 1
}
# 检查 Homebrew 相关访问
ensure_brew_access() {
    info_echo "开始检查 Homebrew 安装所需网络..."
    if check_url_access "https://raw.githubusercontent.com"; then
        success_echo "Homebrew 安装源访问正常"
        return 0
    fi

    error_echo "当前无法访问 raw.githubusercontent.com，Homebrew / oh-my-zsh 安装会失败。"
    warm_echo "请先打开 VPN 或修复网络后再运行。"
    return 1
}
# 安装 Rosetta（仅 Apple Silicon，且未安装时）
ensure_rosetta_if_needed() {
    if [[ $(uname -m) == 'arm64' ]]; then
        if ! /usr/bin/pgrep oahd >/dev/null 2>&1; then
            run_cmd "安装 Rosetta 2" /usr/sbin/softwareupdate --install-rosetta --agree-to-license
        else
            info_echo "检测到 Rosetta 2 已安装，跳过"
        fi
    fi
}
# 准备只读展示路径；真实初始化放在自述确认之后。
prepare_intro_context() {
    local source_path="${BASH_SOURCE[0]:-${(%):-%x}}"
    SCRIPT_DIR="$(cd "$(dirname "$source_path")" && pwd)"
    SCRIPT_PATH="${SCRIPT_DIR}/${source_path:t}"
    SCRIPT_BASENAME="${source_path:t:r}"
    LOG_FILE="${TMPDIR:-/tmp}/${SCRIPT_BASENAME}.log"
    JOBS_CONFIG_ROOT="${SCRIPT_DIR:h}"
    CODEGRAPH_INSTALLER="${JOBS_CONFIG_ROOT:h}/JobsCommand@iOS/配置相关/【MacOS】⚙️安装代码地图CodeGraph.command/【MacOS】⚙️安装代码地图CodeGraph.command"
    if [[ ! -t 1 || -z "${TERM:-}" || "${TERM:-}" == dumb || -n "${NO_COLOR+x}" ]]; then
        PLAIN_OUTPUT=1
    fi
}
# 显示固定内置说明；确认前不写日志或执行安装。
show_script_intro_and_wait() {
    prepare_intro_context
    print -r -- '============================== 脚本内置自述 ==============================' | jobs_intro_style title
    print -r -- '【MacOS】🆕新系统配置.command' | jobs_intro_style title
    print -r -- '核心用途：按需准备新 Mac 开发环境，并可安装 CodeGraph 代码地图命令行工具。' | jobs_intro_style body
    print -r -- '1、CLT；2、Xcode 模拟器；3、oh-my-zsh；4、Homebrew；5、开发工具。' | jobs_intro_style body
    print -r -- '6、CodeGraph；7、npm / quicktype；8、gem / CocoaPods；9、Jobs 环境配置。' | jobs_intro_style body
    print -r -- '运行策略：每个阶段直接回车跳过，输入任意字符后回车执行；缓存删除另需输入 YES。' | jobs_intro_style body
    print -r -- '影响范围：选中的阶段会安装软件、修改用户配置、Git 全局设置或下载 Xcode 平台。' | jobs_intro_style body
    print -r -- 'Homebrew 使用前执行体检，doctor 失败时阻止后续 Brew 安装；更新列表单独确认，不全量升级或清理。' | jobs_intro_style body
    print -r -- 'CodeGraph 阶段只安装 CLI，不会自动给仓库建立 .codegraph 或修改 Codex 配置。' | jobs_intro_style body
    print -r -- '部分阶段可能请求管理员密码、弹出系统安装窗口或访问 GitHub。按 Ctrl+C 可随时取消。' | jobs_intro_style body
    print -r -- "日志文件：${LOG_FILE}" | jobs_intro_style body
    print -r -- '============================================================================' | jobs_intro_style title
    pause_for_enter '👉 已了解用途和影响，按回车进入阶段选择，或按 Ctrl+C 取消：' || exit 1
}
# =========================
# 阶段 1：Command Line Tools（CLT）
# =========================
# 检查 CLT；缺失时打开安装窗口，完整 Xcode 可用时接受协议。
stage_clt() {
    if xcode-select -p >/dev/null 2>&1 && xcrun --find clang >/dev/null 2>&1; then
        info_echo "Command Line Tools 已可用"
    else
        run_cmd "打开 Command Line Tools 安装窗口" xcode-select --install || return 1
        warn_echo "请完成系统安装后重新运行需要 CLT 的阶段。"
        return 1
    fi
    if xcodebuild -version >/dev/null 2>&1; then
        run_cmd "接受 Xcode License" sudo xcodebuild -license accept
    else
        info_echo "尚未选定完整 Xcode，跳过 Xcode License；可在安装 Xcode 后重新运行此阶段。"
    fi
}
# =========================
# 阶段 2：Xcode 模拟器配件
# =========================
# 在 Xcode 可用时按需清理缓存并下载 iOS 平台。
stage_xcode_simulator_assets() {
    if ! xcodebuild -version >/dev/null 2>&1; then
        error_echo "Xcode 尚不可用，请安装并用 xcode-select 选定完整 Xcode。"
        return 1
    fi
    if confirm_yes "是否删除 Xcode 与 CoreSimulator 缓存？缓存可重新生成，删除后首次启动可能变慢。"; then
        run_cmd "删除 Xcode 缓存" /bin/rm -r -f -- "$HOME/Library/Caches/com.apple.dt.Xcode" || return 1
        run_cmd "删除 CoreSimulator 缓存" /bin/rm -r -f -- "$HOME/Library/Developer/CoreSimulator/Caches" || return 1
    else
        info_echo "保留 Xcode 与 CoreSimulator 缓存"
    fi
    run_cmd "下载 iOS 模拟器平台" xcodebuild -downloadPlatform iOS -verbose
}
# =========================
# 阶段 3：ohmyzsh
# =========================
# 保留既有 oh-my-zsh；缺失时执行官方安装流程。
stage_oh_my_zsh() {
    if [[ -d "${HOME}/.oh-my-zsh" ]]; then
        info_echo "检测到 ~/.oh-my-zsh 已存在，跳过安装"
        return 0
    fi
    ensure_brew_access || return 1
    run_sh \
        "安装 oh-my-zsh" \
        'RUNZSH=no CHSH=no sh -c "$(curl -fsSL --connect-timeout 10 --max-time 120 https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"' || return 1
    warn_echo "oh-my-zsh 官方安装流程可能有交互输出，这是正常现象。"
}
# =========================
# 阶段 4：Homebrew
# 参考你给的双击安装升级思路，区分 Intel / Apple Silicon
# =========================
# 检查 Homebrew 命令层、前缀和诊断；任一失败时阻止 Brew 安装。
check_homebrew_health() {
    local prefix=""
    HOMEBREW_HEALTH_FAILED=1
    if ! run_cmd "Homebrew 版本体检" "$JOBS_HOMEBREW_BIN" --version; then
        error_echo "Homebrew 版本检查失败：$JOBS_HOMEBREW_BIN"
        return 1
    fi
    if ! prefix="$(HOMEBREW_NO_AUTO_UPDATE=1 "$JOBS_HOMEBREW_BIN" --prefix 2>>"$LOG_FILE")"; then
        error_echo "Homebrew 前缀体检失败：$JOBS_HOMEBREW_BIN --prefix；详情见日志。"
        return 1
    fi
    if [[ "$prefix" != /* || ! -d "$prefix" ]]; then
        error_echo "Homebrew 前缀不可用：$prefix"
        return 1
    fi
    info_echo "Homebrew 实际前缀：$prefix"
    if ! run_cmd "Homebrew 配置体检" "$JOBS_HOMEBREW_BIN" config ||
       ! run_cmd "Homebrew 健康诊断" "$JOBS_HOMEBREW_BIN" doctor; then
        error_echo "Homebrew 体检未通过，停止下游 Brew / CodeGraph 安装；请按上方诊断修复后重试。"
        return 1
    fi
    HOMEBREW_HEALTH_FAILED=0
    success_echo "Homebrew 健康体检通过"
}
# 复用健康 Homebrew；没有安装时明确提示先执行 Homebrew 阶段。
require_healthy_homebrew() {
    if [[ "$HOMEBREW_HEALTH_FAILED" == 1 ]]; then
        error_echo "本次 Homebrew 体检失败，已阻止后续依赖安装。"
        return 1
    fi
    if ! JOBS_HOMEBREW_BIN="$(jobs_brew_find)"; then
        error_echo "未发现可用 Homebrew，请先执行 Homebrew 阶段。"
        return 1
    fi
    jobs_brew_activate || return 1
    check_homebrew_health
}
# 需要时安装 Homebrew；已有安装只在主动确认后更新软件列表。
stage_homebrew() {
    if ! jobs_brew_install_or_fail; then
        HOMEBREW_HEALTH_FAILED=1
        return 1
    fi
    check_homebrew_health || return 1
    if ask_any_to_run "更新 Homebrew 软件列表（brew update）"; then
        run_cmd "更新 Homebrew 软件列表" "$JOBS_HOMEBREW_BIN" update || return 1
        check_homebrew_health || return 1
    else
        info_echo "保留当前 Homebrew 软件列表"
    fi
}
# =========================
# 阶段 5：brew 安装开发工具
# =========================
# 兼容带 tap 前缀的软件名，检查 formula 是否已安装。
brew_formula_installed() {
    local pkg="$1"
    local short_name="${pkg:t}"

    "$JOBS_HOMEBREW_BIN" list --formula --versions "${pkg}" >/dev/null 2>&1 && return 0
    "$JOBS_HOMEBREW_BIN" list --formula --versions "${short_name}" >/dev/null 2>&1 && return 0

    return 1
}
# 检查图形应用是否已通过 Homebrew 安装。
brew_cask_installed() {
    local pkg="$1"
    "$JOBS_HOMEBREW_BIN" list --cask --versions "${pkg}" >/dev/null 2>&1
}
# 按 formula 的真实前缀检查 3.13，避免误用 PATH 中的其它 Python。
check_python313_health() {
    local python_prefix="" python_bin="" python_version=""
    if ! python_prefix="$("$JOBS_HOMEBREW_BIN" --prefix python@3.13 2>>"$LOG_FILE")"; then
        error_echo "无法解析 python@3.13 安装前缀；详情见日志。"
        return 1
    fi
    python_bin="${python_prefix}/bin/python3.13"
    if [[ "$python_prefix" != /* || ! -x "$python_bin" ]]; then
        error_echo "python@3.13 解释器不可用：$python_bin"
        return 1
    fi
    if ! python_version="$("$python_bin" --version 2>>"$LOG_FILE")" ||
       [[ "$python_version" != "Python 3.13."* ]]; then
        error_echo "python@3.13 版本体检失败：$python_bin（${python_version:-无版本输出}）；请查看日志。"
        return 1
    fi
    success_echo "${python_version} 体检通过：$python_bin"
}
# 补装缺失的 3.13，已有安装损坏时只重装一次并复检。
ensure_python313() {
    local install_action=install
    if brew_formula_installed python@3.13; then
        if check_python313_health; then
            return 0
        fi
        warn_echo "已有 python@3.13 未通过体检，将尝试重装一次。"
        install_action=reinstall
    fi
    run_cmd "${install_action} python@3.13" "$JOBS_HOMEBREW_BIN" "$install_action" python@3.13 || return 1
    rehash
    if ! check_python313_health; then
        error_echo "python@3.13 安装或修复后仍不可用，停止开发工具阶段；请检查 Brew 日志后重试。"
        return 1
    fi
}
# 只补装缺失的 formula，失败时保留具体包名。
brew_install_if_needed() {
    local pkg="$1"

    if [[ "$pkg" == python@3.13 ]]; then
        ensure_python313
        return $?
    fi
    if brew_formula_installed "${pkg}"; then
        info_echo "brew formula 已安装：${pkg}"
    else
        if ! run_cmd "安装 brew formula：${pkg}" "$JOBS_HOMEBREW_BIN" install "${pkg}"; then
            error_echo "brew formula 安装失败：${pkg}"
            return 1
        fi
    fi
}
# 只补装缺失的 cask，失败时保留具体应用名。
brew_install_cask_if_needed() {
    local pkg="$1"

    if brew_cask_installed "${pkg}"; then
        info_echo "brew cask 已安装：${pkg}"
    else
        if ! run_cmd "安装 brew cask：${pkg}" "$JOBS_HOMEBREW_BIN" install --cask "${pkg}"; then
            error_echo "brew cask 安装失败：${pkg}"
            return 1
        fi
    fi
}
# 通过健康 Homebrew 补装工具、体检 Python 3.13，并配置原有 Git LFS 参数。
stage_brew_packages() {
    require_healthy_homebrew || return 1

    info_echo "开始安装 brew formula..."
    local pkg
    for pkg in "${BREW_FORMULAE[@]}"; do
        brew_install_if_needed "${pkg}" || return 1
    done

    # Git LFS 初始化
    if require_command git && git lfs version >/dev/null 2>&1; then
        info_echo "初始化 Git LFS..."
        run_cmd "初始化 Git LFS" git lfs install || {
            error_echo "Git LFS 初始化失败"
            return 1
        }

        info_echo "配置 Git 大文件传输参数..."
        run_cmd "配置 Git 压缩参数" git config --global core.compression 0 || {
            error_echo "git config core.compression 失败"
            return 1
        }

        run_cmd "配置 Git HTTP 传输缓冲" git config --global http.postBuffer 524288000 || {
            error_echo "git config http.postBuffer 失败"
            return 1
        }
    else
        error_echo "git-lfs 未正确安装，无法执行 git lfs install"
        return 1
    fi

    info_echo "开始安装 brew cask..."
    for pkg in "${BREW_CASKS[@]}"; do
        brew_install_cask_if_needed "${pkg}" || return 1
    done

    success_echo "开发工具安装阶段完成；未执行全量升级或缓存清理。"
}
# =========================
# 阶段 6：CodeGraph
# =========================
# 调用相邻 JobsCommand 仓库中的独立安装器，不隐式创建仓库索引。
stage_codegraph() {
    if [[ "$HOMEBREW_HEALTH_FAILED" == 1 ]]; then
        error_echo "本次 Homebrew 体检失败，已阻止 CodeGraph 安装。"
        return 1
    fi
    if [[ ! -f "$CODEGRAPH_INSTALLER" ]]; then
        error_echo "未找到 CodeGraph 安装器：$CODEGRAPH_INSTALLER"
        warn_echo "请将 JobsCommand@iOS 与 JobsConfigOS 放在同一父目录，并保留安装器的完整目录结构。"
        return 1
    fi
    info_echo "独立安装器将逐层体检 Homebrew、Node.js、npm 与 CodeGraph。"
    run_interactive_script "安装 / 复检 CodeGraph CLI" "$CODEGRAPH_INSTALLER"
}
# 检查 Node 与 npm 可执行性后安装原有 quicktype 工具。
stage_npm() {
    if ! require_command node || ! require_command npm ||
       ! run_cmd "Node.js 版本体检" node --version ||
       ! run_cmd "Node.js 运行体检" node -e 'process.exit(0)' ||
       ! run_cmd "npm 版本体检" npm --version; then
        error_echo "Node.js / npm 尚不可用，请先准备工具链；未执行 quicktype 安装。"
        return 1
    fi

    run_cmd "全局安装 quicktype" sudo npm install -g quicktype
}
# =========================
# 阶段 8：gem
# =========================
# 验证 RubyGems 后安装 CocoaPods。
stage_gem() {
    if ! require_command gem || ! run_cmd "RubyGems 版本体检" gem --version; then
        error_echo "gem 不存在，跳过 cocoapods 安装"
        return 1
    fi

    run_cmd "安装 cocoapods" sudo gem install cocoapods
}
# =========================
# 阶段 9：Jobs
# 下载仓库并执行 install.command
# =========================
# 克隆缺失仓库；已有脏工作区保持原样，干净工作区只允许快进更新。
clone_or_pull_repo() {
    local repo_url="$1"
    local target_dir="$2"
    local repository_root="" target_root=""

    if git -C "$target_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        repository_root="$(git -C "$target_dir" rev-parse --show-toplevel)" || return 1
        target_root="$(cd "$target_dir" && pwd -P)" || return 1
        if [[ "$repository_root" != "$target_root" ]]; then
            error_echo "目标只是其它 Git 仓库内的目录，不作为独立仓库更新：$target_dir"
            return 1
        fi
        if [[ -n "$(git -C "$target_dir" status --porcelain)" ]]; then
            warn_echo "仓库存在未提交改动，保留工作区并跳过更新：$target_dir"
            return 0
        fi
        run_cmd "更新仓库 ${target_dir}" git -C "$target_dir" pull --ff-only
    elif [[ -e "$target_dir" ]]; then
        error_echo "目标已存在但不是可用 Git 仓库，不覆盖：$target_dir"
        return 1
    else
        run_cmd "克隆仓库到 ${target_dir}" git clone -- "$repo_url" "$target_dir"
    fi
}
# 准备 Jobs 软件仓，并执行当前 JobsConfigOS 中的环境配置入口。
stage_jobs() {
    local base_dir="${HOME}/Desktop/JobsKits"
    local software_dir="${base_dir}/JobsSoftware.MacOS"
    local install_script="${JOBS_CONFIG_ROOT}/🌍JobsMacEnvVarConfigs/install.command/install.command"
    if [[ ! -f "$install_script" ]]; then
        error_echo "未找到本仓环境配置入口：$install_script"
        warn_echo "请先准备 🌍JobsMacEnvVarConfigs 子模块，再运行 Jobs 阶段。"
        return 1
    fi
    ensure_github_access || return 1
    run_cmd "创建 JobsKits 工作目录" mkdir -p "$base_dir" || return 1
    clone_or_pull_repo "$JOBS_SOFTWARE_REPO" "$software_dir" || return 1
    run_interactive_script "同步本仓 JobsMacEnvVarConfigs 到当前用户环境" "$install_script"
}
# =========================
# 手动下载环节
# =========================
# 用户主动选择后才打开软件官网下载页。
open_manual_download_pages() {
    if ! ask_any_to_run "打开需要手动下载的软件官网"; then
        info_echo "已跳过手动下载页面"
        return 0
    fi
    echo ""
    highlight_echo "接下来会为你打开需要手动下载安装的页面："
    gray_echo "• Visual Studio Code"
    gray_echo "• Android Studio"
    gray_echo "• Python Downloads"

    run_cmd "打开 VS Code 下载页" open "https://code.visualstudio.com/" || FAILED_STAGES+=("VS Code 下载页")
    run_cmd "打开 Android Studio 下载页" open "https://developer.android.com/studio?hl=zh-cn" || FAILED_STAGES+=("Android Studio 下载页")
    run_cmd "打开 Python 下载页" open "https://www.python.org/downloads/" || FAILED_STAGES+=("Python 下载页")
}
# =========================
# 收尾
# =========================
# 汇总已选阶段的真实结果以及日志位置。
finish_summary() {
    echo ""
    print_divider
    if (( ${#FAILED_STAGES} == 0 )); then
        success_echo "macOS 新系统配置流程结束，选中的阶段均已完成。"
    else
        error_echo "macOS 新系统配置流程结束，失败 ${#FAILED_STAGES} 项：${(j:、:)FAILED_STAGES}"
    fi
    info_echo "日志文件位置：${LOG_FILE}"
    info_echo "跳过 ${#SKIPPED_STAGES} 个阶段：${(j:、:)SKIPPED_STAGES}"
    warm_echo "CodeGraph 只有安装 CLI；需要建图时在目标目录运行 codemap，或运行 codemap 后追加目标目录。"
    print_divider
}
# =========================
# 主函数
# 说明：
# 1. 所有模块统一从 main 进入
# 2. 便于后续继续加阶段、加参数、加开关
# 3. 最终使用 main \"$@\" 一键唤起
# =========================
# 初始化本次运行的日志文件。
initialize_execution_log() {
    : > "$LOG_FILE" || exit 1
    info_echo "开始新系统配置；架构：$(get_cpu_arch)"
}
# 编排脚本的高层业务流程。
# 初始化脚本运行环境，并集中承载原有的顶层执行逻辑。
initialize_script_runtime() {
    set -u
    setopt NO_NOMATCH
    export HOMEBREW_NO_AUTO_UPDATE=1
    if [[ "$(uname -s)" != Darwin ]]; then
        print -u2 -r -- '✖ 此入口仅支持 macOS，请在 Mac 终端中运行。'
        exit 1
    fi
}
# 等待查看结果，并用退出码反映是否存在失败阶段。
finish_and_wait() {
    pause_for_enter '👉 阶段选择与执行已结束，按回车退出：' || exit 1
    (( ${#FAILED_STAGES} == 0 )) || exit 1
}
# 编排脚本的高层业务流程。
main() {
    show_script_intro_and_wait # 展示内置自述，回车确认后进入阶段选择。
    initialize_script_runtime # 确认 macOS 并集中初始化 Shell 运行选项。
    initialize_execution_log # 确认后才初始化本次执行日志。
    run_optional_stage stage_clt 'Command Line Tools（CLT）' # 按需安装 CLT 并处理 Xcode 协议。
    run_optional_stage stage_xcode_simulator_assets 'Xcode 模拟器配件' # 按需清理缓存并下载 iOS 平台。
    run_optional_stage stage_oh_my_zsh 'oh-my-zsh' # 按需安装终端配置框架。
    run_optional_stage stage_homebrew 'Homebrew' # 安装或复用 Homebrew，并在使用前体检。
    run_optional_stage stage_brew_packages 'Homebrew 开发工具' # 体检通过后按需补装开发工具。
    run_optional_stage stage_codegraph 'CodeGraph 代码地图 CLI' # 调用相邻仓库中的独立安装器。
    run_optional_stage stage_npm 'npm / quicktype' # 按需安装原有 npm 工具。
    run_optional_stage stage_gem 'gem / CocoaPods' # 按需安装原有 Ruby 工具。
    run_optional_stage stage_jobs 'Jobs 环境配置' # 准备软件仓并同步当前仓库的终端配置。
    open_manual_download_pages # 按需打开手动下载的软件官网。
    finish_summary # 汇总完成、跳过与失败结果。
    finish_and_wait # 等待查看摘要，并传播真实失败状态。
}

main "$@"

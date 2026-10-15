#!/bin/zsh
# 脚本自述：
# - 脚本名称：【MacOS】🆕新系统配置.command
# - 核心用途：执行“🆕新系统配置”对应的本机环境配置任务。
# - 影响范围：可能安装、更新或修改当前用户的工具链与配置文件。
# - 运行提示：运行后会先打印内置自述；终端模式按回车确认后继续，按 Ctrl+C 可取消。

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
  print -u2 -r -- "ℹ $*"
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
# 在原版安装位置复用或安装 Homebrew，安装失败必须终止外层业务。
jobs_brew_install_or_exit() {
  local installed=""
  if [[ "${DRY_RUN:-0}" == 1 ]]; then
    jobs_brew_note "演练：Homebrew 系统路径 $(jobs_brew_system_prefix)；用户路径 ${JOBS_HOMEBREW_INSTALL_PREFIX:-$HOME/.local/homebrew}；未询问或执行安装。"
    return 0
  fi
  if ! JOBS_HOMEBREW_BIN="$(jobs_brew_find)"; then
    jobs_brew_choose_installation || exit 1
    case "$JOBS_HOMEBREW_INSTALL_MODE" in
      system) jobs_brew_install_system || exit 1 ;;
      user) jobs_brew_install_user || exit 1 ;;
      *) jobs_brew_note "安装路径选择无效，停止。"; exit 1 ;;
    esac
    installed=installed
  fi
  jobs_brew_activate "$installed" || exit 1
}
# <<< Jobs Homebrew install choice <<<
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
SCRIPT_BASENAME=$(basename "$0" | sed 's/\.[^.]*$//')   # 当前脚本名（去掉扩展名）
LOG_FILE="/tmp/${SCRIPT_BASENAME}.log"                  # 设置对应的日志文件路径
# 统一输出终端信息并同步记录日志。
log()            { echo -e "$1" | tee -a "$LOG_FILE"; }
# 输出 color echo 对应级别的日志信息。
color_echo()     { log "\033[1;32m$1\033[0m"; }         # ✅ 正常绿色输出
# 输出 info echo 对应级别的日志信息。
info_echo()      { log "\033[1;34mℹ $1\033[0m"; }       # ℹ 信息
# 输出 success echo 对应级别的日志信息。
success_echo()   { log "\033[1;32m✔ $1\033[0m"; }       # ✔ 成功
# 输出 warn echo 对应级别的日志信息。
warn_echo()      { log "\033[1;33m⚠ $1\033[0m"; }       # ⚠ 警告
# 输出 warm echo 对应级别的日志信息。
warm_echo()      { log "\033[1;33m$1\033[0m"; }         # 🟡 温馨提示（无图标）
# 输出 note echo 对应级别的日志信息。
note_echo()      { log "\033[1;35m➤ $1\033[0m"; }       # ➤ 说明
# 输出 error echo 对应级别的日志信息。
error_echo()     { log "\033[1;31m✖ $1\033[0m"; }       # ✖ 错误
# 输出 err echo 对应级别的日志信息。
err_echo()       { log "\033[1;31m$1\033[0m"; }         # 🔴 错误纯文本
# 输出 debug echo 对应级别的日志信息。
debug_echo()     { log "\033[1;35m🐞 $1\033[0m"; }      # 🐞 调试
# 输出 highlight echo 对应级别的日志信息。
highlight_echo() { log "\033[1;36m🔹 $1\033[0m"; }      # 🔹 高亮
# 输出 gray echo 对应级别的日志信息。
gray_echo()      { log "\033[0;90m$1\033[0m"; }         # ⚫ 次要信息
# 输出 bold echo 对应级别的日志信息。
bold_echo()      { log "\033[1m$1\033[0m"; }            # 📝 加粗
# 输出 underline echo 对应级别的日志信息。
underline_echo() { log "\033[4m$1\033[0m"; }            # 🔗 下划线

# =========================
# 全局配置
# =========================
readonly TOTAL_STAGES=8
CURRENT_STAGE=0

readonly JOBS_SOFTWARE_REPO="https://github.com/JobsKits/JobsSoftware.MacOS.git"
readonly JOBS_ENV_REPO="https://github.com/JobsKits/JobsMacEnvVarConfig.git"

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
    echo ""
    read "?${prompt}"
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

    "$@"
    local exit_code=$?

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

    /bin/zsh -c "${cmd}"
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        success_echo "${desc}：完成"
    else
        error_echo "${desc}：失败（exit code: ${exit_code}）"
    fi

    return $exit_code
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
ensure_github_access_or_exit() {
    info_echo "开始检查 GitHub 网络连通性..."
    if check_url_access "https://github.com"; then
        success_echo "GitHub 网络访问正常"
        return 0
    fi

    error_echo "当前无法访问 GitHub。你现在的网络环境大概率无法直连 GitHub。"
    warm_echo "这一步在中国大陆网络环境下很常见，需要科学上网/VPN。"
    warm_echo "请先处理网络问题，再重新运行脚本。"
    pause_for_enter "👉 GitHub 不可访问。请按回车结束脚本..."
    exit 1
}
# 检查 Homebrew 相关访问
ensure_brew_access_or_exit() {
    info_echo "开始检查 Homebrew 安装所需网络..."
    if check_url_access "https://raw.githubusercontent.com"; then
        success_echo "Homebrew 安装源访问正常"
        return 0
    fi

    error_echo "当前无法访问 raw.githubusercontent.com，Homebrew / oh-my-zsh 安装会失败。"
    warm_echo "请先打开 VPN 或修复网络后再运行。"
    pause_for_enter "👉 网络未就绪。请按回车结束脚本..."
    exit 1
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
# =========================
# 自述文件 / 启动说明
# =========================
show_readme_and_block() {
    clear 2>/dev/null || true
  print -r -- '============================== 脚本内置自述 ==============================' | jobs_intro_style title
  print -r -- '脚本名称：【MacOS】🆕新系统配置.command' | jobs_intro_style title
  print -r -- '核心用途：执行“🆕新系统配置”对应的本机环境配置任务。' | jobs_intro_style body
  print -r -- '影响范围：可能安装、更新或修改当前用户的工具链与配置文件。' | jobs_intro_style body
  print -r -- '取消方式：确认前按 Ctrl+C 终止，不会继续执行后续业务。' | jobs_intro_style body
  print -r -- '============================================================================' | jobs_intro_style title

    echo "" | jobs_intro_style body
    bold_echo "========================= macOS 新系统配置脚本说明 =========================" | jobs_intro_style title
    echo "" | jobs_intro_style body

    info_echo "用途：自动执行一套新 Mac 常用开发环境初始化流程。" | jobs_intro_style body
    info_echo "执行方式：支持双击 .command 运行，也支持终端手动执行。" | jobs_intro_style body
    echo "" | jobs_intro_style body

    highlight_echo "本脚本将尝试执行以下阶段：" | jobs_intro_style title
    gray_echo "1. 【Command Line Tools（CLT）】" | jobs_intro_style body
    gray_echo "2. 【Xcode模拟器配件】" | jobs_intro_style body
    gray_echo "3. 【ohmyzsh】" | jobs_intro_style body
    gray_echo "4. 【Homebrew】" | jobs_intro_style body
    gray_echo "5. 【brew 安装开发工具】" | jobs_intro_style body
    gray_echo "6. 【npm】" | jobs_intro_style body
    gray_echo "7. 【gem】" | jobs_intro_style body
    gray_echo "8. 【Jobs】" | jobs_intro_style body
    echo "" | jobs_intro_style body

    warn_echo "注意事项：" | jobs_intro_style title
    gray_echo "• 脚本中包含 sudo 命令，执行时可能要求输入系统密码" | jobs_intro_style body
    gray_echo "• 部分步骤依赖 GitHub / raw.githubusercontent.com，网络不通会失败" | jobs_intro_style body
    gray_echo "• xcode-select --install 可能弹出系统图形安装窗口" | jobs_intro_style body
    gray_echo "• oh-my-zsh 官方脚本可能有交互行为，属于正常现象" | jobs_intro_style body
    gray_echo "• 某些图形应用会使用 brew cask 安装，耗时取决于网络与机器性能" | jobs_intro_style body
    gray_echo "• 手动软件下载链接会在最后自动打开浏览器" | jobs_intro_style body
    echo "" | jobs_intro_style body

    warm_echo "日志文件：${LOG_FILE}" | jobs_intro_style body
    echo "" | jobs_intro_style body

    pause_for_enter "👉 请确认没有误操作。按回车继续执行，或按 Ctrl+C 取消..."
}
# =========================
# 阶段 1：Command Line Tools（CLT）
# =========================
stage_clt() {
    progress_step "Command Line Tools（CLT）"

    run_cmd "安装 Command Line Tools" xcode-select --install
    warn_echo "如果系统提示“Command Line Tools 已安装”，这是正常情况。"

    run_cmd "接受 Xcode License" sudo xcodebuild -license accept
}
# =========================
# 阶段 2：Xcode 模拟器配件
# =========================
stage_xcode_simulator_assets() {
    progress_step "Xcode模拟器配件"

    run_sh "删除 Xcode 缓存" 'rm -rf ~/Library/Caches/com.apple.dt.Xcode'
    run_sh "删除 CoreSimulator 缓存" 'rm -rf ~/Library/Developer/CoreSimulator/Caches'
    run_cmd "下载 iOS 模拟器平台" xcodebuild -downloadPlatform iOS -verbose
}
# =========================
# 阶段 3：ohmyzsh
# =========================
stage_oh_my_zsh() {
    progress_step "ohmyzsh"

    ensure_brew_access_or_exit

    if [[ -d "${HOME}/.oh-my-zsh" ]]; then
        info_echo "检测到 ~/.oh-my-zsh 已存在，跳过安装"
        return 0
    fi

    run_sh \
        "安装 oh-my-zsh" \
        'sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"'

    warn_echo "oh-my-zsh 官方安装流程可能有交互输出，这是正常现象。"
}
# =========================
# 阶段 4：Homebrew
# 参考你给的双击安装升级思路，区分 Intel / Apple Silicon
# =========================
setup_brew_shellenv() {
  local jobs_existing_brew=""
  if jobs_existing_brew="$(jobs_brew_find)"; then
    JOBS_HOMEBREW_BIN="$jobs_existing_brew"
    jobs_brew_activate || return 1
  fi
    local brew_bin="$1"
    local target_file="${HOME}/.zprofile"
    local shellenv_line="eval \"\$(${brew_bin} shellenv)\""

    if [[ ! -x "${brew_bin}" ]]; then
        error_echo "Homebrew 可执行文件不存在或不可执行：${brew_bin}"
        return 1
    fi

    if [[ ! -f "${target_file}" ]]; then
        touch "${target_file}"
    fi

    if grep -Fq "${shellenv_line}" "${target_file}"; then
        info_echo "${target_file} 已存在 Homebrew shellenv 配置，跳过写入"
    else
        echo "" >> "${target_file}"
        echo "# Homebrew shellenv" >> "${target_file}"
        echo "${shellenv_line}" >> "${target_file}"
        success_echo "已写入 Homebrew 环境变量到 ${target_file}"
    fi

    eval "$(${brew_bin} shellenv)"
}
# 准备并配置 install or upgrade homebrew 对应的运行条件。
install_or_upgrade_homebrew() {
  local jobs_existing_brew=""
  if jobs_existing_brew="$(jobs_brew_find)"; then
    JOBS_HOMEBREW_BIN="$jobs_existing_brew"
    jobs_brew_activate || return 1
  fi
  if [[ "${DRY_RUN:-0}" == 1 ]]; then
    jobs_brew_install_or_exit
    return 0
  fi
    local arch
    local brew_bin
    arch="$(get_cpu_arch)"

    ensure_brew_access_or_exit

    # 先找现有 Homebrew。双击 .command 时 PATH 可能不完整，不能只靠 command -v brew。
    if brew_bin="$(find_brew_bin)"; then
        setup_brew_shellenv "${brew_bin}" || return 1
        info_echo "已检测到 Homebrew：${brew_bin}，执行更新与升级流程"
        run_cmd "brew update（更新软件列表）" brew update
        run_cmd "brew upgrade（升级已安装软件）" brew upgrade
        run_cmd "brew cleanup（清理旧版本缓存）" brew cleanup
        run_cmd "brew doctor（检查 Homebrew 健康状态）" brew doctor
        run_cmd "brew -v（输出 Homebrew 版本）" brew -v
        return 0
    fi

    warn_echo "未检测到 Homebrew，开始安装（芯片架构：${arch}）"

    jobs_brew_install_or_exit
    brew_bin="$JOBS_HOMEBREW_BIN"
    setup_brew_shellenv "${brew_bin}" || return 1

    if require_command brew; then
        success_echo "Homebrew 安装成功"
        run_cmd "brew update（更新软件列表）" brew update
        run_cmd "brew upgrade（升级已安装软件）" brew upgrade
        run_cmd "brew cleanup（清理旧版本缓存）" brew cleanup
        run_cmd "brew doctor（检查 Homebrew 健康状态）" brew doctor
        run_cmd "brew -v（输出 Homebrew 版本）" brew -v
    else
        error_echo "Homebrew 安装后仍未检测到 brew 命令，后续流程将受到影响"
        return 1
    fi
}
# 封装 stage homebrew 对应的独立处理逻辑。
stage_homebrew() {
    progress_step "Homebrew"
    install_or_upgrade_homebrew || exit 1
}
# =========================
# 阶段 5：brew 安装开发工具
# =========================
brew_formula_installed() {
    local pkg="$1"
    local short_name="${pkg:t}"

    brew list --formula --versions "${pkg}" >/dev/null 2>&1 && return 0
    brew list --formula --versions "${short_name}" >/dev/null 2>&1 && return 0

    return 1
}
# 封装 brew cask installed 对应的独立处理逻辑。
brew_cask_installed() {
    local pkg="$1"
    brew list --cask --versions "${pkg}" >/dev/null 2>&1
}
# 封装 brew install if needed 对应的独立处理逻辑。
brew_install_if_needed() {
    local pkg="$1"

    if brew_formula_installed "${pkg}"; then
        info_echo "brew formula 已安装：${pkg}"
    else
        if ! run_cmd "安装 brew formula：${pkg}" brew install "${pkg}"; then
            error_echo "brew formula 安装失败：${pkg}"
            return 1
        fi
    fi
}
# 封装 brew install cask if needed 对应的独立处理逻辑。
brew_install_cask_if_needed() {
    local pkg="$1"

    if brew_cask_installed "${pkg}"; then
        info_echo "brew cask 已安装：${pkg}"
    else
        if ! run_cmd "安装 brew cask：${pkg}" brew install --cask "${pkg}"; then
            error_echo "brew cask 安装失败：${pkg}"
            return 1
        fi
    fi
}
# 封装 stage brew packages 对应的独立处理逻辑。
stage_brew_packages() {
    progress_step "brew 安装开发工具"

    if ! require_command brew; then
        error_echo "brew 不存在，无法继续安装开发工具"
        return 1
    fi

    info_echo "开始安装 brew formula..."
    local pkg
    for pkg in "${BREW_FORMULAE[@]}"; do
        brew_install_if_needed "${pkg}" || return 1
    done

    # Git LFS 初始化
    if require_command git && git lfs version >/dev/null 2>&1; then
        info_echo "初始化 Git LFS..."
        git lfs install || {
            error_echo "Git LFS 初始化失败"
            return 1
        }

        info_echo "配置 Git 大文件传输参数..."
        git config --global core.compression 0 || {
            error_echo "git config core.compression 失败"
            return 1
        }

        git config --global http.postBuffer 524288000 || {
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

    run_cmd "brew cleanup（清理旧版本与缓存）" brew cleanup
}
# =========================
# 阶段 6：npm
# =========================
stage_npm() {
    progress_step "npm"

    if ! require_command npm; then
        error_echo "npm 不存在，跳过 quicktype 安装"
        return 1
    fi

    run_cmd "全局安装 quicktype" sudo npm install -g quicktype
}
# =========================
# 阶段 7：gem
# =========================
stage_gem() {
    progress_step "gem"

    if ! require_command gem; then
        error_echo "gem 不存在，跳过 cocoapods 安装"
        return 1
    fi

    run_cmd "安装 cocoapods" sudo gem install cocoapods
}
# =========================
# 阶段 8：Jobs
# 下载仓库并执行 install.command
# =========================
clone_or_pull_repo() {
    local repo_url="$1"
    local target_dir="$2"

    if [[ -d "${target_dir}/.git" ]]; then
        info_echo "仓库已存在，执行 git pull：${target_dir}"
        run_sh "更新仓库 ${target_dir}" "cd '${target_dir}' && git pull --ff-only"
    else
        run_sh "克隆仓库到 ${target_dir}" "git clone '${repo_url}' '${target_dir}'"
    fi
}
# 封装 stage jobs 对应的独立处理逻辑。
stage_jobs() {
    progress_step "Jobs"

    ensure_github_access_or_exit

    local base_dir="${HOME}/Desktop/JobsKits"
    local software_dir="${base_dir}/JobsSoftware.MacOS"
    local env_dir="${base_dir}/JobsMacEnvVarConfig"

    run_sh "创建 JobsKits 工作目录" "mkdir -p '${base_dir}'"

    clone_or_pull_repo "${JOBS_SOFTWARE_REPO}" "${software_dir}"
    clone_or_pull_repo "${JOBS_ENV_REPO}" "${env_dir}"

    local install_script="${env_dir}/install.command"
    if [[ -f "${install_script}" ]]; then
        run_cmd "为 install.command 添加可执行权限" chmod +x "${install_script}"
        run_cmd "执行 JobsMacEnvVarConfig/install.command" "${install_script}"
    else
        error_echo "未找到 ${install_script}"
    fi
}
# =========================
# 手动下载环节
# =========================
open_manual_download_pages() {
    echo ""
    highlight_echo "接下来会为你打开需要手动下载安装的页面："
    gray_echo "• Visual Studio Code"
    gray_echo "• Android Studio"
    gray_echo "• Python Downloads"

    run_cmd "打开 VS Code 下载页" open "https://code.visualstudio.com/"
    run_cmd "打开 Android Studio 下载页" open "https://developer.android.com/studio?hl=zh-cn"
    run_cmd "打开 Python 下载页" open "https://www.python.org/downloads/"
}
# =========================
# 收尾
# =========================
finish_summary() {
    echo ""
    print_divider
    success_echo "macOS 新系统配置流程执行结束"
    info_echo "日志文件位置：${LOG_FILE}"
    warm_echo "请你手动检查终端日志，确认失败项并按需补装。"
    warm_echo "尤其留意：CLT / Xcode / oh-my-zsh / Homebrew / GitHub 网络相关步骤。"
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
  : > "${LOG_FILE}"
}
# 编排脚本的高层业务流程。
# 初始化脚本运行环境，并集中承载原有的顶层执行逻辑。
initialize_script_runtime() {
  set -u
}
# 编排脚本的高层业务流程。
main() {
  # 显示内置自述并阻塞，等待用户确认后继续。
  show_readme_and_block
  # 初始化 Shell 选项、日志、依赖和入口运行状态。
  initialize_script_runtime
  # 清空旧日志，确保本次记录独立可查。
  initialize_execution_log
  # 安装 Command Line Tools 并接受 Xcode 协议。
  stage_clt
  # 清理 Xcode 与模拟器缓存并下载 iOS 平台组件。
  stage_xcode_simulator_assets
  # 安装 oh-my-zsh。
  stage_oh_my_zsh
  # 安装或升级 Homebrew，并完成基础环境配置。
  stage_homebrew
  # 通过 Homebrew 安装常用开发工具与图形应用。
  stage_brew_packages
  # 通过 npm 安装全局工具 quicktype。
  stage_npm
  # 通过 gem 安装 CocoaPods。
  stage_gem
  # 下载 Jobs 相关仓库并执行环境配置脚本。
  stage_jobs
  # 打开需要用户手动下载安装的软件官网。
  open_manual_download_pages
  # 输出执行结果与日志路径摘要。
  finish_summary
  # 等待用户确认全部流程完成后退出。
  pause_for_enter "👉 全部流程已执行完成。请按回车退出..."
}

main "$@"

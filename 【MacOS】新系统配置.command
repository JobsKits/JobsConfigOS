#!/bin/zsh

# ==============================================================================
# macOS 新系统初始化脚本
# 说明：
# 1. 适合 .command 双击运行，也可终端执行
# 2. 每个安装阶段会在终端打印当前进度
# 3. 关键外网步骤会先检查网络（尤其 GitHub）
# 4. 最终从 main "$@" 统一收口
# ==============================================================================

set -u

# =========================
# 日志与彩色输出
# =========================
SCRIPT_BASENAME=$(basename "$0" | sed 's/\.[^.]*$//')   # 当前脚本名（去掉扩展名）
LOG_FILE="/tmp/${SCRIPT_BASENAME}.log"                  # 设置对应的日志文件路径

log()            { echo -e "$1" | tee -a "$LOG_FILE"; }
color_echo()     { log "\033[1;32m$1\033[0m"; }         # ✅ 正常绿色输出
info_echo()      { log "\033[1;34mℹ $1\033[0m"; }       # ℹ 信息
success_echo()   { log "\033[1;32m✔ $1\033[0m"; }       # ✔ 成功
warn_echo()      { log "\033[1;33m⚠ $1\033[0m"; }       # ⚠ 警告
warm_echo()      { log "\033[1;33m$1\033[0m"; }         # 🟡 温馨提示（无图标）
note_echo()      { log "\033[1;35m➤ $1\033[0m"; }       # ➤ 说明
error_echo()     { log "\033[1;31m✖ $1\033[0m"; }       # ✖ 错误
err_echo()       { log "\033[1;31m$1\033[0m"; }         # 🔴 错误纯文本
debug_echo()     { log "\033[1;35m🐞 $1\033[0m"; }      # 🐞 调试
highlight_echo() { log "\033[1;36m🔹 $1\033[0m"; }      # 🔹 高亮
gray_echo()      { log "\033[0;90m$1\033[0m"; }         # ⚫ 次要信息
bold_echo()      { log "\033[1m$1\033[0m"; }            # 📝 加粗
underline_echo() { log "\033[4m$1\033[0m"; }            # 🔗 下划线

# =========================
# 全局配置
# =========================
readonly TOTAL_STAGES=8
CURRENT_STAGE=0

readonly JOBS_SOFTWARE_REPO="https://github.com/JobsKits/JobsSoftware.MacOS.git"
readonly JOBS_ENV_REPO="https://github.com/JobsKits/JobsMacEnvVarConfig.git"

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

    echo ""
    bold_echo "========================= macOS 新系统配置脚本说明 ========================="
    echo ""

    info_echo "用途：自动执行一套新 Mac 常用开发环境初始化流程。"
    info_echo "执行方式：支持双击 .command 运行，也支持终端手动执行。"
    echo ""

    highlight_echo "本脚本将尝试执行以下阶段："
    gray_echo "1. 【Command Line Tools（CLT）】"
    gray_echo "2. 【Xcode模拟器配件】"
    gray_echo "3. 【ohmyzsh】"
    gray_echo "4. 【Homebrew】"
    gray_echo "5. 【brew 安装开发工具】"
    gray_echo "6. 【npm】"
    gray_echo "7. 【gem】"
    gray_echo "8. 【Jobs】"
    echo ""

    warn_echo "注意事项："
    gray_echo "• 脚本中包含 sudo 命令，执行时可能要求输入系统密码"
    gray_echo "• 部分步骤依赖 GitHub / raw.githubusercontent.com，网络不通会失败"
    gray_echo "• xcode-select --install 可能弹出系统图形安装窗口"
    gray_echo "• oh-my-zsh 官方脚本可能有交互行为，属于正常现象"
    gray_echo "• 某些图形应用会使用 brew cask 安装，耗时取决于网络与机器性能"
    gray_echo "• 手动软件下载链接会在最后自动打开浏览器"
    echo ""

    warm_echo "日志文件：${LOG_FILE}"
    echo ""

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
    local brew_bin="$1"
    local target_file="${HOME}/.zprofile"
    local shellenv_line="eval \"\$(${brew_bin} shellenv)\""

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

install_or_upgrade_homebrew() {
    local arch
    arch="$(get_cpu_arch)"

    ensure_brew_access_or_exit
    ensure_rosetta_if_needed

    if require_command brew; then
        info_echo "已检测到 Homebrew，执行更新与升级流程"
        run_cmd "brew update（更新软件列表）" brew update
        run_cmd "brew upgrade（升级已安装软件）" brew upgrade
        run_cmd "brew cleanup（清理旧版本缓存）" brew cleanup
        return 0
    fi

    warn_echo "未检测到 Homebrew，开始安装（芯片架构：${arch}）"

    if [[ "${arch}" == "arm64" ]]; then
        run_sh \
            "安装 Homebrew（Apple Silicon）" \
            '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
        setup_brew_shellenv "/opt/homebrew/bin/brew"
    else
        run_sh \
            "安装 Homebrew（Intel）" \
            '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
        setup_brew_shellenv "/usr/local/bin/brew"
    fi

    if require_command brew; then
        success_echo "Homebrew 安装成功"
        run_cmd "brew update（更新软件列表）" brew update
        run_cmd "brew upgrade（升级已安装软件）" brew upgrade
    else
        error_echo "Homebrew 安装后仍未检测到 brew 命令，后续流程将受到影响"
        return 1
    fi
}

stage_homebrew() {
    progress_step "Homebrew"
    install_or_upgrade_homebrew
}

# =========================
# 阶段 5：brew 安装开发工具
# =========================
brew_install_if_needed() {
    local pkg="$1"

    if brew list --formula | grep -Fxq "${pkg}"; then
        info_echo "brew formula 已安装：${pkg}"
    else
        if ! run_cmd "安装 brew formula：${pkg}" brew install "${pkg}"; then
            error_echo "brew formula 安装失败：${pkg}"
            return 1
        fi
    fi
}

brew_install_cask_if_needed() {
    local pkg="$1"

    if brew list --cask | grep -Fxq "${pkg}"; then
        info_echo "brew cask 已安装：${pkg}"
    else
        run_cmd "安装 brew cask：${pkg}" brew install --cask "${pkg}"
    fi
}

stage_brew_packages() {
    progress_step "brew 安装开发工具"

    if ! require_command brew; then
        error_echo "brew 不存在，无法继续安装开发工具"
        return 1
    fi

    info_echo "开始安装 brew formula..."
    local formulae=(
        git-lfs
        gh
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
    )

    local pkg
    for pkg in "${formulae[@]}"; do
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
    local casks=(
        hammerspoon
        flutter
    )

    for pkg in "${casks[@]}"; do
        brew_install_cask_if_needed "${pkg}"
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
main() {
    : > "${LOG_FILE}"

    show_readme_and_block              # 显示自述说明并阻塞，等待用户确认后继续

    stage_clt                          # 阶段 1：安装 Command Line Tools 并接受 Xcode 协议
    stage_xcode_simulator_assets       # 阶段 2：清理 Xcode/模拟器缓存并下载 iOS 平台组件
    stage_oh_my_zsh                    # 阶段 3：安装 oh-my-zsh
    stage_homebrew                     # 阶段 4：安装或升级 Homebrew，并完成基础环境配置
    stage_brew_packages                # 阶段 5：通过 Homebrew 安装常用开发工具与图形应用
    stage_npm                          # 阶段 6：通过 npm 安装全局工具 quicktype
    stage_gem                          # 阶段 7：通过 gem 安装 cocoapods
    stage_jobs                         # 阶段 8：下载 Jobs 相关仓库并执行环境配置脚本

    open_manual_download_pages         # 打开需要用户手动下载安装的软件官网
    finish_summary                     # 输出执行结果与日志路径摘要

    pause_for_enter "👉 全部流程已执行完成。请按回车退出..."
}

main "$@"

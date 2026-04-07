#!/usr/bin/env zsh
set -euo pipefail

# ============================== 全局配置 ==============================
SUBMODULE_BRANCH="${SUBMODULE_BRANCH:-main}"     # 统一子模块分支👉Github默认建仓分支名：main
REMOTE_NAME="${REMOTE_NAME:-origin}"             # 父仓远端名
DRY_RUN="${DRY_RUN:-0}"                          # 1=干跑，只打印动作不执行
ONLY_PATHS="${ONLY_PATHS:-}"                     # 仅更新这些子模块路径（空格分隔）；空=全部
FORCE_DELETE="${FORCE_DELETE:-0}"                # 1=直接删除冲突目录；0=移动到备份目录

SCRIPT_BASENAME=$(basename "$0" | sed 's/\.[^.]*$//')
LOG_FILE="/tmp/${SCRIPT_BASENAME}.log"

# 你图里这些目录（将先处理冲突）
CONFLICT_PATHS=(
    "JobsConfigHotKeyByHammerspoon"
    "JobsMacEnvVarConfig"
    "SourceTree.sh"
    "JobsCodeSnippets"
    "JobsSoftware.MacOS"
)

# ============================== 输出 & 工具 ==============================
log()          { echo -e "$1" | tee -a "$LOG_FILE"; }
info_echo()    { log "ℹ️  $*"; }
success_echo() { log "✅ $*"; }
warn_echo()    { log "⚠️  $*"; }
error_echo()   { log "❌ $*" >&2; }
note_echo()    { log "📝 $*"; }

_do_or_echo() {
  if [[ "$DRY_RUN" == "1" ]]; then
    note_echo "[DRY-RUN] $*"
  else
    eval "$@"
  fi
}

get_ncpu() { command -v sysctl >/dev/null 2>&1 && sysctl -n hw.ncpu || echo 1; }

cd_to_script_dir() {
  local script_path
  script_path="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")" && pwd)"
  cd "$script_path"
}

show_intro_and_wait() {
  cat <<EOF
📘 Git 子模块批量管理脚本（统一分支：$SUBMODULE_BRANCH）
------------------------------------------------------------
远端: $REMOTE_NAME
干跑: $DRY_RUN
仅更新路径: ${ONLY_PATHS:-全部子模块}
删除策略: $( [[ "$FORCE_DELETE" == "1" ]] && echo "直接删除" || echo "先备份再移除" )

将优先清理这些冲突目录：
  ${CONFLICT_PATHS[*]}

流程：
  1) 切换到脚本所在目录
  2) 确认父仓初始化 & 远端
  3) **先清理同名目录（备份或删除 + 从索引移除 + 清理旧子模块痕迹）**
  4) 添加预设子模块（分支：$SUBMODULE_BRANCH）
  5) 初始化 & 同步子模块
  6) 将每个子模块强制对齐到远端最新（fetch → checkout/track → reset --hard）
  7) 如有 gitlink 变化则提交到父仓
  8) 父仓切到 $SUBMODULE_BRANCH 并与远端 rebase 同步
  9) 推送父仓到远端

⚠️ 干跑模式不会执行 reset/commit/push 等修改，仅打印动作。
------------------------------------------------------------
按 [回车] 继续，或 Ctrl+C 取消。
EOF
  read -r
}

# ============================== 父仓操作 ==============================
ensure_repo_initialized() {
  _do_or_echo "git init"
  _do_or_echo "git add . || true"
  _do_or_echo "git status >/dev/null"
}

ensure_git_remote() {
  local remote_name="${1:-$REMOTE_NAME}"
  if git remote get-url "$remote_name" >/dev/null 2>&1; then
    info_echo "已存在远端 [$remote_name] -> $(git remote get-url "$remote_name")"
    return
  fi
  local remote_url=""
  while true; do
    read "?请输入 Git 远端地址（用于 $remote_name）: " remote_url
    [[ -z "$remote_url" ]] && { warn_echo "输入为空"; continue; }
    if git ls-remote "$remote_url" >/dev/null 2>&1; then
      _do_or_echo "git remote add \"$remote_name\" \"$remote_url\""
      success_echo "已添加远端：$remote_name -> $remote_url"
      break
    else
      error_echo "无法访问：$remote_url"
    fi
  done
}

ensure_parent_branch() {
  local b="$SUBMODULE_BRANCH"
  if ! git rev-parse --verify "$b" >/dev/null 2>&1; then
    if git ls-remote --exit-code --heads "$REMOTE_NAME" "$b" >/dev/null 2>&1; then
      _do_or_echo "git checkout -B \"$b\" --track \"$REMOTE_NAME/$b\""
    else
      _do_or_echo "git checkout -B \"$b\""
    fi
  else
    _do_or_echo "git checkout \"$b\""
  fi
}

parent_pull_rebase() {
  local b; b="$(git rev-parse --abbrev-ref HEAD)"
  _do_or_echo "git fetch \"$REMOTE_NAME\" || true"
  if git ls-remote --exit-code --heads "$REMOTE_NAME" "$b" >/dev/null 2>&1; then
    _do_or_echo "git pull --rebase \"$REMOTE_NAME\" \"$b\" || git pull --no-rebase \"$REMOTE_NAME\" \"$b\" || true"
  fi
}

parent_push() {
  local b; b="$(git rev-parse --abbrev-ref HEAD)"
  _do_or_echo "git push -u \"$REMOTE_NAME\" \"$b\""
}

# ============================== 冲突目录清理 ==============================
# 目标：把同名的普通目录/旧子模块清理掉（索引、.git/modules、.gitmodules），避免 submodule add 报错
pre_clean_conflicting_dirs() {
  local backup_root=".backup-conflicts/$(date +%Y%m%d-%H%M%S)"
  [[ "$FORCE_DELETE" == "1" ]] || _do_or_echo "mkdir -p \"$backup_root\""

  for p in "${CONFLICT_PATHS[@]}"; do
    # 若已被索引追踪（无论文件/目录），先从索引移除
    if git ls-files --error-unmatch -- "$p" >/dev/null 2>&1; then
      _do_or_echo "git rm -rf --cached \"$p\" || true"
      note_echo "已从索引移除：$p"
    fi

    # 清理旧的子模块仓库目录
    if [[ -d ".git/modules/$p" ]]; then
      _do_or_echo "rm -rf \".git/modules/$p\""
      note_echo "已清理 .git/modules/$p"
    fi

    # 物理目录处理：备份或删除
    if [[ -e "$p" ]]; then
      if [[ "$FORCE_DELETE" == "1" ]]; then
        _do_or_echo "rm -rf \"$p\""
        warn_echo "已删除：$p"
      else
        _do_or_echo "mkdir -p \"$(dirname "$backup_root/$p")\""
        _do_or_echo "mv \"$p\" \"$backup_root/$p\""
        warn_echo "已备份并移除：$p  →  $backup_root/$p"
      fi
    fi

    # 删除 .gitmodules 里与该路径相关的段（若存在）
    if [[ -f ".gitmodules" ]] && git config -f .gitmodules --get-regexp "^submodule\..*\.path$" >/dev/null 2>&1; then
      local name
      name="$(git config -f .gitmodules --name-only --get-regexp "^submodule\..*\.path$" | while read -r k; do
        v="$(git config -f .gitmodules --get "$k")"
        [[ "$v" == "$p" ]] && echo "$k"
      done | sed -E 's/^submodule\.([^.]*)\.path.*/\1/' || true)"
      if [[ -n "$name" ]]; then
        _do_or_echo "git config -f .gitmodules --remove-section \"submodule.$name\" || true"
        note_echo "已从 .gitmodules 移除段：submodule.$name"
      fi
    fi
  done

  # 规范化 .gitmodules（可能为空或被改动）
  if [[ -f ".gitmodules" ]]; then
    _do_or_echo "git add .gitmodules || true"
    _do_or_echo "git commit -m 'chore: cleanup conflicting paths before adding submodules' || true"
  fi
}

# ============================== 子模块操作 ==============================
add_submodules() {
  local b="$SUBMODULE_BRANCH"
  info_echo "添加子模块（分支：$b）"
  _do_or_echo 'git submodule add -b "'"$b"'" https://github.com/JobsKits/JobsConfigHotKeyByHammerspoon.git ./JobsConfigHotKeyByHammerspoon'
  _do_or_echo 'git submodule add -b "'"$b"'" https://github.com/JobsKits/JobsMacEnvVarConfig.git ./JobsMacEnvVarConfig'
  _do_or_echo 'git submodule add -b "'"$b"'" https://github.com/JobsKits/SourceTree.sh.git ./SourceTree.sh'
  _do_or_echo 'git submodule add -b "'"$b"'" https://github.com/JobsKits/JobsCodeSnippets.git ./JobsCodeSnippets'
  _do_or_echo 'git submodule add -b "'"$b"'" https://github.com/JobsKits/JobsSoftware.MacOS.git ./JobsSoftware.MacOS'
}

sync_and_init_submodules() {
  _do_or_echo "git submodule sync"
  _do_or_echo "git submodule update --init --recursive --jobs=\"\$(get_ncpu)\""
}

__selected() {
  local p="$1"
  [[ -z "$ONLY_PATHS" ]] && return 0
  for x in ${(z)ONLY_PATHS}; do [[ "$x" == "$p" ]] && return 0; done
  return 1
}

record_and_normalize_submodules() {
  local b="$SUBMODULE_BRANCH"
  info_echo "对子模块强制对齐远端最新（分支：$b，DRY_RUN=$DRY_RUN）"

  local paths=()
  if [[ -f .gitmodules ]]; then
    while IFS= read -r p; do [[ -n "$p" ]] && paths+=("$p"); done < <(git config -f .gitmodules --get-regexp '^submodule\..*\.path$' 2>/dev/null | awk '{print $2}')
  fi

  for sp in "${paths[@]:-}"; do
    __selected "$sp" || { note_echo "跳过未选路径：$sp"; continue; }
    note_echo ">>> 处理子模块：$sp"
    if [[ "$DRY_RUN" == "1" ]]; then
      note_echo "[DRY-RUN] git -C \"$sp\" fetch --all --tags --prune"
      note_echo "[DRY-RUN] git -C \"$sp\" checkout -B \"$b\" --track origin/\"$b\" || true"
      note_echo "[DRY-RUN] git -C \"$sp\" reset --hard origin/\"$b\""
      continue
    fi
    (
      set -e
      cd "$sp"
      git fetch --all --tags --prune
      if git ls-remote --exit-code --heads origin "$b" >/dev/null 2>&1; then
        git checkout -B "$b" --track "origin/$b" || git checkout "$b" || true
        git reset --hard "origin/$b"
      else
        local def; def="$(git remote show origin | awk '/HEAD branch/ {print $NF}')"
        if [[ -n "$def" ]] && git ls-remote --exit-code --heads origin "$def" >/dev/null 2>&1; then
          git checkout -B "$def" --track "origin/$def" || git checkout "$def" || true
          git reset --hard "origin/$def"
        else
          warn_echo "远端无 $b 且无法确定默认分支：$sp"
        fi
      fi
      success_echo "$sp → $(git rev-parse --short HEAD)"
    )
  done

  if [[ "$DRY_RUN" == "0" && ${#paths[@]} -gt 0 ]]; then
    local add_list=()
    for sp in "${paths[@]}"; do __selected "$sp" && add_list+=("$sp"); done
    if [[ ${#add_list[@]} -gt 0 ]]; then
      _do_or_echo "git add ${add_list[*]}"
      if ! git diff --cached --quiet -- "${add_list[@]}"; then
        _do_or_echo "git commit -m \"chore: bump submodules to latest ($b)\""
        success_echo "父仓已固化最新 gitlink"
      else
        info_echo "gitlink 无变化，跳过提交"
      fi
    fi
  fi
}

# ============================== main ==============================
main() {
  # ---- 自述与确认 ----
  show_intro_and_wait

  # ---- 1) 切换到脚本目录（确保相对路径正确）----
  cd_to_script_dir

  # ---- 2) 初始化父仓（幂等）----
  ensure_repo_initialized

  # ---- 3) 确认/配置远端（origin），后续 pull/push 依赖它 ----
  ensure_git_remote "$REMOTE_NAME"

  # ---- 4) 先清理目标子模块同名目录（现在是这 5 个）以避免 submodule add 报错 ----
  pre_clean_conflicting_dirs

  # ---- 5) 添加预设子模块（统一分支 SUBMODULE_BRANCH）----
  add_submodules

  # ---- 6) 初始化 & 同步子模块 ----
  sync_and_init_submodules

  # ---- 7) 强制将每个子模块对齐到远端最新，并在父仓固化 gitlink ----
  record_and_normalize_submodules

  # ---- 8) 确保父仓切到 SUBMODULE_BRANCH（默认 main）----
  ensure_parent_branch

  # ---- 9) 先与远端 rebase 同步，避免 push 冲突 ----
  parent_pull_rebase

  # ---- 10) 推送父仓到远端 ----
  parent_push

  success_echo "全部完成 ✅（分支：$SUBMODULE_BRANCH，干跑：$DRY_RUN，删除策略：$([[ "$FORCE_DELETE" == "1" ]] && echo 删除 || echo 备份)）"
  note_echo    "日志文件：$LOG_FILE"
}

main "$@"

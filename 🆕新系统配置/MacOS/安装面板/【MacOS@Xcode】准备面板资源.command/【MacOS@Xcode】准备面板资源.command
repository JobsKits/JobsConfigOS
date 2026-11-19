#!/bin/zsh
# 脚本自述：Xcode 原生 App target 的资源阶段，只准备本次构建目录的资源。
# 依赖：Xcode 构建环境和当前仓库的源资源；不执行环境安装、卸载或编译。
# 影响：替换 TARGET_BUILD_DIR 内本工具的受管资源；保留仓库旁已有发行 App。
# shell: zsh

ENTRY_FILE="${0:A}"
PANEL_ROOT=""
PROJECT_ROOT=""
PROFILE=system
APP_NAME='【MacOS】🧰新系统配置管理.app'
BUNDLE_ID='com.jobs.systemsetup.managementpanel'
STAGE_DIR=""
LOG_FILE=""
RESOURCE_ROOT=""
# 显示构建职责，并拒绝脱离 Xcode 构建环境的误执行。
show_intro_and_check_context() {
    print -r -- 'Xcode 资源阶段：从本仓源码准备 App 包内后端、翻译、图标和构建收据。'
    print -r -- '只写本次 TARGET_BUILD_DIR；不执行系统环境安装、卸载或发布现有 App。'
    [[ -n "${XCODE_VERSION_ACTUAL:-}" && -n "${TARGET_BUILD_DIR:-}" && -n "${TARGET_TEMP_DIR:-}" &&
       "${PRODUCT_BUNDLE_IDENTIFIER:-}" == "$BUNDLE_ID" &&
       "${FULL_PRODUCT_NAME:-}" == "$APP_NAME" &&
       "${UNLOCALIZED_RESOURCES_FOLDER_PATH:-}" == "$APP_NAME/Contents/Resources" ]] || {
        print -u2 -r -- '此内部入口仅供对应 Xcode App target 的资源阶段使用。'
        return 2
    }
}
# 按脚本位置解析源目录，所有临时文件限定于 Xcode 的目标临时目录。
initialize_resources() {
    setopt NO_NOMATCH PIPE_FAIL
    umask 077
    PANEL_ROOT="${ENTRY_FILE:h:h}"
    PROJECT_ROOT="${PANEL_ROOT:h:h:h}"
    [[ -d "$TARGET_BUILD_DIR" && -d "$TARGET_TEMP_DIR" && ! -L "$TARGET_TEMP_DIR" ]] || return 2
    RESOURCE_ROOT="$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH"
    [[ ! -L "$RESOURCE_ROOT" && ! -L "${RESOURCE_ROOT:h}" ]] || return 2
    STAGE_DIR="$(/usr/bin/mktemp -d "$TARGET_TEMP_DIR/JobsPanelResources.XXXXXXXX")" || return 1
    LOG_FILE="$STAGE_DIR/resources.log"
    : > "$LOG_FILE" || return 1
    trap 'exit 130' INT
    trap 'exit 143' TERM HUP
}
# 仅清理本轮创建的精确临时目录。
cleanup_resources() {
    local result=$?
    trap - EXIT
    if [[ -n "$STAGE_DIR" && -d "$STAGE_DIR" && ! -L "$STAGE_DIR" &&
          "${STAGE_DIR:h}" == "$TARGET_TEMP_DIR" && "${STAGE_DIR:t}" == JobsPanelResources.* ]]; then
        /bin/rm -r -- "$STAGE_DIR" || { (( result != 0 )) || result=1; }
    fi
    return "$result"
}
# 同步构建日志并保留外部命令的退出结果。
log_message() {
    print -r -- "$1" | /usr/bin/tee -a "$LOG_FILE"
}
# 管道同时核对原命令和日志写入，避免 tee 掩盖失败。
run_logged() {
    "$@" 2>&1 | /usr/bin/tee -a "$LOG_FILE"
    local codes=("${pipestatus[@]}")
    (( codes[1] == 0 && codes[2] == 0 ))
}
# 完整复制受管源目录，排除 Git、依赖、测试和已有 App 产物。
copy_tree() {
    local source_dir="$1" target_dir="$2"
    [[ -d "$source_dir" && ! -L "$source_dir" ]] || { log_message "错误：配套目录缺失或为链接：$source_dir"; return 1; }
    /bin/mkdir -p "$target_dir" || return 1
    /usr/bin/tar -C "$source_dir" --exclude .git --exclude .DS_Store --exclude node_modules \
        --exclude work --exclude build --exclude DerivedData --exclude Tests --exclude tests --exclude '*.app' -cf - . |
        /usr/bin/tar -C "$target_dir" -xf -
    local codes=("${pipestatus[@]}")
    (( codes[1] == 0 && codes[2] == 0 ))
}
# 按既有布局准备 Jobs 环境后端及其必需源资源。
copy_environment_payload() {
    local source_root="$1" target_root="$2" item=""
    for item in scripts zsh Sys 【MacOS】环境管理后端.command; do
        copy_tree "$source_root/$item" "$target_root/$item" || return 1
    done
    /bin/cp -p "$source_root/sync_env.txt" "$target_root/sync_env.txt" || return 1
}
# 复用命令行构建器的包布局，临时 Info 不覆盖 Xcode 生成的 Info。
stage_resources() {
    local application="$1" package_root="" backend_relative=""
    package_root="$application/Contents/Resources/package"
    /bin/mkdir -p "$application/Contents/MacOS" "$application/Contents/Resources" "$package_root" || return 1
    /bin/cp -p "$PANEL_ROOT/Resources/PanelTranslations.json" "$application/Contents/Resources/PanelTranslations.json" || return 1
    if [[ "$PROFILE" == system ]]; then
        copy_tree "$PROJECT_ROOT/🆕新系统配置/MacOS/【MacOS】🆕新系统配置.command" "$package_root/【MacOS】🆕新系统配置/MacOS/【MacOS】🆕新系统配置.command" || return 1
        copy_environment_payload "$PROJECT_ROOT/🌍JobsMacEnvVarConfigs" "$package_root/🌍JobsMacEnvVarConfigs" || return 1
        backend_relative='package/【MacOS】🆕新系统配置/MacOS/【MacOS】🆕新系统配置.command/【MacOS】环境管理后端.command/【MacOS】环境管理后端.command'
    else
        copy_environment_payload "$PROJECT_ROOT" "$package_root" || return 1
        backend_relative='package/【MacOS】环境管理后端.command/【MacOS】环境管理后端.command'
    fi
    /bin/cat > "$application/Contents/Resources/PanelConfiguration.json" <<PROFILE_JSON
{"kind":"$PROFILE","backend":"$backend_relative","preferenceDomain":"$BUNDLE_ID.preferences"}
PROFILE_JSON
    /bin/cat > "$application/Contents/Info.plist" <<APP_PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
<key>CFBundleName</key><string>JobsEnvironmentManager</string>
<key>CFBundleDisplayName</key><string>${APP_NAME%.app}</string>
<key>CFBundleExecutable</key><string>JobsEnvironmentManager</string>
<key>CFBundleIconFile</key><string>JobsEnvironmentManager.icns</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
APP_PLIST
    /usr/bin/plutil -lint "$application/Contents/Info.plist" || return 1
}
# 从仓库已有图标生成原生 ICNS，不下载任何视觉素材。
build_icon() {
    local application="$1" size="" scale="" pixels="" iconset="$STAGE_DIR/JobsEnvironmentManager.iconset"
    /bin/mkdir -p "$iconset" || return 1
    for size in 16 32 128 256 512; do
        for scale in 1 2; do
            pixels=$(( size * scale ))
            local suffix=""
            (( scale == 1 )) || suffix='@2x'
            /usr/bin/sips -z "$pixels" "$pixels" "$PROJECT_ROOT/icon.png" --out "$iconset/icon_${size}x${size}${suffix}.png" >/dev/null || return 1
        done
    done
    run_logged /usr/bin/iconutil -c icns "$iconset" -o "$application/Contents/Resources/JobsEnvironmentManager.icns"
}
# 用当前源码与完整资源写构建收据和可核对的哈希清单。
write_build_receipt() {
    local application="$1" resource_root="$1/Contents/Resources"
    local source_digest="" built_at="" item="" file_count=0
    source_digest="$(/usr/bin/shasum -a 256 "$PANEL_ROOT/Sources/EnvironmentManager.swift")" || return 1
    source_digest="${source_digest%% *}"
    built_at="$(/bin/date -u '+%Y-%m-%dT%H:%M:%SZ')" || return 1
    /bin/cat > "$resource_root/BuildReceipt.plist" <<BUILD_RECEIPT
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>profile</key><string>$PROFILE</string>
<key>builtAtUTC</key><string>$built_at</string>
<key>sourceSHA256</key><string>$source_digest</string>
</dict></plist>
BUILD_RECEIPT
    /usr/bin/plutil -lint "$resource_root/BuildReceipt.plist" >> "$LOG_FILE" 2>&1 || return 1
    (
        cd "$resource_root" || exit 1
        local resource_files=(**/*(.DN))
        (( ${#resource_files} > 0 )) || exit 1
        for item in "${resource_files[@]}"; do
            [[ "$item" != Payload.sha256 ]] || continue
            [[ "$item" != *$'\n'* && "$item" != *$'\r'* ]] || exit 1
            /usr/bin/shasum -a 256 "./$item" || exit 1
        done
    ) > "$resource_root/Payload.sha256" || return 1
    (
        cd "$resource_root" || exit 1
        /usr/bin/shasum -a 256 -c Payload.sha256
    ) >> "$LOG_FILE" 2>&1 || return 1
    file_count="$(/usr/bin/wc -l < "$resource_root/Payload.sha256")" || return 1
    log_message "资源清单已验证：${file_count//[[:space:]]/} 份；源码 SHA-256：$source_digest"
}
# 先在独立临时 App 中准备完整资源，完成后才写入本次构建产物。
prepare_current_resources() {
    local application="$STAGE_DIR/$APP_NAME"
    stage_resources "$application" && build_icon "$application" && write_build_receipt "$application" || return 1
    /bin/mkdir -p "$RESOURCE_ROOT" || return 1
    local item=""
    for item in package PanelTranslations.json PanelConfiguration.json JobsEnvironmentManager.icns BuildReceipt.plist Payload.sha256; do
        [[ ! -L "$RESOURCE_ROOT/$item" ]] || { log_message "拒绝替换链接资源：$item"; return 2; }
        if [[ -e "$RESOURCE_ROOT/$item" ]]; then
            /bin/mkdir -p "$STAGE_DIR/previous" || return 1
            /bin/mv "$RESOURCE_ROOT/$item" "$STAGE_DIR/previous/$item" || return 1
        fi
        /bin/mv "$application/Contents/Resources/$item" "$RESOURCE_ROOT/$item" || return 1
    done
    (cd "$RESOURCE_ROOT" && /usr/bin/shasum -a 256 -c Payload.sha256) >> "$LOG_FILE" 2>&1 || return 1
    log_message "Xcode 包内资源已就绪：$RESOURCE_ROOT"
}
# Xcode Build 本身授权此资源生成阶段，不额外打开交互终端。
main() {
    show_intro_and_check_context || return $? # 首先说明职责并校验当前 App target。
    initialize_resources || return $? # 将状态限定在当前 DerivedData 目标目录。
    trap cleanup_resources EXIT # 结束时回收本轮临时资源和日志。
    prepare_current_resources # 准备当前后端和资源，不编译、不签名、不发布发行 App。
}
main "$@"

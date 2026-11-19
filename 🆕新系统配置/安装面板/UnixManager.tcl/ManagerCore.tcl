# Jobs Unix 管理面板数据与进程模型；不加载 Tk，不执行包管理业务。
namespace eval ::manager {
    variable root [file normalize [file join [file dirname [info script]] ../..]]
    variable platform ""
    variable backend ""
    variable catalog [dict create]
    variable selected [dict create]
    variable active ""
    variable job [dict create]
    variable prefs [dict create theme system language system]
    variable translations [dict create]
    variable languages {system zh-Hans zh-Hant bo en ja fr es de ru ko}
    variable themeIds {system light dark}
    variable stateDir ""
    variable logPath ""
    variable logChannel ""
    variable onOutput ""
    variable onDone ""
}
# 按 UTF-8 读取数据文件，始终关闭通道。
proc ::manager::readData {path} {
    set channel [open $path r]
    fconfigure $channel -encoding utf-8
    try { return [read $channel] } finally { close $channel }
}
# 按平台定位随包后端与当前用户状态目录。
proc ::manager::initialize {name} {
    variable root; variable platform; variable backend; variable stateDir; variable translations
    if {$name ni {Ubuntu Debian RockyLinux Alpine AlibabaCloudLinux FreeBSD}} {
        error "Unsupported platform: $name"
    }
    set platform $name
    set backend [file join $root $name 【${name}】🆕新系统配置.sh 【${name}】🆕新系统配置.sh]
    if {![file isfile $backend]} { error "Missing backend: $backend" }
    set translations [readData [file join $root 安装面板 Resources UnixTranslations.dict]]
    dict size $translations
    set base [file join $::env(HOME) .local state]
    if {[info exists ::env(XDG_STATE_HOME)] && [file pathtype $::env(XDG_STATE_HOME)] eq "absolute"} {
        set base $::env(XDG_STATE_HOME)
    }
    set stateDir [file join $base jobs-new-system-gui $platform]
    loadPreferences
}
# 配置是 Tcl dict 数据，不使用 source / eval 执行用户文件。
proc ::manager::loadPreferences {} {
    variable stateDir; variable prefs
    set path [file join $stateDir preferences.dict]
    if {[file exists $path] && [file size $path] < 4096 && ![catch {set values [readData $path]; dict size $values}]} {
        foreach {key allowed} {theme {system light dark} language {system zh-Hans zh-Hant bo en ja fr es de ru ko}} {
            if {[dict exists $values $key] && [dict get $values $key] in $allowed} {
                dict set prefs $key [dict get $values $key]
            }
        }
    }
}
# 建立本用户私有状态目录，不接受目录符号链接。
proc ::manager::privateDirectory {} {
    variable stateDir
    file mkdir $stateDir
    if {[file type $stateDir] eq "link"} { error "State directory must not be a symbolic link: $stateDir" }
    file attributes $stateDir -permissions 0700
}
# 原子保存主题与语言，不写入选择或执行授权。
proc ::manager::savePreferences {} {
    variable stateDir; variable prefs
    privateDirectory
    set channel [file tempfile temporary [file join $stateDir .preferences-]]
    try {
        fconfigure $channel -encoding utf-8
        puts $channel $prefs
    } finally { close $channel }
    file rename -force $temporary [file join $stateDir preferences.dict]
}
# 解析显式语言或当前进程的系统区域设置。
proc ::manager::language {} {
    variable prefs
    set value [dict get $prefs language]
    if {$value ne "system"} { return $value }
    set locale en
    foreach key {LC_ALL LC_MESSAGES LANG} {
        if {[info exists ::env($key)] && $::env($key) ne ""} { set locale $::env($key); break }
    }
    if {[regexp -nocase {^zh[_-](TW|HK|MO|Hant)} $locale]} { return zh-Hant }
    if {[regexp -nocase {^zh} $locale]} { return zh-Hans }
    foreach value {bo ja fr es de ru ko} {
        if {[string match -nocase ${value}* $locale]} { return $value }
    }
    return en
}
# 按当前语言替换稳定占位符，诊断原文不在此处理。
proc ::manager::tr {key args} {
    variable translations
    set locale [language]
    if {[dict exists $translations $locale $key]} { set value [dict get $translations $locale $key] } else { set value $key }
    set index 0
    foreach arg $args {
        set value [string map [list "\{$index\}" $arg] $value]
        incr index
    }
    return $value
}
# 清单只接受两列数据、合法稳定 ID；说明文字与日志不会变成可执行内容。
proc ::manager::parseCatalog {output} {
    set result [dict create]
    foreach line [split $output \n] {
        set fields [split [string trimright $line \r] \t]
        if {[llength $fields] != 2} { continue }
        lassign $fields id packages
        if {![regexp {^[a-z][a-z-]*$} $id] || $packages eq ""} { continue }
        if {[dict exists $result $id]} { error "Duplicate component ID: $id" }
        dict set result $id $packages
    }
    if {[dict size $result] == 0} { error "Empty or invalid component catalog" }
    return $result
}
# 只按当前目录顺序返回有效已选 ID。
proc ::manager::selectedIds {} {
    variable catalog; variable selected
    set result {}
    foreach id [dict keys $catalog] {
        if {[dict exists $selected $id] && [dict get $selected $id]} { lappend result $id }
    }
    return $result
}
# 构建唯一后端命令，写操作必须显式非空选择。
proc ::manager::commandFor {mode ids} {
    variable backend; variable catalog
    if {$mode ni {list plan install uninstall}} { error "Unsupported operation: $mode" }
    foreach id $ids {
        if {![dict exists $catalog $id]} { error "Unknown component ID: $id" }
    }
    if {$mode in {install uninstall} && [llength $ids] == 0} { error "No components selected" }
    set command [list /bin/sh $backend --$mode]
    if {[llength $ids] > 0} { lappend command --components [join $ids ,] }
    if {$mode in {install uninstall}} { lappend command --yes }
    return $command
}
# 只在明确执行后请求 PolicyKit；无可用图形授权工具时不偷偷启动 sudo。
proc ::manager::authorizedCommand {command} {
    if {[string trim [exec id -u]] eq "0"} { return $command }
    set pkexec [auto_execok pkexec]
    if {$pkexec eq ""} { error [tr {Administrator authorization unavailable. Run this manager in an authorized administrator session, or use the CLI.}] }
    return [concat $pkexec $command]
}
# 为本次查询或执行创建私有完整日志。
proc ::manager::newLog {} {
    variable stateDir; variable logPath; variable logChannel
    privateDirectory
    if {$logChannel ne ""} { close $logChannel }
    set logChannel [file tempfile logPath [file join $stateDir session-]]
    fconfigure $logChannel -encoding utf-8 -buffering line
}
# 保存纯文本输出，再送到界面显示回调。
proc ::manager::emit {value {tag ""}} {
    variable logChannel; variable onOutput
    # 终端样式仅从显示/会话副本剥离，后端自身日志保持不变。
    regsub -all {\x1b\[[0-?]*[ -/]*[@-~]} $value "" value
    if {$logChannel ne ""} {
        if {[catch {puts -nonewline $logChannel $value; flush $logChannel} message]} {
            catch {close $logChannel}
            set logChannel ""
            append value "\n[tr {Log file write failed. Visible output remains available to copy.}]\n$message\n"
        }
    }
    if {$onOutput ne ""} {
        if {$tag eq ""} { {*}$onOutput $value } else { {*}$onOutput $value $tag }
    }
}
# Runner 在子命令退出后落下状态；同时等待输出 EOF，不能把关闭输出当作任务完成。
proc ::manager::startJob {command callback} {
    variable root; variable stateDir; variable active; variable job; variable onDone
    if {$active ne ""} { error "An operation is already running" }
    privateDirectory
    set control [file tempfile controlPath [file join $stateDir .result-]]
    close $control
    set runner [file join $root 安装面板 UnixManager.tcl RunBackend.sh RunBackend.sh]
    set pipeline [list | /bin/sh $runner $controlPath {*}$command 2>@1]
    if {[catch {set active [open $pipeline r]} message options]} {
        file delete $controlPath
        return -options $options $message
    }
    fconfigure $active -blocking 0 -encoding utf-8 -translation auto
    set job [dict create result $controlPath output "" eof 0 started [clock clicks -milliseconds]]
    set onDone $callback
    fileevent $active readable ::manager::readJob
}
# 处理当前独立职责，保留已有资源与失败证据。
proc ::manager::readJob {} {
    variable active; variable job
    if {$active eq ""} { return }
    if {[catch {set chunk [read $active 32768]} message]} {
        emit "\n$message\n"
        dict set job readError 1
        set chunk ""
    }
    if {$chunk ne ""} {
        # 清单捕获有界；长日志持续落盘，不在模型中重复堆积。
        if {[string length [dict get $job output]] < 131072} { dict append job output $chunk }
        emit $chunk
    }
    if {[eof $active]} {
        fileevent $active readable {}
        dict set job eof 1
        finishJob
    }
}
# 排空管道并核对真实结果后冻结耗时及执行回调。
proc ::manager::finishJob {} {
    variable active; variable job; variable onDone
    if {$active eq ""} { return }
    set path [dict get $job result]
    set code [string trim [readData $path]]
    if {![string is integer -strict $code] || $code < 0 || $code > 255} {
        # Runner 异常退出时 EOF 仍已确认，不以缺少状态冒充成功。
        set code 125
    }
    if {[dict exists $job readError]} { set code 125 }
    fconfigure $active -blocking 1
    if {[catch {close $active} message options]} {
        if {$code == 0} { set code 125 }
        emit "\n$message\n"
    }
    set active ""
    file delete $path
    set output [dict get $job output]
    set elapsed [expr {([clock clicks -milliseconds] - [dict get $job started]) / 1000.0}]
    set callback $onDone
    set onDone ""
    if {$callback ne ""} { {*}$callback $code $output $elapsed }
}

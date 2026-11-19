#!/usr/bin/env wish
# Jobs Unix 新系统配置管理界面；系统包生命周期始终交给本平台 CLI。
source [file join [file dirname [info script]] ManagerCore.tcl]
namespace eval ::ui {
    variable mode install
    variable theme system
    variable locale system
    variable filter ""
    variable follow 1
    variable busy 0
    variable approval ""
    variable currentMode ""
    variable noticeKey {Ready. Select features and choose an action.}
    variable noticeArgs {}
    variable controls {}
    variable elapsed
    array set elapsed {install 0 uninstall 0 plan 0 list 0}
    variable rowChoice
    variable background "#f2f4f7"
    variable foreground "#17202a"
    variable lastTheme ""
    variable baseDark 0
    variable pressRow ""
    variable pressX 0
    variable pressY 0
    variable rowCanceled 0
}
# 建立可滚动的原生控件和单一长期事件循环。
proc ::ui::build {} {
    variable controls; variable theme; variable locale; variable baseDark
    set theme [dict get $::manager::prefs theme]
    set locale [dict get $::manager::prefs language]
    wm geometry . 1040x760
    wm minsize . 760 620
    wm protocol . WM_DELETE_WINDOW ::ui::requestClose
    ttk::style theme use clam
    set color [winfo rgb . [ttk::style lookup TFrame -background]]
    set baseDark [expr {[lindex $color 0] + [lindex $color 1] + [lindex $color 2] < 98302}]
    ttk::frame .main -padding 16
    pack .main -fill both -expand 1
    ttk::label .main.title -font {TkDefaultFont 18 bold}
    pack .main.title -anchor w -pady {0 8}
    ttk::label .main.subtitle -wraplength 980
    pack .main.subtitle -anchor w -fill x -pady {0 12}
    bind . <Configure> {if {"%W" eq "."} {.main.subtitle configure -wraplength [expr {max(200, %w - 40)}]}}
    ttk::frame .main.prefs
    pack .main.prefs -fill x -pady {0 12}
    ttk::label .main.prefs.theme
    ttk::combobox .main.prefs.themes -state readonly -width 16
    ttk::label .main.prefs.language
    ttk::combobox .main.prefs.languages -state readonly -width 19
    foreach widget {theme themes language languages} {
        pack .main.prefs.$widget -side left -padx {0 8}
    }
    bind .main.prefs.themes <<ComboboxSelected>> ::ui::changeTheme
    bind .main.prefs.languages <<ComboboxSelected>> ::ui::changeLanguage
    ttk::frame .main.tools
    pack .main.tools -fill x -pady {0 8}
    ttk::label .main.tools.search
    ttk::entry .main.tools.query -textvariable ::ui::filter -width 24
    ttk::button .main.tools.select -command {::ui::selectVisible 1}
    ttk::button .main.tools.clear -command {::ui::selectVisible 0}
    ttk::button .main.tools.reload -command ::ui::reload
    pack .main.tools.search .main.tools.query -side left -padx {0 8}
    pack .main.tools.reload .main.tools.clear .main.tools.select -side right -padx {8 0}
    lappend controls .main.tools.query .main.tools.select .main.tools.clear .main.tools.reload
    ttk::panedwindow .main.split -orient vertical
    pack .main.split -fill both -expand 1
    ttk::frame .main.split.components
    canvas .main.split.components.canvas -height 250 -highlightthickness 0 -yscrollcommand {.main.split.components.scroll set}
    ttk::scrollbar .main.split.components.scroll -command {.main.split.components.canvas yview}
    ttk::frame .main.split.components.canvas.rows
    .main.split.components.canvas create window 0 0 -window .main.split.components.canvas.rows -anchor nw -tags body
    pack .main.split.components.scroll -side right -fill y
    pack .main.split.components.canvas -side left -fill both -expand 1
    bind .main.split.components.canvas.rows <Configure> {.main.split.components.canvas configure -scrollregion [.main.split.components.canvas bbox all]}
    bind .main.split.components.canvas <Configure> {.main.split.components.canvas itemconfigure body -width %w}
    .main.split add .main.split.components -weight 1
    ttk::frame .main.split.logs
    ttk::frame .main.split.logs.tools
    pack .main.split.logs.tools -fill x -pady {10 8}
    ttk::label .main.split.logs.tools.title
    ttk::checkbutton .main.split.logs.tools.follow -variable ::ui::follow -command ::ui::resumeTail
    ttk::button .main.split.logs.tools.copy -command ::ui::copyLog
    ttk::button .main.split.logs.tools.file -command ::ui::openLog
    pack .main.split.logs.tools.title -side left
    pack .main.split.logs.tools.file .main.split.logs.tools.copy .main.split.logs.tools.follow -side right -padx {8 0}
    text .main.split.logs.text -wrap word -height 12 -state disabled -font TkFixedFont -yscrollcommand {.main.split.logs.scroll set}
    ttk::scrollbar .main.split.logs.scroll -command ::ui::scrollLog
    pack .main.split.logs.scroll -side right -fill y
    pack .main.split.logs.text -side left -fill both -expand 1
    foreach event {<MouseWheel> <Button-4> <Button-5> <Key-Up> <Key-Down> <Key-Prior> <Key-Next> <Key-Home> <Key-End>} {
        bind .main.split.logs.text $event {set ::ui::follow 0}
    }
    .main.split add .main.split.logs -weight 1
    ttk::frame .main.actions
    pack .main.actions -fill x -pady {12 8}
    ttk::radiobutton .main.actions.install -variable ::ui::mode -value install -command ::ui::invalidate
    ttk::radiobutton .main.actions.uninstall -variable ::ui::mode -value uninstall -command ::ui::invalidate
    ttk::button .main.actions.preview -command ::ui::preview
    ttk::button .main.actions.execute -command ::ui::execute
    ttk::button .main.actions.background -command {wm iconify .}
    pack .main.actions.install .main.actions.uninstall -side left -padx {0 10}
    pack .main.actions.background .main.actions.execute .main.actions.preview -side right -padx {8 0}
    lappend controls .main.actions.install .main.actions.uninstall .main.actions.preview .main.actions.execute
    ttk::progressbar .main.progress -mode indeterminate
    pack .main.progress -fill x -pady {0 8}
    ttk::label .main.count
    ttk::label .main.status -wraplength 980
    pack .main.count .main.status -anchor w -fill x -pady {0 4}
    trace add variable ::ui::filter write {apply {{args} {::ui::renderRows}}}
    set ::manager::onOutput ::ui::appendLog
    applyLanguage
    pollTheme
    after 1000 ::ui::tick
}
# 保存结构化界面提示键，语言变化时重新渲染。
proc ::ui::setNotice {key args} {
    variable noticeKey; variable noticeArgs
    set noticeKey $key
    set noticeArgs $args
    updateStatus
}
# 显示当前操作的提示和独立实际耗时。
proc ::ui::updateStatus {} {
    variable noticeKey; variable noticeArgs; variable elapsed; variable currentMode; variable mode
    set shown $mode
    if {$currentMode ne ""} { set shown $currentMode }
    .main.status configure -text "[::manager::tr $noticeKey {*}$noticeArgs]   [::manager::tr {Elapsed: {0} s} [format %.1f $elapsed($shown)]]"
}
# 翻译所有现有界面自有控件，保留选择与工作进程。
proc ::ui::applyLanguage {} {
    variable mode; variable theme; variable locale
    wm title . "Jobs $::manager::platform — [::manager::tr {System Setup Manager}]"
    foreach {path key} {
        .main.title {System Setup Manager}
        .main.subtitle {Review a plan before executing. System packages change only after the main button is pressed.}
        .main.prefs.theme Theme .main.prefs.language Language
        .main.tools.search {Search components} .main.tools.select {Select visible}
        .main.tools.clear {Clear all} .main.tools.reload Reload
        .main.split.logs.tools.title {Live log} .main.split.logs.tools.copy {Copy displayed log}
        .main.split.logs.tools.file {Log file} .main.split.logs.tools.follow Auto-scroll
        .main.actions.install Install .main.actions.uninstall Uninstall
        .main.actions.preview {Preview plan} .main.actions.background Minimize
    } { $path configure -text [::manager::tr $key] }
    set values {}
    foreach key {{Follow system} Light Dark} { lappend values [::manager::tr $key] }
    .main.prefs.themes configure -values $values
    .main.prefs.themes current [lsearch -exact $::manager::themeIds $theme]
    .main.prefs.languages configure -values [list [::manager::tr {Follow system}] 简体中文 繁體中文 བོད་ཡིག English 日本語 Français Español Deutsch Русский 한국어]
    .main.prefs.languages current [lsearch -exact $::manager::languages $locale]
    .main.actions.execute configure -text [::manager::tr [expr {$mode eq "install" ? "Install selected" : "Uninstall selected"}]]
    if {[winfo exists .close]} {
        wm title .close [::manager::tr {Close Manager}]
        .close.prompt configure -text [::manager::tr {Keep the manager minimized or quit completely?}]
        .close.buttons.keep configure -text [::manager::tr Minimize]
        .close.buttons.cancel configure -text [::manager::tr Cancel]
        .close.buttons.quit configure -text [::manager::tr {Quit completely}]
    }
    renderRows
    updateStatus
}
# 保存显式外观选择并原地更新颜色。
proc ::ui::changeTheme {} {
    variable theme
    set theme [lindex $::manager::themeIds [.main.prefs.themes current]]
    dict set ::manager::prefs theme $theme
    savePreferences
    applyTheme
}
# 保存语言选择并原地翻译界面。
proc ::ui::changeLanguage {} {
    variable locale
    set locale [lindex $::manager::languages [.main.prefs.languages current]]
    dict set ::manager::prefs language $locale
    savePreferences
    applyLanguage
}
# 原子保存主题与语言，不写入选择或执行授权。
proc ::ui::savePreferences {} {
    if {[catch {::manager::savePreferences} message]} { appendLog "\n$message\n" }
}
# GNOME 与 KDE 提供外观偏好时跟随；其它 X11 桌面保留启动时的系统 Tk 色调。
proc ::ui::systemDark {} {
    variable baseDark
    if {[info exists ::env(GTK_THEME)]} { return [string match -nocase *dark* $::env(GTK_THEME)] }
    set gsettings [auto_execok gsettings]
    if {$gsettings ne ""} {
        if {![catch {exec {*}$gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null} value] && [string match *prefer-dark* $value]} { return 1 }
        if {![catch {exec {*}$gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null} value]} { return [string match -nocase *dark* $value] }
    }
    set kde [file join $::env(HOME) .config kdeglobals]
    if {[file isfile $kde] && [file size $kde] < 1048576} {
        set data [::manager::readData $kde]
        if {[regexp -nocase {ColorScheme=([^\r\n]+)} $data -> scheme]} { return [string match -nocase *dark* $scheme] }
    }
    return $baseDark
}
# 定时监听受支持桌面的系统外观变化。
proc ::ui::pollTheme {} {
    if {$::ui::theme eq "system"} { applyTheme }
    after 3000 ::ui::pollTheme
}
# 为控件、下拉菜单及已有日志统一应用两套颜色。
proc ::ui::applyTheme {} {
    variable theme; variable lastTheme; variable background; variable foreground
    set dark [expr {$theme eq "dark" || ($theme eq "system" && [systemDark])}]
    if {$dark eq $lastTheme} { return }
    set lastTheme $dark
    if {$dark} {
        set background #20242b; set foreground #f1f4f8; set field #15191f; set muted #adb7c4
        set selection #284e75; set error #ffb3b3; set success #8fe2ad
    } else {
        set background #f2f4f7; set foreground #17202a; set field #ffffff; set muted #525e6d
        set selection #cce2ff; set error #9c2020; set success #126633
    }
    . configure -background $background
    if {[winfo exists .close]} { .close configure -background $background }
    ttk::style configure . -background $background -foreground $foreground -fieldbackground $field -font TkDefaultFont
    ttk::style configure TButton -padding {12 7} -background $background -foreground $foreground
    ttk::style map TButton -background [list active $selection disabled $background] -foreground [list disabled $muted]
    ttk::style map TCheckbutton -background [list active $selection] -foreground [list disabled $muted]
    ttk::style map TRadiobutton -background [list active $selection] -foreground [list disabled $muted]
    ttk::style configure TEntry -insertcolor $foreground
    ttk::style map TCombobox -fieldbackground [list readonly $field] -selectbackground [list readonly $field] -selectforeground [list readonly $foreground]
    option add *TCombobox*Listbox.background $field
    option add *TCombobox*Listbox.foreground $foreground
    option add *TCombobox*Listbox.selectBackground $selection
    option add *TCombobox*Listbox.selectForeground $foreground
    .main.split.components.canvas configure -background $background
    .main.split.logs.text configure -background $field -foreground $foreground -insertbackground $foreground -selectbackground $selection -selectforeground $foreground
    .main.split.logs.text tag configure error -foreground $error
    .main.split.logs.text tag configure success -foreground $success
}
# 按搜索重绘原生整行复选框，空目录保留重载入口。
proc ::ui::renderRows {} {
    variable filter; variable busy; variable rowChoice
    set body .main.split.components.canvas.rows
    foreach widget [winfo children $body] { destroy $widget }
    set count 0
    foreach id [dict keys $::manager::catalog] {
        set packages [dict get $::manager::catalog $id]
        if {$filter ne "" && [string first [string tolower $filter] [string tolower "$id $packages"]] < 0} { continue }
        set rowChoice($id) [expr {[dict exists $::manager::selected $id] && [dict get $::manager::selected $id]}]
        ttk::checkbutton $body.r$count -text "$id    $packages" -variable ::ui::rowChoice($id) -command [list ::ui::selected $id] -padding {12 9}
        pack $body.r$count -fill x -anchor w
        if {$busy} { $body.r$count state disabled }
        # Guard only cancels a pointer gesture; the native class remains the sole toggle.
        bind $body.r$count <ButtonPress-1> {if {![::ui::rowPress %W %X %Y]} {break}}
        bind $body.r$count <B1-Motion> {::ui::rowMotion %X %Y}
        bind $body.r$count <Leave> {::ui::cancelRow}
        bind $body.r$count <ButtonRelease-1> {if {![::ui::rowRelease %W %X %Y]} {break}}
        foreach event {<MouseWheel> <Button-4> <Button-5>} {
            bind $body.r$count $event [list ::ui::scrollRows $event %D]
        }
        incr count
    }
    if {$count == 0} {
        set key {No matching components. Clear the search or reload.}
        if {[dict size $::manager::catalog] == 0} { set key {No components available. Use Reload to try again.} }
        ttk::label $body.empty -text [::manager::tr $key] -wraplength 640 -padding 20
        ttk::button $body.retry -text [::manager::tr Reload] -command ::ui::reload
        pack $body.empty $body.retry -anchor center -pady 12
        if {$busy} { $body.retry state disabled }
    }
    .main.count configure -text [::manager::tr {Selected {0} / {1}; visible {2}} [llength [::manager::selectedIds]] [dict size $::manager::catalog] $count]
    updateButtons
}
# 开始指针候选点击，执行中不接受新选择。
proc ::ui::rowPress {widget x y} {
    variable pressRow; variable pressX; variable pressY; variable rowCanceled
    if {$::ui::busy} { return 0 }
    set pressRow $widget
    set pressX $x
    set pressY $y
    set rowCanceled 0
    return 1
}
# 超过系统等价拖动容差后取消候选点击。
proc ::ui::rowMotion {x y} {
    variable pressX; variable pressY
    if {abs($x - $pressX) > 5 || abs($y - $pressY) > 5} { cancelRow }
}
# 取消待提交点击，保留原生控件的键盘动作。
proc ::ui::cancelRow {} {
    variable pressRow; variable rowCanceled
    set rowCanceled 1
    if {$pressRow ne "" && [winfo exists $pressRow]} { $pressRow state !pressed }
}
# 仅原行内的完整点击交给原生类绑定切换一次。
proc ::ui::rowRelease {widget x y} {
    variable pressRow; variable pressX; variable pressY; variable rowCanceled
    set valid [expr {!$::ui::busy && !$rowCanceled && $pressRow eq $widget && abs($x - $pressX) <= 5 && abs($y - $pressY) <= 5}]
    if {!$valid} { cancelRow }
    set pressRow ""
    return $valid
}
# 按桌面事件保留滚动位移，滚动不会提交行点击。
proc ::ui::scrollRows {event delta} {
    cancelRow
    set pixels 0.0
    switch -- $event {
        <Button-4> { set pixels -40.0 }
        <Button-5> { set pixels 40.0 }
        default {
            if {[tk windowingsystem] eq "aqua"} {
                set pixels [expr {-$delta * 1.0}]
            } else { set pixels [expr {-$delta / 120.0 * 40.0}] }
        }
    }
    set canvas .main.split.components.canvas
    set box [$canvas bbox all]
    if {[llength $box] == 4 && [lindex $box 3] > 0} {
        set first [lindex [$canvas yview] 0]
        $canvas yview moveto [expr {$first + $pixels / [lindex $box 3]}]
    }
}
# 把原生勾选写回稳定 ID 后撤销旧计划。
proc ::ui::selected {id} {
    variable rowChoice
    if {$::ui::busy} { return }
    dict set ::manager::selected $id $rowChoice($id)
    invalidate
}
# 全选仅作用于当前匹配项，清空作用于全部选择。
proc ::ui::selectVisible {value} {
    variable filter
    if {$::ui::busy} { return }
    foreach id [dict keys $::manager::catalog] {
        if {!$value || $filter eq "" || [string first [string tolower $filter] [string tolower "$id [dict get $::manager::catalog $id]"]] >= 0} {
            dict set ::manager::selected $id $value
        }
    }
    invalidate
}
# 选择或动作变化后重新要求预览。
proc ::ui::invalidate {} {
    variable approval
    set approval ""
    .main.actions.execute configure -text [::manager::tr [expr {$::ui::mode eq "install" ? "Install selected" : "Uninstall selected"}]]
    renderRows
    updateStatus
}
# 空选、忙态或过期计划均不能执行写操作。
proc ::ui::updateButtons {} {
    variable busy; variable approval; variable mode
    set ids [::manager::selectedIds]
    set enabled [expr {!$busy && [llength $ids] > 0}]
    .main.actions.preview state [expr {$enabled ? "!disabled" : "disabled"}]
    .main.actions.execute state [expr {$enabled && $approval eq [list $mode $ids] ? "!disabled" : "disabled"}]
}
# 锁定计划编辑与重复执行，日志浏览始终可用。
proc ::ui::lock {value} {
    variable busy; variable controls
    set busy $value
    foreach widget $controls { $widget state [expr {$value ? "disabled" : "!disabled"}] }
    if {$value} { .main.progress start 80 } else { .main.progress stop }
    renderRows
}
# 为单批任务建立日志、锁定控件并启动异步后端。
proc ::ui::begin {kind command callback} {
    variable currentMode; variable elapsed
    if {$::ui::busy} { return }
    if {[catch {::manager::newLog} message]} { tk_messageBox -icon error -message "$message"; return }
    set currentMode $kind
    set elapsed($kind) 0
    lock 1
    if {[catch {::manager::startJob $command $callback} message]} {
        ::manager::emit "\n$message\n"
        set currentMode ""
        lock 0
        setNotice {Failed: see log}
    }
}
# 启动只读清单查询，不初始化系统包状态。
proc ::ui::reload {} {
    if {$::ui::busy} { return }
    set ::ui::approval ""
    setNotice {Reading component status…}
    begin list [::manager::commandFor list {}] ::ui::catalogDone
}
# 只接受成功且可解析的清单，否则显示重载空态。
proc ::ui::catalogDone {code output elapsed} {
    set ::ui::elapsed(list) $elapsed
    set ::ui::currentMode ""
    if {$code == 0 && ![catch {set values [::manager::parseCatalog $output]} message]} {
        set ::manager::catalog $values
        setNotice {Ready. Select features and choose an action.}
    } else {
        set ::manager::catalog [dict create]
        if {[info exists message]} { appendLog "\n$message\n" }
        setNotice {Could not read status. See log and use Reload.}
    }
    lock 0
}
# 预览当前显式选择，并说明卸载资格的实际检查边界。
proc ::ui::preview {} {
    set ids [::manager::selectedIds]
    if {$::ui::busy || [llength $ids] == 0} { return }
    set ::ui::approval ""
    setNotice {Previewing plan…}
    if {$::ui::mode eq "uninstall"} { ::manager::emit "\n[::manager::tr {Uninstall eligibility is checked against receipts during execution. This plan only reports current health.}]\n" }
    begin plan [::manager::commandFor plan $ids] [list ::ui::planDone $::ui::mode $ids]
}
# 只为成功预览的动作和 ID 快照启用主按钮。
proc ::ui::planDone {mode ids code output elapsed} {
    set ::ui::elapsed(plan) $elapsed
    set ::ui::currentMode ""
    if {$code == 0} {
        set ::ui::approval [list $mode $ids]
        if {$mode eq "uninstall"} {
            ::manager::emit "\n[::manager::tr {Uninstall eligibility is checked against receipts during execution. This plan only reports current health.}]\n"
            setNotice {Uninstall eligibility is checked against receipts during execution. This plan only reports current health.}
        } else { setNotice {Plan ready} }
    } else { setNotice {Failed: see log} }
    lock 0
}
# 验证当前计划后才请求权限并提交唯一批任务。
proc ::ui::execute {} {
    variable approval; variable mode
    set ids [::manager::selectedIds]
    if {$::ui::busy || $ids eq "" || $approval ne [list $mode $ids]} { return }
    if {[catch {set command [::manager::authorizedCommand [::manager::commandFor $mode $ids]]} message]} {
        tk_messageBox -title [::manager::tr {System Setup Manager}] -icon warning -message $message
        return
    }
    set approval ""
    setNotice [expr {$mode eq "install" ? "Installing…" : "Uninstalling…"}]
    begin $mode $command [list ::ui::operationDone $mode]
}
# 按真实退出码呈现批结果，不猜测逐项状态。
proc ::ui::operationDone {mode code output elapsed} {
    set ::ui::elapsed($mode) $elapsed
    set ::ui::currentMode ""
    if {$code == 0} {
        set key {Batch completed. Per-component details are in the log.}
        set tag success
    } else {
        set key {Batch did not complete. Per-component details are in the log.}
        set tag error
    }
    ::manager::emit "\n[::manager::tr $key]\n[::manager::tr {Exit code: {0}} $code]\n" $tag
    setNotice $key
    lock 0
}
# 有界显示日志，保留手动浏览位置及完整落盘日志。
proc ::ui::appendLog {text {tag {}}} {
    variable follow
    set widget .main.split.logs.text
    $widget mark set __viewport [$widget index @0,0]
    $widget mark gravity __viewport left
    $widget configure -state normal
    $widget insert end $text $tag
    set lines [lindex [split [$widget index end] .] 0]
    if {$lines > 5000} { $widget delete 1.0 [expr {$lines - 5000}].0 }
    $widget configure -state disabled
    if {$follow} { $widget see end } else { $widget yview __viewport }
}
# 显式重新勾选时才恢复日志自动追尾。
proc ::ui::resumeTail {} {
    if {$::ui::follow} { .main.split.logs.text see end }
}
# 滚动条浏览暂停追尾，不干扰原生位移。
proc ::ui::scrollLog {args} {
    set ::ui::follow 0
    .main.split.logs.text yview {*}$args
}
# 复制显示区保留的纯文本，范围由按钮文案明确。
proc ::ui::copyLog {} {
    clipboard clear
    clipboard append [.main.split.logs.text get 1.0 end-1c]
}
# 安全打开当前完整日志，无查看器时显示实际路径。
proc ::ui::openLog {} {
    set path $::manager::logPath
    if {$path eq "" || ![file isfile $path]} { return }
    set open [auto_execok xdg-open]
    if {$open ne "" && ![catch {exec {*}$open $path 2>/dev/null &}]} { return }
    tk_messageBox -title [::manager::tr {Log file}] -message $path
}
# 活动任务每秒刷新实际单调耗时。
proc ::ui::tick {} {
    if {$::ui::busy && $::ui::currentMode ne "" && $::manager::active ne ""} {
        set ::ui::elapsed($::ui::currentMode) [expr {([clock clicks -milliseconds] - [dict get $::manager::job started]) / 1000.0}]
        updateStatus
    }
    after 1000 ::ui::tick
}
# 忙时直接最小化，空闲才提供默认保留的退出选择。
proc ::ui::requestClose {} {
    if {$::ui::busy} { wm iconify .; return }
    if {[winfo exists .close]} { raise .close; return }
    toplevel .close
    .close configure -background $::ui::background
    wm title .close [::manager::tr {Close Manager}]
    wm transient .close .
    ttk::label .close.prompt -text [::manager::tr {Keep the manager minimized or quit completely?}] -wraplength 500 -padding 18
    pack .close.prompt -fill both
    ttk::frame .close.buttons -padding 12
    pack .close.buttons -fill x
    ttk::button .close.buttons.keep -text [::manager::tr Minimize] -command {destroy .close; wm iconify .}
    ttk::button .close.buttons.cancel -text [::manager::tr Cancel] -command {destroy .close}
    ttk::button .close.buttons.quit -text [::manager::tr {Quit completely}] -command ::ui::quit
    pack .close.buttons.keep .close.buttons.cancel .close.buttons.quit -side left -padx 8
    bind .close <Escape> {destroy .close}
    wm protocol .close WM_DELETE_WINDOW {destroy .close}
    focus .close.buttons.keep
}
# 只在工作进程及输出均已结束时释放图形资源。
proc ::ui::quit {} {
    # 关闭选择期间若开始任务，旧退出动作仍不能终止工作进程。
    if {$::ui::busy || $::manager::active ne ""} {
        if {[winfo exists .close]} { destroy .close }
        wm iconify .
        return
    }
    if {$::manager::logChannel ne ""} { close $::manager::logChannel }
    destroy .
}
# 核验运行时和资源，再建立界面并只读加载目录。
proc main {args} {
    if {[llength $args] != 1} { puts stderr "Usage: wish UnixManager.tcl <platform>"; exit 2 }
    package require Tk
    if {[package vcompare [package present Tcl] 8.6] < 0 || [package vcompare [package present Tk] 8.6] < 0} {
        puts stderr "Tcl/Tk 8.6 or later is required"
        exit 2
    }
    if {[catch {::manager::initialize [lindex $args 0]} message]} {
        tk_messageBox -icon error -message $message
        exit 1
    }
    ::ui::build
    after idle ::ui::reload
}
if {[file normalize [info script]] eq [file normalize $argv0]} { main {*}$argv }

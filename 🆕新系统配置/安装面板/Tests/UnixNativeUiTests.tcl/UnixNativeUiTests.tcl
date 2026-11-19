#!/usr/bin/env tclsh
# 本机原生 Tk 控件与后台生命周期的有界假 worker；不执行真实包事务。
set sourcePath [file normalize [file join [file dirname [info script]] ../../UnixManager.tcl/UnixManager.tcl]]
set report [file tempfile reportPath]
fconfigure $report -encoding utf-8 -buffering line
puts "Native Tk report: $reportPath"
flush stdout
source $sourcePath
namespace eval ::nativeTest { variable count 0 }
proc bgerror {message} {
    puts $::report "BACKGROUND ERROR: $message\n$::errorInfo"
    close $::report
    exit 1
}
after 10000 {puts $::report "FAILED: native test watchdog"; close $::report; exit 1}
# 每个断言写入独立报告，Tk Aqua 改变标准通道时仍保留证据。
proc ::nativeTest::check {expression message} {
    incr ::nativeTest::count
    if {![uplevel 1 [list expr $expression]]} { error "FAIL: $message" }
    puts $::report "OK: $message"
}
# 生成真实控件的按下/抬起事件，类绑定仍是唯一选择执行者。
proc ::nativeTest::click {widget {offset 24}} {
    set x [expr {[winfo rootx $widget] + $offset}]
    set y [expr {[winfo rooty $widget] + [winfo height $widget]/2}]
    event generate $widget <ButtonPress-1> -x $offset -y 12 -rootx $x -rooty $y
    event generate $widget <ButtonRelease-1> -x $offset -y 12 -rootx $x -rooty $y
    update
}
# 等待真实 Tcl 事件循环处理有界假后端输出，超时立即报告。
proc ::nativeTest::waitJob {} {
    set deadline [expr {[clock milliseconds] + 5000}]
    while {$::manager::active ne ""} {
        if {[clock milliseconds] > $deadline} { error "Native worker timeout" }
        update
        after 10
    }
    update
}
# 不加载生产权限或包命令，假命令只有输出、等待与明确退出码。
proc ::nativeTest::setup {} {
    package require Tk
    check {[package vcompare [package present Tk] 8.6] >= 0} "Tk runtime version [package present Tk]"
    set tmp [file tempfile path]
    close $tmp
    file delete $path
    set ::fixture "$path native GUI 中文 空格"
    file mkdir $::fixture
    set ::env(XDG_STATE_HOME) $::fixture
    ::manager::initialize Ubuntu
    set ::manager::catalog [::manager::parseCatalog "git\tgit\ncurl\tcurl\nnode\tnodejs npm"]
    set ::manager::backend [file join $::fixture fake-backend.sh]
    set fake [open $::manager::backend w]
    puts $fake {#!/bin/sh
printf 'fake backend: %s\n' "$*"
sleep 0.15
printf 'late tail\n'
exit 0
}
    close $fake
    rename ::manager::authorizedCommand ::manager::originalAuthorizedCommand
    proc ::manager::authorizedCommand {command} { return $command }
    ::ui::build
    update
}
# 覆盖整行、键盘、拖动、出界、滚动取消和执行中锁定。
proc ::nativeTest::selection {} {
    set row .main.split.components.canvas.rows.r0
    check {[llength [::manager::selectedIds]] == 0} "default empty"
    click $row
    check {[::manager::selectedIds] eq {git}} "checkbox click toggles exactly once"
    click $row 220
    check {[llength [::manager::selectedIds]] == 0} "row whitespace toggles exactly once"
    set x [expr {[winfo rootx $row]+24}]
    set y [expr {[winfo rooty $row]+12}]
    event generate $row <ButtonPress-1> -x 24 -y 12 -rootx $x -rooty $y
    event generate $row <B1-Motion> -x 50 -y 12 -rootx [expr {$x+26}] -rooty $y
    event generate $row <ButtonRelease-1> -x 24 -y 12 -rootx $x -rooty $y
    update
    check {[llength [::manager::selectedIds]] == 0} "drag away and return cancels"
    event generate $row <ButtonPress-1> -x 24 -y 12 -rootx $x -rooty $y
    event generate $row <Leave>
    event generate $row <ButtonRelease-1> -x 24 -y 12 -rootx $x -rooty $y
    update
    check {[llength [::manager::selectedIds]] == 0} "leave and return cancels"
    event generate $row <ButtonPress-1> -x 24 -y 12 -rootx $x -rooty $y
    event generate $row <MouseWheel> -delta -12
    event generate $row <ButtonRelease-1> -x 24 -y 12 -rootx $x -rooty $y
    update
    check {[llength [::manager::selectedIds]] == 0} "wheel cancels pending click"
    focus -force $row
    event generate $row <KeyPress-space>
    event generate $row <KeyRelease-space>
    update
    check {[::manager::selectedIds] eq {git}} "native Space key toggles"
    foreach language {zh-Hans zh-Hant bo en ja fr es de ru ko} {
        dict set ::manager::prefs language $language
        set ::ui::locale $language
        ::ui::applyLanguage
        update
        check {[::manager::selectedIds] eq {git}} "language $language keeps selection"
    }
    foreach theme {dark light system} {
        set ::ui::theme $theme
        ::ui::applyTheme
        update
        check {[::manager::selectedIds] eq {git}} "theme $theme keeps selection"
    }
    ::ui::lock 1
    $row invoke
    update
    check {[::manager::selectedIds] eq {git}} "busy row cannot change selection"
    ::ui::lock 0
}
# 主按钮、后台最小化、尾输出、原窗口恢复及空闲退出合同。
proc ::nativeTest::lifecycle {} {
    ::ui::preview
    waitJob
    check {$::ui::approval eq [list install {git}]} "successful plan enables exact selected snapshot"
    check {[.main.actions.execute instate !disabled]} "main action enabled only after plan"
    .main.actions.execute invoke
    check {$::ui::busy && $::manager::active ne ""} "worker and UI busy"
    ::ui::requestClose
    update
    check {![winfo exists .close]} "busy close has no question"
    check {[wm state .] eq "iconic"} "busy close minimizes original window"
    waitJob
    check {!$::ui::busy && [wm state .] eq "iconic"} "completion remains background"
    check {[string first {late tail} [.main.split.logs.text get 1.0 end]] >= 0} "hidden window retains final output"
    check {$::ui::elapsed(install) >= 0.1} "timer freezes after true worker completion"
    wm deiconify .
    update
    check {[::manager::selectedIds] eq {git}} "restore keeps original selection"
    set ::ui::follow 0
    ::ui::appendLog "manual browser position\n"
    check {!$::ui::follow} "output does not resume paused tail"
    ::ui::requestClose
    update
    check {[winfo exists .close]} "idle close asks explicitly"
    check {[focus] eq ".close.buttons.keep"} "idle default is keep minimized"
    destroy .close
    set ::ui::mode uninstall
    ::ui::invalidate
    check {$::ui::elapsed(install) >= 0.1 && $::ui::elapsed(uninstall) == 0} "operation timers are independent"
    set ::ui::filter no-match
    update
    check {[winfo exists .main.split.components.canvas.rows.retry]} "filtered empty state has reload"
    set ::ui::filter ""
    update
}
# 只编排已声明的有界控件与假 worker 验证。
proc ::nativeTest::run {} {
    setup
    selection
    lifecycle
}
set code [catch {::nativeTest::run} message options]
if {$code} {
    puts $report "FAILED: $message\n[dict get $options -errorinfo]"
} else {
    puts $report "PASS: $::nativeTest::count native checks; fixture: $::fixture"
}
close $report
catch {destroy .}
exit [expr {$code ? 1 : 0}]

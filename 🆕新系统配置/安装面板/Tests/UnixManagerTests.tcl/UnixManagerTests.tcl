#!/usr/bin/env tclsh
# Jobs GUI 模型隔离回归；不加载 Tk，不运行真实包管理器。
source [file join [file dirname [info script]] ../../UnixManager.tcl/ManagerCore.tcl]
set count 0
proc check {expression message} {
    incr ::count
    if {![uplevel 1 [list expr $expression]]} { error "FAIL: $message" }
}
proc writeFile {path value} {
    set channel [open $path w]
    fconfigure $channel -encoding utf-8
    puts -nonewline $channel $value
    close $channel
}
proc capture {value} { append ::received $value }
proc complete {code output elapsed} {
    set ::result [list $code $output $elapsed]
    set ::done 1
}
proc run {command} {
    set ::done 0
    set ::received ""
    ::manager::newLog
    ::manager::startJob $command complete
    set watchdog [after 5000 {set ::done timeout}]
    vwait ::done
    after cancel $watchdog
    if {$::done eq "timeout"} { error "Worker timeout" }
    return $::result
}
proc main {} {
    set channel [file tempfile path]
    close $channel
    file delete $path
    set ::scratch "$path GUI 中文 空格"
    file mkdir $::scratch
    set ::env(XDG_STATE_HOME) $::scratch
    foreach platform {Ubuntu Debian RockyLinux Alpine AlibabaCloudLinux FreeBSD} {
        ::manager::initialize $platform
        check {[file exists $::manager::backend]} "backend for $platform"
    }
    set keys [dict keys [dict get $::manager::translations en]]
    foreach lang {zh-Hans zh-Hant bo en ja fr es de ru ko} {
        check {[lsort [dict keys [dict get $::manager::translations $lang]]] eq [lsort $keys]} "complete keys $lang"
        foreach key $keys { check {[dict get $::manager::translations $lang $key] ne ""} "nonempty $lang $key" }
    }
    set catalog [::manager::parseCatalog "Jobs intro\nID\t系统软件包\ngit\tgit\nnode\tnodejs npm\n"]
    check {[dict size $catalog] == 2} "two column catalog"
    check {[catch {::manager::parseCatalog "git\tgit\ngit\tother"}]} "duplicate IDs rejected"
    check {[catch {::manager::parseCatalog "not a catalog"}]} "empty catalog rejected"
    set ::manager::catalog $catalog
    check {[catch {::manager::commandFor install {}}]} "empty write rejected"
    check {[catch {::manager::commandFor uninstall {unknown}}]} "unknown ID rejected"
    set command [::manager::commandFor install {git node}]
    check {[lrange $command 2 end] eq {--install --components git,node --yes}} "single batch no split"
    check {[llength [::manager::selectedIds]] == 0} "default selection empty"
    dict set ::manager::selected node 1
    dict set ::manager::selected unknown 1
    check {[::manager::selectedIds] eq {node}} "stable catalog IDs only"
    dict set ::manager::prefs theme dark
    dict set ::manager::prefs language bo
    ::manager::savePreferences
    set ::manager::prefs [dict create theme light language en]
    ::manager::loadPreferences
    check {[dict get $::manager::prefs theme] eq "dark"} "theme persists"
    check {[dict get $::manager::prefs language] eq "bo"} "language persists"
    set preferences [file join $::manager::stateDir preferences.dict]
    writeFile $preferences {theme [exec touch should-not-exist] language unknown}
    ::manager::loadPreferences
    check {![file exists should-not-exist]} "preferences treated as data"
    set ::manager::onOutput capture
    set backend [file join $::scratch {fake backend ; $script.sh}]
    writeFile $backend {#!/bin/sh
printf 'first\n'
sleep 0.1
printf '%s\n' "$1"
printf 'error details\n' >&2
exit 7
}
    set arg {中文 空格 ; $(touch should-not-exist)}
    lassign [run [list /bin/sh $backend $arg]] code output elapsed
    check {$code == 7} "true nonzero exit preserved"
    check {[string first $arg $output] >= 0} "arguments preserved without shell eval"
    check {[string first {error details} $output] >= 0} "stderr drained"
    check {$elapsed >= 0.08} "actual elapsed time"
    check {$::manager::active eq ""} "inactive only after completion"
    set log [::manager::readData $::manager::logPath]
    check {[string first $arg $log] >= 0} "full log recorded"
    check {![file exists should-not-exist]} "argument not evaluated"
    writeFile $backend {#!/bin/sh
printf 'tail\n'
exit 0
}
    lassign [run [list /bin/sh $backend]] code output elapsed
    check {$code == 0 && [string first tail $output] >= 0} "zero exit and tail retained"
    writeFile $backend {#!/bin/sh
printf 'starting\n'
sleep 0.2
printf 'ending\n'
exit 0
}
    set ::done 0
    set ::received ""
    ::manager::newLog
    ::manager::startJob [list /bin/sh $backend] complete
    check {[catch {::manager::startJob [list /bin/sh $backend] complete}]} "duplicate start rejected"
    after 50 {set ::earlyDone 1}
    vwait ::earlyDone
    check {$::manager::active ne ""} "worker active while awaiting tail"
    vwait ::done
    check {[string first ending $::received] >= 0} "late output retained"
    # 任意进程关闭stdout后仍继续，runner的状态完成之前不能判空闲。
    writeFile $backend {#!/bin/sh
printf 'before close\n'
exec 1>&- 2>&-
sleep 0.2
exit 9
}
    lassign [run [list /bin/sh $backend]] code output elapsed
    check {$code == 9 && $elapsed >= 0.15} "output closure is not completion"
    puts "PASS: $::count assertions; fixture: $::scratch"
}
main

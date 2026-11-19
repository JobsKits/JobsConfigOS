#requires -Version 5.1
<#
WindowsPanel.Tests.ps1 | Jobs 新系统配置 GUI 协议回归
Created by Jobs on 2026年11月17日，星期二.
只验证目录、翻译、后台假进程及事件协议，不加载 WinForms、不访问 WinGet。
#>
[CmdletBinding()]
param()
# 验证隔离场景，不把语法检查称为 Windows 控件验收。
function Assert-PanelCase {
    param([bool]$Condition,[string]$Name)
    if (-not $Condition) { throw ('Assertion failed: '+$Name) }
    $script:Assertions++
    Write-Output ('PASS '+$Name)
}
# 记录事件 JSON，避免测试触发安装、权限或包管理器检查。
function Invoke-PanelProtocolTests {
    . $script:Backend
    $script:Selected=@($script:Catalog | Select-Object -First 3)
    $Mode='Install'; $Events=$true
    function Install-Component { param($Component) if ($Component.Id -eq 'git-lfs') { throw 'simulated package failure' }; $script:ComponentResult='reused' }
    $captured=New-Object 'System.Collections.Generic.List[string]'
    $failed=$false
    try { Invoke-SelectedOperation | ForEach-Object { $captured.Add([string]$_) } } catch { $failed=$true }
    $frames=@($captured | Where-Object { $_.StartsWith('@@JOBS_EVENT@@') } | ForEach-Object { $_.Substring(14) | ConvertFrom-Json })
    Assert-PanelCase $failed 'backend failure is propagated'
    Assert-PanelCase ((($frames | ForEach-Object { $_.id+':'+$_.state }) -join ',') -ceq 'git:running,git:reused,git-lfs:running,git-lfs:failed') 'stable ID event order, true reuse and first failure'
    Assert-PanelCase (@($frames | Where-Object { $_.id -eq 'gh' }).Count -eq 0) 'unstarted component has no fabricated result'
    Assert-PanelCase (@($frames | Where-Object { $_.schema -ne 1 -or $_.operation -ne 'Install' }).Count -eq 0) 'event schema and operation identity'
    $script:Selected=@($script:Catalog | Select-Object -First 1)
    $Events=$false
    $output=@(Invoke-SelectedOperation)
    Assert-PanelCase (@($output | Where-Object { $_ -like '@@JOBS_EVENT@@*' }).Count -eq 0) 'default CLI output has no event frames'
    $Events=$true; $Mode='Uninstall'
    $script:Selected=@($script:Catalog | Select-Object -First 3)
    function Uninstall-Component { param($Component) $script:ComponentResult='skipped' }
    $frames=@(Invoke-SelectedOperation | ForEach-Object { $_.Substring(14) | ConvertFrom-Json })
    Assert-PanelCase ((($frames | ForEach-Object { $_.id+':'+$_.state }) -join ',') -ceq 'gh:running,gh:skipped,git-lfs:running,git-lfs:skipped,git:running,git:skipped') 'reverse removal order and separate no-removal results'
}
# 主流程只启动有界假子进程，并等待尾输出排空后核对真实非零退出码。
function Main {
    $script:ErrorActionPreference='Stop'; $script:Assertions=0
    $root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $script:Backend=Join-Path $root '【WindowsOS】🆕新系统配置.ps1/【WindowsOS】🆕新系统配置.ps1'
    $panel=Join-Path $root '【WindowsOS】🧰新系统配置管理.ps1/【WindowsOS】🧰新系统配置管理.ps1'
    . $panel
    Initialize-PanelPaths
    $script:PanelLanguage='en'
    Assert-PanelCase ($script:PanelCatalog.Count -eq 20) 'GUI reads the current backend catalog without executing it'
    $required=@($script:PanelTranslations.en.PSObject.Properties.Name)
    foreach ($language in @('en','zh-Hans','zh-Hant','bo','ja','fr','es','de','ru','ko')) {
        $actual=@($script:PanelTranslations.$language.PSObject.Properties.Name)
        Assert-PanelCase ((($actual | Sort-Object) -join "`n") -ceq (($required | Sort-Object) -join "`n")) ($language+' covers every translation key')
        foreach ($key in $required) { if ([string]::IsNullOrWhiteSpace([string]$script:PanelTranslations.$language.$key)) { throw ('Empty translation: '+$language+'/'+$key) } }
    }
    $plan=New-PanelWorkerCommand 'Plan' 'Install' @('git')
    $install=New-PanelWorkerCommand 'Install' 'Install' @('git')
    Assert-PanelCase ($plan -notmatch '\-Confirm|\-Events' -and $install -match '\-Confirm \-Events$') 'read-only plans and confirmed writes have distinct command contracts'
    $rejected=$false
    try { New-PanelWorkerCommand 'Install' 'Install' @('git;malicious') } catch { $rejected=$true }
    Assert-PanelCase $rejected 'unrecognized IDs cannot enter an executable command'
    $script:PanelBackend="C:\中文 空格 O'Brien\配置.ps1"
    $quoted=New-PanelWorkerCommand 'Plan' 'Install' @('git')
    $tokens=$null; $errors=$null; [void][Management.Automation.Language.Parser]::ParseInput($quoted,[ref]$tokens,[ref]$errors)
    Assert-PanelCase ($errors.Count -eq 0 -and $quoted.Contains("O''Brien")) 'Chinese, spaces and apostrophes remain literal path data'
    Invoke-PanelProtocolTests
    if (-not ('Jobs.Setup.PanelWorker' -as [type])) { Add-Type -Path (Join-Path $root '【WindowsOS】🧰新系统配置管理.ps1/Resources/PanelWorker.cs') }
    $worker=New-Object Jobs.Setup.PanelWorker
    $exe=(Get-Process -Id $PID).Path
    $lines=New-Object 'System.Collections.Generic.List[string]'
    $timer=[Diagnostics.Stopwatch]::StartNew()
    try {
        $worker.Start($exe,"[Console]::OutputEncoding=New-Object Text.UTF8Encoding(`$false); [Console]::WriteLine('中文 head'); Start-Sleep -Milliseconds 250; [Console]::Error.WriteLine('tail diagnostic'); [Console]::WriteLine('last-output'); exit 7",[IO.Path]::GetTempPath())
        while (-not $worker.Finished -and $timer.Elapsed.TotalSeconds -lt 15) {
            while ($null -ne ($line=$worker.Take())) { $lines.Add($line) }
            Start-Sleep -Milliseconds 20
        }
        while ($null -ne ($line=$worker.Take())) { $lines.Add($line) }
        Assert-PanelCase $worker.Finished 'background worker finishes only after both output pipes drain'
        Assert-PanelCase ($worker.ExitCode -eq 7) 'real child exit code preserved'
        Assert-PanelCase ($lines.Contains('中文 head') -and $lines.Contains('tail diagnostic') -and $lines.Contains('last-output')) 'UTF-8 and both late output streams are retained'
    } finally { $worker.Dispose() }
    Write-Output ('Validated '+$script:Assertions+' isolated assertions; Windows GUI requires native acceptance.')
}
Main

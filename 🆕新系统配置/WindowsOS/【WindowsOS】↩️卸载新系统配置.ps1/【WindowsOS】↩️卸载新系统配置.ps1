#requires -Version 5.1
<#
【WindowsOS】↩️卸载新系统配置.ps1 | Jobs Windows 受管反安装快捷入口
Created by Jobs on 2026年11月17日，星期二.
转交同平台唯一实施脚本，保留其自述、显式组件、默认取消和收据检查。
#>
[CmdletBinding()]
param([string[]]$Components=@(), [switch]$Confirm, [string]$StateRoot='')
# 从本文件位置定位本平台受管实施脚本，不依赖启动工作目录。
function Main {
    $entry = Join-Path (Split-Path $PSScriptRoot -Parent) '【WindowsOS】🆕新系统配置.ps1/【WindowsOS】🆕新系统配置.ps1'
    if (-not (Test-Path -LiteralPath $entry -PathType Leaf)) { throw ('缺少本平台受管实施脚本：' + $entry) }
    & $entry -Mode Uninstall -Components $Components -Confirm:$Confirm -StateRoot $StateRoot # 复用唯一反安装流程与确认。
    return $LASTEXITCODE
}
try { $result=Main; exit $result }
catch { [Console]::Error.WriteLine('失败：' + $_.Exception.Message); exit 1 }

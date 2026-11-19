#requires -Version 5.1
<#
WindowsBootstrap.Tests.ps1 | Jobs Windows 新系统配置隔离回归
Created by Jobs on 2026年11月17日，星期二.
只运行临时目录夹具和函数替身，不调用真实 WinGet、注册表或安装器。
#>
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$source = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) '【WindowsOS】🆕新系统配置.ps1/【WindowsOS】🆕新系统配置.ps1'
. $source
$temporary = [IO.Path]::GetTempPath()
if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT -and (Test-Path -LiteralPath '/private/tmp')) { $temporary='/private/tmp' }
$script:TestRoot = Join-Path $temporary ('Jobs Windows 中文 回归 ' + [Guid]::NewGuid().ToString('N'))
$script:Assertions = 0
$script:MockPackages = @{}
$script:MockHealthy = @{}
$script:MockRecords = @{}
$script:MockCalls = New-Object 'System.Collections.Generic.List[string]'
$script:FailInstall = $false
$script:FailUndo = $false
$script:RealFingerprint = ${function:Get-ComponentFingerprint}
$script:RealMain = ${function:Main}
$script:RealInventory = ${function:Get-PackageInventory}
$script:RealHealth = ${function:Test-ComponentHealth}
$script:RealInvokeWinGet = ${function:Invoke-WinGet}
$script:ExportJson = '{}'
# 验证可见结果与副作用边界，失败时保留全部夹具。
function Assert-Case {
    param([bool]$Condition,[string]$Name)
    if (-not $Condition) { throw ('断言失败：' + $Name) }
    $script:Assertions++
    Write-Host ('PASS ' + $Name)
}
# 验证预期失败，而不是把异常当作成功或吞掉未知错误。
function Assert-Throws {
    param([scriptblock]$Action,[string]$Name)
    $failed = $false
    try { & $Action } catch { $failed = $true }
    Assert-Case $failed $Name
}
# 在本轮私有目录复位模拟包管理状态，不删除其它路径。
function Reset-Fixture {
    param([string]$Name)
    if ($script:LockStream) { $script:LockStream.Dispose(); $script:LockStream=$null }
    $script:WorkRoot = Join-Path $script:TestRoot $Name
    [void][IO.Directory]::CreateDirectory($script:WorkRoot)
    $script:LogFile = Join-Path $script:WorkRoot 'test.log'
    $script:MockPackages = @{}
    $script:MockHealthy = @{}
    $script:MockRecords = @{}
    $script:MockCalls.Clear()
    $script:FailInstall = $false
    $script:FailUndo = $false
}
# 返回完全隔离的包清单，替代 WinGet JSON 导出。
function Get-PackageInventory {
    return $script:MockPackages.Clone()
}
# 只读取内存健康标记，不执行机器上的真实开发工具。
function Test-ComponentHealth {
    param($Component)
    return ($script:MockHealthy.ContainsKey($Component.Id) -and $script:MockHealthy[$Component.Id])
}
# 返回模拟安装器新建的独立目录与注册信息。
function Get-ApplicationRecord {
    param($Component)
    if ($script:MockRecords.ContainsKey($Component.Id)) { return $script:MockRecords[$Component.Id] }
    return $null
}
# 模拟实际包操作，真实收据与完整目录指纹逻辑保持不变。
function Invoke-PackageWrite {
    param($Component,[string]$Action)
    $script:MockCalls.Add($Action + ':' + $Component.Id)
    if ($Action -eq 'install') {
        if ($script:FailInstall) { throw '模拟安装失败。' }
        $install = Join-Path $script:WorkRoot ($Component.Id + '-payload')
        [void][IO.Directory]::CreateDirectory($install)
        [IO.File]::WriteAllText((Join-Path $install 'tool.exe'),'模拟程序')
        $script:MockRecords[$Component.Id] = [ordered]@{ Key='mock'; Name=$Component.Name; Version='1.2.3'; Location=$install; Uninstall='mock-only' }
        $script:MockPackages[$Component.Package] = '1.2.3'
        $script:MockHealthy[$Component.Id] = $true
    } elseif ($Action -eq 'repair') {
        $script:MockHealthy[$Component.Id] = $true
    } elseif ($Action -eq 'uninstall') {
        if ($script:FailUndo) { throw '模拟反安装失败。' }
        $script:MockPackages.Remove($Component.Package)
        $script:MockHealthy[$Component.Id] = $false
    } else { throw ('未知模拟动作：' + $Action) }
}
# 测试流程不修改本机 PATH。
function Update-ProcessPath {}
# 模拟官方 export 文件协议，供真实清单解析器验证结构与失败边界。
function Invoke-WinGet {
    param([string[]]$Arguments)
    if ($Arguments[0] -ne 'export') { throw '此替身只允许 export。' }
    $index = [array]::IndexOf($Arguments,'--output')
    [IO.File]::WriteAllText($Arguments[$index+1], $script:ExportJson)
    return [pscustomobject]@{ Code=0; Text='' }
}
# 逐场覆盖默认只读、安装生命周期、并发及保守恢复。
function Main-Tests {
    [void][IO.Directory]::CreateDirectory($script:TestRoot)
    $git = $script:Catalog | Where-Object { $_.Id -eq 'git' }
    $node = $script:Catalog | Where-Object { $_.Id -eq 'node' }
    Reset-Fixture 'readonly'
    $script:Mode='Plan'; $script:Components=@('git,node'); $script:Operation='Install'
    Initialize-Selection
    $plan = @(Show-ReadOnlyResult)
    Assert-Case ($plan.Count -eq 2) '计划按逗号分隔组件并保持确定顺序'
    Assert-Case ($script:MockCalls.Count -eq 0) '计划不启动包操作'
    Assert-Case (@(Get-ChildItem -LiteralPath $script:WorkRoot -Force).Count -eq 0) '计划不创建日志锁或收据'
    $script:Mode='Install'; $script:Components=@()
    Assert-Throws { Initialize-Selection } '写模式空组件拒绝'
    $script:Components=@('unknown')
    Assert-Throws { Initialize-Selection } '未知组件拒绝'
    Reset-Fixture 'install'
    Install-Component $git
    $receipt=Read-Receipt $git
    Assert-Case ($receipt.Status -eq 'Installed' -and $receipt.Version -eq '1.2.3') '新增组件建立版本与完整目录指纹收据'
    Assert-Case ($receipt.Fingerprint.Length -eq 64) '安装后指纹是SHA256'
    Install-Component $git
    Assert-Case ($script:MockCalls.Count -eq 1) '重复安装复用健康组件'
    Uninstall-Component $git
    Assert-Case (-not $script:MockPackages.ContainsKey($git.Package)) '归属清晰且未变组件可卸载'
    Assert-Case ((Read-Receipt $git).Status -eq 'Removed') '卸载成功更新收据'
    Uninstall-Component $git
    Assert-Case ($script:MockCalls.Count -eq 2) '重复反安装不重放卸载器'
    Reset-Fixture 'existing'
    $script:MockHealthy[$git.Id]=$true; $script:MockPackages[$git.Package]='old'
    Install-Component $git
    Assert-Case ($script:MockCalls.Count -eq 0 -and $null -eq (Read-Receipt $git)) '原有健康组件不升级不认领'
    Assert-Throws { Uninstall-Component $git } '没有收据时保留原有组件'
    Reset-Fixture 'repair'
    $script:MockHealthy[$git.Id]=$false; $script:MockPackages[$git.Package]='old'
    Install-Component $git
    Assert-Case ($script:MockCalls[0] -eq 'repair:git' -and $null -eq (Read-Receipt $git)) '原有损坏组件定向修复但不取得卸载归属'
    Reset-Fixture 'failure'
    $script:FailInstall=$true
    Assert-Throws { Install-Component $git } '安装失败正确传播'
    Assert-Case ((Read-Receipt $git).Status -eq 'Pending') '失败保留待完成收据'
    $script:FailInstall=$false
    Assert-Throws { Install-Component $git } '未完成收据不被重试自动认领'
    Assert-Throws { Uninstall-Component $git } '未完成收据不执行卸载'
    Reset-Fixture 'changed-file'
    Install-Component $git
    [IO.File]::WriteAllText((Join-Path $script:MockRecords[$git.Id].Location 'tool.exe'),'用户修改')
    Assert-Throws { Uninstall-Component $git } '安装文件被改后保留'
    Assert-Case ($script:MockCalls.Count -eq 1) '指纹不符没有调用卸载器'
    Reset-Fixture 'changed-version'
    Install-Component $git
    $script:MockPackages[$git.Package]='2.0.0'
    Assert-Throws { Uninstall-Component $git } '版本被升级后保留'
    Reset-Fixture 'extra-file'
    Install-Component $git
    [IO.File]::WriteAllText((Join-Path $script:MockRecords[$git.Id].Location 'user.txt'),'用户新增')
    Assert-Throws { Uninstall-Component $git } '安装目录新增用户文件后保留'
    Reset-Fixture 'extra-directory'
    Install-Component $git
    [void][IO.Directory]::CreateDirectory((Join-Path $script:MockRecords[$git.Id].Location 'empty-user-directory'))
    Assert-Throws { Uninstall-Component $git } '安装目录新增空目录后保留'
    Reset-Fixture 'manual-undo'
    Install-Component $git
    $receipt=Read-Receipt $git; $receipt.Status='InstalledManualUndo'; $receipt.Fingerprint=''; Save-Receipt $git $receipt
    Assert-Throws { Uninstall-Component $git } '无法建立独立目录指纹时不自动卸载'
    Reset-Fixture 'failed-undo'
    Install-Component $git; $script:FailUndo=$true
    Assert-Throws { Uninstall-Component $git } '卸载器失败传播'
    Assert-Case ((Read-Receipt $git).Status -eq 'Installed') '卸载失败保留有效收据供重试'
    Reset-Fixture 'missing-after'
    Install-Component $git; $script:MockPackages.Remove($git.Package)
    Uninstall-Component $git
    Assert-Case ((Read-Receipt $git).Status -eq 'Removed' -and $script:MockCalls.Count -eq 1) '外部已卸载时不重复启动卸载器'
    Reset-Fixture 'identity'
    Install-Component $git
    $receipt=Read-Receipt $git; $receipt.Package='Other.Package'; Save-Receipt $git $receipt
    Assert-Throws { Uninstall-Component $git } '收据包身份不匹配拒绝'
    Reset-Fixture 'lock'
    $path=Join-Path $script:WorkRoot 'operation.lock'
    $first=[IO.File]::Open($path,[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
    try { Assert-Throws { $second=[IO.File]::Open($path,[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None); $second.Dispose() } '并发写锁拒绝第二个运行' }
    finally { $first.Dispose() }
    Reset-Fixture 'inventory-json'
    foreach ($json in @('{}','{"Sources":null}','{"Sources":[{}]}','{"Sources":[{"Packages":[{}]}]}','{"Sources":[{"Packages":[{"PackageIdentifier":""}]}]}','{"Sources":[{"Packages":[{"PackageIdentifier":"Git.Git","Version":"1"},{"PackageIdentifier":"Git.Git","Version":"2"}]}]}')) {
        $script:ExportJson=$json
        Assert-Throws { & $script:RealInventory } ('拒绝损坏导出结构：' + $json)
    }
    $script:ExportJson='{"Sources":[]}'
    $inventory=& $script:RealInventory
    Assert-Case ($inventory.Count -eq 0) '合法空Sources返回空清单'
    $script:ExportJson='{"Sources":[{"Packages":[{"PackageIdentifier":"Git.Git","Version":"1.2.3"}]}]}'
    $inventory=& $script:RealInventory
    Assert-Case ($inventory['Git.Git'] -eq '1.2.3') '官方JSON字段精确解析包身份与版本'
    $script:ExportJson='{"Sources":[{"Packages":[{"PackageIdentifier":"Git.Git"}]}]}'
    $inventory=& $script:RealInventory
    Assert-Case ($inventory.ContainsKey('Git.Git') -and $inventory['Git.Git'] -eq '') '未知版本仍算既有包而非缺失'
    Assert-Case (@(Get-ChildItem -LiteralPath $script:WorkRoot -Filter 'inventory-*.json').Count -eq 0) 'JSON成功失败都清理本轮导出临时文件'
    Reset-Fixture 'cancel'
    $script:Mode='Install'; $script:Components=@('git'); $script:Confirm=$false
    function Confirm-ScriptAction { return $false }
    function Assert-WindowsHost { throw '取消后不应检查主机或准备写入。' }
    & $script:RealMain
    Assert-Case (@(Get-ChildItem -LiteralPath $script:WorkRoot -Force).Count -eq 0 -and $script:MockCalls.Count -eq 0) '取消发生在日志锁收据及包管理器前'
    Reset-Fixture 'real-health'
    $script:HealthNode=Join-Path $script:WorkRoot 'node-health.ps1'
    $script:HealthNpm=Join-Path $script:WorkRoot 'npm-health.ps1'
    [IO.File]::WriteAllText($script:HealthNode,"Write-Output 'v24.0.0'; exit 0")
    $script:NpmAvailable=$false
    function Get-Command {
        param([string]$Name,$CommandType,$ErrorAction)
        if ($Name -eq 'node.exe') { return [pscustomobject]@{ Source=$script:HealthNode } }
        if ($Name -eq 'npm.cmd' -and $script:NpmAvailable) { return [pscustomobject]@{ Source=$script:HealthNpm } }
        return $null
    }
    Assert-Case (-not (& $script:RealHealth $node)) '真实健康函数不把Node单独可用视作npm就绪'
    $script:NpmAvailable=$true
    [IO.File]::WriteAllText($script:HealthNpm,"Write-Output 'damaged npm'; exit 2")
    Assert-Case (-not (& $script:RealHealth $node)) '真实健康函数拒绝损坏npm'
    [IO.File]::WriteAllText($script:HealthNpm,"Write-Output '11.0.0'; exit 0")
    Assert-Case ([bool](& $script:RealHealth $node)) '真实健康函数同时验证Node与npm执行结果'
    $script:WinGet=Join-Path $script:WorkRoot 'winget-output.ps1'
    [IO.File]::WriteAllText($script:WinGet,"Write-Output 'first-output'; Write-Output 'last-output'; exit 3")
    $result=& $script:RealInvokeWinGet @('--version')
    Assert-Case ($result.Code -eq 3 -and $result.Text -match 'first-output' -and $result.Text -match 'last-output') '真实WinGet包装保留退出码与完整输出'
    $text=[IO.File]::ReadAllText($script:LogFile)
    Assert-Case ($text -match 'first-output' -and $text -match 'last-output') '真实WinGet包装逐行写入纯文本日志'
    Write-Host ('验证通过：' + $script:Assertions + ' 项断言；夹具：' + $script:TestRoot)
}
Main-Tests

#requires -Version 5.1
<#
【WindowsOS】🧰新系统配置管理.ps1 | Jobs 新系统配置原生管理面板
Created by Jobs on 2026年11月17日，星期二.
用途：选择、预览并后台调用同平台受管安装／卸载后端。
默认：空选与静态清单；启动不调用 WinGet，不安装或卸载任何组件。
影响：执行按钮是当前选择的最终确认，接受对应包及 WinGet 源许可，可能请求 UAC。
依赖：Windows PowerShell 5.1 / WinForms；WinGet 只在写操作时检查。
#>
[CmdletBinding()]
param([switch]$Check)
# 解析同平台资源位置；不依赖启动工作目录。
function Initialize-PanelPaths {
    $script:ErrorActionPreference='Stop'
    $script:PanelRoot = $PSScriptRoot
    $script:PanelBackend = Join-Path (Split-Path $PSScriptRoot -Parent) '【WindowsOS】🆕新系统配置.ps1/【WindowsOS】🆕新系统配置.ps1'
    $script:PanelTranslations = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'Resources/PanelTranslations.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    if (-not (Test-Path -LiteralPath $script:PanelBackend -PathType Leaf)) { throw ('Missing backend: ' + $script:PanelBackend) }
    $script:PanelCatalog = @(& { param($Backend) . $Backend; $script:Catalog } $script:PanelBackend)
    if ($script:PanelCatalog.Count -eq 0) { throw 'Empty backend catalog.' }
}
# 返回用户偏好对应语言，系统语言只做受支持范围内的映射。
function Get-PanelLanguage {
    if ($script:PanelLanguage -ne 'system') { return $script:PanelLanguage }
    $name = [Globalization.CultureInfo]::CurrentUICulture.Name
    if ($name -match '^zh-(TW|HK|MO|Hant)') { return 'zh-Hant' }
    if ($name -match '^zh') { return 'zh-Hans' }
    $short = $name.Split('-')[0]
    if ($short -in @('bo','ja','fr','es','de','ru','ko')) { return $short }
    return 'en'
}
# 界面字符串集中翻译；原始包名、路径及后端诊断不做机械翻译。
function Get-PanelText {
    param([string]$Key)
    $language = Get-PanelLanguage
    $entry = $script:PanelTranslations.$language.PSObject.Properties[$Key]
    if ($entry) { return [string]$entry.Value }
    return $Key
}
# 只返回封闭的后端命令，不用命令行字符串拼接组件或路径。
function New-PanelWorkerCommand {
    param([string]$Mode,[string]$Operation,[string[]]$Ids)
    if ($Mode -notin @('Plan','Install','Uninstall')) { throw 'Invalid mode.' }
    if ($Operation -notin @('Install','Uninstall')) { throw 'Invalid operation.' }
    if ($Ids.Count -eq 0) { throw 'No components selected.' }
    foreach ($id in $Ids) {
        if (@($script:PanelCatalog | Where-Object { $_.Id -ceq $id }).Count -ne 1) { throw ('Unknown component: ' + $id) }
    }
    $pathLiteral = "'" + $script:PanelBackend.Replace("'", "''") + "'"
    $idLiteral = "'" + ($Ids -join ',').Replace("'", "''") + "'"
    $command = '[Console]::OutputEncoding = New-Object Text.UTF8Encoding($false); $OutputEncoding = [Console]::OutputEncoding; & ' + $pathLiteral + ' -Mode ' + $Mode + ' -Operation ' + $Operation + ' -Components ' + $idLiteral
    if ($Mode -ne 'Plan') { $command += ' -Confirm -Events' }
    return $command
}
# 拒绝重解析点，偏好和日志不能穿过联接目录写入其它位置。
function Assert-PanelPlainPath {
    param([string]$Path)
    $cursor = [IO.Path]::GetFullPath($Path)
    while ($cursor) {
        if (Test-Path -LiteralPath $cursor) {
            if (((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw ('Unsafe linked path: ' + $cursor) }
        }
        $parent = [IO.Path]::GetDirectoryName($cursor)
        if ($parent -eq $cursor) { break }
        $cursor = $parent
    }
}
# 读取当前用户的语言和主题；不存在时不创建文件。
function Initialize-PanelPreferences {
    $script:PanelTheme = 'system'
    $script:PanelLanguage = 'system'
    $script:PanelStateRoot = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'JobsSystemBootstrap/WindowsOS'
    $script:PanelPreferenceFile = Join-Path $script:PanelStateRoot 'panel-settings.json'
    Assert-PanelPlainPath $script:PanelPreferenceFile
    if (Test-Path -LiteralPath $script:PanelPreferenceFile -PathType Leaf) {
        try {
            $pref = Get-Content -LiteralPath $script:PanelPreferenceFile -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($pref.Theme -in @('system','light','dark')) { $script:PanelTheme = $pref.Theme }
            if ($pref.Language -in @('system','en','zh-Hans','zh-Hant','bo','ja','fr','es','de','ru','ko')) { $script:PanelLanguage = $pref.Language }
        } catch { [Console]::Error.WriteLine('Could not read panel preferences: ' + $_.Exception.Message) }
    }
}
# 用户主动改变外观时才持久化，不保存组件选择或自动退出偏好。
function Save-PanelPreferences {
    try {
        Assert-PanelPlainPath $script:PanelPreferenceFile
        [void][IO.Directory]::CreateDirectory($script:PanelStateRoot)
        $data = @{ Theme=$script:PanelTheme; Language=$script:PanelLanguage } | ConvertTo-Json
        [IO.File]::WriteAllText($script:PanelPreferenceFile,$data,(New-Object Text.UTF8Encoding($false)))
    } catch { Add-PanelLog $_.Exception.Message 'error' }
}
# 原生辅助控件保护整行按下／抬起、滚动语义和后台进程输出排空。
function Initialize-PanelNativeTypes {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    if ('Jobs.Setup.PanelWorker' -as [type]) { return }
    Add-Type -Path (Join-Path $script:PanelRoot 'Resources/PanelWorker.cs')
    Add-Type -ReferencedAssemblies System.Windows.Forms,System.Drawing -TypeDefinition @'
using System;
using System.Collections.Concurrent;
using System.Diagnostics;
using System.Drawing;
using System.Text;
using System.Threading;
using System.Windows.Forms;
using System.Runtime.InteropServices;
namespace Jobs.Setup {
    public sealed class SelectionGrid : DataGridView {
        int pending = -1; Point origin;
        public bool Busy;
        void Toggle(int row) { if (!Busy && row >= 0 && row < Rows.Count) Rows[row].Cells[0].Value = !(bool)Rows[row].Cells[0].Value; }
        protected override void OnMouseDown(MouseEventArgs e) {
            HitTestInfo hit = HitTest(e.X,e.Y);
            pending = e.Button == MouseButtons.Left && !Busy ? hit.RowIndex : -1;
            origin = e.Location;
            if (pending >= 0) { CurrentCell = Rows[pending].Cells[0]; return; }
            base.OnMouseDown(e);
        }
        protected override void OnMouseMove(MouseEventArgs e) {
            if (pending >= 0 && (Math.Abs(e.X-origin.X) > SystemInformation.DragSize.Width/2 || Math.Abs(e.Y-origin.Y) > SystemInformation.DragSize.Height/2)) pending=-1;
            base.OnMouseMove(e);
        }
        protected override void OnMouseUp(MouseEventArgs e) {
            int row = pending; pending=-1;
            if (row >= 0) { if (e.Button == MouseButtons.Left && HitTest(e.X,e.Y).RowIndex == row && !Busy) Toggle(row); return; }
            base.OnMouseUp(e);
        }
        protected override void OnMouseWheel(MouseEventArgs e) { pending=-1; base.OnMouseWheel(e); }
        protected override void OnMouseLeave(EventArgs e) { pending=-1; base.OnMouseLeave(e); }
        protected override void OnKeyDown(KeyEventArgs e) { if (e.KeyCode == Keys.Space && CurrentCell != null) { Toggle(CurrentCell.RowIndex); e.Handled=true; return; } base.OnKeyDown(e); }
    }
    public sealed class PanelLog : RichTextBox {
        public bool AutoFollow=true;
        public event EventHandler ManualScroll;
        const int GetScroll=0x4DD, SetScroll=0x4DE;
        [DllImport("user32.dll")] static extern IntPtr SendMessage(IntPtr h,int m,IntPtr w,ref Point p);
        public Point Position() { Point p = new Point(); SendMessage(Handle,GetScroll,IntPtr.Zero,ref p); return p; }
        public void Restore(Point p) { SendMessage(Handle,SetScroll,IntPtr.Zero,ref p); }
        protected override void WndProc(ref Message m) {
            if (m.Msg == 0x20A || m.Msg == 0x20E || m.Msg == 0x115 || m.Msg == 0x114 || (m.Msg == 0x100 && ((int)m.WParam == 33 || (int)m.WParam == 34 || (int)m.WParam == 35 || (int)m.WParam == 36 || (int)m.WParam == 38 || (int)m.WParam == 40))) {
                AutoFollow=false; if (ManualScroll != null) ManualScroll(this,EventArgs.Empty);
            }
            base.WndProc(ref m);
        }
    }
}
'@
}
# 跟随系统时每秒读取用户外观，不订阅跨线程 PowerShell 回调。
function Get-PanelDark {
    if ($script:PanelTheme -eq 'dark') { return $true }
    if ($script:PanelTheme -eq 'light') { return $false }
    if ([Windows.Forms.SystemInformation]::HighContrast) { return [Drawing.SystemColors]::Window.GetBrightness() -lt 0.5 }
    $settings = Get-ItemProperty 'HKCU:/Software/Microsoft/Windows/CurrentVersion/Themes/Personalize' -ErrorAction SilentlyContinue
    return ($settings -and $settings.AppsUseLightTheme -eq 0)
}
# 根据当前主题统一设置所有控件及日志，保留已有日志选择和浏览位置。
function Set-PanelTheme {
    $script:PanelDark = Get-PanelDark
    if ($script:PanelDark) { $bg='#202124'; $fg='#F1F3F4'; $surface='#292B2F'; $select='#374C69'; $script:PanelColors=@{ plain='#F1F3F4'; info='#A7D4FF'; success='#91D9A3'; warning='#FFD985'; error='#FFB4AB' } }
    else { $bg='#F5F6F8'; $fg='#17212B'; $surface='#FFFFFF'; $select='#CDE1FA'; $script:PanelColors=@{ plain='#17212B'; info='#164B7A'; success='#175B2B'; warning='#6B4700'; error='#A01816' } }
    $convert = [Drawing.ColorTranslator]
    $stack = New-Object 'System.Collections.Generic.Stack[System.Windows.Forms.Control]'
    $stack.Push($script:PanelForm)
    while ($stack.Count) {
        $control=$stack.Pop(); $control.BackColor=$convert::FromHtml($bg); $control.ForeColor=$convert::FromHtml($fg)
        if ($control -is [Windows.Forms.TextBoxBase] -or $control -is [Windows.Forms.ComboBox]) { $control.BackColor=$convert::FromHtml($surface) }
        if ($control -is [Windows.Forms.Button]) { $control.FlatStyle='Flat' }
        foreach ($child in $control.Controls) { $stack.Push($child) }
    }
    $grid=$script:PanelGrid
    $grid.BackgroundColor=$convert::FromHtml($surface)
    $grid.DefaultCellStyle.BackColor=$convert::FromHtml($surface); $grid.DefaultCellStyle.ForeColor=$convert::FromHtml($fg)
    $grid.DefaultCellStyle.SelectionBackColor=$convert::FromHtml($select); $grid.DefaultCellStyle.SelectionForeColor=$convert::FromHtml($fg)
    $grid.ColumnHeadersDefaultCellStyle.BackColor=$convert::FromHtml($bg); $grid.ColumnHeadersDefaultCellStyle.ForeColor=$convert::FromHtml($fg)
    $grid.EnableHeadersVisualStyles=$false; $grid.GridColor=$convert::FromHtml($bg)
    $script:PanelLog.BackColor=$convert::FromHtml($surface)
    $script:PanelTrayMenu.BackColor=$convert::FromHtml($bg); $script:PanelTrayMenu.ForeColor=$convert::FromHtml($fg)
    foreach ($item in $script:PanelTrayMenu.Items) { $item.BackColor=$convert::FromHtml($bg); $item.ForeColor=$convert::FromHtml($fg) }
    Redraw-PanelLog
}
# 日志显示有上限，完整会话日志独立落盘；stderr 本身不作为失败依据。
function Add-PanelLog {
    param([string]$Text,[string]$Kind='plain')
    $plain=[regex]::Replace($Text,"\x1B\[[0-?]*[ -/]*[@-~]",'')
    if ($script:PanelLogFile) {
        try { [IO.File]::AppendAllText($script:PanelLogFile,$plain+[Environment]::NewLine,(New-Object Text.UTF8Encoding($false))) }
        catch { $script:PanelLogFile=$null; $plain += "`n"+(Get-PanelText 'Log file write failed. Visible output remains available to copy.') }
    }
    if ($plain.Length -gt 100000) { $plain=$plain.Substring($plain.Length-100000) }
    $script:PanelSegments.Add([pscustomobject]@{ Text=$plain; Kind=$Kind })
    $script:PanelLogCharacters += $plain.Length+2
    $trimmed=$false
    while ($script:PanelLogCharacters -gt 300000 -and $script:PanelSegments.Count -gt 1) {
        $script:PanelLogCharacters -= $script:PanelSegments[0].Text.Length+2
        $script:PanelSegments.RemoveAt(0); $trimmed=$true
    }
    if ($trimmed) { Redraw-PanelLog; return }
    $log=$script:PanelLog; $position=$log.Position(); $start=$log.SelectionStart; $length=$log.SelectionLength
    $log.Select($log.TextLength,0); $log.SelectionColor=[Drawing.ColorTranslator]::FromHtml($script:PanelColors[$Kind]); $log.AppendText($plain+[Environment]::NewLine)
    if ($log.AutoFollow) { $log.Select($log.TextLength,0); $log.ScrollToCaret() }
    else { $log.Select($start,$length); $log.Restore($position) }
}
# 主题切换重画已有日志的语义色，文件原文保持不变。
function Redraw-PanelLog {
    $log=$script:PanelLog; $position=$log.Position(); $start=$log.SelectionStart; $length=$log.SelectionLength
    $log.Clear()
    foreach ($segment in $script:PanelSegments) { $log.SelectionColor=[Drawing.ColorTranslator]::FromHtml($script:PanelColors[$segment.Kind]); $log.AppendText($segment.Text+[Environment]::NewLine) }
    if ($log.AutoFollow) { $log.Select($log.TextLength,0); $log.ScrollToCaret() }
    else { $log.Select([Math]::Min($start,$log.TextLength),[Math]::Min($length,[Math]::Max(0,$log.TextLength-$start))); $log.Restore($position) }
}
# 搜索只影响显示，稳定 ID 保留同会话选择与执行状态。
function Update-PanelRows {
    $query=$script:PanelSearch.Text.Trim()
    $script:PanelGrid.Rows.Clear()
    foreach ($component in $script:PanelCatalog) {
        if ($query -and ($component.Id+' '+$component.Name+' '+$component.Package).IndexOf($query,[StringComparison]::OrdinalIgnoreCase) -lt 0) { continue }
        $index=$script:PanelGrid.Rows.Add([bool]$script:PanelSelected.ContainsKey($component.Id),$component.Name,$component.Package,(Get-PanelText $script:PanelStatuses[$component.Id]))
        $script:PanelGrid.Rows[$index].Tag=$component.Id
    }
    $script:PanelEmpty.Visible=($script:PanelGrid.Rows.Count -eq 0)
    Update-PanelAvailability
}
# 选择计数和忙态按实际状态刷新，空选不能预览或执行。
function Update-PanelAvailability {
    $busy=$null -ne $script:PanelWorker
    $script:PanelGrid.Busy=$busy
    foreach ($control in @($script:PanelSearch,$script:PanelSelect,$script:PanelClear,$script:PanelReload,$script:PanelOperation)) { $control.Enabled=-not $busy }
    $script:PanelPreview.Enabled=(-not $busy -and $script:PanelSelected.Count -gt 0)
    $script:PanelExecute.Enabled=$script:PanelPreview.Enabled
    $script:PanelExecute.Text=Get-PanelText $(if ($script:PanelOperation.SelectedIndex -eq 1) { 'Uninstall selected' } else { 'Install selected' })
    $script:PanelCount.Text=(Get-PanelText 'Selected {0} / {1}; visible {2}') -f $script:PanelSelected.Count,$script:PanelCatalog.Count,$script:PanelGrid.Rows.Count
    $script:PanelTrayExit.Enabled=-not $busy
}
# 将语言设置应用到主窗、托盘与所有动态状态，保留选择和后台任务。
function Set-PanelLanguage {
    if ($script:PanelUpdatingLanguage) { return }
    $script:PanelUpdatingLanguage=$true
    try {
    $script:PanelForm.Text='Jobs · '+(Get-PanelText 'System Setup Manager')+' · WindowsOS'
    foreach ($pair in $script:PanelLabels) { $pair.Control.Text=Get-PanelText $pair.Key; $pair.Control.AccessibleName=$pair.Control.Text }
    $script:PanelThemeLabel.Text=Get-PanelText 'Theme'; $script:PanelLanguageLabel.Text=Get-PanelText 'Language'
    $script:PanelThemeBox.Items[0]=Get-PanelText 'Follow system'; $script:PanelThemeBox.Items[1]=Get-PanelText 'Light'; $script:PanelThemeBox.Items[2]=Get-PanelText 'Dark'
    $script:PanelLanguageBox.Items[0]=Get-PanelText 'Follow system'
    $operation=$script:PanelOperation.SelectedIndex
    $script:PanelOperation.Items[0]=Get-PanelText 'Install'; $script:PanelOperation.Items[1]=Get-PanelText 'Uninstall'; $script:PanelOperation.SelectedIndex=$operation
    $script:PanelGrid.Columns[0].HeaderText=Get-PanelText 'Select all'
    $script:PanelGrid.Columns[1].HeaderText=Get-PanelText 'Component'; $script:PanelGrid.Columns[3].HeaderText=Get-PanelText 'Status'
    $script:PanelTrayShow.Text=Get-PanelText 'Show management panel'; $script:PanelTrayExit.Text=Get-PanelText 'Quit completely'
    $script:PanelCopy.AccessibleDescription=Get-PanelText 'Copy visible log; open the log file for complete output.'
    Update-PanelRows
    } finally { $script:PanelUpdatingLanguage=$false }
}
# 只有封闭事件协议可以改变逐项最终状态，普通日志不能伪造成功。
function Receive-PanelLine {
    param([string]$Line)
    if ($Line.StartsWith('@@JOBS_EVENT@@',[StringComparison]::Ordinal)) {
        $event=$Line.Substring(14) | ConvertFrom-Json -ErrorAction Stop
        if ($event.schema -ne 1 -or -not $script:PanelRunIds.ContainsKey([string]$event.id) -or $event.operation -cne $script:PanelRunOperation) { throw 'Invalid component event identity.' }
        $keys=@{ running=$(if ($script:PanelRunOperation -eq 'Install') { 'Installing…' } else { 'Uninstalling…' }); completed='Completed'; reused='Reused existing tool'; skipped='Nothing to uninstall'; failed='Failed: see log' }
        if (-not $keys.ContainsKey([string]$event.state)) { throw 'Invalid component event state.' }
        $script:PanelStatuses[[string]$event.id]=$keys[[string]$event.state]
        $script:PanelRunResults[[string]$event.id]=[string]$event.state
        $kind='info'
        if ($event.state -in @('completed','reused')) { $kind='success' }
        elseif ($event.state -eq 'failed') { $kind='error' }
        elseif ($event.state -eq 'skipped') { $kind='warning' }
        Add-PanelLog ($event.id+': '+(Get-PanelText $keys[[string]$event.state])) $kind
        Update-PanelRows
        $done=@($script:PanelRunResults.Values | Where-Object { $_ -ne 'running' }).Count
        $script:PanelProgress.Value=[Math]::Min(100,[int](100*$done/$script:PanelRunIds.Count))
    } else { Add-PanelLog $Line }
}
# 编码后启动现有 CLI；只读计划不传写授权，执行按钮本身即最终确认。
function Start-PanelOperation {
    param([bool]$Preview)
    if ($script:PanelWorker -or $script:PanelSelected.Count -eq 0) { return }
    $operation=$(if ($script:PanelOperation.SelectedIndex -eq 1) { 'Uninstall' } else { 'Install' })
    $mode=$(if ($Preview) { 'Plan' } else { $operation })
    $ids=@($script:PanelCatalog | Where-Object { $script:PanelSelected.ContainsKey($_.Id) } | ForEach-Object { $_.Id })
    try {
        $command=New-PanelWorkerCommand $mode $operation $ids
        Assert-PanelPlainPath $script:PanelStateRoot
        [void][IO.Directory]::CreateDirectory($script:PanelStateRoot)
        $script:PanelLogFile=Join-Path $script:PanelStateRoot ('panel-'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'-'+[Guid]::NewGuid().ToString('N')+'.log')
        [IO.File]::WriteAllText($script:PanelLogFile,'',(New-Object Text.UTF8Encoding($false)))
        $script:PanelRunIds=@{}; $script:PanelRunResults=@{}; $script:PanelRunOperation=$operation; $script:PanelRunPreview=$Preview; $script:PanelProtocolFailed=$false
        foreach ($id in $ids) { $script:PanelRunIds[$id]=$true; if (-not $Preview) { $script:PanelStatuses[$id]='Waiting' } }
        $script:PanelRunWatch=[Diagnostics.Stopwatch]::StartNew()
        if (-not $Preview) { $script:PanelDurations[$operation]=[TimeSpan]::Zero }
        $script:PanelProgress.Value=0
        $worker=New-Object Jobs.Setup.PanelWorker
        $executable=Join-Path $PSHOME 'powershell.exe'
        if (-not (Test-Path -LiteralPath $executable -PathType Leaf)) { $executable=Join-Path $PSHOME 'pwsh.exe' }
        $worker.Start($executable,$command,(Split-Path $script:PanelBackend -Parent))
        $script:PanelWorker=$worker
        $script:PanelStatusKey=$(if ($Preview) { 'Previewing plan…' } elseif ($operation -eq 'Install') { 'Installing…' } else { 'Uninstalling…' })
        Update-PanelRows
    } catch { if ($worker -and -not $script:PanelWorker) { $worker.Dispose() }; Add-PanelLog $_.Exception.Message 'error'; $script:PanelStatusKey='Task failed' }
    Update-PanelAvailability
}
# 安全退出只在真正空闲时放行；隐藏窗口不会结束消息循环或释放 worker。
function Request-PanelClose {
    if ($script:PanelWorker) { $script:PanelForm.Hide(); return }
    if ($script:PanelCloseDialog) { return }
    $dialog=New-Object Windows.Forms.Form
    $script:PanelCloseDialog=$dialog
    $dialog.Text=Get-PanelText 'Close Manager'; $dialog.Size=New-Object Drawing.Size(620,200); $dialog.StartPosition='CenterParent'; $dialog.FormBorderStyle='FixedDialog'; $dialog.MaximizeBox=$false; $dialog.MinimizeBox=$false
    $layout=New-Object Windows.Forms.FlowLayoutPanel; $layout.Dock='Fill'; $layout.Padding=New-Object Windows.Forms.Padding(16); $layout.WrapContents=$true
    $label=New-Object Windows.Forms.Label; $label.AutoSize=$true; $label.MaximumSize=New-Object Drawing.Size(570,0); $label.Text=Get-PanelText 'Keep the manager in the menu bar or quit completely?'; $layout.Controls.Add($label)
    $background=New-Object Windows.Forms.Button; $background.AutoSize=$true; $background.Text=Get-PanelText 'Background'; $background.DialogResult='Yes'; $layout.Controls.Add($background)
    $quit=New-Object Windows.Forms.Button; $quit.AutoSize=$true; $quit.Text=Get-PanelText 'Quit completely'; $quit.DialogResult='No'; $layout.Controls.Add($quit)
    $cancel=New-Object Windows.Forms.Button; $cancel.AutoSize=$true; $cancel.Text=Get-PanelText 'Cancel'; $cancel.DialogResult='Cancel'; $layout.Controls.Add($cancel)
    $dialog.Controls.Add($layout); $dialog.AcceptButton=$background; $dialog.CancelButton=$cancel
    $dialog.BackColor=$script:PanelForm.BackColor; $dialog.ForeColor=$script:PanelForm.ForeColor
    $layout.BackColor=$dialog.BackColor; $layout.ForeColor=$dialog.ForeColor
    foreach ($control in $layout.Controls) { $control.BackColor=$dialog.BackColor; $control.ForeColor=$dialog.ForeColor; if ($control -is [Windows.Forms.Button]) { $control.FlatStyle='Flat' } }
    try {
        $result=$dialog.ShowDialog($script:PanelForm)
        if ($result -eq 'Yes' -or $script:PanelWorker) { $script:PanelForm.Hide() }
        elseif ($result -eq 'No') { $script:PanelCanExit=$true; $script:PanelForm.Close() }
    } finally { $dialog.Dispose(); $script:PanelCloseDialog=$null }
}
# 构造自适应原生窗体、稳定选择表格和独立滚动日志。
function New-PanelWindow {
    $script:PanelWorker=$null; $script:PanelCanExit=$false; $script:PanelLogFile=$null; $script:PanelLogCharacters=0
    $script:PanelSegments=New-Object 'System.Collections.Generic.List[object]'
    $script:PanelSelected=@{}; $script:PanelStatuses=@{}; $script:PanelDurations=@{ Install=[TimeSpan]::Zero; Uninstall=[TimeSpan]::Zero }; $script:PanelStatusKey='Ready. Select features and choose an action.'
    foreach ($item in $script:PanelCatalog) { $script:PanelStatuses[$item.Id]='Ownership unknown' }
    $script:PanelForm=New-Object Windows.Forms.Form
    $form=$script:PanelForm; $form.Size=New-Object Drawing.Size(1100,850); $form.MinimumSize=New-Object Drawing.Size(860,650); $form.StartPosition='CenterScreen'; $form.Font=New-Object Drawing.Font('Segoe UI',10)
    $outer=New-Object Windows.Forms.TableLayoutPanel; $outer.Dock='Fill'; $outer.Padding=New-Object Windows.Forms.Padding(16); $outer.ColumnCount=1; $outer.RowCount=6
    foreach ($height in @(0,0,0,100,0,0)) { $style=New-Object Windows.Forms.RowStyle; $style.SizeType=$(if ($height -eq 100) { 'Percent' } else { 'AutoSize' }); $style.Height=$height; [void]$outer.RowStyles.Add($style) }
    $form.Controls.Add($outer)
    $script:PanelLabels=New-Object 'System.Collections.Generic.List[object]'
    $intro=New-Object Windows.Forms.Label; $intro.AutoSize=$true; $intro.MaximumSize=New-Object Drawing.Size(1500,0); $intro.Margin=New-Object Windows.Forms.Padding(3,3,3,10); $outer.Controls.Add($intro,0,0)
    $script:PanelIntro=$intro
    $script:PanelLabels.Add(@{ Control=$intro; Key='Static catalog; package health and ownership are checked only when executing.' })
    $preferences=New-Object Windows.Forms.FlowLayoutPanel; $preferences.AutoSize=$true; $preferences.Dock='Fill'; $outer.Controls.Add($preferences,0,1)
    $script:PanelThemeLabel=New-Object Windows.Forms.Label; $script:PanelThemeLabel.AutoSize=$true; $script:PanelThemeLabel.Padding=New-Object Windows.Forms.Padding(0,6,0,0); $preferences.Controls.Add($script:PanelThemeLabel)
    $script:PanelThemeBox=New-Object Windows.Forms.ComboBox; $script:PanelThemeBox.DropDownStyle='DropDownList'; $script:PanelThemeBox.Width=180; [void]$script:PanelThemeBox.Items.AddRange(@('system','light','dark')); $script:PanelThemeBox.SelectedIndex=@('system','light','dark').IndexOf($script:PanelTheme); $preferences.Controls.Add($script:PanelThemeBox)
    $script:PanelLanguageLabel=New-Object Windows.Forms.Label; $script:PanelLanguageLabel.AutoSize=$true; $script:PanelLanguageLabel.Padding=New-Object Windows.Forms.Padding(12,6,0,0); $preferences.Controls.Add($script:PanelLanguageLabel)
    $script:PanelLanguageBox=New-Object Windows.Forms.ComboBox; $script:PanelLanguageBox.DropDownStyle='DropDownList'; $script:PanelLanguageBox.Width=200; [void]$script:PanelLanguageBox.Items.AddRange(@('system','简体中文','繁體中文','བོད་ཡིག','English','日本語','Français','Español','Deutsch','Русский','한국어')); $script:PanelLanguageIds=@('system','zh-Hans','zh-Hant','bo','en','ja','fr','es','de','ru','ko'); $script:PanelLanguageBox.SelectedIndex=$script:PanelLanguageIds.IndexOf($script:PanelLanguage); $preferences.Controls.Add($script:PanelLanguageBox)
    $tools=New-Object Windows.Forms.FlowLayoutPanel; $tools.AutoSize=$true; $tools.Dock='Fill'; $outer.Controls.Add($tools,0,2)
    $searchLabel=New-Object Windows.Forms.Label; $searchLabel.AutoSize=$true; $searchLabel.Padding=New-Object Windows.Forms.Padding(0,6,0,0); $tools.Controls.Add($searchLabel); $script:PanelLabels.Add(@{ Control=$searchLabel; Key='Search components' })
    $script:PanelSearch=New-Object Windows.Forms.TextBox; $script:PanelSearch.Width=220; $tools.Controls.Add($script:PanelSearch)
    foreach ($spec in @(@('PanelSelect','Select visible'),@('PanelClear','Clear all'),@('PanelReload','Reload'))) {
        $button=New-Object Windows.Forms.Button; $button.AutoSize=$true; $tools.Controls.Add($button); Set-Variable -Scope Script -Name $spec[0] -Value $button; $script:PanelLabels.Add(@{ Control=$button; Key=$spec[1] })
    }
    $split=New-Object Windows.Forms.SplitContainer; $split.Dock='Fill'; $split.Orientation='Horizontal'; $split.Panel1MinSize=100; $split.Panel2MinSize=100; $split.Size=New-Object Drawing.Size(1000,420); $split.SplitterDistance=220; $outer.Controls.Add($split,0,3)
    $script:PanelGrid=New-Object Jobs.Setup.SelectionGrid; $grid=$script:PanelGrid; $grid.Dock='Fill'; $grid.AllowUserToAddRows=$false; $grid.AllowUserToDeleteRows=$false; $grid.AllowUserToResizeRows=$false; $grid.RowHeadersVisible=$false; $grid.MultiSelect=$false; $grid.SelectionMode='FullRowSelect'; $grid.EditMode='EditProgrammatically'; $grid.AutoSizeColumnsMode='Fill'; $grid.RowTemplate.Height=36
    $checkColumn=New-Object Windows.Forms.DataGridViewCheckBoxColumn; $checkColumn.Width=80; $checkColumn.AutoSizeMode='None'; [void]$grid.Columns.Add($checkColumn)
    foreach ($columnName in @('Component','Package','Status')) { $column=New-Object Windows.Forms.DataGridViewTextBoxColumn; $column.ReadOnly=$true; $column.SortMode='NotSortable'; [void]$grid.Columns.Add($column) }
    $grid.Columns[1].FillWeight=33; $grid.Columns[2].FillWeight=35; $grid.Columns[3].FillWeight=32
    $split.Panel1.Controls.Add($grid)
    $script:PanelEmpty=New-Object Windows.Forms.Label; $script:PanelEmpty.AutoSize=$false; $script:PanelEmpty.Dock='Fill'; $script:PanelEmpty.TextAlign='MiddleCenter'; $script:PanelLabels.Add(@{ Control=$script:PanelEmpty; Key='No matching components. Clear the search or reload.' }); $split.Panel1.Controls.Add($script:PanelEmpty); $script:PanelEmpty.BringToFront()
    $script:PanelLog=New-Object Jobs.Setup.PanelLog; $script:PanelLog.Dock='Fill'; $script:PanelLog.ReadOnly=$true; $script:PanelLog.DetectUrls=$false; $script:PanelLog.WordWrap=$false; $script:PanelLog.Font=New-Object Drawing.Font('Consolas',10); $split.Panel2.Controls.Add($script:PanelLog)
    $footer=New-Object Windows.Forms.FlowLayoutPanel; $footer.AutoSize=$true; $footer.Dock='Fill'; $outer.Controls.Add($footer,0,4)
    $script:PanelOperation=New-Object Windows.Forms.ComboBox; $script:PanelOperation.DropDownStyle='DropDownList'; $script:PanelOperation.Width=160; [void]$script:PanelOperation.Items.AddRange(@('Install','Uninstall')); $script:PanelOperation.SelectedIndex=0; $footer.Controls.Add($script:PanelOperation)
    foreach ($spec in @(@('PanelPreview','Preview plan'),@('PanelExecute','Install selected'),@('PanelCopy','Copy log'),@('PanelOpenLog','Log file'))) { $button=New-Object Windows.Forms.Button; $button.AutoSize=$true; $footer.Controls.Add($button); Set-Variable -Scope Script -Name $spec[0] -Value $button; $script:PanelLabels.Add(@{ Control=$button; Key=$spec[1] }) }
    $script:PanelFollow=New-Object Windows.Forms.CheckBox; $script:PanelFollow.AutoSize=$true; $script:PanelFollow.Checked=$true; $footer.Controls.Add($script:PanelFollow); $script:PanelLabels.Add(@{ Control=$script:PanelFollow; Key='Auto-scroll' })
    $bottom=New-Object Windows.Forms.TableLayoutPanel; $bottom.AutoSize=$true; $bottom.Dock='Fill'; $bottom.ColumnCount=1; $outer.Controls.Add($bottom,0,5)
    $license=New-Object Windows.Forms.Label; $license.AutoSize=$true; $license.MaximumSize=New-Object Drawing.Size(1500,0); $bottom.Controls.Add($license); $script:PanelLabels.Add(@{ Control=$license; Key='Accept the selected packages and WinGet source licenses; Windows may request UAC. No automatic restart.' })
    $script:PanelLicense=$license
    $script:PanelCount=New-Object Windows.Forms.Label; $script:PanelCount.AutoSize=$true; $bottom.Controls.Add($script:PanelCount)
    $script:PanelStatus=New-Object Windows.Forms.Label; $script:PanelStatus.AutoSize=$true; $script:PanelStatus.MaximumSize=New-Object Drawing.Size(1500,0); $bottom.Controls.Add($script:PanelStatus)
    $script:PanelProgress=New-Object Windows.Forms.ProgressBar; $script:PanelProgress.Dock='Top'; $script:PanelProgress.Height=12; $bottom.Controls.Add($script:PanelProgress)
    $script:PanelTrayMenu=New-Object Windows.Forms.ContextMenuStrip; $script:PanelTrayShow=$script:PanelTrayMenu.Items.Add('Show'); $script:PanelTrayState=$script:PanelTrayMenu.Items.Add('Ready'); $script:PanelTrayState.Enabled=$false; $script:PanelTrayExit=$script:PanelTrayMenu.Items.Add('Exit')
    $script:PanelTray=New-Object Windows.Forms.NotifyIcon; $script:PanelTray.Icon=[Drawing.SystemIcons]::Application; $script:PanelTray.ContextMenuStrip=$script:PanelTrayMenu; $script:PanelTray.Text='Jobs System Setup'; $script:PanelTray.Visible=$true
    Connect-PanelEvents
    $width=[Math]::Max(200,$form.ClientSize.Width-50); $intro.MaximumSize=New-Object Drawing.Size($width,0); $license.MaximumSize=New-Object Drawing.Size($width,0)
    Set-PanelLanguage; Set-PanelTheme
}
# 原生事件只在 GUI 线程处理；关闭保护覆盖窗口关闭和正常应用退出。
function Connect-PanelEvents {
    $script:PanelGrid.Add_CellValueChanged({ param($sender,$eventArgs) if ($eventArgs.RowIndex -ge 0 -and $eventArgs.ColumnIndex -eq 0) { $row=$sender.Rows[$eventArgs.RowIndex]; if ($row.Tag) { if ($script:PanelWorker) { $row.Cells[0].Value=[bool]$script:PanelSelected.ContainsKey([string]$row.Tag); return }; if ([bool]$row.Cells[0].Value) { $script:PanelSelected[[string]$row.Tag]=$true } else { $script:PanelSelected.Remove([string]$row.Tag) }; Update-PanelAvailability } } })
    $script:PanelForm.Add_Resize({ $width=[Math]::Max(200,$script:PanelForm.ClientSize.Width-50); $script:PanelIntro.MaximumSize=New-Object Drawing.Size($width,0); $script:PanelLicense.MaximumSize=New-Object Drawing.Size($width,0); $script:PanelStatus.MaximumSize=New-Object Drawing.Size($width,0) })
    $script:PanelSearch.Add_TextChanged({ Update-PanelRows })
    $script:PanelSelect.Add_Click({ foreach ($row in $script:PanelGrid.Rows) { $row.Cells[0].Value=$true } })
    $script:PanelClear.Add_Click({ $script:PanelSelected.Clear(); Update-PanelRows })
    $script:PanelReload.Add_Click({ try { Initialize-PanelPaths; Update-PanelRows } catch { Add-PanelLog $_.Exception.Message 'error' } })
    $script:PanelOperation.Add_SelectedIndexChanged({ if (-not $script:PanelUpdatingLanguage) { Update-PanelAvailability } })
    $script:PanelPreview.Add_Click({ Start-PanelOperation $true })
    $script:PanelExecute.Add_Click({ Start-PanelOperation $false })
    $script:PanelCopy.Add_Click({ if ($script:PanelLog.TextLength) { [Windows.Forms.Clipboard]::SetText($script:PanelLog.Text) } })
    $script:PanelOpenLog.Add_Click({ if ($script:PanelLogFile -and (Test-Path -LiteralPath $script:PanelLogFile)) { $info=New-Object Diagnostics.ProcessStartInfo; $info.FileName=$script:PanelLogFile; $info.UseShellExecute=$true; [void][Diagnostics.Process]::Start($info) } })
    $script:PanelLog.Add_ManualScroll({ $script:PanelFollow.Checked=$false })
    $script:PanelFollow.Add_CheckedChanged({ $script:PanelLog.AutoFollow=$script:PanelFollow.Checked; if ($script:PanelFollow.Checked) { $script:PanelLog.Select($script:PanelLog.TextLength,0); $script:PanelLog.ScrollToCaret() } })
    $script:PanelThemeBox.Add_SelectedIndexChanged({ if ($script:PanelUpdatingLanguage) { return }; $script:PanelTheme=@('system','light','dark')[$script:PanelThemeBox.SelectedIndex]; Set-PanelTheme; Save-PanelPreferences })
    $script:PanelLanguageBox.Add_SelectedIndexChanged({ if ($script:PanelUpdatingLanguage) { return }; $script:PanelLanguage=$script:PanelLanguageIds[$script:PanelLanguageBox.SelectedIndex]; Set-PanelLanguage; Save-PanelPreferences })
    $script:PanelTrayShow.Add_Click({ $script:PanelForm.Show(); $script:PanelForm.WindowState='Normal'; $script:PanelForm.Activate() })
    $script:PanelTray.Add_DoubleClick({ $script:PanelForm.Show(); $script:PanelForm.WindowState='Normal'; $script:PanelForm.Activate() })
    $script:PanelTrayExit.Add_Click({ if (-not $script:PanelWorker) { $script:PanelCanExit=$true; $script:PanelForm.Close() } })
    $script:PanelForm.Add_FormClosing({ param($sender,$eventArgs) if (-not $script:PanelCanExit -or $script:PanelWorker) { $eventArgs.Cancel=$true; Request-PanelClose } })
    $script:PanelTimer=New-Object Windows.Forms.Timer; $script:PanelTimer.Interval=100; $script:PanelTimer.Add_Tick({ Update-PanelWorker }); $script:PanelTimer.Start()
}
# 输出全部排空且进程退出后才冻结计时，未收到完成事件不能推断成功。
function Update-PanelWorker {
    if ((Get-PanelDark) -ne $script:PanelDark) { Set-PanelTheme }
    if ($script:PanelWorker) {
        $batch=0
        while ($batch -lt 250) {
            $line=$script:PanelWorker.Take(); if ($null -eq $line) { break }; $batch++
            try { Receive-PanelLine $line } catch { $script:PanelProtocolFailed=$true; Add-PanelLog $_.Exception.Message 'error' }
        }
        if (-not $script:PanelRunPreview) { $script:PanelDurations[$script:PanelRunOperation]=$script:PanelRunWatch.Elapsed }
        if ($script:PanelWorker.Finished) {
            $code=$script:PanelWorker.ExitCode; $script:PanelRunWatch.Stop(); $script:PanelWorker.Dispose(); $script:PanelWorker=$null
            if ($script:PanelRunPreview) { $script:PanelStatusKey=$(if ($code -eq 0) { 'Plan ready' } else { 'Task failed' }) }
            else {
                $counts=@{ completed=0; reused=0; skipped=0; failed=0; notrun=0 }
                foreach ($id in $script:PanelRunIds.Keys) {
                    if (-not $script:PanelRunResults.ContainsKey($id)) { $counts.notrun++; $script:PanelStatuses[$id]='Not run' }
                    elseif ($script:PanelRunResults[$id] -eq 'running') { $counts.failed++; $script:PanelStatuses[$id]='Failed: see log' }
                    else { $counts[$script:PanelRunResults[$id]]++ }
                }
                $summary=(Get-PanelText 'Finished: {0} completed, {1} reused, {2} skipped, {3} failed, {4} not run') -f $counts.completed,$counts.reused,$counts.skipped,$counts.failed,$counts.notrun
                Add-PanelLog $summary $(if ($code -ne 0 -or $script:PanelProtocolFailed -or $counts.failed -or $counts.notrun) { 'error' } else { 'success' })
                $script:PanelStatusKey=$(if ($code -ne 0 -or $script:PanelProtocolFailed -or $counts.failed -or $counts.notrun) { 'Task failed' } else { 'Completed' })
            }
            Add-PanelLog ((Get-PanelText 'Exit code: {0}') -f $code) $(if ($code -ne 0) { 'error' } else { 'info' })
            $script:PanelProgress.Value=100; Update-PanelRows
        }
    }
    $state=Get-PanelText $script:PanelStatusKey
    $script:PanelStatus.Text=$state+'  ·  '+(Get-PanelText 'Install')+' '+$script:PanelDurations.Install.ToString('hh\:mm\:ss')+'  ·  '+(Get-PanelText 'Uninstall')+' '+$script:PanelDurations.Uninstall.ToString('hh\:mm\:ss')
    $script:PanelTrayState.Text=$state
}
# 资源检查可跨平台运行，不加载 WinForms、不调用 WinGet或写配置。
function Test-PanelResources {
    $required=@($script:PanelTranslations.en.PSObject.Properties.Name | Sort-Object)
    foreach ($language in @('en','zh-Hans','zh-Hant','bo','ja','fr','es','de','ru','ko')) {
        $table=$script:PanelTranslations.PSObject.Properties[$language]
        if (-not $table) { throw ('Missing language: '+$language) }
        $keys=@($table.Value.PSObject.Properties.Name | Sort-Object)
        if (($keys -join "`n") -cne ($required -join "`n")) { throw ('Incomplete language: '+$language) }
    }
    foreach ($resource in @('Resources/PanelWorker.cs','Resources/PanelTranslations.json')) {
        if (-not (Test-Path -LiteralPath (Join-Path $script:PanelRoot $resource) -PathType Leaf)) { throw ('Missing resource: '+$resource) }
    }
}
# 按显式模式选择只读诊断或 Windows GUI，资源释放只在消息循环真正结束后进行。
function Invoke-PanelRequestedMode {
    if ($Check) {
        Write-Output ('Catalog: '+$script:PanelCatalog.Count)
        Write-Output 'Resources: OK; no package queries or writes.'
        return
    }
    if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) { throw 'This native WinForms panel requires Windows. Use -Check for portable resource checks.' }
    if ([Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') { throw 'Start with powershell.exe -STA -File, or use the adjacent CMD launcher.' }
    Initialize-PanelPreferences
    Initialize-PanelNativeTypes
    [Windows.Forms.Application]::EnableVisualStyles()
    try {
        New-PanelWindow
        [Windows.Forms.Application]::Run($script:PanelForm)
    } finally {
        if ($script:PanelTimer) { $script:PanelTimer.Stop(); $script:PanelTimer.Dispose() }
        if ($script:PanelTray) { $script:PanelTray.Visible=$false; $script:PanelTray.Dispose() }
        if ($script:PanelTrayMenu) { $script:PanelTrayMenu.Dispose() }
        if ($script:PanelForm) { $script:PanelForm.Dispose() }
    }
}
# 入口只编排路径、资源验证和所请求的运行模式。
function Main {
    Initialize-PanelPaths # 以本脚本位置定位同平台实施脚本和资源。
    Test-PanelResources # 核对当前目录与十语界面资源完整性。
    Invoke-PanelRequestedMode # 只读检查直接返回，正常模式启动受保护的 GUI 会话。
}
if ($MyInvocation.InvocationName -ne '.') {
    try { Main; exit 0 }
    catch {
        $message='Panel failed: '+$_.Exception.Message
        [Console]::Error.WriteLine($message)
        if (-not $Check -and [Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT) {
            Add-Type -AssemblyName System.Windows.Forms
            [void][Windows.Forms.MessageBox]::Show($message,'Jobs System Setup','OK','Error')
        }
        exit 1
    }
}

#requires -Version 5.1
<#
【WindowsOS】🆕新系统配置.ps1 | Jobs 新系统开发环境
Created by Jobs on 2026年11月17日，星期二.
用途：显式选择 Windows 开发组件，预览、补装或按收据反安装。
影响：写模式调用既有 WinGet，可能请求 UAC；不自动升级、不改系统代理。
默认：Plan 只列静态清单；Install / Uninstall 必须指定组件并明确确认。
#>
[CmdletBinding()]
param(
    [ValidateSet('Help', 'List', 'Plan', 'Install', 'Uninstall')][string]$Mode = 'Plan',
    [string[]]$Components = @(),
    [ValidateSet('Install', 'Uninstall')][string]$Operation = 'Install',
    [switch]$Confirm,
    [string]$StateRoot = '',
    [switch]$Events
)
# BEGIN JOBS_TERMINAL_STYLE_V1 - session-only colors; no profile or registry changes.
# 创建当前控制台的配色快照与能力状态。
function New-JobsTerminalStyleState {
    if ($PSVersionTable.PSVersion.Major -lt 5) { return @{ JobsTerminalPlainFallback = $true; Before = @{} } }
    if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT -or $Host.Name -ne 'ConsoleHost') { return $null }
    if ([Console]::IsInputRedirected -or [Console]::IsOutputRedirected -or [Console]::IsErrorRedirected) { return $null }
    if ((Test-Path Env:NO_COLOR) -or $env:TERM -ieq 'dumb' -or $env:PLAIN_OUTPUT -eq '1') { return $null }
    foreach ($key in [Environment]::GetEnvironmentVariables().Keys) {
        if ([string]$key -match '^(?i:SOURCE_?TREE)') { return $null }
    }
    if (-not ('Jobs.TerminalStyleV1.Native' -as [type])) {
        try {
        Add-Type -ErrorAction Stop -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.RegularExpressions;
namespace Jobs.TerminalStyleV1 {
    public static class Native {
        [StructLayout(LayoutKind.Explicit, Size=20, CharSet=CharSet.Unicode)]
        public struct InputRecord {
            [FieldOffset(0)] public ushort Kind;
            [FieldOffset(4)] public int Down;
            [FieldOffset(8)] public ushort Repeat;
            [FieldOffset(10)] public ushort Key;
            [FieldOffset(12)] public ushort Scan;
            [FieldOffset(14)] public char Character;
            [FieldOffset(16)] public uint Modifiers;
        }
        [DllImport("kernel32.dll")] static extern IntPtr GetStdHandle(int n);
        [DllImport("kernel32.dll")] static extern IntPtr GetConsoleWindow();
        [DllImport("kernel32.dll")] static extern bool GetConsoleMode(IntPtr h, out uint mode);
        [DllImport("kernel32.dll")] static extern bool SetConsoleMode(IntPtr h, uint mode);
        [DllImport("kernel32.dll")] static extern uint WaitForSingleObject(IntPtr h, uint milliseconds);
        [DllImport("kernel32.dll")] static extern bool GetNumberOfConsoleInputEvents(IntPtr h, out uint count);
        [DllImport("kernel32.dll", CharSet=CharSet.Unicode, ExactSpelling=true)] static extern bool ReadConsoleInputW(IntPtr h, [Out] InputRecord[] records, uint count, out uint read);
        [DllImport("kernel32.dll", CharSet=CharSet.Unicode, ExactSpelling=true)] static extern bool WriteConsoleInputW(IntPtr h, InputRecord[] records, uint count, out uint written);
        const string OwnerName = "JOBS_TERMINAL_STYLE_WINDOWS_OWNER";
        static readonly string[] Keys = { "10", "11", "4;0", "4;1", "4;2", "4;3", "4;4", "4;5", "4;6", "4;7", "4;8", "4;9", "4;10", "4;11", "4;12", "4;13", "4;14", "4;15" };
        static readonly string[] Hex = { "000000", "ff5f56", "5fd787", "ffd75f", "5fafff", "d787ff", "5fd7ff", "eeeeee", "9e9e9e", "ff8787", "87ffaf", "ffff87", "87bfff", "ffafff", "afffff", "ffffff" };
        static readonly Regex Reply = new Regex("\\x1b\\](?<key>10|11|4;[0-9]{1,2});(?<rgb>rgb:[0-9a-f]{1,4}/[0-9a-f]{1,4}/[0-9a-f]{1,4})(?:\\x07|\\x1b\\\\)", RegexOptions.IgnoreCase);
        public sealed class State {
            public IntPtr Input, Output;
            public uint OutputMode;
            public ConsoleColor Foreground, Background;
            public Dictionary<string,string> Original, Applied;
            public string Owner, PreviousOwner, Recovery;
            public bool Active, ModeChanged, Fallback;
            public Dictionary<string,string> EnvironmentBefore = new Dictionary<string,string>();
        }
        static string Escape(string key, string value) { return "\x1b]" + key + ";" + value + "\x07"; }
        static string Rgb(string hex) { return "rgb:" + hex.Substring(0,2) + "/" + hex.Substring(2,2) + "/" + hex.Substring(4,2); }
        static string Normal(string rgb) {
            string[] parts = rgb.Substring(4).Split('/');
            for (int n=0; n<3; n++) {
                int maximum = (1 << (4 * parts[n].Length)) - 1;
                int value = Convert.ToInt32(parts[n],16);
                parts[n] = ((value * 65535L + maximum/2) / maximum).ToString("x4");
            }
            return String.Join("/",parts);
        }
        // Preserve unrelated key/window records instead of consuming user input during color queries.
        static Dictionary<string,string> Query(State state) {
            uint pending;
            if (!GetNumberOfConsoleInputEvents(state.Input,out pending) || pending != 0) { return null; }
            StringBuilder commands = new StringBuilder();
            foreach (string key in Keys) { commands.Append(Escape(key,"?")); }
            Console.Write(commands.ToString());
            List<InputRecord> records = new List<InputRecord>();
            List<int> characterIndices = new List<int>();
            StringBuilder text = new StringBuilder();
            Dictionary<string,string> result = new Dictionary<string,string>();
            Stopwatch timer = Stopwatch.StartNew();
            try {
                while (timer.ElapsedMilliseconds < 600) {
                    if (result.Count == Keys.Length && GetNumberOfConsoleInputEvents(state.Input,out pending) && pending == 0) { break; }
                    if (WaitForSingleObject(state.Input,20) != 0) { continue; }
                    InputRecord[] item = new InputRecord[1]; uint read;
                    if (!ReadConsoleInputW(state.Input,item,1,out read) || read != 1) { break; }
                    int index = -1;
                    if (item[0].Kind == 1 && item[0].Character != '\0') {
                        if (item[0].Down != 0) { index = text.Length; text.Append(item[0].Character); }
                        else if (text.Length != 0 && text[text.Length-1] == item[0].Character) { index = text.Length-1; }
                    }
                    records.Add(item[0]); characterIndices.Add(index);
                    foreach (Match match in Reply.Matches(text.ToString())) {
                        string key = match.Groups["key"].Value;
                        if (Array.IndexOf(Keys,key) >= 0) { result[key] = match.Groups["rgb"].Value; }
                    }
                }
            } finally {
                bool[] used = new bool[text.Length];
                foreach (Match match in Reply.Matches(text.ToString())) {
                    for (int n=match.Index; n<match.Index+match.Length; n++) { used[n] = true; }
                }
                List<InputRecord> replay = new List<InputRecord>();
                for (int n=0; n<records.Count; n++) {
                    int index = characterIndices[n];
                    if (index < 0 || !used[index]) { replay.Add(records[n]); }
                }
                if (replay.Count != 0) {
                    uint written;
                    if (!WriteConsoleInputW(state.Input,replay.ToArray(),(uint)replay.Count,out written) || written != replay.Count) {
                        Console.Error.WriteLine("[Jobs] Could not replay terminal input; color protection is unavailable.");
                        result.Clear();
                    }
                }
            }
            return result.Count == Keys.Length ? result : null;
        }
        static void Plain(State state) {
            foreach (string key in new string[] { "NO_COLOR", "PLAIN_OUTPUT", "FORCE_COLOR", "CLICOLOR", "ANSI_COLORS_DISABLED" }) {
                state.EnvironmentBefore[key] = Environment.GetEnvironmentVariable(key);
                Environment.SetEnvironmentVariable(key, key == "FORCE_COLOR" || key == "CLICOLOR" ? "0" : "1");
            }
            state.Fallback = true;
        }
        public static void Enter(State state) {
            try {
                state.Input = GetStdHandle(-10); state.Output = GetStdHandle(-11);
                uint inputMode;
                if (!GetConsoleMode(state.Input,out inputMode) || !GetConsoleMode(state.Output,out state.OutputMode)) { Plain(state); return; }
                IntPtr window = GetConsoleWindow();
                if (window == IntPtr.Zero) { Plain(state); return; }
                string identity = window.ToInt64().ToString("x");
                state.PreviousOwner = Environment.GetEnvironmentVariable(OwnerName);
                if (!String.IsNullOrEmpty(state.PreviousOwner)) {
                    string[] owner = state.PreviousOwner.Split(':');
                    int pid; long started;
                    if (owner.Length == 3 && owner[0] == identity && Int32.TryParse(owner[1],out pid) && Int64.TryParse(owner[2],out started)) {
                        try { if (Process.GetProcessById(pid).StartTime.ToUniversalTime().Ticks == started) { return; } } catch {}
                    }
                }
                state.Foreground = Console.ForegroundColor; state.Background = Console.BackgroundColor;
                if ((state.OutputMode & 4) == 0) {
                    if (!SetConsoleMode(state.Output,state.OutputMode | 4)) { Plain(state); return; }
                    state.ModeChanged = true;
                }
                state.Original = Query(state);
                if (state.Original == null) { Restore(state); Plain(state); return; }
                state.Applied = new Dictionary<string,string>();
                state.Applied["10"] = "rgb:ff/ff/ff"; state.Applied["11"] = "rgb:00/00/00";
                for (int n=0; n<16; n++) { state.Applied["4;"+n] = Rgb(Hex[n]); }
                StringBuilder restore = new StringBuilder();
                foreach (string key in Keys) { restore.Append(Escape(key,state.Original[key])); }
                string encoded = Convert.ToBase64String(Encoding.UTF8.GetBytes(restore.ToString()));
                state.Recovery = Path.Combine(Path.GetTempPath(),"JobsTerminalStyle-"+Process.GetCurrentProcess().Id+"-"+Guid.NewGuid().ToString("N")+".ps1");
                string manual = "# Restore only the session colors saved by this Jobs script.\r\n"+
                    "if ([Console]::IsOutputRedirected) { throw 'Run in the original console.' }\r\n"+
                    "Add-Type -Namespace Jobs -Name RecoveryConsole -MemberDefinition '[System.Runtime.InteropServices.DllImport(\"kernel32.dll\")] public static extern System.IntPtr GetStdHandle(int n); [System.Runtime.InteropServices.DllImport(\"kernel32.dll\")] public static extern bool GetConsoleMode(System.IntPtr h, out uint m); [System.Runtime.InteropServices.DllImport(\"kernel32.dll\")] public static extern bool SetConsoleMode(System.IntPtr h, uint m);'\r\n"+
                    "$h = [Jobs.RecoveryConsole]::GetStdHandle(-11); [uint32]$m = 0\r\n"+
                    "if (-not [Jobs.RecoveryConsole]::GetConsoleMode($h, [ref]$m)) { throw 'Run in the original console.' }\r\n"+
                    "try {\r\nif (-not [Jobs.RecoveryConsole]::SetConsoleMode($h, ($m -bor 4))) { throw 'Cannot enable terminal recovery.' }\r\n"+
                    "[Console]::Write([Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('"+encoded+"')))\r\n"+
                    "[Console]::ForegroundColor = [ConsoleColor]"+((int)state.Foreground)+"\r\n"+
                    "[Console]::BackgroundColor = [ConsoleColor]"+((int)state.Background)+"\r\n"+
                    "[Console]::Write([string][char]27 + '[39;49m')\r\n"+
                    "} finally { [void][Jobs.RecoveryConsole]::SetConsoleMode($h, $m) }\r\n";
                File.WriteAllText(state.Recovery,manual,new UTF8Encoding(false));
                state.Owner = identity+":"+Process.GetCurrentProcess().Id+":"+Process.GetCurrentProcess().StartTime.ToUniversalTime().Ticks;
                Environment.SetEnvironmentVariable(OwnerName,state.Owner);
                state.Active = true;
                foreach (string key in Keys) { Console.Write(Escape(key,state.Applied[key])); }
                Console.ForegroundColor = ConsoleColor.White; Console.BackgroundColor = ConsoleColor.Black;
                Dictionary<string,string> check = Query(state);
                foreach (string key in Keys) {
                    if (check == null || Normal(check[key]) != Normal(state.Applied[key])) { Restore(state); Plain(state); return; }
                }
            } catch (Exception error) {
                Restore(state); Plain(state);
                Console.Error.WriteLine("[Jobs] Terminal style unavailable: " + error.Message);
            }
        }
        public static void Restore(State state) {
            if (state == null) { return; }
            try {
                if (state.Active) {
                    Dictionary<string,string> current = Query(state);
                    bool complete = current != null;
                    if (current != null) {
                        bool restoreForeground = Console.ForegroundColor == ConsoleColor.White && Normal(current["10"]) == Normal(state.Applied["10"]) && Normal(current["4;15"]) == Normal(state.Applied["4;15"]);
                        bool restoreBackground = Console.BackgroundColor == ConsoleColor.Black && Normal(current["11"]) == Normal(state.Applied["11"]) && Normal(current["4;0"]) == Normal(state.Applied["4;0"]);
                        foreach (string key in Keys) {
                            if (Normal(current[key]) == Normal(state.Applied[key])) { Console.Write(Escape(key,state.Original[key])); }
                            else if (Normal(current[key]) != Normal(state.Original[key])) {
                                complete = false; Console.Error.WriteLine("[Jobs] Kept a concurrent color change: " + key);
                            }
                        }
                        if (restoreForeground) { Console.ForegroundColor = state.Foreground; Console.Write("\x1b[39m"); }
                        if (restoreBackground) { Console.BackgroundColor = state.Background; Console.Write("\x1b[49m"); }
                    }
                    if (complete) {
                        Dictionary<string,string> check = Query(state);
                        foreach (string key in Keys) { if (check == null || Normal(check[key]) != Normal(state.Original[key])) { complete = false; } }
                    }
                    if (complete) { File.Delete(state.Recovery); }
                    else { Console.Error.WriteLine("[Jobs] Color restore needs review. Manual recovery: powershell -NoProfile -File \""+state.Recovery+"\""); }
                }
            } catch (Exception error) {
                Console.Error.WriteLine("[Jobs] Color restore failed: "+error.Message+"; recovery: "+state.Recovery);
            } finally {
                if (state.Owner != null && Environment.GetEnvironmentVariable(OwnerName) == state.Owner) { Environment.SetEnvironmentVariable(OwnerName,state.PreviousOwner); }
                state.Active = false;
                uint currentMode;
                if (state.ModeChanged && GetConsoleMode(state.Output,out currentMode) && currentMode == (state.OutputMode | 4)) { SetConsoleMode(state.Output,state.OutputMode); }
                state.ModeChanged = false;
                if (state.Fallback) {
                    foreach (KeyValuePair<string,string> pair in state.EnvironmentBefore) {
                        string applied = pair.Key == "FORCE_COLOR" || pair.Key == "CLICOLOR" ? "0" : "1";
                        if (Environment.GetEnvironmentVariable(pair.Key) == applied) { Environment.SetEnvironmentVariable(pair.Key,pair.Value); }
                    }
                    state.Fallback = false;
                }
            }
        }
    }
}
'@
        } catch {
            [Console]::Error.WriteLine('[Jobs] Terminal style setup failed; using plain output: ' + $_.Exception.Message)
            return @{ JobsTerminalPlainFallback = $true; Before = @{} }
        }
    }
    return New-Object Jobs.TerminalStyleV1.Native+State
}
# Guard setup is optional; failure keeps business behavior and the user's original terminal settings.
function Start-JobsTerminalStyle {
    param($State)
    if ($State -is [Collections.IDictionary] -and $State.Contains('JobsTerminalPlainFallback')) {
        foreach ($key in @('NO_COLOR', 'PLAIN_OUTPUT', 'FORCE_COLOR', 'CLICOLOR', 'ANSI_COLORS_DISABLED')) {
            $State.Before[$key] = [Environment]::GetEnvironmentVariable($key)
            [Environment]::SetEnvironmentVariable($key, $(if (@('FORCE_COLOR', 'CLICOLOR') -contains $key) { '0' } else { '1' }))
        }
        return
    }
    if ($null -ne $State) { [Jobs.TerminalStyleV1.Native]::Enter($State) }
}
# A finally block also runs for script exit and Ctrl+C; direct .NET calls avoid stopped pipelines.
function Stop-JobsTerminalStyle {
    param($State)
    if ($State -is [Collections.IDictionary] -and $State.Contains('JobsTerminalPlainFallback')) {
        foreach ($key in $State.Before.Keys) {
            $applied = if (@('FORCE_COLOR', 'CLICOLOR') -contains $key) { '0' } else { '1' }
            if ([Environment]::GetEnvironmentVariable($key) -ceq $applied) { [Environment]::SetEnvironmentVariable($key, $State.Before[$key]) }
        }
        return
    }
    if ($null -ne $State) { [Jobs.TerminalStyleV1.Native]::Restore($State) }
}
# END JOBS_TERMINAL_STYLE_V1
$script:Catalog = @(
    @{ Id='git'; Package='Git.Git'; Command='git.exe'; Args=@('--version'); Name='Git'; Pattern='^Git version ' },
    @{ Id='git-lfs'; Package='GitHub.GitLFS'; Command='git-lfs.exe'; Args=@('--version'); Name='Git LFS'; Pattern='^Git LFS' },
    @{ Id='gh'; Package='GitHub.cli'; Command='gh.exe'; Args=@('--version'); Name='GitHub CLI'; Pattern='^GitHub CLI' },
    @{ Id='nushell'; Package='Nushell.Nushell'; Command='nu.exe'; Args=@('--version'); Name='Nushell'; Pattern='^Nushell' },
    @{ Id='node'; Package='OpenJS.NodeJS.LTS'; Command='node.exe'; Args=@('--version'); Name='Node.js / npm（补装 LTS）'; Pattern='^Node.js$' },
    @{ Id='python'; Package='Python.Python.3.13'; Command='py.exe'; Args=@('-3.13','--version'); Name='Python 3.13'; Pattern='^Python 3\.13\..*\((64-bit|ARM64)\)$' },
    @{ Id='java'; Package='Microsoft.OpenJDK.17'; Command='java.exe'; Args=@('-version'); Name='Microsoft OpenJDK 17'; Pattern='^Microsoft Build of OpenJDK.*17' },
    @{ Id='go'; Package='GoLang.Go'; Command='go.exe'; Args=@('version'); Name='Go'; Pattern='^Go Programming Language' },
    @{ Id='cmake'; Package='Kitware.CMake'; Command='cmake.exe'; Args=@('--version'); Name='CMake'; Pattern='^CMake' },
    @{ Id='vscode'; Package='Microsoft.VisualStudioCode'; Command='code.cmd'; Args=@('--version'); Name='Visual Studio Code'; Pattern='^Microsoft Visual Studio Code' },
    @{ Id='7zip'; Package='7zip.7zip'; Command='7z.exe'; Args=@('i'); Name='7-Zip'; Pattern='^7-Zip' },
    @{ Id='curl'; Package='cURL.cURL'; Command='curl.exe'; Args=@('--version'); Name='cURL'; Pattern='^cURL' },
    @{ Id='jq'; Package='jqlang.jq'; Command='jq.exe'; Args=@('--version'); Name='jq'; Pattern='^jq' },
    @{ Id='fzf'; Package='junegunn.fzf'; Command='fzf.exe'; Args=@('--version'); Name='fzf'; Pattern='^fzf' },
    @{ Id='lazygit'; Package='JesseDuffield.lazygit'; Command='lazygit.exe'; Args=@('--version'); Name='lazygit'; Pattern='^lazygit' },
    @{ Id='uv'; Package='astral-sh.uv'; Command='uv.exe'; Args=@('--version'); Name='uv'; Pattern='^uv' },
    @{ Id='yt-dlp'; Package='yt-dlp.yt-dlp'; Command='yt-dlp.exe'; Args=@('--version'); Name='yt-dlp'; Pattern='^yt-dlp' },
    @{ Id='ffmpeg'; Package='Gyan.FFmpeg'; Command='ffmpeg.exe'; Args=@('-version'); Name='FFmpeg'; Pattern='^FFmpeg' },
    @{ Id='task'; Package='Task.Task'; Command='task.exe'; Args=@('--version'); Name='Task'; Pattern='^Task' },
    @{ Id='hugo'; Package='Hugo.Hugo.Extended'; Command='hugo.exe'; Args=@('version'); Name='Hugo Extended'; Pattern='^Hugo' }
)
$script:Selected = @()
$script:LogFile = $null
$script:LockStream = $null
$script:WorkRoot = $null
$script:WinGet = $null
# 展示本入口的用途、默认值与影响范围，不读取外部文档。
function Show-ScriptIntro {
    Write-Host 'Jobs Windows 新系统配置'
    Write-Host '默认 Plan；Help / List / Plan 只输出静态清单，不调用 WinGet、不落盘。'
    Write-Host 'Install 补装缺失组件、修复已登记但不可用的组件；健康安装直接复用。'
    Write-Host 'Uninstall 仅撤回有本工具收据、版本与完整安装目录指纹一致的新增组件。'
    Write-Host '原有工具、未知归属、目录已变化的工具和 WinGet 自动依赖保留。'
    Write-Host '实际写入会接受所选包及 winget 源许可，可能请求 UAC；不自动重启。'
    Write-Host '不安装 Xcode / CLT / Hammerspoon / JobsMacEnvVarConfigs；不更换默认 Shell。'
}
# 校验组件 ID 并构造显式清单；写模式不接受空选。
function Initialize-Selection {
    $ids = @($Components | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Select-Object -Unique)
    foreach ($id in $ids) {
        if (@($script:Catalog | Where-Object { $_.Id -ceq $id }).Count -ne 1) { throw ('未知组件：' + $id + '；使用 -Mode List 查看。') }
    }
    if ($Mode -in @('Install', 'Uninstall') -and $ids.Count -eq 0) { throw '写模式必须通过 -Components 指定组件，不默认全选。' }
    $script:Selected = @($script:Catalog | Where-Object { $ids.Count -eq 0 -or $ids -ccontains $_.Id })
}
# 输出帮助、组件清单或静态计划；此调用链无目录、日志和包管理器写入。
function Show-ReadOnlyResult {
    if ($Mode -eq 'Help') {
        Write-Host '-Mode Help|List|Plan|Install|Uninstall  默认 Plan'
        Write-Host '-Components git,node,python  必须使用清单 ID；省略时仅在只读模式列出全部。'
        Write-Host '-Operation Install|Uninstall  Plan 的预览操作，默认 Install。'
        Write-Host '-Confirm  自动化的显式写授权；省略时使用默认取消的键盘确认。'
        Write-Host '-StateRoot 路径  可选收据与日志位置；默认当前用户本地应用数据目录。'
        Write-Host '-Events  输出 @@JOBS_EVENT@@ JSON 组件事件，供管理面板读取；默认关闭。'
        return
    }
    foreach ($component in $script:Selected) {
        if ($Mode -eq 'List') { Write-Output ($component.Id + "`t" + $component.Package + "`t" + $component.Name) }
        elseif ($Operation -eq 'Uninstall') { Write-Output ('保守卸载计划：' + $component.Id + '；执行时复检收据、安装版本、完整目录及注册信息；条件不足保留。') }
        else { Write-Output ('补装计划：' + $component.Id + ' -> winget install --id ' + $component.Package + ' --exact --source winget --no-upgrade；执行时先体检，健康工具复用。') }
    }
    if ($Mode -eq 'Plan') { Write-Host '这是静态计划；尚未联网、检查安装状态或解析最终安装地址。' }
}
# 使用方向键和 Tab 选择，默认取消；无人值守只能显式传入 -Confirm。
function Confirm-ScriptAction {
    if ($Confirm) { return $true }
    if ($Host.Name -ne 'ConsoleHost' -or [Console]::IsInputRedirected -or [Console]::IsOutputRedirected) {
        throw '无交互写操作必须显式传入 -Confirm；只读查询无需授权参数。'
    }
    $index = 0
    Write-Host ('操作：' + $Mode + '；组件：' + (($script:Selected | ForEach-Object { $_.Id }) -join ', '))
    Write-Host '← / → / Tab 切换，回车确认；默认取消，Esc 取消。'
    while ($true) {
        [Console]::Write("`r" + $(if ($index -eq 0) { '[取消]  执行所选操作  ' } else { ' 取消  [执行所选操作]' }))
        $key = [Console]::ReadKey($true)
        if ($key.Key -eq 'Escape') { [Console]::WriteLine(); return $false }
        if ($key.Key -eq 'Enter') { [Console]::WriteLine(); return ($index -eq 1) }
        if ($key.Key -in @('LeftArrow','RightArrow','Tab','UpArrow','DownArrow')) { $index = 1 - $index }
    }
}
# 拒绝不支持的运行系统；包自身架构兼容性继续由官方清单解析。
function Assert-WindowsHost {
    if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) { throw '实际安装与卸载仅支持 Windows；其它系统可以查看 Help / List / Plan。' }
    if (-not [Environment]::Is64BitOperatingSystem -or [Environment]::OSVersion.Version.Build -lt 17763) { throw '最低要求 Windows 10 1809（build 17763）64 位；具体组件可能要求更新系统。' }
}
# 防止收据、日志或安装目录穿过重解析点。
function Assert-PlainPath {
    param([string]$Path)
    $cursor = [IO.Path]::GetFullPath($Path)
    while ($cursor) {
        if (Test-Path -LiteralPath $cursor) {
            $item = Get-Item -LiteralPath $cursor -Force -ErrorAction Stop
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw ('路径含联接或符号链接：' + $cursor) }
        }
        $parent = [IO.Path]::GetDirectoryName($cursor)
        if ($parent -eq $cursor) { break }
        $cursor = $parent
    }
}
# 确认后建立用户级工作目录及互斥文件，已有运行不抢锁。
function Initialize-WriteContext {
    $root = $StateRoot
    if ([string]::IsNullOrWhiteSpace($root)) {
        if ([string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) { throw '无法定位当前用户本地应用数据目录；请显式指定 -StateRoot。' }
        $root = Join-Path $env:LOCALAPPDATA 'JobsSystemBootstrap\WindowsOS'
    }
    $script:WorkRoot = [IO.Path]::GetFullPath($root)
    Assert-PlainPath $script:WorkRoot
    [void][IO.Directory]::CreateDirectory($script:WorkRoot)
    $script:LockStream = [IO.File]::Open((Join-Path $script:WorkRoot 'operation.lock'), [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    $script:LogFile = Join-Path $script:WorkRoot ((Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N') + '.log')
    [IO.File]::WriteAllText($script:LogFile, '', (New-Object Text.UTF8Encoding($false)))
    Write-RunMessage ('日志与收据：' + $script:WorkRoot)
}
# 同步控制台与纯文本日志，不把 ANSI 控制码写入磁盘。
function Write-RunMessage {
    param([string]$Message)
    $plain = [regex]::Replace($Message, "\x1B\[[0-?]*[ -/]*[@-~]", '')
    Write-Host $plain
    if ($script:LogFile) { [IO.File]::AppendAllText($script:LogFile, $plain + [Environment]::NewLine, (New-Object Text.UTF8Encoding($false))) }
}
# 调用既有 WinGet 并保留真实退出码，不执行下载脚本来安装包管理器。
function Invoke-WinGet {
    param([string[]]$Arguments)
    $ErrorActionPreference = 'Continue'
    $lines = New-Object 'System.Collections.Generic.List[string]'
    & $script:WinGet @Arguments 2>&1 | ForEach-Object {
        $line = $_.ToString()
        $lines.Add($line)
        Write-RunMessage $line
    }
    $code = $LASTEXITCODE
    return [pscustomobject]@{ Code = $code; Text = ($lines -join "`n") }
}
# 校验 WinGet 版本及所需选项；不自动安装 App Installer 或接受额外来源。
function Resolve-WinGet {
    $command = Get-Command winget.exe -CommandType Application -ErrorAction SilentlyContinue
    if (-not $command) { throw '未发现 winget；请从 Microsoft 官方 App Installer 准备：https://aka.ms/getwinget 。本入口不下载执行远程安装脚本。' }
    $script:WinGet = $command.Source
    $result = Invoke-WinGet @('--version')
    if ($result.Code -ne 0 -or $result.Text -notmatch '(?m)^v?(\d+)\.(\d+)') { throw 'winget 版本检查失败。' }
    if ([version]($Matches[1] + '.' + $Matches[2]) -lt [version]'1.8') { throw '需要 WinGet 1.8 或以上，请通过官方 App Installer 更新。' }
}
# 从 WinGet 官方 JSON 导出取得精确包 ID 与版本，不解析本地化终端表格。
function Get-PackageInventory {
    $file = Join-Path $script:WorkRoot ('inventory-' + [Guid]::NewGuid().ToString('N') + '.json')
    try {
        $result = Invoke-WinGet @('export','--output',$file,'--include-versions','--source','winget','--accept-source-agreements','--disable-interactivity')
        if ($result.Code -ne 0 -or -not (Test-Path -LiteralPath $file -PathType Leaf)) { throw 'WinGet 已安装清单导出失败，不猜测软件是否缺失。' }
        $data = [IO.File]::ReadAllText($file) | ConvertFrom-Json -ErrorAction Stop
        if (-not $data.PSObject.Properties['Sources'] -or $data.Sources -isnot [array]) { throw 'WinGet JSON 缺少 Sources 数组，停止处理而非推断为空清单。' }
        $packages = @{}
        foreach ($source in @($data.Sources)) {
            if (-not $source.PSObject.Properties['Packages'] -or $source.Packages -isnot [array]) { throw 'WinGet JSON 缺少 Packages 数组。' }
            foreach ($package in @($source.Packages)) {
                if (-not $package.PSObject.Properties['PackageIdentifier'] -or [string]::IsNullOrWhiteSpace([string]$package.PackageIdentifier)) { throw 'WinGet JSON 包身份无效。' }
                if ($packages.ContainsKey([string]$package.PackageIdentifier)) { throw '同一包 ID 存在多个版本或作用域，停止自动处理。' }
                $version = ''
                if ($package.PSObject.Properties['Version']) { $version = [string]$package.Version }
                $packages[[string]$package.PackageIdentifier] = $version
            }
        }
        return $packages
    } finally { if (Test-Path -LiteralPath $file -PathType Leaf) { [IO.File]::Delete($file) } }
}
# 安装后刷新本进程 PATH，不写 Shell 配置或覆盖调用者其它环境。
function Update-ProcessPath {
    $extra = @([Environment]::GetEnvironmentVariable('Path','Machine'), [Environment]::GetEnvironmentVariable('Path','User')) -join ';'
    $env:Path = $env:Path + ';' + $extra
}
# 真实执行组件的只读版本检查，命令别名和路径存在不能冒充健康。
function Test-ComponentHealth {
    param($Component)
    $ErrorActionPreference = 'Continue'
    $candidate = Get-Command $Component.Command -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    $path = $null
    $healthArgs = @($Component.Args)
    if ($candidate) { $path = $candidate.Source }
    if (-not $path) {
        $record = Get-ApplicationRecord $Component
        if ($record -and -not [string]::IsNullOrWhiteSpace([string]$record.Location)) {
            $relatives = @($Component.Command, ('bin\' + $Component.Command), ('cmd\' + $Component.Command))
            if ($Component.Id -eq 'python') { $relatives += 'python.exe' }
            foreach ($relative in $relatives) {
                $target = Join-Path ([string]$record.Location) $relative
                if (Test-Path -LiteralPath $target -PathType Leaf) {
                    $path=$target
                    if ($Component.Id -eq 'python' -and $relative -eq 'python.exe') { $healthArgs=@('--version') }
                    break
                }
            }
        }
    }
    if (-not $path) { return $false }
    try {
        $output = @(& $path @healthArgs 2>&1)
        if ($LASTEXITCODE -ne 0 -or $output.Count -eq 0) { return $false }
        $text = $output -join "`n"
        if ($Component.Id -eq 'node') {
            $npm = Get-Command npm.cmd -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
            $npmPath = $null
            if ($npm) { $npmPath = $npm.Source }
            if (-not $npmPath) { $npmPath = Join-Path ([IO.Path]::GetDirectoryName($path)) 'npm.cmd' }
            if (-not (Test-Path -LiteralPath $npmPath -PathType Leaf)) { return $false }
            $npmOutput = @(& $npmPath --version 2>&1)
            return ($LASTEXITCODE -eq 0 -and ($npmOutput -join "`n") -match '(?m)^\d+\.\d+\.\d+')
        }
        if ($Component.Id -eq 'python') { return ($text -match 'Python 3\.13\.') }
        if ($Component.Id -eq 'java') { return ($text -match 'version "17\.') }
        return $true
    } catch { return $false }
}
# 唯一注册记录提供安装目录；记录不唯一或缺目录时不承诺自动反安装。
function Get-ApplicationRecord {
    param($Component)
    $records = @()
    foreach ($base in @('HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall','HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall','HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall')) {
        if (-not (Test-Path -LiteralPath $base)) { continue }
        foreach ($key in Get-ChildItem -LiteralPath $base -ErrorAction Stop) {
            $record = Get-ItemProperty -LiteralPath $key.PSPath -ErrorAction Stop
            if ($record.PSObject.Properties['DisplayName'] -and $record.DisplayName -match $Component.Pattern) {
                $records += [ordered]@{ Key=$key.Name; Name=[string]$record.DisplayName; Version=[string]$record.DisplayVersion; Location=[string]$record.InstallLocation; Uninstall=[string]$record.UninstallString }
            }
        }
    }
    if ($records.Count -gt 1) { throw ('注册记录不唯一，保留并停止自动处理：' + $Component.Id) }
    if ($records.Count -eq 0) { return $null }
    return $records[0]
}
# 对独立安装目录的所有文件及注册信息生成指纹；无法完整读取则保留软件。
function Get-ComponentFingerprint {
    param($Component)
    $record = Get-ApplicationRecord $Component
    if (-not $record) { throw '没有唯一、带独立安装目录的注册信息。' }
    if ([string]::IsNullOrWhiteSpace([string]$record.Location)) { throw '注册信息缺少独立安装目录。' }
    $root = [IO.Path]::GetFullPath([string]$record.Location).TrimEnd([char[]]@('\','/'))
    Assert-PlainPath $root
    if (-not (Test-Path -LiteralPath $root -PathType Container)) { throw '安装目录不存在。' }
    foreach ($forbidden in @([IO.Path]::GetPathRoot($root),$env:WINDIR,$env:ProgramFiles,${env:ProgramFiles(x86)},$env:USERPROFILE,$env:LOCALAPPDATA)) {
        if ($forbidden -and $root.TrimEnd([char[]]@('\','/')) -ieq $forbidden.TrimEnd([char[]]@('\','/'))) { throw '安装目录不是可独立核对的软件目录。' }
    }
    $lines = New-Object 'System.Collections.Generic.List[string]'
    $stack = New-Object 'System.Collections.Generic.Stack[string]'
    $stack.Push($root)
    while ($stack.Count -gt 0) {
        $directory = $stack.Pop()
        foreach ($item in Get-ChildItem -LiteralPath $directory -Force -ErrorAction Stop) {
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw '安装目录包含联接或符号链接，保留软件。' }
            if ($item.PSIsContainer) { $lines.Add('D' + "`t" + $item.FullName.Substring($root.Length)); $stack.Push($item.FullName) }
            else { $lines.Add('F' + "`t" + $item.FullName.Substring($root.Length) + "`t" + (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256 -ErrorAction Stop).Hash) }
        }
    }
    if ($lines.Count -eq 0) { throw '安装目录为空，无法建立完整指纹。' }
    $text = ($record | ConvertTo-Json -Compress) + "`n" + (($lines | Sort-Object) -join "`n")
    $hash = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($hash.ComputeHash([Text.Encoding]::UTF8.GetBytes($text)))).Replace('-','') }
    finally { $hash.Dispose() }
}
# 原子保存单组件收据，待完成状态绝不被当成可卸载凭据。
function Save-Receipt {
    param($Component, $Receipt)
    $path = Join-Path $script:WorkRoot ($Component.Id + '.json')
    Assert-PlainPath $path
    $temp = $path + '.' + [Guid]::NewGuid().ToString('N') + '.tmp'
    try {
        [IO.File]::WriteAllText($temp, ($Receipt | ConvertTo-Json -Depth 8), (New-Object Text.UTF8Encoding($false)))
        if (Test-Path -LiteralPath $path) { [IO.File]::Replace($temp,$path,[NullString]::Value) }
        else { [IO.File]::Move($temp,$path) }
    } finally { if (Test-Path -LiteralPath $temp -PathType Leaf) { [IO.File]::Delete($temp) } }
}
# 读取本工具的收据并校验包身份，不接管旧工具或其它安装器。
function Read-Receipt {
    param($Component)
    $path = Join-Path $script:WorkRoot ($Component.Id + '.json')
    Assert-PlainPath $path
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $null }
    $receipt = [IO.File]::ReadAllText($path) | ConvertFrom-Json -ErrorAction Stop
    if ($receipt.Schema -ne 1 -or $receipt.Package -cne $Component.Package -or $receipt.Owner -cne 'JobsSystemBootstrap-WindowsOS') { throw ('收据身份不匹配：' + $Component.Id) }
    return $receipt
}
# 显示真实包源和目标后执行单个安装／修复，网络传输错误可中断退避。
function Invoke-PackageWrite {
    param($Component, [string]$Action)
    Write-RunMessage ('来源｜' + $Component.Name + '；winget 社区源；包 ID：' + $Component.Package)
    Write-RunMessage '来源：当前 WinGet 配置中名为 winget 的源；源 URL 与最终安装地址由 WinGet 解析，实际传输以它的输出为准。'
    Write-RunMessage '目标：所选包的官方默认安装目录；本入口不设置系统代理、不自动重启。'
    $arguments = @($Action,'--id',$Component.Package,'--exact','--source','winget','--silent','--disable-interactivity','--accept-source-agreements')
    if ($Action -in @('install','repair')) { $arguments += '--accept-package-agreements' }
    if ($Action -eq 'install') { $arguments += '--no-upgrade' }
    $attempt = 0
    while ($true) {
        $result = Invoke-WinGet $arguments
        if ($result.Code -eq 0) { return }
        $unsigned = [uint32]([int64]$result.Code -band 4294967295)
        if ($Action -eq 'uninstall' -or $unsigned -notin @(2147954402,2147954407,2147954429,2147954430)) {
            throw ('WinGet ' + $Action + ' 失败：' + $Component.Package + '，退出码 ' + $result.Code + '；保留现场，未重放其它组件。')
        }
        $attempt++
        $delay = [Math]::Min(30, $attempt * 3)
        Write-RunMessage ('网络获取失败，第 ' + $attempt + ' 次；' + $delay + ' 秒后重试，Ctrl+C 结束。')
        Start-Sleep -Seconds $delay
    }
}
# 只补装缺失工具；原有安装修复后也不取得卸载归属。
function Install-Component {
    param($Component)
    $inventory = Get-PackageInventory
    $healthy = Test-ComponentHealth $Component
    if ($healthy) { Write-RunMessage ('复用健康工具：' + $Component.Id + '；保留既有归属。'); $script:ComponentResult='reused'; return }
    if ($inventory.ContainsKey($Component.Package)) {
        Write-RunMessage ('修复既有但不可用的工具：' + $Component.Id + '；不取得反安装归属。')
        Invoke-PackageWrite $Component 'repair'
        Update-ProcessPath
        if (-not (Test-ComponentHealth $Component)) { throw ('修复后仍不可用：' + $Component.Id) }
        return
    }
    if (Get-ApplicationRecord $Component) { throw ('发现 WinGet 未能唯一映射的既有软件：' + $Component.Id + '；保留原件，不执行覆盖或认领。') }
    $existing = Read-Receipt $Component
    if ($existing -and $existing.Status -eq 'Pending') { throw ('发现上次未完成收据：' + $Component.Id + '；请先核对实际安装状态，不自动接管。') }
    $receipt = [ordered]@{ Schema=1; Owner='JobsSystemBootstrap-WindowsOS'; Package=$Component.Package; Status='Pending'; Version=''; Fingerprint=''; CreatedUtc=[DateTime]::UtcNow.ToString('o') }
    Save-Receipt $Component $receipt
    Invoke-PackageWrite $Component 'install'
    Update-ProcessPath
    $after = Get-PackageInventory
    if (-not $after.ContainsKey($Component.Package) -or [string]::IsNullOrWhiteSpace($after[$Component.Package]) -or $after[$Component.Package] -ieq 'Unknown' -or -not (Test-ComponentHealth $Component)) { throw ('安装后版本检查或包登记失败：' + $Component.Id + '；保留 Pending 收据，不声称就绪。') }
    $receipt.Version = $after[$Component.Package]
    $receipt.Status = 'InstalledManualUndo'
    try { $receipt.Fingerprint = Get-ComponentFingerprint $Component; $receipt.Status = 'Installed' }
    catch { Write-RunMessage ('已安装，但保留手工卸载边界：' + $Component.Id + '；' + $_.Exception.Message) }
    Save-Receipt $Component $receipt
    Write-RunMessage ('已验证安装：' + $Component.Id + '，版本 ' + $receipt.Version + '；收据状态 ' + $receipt.Status)
}
# 仅撤回新增且完整指纹不变的软件；原有、共享自动依赖和模糊状态保留。
function Uninstall-Component {
    param($Component)
    $receipt = Read-Receipt $Component
    if (-not $receipt) { throw ('保留 ' + $Component.Id + '：没有本工具新增归属收据。') }
    if ($receipt.Status -eq 'Removed') { Write-RunMessage ('已经撤回：' + $Component.Id); $script:ComponentResult='skipped'; return }
    if ($receipt.Status -ne 'Installed' -or -not $receipt.Fingerprint -or [string]::IsNullOrWhiteSpace([string]$receipt.Version) -or $receipt.Version -ieq 'Unknown') { throw ('保留 ' + $Component.Id + '：没有完整、可验证的安装后指纹与版本。') }
    $inventory = Get-PackageInventory
    if (-not $inventory.ContainsKey($Component.Package)) { $receipt.Status='Removed'; Save-Receipt $Component $receipt; Write-RunMessage ('软件已不存在：' + $Component.Id); $script:ComponentResult='skipped'; return }
    if ($inventory[$Component.Package] -cne $receipt.Version) { throw ('保留 ' + $Component.Id + '：安装版本已改变。') }
    if ((Get-ComponentFingerprint $Component) -cne $receipt.Fingerprint) { throw ('保留 ' + $Component.Id + '：安装目录或注册信息已改变。') }
    Invoke-PackageWrite $Component 'uninstall'
    $after = Get-PackageInventory
    if ($after.ContainsKey($Component.Package)) { throw ('卸载后仍有包登记：' + $Component.Id) }
    $receipt.Status = 'Removed'
    Save-Receipt $Component $receipt
    Write-RunMessage ('已撤回新增组件：' + $Component.Id + '；包管理器自动依赖与用户配置保留。')
}
# 可选机器事件不替代原日志；真实业务异常仍交给原入口返回非零退出码。
function Write-ComponentEvent {
    param([string]$Id, [string]$State)
    if ($Events) {
        Write-Output ('@@JOBS_EVENT@@' + ([ordered]@{ schema=1; id=$Id; operation=$Mode; state=$State } | ConvertTo-Json -Compress))
    }
}
# 顺序安装、逆序卸载；首个不确定状态停止，保留已完成收据供重试。
function Invoke-SelectedOperation {
    $items = @($script:Selected)
    if ($Mode -eq 'Uninstall') { [array]::Reverse($items) }
    foreach ($component in $items) {
        Write-RunMessage ('组件：' + $component.Id + '；操作：' + $Mode)
        Write-ComponentEvent $component.Id 'running'
        $script:ComponentResult = 'completed'
        try {
            if ($Mode -eq 'Install') { Install-Component $component }
            else { Uninstall-Component $component }
            Write-ComponentEvent $component.Id $script:ComponentResult
        } catch {
            Write-ComponentEvent $component.Id 'failed'
            throw
        }
    }
}
# 集中编排自述、计划、确认与受管写入；锁及终端状态由外层 finally 回收。
function Main {
    Show-ScriptIntro # 先说明用途、只读默认值、安装与反安装边界。
    $script:ErrorActionPreference = 'Stop'
    Initialize-Selection # 解析显式组件并拒绝写模式空选或未知对象。
    if ($Mode -in @('Help','List','Plan')) { Show-ReadOnlyResult; return }
    if (-not (Confirm-ScriptAction)) { Write-Host '已取消；未创建日志、锁或收据。'; return }
    Assert-WindowsHost # 明确确认后核对目标系统与位数。
    Initialize-WriteContext # 准备本轮独立日志和用户级互斥锁。
    Resolve-WinGet # 校验既有包管理器；缺失时给出官方准备入口。
    Invoke-SelectedOperation # 按显式清单处理组件并逐项保存真实状态。
}
# 点加载供隔离测试复用函数；独立运行始终由唯一 Main 入口收口。
if ($MyInvocation.InvocationName -ne '.') {
    $terminalState = $null
    try {
        if ($Mode -in @('Install','Uninstall')) { $terminalState = New-JobsTerminalStyleState; Start-JobsTerminalStyle $terminalState }
        Main
        exit 0
    } catch {
        [Console]::Error.WriteLine('失败：' + $_.Exception.Message)
        exit 1
    } finally {
        if ($script:LockStream) { $script:LockStream.Dispose() }
        Stop-JobsTerminalStyle $terminalState
    }
}

# Windows 管理面板 EXE 启动器源码工程

![Jobs出品，必属精品](https://picsum.photos/1500/400)

<!-- jobs-toc:start -->
<!-- jobs-toc:source {"v":2,"token":"[toc]"} -->
<details>
<summary>📚 目录（点击展开 / 收起）</summary>

- [🔥 前言](#%E5%89%8D%E8%A8%80)
- [一、源码与运行依赖](#files)
- [二、启动行为与失败边界](#launch)
- [三、在 Windows 重现构建](#build)
- [四、现有验证与目标系统待核](#verification)

</details>
<!-- jobs-toc:end -->

---

## 🔥 <span id="前言">前言</span>

本目录是 [**C#**](https://learn.microsoft.com/dotnet/csharp/) 启动器源码工程，生成真实的 Windows GUI 子系统 PE 可执行文件 `JobsSystemSetupManager.exe`，使用 [**.NET Framework 4.7.2**](https://learn.microsoft.com/dotnet/framework/install/on-windows-and-server) 与 AnyCPU 托管 IL。它负责打开既有管理面板，**不是单文件自包含应用，也不是 Native AOT**。

源码与成品共用原生 [**Windows PowerShell 5.1**](https://learn.microsoft.com/powershell/scripting/windows-powershell/overview)／WinForms 面板，不复制或重写 GUI 与组件生命周期。双击 EXE 只启动面板，不传安装、卸载或写入授权参数。

## 一、<span id="files">源码与运行依赖</span> <a href="#前言">🔼</a> <a href="#🔚">🔽</a>

| 文件 | 职责 |
| --- | --- |
| [JobsSystemSetupManager.csproj](./JobsSystemSetupManager.csproj) | `net472`、`WinExe`、`AnyCPU`、`Prefer32Bit=false`、确定性构建及版本声明 |
| [Program.cs](./Program.cs) | 按 EXE 实际位置校验资源、编码单个路径参数、启动系统 PowerShell、报告早期失败 |
| [app.manifest](./app.manifest) | `asInvoker`；启动器不请求管理员权限，不绕过 UAC |
| [NuGet.Config](./NuGet.Config) | 仅使用官方 nuget.org 包源，不继承其它包源 |
| [packages.lock.json](./packages.lock.json) | 固定官方参考程序集版本与内容哈希 |
| [LauncherBuildReceipt.json](../LauncherBuildReceipt.json) | 当前成品、配置、源码哈希与限定验证结果 |

构建依赖是 [**.NET SDK**](https://dotnet.microsoft.com/download) 与官方 [Microsoft.NETFramework.ReferenceAssemblies.net472 1.0.3](https://www.nuget.org/packages/Microsoft.NETFramework.ReferenceAssemblies.net472/1.0.3)。参考程序集只在构建期使用，不随产品分发；EXE 运行时仅引用系统 BCL，不要求安装构建所用的现代 .NET SDK。

产品运行需要 Windows 10 1809 64 位或更新版本、.NET Framework 4.7.2 或兼容的更高 4.x，以及系统 Windows PowerShell 5.1／WinForms。AnyCPU 表示 CLR 按实际环境选择进程架构，不能据此宣称每个 Windows 架构已经实测；ARM64 与旧系统均需目标机器验收。WinGet 只在用户点击实际安装／卸载时由既有后端检查。

分发必须保留以下相对结构；请复制完整 WindowsOS 产品包，不能只发送 EXE：

```text
WindowsOS/
├── 【WindowsOS】🆕新系统配置.ps1/
│   └── 【WindowsOS】🆕新系统配置.ps1
└── 【WindowsOS】🧰新系统配置管理.ps1/
    ├── JobsSystemSetupManager.exe
    ├── JobsSystemSetupManager.exe.config
    ├── 【WindowsOS】🧰新系统配置管理.ps1
    └── Resources/
        ├── PanelTranslations.json
        └── PanelWorker.cs
```

## 二、<span id="launch">启动行为与失败边界</span> <a href="#前言">🔼</a> <a href="#🔚">🔽</a>

- 使用 `AppDomain.CurrentDomain.BaseDirectory` 定位邻接面板和资源，不依赖调用工作目录。启动前检查 GUI、翻译、worker 源码与同平台 CLI 是否存在。
- 从系统 Windows 目录解析 `System32/WindowsPowerShell/v1.0/powershell.exe`；32 位进程在 64 位系统中使用 `Sysnative` 避免重定向。不从 PATH 查找替代程序，不调用 cmd 或 `ShellExecute`。
- 固定传入 `-NoLogo -NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File` 和一个编码后的本地脚本路径，不接收外部命令参数，不传 `-Confirm`、`-Mode` 或组件选择。执行策略仅作用本次子进程，组织策略仍可阻止运行。
- EXE 没有控制台窗口；GUI 子进程独立运行，启动器最多观察两秒早期退出，随后关闭自己的进程句柄，不终止 GUI。更晚的面板错误继续由既有 GUI 报告。
- 缺资源、系统 PowerShell 不存在、进程启动失败或早期非零退出使用原生 Windows 消息框提示。通用提示跟随系统十种语言，实际文件路径和诊断证据保留原文；不下载依赖、不改账户或系统设置、不触发软件安装。
- 当前 EXE 未进行 Authenticode 签名；平台信誉与组织应用控制策略另行生效。启动器不自动修改安全策略或清除来源标记。

## 三、<span id="build">在 Windows 重现构建</span> <a href="#前言">🔼</a> <a href="#🔚">🔽</a>

准备已有 .NET SDK 后，在本 `Launcher/` 目录运行下面的 PowerShell。构建入口不安装 SDK；首次需要从官方 NuGet 源下载锁定参考包。相同源码、参考包和编译器版本可复现确定性输出；跨 SDK 版本可能生成不同字节，仍应重新核对产物。

命令在独立 PowerShell 子进程中设置临时缓存、CLI 状态和中间产物，不持久修改调用者环境。显式关闭 SDK 首次运行的 ASP.NET 证书生成及工具路径追加；`DOTNET_SKIP_FIRST_TIME_EXPERIENCE` 本身不能代替这些开关。

```powershell
powershell.exe -NoLogo -NoProfile -Command {
    $ErrorActionPreference = 'Stop'
    $project = (Resolve-Path -LiteralPath './JobsSystemSetupManager.csproj').Path
    $projectDirectory = Split-Path $project -Parent
    $taskDirectory = Join-Path ([IO.Path]::GetTempPath()) ('JobsLauncherBuild-' + [Guid]::NewGuid().ToString('N'))
    [void][IO.Directory]::CreateDirectory($taskDirectory)
    $env:DOTNET_CLI_HOME = Join-Path $taskDirectory 'dotnet-home'
    $env:NUGET_PACKAGES = Join-Path $taskDirectory 'nuget'
    $env:NUGET_HTTP_CACHE_PATH = Join-Path $taskDirectory 'http-cache'
    $env:NUGET_PLUGINS_CACHE_PATH = Join-Path $taskDirectory 'plugin-cache'
    $env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'
    $env:DOTNET_SKIP_FIRST_TIME_EXPERIENCE = '1'
    $env:DOTNET_GENERATE_ASPNET_CERTIFICATE = 'false'
    $env:DOTNET_ADD_GLOBAL_TOOLS_TO_PATH = 'false'
    $objects = (Join-Path $taskDirectory 'obj') + [IO.Path]::DirectorySeparatorChar
    $output = (Join-Path $taskDirectory 'product') + [IO.Path]::DirectorySeparatorChar
    $configuration = Join-Path $projectDirectory 'NuGet.Config'
    dotnet --list-sdks
    if ($LASTEXITCODE -ne 0) { throw 'A working .NET SDK is required.' }
    dotnet restore $project --configfile $configuration --locked-mode --disable-parallel `
        "-p:BaseIntermediateOutputPath=$objects" "-p:MSBuildProjectExtensionsPath=$objects" -p:NuGetAudit=false
    if ($LASTEXITCODE -ne 0) { throw 'Restore failed; no product was replaced.' }
    dotnet build $project --no-restore -c Release `
        "-p:BaseIntermediateOutputPath=$objects" "-p:MSBuildProjectExtensionsPath=$objects" "-p:OutputPath=$output"
    if ($LASTEXITCODE -ne 0) { throw 'Build failed; no product was replaced.' }
    $destination = Split-Path $projectDirectory -Parent
    foreach ($name in @('JobsSystemSetupManager.exe', 'JobsSystemSetupManager.exe.config')) {
        $built = Join-Path $output $name
        if (-not (Test-Path -LiteralPath $built -PathType Leaf)) { throw ('Missing output: ' + $name) }
        Copy-Item -LiteralPath $built -Destination (Join-Path $destination $name) -Force
        Get-FileHash -LiteralPath (Join-Path $destination $name) -Algorithm SHA256
    }
    Write-Host ('Build records and isolated caches: ' + $taskDirectory)
}
```

构建成功后还需更新 `../LauncherBuildReceipt.json` 中的工具链、成品与源码哈希，再制作分发包；命令不伪造 Windows 实机验收记录。保留失败现场，别将不完整产物替换为成品。可在 Visual Studio 打开本 `.csproj` 检查源码与 manifest，框架和包版本仍以工程与锁文件为准。

## 四、<span id="verification">现有验证与目标系统待核</span> <a href="#前言">🔼</a> <a href="#🔚">🔽</a>

2026-11-17 使用 macOS 的 .NET SDK 11.0.100 跨编译，官方参考包还原成功，Release 构建零警告、零错误。PE 结构证明 GUI 子系统、CLR 托管入口、ILOnly、非 32BitRequired、非 32BitPreferred，目标框架属性为 `.NETFramework,Version=v4.7.2`。

18 项隔离断言覆盖 Unicode／空格／引号参数、系统 PowerShell 与 Sysnative 路由、没有写操作参数、没有控制台／ShellExecute、缺资源拒绝、移动目录后资源定位，以及 PE／AnyCPU／BCL 引用。测试仅调用纯路径与参数逻辑并读取编译结果；没有执行 Windows PowerShell、WinGet 或安装器。

**尚未在 Windows 实机执行 EXE。** 双击启动、原生错误消息框、组织策略、路径含中文与空格的实际 CreateProcess、x64／ARM64、GUI 交互、UAC 及安装卸载仍需在目标系统验收。跨编译成功与 AnyCPU 标记不替代这些结果。

<a id="🔚" href="#前言">我是有底线的➤点我回到首页</a>

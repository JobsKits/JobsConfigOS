# 只打开仓库管理 GUI；写操作在 GUI 中预览和确认。
param([string]$Repository)
$ErrorActionPreference = 'Stop'
# 限定清单目标在本工具 dist 内，不依赖当前工作目录。
function Main {
    Write-Host 'Git repository manager: opening the read-only panel.'
    $delivery = Split-Path -Parent $PSScriptRoot
    $manifest = Join-Path $delivery 'latest-windows.json'
    if (-not (Test-Path -LiteralPath $manifest -PathType Leaf)) {
        throw 'Build the Windows EXE using the Windows build entry in the Git manager folder first.'
    }
    $relative = (Get-Content -LiteralPath $manifest -Raw -Encoding UTF8 | ConvertFrom-Json).executable
    if ([string]::IsNullOrWhiteSpace($relative) -or [IO.Path]::IsPathRooted($relative) -or $relative.Contains('..') -or $relative -notlike 'dist/WindowsOS/*/JobsGitManager/JobsGitManager.exe') {
        throw 'Invalid build manifest.'
    }
    $target = Join-Path $delivery $relative
    if (-not (Test-Path -LiteralPath $target -PathType Leaf)) { throw "Missing executable: $target" }
    if ([string]::IsNullOrWhiteSpace($Repository)) { $Repository = Split-Path -Parent $delivery }
    & $target --repo $Repository
    if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
try { Main; exit 0 } catch {
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'JobsGitManager') | Out-Null
    exit 1
}

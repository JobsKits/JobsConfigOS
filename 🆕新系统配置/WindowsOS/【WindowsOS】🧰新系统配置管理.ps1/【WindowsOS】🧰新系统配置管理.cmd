@echo off
setlocal DisableDelayedExpansion
rem Jobs native WinForms launcher. GUI execution buttons confirm all writes.
rem Resolve the UTF-8 script name through this ASCII marker; no console is retained.
set "JOBS_SETUP_PANEL_DIRECTORY=%~dp0."
powershell.exe -NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -Command "$entry = Get-ChildItem -LiteralPath $env:JOBS_SETUP_PANEL_DIRECTORY -Filter '*.ps1' -File; if (@($entry).Count -ne 1) { throw 'Expected one panel script.' }; $p = New-Object Diagnostics.ProcessStartInfo; $p.FileName = Join-Path $PSHOME 'powershell.exe'; $p.Arguments = '-NoLogo -NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File ' + [char]34 + $entry[0].FullName + [char]34; $p.UseShellExecute = $false; $p.CreateNoWindow = $true; [void][Diagnostics.Process]::Start($p)"
if errorlevel 1 pause
endlocal

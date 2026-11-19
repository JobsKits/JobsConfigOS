@echo off
rem Jobs Windows bootstrap: ASCII launcher, one implementation per package.
setlocal DisableDelayedExpansion
set "jobs_pause="
if "%~1"=="" set "jobs_pause=1"
set "jobs_script="
set "jobs_count=0"
for %%F in ("%~dp0*.ps1") do (
    if exist "%%~fF" if not exist "%%~fF\" (
        set /a jobs_count+=1 >nul
        set "jobs_script=%%~fF"
    )
)
if not "%jobs_count%"=="1" goto missing_script
set "jobs_engine=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%jobs_engine%" goto missing_engine
"%jobs_engine%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%jobs_script%" %*
set "jobs_result=%errorlevel%"
if defined jobs_pause (
    echo Press any key to close this window.
    pause >nul
)
endlocal & exit /b %jobs_result%
:missing_script
>&2 echo Expected exactly one PowerShell implementation in this package.
endlocal & exit /b 1
:missing_engine
>&2 echo Windows PowerShell was not found at the system location.
endlocal & exit /b 1

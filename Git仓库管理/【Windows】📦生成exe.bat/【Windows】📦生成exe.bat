@echo off
rem Native Windows builder. Python handles confirmation and isolated dependencies.
setlocal
where py >nul 2>nul
if errorlevel 1 goto python_fallback
for %%V in (3.13 3.14 3.12 3.11) do (
    py -%%V -c "import sys" >nul 2>nul
    if not errorlevel 1 (
        set "build_python_version=%%V"
        goto build_py
    )
)
:python_fallback
python "%~dp0..\JobsGitManager\scripts\build.py\build.py" %*
goto end
:build_py
py -%build_python_version% "%~dp0..\JobsGitManager\scripts\build.py\build.py" %*
:end
set "build_result=%errorlevel%"
if not "%build_result%"=="0" pause
exit /b %build_result%

@echo off
rem Relative text launcher. Git changes require confirmation inside the GUI.
setlocal
chcp 65001 >nul
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Git仓库管理\WindowsOS\launch.ps1" -Repository "%~dp0."
exit /b %errorlevel%

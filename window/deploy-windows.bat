@echo off
REM OpenClaw Windows GUI Installer
REM Double-click this file to launch the installer wizard.
powershell.exe -STA -ExecutionPolicy Bypass -NoProfile -File "%~dp0scripts\deploy-windows.ps1"
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo Something went wrong. Check the errors above.
    pause
)

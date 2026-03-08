@echo off
REM OpenClaw EXE Builder
REM Double-click to build manage-config.ps1 and deploy-windows.ps1 into EXE files.
powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%~dp0scripts\build-exe.ps1"
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo Build failed. Check the errors above.
)
pause

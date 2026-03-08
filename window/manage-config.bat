@echo off
REM OpenClaw Configuration Manager
REM Double-click to view and manage gateway credentials and settings.
powershell.exe -STA -ExecutionPolicy Bypass -NoProfile -File "%~dp0scripts\manage-config.ps1"

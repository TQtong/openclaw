@echo off
REM OpenClaw Docker One-Click Setup (Windows)
REM Double-click this file to set up OpenClaw with Docker.
REM
REM Requirements:
REM   - Docker Desktop installed and running
REM   - At least 2GB RAM for image build
REM
REM Optional environment variables (set before running):
REM   OPENCLAW_IMAGE           - Use remote image instead of building locally
REM   OPENCLAW_GATEWAY_PORT    - Gateway port (default: 18789)
REM   OPENCLAW_CONFIG_DIR      - Config directory

echo.
echo ================================================================
echo         OpenClaw Docker One-Click Setup
echo ================================================================
echo.

REM Check if Docker is running
docker info >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Docker is not running.
    echo Please start Docker Desktop and try again.
    echo.
    pause
    exit /b 1
)

powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%~dp0script\docker-setup.ps1"

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo Setup failed. Check the errors above.
)

echo.
pause

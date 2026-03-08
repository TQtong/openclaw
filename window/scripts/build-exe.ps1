# OpenClaw EXE Builder
# Compiles PowerShell scripts into standalone EXE files using PS2EXE

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir = Split-Path $scriptDir -Parent
$outputDir = Join-Path $rootDir "dist"

Write-Host ""
Write-Host "OpenClaw EXE Builder" -ForegroundColor Cyan
Write-Host "====================" -ForegroundColor Cyan
Write-Host ""

# Check/Install PS2EXE module
$ps2exe = Get-Module -ListAvailable -Name ps2exe
if (-not $ps2exe) {
    Write-Host "PS2EXE module not found. Installing..." -ForegroundColor Yellow
    try {
        Install-Module -Name ps2exe -Scope CurrentUser -Force -AllowClobber
        Write-Host "PS2EXE installed." -ForegroundColor Green
    } catch {
        Write-Host "ERROR: Failed to install PS2EXE." -ForegroundColor Red
        Write-Host "Run: Install-Module -Name ps2exe -Scope CurrentUser" -ForegroundColor Yellow
        exit 1
    }
}
Import-Module ps2exe -Force

# Create output directory
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

# Scripts to build
$scripts = @(
    @{
        Source = Join-Path $scriptDir "manage-config.ps1"
        Output = Join-Path $outputDir "OpenClaw-Config-Manager.exe"
        Title = "OpenClaw Config Manager"
        NoConsole = $true
    },
    @{
        Source = Join-Path $scriptDir "deploy-windows.ps1"
        Output = Join-Path $outputDir "OpenClaw-Installer.exe"
        Title = "OpenClaw Installer"
        NoConsole = $true
    }
)

$success = 0
$failed = 0

foreach ($s in $scripts) {
    if (-not (Test-Path $s.Source)) {
        Write-Host "SKIP: $($s.Source) not found" -ForegroundColor Yellow
        continue
    }
    
    Write-Host "Building: $($s.Title)..." -ForegroundColor White
    Write-Host "  Source: $($s.Source)" -ForegroundColor Gray
    Write-Host "  Output: $($s.Output)" -ForegroundColor Gray
    
    try {
        $params = @{
            InputFile = $s.Source
            OutputFile = $s.Output
            STA = $true
            Title = $s.Title
            Description = $s.Title
            Company = "OpenClaw"
            Product = $s.Title
            Version = "1.0.0.0"
            Copyright = "OpenClaw"
            RequireAdmin = $false
        }
        if ($s.NoConsole) {
            $params.NoConsole = $true
        }
        
        Invoke-PS2EXE @params
        
        if (Test-Path $s.Output) {
            Write-Host "  OK" -ForegroundColor Green
            $success++
        } else {
            Write-Host "  FAILED: Output not created" -ForegroundColor Red
            $failed++
        }
    } catch {
        Write-Host "  FAILED: $($_.Exception.Message)" -ForegroundColor Red
        $failed++
    }
    Write-Host ""
}

Write-Host "==============================" -ForegroundColor Cyan
Write-Host "Built: $success  Failed: $failed" -ForegroundColor $(if ($failed -eq 0) { "Green" } else { "Yellow" })
Write-Host "Output: $outputDir" -ForegroundColor Gray
Write-Host ""

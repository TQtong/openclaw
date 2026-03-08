# OpenClaw Gateway - Stop
$logDir = Join-Path $env:USERPROFILE ".openclaw\logs"
$pidFile = Join-Path $logDir "gateway.pid"

if (-not (Test-Path $pidFile)) {
    Write-Host "No gateway PID file found. Gateway may not be running."
    exit 0
}

$rawPid = (Get-Content $pidFile -ErrorAction SilentlyContinue).Trim()
if (-not $rawPid) {
    Write-Host "PID file is empty."
    Remove-Item $pidFile -Force -ErrorAction SilentlyContinue
    exit 0
}

$proc = Get-Process -Id $rawPid -ErrorAction SilentlyContinue
if ($proc) {
    Write-Host "Stopping gateway (PID: $rawPid)..."
    Stop-Process -Id $rawPid -Force
    Start-Sleep -Seconds 2
    Write-Host "Gateway stopped."
} else {
    Write-Host "Gateway process (PID: $rawPid) is not running."
}

Remove-Item $pidFile -Force -ErrorAction SilentlyContinue

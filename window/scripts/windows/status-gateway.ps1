# OpenClaw Gateway - Status
$logDir = Join-Path $env:USERPROFILE ".openclaw\logs"
$pidFile = Join-Path $logDir "gateway.pid"
$ProjectRoot = "G:\\myself\\exploration\\openclaw"
$HealthPort = 18789

Write-Host ""
Write-Host "OpenClaw Gateway Status"
Write-Host "======================"

if (Test-Path $pidFile) {
    $rawPid = (Get-Content $pidFile -ErrorAction SilentlyContinue).Trim()
    if ($rawPid) {
        $proc = Get-Process -Id $rawPid -ErrorAction SilentlyContinue
        if ($proc -and ($proc.ProcessName -eq "node")) {
            $uptime = ((Get-Date) - $proc.StartTime)
            $uptimeStr = "{0}d {1:D2}h {2:D2}m {3:D2}s" -f $uptime.Days, $uptime.Hours, $uptime.Minutes, $uptime.Seconds
            Write-Host "Status:  RUNNING"
            Write-Host "PID:     $rawPid"
            Write-Host "Uptime:  $uptimeStr"
        } else {
            Write-Host "Status:  STOPPED (stale PID file)"
            Remove-Item $pidFile -Force -ErrorAction SilentlyContinue
        }
    }
} else {
    Write-Host "Status:  STOPPED"
}

Write-Host "Project: $ProjectRoot"
Write-Host "Config:  $($env:USERPROFILE)\.openclaw"

try {
    $response = Invoke-WebRequest -Uri "http://127.0.0.1:${HealthPort}/healthz" -TimeoutSec 3 -UseBasicParsing -ErrorAction Stop
    Write-Host "Health:  OK ($($response.StatusCode))"
} catch {
    Write-Host "Health:  Unreachable"
}
Write-Host ""

# OpenClaw Gateway - Start
$ErrorActionPreference = "Stop"
$ProjectRoot = "G:\\myself\\exploration\\openclaw"
$GatewayPort = 18789
$GatewayBind = "loopback"

if ($args.Count -ge 1) { $GatewayPort = $args[0] }
if ($args.Count -ge 2) { $GatewayBind = $args[1] }

$logDir = Join-Path $env:USERPROFILE ".openclaw\logs"
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}
$logFile = Join-Path $logDir "gateway.log"
$errFile = Join-Path $logDir "gateway-error.log"
$pidFile = Join-Path $logDir "gateway.pid"

if (Test-Path $pidFile) {
    $existingPid = (Get-Content $pidFile -ErrorAction SilentlyContinue).Trim()
    if ($existingPid) {
        $proc = Get-Process -Id $existingPid -ErrorAction SilentlyContinue
        if ($proc -and ($proc.ProcessName -eq "node")) {
            Write-Host "Gateway is already running (PID: $existingPid)"
            Write-Host "Use stop-gateway.ps1 to stop it first."
            exit 0
        }
    }
}

Write-Host "Starting OpenClaw Gateway..."
Write-Host "  Port: $GatewayPort"
Write-Host "  Bind: $GatewayBind"
Write-Host "  Log:  $logFile"

$p = Start-Process -FilePath "node" `
    -ArgumentList "$ProjectRoot\openclaw.mjs","gateway","run","--port","$GatewayPort","--bind","$GatewayBind","--force" `
    -WorkingDirectory $ProjectRoot `
    -WindowStyle Hidden `
    -RedirectStandardOutput $logFile `
    -RedirectStandardError $errFile `
    -PassThru

Set-Content -Path $pidFile -Value $p.Id -Encoding ASCII

Write-Host "Gateway started (PID: $($p.Id))"
Write-Host "Logs: $logFile"

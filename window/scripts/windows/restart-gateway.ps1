# OpenClaw Gateway - Restart
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
& "$scriptDir\stop-gateway.ps1"
Start-Sleep -Seconds 2
& "$scriptDir\start-gateway.ps1" @args

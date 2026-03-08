# Start OpenClaw Docker containers
$RootDir = Split-Path (Split-Path $MyInvocation.MyCommand.Path -Parent) -Parent
$ComposeFile = Join-Path $RootDir "docker-compose.yml"

Write-Host "Starting OpenClaw gateway..." -ForegroundColor Yellow
docker compose -f $ComposeFile up -d openclaw-gateway
Write-Host "Done." -ForegroundColor Green
Write-Host ""
Write-Host "Gateway URL: http://127.0.0.1:18789" -ForegroundColor Cyan

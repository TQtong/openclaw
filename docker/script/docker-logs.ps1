# View OpenClaw Docker logs
$RootDir = Split-Path (Split-Path $MyInvocation.MyCommand.Path -Parent) -Parent
$ComposeFile = Join-Path $RootDir "docker-compose.yml"

Write-Host "Viewing OpenClaw gateway logs (Ctrl+C to exit)..." -ForegroundColor Yellow
docker compose -f $ComposeFile logs -f openclaw-gateway

# Stop OpenClaw Docker containers
$RootDir = Split-Path (Split-Path $MyInvocation.MyCommand.Path -Parent) -Parent
$ComposeFile = Join-Path $RootDir "docker-compose.yml"

Write-Host "Stopping OpenClaw containers..." -ForegroundColor Yellow
docker compose -f $ComposeFile stop
Write-Host "Done." -ForegroundColor Green
